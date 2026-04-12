import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/colors/app_theme.dart';
import 'package:omusiber/backend/theme_manager.dart';
import 'package:omusiber/pages/new_view/master_view.dart';
import 'package:omusiber/pages/agreement_page.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStartupController.instance.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeManager(),
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navKey,
          debugShowCheckedModeBanner: false,
          title: 'AkademiZ',
          scrollBehavior: const AppScrollBehavior(),

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'), // İngilizce
            Locale('tr', 'TR'), // Türkçe
          ],
          locale: const Locale(
            'tr',
            'TR',
          ), // Varsayılan dili Türkçe yapabilirsiniz
          // -------------------------------
          themeMode: ThemeManager().themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const MasterView(),
        );
      },
    );
  }
}

class _StartupShell extends StatelessWidget {
  const _StartupShell();

  @override
  Widget build(BuildContext context) {
    final controller = AppStartupController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Stack(
          children: [
            const MasterView(),
            if (controller.isBooting)
              const Positioned(top: 0, left: 0, right: 0, child: _BootStripe()),
            if (controller.needsAgreement)
              Positioned.fill(
                child: AgreementsPage(onContinue: controller.acceptAgreements),
              ),
            if (controller.stage == AppStartupStage.failed)
              Positioned.fill(
                child: _StartupErrorOverlay(
                  error: controller.lastError,
                  onRetry: controller.retry,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BootStripe extends StatelessWidget {
  const _BootStripe();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: const LinearProgressIndicator(minHeight: 2),
    );
  }
}

class _StartupErrorOverlay extends StatelessWidget {
  const _StartupErrorOverlay({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surface.withValues(alpha: 0.96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: colorScheme.error,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Baslangic baglantisi kurulamadi',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => onRetry(),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
