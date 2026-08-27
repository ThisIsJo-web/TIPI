import 'package:flutter/material.dart';
import '../services/cache_service.dart';
import '../services/theme_service.dart';
import 'auth/login_view.dart';

class LoadingView extends StatefulWidget {
  const LoadingView({super.key});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  String _statusText = "Syncing local price dataset...";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Sync WFP grocery prices dataset
    bool syncSuccess = await CacheService.instance.syncDataset();
    if (!mounted) return;

    if (!syncSuccess) {
      setState(() {
        _statusText = "Failed to sync price dataset. Continuing offline...";
      });
      await Future.delayed(const Duration(seconds: 1));
    }

    // 2. Redirect to Login Screen
    // (Since we reset the backend to 0, users must always login/register first)
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDarkMode.value;
    return Scaffold(
      backgroundColor: ThemeService.instance.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Beautiful minimal brand text
              Text(
                "TIPI",
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.0,
                  color: ThemeService.instance.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Matipid Grocery Runs",
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 48),
              CircularProgressIndicator(
                color: ThemeService.instance.primary,
                strokeWidth: 3.0,
              ),
              const SizedBox(height: 24),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
