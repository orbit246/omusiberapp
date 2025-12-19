import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/colors/app_theme.dart';
import 'package:omusiber/backend/theme_manager.dart';
import 'package:omusiber/pages/agreement_page.dart';
import 'package:omusiber/pages/new_view/master_view.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeManager(),
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navKey,
          debugShowCheckedModeBanner: false,
          title: 'OMÜ Siber',

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
          home: Constants.debugMode
              ? MasterView()
              : AgreementsPage(
                  onContinue: (acceptance) async {
                    if (acceptance.consent.accepted &&
                        acceptance.privacy.accepted &&
                        acceptance.terms.accepted) {
                      navKey.currentState!.pushReplacement(
                        MaterialPageRoute(builder: (_) => const MasterView()),
                      );
                    }
                  },
                ),
        );
      },
    );
  }
}
