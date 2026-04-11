import 'package:flutter/material.dart';

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.margin = EdgeInsets.zero,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry margin;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = Color.lerp(
      colorScheme.surface,
      colorScheme.surfaceContainerHighest,
      0.42,
    )!;
    final highlight = Color.lerp(base, Colors.white, 0.28)!;

    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(color: base, borderRadius: widget.borderRadius),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final x = -1.2 + (_controller.value * 2.4);
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(x - 0.5, 0),
                end: Alignment(x + 0.5, 0),
                colors: [base, base, highlight, base, base],
                stops: const [0.0, 0.38, 0.5, 0.62, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: base,
            borderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }
}
