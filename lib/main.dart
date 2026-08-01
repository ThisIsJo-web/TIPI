import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/theme_service.dart';
import 'pages/loading_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable edge-to-edge display with standard status and navigation overlays
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  // Initialize Supabase with configuration constants
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } catch (e) {
    debugPrint('Supabase Initialization Error (make sure credentials are set): $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.instance.isDarkMode,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'Tipi',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D5C2C),
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor: ThemeService.instance.background,
            useMaterial3: true,
          ),
          debugShowCheckedModeBanner: false,
          home: const LoadingPage(),
        );
      },
    );
  }
}

