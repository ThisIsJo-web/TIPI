import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/grocery_run_item.dart';
import 'motion/bouncy_pressable.dart';

class CommodityChecklistTile extends StatefulWidget {
  final GroceryRunItem item;
  final ValueChanged<bool?> onChecked;
  final VoidCallback onTapEdit;
  final VoidCallback onDelete;

  const CommodityChecklistTile({
    super.key,
    required this.item,
    required this.onChecked,
    required this.onTapEdit,
    required this.onDelete,
  });

  @override
  State<CommodityChecklistTile> createState() => _CommodityChecklistTileState();
}

class _CommodityChecklistTileState extends State<CommodityChecklistTile> with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeInOutCubic,
    );

    if (widget.item.checked) {
      _checkController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant CommodityChecklistTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.checked != oldWidget.item.checked) {
      if (widget.item.checked) {
        _checkController.forward();
      } else {
        _checkController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemTotal = widget.item.price * widget.item.quantity;

    return Dismissible(
      key: Key('checklist_item_${widget.item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        await HapticFeedback.vibrate();
        return true;
      },
      onDismissed: (_) => widget.onDelete(),
      child: BouncyPressable(
        onTap: widget.onTapEdit,
        child: Card(
          margin: EdgeInsets.zero,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Row(
              children: [
                // Tactile check box with drawing animation
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onChecked(!widget.item.checked);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: AnimatedBuilder(
                      animation: _checkAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              Colors.transparent,
                              const Color(0xFF0D5C2C),
                              _checkAnimation.value,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color.lerp(
                                isDark ? Colors.white30 : Colors.black38,
                                const Color(0xFF0D5C2C),
                                _checkAnimation.value,
                              )!,
                              width: 2,
                            ),
                          ),
                          child: _checkAnimation.value > 0
                              ? CustomPaint(
                                  painter: CheckmarkPainter(
                                    progress: _checkAnimation.value,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ),
                
                // Commodity Info with animated line-through
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _checkAnimation,
                        builder: (context, child) {
                          return Stack(
                            children: [
                              Text(
                                widget.item.commodity,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color.lerp(
                                    isDark ? Colors.white : Colors.black87,
                                    isDark ? Colors.white38 : Colors.black38,
                                    _checkAnimation.value,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 11, // Vertically aligns line-through
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _checkAnimation.value,
                                  child: Container(
                                    height: 2.0,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${widget.item.market} • ₱${widget.item.price.toStringAsFixed(2)} / ${widget.item.unit}",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quantity and Total with vertical sliding counters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.4),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                            child: FadeTransition(opacity: animation, child: child),
                          );
                        },
                        child: Text(
                          "₱${itemTotal.toStringAsFixed(2)}",
                          key: ValueKey("total_${widget.item.id}_${itemTotal.toStringAsFixed(2)}"),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? (widget.item.checked ? Colors.white38 : Colors.white)
                                : (widget.item.checked ? Colors.black38 : Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.4),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          },
                          child: Text(
                            "Qty: ${widget.item.quantity.toStringAsFixed(1)} ${widget.item.unit}",
                            key: ValueKey("qty_${widget.item.id}_${widget.item.quantity.toStringAsFixed(1)}"),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit Button indicator
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Checkmark path drawing custom painter (60-120fps physics)
class CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    // Checkmark standard vector offsets:
    // Left start to mid tip, then mid tip to right finish.
    final start = Offset(size.width * 0.26, size.height * 0.5);
    final mid = Offset(size.width * 0.44, size.height * 0.68);
    final end = Offset(size.width * 0.74, size.height * 0.32);

    if (progress > 0) {
      path.moveTo(start.dx, start.dy);
      
      const segment1Length = 0.4;
      if (progress <= segment1Length) {
        final ratio = progress / segment1Length;
        path.lineTo(
          start.dx + (mid.dx - start.dx) * ratio,
          start.dy + (mid.dy - start.dy) * ratio,
        );
      } else {
        path.lineTo(mid.dx, mid.dy);
        
        final ratio = (progress - segment1Length) / (1.0 - segment1Length);
        path.lineTo(
          mid.dx + (end.dx - mid.dx) * ratio,
          mid.dy + (end.dy - mid.dy) * ratio,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
