import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedMeshBackground extends StatefulWidget {
  final Widget child;
  const AnimatedMeshBackground({super.key, required this.child});

  @override
  State<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<AnimatedMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark background base
        Container(color: AppColors.background),
        // Animated Mesh
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _MeshPainter(
                animationValue: _controller.value,
                primaryColor: AppColors.accent,
                secondaryColor: AppColors.surface,
              ),
              size: Size.infinite,
            );
          },
        ),
        // Glass overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.1),
                AppColors.background.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final Color secondaryColor;

  _MeshPainter({
    required this.animationValue,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Generate organic blobs
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    void drawBlob(Offset center, double radius, Color color, double phase) {
      final offset = Offset(
        math.sin(animationValue * 2 * math.pi + phase) * 40,
        math.cos(animationValue * 2 * math.pi + phase) * 40,
      );
      paint.color = color;
      canvas.drawCircle(center + offset, radius, paint);
    }

    // 纯灰色光晕（无蓝调）
    // 右上角光晕
    drawBlob(
      Offset(size.width * 0.8, size.height * 0.2),
      200,
      const Color(0xFF808080).withValues(alpha: 0.08),
      0,
    );

    // 左下角光晕
    drawBlob(
      Offset(size.width * 0.2, size.height * 0.8),
      250,
      const Color(0xFF606060).withValues(alpha: 0.06),
      math.pi,
    );
    
    // 中心微光
    drawBlob(
      Offset(size.width * 0.5, size.height * 0.5),
      300,
      const Color(0xFF505050).withValues(alpha: 0.04),
      math.pi / 2,
    );
  }

  @override
  bool shouldRepaint(_MeshPainter oldDelegate) => true;
}
