import 'package:flutter/material.dart';
import '../../services/grocery_run_service.dart';
import '../../widgets/staggered_fade_slide.dart';
import '../../services/theme_service.dart';
import 'dart:async';

class HistoryTab extends StatefulWidget {
  final String? userId;

  const HistoryTab({super.key, this.userId});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _runService = GroceryRunService.instance;
  List<Map<String, dynamic>> _completedRuns = [];
  bool _isLoading = true;
  StreamSubscription<void>? _runSubscription;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _runSubscription = _runService.onRunUpdated.listen((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _runSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final allRuns = await _runService.getRuns(widget.userId);
    final completed = allRuns.where((r) => r['status'] == 'completed').toList();
    if (mounted) {
      setState(() {
        _completedRuns = completed;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRun(String runId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete from History?'),
        content: const Text('This will permanently delete this completed run record.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _runService.deleteRun(runId, userId: widget.userId);
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = ThemeService.instance.background;
    final cardBg = ThemeService.instance.cardBg;
    final greenColor = ThemeService.instance.greenText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          'Runs History',
          style: TextStyle(color: greenColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: greenColor))
          : _completedRuns.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: greenColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _completedRuns.length,
                    itemBuilder: (context, index) {
                      final run = _completedRuns[index];
                      return StaggeredFadeSlide(
                        delay: Duration(milliseconds: index * 80),
                        child: _buildCompletedRunCard(run),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final greenColor = ThemeService.instance.greenText;
    final textThemeColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: StaggeredFadeSlide(
          delay: const Duration(milliseconds: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingWidget(
                amplitude: 6,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: greenColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history,
                    color: greenColor,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Completed Runs Yet',
                style: TextStyle(color: textThemeColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your grocery shopping runs in active shopping mode to see your purchase history here.',
                style: TextStyle(color: subText, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedRunCard(Map<String, dynamic> run) {
    final String runId = run['id'] ?? '';
    final String name = run['name'] ?? 'Grocery Run';
    final double budget = (run['budget'] as num? ?? 0.0).toDouble();
    final double spent = (run['spent'] as num? ?? 0.0).toDouble();
    final double saved = budget - spent;
    final bool didSave = saved > 0;

    // Date formatting fallback
    String dateStr = 'Completed';
    try {
      if (run['created_at'] != null) {
        final parsed = DateTime.parse(run['created_at']);
        dateStr = '${parsed.month}/${parsed.day}/${parsed.year}';
      }
    } catch (_) {}

    final cardBg = ThemeService.instance.cardBg;
    final textThemeColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final isDark = ThemeService.instance.isDarkMode.value;

    final savedBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFE2F0D9);
    final savedText = isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C2C);
    final overBg = isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50;
    final overText = isDark ? Colors.red.shade300 : Colors.red.shade700;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ScaleOnPress(
        scaleDown: 0.97,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textThemeColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(color: subText, fontSize: 12),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: subText, size: 20),
                      onPressed: () => _deleteRun(runId),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Spent', style: TextStyle(color: subText, fontSize: 11)),
                        const SizedBox(height: 2),
                        // Animated count-up
                        AnimatedCount(
                          value: spent,
                          prefix: '₱',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textThemeColor),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Target Budget', style: TextStyle(color: subText, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '₱${budget.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: subText),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Animated savings badge
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (context, val, child) {
                    return Transform.scale(
                      scale: val,
                      alignment: Alignment.centerLeft,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: didSave ? savedBg : overBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          didSave ? Icons.lightbulb : Icons.warning_amber_rounded,
                          color: didSave ? savedText : overText,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            didSave
                                ? 'Naka-save ka ng ₱${saved.toStringAsFixed(2)} kumpara sa iyong budget! 💡'
                                : 'Lumampas ka ng ₱${(saved.abs()).toStringAsFixed(2)} sa iyong budget.',
                            style: TextStyle(
                              color: didSave ? savedText : overText,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
