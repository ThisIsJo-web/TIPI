import 'package:flutter/material.dart';
import '../../services/grocery_run_service.dart';
import '../../widgets/staggered_fade_slide.dart';
import '../../widgets/page_transitions.dart';
import 'create_run_dialog.dart';
import 'grocery_builder_page.dart';
import '../../services/theme_service.dart';
import 'dart:async';

class RunsTab extends StatefulWidget {
  final String? userId;
  final String? detectedCity;
  final String? detectedProvince;
  final VoidCallback? onCreateRunTap;

  const RunsTab({
    super.key,
    this.userId,
    this.detectedCity,
    this.detectedProvince,
    this.onCreateRunTap,
  });

  @override
  State<RunsTab> createState() => _RunsTabState();
}

class _RunsTabState extends State<RunsTab> {
  final _runService = GroceryRunService.instance;
  List<Map<String, dynamic>> _runs = [];
  bool _isLoading = true;
  StreamSubscription<void>? _runSubscription;

  @override
  void initState() {
    super.initState();
    _loadRuns();
    _runSubscription = _runService.onRunUpdated.listen((_) {
      _loadRuns();
    });
  }

  @override
  void dispose() {
    _runSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRuns() async {
    setState(() => _isLoading = true);
    final runs = await _runService.getRuns(widget.userId);
    if (mounted) {
      setState(() {
        _runs = runs;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCreateRun() async {
    final createdRun = await CreateRunDialog.show(context, userId: widget.userId);
    if (createdRun != null && mounted) {
      await _loadRuns();
      _openRunBuilder(createdRun);
    }
  }

  Future<void> _openRunBuilder(Map<String, dynamic> run) async {
    final result = await Navigator.push(
      context,
      SlideUpFadeRoute(
        page: GroceryBuilderPage(
          runData: run,
          userId: widget.userId,
          detectedCity: widget.detectedCity,
          detectedProvince: widget.detectedProvince,
        ),
      ),
    );
    if (result == true && mounted) {
      _loadRuns();
    }
  }

  Future<void> _deleteRun(String runId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Grocery Run?'),
        content: const Text('This will permanently delete this run and its items.'),
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
      _loadRuns();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = ThemeService.instance.background;
    final cardBg = ThemeService.instance.cardBg;
    final greenColor = ThemeService.instance.greenText;
    final primaryGreen = ThemeService.instance.primaryButtonBg;
    final buttonText = ThemeService.instance.primaryButtonText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          'My Grocery Runs',
          style: TextStyle(color: greenColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: greenColor),
            onPressed: _loadRuns,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: greenColor))
          : _runs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRuns,
                  color: greenColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _runs.length,
                    itemBuilder: (context, index) {
                      final run = _runs[index];
                      return StaggeredFadeSlide(
                        delay: Duration(milliseconds: index * 80),
                        child: _buildRunCard(run),
                      );
                    },
                  ),
                ),
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: FloatingActionButton.extended(
          onPressed: _handleCreateRun,
          backgroundColor: primaryGreen,
          icon: Icon(Icons.add, color: buttonText),
          label: Text('New Run', style: TextStyle(color: buttonText, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final greenColor = ThemeService.instance.greenText;
    final primaryGreen = ThemeService.instance.primaryButtonBg;
    final buttonText = ThemeService.instance.primaryButtonText;
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
                    Icons.shopping_bag_outlined,
                    color: greenColor,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Grocery Runs Yet',
                style: TextStyle(color: textThemeColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a new grocery run header with your target budget, then start adding groceries!',
                style: TextStyle(color: subText, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ScaleOnPress(
                onTap: _handleCreateRun,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: buttonText, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Start New Run',
                        style: TextStyle(color: buttonText, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunCard(Map<String, dynamic> run) {
    final String runId = run['id'] ?? '';
    final String syncStatus = run['sync_status'] ?? 'synced';
    final bool isUnsynced = syncStatus != 'synced' || double.tryParse(runId) != null;
    final String name = run['name'] ?? 'Grocery Run';
    final double budget = (run['budget'] as num? ?? 0.0).toDouble();
    final double spent = (run['spent'] as num? ?? 0.0).toDouble();
    final String status = run['status'] ?? 'draft';

    final items = (run['grocery_run_items'] as List?) ?? [];
    final int itemLength = items.length;

    final double progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final bool isOverBudget = spent > budget && budget > 0;

    final isDark = ThemeService.instance.isDarkMode.value;
    final cardBg = ThemeService.instance.cardBg;
    final textThemeColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final greenColor = ThemeService.instance.greenText;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'active':
        statusColor = isDark ? const Color(0xFF4ADE80) : Colors.green;
        statusLabel = 'Shopping Active';
        break;
      case 'completed':
        statusColor = isDark ? Colors.blueAccent : Colors.blue;
        statusLabel = 'Completed';
        break;
      default:
        statusColor = isDark ? Colors.orangeAccent : Colors.orange;
        statusLabel = 'Draft List';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ScaleOnPress(
        onTap: () => _openRunBuilder(run),
        scaleDown: 0.97,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
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
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textThemeColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnsynced) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.cloud_upload_outlined,
                              color: Colors.orange,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Pulsing badge for active runs
                    status == 'active'
                        ? PulsingWidget(
                            child: _buildStatusChip(statusColor, statusLabel),
                          )
                        : _buildStatusChip(statusColor, statusLabel),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: subText),
                      onSelected: (val) {
                        if (val == 'delete') _deleteRun(runId);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete Run', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Animated count for spent
                    AnimatedCount(
                      value: spent,
                      prefix: '₱',
                      suffix: ' / ₱${budget.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isOverBudget ? Colors.red : textThemeColor,
                      ),
                    ),
                    Text(
                      '$itemLength item${itemLength == 1 ? '' : 's'}',
                      style: TextStyle(color: subText, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Animated progress bar
                AnimatedProgressBar(
                  value: progress,
                  color: isOverBudget ? Colors.red : greenColor,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: greenColor),
                    const SizedBox(width: 4),
                    Text(
                      status == 'active' ? 'Tap to view / shopping mode' : 'Tap to add or edit groceries',
                      style: TextStyle(color: greenColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
