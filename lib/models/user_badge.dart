import 'package:flutter/material.dart';

/// Badge types that can be awarded to users
enum BadgeType {
  EARLY_TESTER,
  BETA_TESTER,
  CONTRIBUTOR,
  VIP,
  MODERATOR,
  DEVELOPER,
}

/// User badge model with display properties
class UserBadge {
  final BadgeType type;
  final String text;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;

  const UserBadge({
    required this.type,
    required this.text,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
  });

  /// Factory constructor to create a badge from its type
  factory UserBadge.fromType(BadgeType type) {
    switch (type) {
      case BadgeType.EARLY_TESTER:
        return const UserBadge(
          type: BadgeType.EARLY_TESTER,
          text: 'Erken Test Kullanıcısı',
          icon: Icons.rocket_launch_rounded,
          backgroundColor: Color(0xFF6366F1), // Indigo
          textColor: Colors.white,
        );
      case BadgeType.BETA_TESTER:
        return const UserBadge(
          type: BadgeType.BETA_TESTER,
          text: 'Beta Test Kullanıcısı',
          icon: Icons.science_rounded,
          backgroundColor: Color(0xFF8B5CF6), // Purple
          textColor: Colors.white,
        );
      case BadgeType.CONTRIBUTOR:
        return const UserBadge(
          type: BadgeType.CONTRIBUTOR,
          text: 'Katkı Sağlayan',
          icon: Icons.volunteer_activism_rounded,
          backgroundColor: Color(0xFF10B981), // Emerald
          textColor: Colors.white,
        );
      case BadgeType.VIP:
        return const UserBadge(
          type: BadgeType.VIP,
          text: 'VIP Üye',
          icon: Icons.star_rounded,
          backgroundColor: Color(0xFFF59E0B), // Amber
          textColor: Colors.white,
        );
      case BadgeType.MODERATOR:
        return const UserBadge(
          type: BadgeType.MODERATOR,
          text: 'Moderatör',
          icon: Icons.shield_rounded,
          backgroundColor: Color(0xFF3B82F6), // Blue
          textColor: Colors.white,
        );
      case BadgeType.DEVELOPER:
        return const UserBadge(
          type: BadgeType.DEVELOPER,
          text: 'Geliştirici',
          icon: Icons.code_rounded,
          backgroundColor: Color(0xFF1F2937), // Dark gray
          textColor: Colors.white,
        );
    }
  }

  /// Parse badge type from string (from backend)
  static BadgeType? parseType(String value) {
    try {
      return BadgeType.values.firstWhere(
        (e) => e.toString().split('.').last == value,
      );
    } catch (e) {
      return null;
    }
  }

  /// Create a list of UserBadge from a list of string enum values
  static List<UserBadge> fromStringList(List<String> badges) {
    return badges
        .map((badgeStr) {
          final type = parseType(badgeStr);
          return type != null ? UserBadge.fromType(type) : null;
        })
        .whereType<UserBadge>()
        .toList();
  }
}
