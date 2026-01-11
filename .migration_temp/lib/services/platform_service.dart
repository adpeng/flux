import 'dart:io';
import 'package:flutter/foundation.dart';

/// 平台适配层 - 统一检测和处理不同平台
class PlatformService {
  static PlatformService? _instance;
  static PlatformService get instance => _instance ??= PlatformService._();
  
  PlatformService._();
  
  /// 是否是桌面平台 (Windows, macOS, Linux)
  bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }
  
  /// 是否是移动平台 (Android, iOS)
  bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
  
  /// 是否是 Web 平台
  bool get isWeb => kIsWeb;
  
  /// 是否支持 VPN 功能
  bool get supportsVpn {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS || isDesktop;
  }
  
  /// 是否支持系统托盘
  bool get supportsTray {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }
  
  /// 获取当前平台名称
  String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }
  
  /// 获取 xray-core 可执行文件名 (回退用的基础名称)
  String get xrayExecutable {
    if (kIsWeb) return '';
    if (Platform.isWindows) return 'xray-windows-amd64.exe';
    if (Platform.isMacOS) return 'xray-darwin-amd64';
    if (Platform.isLinux) return 'xray-linux-amd64';
    return '';
  }
}
