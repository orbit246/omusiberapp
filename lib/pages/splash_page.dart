import 'package:flutter/material.dart';
import 'package:omusiber/widgets/image_splash.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final GlobalKey<SplashDiagonalRevealState> _key = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Simulate async loading (API, assets, etc.)
    Future.delayed(const Duration(seconds: 30), () {
      _key.currentState?.stop(); // stop the looping animation
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Center(
              child: SplashDiagonalReveal(
                key: _key,
                logo: Image.asset('assets/logo.png', width: 180),
                duration: const Duration(milliseconds: 1200),
              ),
            ),
            Text("Yükleniyor...", style: Theme.of(context).textTheme.headlineLarge),
            Spacer(),
            CircularProgressIndicator(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
