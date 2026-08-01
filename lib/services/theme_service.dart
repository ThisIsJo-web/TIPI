import 'package:flutter/material.dart';

class ThemeService {
  static final ThemeService instance = ThemeService._init();
  ThemeService._init();

  final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);

  void toggleTheme(bool value) {
    isDarkMode.value = value;
  }

  // Colors matching user WCAG specifications for Dark Mode vs Light Mode
  Color get primaryButtonBg => isDarkMode.value ? const Color(0xFF10B981) : const Color(0xFF0D5C2C);
  Color get primaryButtonText => isDarkMode.value ? const Color(0xFF06140E) : Colors.white;

  Color get cardBg => isDarkMode.value ? const Color(0xFF111A16) : Colors.white;
  Color get cardText => isDarkMode.value ? const Color(0xFFF1F5F9) : Colors.black87;
  Color get subText => isDarkMode.value ? const Color(0xFF8D9C97) : Colors.grey;

  Color get greenText => isDarkMode.value ? const Color(0xFF34D399) : const Color(0xFF0D5C2C);
  Color get background => isDarkMode.value ? const Color(0xFF090E0C) : const Color(0xFFF7F9F7);
}
