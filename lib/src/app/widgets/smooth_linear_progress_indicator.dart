import 'package:flutter/material.dart';

class SmoothLinearProgressIndicator extends StatelessWidget {
  const SmoothLinearProgressIndicator({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 350),
    this.minHeight,
    this.backgroundColor,
    this.color,
  });

  final double? value;
  final Duration duration;
  final double? minHeight;
  final Color? backgroundColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final target = value;
    if (target == null) {
      return LinearProgressIndicator(
        minHeight: minHeight,
        backgroundColor: backgroundColor,
        color: color,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target.clamp(0, 1)),
      duration: duration,
      curve: Curves.linear,
      builder: (context, animatedValue, _) {
        return LinearProgressIndicator(
          value: animatedValue,
          minHeight: minHeight,
          backgroundColor: backgroundColor,
          color: color,
        );
      },
    );
  }
}
