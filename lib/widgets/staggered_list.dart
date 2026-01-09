import 'package:flutter/material.dart';
import 'fade_in_widget.dart';

/// 交错动画列表
class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Duration animationDuration;
  final ScrollController? controller;
  final EdgeInsets? padding;

  const StaggeredList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 100),
    this.animationDuration = const Duration(milliseconds: 600),
    this.controller,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return FadeInWidget(
          delay: staggerDelay * index,
          duration: animationDuration,
          child: children[index],
        );
      },
    );
  }
}

