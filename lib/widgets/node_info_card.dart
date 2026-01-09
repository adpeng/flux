import 'package:flutter/material.dart';
import '../models/server_node.dart';
import '../utils/node_utils.dart';

/// 节点信息卡片组件
class NodeInfoCard extends StatelessWidget {
  final ServerNode node;

  const NodeInfoCard({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16), // 增加内边距从14到16
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.greenAccent.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    NodeUtils.extractCountry(node.name),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white, // 提高对比度，移除opacity
                    ),
                  ),
                ),
              ],
            ),
            if (node.latency != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.speed,
                      size: 16,
                      color: node.latency! < 100
                          ? Colors.greenAccent
                          : node.latency! < 300
                              ? Colors.orangeAccent
                              : Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${node.latency}ms',
                      style: TextStyle(
                        fontSize: 14,
                        color: node.latency! < 100
                            ? Colors.greenAccent
                            : node.latency! < 300
                                ? Colors.orangeAccent
                                : Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

