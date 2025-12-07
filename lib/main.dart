import 'package:flutter/material.dart';
import 'package:omusiber/colors/app_theme.dart';
import 'package:omusiber/backend/theme_manager.dart';
import 'package:omusiber/pages/new_view/master_view.dart'; // Import the manager

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder listens to the ThemeManager singleton
    return ListenableBuilder(
      listenable: ThemeManager(), 
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'OMÜ Siber',
          
          // 1. Bind the ThemeMode to the Manager
          themeMode: ThemeManager().themeMode, 

          // 2. Define Light Theme
          theme: AppTheme.light(),

          // 3. Define Dark Theme
          darkTheme: AppTheme.dark(),

          home: const MasterView(),
        );
      },
    );
  }
}