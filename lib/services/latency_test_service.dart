import 'dart:io';
import '../models/server_node.dart';

/// 延迟测试服务
class LatencyTestService {
  /// 测试单个节点的延迟
  Future<int?> testLatency(ServerNode node, {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      final socket = await Socket.connect(
        node.address,
        node.port,
        timeout: timeout,
      ).timeout(timeout);
      
      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;
      
      await socket.close();
      
      return latency;
    } catch (e) {
      // 连接失败，返回null表示超时或不可达
      return null;
    }
  }

  /// 批量测试节点延迟
  Future<void> testNodesLatency(List<ServerNode> nodes, {
    Function(ServerNode, int?)? onProgress,
  }) async {
    for (var node in nodes) {
      final latency = await testLatency(node);
      node.latency = latency;
      
      if (onProgress != null) {
        onProgress(node, latency);
      }
    }
  }

  /// 找到延迟最低的节点
  ServerNode? findBestNode(List<ServerNode> nodes) {
    if (nodes.isEmpty) return null;
    
    // 过滤掉延迟为null的节点
    final validNodes = nodes.where((node) => node.latency != null).toList();
    
    if (validNodes.isEmpty) return null;
    
    // 按延迟排序，返回最低延迟的节点
    validNodes.sort((a, b) => (a.latency ?? 999999).compareTo(b.latency ?? 999999));
    
    return validNodes.first;
  }
}
