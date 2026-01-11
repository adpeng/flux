import 'package:flutter/material.dart';
import '../models/plan.dart';
import '../theme/app_colors.dart';
import '../widgets/glow_button.dart';
import '../widgets/gradient_card.dart';


class OrderSuccessScreen extends StatelessWidget {
  final Plan plan;
  final String period;
  final String tradeNo;

  const OrderSuccessScreen({
    super.key,
    required this.plan,
    required this.period,
    required this.tradeNo,
  });

  String _getPeriodLabel(String key) {
    // 简单的映射，保持与 OrdersScreen 一致
    switch (key) {
      case 'month_price': return '按月订阅';
      case 'quarter_price': return '按季订阅';
      case 'half_year_price': return '半年订阅';
      case 'year_price': return '按年订阅';
      case 'two_year_price': return '两年订阅';
      case 'three_year_price': return '三年订阅';
      case 'onetime_price': return '一次性';
      case 'reset_price': return '重置流量包';
      default: return '订阅服务的';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.heroGlow,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 64, // 减去垂直 padding (32*2)
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(),
                          // 成功图标动画
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 80,
                          ),
                          const SizedBox(height: 24),
                          
                          // 标题
                          Text(
                            '支付成功',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '您的订阅服务已开通',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          
                          const SizedBox(height: 48),
                          
                          // 订单详情卡片
                          GradientCard(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.shopping_bag_outlined, color: AppColors.accent, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        '产品信息',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    plan.name,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getPeriodLabel(period),
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 32, color: AppColors.border),
                                  _buildRow('订单号', tradeNo),
                                  const SizedBox(height: 12),
                                  _buildRow('流量', '${plan.transferEnable} GB'),
                                ],
                              ),
                            ),
                          ),
                          
                          const Spacer(),
                          const SizedBox(height: 32),
                          
                          // 返回按钮
                          GlowButton(
                            label: '开始使用',
                            onPressed: () {
                              Navigator.of(context).pop(true); // 返回 true 表示刷新
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
