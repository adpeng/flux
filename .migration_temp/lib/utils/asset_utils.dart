import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AssetUtils {
  /// 将资产文件复制到应用文件目录
  static Future<void> copyAssets() async {
    try {
      final dir = await getApplicationSupportDirectory();
      
      // 确保目录存在
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      await _copyFile('assets/bin/geoip.dat', '${dir.path}/geoip.dat');
      await _copyFile('assets/bin/geosite.dat', '${dir.path}/geosite.dat');
    } catch (e) {
      print('Error copying assets: $e');
    }
  }

  static Future<void> _copyFile(String assetPath, String targetPath) async {
    if (await File(targetPath).exists()) {
      // 可以在这里添加版本检查逻辑，暂时只假设文件存在就不覆盖
      return;
    }

    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(targetPath).writeAsBytes(bytes);
      print('Copied $assetPath to $targetPath');
    } catch (e) {
      print('Failed to copy $assetPath: $e');
    }
  }
}
