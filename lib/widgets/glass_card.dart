import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.opacity = 0.1,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBorderRadius = borderRadius ?? BorderRadius.circular(24.0);

    return ClipRRect(
      borderRadius: defaultBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: opacity),
                Colors.white.withValues(alpha: opacity * 0.4),
              ],
            ),
            borderRadius: defaultBorderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
