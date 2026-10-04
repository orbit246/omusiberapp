import 'package:flutter/material.dart';
import 'package:omusiber/colors/app_colors.dart';
import 'package:omusiber/pages/new_view/master_view.dart';
import 'package:omusiber/pages/notifications_page.dart';

class FloatingClassicNavbar extends StatelessWidget {
  const FloatingClassicNavbar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = [
    (icon: Icons.home_outlined, label: 'Bugün'),
    (icon: Icons.newspaper_outlined, label: 'Haberler'),
    (icon: Icons.event_outlined, label: 'Etkinlikler'),
    (icon: Icons.groups_outlined, label: 'Topluluk'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.96),
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            ...List<Widget>.generate(_destinations.length, (index) {
              final destination = _destinations[index];
              return Expanded(
                child: _DestinationButton(
                  icon: destination.icon,
                  label: destination.label,
                  selected: currentIndex == index,
                  accentColor: _accentColor(index, colorScheme),
                  onPressed: () => onDestinationSelected(index),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _accentColor(int index, ColorScheme colorScheme) {
    return switch (index) {
      2 => AppColors.amberGlow,
      3 => colorScheme.tertiary,
      1 => colorScheme.secondary,
      _ => colorScheme.primary,
    };
  }
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = selected
        ? accentColor
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? accentColor.withValues(alpha: 0.13) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          splashColor: accentColor.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 21, color: foregroundColor),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppNavigationBar extends StatefulWidget {
  const AppNavigationBar({super.key, this.currentIndex = 0});

  final int currentIndex;

  @override
  State<AppNavigationBar> createState() => App_NavigationBarState();
}

class App_NavigationBarState extends State<AppNavigationBar> {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: widget.currentIndex,
      onTap: (index) {
        if (index == widget.currentIndex) {
          return;
        }

        final Widget destination = switch (index) {
          0 => const MasterView(initialTabIndex: 0),
          1 => const MasterView(initialTabIndex: 1),
          2 => const MasterView(initialTabIndex: 2),
          3 => const MasterView(initialTabIndex: 3),
          _ => const NotificationsPage(),
        };

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Bugün"),
        BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: "Haberler"),
        BottomNavigationBarItem(icon: Icon(Icons.event), label: "Etkinlikler"),
        BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Topluluk"),
      ],
    );
  }
}
