import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // DARK MODE: Uses Light Purple (primaryAccent) + Neon Mint
  static ThemeData dark({Color? seed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed ?? AppColors.primaryAccent,
      brightness: Brightness.dark,

      // Mapped from my "Cyber Grape" Dark Palette
      primary: AppColors.primaryAccent, // #B388FF
      onPrimary: Colors.black, // Dark text on light purple for readability

      secondary: AppColors.neonMint, // #64FFDA
      onSecondary: Colors.black,

      tertiary: AppColors.electricMagenta,

      background: AppColors.deepBackground, // #0F172A
      surface: AppColors.surfaceDark, // #1E293B

      error: const Color(0xFFCF6679),
    );

    return _base(scheme).copyWith(extensions: <ThemeExtension<dynamic>>[CyberSemantic.dark(scheme)]);
  }

  // LIGHT MODE: Uses Deep Indigo (primary) + Sharp Teal
  // inside AppTheme class

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,

      primary: AppColors.primary,
      onPrimary: Colors.white,

      secondary: AppColors.cyberTeal,
      onSecondary: Colors.white,

      tertiary: AppColors.electricMagenta,

      // 1. SURFACES: Use the new "Pale Pink" instead of pure White
      surface: AppColors.palePink,
      onSurface: Colors.black87, // Ensure text is still readable
      // 2. BACKGROUND: The darker pink
      background: AppColors.mistyRose,
    );

    return _base(scheme).copyWith(
      // 3. SCAFFOLD: Explicitly set to Misty Rose
      scaffoldBackgroundColor: AppColors.mistyRose,

      // 4. APP BAR: Make it Pink (Misty Rose) to match the background
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.mistyRose,
        surfaceTintColor: Colors.transparent, // Prevents purple tint on scroll
        scrolledUnderElevation: 0, // Keeps it flat and pink even when scrolling
        iconTheme: const IconThemeData(color: Colors.black87),
      ),

      // 5. BOTTOM SHEETS & CARDS: Make them Pale Pink (Overlay color)
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.palePink,
        modalBackgroundColor: AppColors.palePink,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: AppColors.palePink, // The cards will now be slightly pink
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          // Subtle border to separate the pale pink card from the misty rose bg
          side: BorderSide(color: AppColors.primary.withOpacity(0.05)),
        ),
      ),

      dialogTheme: const DialogThemeData(backgroundColor: AppColors.palePink, surfaceTintColor: Colors.transparent),

      extensions: <ThemeExtension<dynamic>>[CyberSemantic.light(scheme)],
    );
  }

  // Base configuration (Typography, Shapes, etc.)
  static ThemeData _base(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      // Default fallback, but overridden in light() above
      scaffoldBackgroundColor: cs.background,
      splashFactory: InkSparkle.splashFactory,

      textTheme: TextTheme(
        // Display - Large, bold, for hero sections
        displayLarge: GoogleFonts.lexend(fontSize: 57, fontWeight: FontWeight.w800, height: 1.1, color: cs.onSurface),
        displayMedium: GoogleFonts.lexend(fontSize: 45, fontWeight: FontWeight.w700, height: 1.15, color: cs.onSurface),
        displaySmall: GoogleFonts.lexend(fontSize: 36, fontWeight: FontWeight.w700, height: 1.2, color: cs.onSurface),

        // Headline - Section headers
        headlineLarge: GoogleFonts.lexend(fontSize: 32, fontWeight: FontWeight.bold, height: 1.25, color: cs.onSurface),
        headlineMedium: GoogleFonts.lexend(fontSize: 28, fontWeight: FontWeight.w600, height: 1.3, color: cs.onSurface),
        headlineSmall: GoogleFonts.lexend(fontSize: 24, fontWeight: FontWeight.w600, height: 1.35, color: cs.onSurface),

        // Title - Card headers, dialog titles
        titleLarge: GoogleFonts.lexend(fontSize: 22, fontWeight: FontWeight.w600, height: 1.2, color: cs.onSurface),
        titleMedium: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0.15,
          color: cs.onSurface,
        ),
        titleSmall: GoogleFonts.lexend(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: cs.onSurface,
        ),

        // Label - Buttons, chips, captions
        labelLarge: GoogleFonts.lexend(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: cs.onSurface,
        ),
        labelMedium: GoogleFonts.lexend(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: cs.onSurfaceVariant,
        ),
        labelSmall: GoogleFonts.lexend(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: cs.onSurfaceVariant,
        ),

        // Body - Long form text
        bodyLarge: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: 0.15,
          color: cs.onSurface,
        ),
        bodyMedium: GoogleFonts.lexend(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: 0.25,
          color: cs.onSurface,
        ),
        bodySmall: GoogleFonts.lexend(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: 0.4,
          color: cs.onSurfaceVariant,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Dark mode uses a slightly lighter shade than bg, Light mode uses white
        fillColor: isDark ? const Color(0xFF334155) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.secondary, // Uses Teal/Mint
          foregroundColor: cs.onSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        selectedColor: cs.primary.withOpacity(0.25),
        side: BorderSide.none, // Cleaner look
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
      ),

      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          // Light mode: grey border. Dark mode: no border.
          side: isDark ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}
