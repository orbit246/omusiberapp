import 'package:flutter/material.dart';

/// Updated with the "Cyber Grape & Teal" palette from the playground
class AppColors {
  // Primary Brand Colors
  // Primary Brand Colors
  static const primary = Color(
    0xFF4F46E5,
  ); // Modern Electric Indigo (Brighter, more vibrant)
  static const primaryAccent = Color(
    0xFFC7B8FF,
  ); // Soft Lavender (Dark Mode Primary)

  // Accents (Teal/Mint)
  static const cyberTeal = Color(0xFF00BFA5); // Sharp Teal (Light Mode Accent)
  static const neonMint = Color(0xFF64FFDA); // Glowing Mint (Dark Mode Accent)

  // Neutrals & Backgrounds
  static const deepBackground = Color(0xFF0F172A); // Slate 900 (Dark Mode Bg)
  static const surfaceDark = Color(0xFF1E293B); // Slate 800 (Dark Mode Surface)
  static const offWhite = Color(
    0xFFF8FAFC,
  ); // Cool White (Light Mode Bg backup)
  static const coolGray = Color(0xFF94A3B8);
  static const jetBlack = Color(0xFF102A43);

  // Functional Colors
  static const amberGlow = Color(0xFFFFD54F); // Warning
  static const electricMagenta = Color(0xFFFF4081); // Tertiary/Pink Accent

  // Legacy/Unused from original mapped to new palette
  static const deepPurple = Color(0xFF12005E);
  static const softLavender = Color(0xFFD1C4E9);

  // Updated Surface/Backgrounds for "Modern" feel (Pink-ish modern)
  static const Color subtleBackground = Color(
    0xFFFFF5F9,
  ); // Very light modern pink
  static const Color subtleSurface = Color(
    0xFFFFFFFF,
  ); // Pure white for crisp contrast
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
