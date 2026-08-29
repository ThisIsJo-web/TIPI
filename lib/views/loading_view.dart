import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/theme_service.dart';
import 'auth/login_view.dart';
import 'home/home_view.dart';

class LoadingView extends StatefulWidget {
  const LoadingView({super.key});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  String _statusText = "Loading up everything for you, please take a moment...";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Sync WFP grocery prices dataset in background
    await CacheService.instance.syncDataset();
    if (!mounted) return;

    // 2. Attempt Auto-Login using persisted JWT
    setState(() {
      _statusText = "Authenticating secure session...";
    });
    
    bool loggedIn = await ApiService.instance.tryAutoLogin();
    if (!mounted) return;

    if (loggedIn) {
      // Direct redirect to Dashboard if session is active
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeView()),
      );
    } else {
      // Redirect to Login Screen otherwise
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
