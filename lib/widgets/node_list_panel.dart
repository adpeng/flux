import 'package:flutter/material.dart';
import '../models/server_node.dart';
import '../utils/node_utils.dart';

/// 节点列表面板组件
class NodeListPanel extends StatefulWidget {
  final List<ServerNode> nodes;
  final ServerNode? selectedNode;
  final ValueChanged<ServerNode> onNodeSelected;
  final bool isExpanded;
  final VoidCallback onToggle;

  const NodeListPanel({
    super.key,
    required this.nodes,
    required this.selectedNode,
    required this.onNodeSelected,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<NodeListPanel> createState() => _NodeListPanelState();
}

class _NodeListPanelState extends State<NodeListPanel> {
  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 面板头部 - 改进点击区域和样式
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.list,
                          color: Colors.blueAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '节点列表',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.87),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.nodes.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: widget.isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 可展开的列表内容 - 使用更自然的动画
        ClipRect(
          child: AnimatedAlign(
            heightFactor: widget.isExpanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: widget.isExpanded
                  ? ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: widget.nodes.length,
                      itemBuilder: (context, index) {
                        final node = widget.nodes[index];
                        final isSelected = node == widget.selectedNode;
                        final country = NodeUtils.extractCountry(node.name);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => widget.onNodeSelected(node),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.greenAccent.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.greenAccent.withValues(alpha: 0.4),
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // 选中指示器
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.greenAccent
                                          : Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 国家名称
                                  Expanded(
                                    child: Text(
                                      country,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.greenAccent
                                            : Colors.white.withValues(alpha: 0.87),
                                        fontWeight:
                                            isSelected ? FontWeight.w600 : FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  // 延迟标签
                                  if (node.latency != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (node.latency! < 100
                                                ? Colors.greenAccent
                                                : node.latency! < 300
                                                    ? Colors.orangeAccent
                                                    : Colors.redAccent)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${node.latency}ms',
                                        style: TextStyle(
                                          color: node.latency! < 100
                                              ? Colors.greenAccent
                                              : node.latency! < 300
                                                  ? Colors.orangeAccent
                                                  : Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '未测试',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
