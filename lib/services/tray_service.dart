import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:tray_manager/tray_manager.dart';
import 'platform_service.dart';

/// 系统托盘服务 - 桌面端右下角托盘图标
class TrayService with TrayListener {
  static TrayService? _instance;
  static TrayService get instance => _instance ??= TrayService._();
  
  TrayService._();
  
  VoidCallback? onConnect;
  VoidCallback? onDisconnect;
  VoidCallback? onShowWindow;
  VoidCallback? onQuit;
  
  bool _isConnected = false;
  bool _isInitialized = false;
  
  /// 初始化系统托盘
  Future<void> init({
    VoidCallback? onConnect,
    VoidCallback? onDisconnect,
    VoidCallback? onShowWindow,
    VoidCallback? onQuit,
  }) async {
    if (!PlatformService.instance.supportsTray || _isInitialized) return;
    
    this.onConnect = onConnect;
    this.onDisconnect = onDisconnect;
    this.onShowWindow = onShowWindow;
    this.onQuit = onQuit;
    
    trayManager.addListener(this);
    
    // 设置托盘图标
    await _updateTrayIcon();
    await _updateTrayMenu();
    
    _isInitialized = true;
  }
  
  /// 更新连接状态
  Future<void> updateConnectionStatus(bool isConnected) async {
    if (!PlatformService.instance.supportsTray) return;
    
    _isConnected = isConnected;
    await _updateTrayIcon();
    await _updateTrayMenu();
  }
  
  /// 更新托盘图标
  Future<void> _updateTrayIcon() async {
    // 获取可执行文件所在目录
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    
    String iconPath;
    
    if (Platform.isWindows) {
      iconPath = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'icons', 'app_icon.ico');
      // 如果不存在，尝试 PNG
      if (!await File(iconPath).exists()) {
        iconPath = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'icons', 'app_icon.png');
      }
    } else {
      // Linux/macOS
      iconPath = '$exeDir/data/flutter_assets/assets/icons/app_icon.png';
    }
    
    // 开发模式下尝试使用项目路径
    if (!await File(iconPath).exists()) {
      iconPath = 'assets/icons/app_icon.png';
    }
    
    try {
      if (await File(iconPath).exists()) {
        await trayManager.setIcon(iconPath);
      }
      await trayManager.setToolTip('Flux VPN - ${_isConnected ? "已连接" : "未连接"}');
    } catch (e) {
      debugPrint('[Tray] Set icon error: $e');
    }
  }
  
  /// 更新托盘菜单
  Future<void> _updateTrayMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show',
          label: '显示主窗口',
        ),
        MenuItem.separator(),
        MenuItem(
          key: _isConnected ? 'disconnect' : 'connect',
          label: _isConnected ? '断开连接' : '快速连接',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: '退出',
        ),
      ],
    );
    
    await trayManager.setContextMenu(menu);
  }
  
  @override
  void onTrayIconMouseDown() {
    // 单击显示窗口
    onShowWindow?.call();
  }
  
  @override
  void onTrayIconRightMouseDown() {
    // 右键显示菜单
    trayManager.popUpContextMenu();
  }
  
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        onShowWindow?.call();
        break;
      case 'connect':
        onConnect?.call();
        break;
      case 'disconnect':
        onDisconnect?.call();
        break;
      case 'quit':
        onQuit?.call();
        break;
    }
  }
  
  /// 释放资源
  void dispose() {
    if (_isInitialized) {
      trayManager.removeListener(this);
      trayManager.destroy();
      _isInitialized = false;
    }
  }
}
