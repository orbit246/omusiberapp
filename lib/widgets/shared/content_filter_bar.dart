import 'package:flutter/material.dart';

class ContentFilterBar extends StatelessWidget {
  const ContentFilterBar({
    super.key,
    required this.sortLabel,
    required this.filterLabel,
    required this.hasActiveFilters,
    required this.onOpen,
    this.selectedItems = const <String>[],
    this.onClear,
    this.isLoading = false,
  });

  final String sortLabel;
  final String filterLabel;
  final bool hasActiveFilters;
  final VoidCallback onOpen;
  final List<String> selectedItems;
  final VoidCallback? onClear;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accentColor = Color(0xFF3D6DFF);
    final borderRadius = BorderRadius.circular(22);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF152746),
                    Color(0xFF0F1E34),
                    Color(0xFF0B1529),
                  ],
                ),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -18,
                    top: -14,
                    child: IgnorePointer(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.04),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.filter_alt_outlined,
                              size: 20,
                              color: accentColor,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Filtrele',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (isLoading) ...[
                              const SizedBox(width: 10),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                        _FilterPill(
                          label: sortLabel,
                          onTap: onOpen,
                          active: true,
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: filterLabel,
                          onTap: onOpen,
                          active: hasActiveFilters,
                        ),
                        if (hasActiveFilters && onClear != null) ...[
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onClear,
                              borderRadius: BorderRadius.circular(999),
                              child: Ink(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34151A),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selectedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectedItems
                    .map(
                      (item) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF17253D),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Text(
                            item,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.onTap,
    required this.active,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF3D6DFF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? [
                      accentColor.withValues(alpha: 0.95),
                      accentColor.withValues(alpha: 0.78),
                    ]
                  : const [Color(0xFF1A2740), Color(0xFF111C31)],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? accentColor.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active ? Colors.white : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContentFilterEmptyState extends StatelessWidget {
  const ContentFilterEmptyState({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_off_rounded,
              size: 32,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Filtreleri değiştirip tekrar deneyebilirsin.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
