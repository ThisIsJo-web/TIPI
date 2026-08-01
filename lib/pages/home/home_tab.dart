import 'package:flutter/material.dart';
import '../../widgets/staggered_fade_slide.dart';
import '../../services/theme_service.dart';

class HomeTab extends StatelessWidget {
  final String userName;
  final String? detectedCity;
  final String? detectedProvince;
  final bool dbExists;
  final VoidCallback onNewRunTap;
  final VoidCallback onSavedListsTap;
  final VoidCallback onPriceSearchTap;
  final VoidCallback onViewAllRunsTap;
  final VoidCallback onProfileTap;
  final Map<String, dynamic>? activeRun;
  final List<Map<String, dynamic>> recentCompletedRuns;
  final Function(Map<String, dynamic>)? onResumeActiveRunTap;

  const HomeTab({
    super.key,
    required this.userName,
    required this.detectedCity,
    required this.detectedProvince,
    required this.dbExists,
    required this.onNewRunTap,
    required this.onSavedListsTap,
    required this.onPriceSearchTap,
    required this.onViewAllRunsTap,
    required this.onProfileTap,
    this.activeRun,
    required this.recentCompletedRuns,
    this.onResumeActiveRunTap,
  });

  @override
  Widget build(BuildContext context) {
    final textThemeColor = ThemeService.instance.cardText;
    final greenColor = ThemeService.instance.greenText;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — immediate, no delay
          StaggeredFadeSlide(
            delay: Duration.zero,
            child: _buildDashboardHeader(),
          ),
          const SizedBox(height: 24),

          // Active Run Card — slight delay
          StaggeredFadeSlide(
            delay: const Duration(milliseconds: 80),
            child: _buildActiveRunCard(context),
          ),
          const SizedBox(height: 24),

          // Quick Actions title
          StaggeredFadeSlide(
            delay: const Duration(milliseconds: 160),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                color: textThemeColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Action Buttons
          StaggeredFadeSlide(
            delay: const Duration(milliseconds: 220),
            child: _buildQuickActions(),
          ),
          const SizedBox(height: 24),

          // Diskarte Tip
          StaggeredFadeSlide(
            delay: const Duration(milliseconds: 300),
            child: _buildDiskarteTipCard(),
          ),
          const SizedBox(height: 24),

          // Recent Runs header
          StaggeredFadeSlide(
            delay: const Duration(milliseconds: 380),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Runs',
                  style: TextStyle(
                    color: textThemeColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: onViewAllRunsTap,
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: greenColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Recent Runs list
          _buildRecentRunsSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    final cardBg = ThemeService.instance.cardBg;
    final textThemeColor = ThemeService.instance.cardText;
    final greenColor = ThemeService.instance.greenText;
    final subText = ThemeService.instance.subText;
    final isDark = ThemeService.instance.isDarkMode.value;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey[200]!;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cardBg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: dividerColor),
          ),
          child: Center(
            child: Icon(Icons.shopping_basket, color: greenColor, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Kamusta, $userName!',
                    style: TextStyle(
                      color: greenColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('👋', style: TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.location_on, color: subText, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      detectedProvince != null
                          ? (detectedCity != null && detectedCity != detectedProvince
                              ? '$detectedCity, $detectedProvince'
                              : '$detectedProvince')
                          : 'Detecting Location...',
                      style: TextStyle(
                        color: subText,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.search, color: textThemeColor),
          onPressed: onPriceSearchTap,
        ),
        GestureDetector(
          onTap: onProfileTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: greenColor, width: 1.5),
            ),
            child: Center(
              child: Icon(Icons.person, color: greenColor, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveRunCard(BuildContext context) {
    final cardBg = ThemeService.instance.cardBg;
    final textThemeColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final greenColor = ThemeService.instance.greenText;
    final primaryGreen = ThemeService.instance.primaryButtonBg;
    final buttonText = ThemeService.instance.primaryButtonText;
    final isDark = ThemeService.instance.isDarkMode.value;

    if (activeRun == null) {
      return Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: greenColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_bag_outlined, color: greenColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Maligayang Pagdating sa TIPI! 🛒',
                    style: TextStyle(
                      color: textThemeColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Plan your grocery budget, search real-time local commodity prices, and save money on every palengke run.',
              style: TextStyle(color: subText, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ScaleOnPress(
                onTap: onNewRunTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: buttonText, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Start a New Grocery Run',
                        style: TextStyle(color: buttonText, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final String name = activeRun!['name'] ?? 'Grocery Run';
    final double budget = (activeRun!['budget'] as num? ?? 0.0).toDouble();
    final double spent = (activeRun!['spent'] as num? ?? 0.0).toDouble();
    final String status = activeRun!['status'] ?? 'draft';
    final items = (activeRun!['grocery_run_items'] as List?) ?? [];
    final int itemLength = items.length;
    final double progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final bool isOverBudget = spent > budget && budget > 0;

    return ScaleOnPress(
      onTap: onResumeActiveRunTap != null ? () => onResumeActiveRunTap!(activeRun!) : null,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Animated side accent bar
              Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: status == 'active'
                        ? [Colors.green.shade400, Colors.green.shade700]
                        : [greenColor, primaryGreen],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: textThemeColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Pulsing status badge for active runs
                          status == 'active'
                              ? PulsingWidget(
                                  child: _buildStatusBadge(status),
                                )
                              : _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$itemLength item${itemLength == 1 ? '' : 's'} added',
                        style: TextStyle(color: subText, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spent',
                                style: TextStyle(color: subText, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              // Animated count-up for spent
                              AnimatedCount(
                                value: spent,
                                prefix: '₱',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isOverBudget ? Colors.red : greenColor,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Budget',
                                style: TextStyle(color: subText, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₱${budget.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textThemeColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Animated progress bar
                      AnimatedProgressBar(
                        value: progress,
                        color: isOverBudget ? Colors.red : greenColor,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow, color: buttonText, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Ipadayon ang Run',
                              style: TextStyle(
                                color: buttonText,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildStatusBadge(String status) {
    final isDark = ThemeService.instance.isDarkMode.value;
    final activeBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFE2F0D9);
    final activeText = isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C2C);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status == 'active' ? activeBg : Colors.orange.shade50.withOpacity(isDark ? 0.2 : 1.0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status == 'active' ? 'Shopping Active' : 'Unfinished Draft',
        style: TextStyle(
          color: status == 'active' ? activeText : (isDark ? Colors.orange.shade300 : Colors.orange.shade800),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final isDark = ThemeService.instance.isDarkMode.value;
    final primaryGreen = ThemeService.instance.primaryButtonBg;
    final buttonText = ThemeService.instance.primaryButtonText;
    final searchBg = isDark ? Colors.grey.shade800 : Colors.grey[200]!;
    final searchIcon = isDark ? Colors.white70 : Colors.grey[800]!;

    return Row(
      children: [
        _buildQuickActionItem(
          icon: Icons.shopping_cart,
          iconColor: buttonText,
          bgColor: primaryGreen,
          label: 'New Run',
          onTap: onNewRunTap,
          delay: const Duration(milliseconds: 240),
        ),
        const SizedBox(width: 12),
        _buildQuickActionItem(
          icon: Icons.list_alt,
          iconColor: Colors.white,
          bgColor: Colors.orange,
          label: 'Saved Lists',
          onTap: onSavedListsTap,
          delay: const Duration(milliseconds: 310),
        ),
        const SizedBox(width: 12),
        _buildQuickActionItem(
          icon: Icons.search,
          iconColor: searchIcon,
          bgColor: searchBg,
          label: 'Price Search',
          onTap: onPriceSearchTap,
          delay: const Duration(milliseconds: 380),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
    Duration delay = Duration.zero,
  }) {
    final cardBg = ThemeService.instance.cardBg;
    final textThemeColor = ThemeService.instance.cardText;
    final isDark = ThemeService.instance.isDarkMode.value;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey[200]!;

    return Expanded(
      child: StaggeredFadeSlide(
        delay: delay,
        offset: const Offset(0, 16),
        child: ScaleOnPress(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: dividerColor),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textThemeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiskarteTipCard() {
    final primaryGreen = ThemeService.instance.primaryButtonBg;
    final greenColor = ThemeService.instance.greenText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryGreen,
            greenColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.yellowAccent, size: 18),
              SizedBox(width: 6),
              Text(
                'Diskarte Tip #1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Check the lower shelves for better deals!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRunsSection() {
    final cardBg = ThemeService.instance.cardBg;
    final subText = ThemeService.instance.subText;
    final isDark = ThemeService.instance.isDarkMode.value;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    if (recentCompletedRuns.isEmpty) {
      return StaggeredFadeSlide(
        delay: const Duration(milliseconds: 440),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dividerColor),
          ),
          child: Column(
            children: [
              FloatingWidget(
                amplitude: 4,
                child: Icon(Icons.history, color: subText, size: 36),
              ),
              const SizedBox(height: 8),
              Text(
                'No completed runs yet.',
                style: TextStyle(color: subText, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: List.generate(recentCompletedRuns.length, (index) {
        return StaggeredFadeSlide(
          delay: Duration(milliseconds: 440 + (index * 100)),
          offset: const Offset(20, 0), // slide from right
          child: _buildRecentRunItem(recentCompletedRuns[index]),
        );
      }),
    );
  }

  Widget _buildRecentRunItem(Map<String, dynamic> run) {
    final String name = run['name'] ?? 'Grocery Run';
    final double budget = (run['budget'] as num? ?? 0.0).toDouble();
    final double spent = (run['spent'] as num? ?? 0.0).toDouble();
    final double saved = budget - spent;
    final bool didSave = saved > 0;

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
    final greenColor = ThemeService.instance.greenText;
    final isDark = ThemeService.instance.isDarkMode.value;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey[100]!;

    final savedBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFE2F0D9);
    final savedText = isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C2C);
    final overBg = isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50;
    final overText = isDark ? Colors.red.shade300 : Colors.red.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: greenColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline, color: greenColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textThemeColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(dateStr, style: TextStyle(color: subText, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCount(
                value: spent,
                prefix: '₱',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textThemeColor),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: didSave ? savedBg : overBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  didSave ? 'Saved ₱${saved.toStringAsFixed(0)}' : 'Over ₱${(saved.abs()).toStringAsFixed(0)}',
                  style: TextStyle(
                    color: didSave ? savedText : overText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
