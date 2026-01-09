import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/server_node.dart';
import 'platform_service.dart';

/// 桌面端代理服务 - 管理 xray-core 进程
class DesktopProxyService {
  static DesktopProxyService? _instance;
  static DesktopProxyService get instance => _instance ??= DesktopProxyService._();
  
  DesktopProxyService._();
  
  Process? _xrayProcess;
  bool _isRunning = false;
  final _statusController = StreamController<bool>.broadcast();
  
  /// 连接状态流
  Stream<bool> get statusStream => _statusController.stream;
  
  /// 是否已连接
  bool get isConnected => _isRunning;
  
  /// 连接到指定节点
  Future<bool> connect(ServerNode node) async {
    if (_isRunning) {
      await disconnect();
    }
    
    try {
      // 生成配置文件
      final configPath = await _generateConfig(node);
      
      // 获取 xray-core 路径和工作目录
      final (xrayPath, workingDir) = await _getXrayPath();
      if (xrayPath == null) {
        debugPrint('[DesktopProxy] xray-core not found');
        return false;
      }
      
      debugPrint('[DesktopProxy] Starting xray-core: $xrayPath');
      debugPrint('[DesktopProxy] Working directory: $workingDir');
      
      // 启动 xray-core 进程，设置工作目录以找到 dat 文件
      _xrayProcess = await Process.start(
        xrayPath,
        ['run', '-c', configPath],
        workingDirectory: workingDir,
        mode: ProcessStartMode.detachedWithStdio,
      );
      
      // 监听进程输出
      _xrayProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[Xray] $data');
      });
      
      _xrayProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[Xray Error] $data');
      });
      
      // 等待启动
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 设置系统代理
      await _setSystemProxy(true);
      
      _isRunning = true;
      _statusController.add(true);
      debugPrint('[DesktopProxy] Connected successfully');
      return true;
    } catch (e) {
      debugPrint('[DesktopProxy] Connect error: $e');
      return false;
    }
  }
  
  /// 断开连接
  Future<bool> disconnect() async {
    try {
      // 关闭系统代理
      await _setSystemProxy(false);
      
      // 终止 xray 进程
      if (_xrayProcess != null) {
        _xrayProcess!.kill();
        _xrayProcess = null;
      }
      
      _isRunning = false;
      _statusController.add(false);
      debugPrint('[DesktopProxy] Disconnected');
      return true;
    } catch (e) {
      debugPrint('[DesktopProxy] Disconnect error: $e');
      return false;
    }
  }
  
  /// 生成 xray 配置文件
  Future<String> _generateConfig(ServerNode node) async {
    final dir = await getApplicationSupportDirectory();
    final configFile = File('${dir.path}/xray_config.json');
    
    // 生成 V2Ray 配置
    final config = node.toV2rayConfig();
    
    // 添加本地监听
    final fullConfig = {
      'log': {
        'loglevel': 'warning',
      },
      'inbounds': [
        {
          'tag': 'socks',
          'port': 10808,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'settings': {
            'auth': 'noauth',
            'udp': true,
          },
        },
        {
          'tag': 'http',
          'port': 10809,
          'listen': '127.0.0.1',
          'protocol': 'http',
          'settings': {},
        },
      ],
      'outbounds': [config],
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [],
      },
    };
    
    await configFile.writeAsString(jsonEncode(fullConfig));
    return configFile.path;
  }
  
  /// 获取 xray-core 可执行文件路径和工作目录
  Future<(String?, String?)> _getXrayPath() async {
    final platform = PlatformService.instance;
    final execName = platform.xrayExecutable;
    
    if (execName.isEmpty) return (null, null);
    
    // 获取可执行文件所在目录（Flutter 打包后的路径）
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    
    // 1. 检查 CMake 安装的路径 (Release/Debug Build)
    // Linux/Windows: data/xray-bin/
    final installedBinDir = '$exeDir/data/xray-bin';
    final installedXray = File('$installedBinDir/$execName');
    
    if (await installedXray.exists()) {
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', installedXray.path]);
      }
      debugPrint('[DesktopProxy] Found xray in installed dir: ${installedXray.path}');
      
      // 工作目录：dat 文件现在也被 CMake 复制到了 bin 同级目录
      return (installedXray.path, installedBinDir);
    }

    // 2. 检查 Flutter Assets (旧逻辑，作为回退 - 虽然现在已移除)
    final bundleAssetsDir = '$exeDir/data/flutter_assets/assets/xray-core';
    final bundleXray = File('$bundleAssetsDir/$execName');
    
    if (await bundleXray.exists()) {
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', bundleXray.path]);
      }
      return (bundleXray.path, bundleAssetsDir);
    }
    
    // 3. 开发环境回退 (直接访问源码目录 assets/bin)
    // 假设当前运行目录是项目根目录
    final devBinXray = File('assets/bin/$execName');
    if (await devBinXray.exists()) {
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', devBinXray.path]);
      }
      // dat 文件也在这里
      return (devBinXray.path, 'assets/bin');
    }
    
    // 检查系统 PATH
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['xray'],
      );
      if (result.exitCode == 0) {
        final xrayPath = result.stdout.toString().trim();
        return (xrayPath, null);
      }
    } catch (_) {}
    
    return (null, null);
  }
  
  /// 设置系统代理
  Future<void> _setSystemProxy(bool enable) async {
    try {
      if (Platform.isWindows) {
        await _setWindowsProxy(enable);
      } else if (Platform.isMacOS) {
        await _setMacOSProxy(enable);
      } else if (Platform.isLinux) {
        await _setLinuxProxy(enable);
      }
    } catch (e) {
      debugPrint('[DesktopProxy] Set system proxy error: $e');
    }
  }
  
  /// Windows 系统代理设置
  Future<void> _setWindowsProxy(bool enable) async {
    if (enable) {
      // 启用代理
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyEnable',
        '/t', 'REG_DWORD',
        '/d', '1',
        '/f',
      ]);
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyServer',
        '/t', 'REG_SZ',
        '/d', '127.0.0.1:10809',
        '/f',
      ]);
    } else {
      // 禁用代理
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyEnable',
        '/t', 'REG_DWORD',
        '/d', '0',
        '/f',
      ]);
    }
  }
  
  /// macOS 系统代理设置
  Future<void> _setMacOSProxy(bool enable) async {
    // 获取当前网络服务
    final result = await Process.run('networksetup', ['-listallnetworkservices']);
    final services = result.stdout.toString().split('\n')
        .where((s) => s.isNotEmpty && !s.startsWith('*'))
        .toList();
    
    for (final service in services) {
      if (enable) {
        await Process.run('networksetup', ['-setsocksfirewallproxy', service, '127.0.0.1', '10808']);
        await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'on']);
      } else {
        await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'off']);
      }
    }
  }
  
  /// Linux 系统代理设置 (GNOME)
  Future<void> _setLinuxProxy(bool enable) async {
    if (enable) {
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy', 'mode', 'manual']);
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy.socks', 'host', '127.0.0.1']);
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy.socks', 'port', '10808']);
    } else {
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy', 'mode', 'none']);
    }
  }
  
  /// 释放资源
  void dispose() {
    disconnect();
    _statusController.close();
  }
}
