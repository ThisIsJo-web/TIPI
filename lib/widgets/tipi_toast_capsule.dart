import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TipiToastCapsule extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color tintColor;
  final VoidCallback onDismiss;

  const TipiToastCapsule({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.tintColor,
    required this.onDismiss,
  });

  @override
  State<TipiToastCapsule> createState() => _TipiToastCapsuleState();
}

class _TipiToastCapsuleState extends State<TipiToastCapsule> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _springController;
  late Animation<double> _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _springAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final threshold = MediaQuery.of(context).size.width * 0.35;
    if (_dragOffset.abs() > threshold) {
      // Swipe-dismiss velocity/distance reached, animate out
      final target = _dragOffset > 0 ? MediaQuery.of(context).size.width : -MediaQuery.of(context).size.width;
      
      _springAnimation = Tween<double>(
        begin: _dragOffset,
        end: target,
      ).animate(
        CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
      )..addListener(() {
          setState(() {
            _dragOffset = _springAnimation.value;
          });
        });

      _springController.forward(from: 0.0).then((_) {
        widget.onDismiss();
      });
    } else {
      // Spring back to center (0.0)
      _springAnimation = Tween<double>(
        begin: _dragOffset,
        end: 0.0,
      ).animate(
        CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
      )..addListener(() {
          setState(() {
            _dragOffset = _springAnimation.value;
          });
        });
      _springController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = (1.0 - (_dragOffset.abs() / MediaQuery.of(context).size.width)).clamp(0.0, 1.0);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Transform.translate(
        offset: Offset(_dragOffset, 0.0),
        child: Opacity(
          opacity: opacity,
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.black.withOpacity(0.6) 
                        : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: widget.tintColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.tintColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.tintColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.message,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ).animate().slideY(
            begin: -1.5,
            end: 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
          ).fade(duration: const Duration(milliseconds: 200)),
    );
  }
}
