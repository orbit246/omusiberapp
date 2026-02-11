import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const primary = Color(
    0xFF2563EB,
  ); // Inter Blue - Professional & Academic
  static const primaryAccent = Color(0xFF3B82F6); // Lighter Blue

  // Accents
  static const cyberTeal = Color(0xFF0D9488); // Teal 600 - Muted Teal
  static const neonMint = Color(0xFF14B8A6); // Teal 500

  // Neutrals / Backgrounds
  static const deepBackground = Color(0xFF0f172a); // Slate 900 (Dark Mode)
  static const surfaceDark = Color(0xFF1e293b); // Slate 800

  static const offWhite = Color(0xFFF8FAFC); // Slate 50 (Light Mode Bg)
  static const coolGray = Color(0xFF64748B); // Slate 500

  // Functional
  static const amberGlow = Color(0xFFF59E0B); // Amber 500
  static const electricMagenta = Color(0xFFEC4899); // Pink 500 (Less neon)

  // Subtle application
  static const Color subtleBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color subtleSurface = Color(0xFFFFFFFF); // Pure White
}

/// Semantic tokens updated to use the new palette
class CyberSemantic extends ThemeExtension<CyberSemantic> {
  final Color success;
  final Color warning;
  final Color info;
  final Color brandGlow; // for borders/shadows/ink
  final Color highlightBg; // for chips/pills

  const CyberSemantic({
    required this.success,
    required this.warning,
    required this.info,
    required this.brandGlow,
    required this.highlightBg,
  });

  @override
  CyberSemantic copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? brandGlow,
    Color? highlightBg,
  }) {
    return CyberSemantic(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      brandGlow: brandGlow ?? this.brandGlow,
      highlightBg: highlightBg ?? this.highlightBg,
    );
  }

  @override
  CyberSemantic lerp(ThemeExtension<CyberSemantic>? other, double t) {
    if (other is! CyberSemantic) return this;
    return CyberSemantic(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      brandGlow: Color.lerp(brandGlow, other.brandGlow, t)!,
      highlightBg: Color.lerp(highlightBg, other.highlightBg, t)!,
    );
  }

  // Updated Semantic Light Logic
  static CyberSemantic light(ColorScheme cs) => CyberSemantic(
    success: const Color(0xFF00BFA5), // Teal
    warning: AppColors.amberGlow,
    info: const Color(0xFF2979FF),
    // Glow is now purple-ish
    brandGlow: AppColors.primary.withOpacity(0.15),
    highlightBg: const Color(0xFFEDE7F6), // Very light purple
  );

  // Updated Semantic Dark Logic
  static CyberSemantic dark(ColorScheme cs) => CyberSemantic(
    success: AppColors.neonMint,
    warning: AppColors.amberGlow,
    info: const Color(0xFF448AFF),
    // Glow is neon mint in dark mode
    brandGlow: AppColors.neonMint.withOpacity(0.20),
    highlightBg: const Color(0xFF1E293B), // Matching surface
  );
}
