import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/server_node.dart';
import 'platform_service.dart';
import 'v2ray_service.dart';
import 'desktop_proxy_service.dart';

/// 统一 VPN 服务 - 根据平台自动选择合适的实现
class UnifiedVpnService {
  static UnifiedVpnService? _instance;
  static UnifiedVpnService get instance => _instance ??= UnifiedVpnService._();
  
  UnifiedVpnService._();
  
  final _platform = PlatformService.instance;
  final _androidService = V2rayService();
  final _desktopService = DesktopProxyService.instance;
  
  /// 连接状态流
  Stream<bool> get statusStream {
    if (kIsWeb) {
      return Stream.value(false);
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return _androidService.statusStream;
    }
    if (_platform.isDesktop) {
      return _desktopService.statusStream;
    }
    return Stream.value(false);
  }
  
  /// 连接到指定节点
  Future<bool> connect(ServerNode node) async {
    if (kIsWeb) {
      debugPrint('[VPN] Web platform does not support VPN');
      return false;
    }
    
    if (Platform.isAndroid || Platform.isIOS) {
      return _androidService.connect(node);
    }
    
    if (_platform.isDesktop) {
      return _desktopService.connect(node);
    }
    
    // iOS 暂不支持
    debugPrint('[VPN] Platform not supported: ${_platform.platformName}');
    return false;
  }
  
  /// 断开连接
  Future<bool> disconnect() async {
    if (kIsWeb) return false;
    
    if (Platform.isAndroid || Platform.isIOS) {
      return _androidService.disconnect();
    }
    
    if (_platform.isDesktop) {
      return _desktopService.disconnect();
    }
    
    return false;
  }
  
  /// 获取连接状态
  Future<bool> isConnected() async {
    if (kIsWeb) return false;
    
    if (Platform.isAndroid || Platform.isIOS) {
      return _androidService.isConnected();
    }
    
    if (_platform.isDesktop) {
      return _desktopService.isConnected;
    }
    
    return false;
  }
  
  /// 释放资源
  void dispose() {
    if (_platform.isDesktop) {
      _desktopService.dispose();
    }
  }
}
