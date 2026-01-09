
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';
import 'package:flux/models/server_node.dart';

class V2rayServiceWindows {
  static final V2rayServiceWindows _instance = V2rayServiceWindows._internal();
  factory V2rayServiceWindows() => _instance;
  V2rayServiceWindows._internal();

  Process? _xrayProcess;
  bool _isConnected = false;

  // Stream controller for connection status
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  Future<void> init() async {
    if (!Platform.isWindows) return;
    await _ensureCoreAssets();
  }

  Future<void> _ensureCoreAssets() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final binDir = Directory(path.join(appSupportDir.path, 'bin'));
    
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    // List of files to copy
    final assets = [
      'xray.exe',
      'geoip.dat',
      'geosite.dat',
    ];

    // Windows executable path (where the running .exe is)
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    final sourceDir = path.join(exeDir, 'data', 'xray-bin');

    for (final asset in assets) {
      final targetFile = File(path.join(binDir.path, asset));
      if (!await targetFile.exists()) {
        final sourceFile = File(path.join(sourceDir, asset));
        if (await sourceFile.exists()) {
          debugPrint('Copying $asset to ${targetFile.path}');
          await sourceFile.copy(targetFile.path);
        } else {
          debugPrint('Warning: Source asset not found: ${sourceFile.path}');
        }
      }
    }
  }

  Future<bool> connect(ServerNode node) async {
    try {
      if (_isConnected) {
        await disconnect();
      }

      await _ensureCoreAssets();
      
      final appSupportDir = await getApplicationSupportDirectory();
      final binDir = path.join(appSupportDir.path, 'bin');
      final xrayPath = path.join(binDir, 'xray.exe');
      final configPath = path.join(binDir, 'config.json');

      // Generate config
      final config = _generateConfig(node);
      await File(configPath).writeAsString(jsonEncode(config));

      // Start Xray
      debugPrint('Starting Xray: $xrayPath -c $configPath');
      _xrayProcess = await Process.start(
        xrayPath,
        ['run', '-c', configPath],
        workingDirectory: binDir,
        runInShell: false,
      );

      // Listen for process exit
      _xrayProcess?.exitCode.then((code) {
        debugPrint('Xray exited with code $code');
        if (_isConnected) {
          disconnect();
        }
      });
      
      // Set System Proxy
      await _setSystemProxy(true, 10809); // Default HTTP port

      _isConnected = true;
      _statusController.add(true);
      return true;
    } catch (e) {
      debugPrint('Windows connect error: $e');
      await disconnect();
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      _xrayProcess?.kill();
      _xrayProcess = null;
      
      await _setSystemProxy(false, 0);

      _isConnected = false;
      _statusController.add(false);
      return true;
    } catch (e) {
      debugPrint('Windows disconnect error: $e');
      return false;
    }
  }

  Future<bool> isConnected() async {
    return _isConnected;
  }

  Future<void> _setSystemProxy(bool enable, int port) async {
    try {
      if (enable) {
        // Enable proxy
        // Set ProxyServer to 127.0.0.1:port
        // Set ProxyEnable to 1
        await Shell().run('''
reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyServer /t REG_SZ /d "127.0.0.1:$port" /f
reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f
''');
      } else {
        // Disable proxy
        await Shell().run('''
reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
''');
      }
    } catch (e) {
      debugPrint('Error setting system proxy: $e');
    }
  }

  Map<String, dynamic> _generateConfig(ServerNode node) {
    // Basic Xray Config Template with Inbounds and Routing
    final baseConfig = {
      "log": {
        "loglevel": "warning"
      },
      "inbounds": [
        {
          "tag": "socks",
          "port": 10808,
          "protocol": "socks",
          "settings": {
            "auth": "noauth",
            "udp": true,
            "ip": "127.0.0.1"
          },
          "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls"]
          }
        },
        {
          "tag": "http",
          "port": 10809,
          "protocol": "http",
          "settings": {
            "userLevel": 8
          }
        }
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
            "domain": ["geosite:cn"],
            "outboundTag": "direct"
          }
        ]
      },
      "outbounds": [
        // The node config (first outbound)
        node.toV2rayConfig()..['tag'] = 'proxy',
        // Direct outbound
        {
          "protocol": "freedom",
          "tag": "direct"
        },
        // Block outbound
        {
          "protocol": "blackhole",
          "tag": "block"
        }
      ]
    };
    return baseConfig;
  }
}
