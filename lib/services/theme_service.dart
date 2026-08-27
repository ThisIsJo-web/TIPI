import 'package:flutter/material.dart';

class ThemeService {
  static final ThemeService instance = ThemeService._init();
  ThemeService._init();

  final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);

  Color get background => isDarkMode.value ? const Color(0xFF121212) : const Color(0xFFF9FBF9);
  Color get surface => isDarkMode.value ? const Color(0xFF1E1E1E) : Colors.white;
  Color get primary => const Color(0xFF0D5C2C);
  Color get primaryLight => const Color(0xFFE2F0E6);

  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
  }
}
