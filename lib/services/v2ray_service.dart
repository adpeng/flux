import 'dart:io';

import 'package:flutter/services.dart';
import '../models/server_node.dart';
import 'dart:convert';
import 'v2ray_service_windows.dart';

/// V2ray服务 - 通过MethodChannel与Android端通信
class V2rayService {
  static const MethodChannel _channel = MethodChannel('com.flux.app/v2ray');
  static const EventChannel _statusChannel =
      EventChannel('com.flux.app/v2ray_status');
  static Stream<bool>? _statusStream;

  Stream<bool> get statusStream {
    if (Platform.isWindows) {
      return V2rayServiceWindows().statusStream;
    }
    return _statusStream ??=
        _statusChannel.receiveBroadcastStream().map((event) {
      if (event is bool) return event;
      return event == true;
    });
  }

  /// 连接到指定节点
  Future<bool> connect(ServerNode node) async {
    if (Platform.isWindows) {
      return await V2rayServiceWindows().connect(node);
    }
    try {
      final config = node.toV2rayConfig();
      final result = await _channel.invokeMethod<bool>(
        'connect',
        {'config': jsonEncode(config)},
      );
      return result ?? false;
    } on PlatformException catch (_) {

      return false;
    }
  }

  /// 断开连接
  Future<bool> disconnect() async {
    if (Platform.isWindows) {
      return await V2rayServiceWindows().disconnect();
    }
    try {
      final result = await _channel.invokeMethod<bool>('disconnect');
      return result ?? false;
    } on PlatformException catch (_) {

      return false;
    }
  }

  /// 获取连接状态
  Future<bool> isConnected() async {
    if (Platform.isWindows) {
      return await V2rayServiceWindows().isConnected();
    }
    try {
      final result = await _channel.invokeMethod<bool>('isConnected');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
