import 'package:flutter/material.dart';
import 'package:omusiber/models/user_badge.dart';

/// Widget to display a user badge with icon, text, and custom styling
class BadgeWidget extends StatelessWidget {
  final UserBadge badge;
  final bool compact;

  const BadgeWidget({super.key, required this.badge, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactBadge();
    }
    return _buildFullBadge();
  }

  /// Full badge with icon and text
  Widget _buildFullBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badge.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: badge.backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: 18, color: badge.textColor),
          const SizedBox(width: 6),
          Text(
            badge.text,
            style: TextStyle(
              color: badge.textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact badge (icon only) with tooltip
  Widget _buildCompactBadge() {
    return Tooltip(
      message: badge.text,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: badge.backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: badge.backgroundColor.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(badge.icon, size: 16, color: badge.textColor),
      ),
    );
  }
}

/// Widget to display a list of badges horizontally
class BadgeList extends StatelessWidget {
  final List<UserBadge> badges;
  final bool compact;
  final int maxDisplay;

  const BadgeList({
    super.key,
    required this.badges,
    this.compact = false,
    this.maxDisplay = 999,
  });

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayBadges = badges.take(maxDisplay).toList();
    final remainingCount = badges.length - displayBadges.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...displayBadges.map(
          (badge) => BadgeWidget(badge: badge, compact: compact),
        ),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+$remainingCount',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
