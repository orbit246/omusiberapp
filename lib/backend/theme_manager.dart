import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager with ChangeNotifier {
  static const String _themeModePrefsKey = 'theme_mode';
  // 1. Singleton Logic (Same as NewsFetcher)
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  // 2. State Variables
  ThemeMode _themeMode = ThemeMode.dark; // Default to system setting
  
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

  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(_themeModePrefsKey);
    if (storedValue == null) {
      return;
    }

    final loadedThemeMode = switch (storedValue) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => _themeMode,
    };

    if (_themeMode == loadedThemeMode) {
      return;
    }

    _themeMode = loadedThemeMode;
    notifyListeners();
  }

  // 3. Method to Toggle Theme
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePrefsKey, _themeMode.name);
    notifyListeners(); // <--- This tells main.dart to rebuild!
  }
}
