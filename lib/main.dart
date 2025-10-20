import 'package:flutter/material.dart';
import 'package:omusiber/colors/app_theme.dart';
import 'package:omusiber/pages/anon_profile_page%20.dart';
import 'package:omusiber/pages/event_details_page.dart';
import 'package:omusiber/pages/mainpage.dart';
import 'package:omusiber/pages/mainpagew.dart';
import 'package:omusiber/pages/splash_page.dart';
import 'package:omusiber/pages/updated_page.dart';
import 'package:omusiber/widgets/event_details/event_details_appbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 👈 this is required before using plugins

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: SimplifiedHomePageState(),
    );
  }
}
