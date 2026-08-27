import 'package:flutter/material.dart';

class CustomAlert {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    bool isSuccess = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    IconData icon;
    Color textColor = Colors.white;

    if (isError) {
      bgColor = const Color(0xFFC62828); // Crimson
      icon = Icons.error_outline;
    } else if (isSuccess) {
      bgColor = const Color(0xFF1E6B39); // Forest Green
      icon = Icons.check_circle_outline;
    } else {
      bgColor = isDark ? const Color(0xFF2C3530) : const Color(0xFFE8EFE9);
      icon = Icons.info_outline;
      textColor = isDark ? Colors.white : const Color(0xFF0D5C2C);
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgColor,
        margin: const EdgeInsets.all(16),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
