import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../services/theme_service.dart';
import '../../services/translation_service.dart';
import '../../models/grocery_run.dart';
import '../../config/motion_transitions.dart';
import '../runs/run_builder_view.dart';
import '../runs/active_run_view.dart';
import '../../widgets/tipi_run_card.dart';
import '../profile/profile_view.dart';
import '../auth/login_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  List<GroceryRun> _runs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRuns();
  }

  Future<void> _loadRuns() async {
    setState(() {
      _isLoading = true;
    });

    // Simultaneously fetch runs and sync price dataset (over-the-air)
    final results = await Future.wait([
      ApiService.instance.fetchRuns(),
      CacheService.instance.syncDataset(),
    ]);

    final fetchedRuns = results[0] as List<GroceryRun>;

    setState(() {
      _runs = fetchedRuns;
      _isLoading = false;
    });
  }

  void _navigateToCreateRun() {
    Navigator.of(context).push(
      TipiPageRouteBuilder(
        page: const RunBuilderView(),
      ),
    ).then((_) => _loadRuns());
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.instance.currentUser;
    final isDark = ThemeService.instance.isDarkMode.value;

    // Calculate budget utilization
    double totalSpentThisMonth = _runs.fold(0.0, (sum, run) => sum + run.spent);
    double budgetGoal = user?.budgetGoal ?? 2000.0;
    double progressPercent = budgetGoal > 0 ? (totalSpentThisMonth / budgetGoal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: ThemeService.instance.background,
      appBar: AppBar(
        title: Text(
          TranslationService.instance.t('dashboard_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              setState(() {
                ThemeService.instance.toggleTheme();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).push(
                TipiPageRouteBuilder(page: const ProfileView()),
              ).then((_) => setState(() {}));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ApiService.instance.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginView()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRuns,
        color: ThemeService.instance.primary,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome header
              Text(
                "${TranslationService.instance.t('hello')}, ${user?.name != null && user!.name.trim().isNotEmpty ? user.name.trim().split(' ').first : 'Saver'} 👋",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Monthly Budget Card
              Card(
                color: ThemeService.instance.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              TranslationService.instance.t('monthly_budget'),
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(
                            "₱${budgetGoal.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ThemeService.instance.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 12,
                          backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          color: progressPercent >= 0.9 
                              ? Colors.red 
                              : ThemeService.instance.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${TranslationService.instance.t('spent')}: ₱${totalSpentThisMonth.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Text(
                            "${(progressPercent * 100).toStringAsFixed(0)}% ${TranslationService.instance.t('used')}",
                            style: TextStyle(
                              fontSize: 13,
                              color: progressPercent >= 0.9 ? Colors.red : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Runs List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      TranslationService.instance.t('recent_runs'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _navigateToCreateRun,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(TranslationService.instance.t('create_run').toUpperCase()),
                    style: TextButton.styleFrom(
                      foregroundColor: ThemeService.instance.primary,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // List of Runs
              Expanded(
                child: _isLoading
                    ? ListView.builder(
                        itemCount: 3,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              Container(
                                height: 76,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              if (index == 2) ...[
                                const SizedBox(height: 12),
                                Text(
                                  TranslationService.instance.t('loading_text'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          );
                        },
                      )
                    : _runs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_basket_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  TranslationService.instance.t('no_runs_yet'),
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _runs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final run = _runs[idx];
                              return TipiRunCard(
                                run: run,
                                onTap: () {
                                  if (run.status == 'draft') {
                                    Navigator.of(context).push(
                                      TipiPageRouteBuilder(
                                        page: RunBuilderView(run: run),
                                      ),
                                    ).then((_) => _loadRuns());
                                  } else {
                                    Navigator.of(context).push(
                                      TipiPageRouteBuilder(
                                        page: ActiveRunView(run: run),
                                      ),
                                    ).then((_) => _loadRuns());
                                  }
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ThemeService.instance.primary,
        onPressed: _navigateToCreateRun,
        tooltip: 'New Run',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
