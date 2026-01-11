import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Netflix/Premium 风格的动画卡片 - 带呼吸灯效果
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final bool enableHover;
  final bool enableBreathing; // 是否启用呼吸灯
  final Duration animationDuration;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.height,
    this.enableHover = true,
    this.enableBreathing = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _breathingAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    // 悬停动画
    _hoverController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _hoverController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // 呼吸灯动画
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _breathingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );
    
    if (widget.enableBreathing) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enableHover) {
      setState(() => _isHovered = true);
      _hoverController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enableHover) {
      setState(() => _isHovered = false);
      _hoverController.reverse();
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (widget.enableHover) {
      setState(() => _isHovered = false);
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _handleTapDown : null,
      onTapUp: widget.onTap != null ? _handleTapUp : null,
      onTapCancel: widget.onTap != null ? _handleTapCancel : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_hoverController, _breathingController]),
        builder: (context, child) {
          // 呼吸灯强度 (0.0 - 1.0)
          final breathValue = _breathingAnimation.value;
          final glowOpacity = 0.08 + (breathValue * 0.12); // 0.08 - 0.20
          final borderOpacity = 0.15 + (breathValue * 0.25); // 0.15 - 0.40
          
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface,
                    Color.lerp(AppColors.surface, AppColors.surfaceAlt, breathValue * 0.5)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _isHovered
                      ? AppColors.accent.withOpacity(0.6)
                      : AppColors.accent.withOpacity(borderOpacity),
                  width: _isHovered ? 1.5 : 1,
                ),
                boxShadow: [
                  // 呼吸光晕
                  BoxShadow(
                    color: AppColors.accent.withOpacity(glowOpacity),
                    blurRadius: 20 + (breathValue * 10),
                    spreadRadius: -2,
                  ),
                  // 悬停时额外光晕
                  if (_isHovered)
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}
