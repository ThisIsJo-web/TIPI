import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/theme_service.dart';
import 'views/loading_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable edge-to-edge display with transparent overlays
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  
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
              seedColor: ThemeService.instance.primary,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor: ThemeService.instance.background,
            useMaterial3: true,
          ),
          debugShowCheckedModeBanner: false,
          home: const LoadingView(),
        );
      },
    );
  }
}
