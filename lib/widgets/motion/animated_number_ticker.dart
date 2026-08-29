import 'package:flutter/material.dart';

class AnimatedNumberTicker extends StatelessWidget {
  final double value;
  final TextStyle style;
  final String prefix;
  final Duration duration;

  const AnimatedNumberTicker({
    super.key,
    required this.value,
    required this.style,
    this.prefix = "₱",
    this.duration = const Duration(milliseconds: 350),
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(
        "$prefix${value.toStringAsFixed(2)}",
        style: style,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          "$prefix${animatedValue.toStringAsFixed(2)}",
          style: style,
        );
      },
    );
  }
}
