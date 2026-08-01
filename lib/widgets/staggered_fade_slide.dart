import 'package:flutter/material.dart';

/// A reusable widget that animates its child with a combined
/// fade-in + slide-up entrance animation.
///
/// Use [delay] to stagger multiple instances for a cascading effect.
/// Use [offset] to control how far the widget slides from.
class StaggeredFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  const StaggeredFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.offset = const Offset(0, 24),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _translation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _translation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curved);

    // Start after delay
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _translation.value,
          child: Opacity(
            opacity: _opacity.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A wrapper that scales down on press for tactile micro-interaction.
class ScaleOnPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const ScaleOnPress({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
  });

  @override
  State<ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends State<ScaleOnPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) async {
        await _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
/// An animated progress bar that smoothly fills to [value].
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double height;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.color = const Color(0xFF0D5C2C),
    this.backgroundColor = const Color(0xFFE5E5E5),
    this.height = 8,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            // Background
            Container(color: backgroundColor),
            // Animated fill
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, animVal, _) {
                return FractionallySizedBox(
                  widthFactor: animVal,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated number that counts up/down to [value].
class AnimatedCount extends StatelessWidget {
  final double value;
  final String prefix;
  final String suffix;
  final int decimals;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCount({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 2,
    this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animVal, _) {
        return Text(
          '$prefix${animVal.toStringAsFixed(decimals)}$suffix',
          style: style,
        );
      },
    );
  }
}

/// Subtle pulse animation for badges or status indicators.
class PulsingWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulsingWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minScale = 0.97,
    this.maxScale = 1.03,
  });

  @override
  State<PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<PulsingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: widget.minScale, end: widget.maxScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// Floating animation — gentle vertical oscillation for empty states.
class FloatingWidget extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration duration;

  const FloatingWidget({
    super.key,
    required this.child,
    this.amplitude = 8.0,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    _translation = Tween<double>(
      begin: -widget.amplitude,
      end: widget.amplitude,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _translation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
