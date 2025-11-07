import 'package:flutter/material.dart';

/// A compact, centered action card to fetch the latest news.
/// - Shows a circular icon and label
/// - Plays a scale animation on press
/// - Swaps to a spinner while the async fetch runs
class FetchNewsButton extends StatefulWidget {
  const FetchNewsButton({
    super.key,
    required this.onFetch,
    this.label = 'Haberleri Yenile',
    this.icon = Icons.refresh,
    this.elevation = 2,
  });

  /// Called when the user taps the button. Await your network call here.
  final Future<void> Function() onFetch;

  /// Button text.
  final String label;

  /// Leading icon (inside the circular badge).
  final IconData icon;

  /// Card elevation.
  final double elevation;

  @override
  State<FetchNewsButton> createState() => _FetchNewsButtonState();
}

class _FetchNewsButtonState extends State<FetchNewsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 140),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isLoading) return;

    // Play a quick press animation
    await _pressController.forward();
    await _pressController.reverse();

    setState(() => _isLoading = true);
    try {
      await widget.onFetch();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the whole thing centered on the X axis and compact in width.
    return Align(
      alignment: Alignment.center,
      child: ScaleTransition(
        scale: _scale,
        child: Card(
          elevation: widget.elevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _handleTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min, // don't expand fully
                children: [
                  // Circular leading icon / spinner
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: _isLoading
                          ? SizedBox(
                              key: const ValueKey('spinner'),
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            )
                          : Icon(
                              widget.icon,
                              key: const ValueKey('icon'),
                              size: 20,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isLoading ? 'Yenileniyor...' : widget.label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
