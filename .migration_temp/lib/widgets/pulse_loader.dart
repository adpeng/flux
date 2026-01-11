import 'package:flutter/material.dart';
import 'flux_loader.dart';

/// 统一使用 FluxLoader，保持动画风格一致
class PulseLoader extends StatelessWidget {
  final double size;
  const PulseLoader({super.key, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return FluxLoader(size: size * 3);
  }
}
