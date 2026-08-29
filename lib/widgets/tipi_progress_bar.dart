import 'package:flutter/material.dart';

class TipiProgressBar extends StatelessWidget {
  final double current;
  final double limit;
  final double height;
  final bool showText;

  const TipiProgressBar({
    super.key,
    required this.current,
    required this.limit,
    this.height = 10,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = limit > 0 ? (current / limit).clamp(0.0, 1.0) : 0.0;
    final isExceeded = current > limit;
    
    // Smooth transition between colors based on threshold
    Color progressColor;
    if (isExceeded) {
      progressColor = const Color(0xFFEF4444); // Vivid Red
    } else if (ratio >= 0.85) {
      progressColor = const Color(0xFFD97706); // Warm Amber
    } else {
      progressColor = const Color(0xFF0D5C2C); // Fresh Botanical Green
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showText) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Budget Spent",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              Text(
                "₱${current.toStringAsFixed(2)} / ₱${limit.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            // Background Track
            Container(
              height: height,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            // Progress Fill
            FractionallySizedBox(
              widthFactor: ratio,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: height,
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(height / 2),
                  boxShadow: ratio > 0
                      ? [
                          BoxShadow(
                            color: progressColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
