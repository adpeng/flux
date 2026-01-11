import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/server_node.dart';
import 'package:path/path.dart' as path;

/// Hysteria2 Service for Desktop (Windows, macOS, Linux)
/// Android implementation is in MainActivity.kt
class Hysteria2Service {
  static Hysteria2Service? _instance;
  static Hysteria2Service get instance => _instance ??= Hysteria2Service._();
  
  factory Hysteria2Service() => instance;

  Hysteria2Service._();

  Process? _process;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Get the correct executable name based on platform
  String _getExecutableName() {
    if (Platform.isWindows) {
      return 'hysteria-windows-amd64.exe'; // Assuming 64-bit
    } else if (Platform.isMacOS) {
      // Detect architecture
      // For simplicity, defaulting to universal or check via system command?
      // Dart Platform.version contains arch info? 
      // Platform.version: "2.19.6 (stable) (Tue Mar 28 13:41:04 2023 +0000) on "macos_arm64""
      if (Platform.version.contains('arm64')) {
        return 'hysteria-darwin-arm64';
      }
      return 'hysteria-darwin-amd64';
    } else if (Platform.isLinux) {
      return 'hysteria-linux-amd64';
    }
    throw UnsupportedError('Unsupported platform for Hysteria2 Service');
  }

  /// Ensure binary exists in application support directory
  Future<String> _ensureBinary() async {
    final appDir = await getApplicationSupportDirectory();
    final exeName = _getExecutableName();
    final targetFile = File(path.join(appDir.path, exeName));

    if (!await targetFile.exists()) {
      print('[Hysteria2] Binary not found at ${targetFile.path}, copying...');
      
      // 确定平台目录名
      String platformDir;
      if (Platform.isWindows) {
        platformDir = 'windows';
      } else if (Platform.isMacOS) {
        platformDir = 'macos';
      } else {
        platformDir = 'linux';
      }
      
      // 查找源文件路径 (Flutter Desktop 打包结构)
      final exePath = Platform.resolvedExecutable;
      final exeDir = File(exePath).parent.path;
      
      String? sourceDir;
      final possibleDirs = [
        path.join(exeDir, 'data', 'flutter_assets', 'assets', 'bin', platformDir),
        path.join('assets', 'bin', platformDir), // 开发环境
      ];
      
      for (final dir in possibleDirs) {
        if (await Directory(dir).exists()) {
          sourceDir = dir;
          print('[Hysteria2] Found asset dir: $dir');
          break;
        }
      }
      
      if (sourceDir == null) {
        throw Exception('[Hysteria2] Asset directory not found! Tried: $possibleDirs');
      }
      
      final sourceFile = File(path.join(sourceDir, exeName));
      if (!await sourceFile.exists()) {
        throw Exception('[Hysteria2] Binary not found: ${sourceFile.path}');
      }
      
      print('[Hysteria2] Copying from ${sourceFile.path} to ${targetFile.path}');
      await sourceFile.copy(targetFile.path);

      if (!Platform.isWindows) {
        // chmod +x
        await Process.run('chmod', ['+x', targetFile.path]);
      }
    } else {
      print('[Hysteria2] Binary already exists at ${targetFile.path}');
    }
    return targetFile.path;
  }

  /// Generate Hysteria2 Client Config
  String generateConfig(ServerNode node, {int socksPort = 10808, int httpPort = 10809}) {
    final raw = node.rawConfig ?? {};
    final server = node.address;
    final port = node.port;
    final auth = raw['password'] as String? ?? raw['auth'] as String? ?? '';
    final sni = raw['sni'] as String? ?? '';
    final insecure = raw['insecure'] == true || raw['allowInsecure'] == true;
    final obfsType = raw['obfs-type'] as String? ?? 'salamander';
    final obfsPassword = raw['obfs-password'] as String? ?? raw['obfuscation'] as String? ?? '';

    final config = {
      'server': '$server:$port',
      'auth': auth,
      'tls': {
        'sni': sni,
        'insecure': insecure,
      },
      'socks5': {
        'listen': '127.0.0.1:$socksPort',
      },
      'http': {
        'listen': '127.0.0.1:$httpPort',
      },
      'lazy': false, // Ensure immediate connection check
    };

    if (obfsPassword.isNotEmpty) {
      config['obfs'] = {
        'type': obfsType,
        'salamander': {'password': obfsPassword},
      };
    }

    return jsonEncode(config);
  }

  Future<void> start(ServerNode node, {int socksPort = 10808, int httpPort = 10809}) async {
    if (_isRunning) await stop();

    try {
      final binPath = await _ensureBinary();
      final appDir = await getApplicationSupportDirectory();
      final configPath = path.join(appDir.path, 'config_hy2.json');

      final configContent = generateConfig(node, socksPort: socksPort, httpPort: httpPort);
      await File(configPath).writeAsString(configContent);

      print('Starting Hysteria2: $binPath -c $configPath (SOCKS: $socksPort, HTTP: $httpPort)');

      _process = await Process.start(
        binPath,
        ['client', '-c', configPath],
        mode: ProcessStartMode.normal,
        workingDirectory: appDir.path,
      );

      _isRunning = true;

      // Log output
      _process!.stdout.transform(utf8.decoder).listen((line) {
        print('[Hysteria2] $line');
      });
      _process!.stderr.transform(utf8.decoder).listen((line) {
        print('[Hysteria2 Error] $line');
      });

      _process!.exitCode.then((code) {
        print('Hysteria2 exited with code $code');
        _isRunning = false;
        _process = null;
      });

    } catch (e) {
      print('Failed to start Hysteria2: $e');
      _isRunning = false;
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_process != null) {
      _process!.kill();
      _process = null;
    }
    _isRunning = false;
  }
}
