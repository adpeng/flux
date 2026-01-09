import 'package:flutter/material.dart';
import '../models/plan.dart';
import '../services/v2board_api.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/animated_card.dart';
import '../widgets/fade_in_widget.dart';
import '../widgets/staggered_list.dart';
import '../widgets/section_header.dart';
import '../widgets/flux_loader.dart';
import 'orders_screen.dart';

class PlansScreen extends StatefulWidget {
  final void Function(Plan plan)? onChoose;
  const PlansScreen({super.key, this.onChoose});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _api = V2BoardApi();
  late Future<List<Plan>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _plansFuture = _loadPlans();
  }

  Future<List<Plan>> _loadPlans() async {
    final data = await _api.getPlans();
    final list = (data['data'] as List? ?? [])
        .map((item) => Plan.fromJson(item as Map<String, dynamic>))
        .toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Plan>>(
      future: _plansFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final err = snapshot.error;
          final message = err is V2BoardApiException ? err.message : '网络开小差了，请稍后重试';
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: const TextStyle(color: AppColors.accentWarm),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _plansFuture = _loadPlans();
                  }),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: FluxLoader());
        }
        final plans = snapshot.data!;
        return StaggeredList(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            FadeInWidget(
              delay: Duration.zero,
              child: SectionHeader(
                title: '选择方案',
                actionLabel: '刷新',
                onAction: () {
                  setState(() {
                    _plansFuture = _loadPlans();
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            ...plans.asMap().entries.map((entry) {
              final plan = entry.value;
              final price = (plan.monthPrice ?? 0) > 0 
                  ? plan.monthPrice! 
                  : (plan.yearPrice ?? 0) > 0 
                      ? plan.yearPrice! 
                      : (plan.onetimePrice ?? 0);
              final priceLabel = (plan.monthPrice ?? 0) > 0 
                  ? '/月' 
                  : (plan.yearPrice ?? 0) > 0 
                      ? '/年' 
                      : '';
                      
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AnimatedCard(
                  onTap: widget.onChoose == null
                      ? null
                      : () async {
                          final result = await Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  OrdersScreen(selectedPlan: plan),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.easeOutCubic;
                                var tween = Tween(begin: begin, end: end).chain(
                                  CurveTween(curve: curve),
                                );
                                return SlideTransition(
                                  position: animation.drive(tween),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 400),
                            ),
                          );
                          if (result == true && widget.onChoose != null) {
                            widget.onChoose!(plan);
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          fontSize: 18,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plan.content ?? '全球优质节点接入',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                              ),
                              child: Text(
                                Formatters.formatBytes(plan.transferEnable),
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '￥',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              Formatters.formatCurrency(price),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            if (priceLabel.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6, left: 4),
                                child: Text(
                                  priceLabel,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                '立即体验',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            // Bottom padding for nav bar
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}
