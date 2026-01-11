import 'package:flutter/material.dart';
import 'animated_card.dart';

/// Hero动画卡片，用于页面转场
class HeroCard extends StatelessWidget {
  final String heroTag;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final double? width;
  final double? height;

  const HeroCard({
    super.key,
    required this.heroTag,
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      flightShuttleBuilder: (
        BuildContext flightContext,
        Animation<double> animation,
        HeroFlightDirection flightDirection,
        BuildContext fromHeroContext,
        BuildContext toHeroContext,
      ) {
        final Hero toHero = toHeroContext.widget as Hero;
        return RotationTransition(
          turns: animation,
          child: toHero.child,
        );
      },
      child: AnimatedCard(
        onTap: onTap,
        padding: padding,
        width: width,
        height: height,
        child: child,
      ),
    );
  }
}
