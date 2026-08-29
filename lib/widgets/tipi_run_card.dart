import 'package:flutter/material.dart';
import '../models/grocery_run.dart';
import 'tipi_progress_bar.dart';
import 'motion/bouncy_pressable.dart';

class TipiRunCard extends StatelessWidget {
  final GroceryRun run;
  final VoidCallback onTap;

  const TipiRunCard({
    super.key,
    required this.run,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverBudget = run.spent > run.budget;
    
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (run.status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.grey;
        statusText = "Completed";
        statusIcon = Icons.check_circle_outline;
        break;
      case 'active':
        statusColor = const Color(0xFF0D5C2C);
        statusText = "Active Errand";
        statusIcon = Icons.play_circle_outline;
        break;
      case 'draft':
      default:
        statusColor = Colors.blueGrey;
        statusText = "Drafting";
        statusIcon = Icons.edit_note;
        break;
    }

    final cardBorderColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.05);

    final markets = run.items.map((i) => i.market).where((m) => m.isNotEmpty).toSet();
    final marketName = markets.isNotEmpty ? markets.join(", ") : "Davao del Norte";

    return BouncyPressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          run.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.storefront,
                              size: 14,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                marketName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 16,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${run.items.length} ${run.items.length == 1 ? 'item' : 'items'}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        "Spent: ",
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      Text(
                        "₱${run.spent.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isOverBudget ? const Color(0xFFEF4444) : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              
              TipiProgressBar(
                current: run.spent,
                limit: run.budget,
                height: 6,
                showText: false,
              ),
              
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Target Budget: ₱${run.budget.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                  if (run.status == 'active') ...[
                    Text(
                      isOverBudget
                          ? "Over budget by ₱${(run.spent - run.budget).toStringAsFixed(2)}"
                          : "Under budget by ₱${(run.budget - run.spent).toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF0D5C2C),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
