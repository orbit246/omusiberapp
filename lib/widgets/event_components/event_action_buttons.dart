import 'package:flutter/material.dart';

class EventActionButtons extends StatelessWidget {
  const EventActionButtons({
    super.key,
    required this.onJoin,
    required this.onBookmark,
    required this.onShare,
    required this.isSaved,
  });

  final VoidCallback? onJoin;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.event_available, size: 18),
            label: const Text("Detaylar"),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ActionIconButton(
          icon: !isSaved ? Icons.bookmark_border : Icons.bookmark,
          isActive: isSaved,
          onTap: onBookmark,
        ),
        const SizedBox(width: 8),
        ActionIconButton(icon: Icons.share_outlined, onTap: onShare),
      ],
    );
  }
}

class ActionIconButton extends StatelessWidget {
  const ActionIconButton({
    super.key,
    required this.icon,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? cs.primary.withOpacity(0.2) : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
