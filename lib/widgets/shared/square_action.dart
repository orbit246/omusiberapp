import 'package:flutter/material.dart';

class SquareEventAction extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;

  const SquareEventAction({
    super.key,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceVariant,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(width: 46, height: 46, child: Icon(icon, size: 24, color: cs.onSurface)),
      ),
    );
  }
}
