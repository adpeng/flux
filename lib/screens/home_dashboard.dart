import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/fade_in_widget.dart';

class HomeDashboard extends StatefulWidget {
  final VoidCallback onConnectPressed;
  final bool isConnected;
  final bool isConnecting;
  final String statusMessage;

  const HomeDashboard({
    super.key,
    required this.onConnectPressed,
    required this.isConnected,
    this.isConnecting = false,
    this.statusMessage = '未连接',
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  // Removed AnimationControllers

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.isConnecting;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Connection Button Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // Simple static decoration
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildHeroButton(),
            ),
            const SizedBox(height: 24),
            // Status Text - Simple switch
            Text(
              widget.statusMessage,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isBusy ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Services Grid
            const SizedBox(height: 40),
            _buildFeatureRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context) {
    // Responsive grid
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 600;
        final crossAxisCount = isDesktop ? 4 : 2;
        final childAspectRatio = isDesktop ? 2.5 : 2.8;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            _buildFeatureTile(Icons.hub_rounded, 'IXP 接入', '极速分流'),
            _buildFeatureTile(Icons.speed_rounded, '高速稳定', '4K 秒开'),
            _buildFeatureTile(Icons.security_rounded, '安全日志', '隐私保护'),
            _buildFeatureTile(Icons.lock_rounded, '强力加密', 'AES-256'),
          ],
        );
      },
    );
  }

  Widget _buildFeatureTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroButton() {
    final isBusy = widget.isConnecting;
    final label = widget.isConnected ? '断开' : (isBusy ? '连接中' : '连接');
    final icon = widget.isConnected ? Icons.power : Icons.power_settings_new;

    return GestureDetector(
      onTap: isBusy ? null : widget.onConnectPressed,
      child: Container(
        width: 200,
        height: 60,
        decoration: BoxDecoration(
          color: widget.isConnected ? AppColors.surface : AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
             color: widget.isConnected ? AppColors.border : Colors.transparent,
          )
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: widget.isConnected ? AppColors.textPrimary : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: widget.isConnected ? AppColors.textPrimary : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
