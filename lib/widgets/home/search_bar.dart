import 'package:flutter/material.dart';

/// Compact search icon that expands to a full-width search bar.
/// - Starts as a square (collapsedSize).
/// - Expands smoothly to max available width.
/// - Auto-focuses on expand; collapses on focus loss if empty.
/// - Avoids overflow when collapsed (no Flexible/Expanded in that state).
class ExpandableSearchBar extends StatefulWidget {
  const ExpandableSearchBar({
    super.key,
    this.hintText = 'Etkinlik ara...',
    this.onChanged,
    this.onSubmitted,
    this.initiallyExpanded = false,
    this.collapsedSize = 160.0,
    this.borderRadius = 8.0,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.elevation = 1.0,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool initiallyExpanded;
  final double collapsedSize;
  final double borderRadius;
  final Duration duration;
  final Curve curve;
  final double elevation;

  @override
  State<ExpandableSearchBar> createState() => _ExpandableSearchBarState();
}

class _ExpandableSearchBarState extends State<ExpandableSearchBar> {
  late final FocusNode _focusNode = FocusNode();
  late final TextEditingController _controller = TextEditingController();
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;

    // Collapse when losing focus if empty
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _controller.text.isEmpty) {
        setState(() => _expanded = false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _expandAndFocus() {
    if (_expanded) return;
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    if (!_focusNode.hasFocus) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVar = theme.colorScheme.onSurfaceVariant;
    final surface = theme.colorScheme.surface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsed = widget.collapsedSize.clamp(0.0, constraints.maxWidth);
        final targetWidth = _expanded ? constraints.maxWidth : collapsed;

        return AnimatedContainer(
          width: targetWidth,
          duration: widget.duration,
          curve: widget.curve,
          alignment: Alignment.centerLeft,
          child: Material(
            color: surface,
            elevation: widget.elevation,
            clipBehavior: Clip.hardEdge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              side: BorderSide(color: onSurfaceVar.withOpacity(0.12)),
            ),
            child: InkWell(
              onTap: _expandAndFocus,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Icon(Icons.search, color: onSurfaceVar),
                    const SizedBox(width: 8),

                    // Collapsed label (no Flexible here -> no overflow)
                    if (!_expanded)
                      Text('Etkinlik Ara', style: theme.textTheme.bodyLarge?.copyWith(color: onSurfaceVar)),

                    // Expanded input (only builds when expanded)
                    if (_expanded) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            focusNode: _focusNode,
                            controller: _controller,
                            onChanged: widget.onChanged,
                            onSubmitted: widget.onSubmitted,
                            textInputAction: TextInputAction.search,
                            style: theme.textTheme.bodyLarge?.copyWith(color: onSurfaceVar),
                            decoration: InputDecoration(
                              hintText: widget.hintText,
                              hintStyle: theme.textTheme.bodyLarge?.copyWith(color: onSurfaceVar.withOpacity(0.6)),
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.all(8),
                            ),
                          ),
                        ),
                      ),

                      // Actions react to text changes without setState via ValueListenableBuilder
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) {
                          final hasText = value.text.isNotEmpty;
                          return Row(
                            children: [
                              if (hasText)
                                IconButton(
                                  tooltip: 'Temizle',
                                  icon: const Icon(Icons.close),
                                  color: onSurfaceVar,
                                  onPressed: _clear,
                                  splashRadius: 18,
                                ),
                              IconButton(
                                tooltip: 'Kapat',
                                icon: const Icon(Icons.keyboard_arrow_up),
                                color: onSurfaceVar,
                                onPressed: () {
                                  _focusNode.unfocus();
                                  setState(() => _expanded = false);
                                },
                                splashRadius: 18,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
