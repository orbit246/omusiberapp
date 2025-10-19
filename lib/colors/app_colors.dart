// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Base brand palette (from your purple/cyber brief)
class AppColors {
  static const primary = Color(0xFF7B2CBF);
  static const primaryAccent = Color(0xFF9D4EDD);
  static const deepPurple = Color(0xFF240046);
  static const softLavender = Color(0xFFE0AAFF);
  static const neonMint = Color(0xFF80FFDB);
  static const cyberTeal = Color(0xFF5DD9C1);
  static const offWhite = Color(0xFFF8F9FA);
  static const coolGray = Color(0xFFADB5BD);
  static const jetBlack = Color(0xFF0B0B0D);
  static const amberGlow = Color(0xFFFFD166);
  static const electricMagenta = Color(0xFFFF5EDF);
}

/// Semantic tokens that libs/components can use without caring about exact hex
class CyberSemantic extends ThemeExtension<CyberSemantic> {
  final Color success;
  final Color warning;
  final Color info;
  final Color brandGlow;    // for borders/shadows/ink
  final Color highlightBg;  // for chips/pills

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

  static CyberSemantic light(ColorScheme cs) => CyberSemantic(
        success: const Color(0xFF12B886), // teal-ish
        warning: AppColors.amberGlow,
        info: AppColors.cyberTeal,
        brandGlow: AppColors.neonMint.withOpacity(0.5),
        highlightBg: const Color(0xFFF1E6FF),
      );

  static CyberSemantic dark(ColorScheme cs) => CyberSemantic(
        success: const Color(0xFF2DD4BF),
        warning: AppColors.amberGlow,
        info: AppColors.neonMint,
        brandGlow: AppColors.neonMint.withOpacity(0.25),
        highlightBg: const Color(0xFF2F1B44),
      );
}
