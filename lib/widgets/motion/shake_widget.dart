import 'package:flutter/material.dart';

class ShakeWidget extends StatefulWidget {
  final Widget child;
  final double shakeRange;
  final Duration duration;
  final dynamic trigger;

  const ShakeWidget({
    super.key,
    required this.child,
    this.shakeRange = 8.0,
    this.duration = const Duration(milliseconds: 350),
    this.trigger,
  });

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Sequence of offsets to simulate a decaying spring shake (60-120fps)
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),      // quick push right
      TweenSequenceItem(tween: Tween(begin: 1.0, end: -0.85), weight: 2),   // bounce far left
      TweenSequenceItem(tween: Tween(begin: -0.85, end: 0.65), weight: 2),  // bounce right
      TweenSequenceItem(tween: Tween(begin: 0.65, end: -0.45), weight: 2),  // bounce left
      TweenSequenceItem(tween: Tween(begin: -0.45, end: 0.25), weight: 2),  // settle right
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.0), weight: 1),    // home
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutQuad,
    ));
  }

  @override
  void didUpdateWidget(covariant ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value * widget.shakeRange, 0.0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
