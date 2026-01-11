import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';
import '../models/server_node.dart';
import 'hysteria2_service.dart';
import 'doh_resolver.dart';

/// V2ray服务 - 全平台统一入口
/// 负责协调所有平台的连接、断开、状态查询
/// Android/iOS: 通过 MethodChannel 调用原生代码
/// Win/Mac/Linux: 直接在 Dart 层管理进程 (Xray & Hysteria2)
class V2rayService {
  static const MethodChannel _channel = MethodChannel('com.flux.app/v2ray');
  static const EventChannel _statusChannel =
      EventChannel('com.flux.app/v2ray_status');
  static Stream<bool>? _statusStream;
  
  // 桌面端专用
  final _hysteriaService = Hysteria2Service();
  Process? _xrayProcess;
  
  // 桌面端连接状态 (因为桌面端主要靠本类管理状态)
  bool _desktopConnected = false;
  final _desktopStatusController = StreamController<bool>.broadcast();

  // 单例模式 (确保全局状态一致)
  static final V2rayService _instance = V2rayService._internal();
  factory V2rayService() => _instance;
  V2rayService._internal();

  Stream<bool> get statusStream {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return _desktopStatusController.stream;
    }
    return _statusStream ??=
        _statusChannel.receiveBroadcastStream().map((event) {
      if (event is bool) return event;
      return event == true;
    });
  }

  // 动态端口
  int _socksPort = 10808;
  int _httpPort = 10809;

  // ...
  
  /// 查找可用端口
  Future<int> _findAvailablePort(int startPort) async {
    int port = startPort;
    while (port < 65535) {
      try {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
        await socket.close();
        return port;
      } catch (_) {
        port++;
      }
    }
    return startPort; // Fallback
  }

  /// 连接到指定节点
  Future<bool> connect(ServerNode node) async {
    // 1. 桌面端处理 (Win / Mac / Linux)
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        await disconnect(); // 确保先断开当前管理的进程

        // 强制清理可能残留的僵尸进程 (增加 /T 参数以清理子进程)
        if (Platform.isWindows) {
           print('[V2rayService] Force cleaning old processes...');
           try { 
             final result = await Process.run('taskkill', ['/F', '/T', '/IM', 'xray-windows*.exe']); 
             print('[V2rayService] Kill Xray result: ${result.exitCode}');
           } catch(e) { print('[V2rayService] Kill Xray error: $e'); }
           
           try { 
             final result = await Process.run('taskkill', ['/F', '/T', '/IM', 'hysteria-windows*.exe']); 
             print('[V2rayService] Kill Hysteria result: ${result.exitCode}');
           } catch(e) { print('[V2rayService] Kill Hysteria error: $e'); }
        } else {
           try { await Process.run('pkill', ['-f', 'xray']); } catch(_) {}
           try { await Process.run('pkill', ['-f', 'hysteria']); } catch(_) {}
        }
        
        // 分配新端口
        _socksPort = await _findAvailablePort(10808);
        _httpPort = await _findAvailablePort(_socksPort + 1);
        print('[V2rayService] Selected ports - SOCKS: $_socksPort, HTTP: $_httpPort');

        print('[V2rayService] Connecting to node protocol: ${node.protocol}');

        // Hysteria2 协议 (不区分大小写)
        final protocol = node.protocol.toLowerCase();
        if (protocol == 'hysteria2' || protocol == 'hy2') {
           await _hysteriaService.start(node, socksPort: _socksPort, httpPort: _httpPort);
           await _setDesktopProxy(true);
           _updateDesktopStatus(true);
           return true;
        } 
        
        // 其他协议 (Xray)
        final success = await _startDesktopXray(node);
        if (success) {
           _updateDesktopStatus(true);
        }
        return success;
        
      } catch(e) {
        print('[V2rayService] Desktop Connect Error: $e');
        await disconnect();
        return false;
      }
    }

    // 2. 移动端处理 (Android / iOS)
    // ...

    await _ensureMobileAssets(); 
    try {
      final resolvedNode = await _resolveServerAddress(node);
      final config = resolvedNode.toV2rayConfig();
      print('[DEBUG v2ray_service] Mobile Connect config: ${jsonEncode(config)}');
      final result = await _channel.invokeMethod<bool>(
        'connect',
        {'config': jsonEncode(config)},
      );
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
  
  void _updateDesktopStatus(bool isConnected) {
    _desktopConnected = isConnected;
    _desktopStatusController.add(isConnected);
  }

  /// 桌面端 Xray 启动逻辑 (Win / Mac / Linux)
  Future<bool> _startDesktopXray(ServerNode node) async {
      await _ensureDesktopAssets();
      
      final (xrayPath, workingDir) = await _getDesktopXrayPath();
      if (xrayPath == null) {
        print('[V2rayService] Xray executable not found');
        return false;
      }

      final dir = await getApplicationSupportDirectory();
      // Windows 习惯放在 bin 目录，Mac/Linux 可能直接放在 Support 根目录，统一一下
      final binDir = Platform.isWindows ? Directory(path.join(dir.path, 'bin')) : dir;
      if (!await binDir.exists()) await binDir.create(recursive: true);
      
      final configPath = path.join(binDir.path, 'config.json');
      
      // 生成 Xray 配置
      final fullConfig = {
        "log": {"loglevel": "warning"},
        "dns": {
          "servers": [
            "8.8.8.8",
            "1.1.1.1",
            "223.5.5.5",
            "localhost"
          ]
        },
        "inbounds": [
          {
            "tag": "socks",
            "port": _socksPort,
            "listen": "127.0.0.1",
            "protocol": "socks",
            "settings": {"auth": "noauth", "udp": true},
            "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
          },
          {
            "tag": "http",
            "port": _httpPort,
            "listen": "127.0.0.1",
            "protocol": "http",
            "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
          }
        ],
        "outbounds": [
          node.toV2rayConfig()..['tag'] = 'proxy',
          {
            "protocol": "freedom", 
            "tag": "direct",
            "settings": {"domainStrategy": "UseIP"}
          },
          {"protocol": "blackhole", "tag": "block"}
        ],
        "routing": {
          "domainStrategy": "IPIfNonMatch",
          "rules": [
            {
              "type": "field",
              "ip": ["geoip:private", "geoip:cn"],
              "outboundTag": "direct"
            },
            {
              "type": "field",
              "domain": ["geosite:private", "geosite:cn"],
              "outboundTag": "direct"
            }
          ]
        }
      };
      
      await File(configPath).writeAsString(jsonEncode(fullConfig));
      
      print('[V2rayService] Starting Xray: $xrayPath -c $configPath');
      
      _xrayProcess = await Process.start(
        xrayPath,
        ['run', '-c', configPath],
        workingDirectory: workingDir ?? binDir.path,
        runInShell: false,
        mode: ProcessStartMode.normal, // 改为 normal 以便捕获日志
      );
      
      // 捕获日志
      _xrayProcess!.stdout.transform(utf8.decoder).listen((line) {
         print('[Xray] $line');
      });
      _xrayProcess!.stderr.transform(utf8.decoder).listen((line) {
         print('[Xray Error] $line');
      });
      
      // 监听退出 (Windows 需要特别是)
      _xrayProcess?.exitCode.then((code) {
         print('Xray exited with code $code');
         if (_desktopConnected) {
            disconnect(); // 意外退出则断开
         }
      });
      
      await _setDesktopProxy(true);
      return true;
  }
  
  /// 确保桌面端资源存在 (主要是 Windows 需要复制)
  Future<void> _ensureDesktopAssets() async {
    if (!Platform.isWindows) return;
    
    final appSupportDir = await getApplicationSupportDirectory();
    final binDir = Directory(path.join(appSupportDir.path, 'bin'));
    if (!await binDir.exists()) await binDir.create(recursive: true);

    final isArm64 = Platform.version.toLowerCase().contains('arm64') || 
                    Platform.version.toLowerCase().contains('aarch64');
    final xrayName = isArm64 ? 'xray-windows-arm64.exe' : 'xray-windows-amd64.exe';
    
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    
    // 平台特定的二进制文件目录
    final platformDir = 'windows';
    var binSourceDir = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'bin', platformDir);
    var dataSourceDir = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'bin'); // geoip/geosite 在根目录
    
    if (!await Directory(binSourceDir).exists()) {
       print('[V2rayService] Source dir not found at $binSourceDir, trying dev fallback...');
       binSourceDir = path.join('assets', 'bin', platformDir);
       dataSourceDir = path.join('assets', 'bin');
    }
    
    print('[V2rayService] Binary source dir: $binSourceDir');
    
    // 复制 Xray 可执行文件
    final xrayTarget = File(path.join(binDir.path, xrayName));
    if (!await xrayTarget.exists()) {
      final xraySource = File(path.join(binSourceDir, xrayName));
      if (await xraySource.exists()) {
        print('[V2rayService] Copying $xrayName');
        await xraySource.copy(xrayTarget.path);
      } else {
        print('[V2rayService] Warning: $xrayName not found at ${xraySource.path}');
      }
    }
    
    // 复制通用数据文件
    for (final asset in ['geoip.dat', 'geosite.dat']) {
      final targetFile = File(path.join(binDir.path, asset));
      if (!await targetFile.exists()) {
        final sourceFile = File(path.join(dataSourceDir, asset));
        if (await sourceFile.exists()) {
          print('[V2rayService] Copying $asset');
          await sourceFile.copy(targetFile.path);
        }
      }
    }
  }
  
  /// 获取桌面端 Xray 路径
  Future<(String?, String?)> _getDesktopXrayPath() async {
    if (Platform.isWindows) {
      final appSupportDir = await getApplicationSupportDirectory();
      final binDir = path.join(appSupportDir.path, 'bin');
      final isArm64 = Platform.version.toLowerCase().contains('arm64');
      final name = isArm64 ? 'xray-windows-arm64.exe' : 'xray-windows-amd64.exe';
      final file = File(path.join(binDir, name));
      
      print('[V2rayService] Checking Xray binary at: ${file.path}');
      
      if (await file.exists()) return (file.path, binDir);
      return (null, null);
    }
    
    // Mac / Linux 查找逻辑
     String archName = 'xray'; 
     if (Platform.isMacOS) {
       archName = Platform.version.contains('arm64') ? 'xray-darwin-arm64' : 'xray-darwin-amd64';
     } else if (Platform.isLinux) {
       archName = Platform.version.contains('arm64') ? 'xray-linux-arm64' : 'xray-linux-amd64';
     }
     
     final possiblePaths = [
       'assets/bin/$archName', // 开发环境
       '/usr/local/bin/xray', 
     ];
     // 还可以添加打包后的路径检查
     
     for (final p in possiblePaths) {
       if (await File(p).exists()) {
         if (!Platform.isWindows) try { await Process.run('chmod', ['+x', p]); } catch(_) {}
         return (p, File(p).parent.path);
       }
     }
     return (null, null);
  }

  /// 确保移动端资源 (Android)
  Future<void> _ensureMobileAssets() async {
    if (!Platform.isAndroid) return;
    try {
      final dir = await getApplicationSupportDirectory();
      for (final file in ['geoip.dat', 'geosite.dat']) {
        final f = File('${dir.path}/$file');
        if (!await f.exists()) {
          final data = await rootBundle.load('assets/bin/$file');
          await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
        }
      }
    } catch (_) {}
  }

  /// 预解析地址
  Future<ServerNode> _resolveServerAddress(ServerNode node) async {
    final address = node.address;
    if (_isIpAddress(address)) return node;
    
    String? ip;
    try {
      final addresses = await InternetAddress.lookup(address).timeout(const Duration(seconds: 3));
      if (addresses.isNotEmpty) {
        ip = (addresses.firstWhere((a) => a.type == InternetAddressType.IPv4, orElse: () => addresses.first)).address;
      }
    } catch (_) {}
    
    if (ip == null) {
      try { ip = await DohResolver.resolve(address); } catch (_) {}
    }
    
    if (ip != null) {
      final newRawConfig = Map<String, dynamic>.from(node.rawConfig ?? {});
      if ((newRawConfig['sni'] as String?)?.isEmpty ?? true) newRawConfig['sni'] = address;
      newRawConfig['server'] = ip;
      
      return ServerNode(
        name: node.name,
        address: ip,
        port: node.port,
        protocol: node.protocol,
        uuid: node.uuid,
        alterId: node.alterId,
        network: node.network,
        security: node.security,
        rawConfig: newRawConfig,
        latency: node.latency,
        isSelected: node.isSelected,
      );
    }
    return node;
  }

  bool _isIpAddress(String address) {
    final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    final ipv6Regex = RegExp(r'^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$');
    return ipv4Regex.hasMatch(address) || ipv6Regex.hasMatch(address);
  }

  /// 断开连接
  Future<bool> disconnect() async {
    // 桌面端处理
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        if (_hysteriaService.isRunning) await _hysteriaService.stop();
        if (_xrayProcess != null) {
          _xrayProcess!.kill();
          _xrayProcess = null;
        }
        await _setDesktopProxy(false);
        _updateDesktopStatus(false);
        return true;
      } catch (e) {
        return false;
      }
    }
    
    // 移动端处理
    try {
      final result = await _channel.invokeMethod<bool>('disconnect');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// 获取连接状态
  Future<bool> isConnected() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
       return _desktopConnected;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isConnected');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
  
  /// 桌面系统代理设置
  Future<void> _setDesktopProxy(bool enable) async {
    try {
       if (Platform.isWindows) {
         await _setWindowsProxy(enable);
       } else if (Platform.isMacOS) {
         await _setMacProxy(enable);
       } else if (Platform.isLinux) {
         await _setLinuxProxy(enable);
       }
    } catch (e) {
      print('Set Proxy Error: $e');
    }
  }
  
  // Windows Proxy
  Future<void> _setWindowsProxy(bool enable) async {
    final shell = Shell();
    if (enable) {
      await shell.run('reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyServer /t REG_SZ /d "127.0.0.1:$_httpPort" /f');
      await shell.run('reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f');
    } else {
      await shell.run('reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f');
    }
  }
  
  // Mac Proxy
  Future<void> _setMacProxy(bool enable) async {
    final result = await Process.run('networksetup', ['-listallnetworkservices']);
    final services = result.stdout.toString().split('\n')
        .where((s) => s.isNotEmpty && !s.startsWith('*'))
        .toList(); 
    for (final service in services) {
       if (enable) {
          await Process.run('networksetup', ['-setwebproxy', service, '127.0.0.1', '$_httpPort']);
          await Process.run('networksetup', ['-setsecurewebproxy', service, '127.0.0.1', '$_httpPort']);
          await Process.run('networksetup', ['-setsocksfirewallproxy', service, '127.0.0.1', '$_socksPort']);
       } else {
          await Process.run('networksetup', ['-setwebproxystate', service, 'off']);
          await Process.run('networksetup', ['-setsecurewebproxystate', service, 'off']);
          await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'off']);
       }
    }
  }
  
  // Linux Proxy (Gnome)
  Future<void> _setLinuxProxy(bool enable) async {
     if (enable) {
        await Process.run('gsettings', ['set', 'org.gnome.system.proxy', 'mode', 'manual']);
        await Process.run('gsettings', ['set', 'org.gnome.system.proxy.http', 'host', '127.0.0.1']);
        await Process.run('gsettings', ['set', 'org.gnome.system.proxy.http', 'port', '10809']);
        await Process.run('gsettings', ['set', 'org.gnome.system.proxy.https', 'host', '127.0.0.1']);
        await Process.run('gsettings', ['set', 'org.gnome.system.proxy.https', 'port', '10809']);
        await Process.run('gsettings', ['set', 'org.gnome.system.proxy.socks', 'host', '127.0.0.1']);
        await Process.run('gsettings', ['set', 'org.gnome.system.proxy.socks', 'port', '10808']);
     } else {
        await Process.run('gsettings', ['set', 'org.gnome.system.proxy', 'mode', 'none']);
     }
  }
}
