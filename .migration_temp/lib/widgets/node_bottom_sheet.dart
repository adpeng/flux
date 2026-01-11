import 'dart:async';
import 'package:flutter/material.dart';
import '../models/server_node.dart';
import '../utils/node_utils.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_card.dart';

/// 节点选择底部弹窗
class NodeBottomSheet extends StatefulWidget {
  final List<ServerNode> nodes;
  final ServerNode? selectedNode;
  final ScrollController scrollController;
  final ValueChanged<ServerNode> onNodeSelected;

  const NodeBottomSheet({
    super.key,
    required this.nodes,
    required this.selectedNode,
    required this.scrollController,
    required this.onNodeSelected,
  });

  @override
  State<NodeBottomSheet> createState() => _NodeBottomSheetState();
}

class _NodeBottomSheetState extends State<NodeBottomSheet> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // 每秒检查一次节点延迟更新
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          // 触发重建以显示最新的延迟数据
        });
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, // Use AppColors default surface
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '选择节点',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '${widget.nodes.length} 个可用',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white10),

          // 节点列表
          Flexible(
            child: ListView.separated(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: widget.nodes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final node = widget.nodes[index];
                final isSelected = node == widget.selectedNode;
                final country = NodeUtils.extractCountry(node.name);

                return GradientCard(
                  padding: EdgeInsets.zero, // Remove default padding for InkWell
                  borderRadius: 16,
                  child: InkWell(
                    onTap: () {
                      widget.onNodeSelected(node);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // 选中指示器
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.textSecondary.withValues(alpha: 0.5),
                                width: 2,
                              ),
                              color: isSelected ? AppColors.accent : Colors.transparent,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 14, color: Colors.black)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          
                          // 国家名称
                          Expanded(
                            child: Text(
                              country,
                              style: TextStyle(
                                color: isSelected ? AppColors.accent : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          
                          // 延迟标签
                          _buildLatencyBadge(node.latency),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 底部安全区域
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildLatencyBadge(int? latency) {
    if (latency == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '未测试',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    Color color;
    if (latency < 100) {
      color = AppColors.success;
    } else if (latency < 300) {
      color = AppColors.warning; 
    } else {
      color = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '${latency}ms',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // Helper colors if AppColors doesn't have warning/danger exposed directly
  // Assuming AppColors has accentWarm for warning-ish tone. 
  // If not, we can rely on standard Colors.
}
