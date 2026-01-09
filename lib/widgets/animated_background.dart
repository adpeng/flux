import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedMeshBackground extends StatelessWidget {
  final Widget child;
  const AnimatedMeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Simple static background
        Container(color: AppColors.background),
        widget.child,
      ],
    );
  }
}
