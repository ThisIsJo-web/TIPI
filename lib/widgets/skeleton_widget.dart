import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// A premium shimmer skeleton loader with a gradient sweep animation.
class SkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.margin,
  });

  @override
  State<SkeletonWidget> createState() => _SkeletonWidgetState();
}

class _SkeletonWidgetState extends State<SkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDarkMode.value;
    final baseColor = isDark ? const Color(0xFF16221E) : const Color(0xFFE8EBE8);
    final highlightColor = isDark ? const Color(0xFF22312C) : const Color(0xFFF4F6F4);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1.0, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
