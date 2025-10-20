import 'package:flutter/material.dart';

class SplashDiagonalReveal extends StatefulWidget {
  const SplashDiagonalReveal({
    super.key,
    required this.logo,
    this.duration = const Duration(milliseconds: 1200),
    this.feather = 0.15,
  });

  final Widget logo;
  final Duration duration;
  final double feather;

  @override
  State<SplashDiagonalReveal> createState() => SplashDiagonalRevealState();
}

class SplashDiagonalRevealState extends State<SplashDiagonalReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: widget.duration);

  bool _running = true;

  @override
  void initState() {
    super.initState();
    _loop();
  }

  Future<void> _loop() async {
    // Runs until stopped manually
    while (_running) {
      await _ctrl.forward();
      await _ctrl.reverse();
    }
  }

  void stop() {
    setState(() => _running = false);
    _ctrl.stop();
  }

  @override
  void dispose() {
    _running = false;
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_ctrl.value);
          final edge = t.clamp(0.0, 1.0);
          final f = widget.feather.clamp(0.0, 0.49);
          final a = (edge - f).clamp(0.0, 1.0);
          final b = edge;
          final c = (edge + 0.0001).clamp(0.0, 1.0);
    
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.transparent, Colors.transparent],
                stops: [a, b, c],
              ).createShader(bounds);
            },
            child: widget.logo,
          );
        },
      ),
    );
  }
}
