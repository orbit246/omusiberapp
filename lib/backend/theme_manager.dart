import 'package:flutter/material.dart';

class ThemeManager with ChangeNotifier {
  // 1. Singleton Logic (Same as NewsFetcher)
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  // 2. State Variables
  ThemeMode _themeMode = ThemeMode.system; // Default to system setting
  
  // Getter to access current theme mode safely
  ThemeMode get themeMode => _themeMode;

  // Helper to check if we are currently forcing dark mode
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // If system, we can't easily know in a singleton without context, 
      // but for the Switch UI, we usually default to false or check platform brightness.
      // For simplicity in the Settings Switch, we'll map System -> False (or handle 3-way toggle later).
      return false; 
    }
    return _themeMode == ThemeMode.dark;
  }

  // 3. Method to Toggle Theme
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // <--- This tells main.dart to rebuild!
  }
}