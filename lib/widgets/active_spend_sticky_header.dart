import 'package:flutter/material.dart';
import 'motion/animated_number_ticker.dart';

class ActiveSpendStickyHeader extends StatelessWidget {
  final double budget;
  final double spent;
  final int totalItems;
  final int checkedItems;

  const ActiveSpendStickyHeader({
    super.key,
    required this.budget,
    required this.spent,
    required this.totalItems,
    required this.checkedItems,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverBudget = spent > budget;
    final remaining = budget - spent;
    final progress = totalItems > 0 ? checkedItems / totalItems : 0.0;

    // Determine colors
    Color statusBgColor;
    Color statusTextColor;
    String statusMsg;

    if (isOverBudget) {
      statusBgColor = const Color(0xFFFEF2F2); // soft red
      statusTextColor = const Color(0xFFDC2626); // red text
      statusMsg = "Exceeded budget by ₱${(spent - budget).toStringAsFixed(2)}!";
    } else if (remaining < (budget * 0.15)) {
      statusBgColor = const Color(0xFFFFFBEB); // soft amber
      statusTextColor = const Color(0xFFD97706); // amber text
      statusMsg = "Approaching budget ceiling!";
    } else {
      statusBgColor = const Color(0xFFF0FDF4); // soft green
      statusTextColor = const Color(0xFF15803D); // green text
      statusMsg = "You are currently within your budget.";
    }

    // Adjust status background for dark mode
    if (isDark) {
      if (isOverBudget) {
        statusBgColor = const Color(0xFF450A0A);
      } else if (remaining < (budget * 0.15)) {
        statusBgColor = const Color(0xFF451A03);
      } else {
        statusBgColor = const Color(0xFF064E3B);
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row containing Spent & Remaining figures
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: "SPENT SO FAR",
                  value: spent,
                  valueColor: isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF0D5C2C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: isOverBudget ? "BUDGET OVER" : "BUDGET REMAINING",
                  value: remaining.abs(),
                  valueColor: isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF0D5C2C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress bar of items checked off
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    color: const Color(0xFF0D5C2C),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "$checkedItems / $totalItems items",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action message container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isOverBudget
                      ? Icons.warning_amber_rounded
                      : (remaining < (budget * 0.15) ? Icons.info_outline : Icons.check_circle_outline),
                  size: 16,
                  color: statusTextColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMsg,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String label,
    required double value,
    required Color valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.black45,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedNumberTicker(
            value: value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
