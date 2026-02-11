import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  // DARK MODE
  static ThemeData dark({Color? seed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed ?? AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryAccent,
      onPrimary: Colors.white,
      secondary: AppColors.neonMint,
      onSecondary: Colors.black,
      surface: AppColors.surfaceDark,
      error: const Color(0xFFCF6679),
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppColors.deepBackground,

      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.1),
        thickness: 1,
      ),

      extensions: <ThemeExtension<dynamic>>[CyberSemantic.dark(scheme)],
    );
  }

  // LIGHT MODE
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.cyberTeal,
      onSecondary: Colors.white,
      surface: AppColors.subtleSurface,
      onSurface: const Color(0xFF0F172A), // Slate 900 text
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppColors.subtleBackground,

      // Clean, flat App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.subtleBackground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      ),

      // Minimalist Card
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Gentle radius
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),

      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),

      // Minimalist Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      extensions: <ThemeExtension<dynamic>>[CyberSemantic.light(scheme)],
    );
  }

  static ThemeData _base(ColorScheme cs) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.primary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.brightness == Brightness.dark
            ? const Color(0xFF334155)
            : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}
