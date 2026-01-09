import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Simplified Card without animations
class AnimatedCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final bool enableHover; // Kept for API compatibility but unused
  final Duration animationDuration; // Kept for API compatibility but unused

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.height,
    this.enableHover = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16), // Slightly less rounded
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}
