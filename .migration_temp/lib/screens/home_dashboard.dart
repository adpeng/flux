import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice.dart';
import '../services/v2board_api.dart';
import '../theme/app_colors.dart';
import 'invite_screen.dart';
import '../widgets/fade_in_widget.dart';
import 'dart:math' as math;
import 'dart:ui'; // Required for ImageFilter

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

class _HomeDashboardState extends State<HomeDashboard>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOutSine,
      ),
    );
    
    // 延迟检查公告
    Future.delayed(const Duration(seconds: 1), _checkNotice);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.isConnecting;
    final showPulse = true; // 开启呼吸动画
    
    return FadeInWidget(
      delay: const Duration(milliseconds: 200),
      duration: const Duration(milliseconds: 800),
      offset: const Offset(0, 30),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulse, _glowController]),
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_pulse.value);
              final glowT = _glowAnimation.value;
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 连接按钮容器
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        // 主阴影
                        BoxShadow(
                          color: AppColors.accent.withValues(
                            alpha: isBusy ? 0.4 : (0.2 + 0.3 * t),
                          ),
                          blurRadius: isBusy ? 40 : (35 + 25 * t),
                          spreadRadius: isBusy ? 3 : (1 + 2 * t),
                          offset: const Offset(0, 15),
                        ),
                        // 光晕效果
                        if (showPulse)
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.15 * t),
                            blurRadius: 60 + 40 * t,
                            spreadRadius: 8 * t,
                            offset: const Offset(0, 10),
                          ),
                        // 动态光晕
                        BoxShadow(
                          color: AppColors.accent.withValues(
                            alpha: 0.1 * (0.5 + 0.5 * math.sin(glowT * math.pi * 2)),
                          ),
                          blurRadius: 50,
                          spreadRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 柔和静态光晕，不做缩放
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.accent.withValues(alpha: 0.12),
                                AppColors.accent.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                        // 主按钮
                        Transform.scale(
                          scale: 1.0,
                          child: _buildHeroButton(t, glowT),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 状态文本 - 带打字机效果
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      widget.statusMessage,
                      key: ValueKey(widget.statusMessage),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isBusy 
                            ? AppColors.accent 
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 服务优势展示
                  const SizedBox(height: 40),
                  _buildFeatureRow(context),
                  const SizedBox(height: 24),
                  _buildInviteBanner(context),
                  // const SizedBox(height: 16),
                  // _buildRedeemButton(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeatureRow(BuildContext context) {
    // 使用 LayoutBuilder 响应式布局：桌面端 4 列，移动端 2 列
    return LayoutBuilder(
      builder: (context, constraints) {
        // 简单判断：如果宽度大于 600 则视为桌面/宽屏
        final isDesktop = constraints.maxWidth > 600;
        final crossAxisCount = isDesktop ? 4 : 2;
        final childAspectRatio = isDesktop ? 2.5 : 2.4;

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
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
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

  Widget _buildHeroButton(double t, double glowT) {
    final isBusy = widget.isConnecting;
    final label = widget.isConnected ? '断开' : (isBusy ? '连接中' : '连接');
    final icon = widget.isConnected ? Icons.power : Icons.power_settings_new;

    return GestureDetector(
      onTap: isBusy ? null : widget.onConnectPressed,
      child: SizedBox(
        width: 240,
        height: 68,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: widget.isConnected
                  ? const [Color(0xFF343A43), Color(0xFF1A1D23)]
                  : const [Color(0xFF2F3540), Color(0xFF12151B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.55),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.42),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 柔和的银色光带，保持静态质感
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // 轻微呼吸感，但不改变尺寸
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, _) {
                    final glow =
                        0.06 + 0.04 * math.sin(_glowAnimation.value * math.pi * 2);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: glow),
                            Colors.transparent,
                          ],
                          radius: 0.9,
                          center: Alignment.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              // 状态指示点
              Positioned(
                right: 16,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.isConnected
                          ? [const Color(0xFF6CFFB8), AppColors.accent]
                          : (isBusy
                              ? [const Color(0xFFFFE18D), const Color(0xFFFFB347)]
                              : [AppColors.accent, const Color(0xFF6F7A8C)]),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isConnected
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkNotice() async {
    try {
      final api = V2BoardApi();
      final response = await api.fetchNotice();
      final data = response['data'] as List<dynamic>?;
      
      if (data == null || data.isEmpty) return;
      
      // 取最新的一条公告
      final latestNotice = Notice.fromJson(data.first as Map<String, dynamic>);
      
      final prefs = await SharedPreferences.getInstance();
      final lastReadId = prefs.getInt('last_read_notice_id') ?? 0;
      
      if (latestNotice.id > lastReadId) {
        if (!mounted) return;
        _showNoticeDialog(latestNotice);
      }
    } catch (e) {
      debugPrint('Fetching notice failed: $e');
    }
  }

  Widget _buildInviteBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const InviteScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.2),
              AppColors.accent.withValues(alpha: 0.05),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.card_giftcard,
                color: AppColors.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '邀请好友赚取佣金',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '分享邀请码，获取高额返利',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDialog(Notice notice) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox(); // 这里的 builder 不重要，主要看 transitionBuilder
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // 使用弹簧曲线
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: LogNoticeDialog(notice: notice),
            ),
          ),
        );
      },
    );
  }

}

class LogNoticeDialog extends StatelessWidget {
  final Notice notice;

  const LogNoticeDialog({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: AppColors.accent.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
            border: Border.all(
              color: AppColors.accent.withOpacity(0.2),
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头部图片或装饰
              if (notice.imgUrl != null && notice.imgUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.network(
                    notice.imgUrl!,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 20),
                  ),
                )
              else
                 Padding(
                   padding: const EdgeInsets.only(top: 24, bottom: 8),
                   child: Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: AppColors.accent.withOpacity(0.1),
                       shape: BoxShape.circle,
                     ),
                     child: const Icon(
                       Icons.notifications_active_rounded,
                       size: 32,
                       color: AppColors.accent,
                     ),
                   ),
                 ),

              // 标题和内容
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Text(
                      notice.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Text(
                          notice.content,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 按钮
                    GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('last_read_notice_id', notice.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent,
                              AppColors.accent.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '我知道了',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
