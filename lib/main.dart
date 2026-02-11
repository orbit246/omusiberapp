import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:omusiber/colors/app_theme.dart';
import 'package:omusiber/backend/theme_manager.dart';
import 'package:omusiber/pages/agreement_page.dart';
import 'package:omusiber/pages/new_view/master_view.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:omusiber/backend/auth/auth_service.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
          title: 'AkademiZ',

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
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // If we are waiting for the initial auth state, we could show a splash screen.
              // But FirebaseAuth usually emits quickly.
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // If we have a user (Anon or Google), go to MasterView
              if (snapshot.hasData) {
                print("Has Data");
                return const MasterView();
              }

              // Otherwise, show AgreementsPage
              // When they agree, we sign them in Anonymously.
              return AgreementsPage(
                onContinue: (acceptance) async {
                  if (acceptance.consent.accepted &&
                      acceptance.privacy.accepted &&
                      acceptance.terms.accepted) {
                    // Perform Anonymous Login
                    // This will trigger the StreamBuilder to rebuild and show MasterView
                    try {
                      await AuthService().signInAnonymously(
                        acceptedTos: acceptance.terms.accepted,
                        acceptedPrivacy: acceptance.privacy.accepted,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
                      }
                    }
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}
