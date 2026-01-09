import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FluxLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const FluxLoader({
    super.key,
    this.size = 40,
    this.color,
  });

  @override
  State<FluxLoader> createState() => _FluxLoaderState();
}

class _FluxLoaderState extends State<FluxLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _FluxPainter(
              animation: _controller,
              color: widget.color ?? AppColors.accent,
            ),
          );
        },
      ),
    );
  }
}

class _FluxPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _FluxPainter({required this.animation, required this.color})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.15;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // Rotate the entire canvas
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animation.value * 2 * math.pi);

    // Draw three arcs with different phases and lengths
    for (int i = 0; i < 3; i++) {
      final double phase = i * (2 * math.pi / 3);
      final double progress = (animation.value + i * 0.33) % 1.0;
      
      // Dynamic length based on sine wave
      final double length = (0.2 + 0.3 * math.sin(progress * 2 * math.pi)).abs() * 2 * math.pi;
      
      // Dynamic opacity
      paint.color = color.withValues(alpha: 0.6 + 0.4 * math.sin(progress * 2 * math.pi));
      
      // Add glow
      paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

      final rect = Rect.fromCircle(center: Offset.zero, radius: radius - strokeWidth / 2);
      canvas.drawArc(rect, phase, length, false, paint);
      
      // Draw inner finer arc
      paint.strokeWidth = strokeWidth * 0.5;
      paint.color = color.withValues(alpha: 0.3);
      final innerRect = Rect.fromCircle(center: Offset.zero, radius: radius * 0.6);
      canvas.drawArc(innerRect, -phase * 1.5, length * 0.8, false, paint);
      
      // Reset stroke for loop
      paint.strokeWidth = strokeWidth;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FluxPainter oldDelegate) => true;
}
