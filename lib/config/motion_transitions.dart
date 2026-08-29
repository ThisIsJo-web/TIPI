import 'package:flutter/material.dart';

class TipiPageRouteBuilder extends PageRouteBuilder {
  final Widget page;

  TipiPageRouteBuilder({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.disableAnimationsOf(context)) {
              return child;
            }

            // Upward slide animation (Material 3 Shared Axis transition style)
            final slideTween = Tween<Offset>(
              begin: const Offset(0.0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            // Fade animation (snappy entrance)
            final fadeTween = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
            ));

            // Scale animation (subtle expanding feeling)
            final scaleTween = Tween<double>(
              begin: 0.98,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            return FadeTransition(
              opacity: fadeTween,
              child: SlideTransition(
                position: slideTween,
                child: ScaleTransition(
                  scale: scaleTween,
                  child: child,
                ),
              ),
            );
          },
        );
}
