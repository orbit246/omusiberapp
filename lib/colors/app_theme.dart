// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData dark({Color? seed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed ?? AppColors.primaryAccent,
      brightness: Brightness.dark, // <- everything derives from this + seed
      primary: AppColors.primary,
      secondary: AppColors.neonMint,
      tertiary: AppColors.electricMagenta,
      background: Color(0xff15131D),
      surface: Color(0xff2c293a).withOpacity(.66),
      onPrimaryContainer: AppColors.offWhite,
      surfaceBright: Colors.white,
    );

    return _base(scheme).copyWith(extensions: <ThemeExtension<dynamic>>[CyberSemantic.dark(scheme)]);
  }

  static ThemeData _base(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, height: 1.3),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2B1C45) : const Color(0xFFF7F2FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.tertiary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.tertiary, // neon accent
          foregroundColor: cs.onTertiary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF2F1B44) : const Color(0xFFF1E6FF),
        selectedColor: cs.tertiary.withOpacity(0.25),
        side: BorderSide(color: cs.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
      ),
    );
  }

  static ThemeData? light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryAccent,
      brightness: Brightness.light, // <- everything derives from this + seed
      primary: AppColors.primary,
      secondary: AppColors.neonMint,
      tertiary: AppColors.electricMagenta,
      background: Color(0xfff3f0ff),
      surface: Color(0xffdfd8fd).withOpacity(.66),
    );

    return _base(scheme).copyWith(extensions: <ThemeExtension<dynamic>>[CyberSemantic.light(scheme)]);
  }
}
