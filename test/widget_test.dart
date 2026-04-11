import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omusiber/colors/app_theme.dart';
import 'package:omusiber/pages/new_view/master_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MasterView opens on Haberler tab', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const MasterView(),
      ),
    );

    expect(find.text('Haberler'), findsWidgets);
    expect(find.text('Etkinlikler'), findsOneWidget);
    expect(find.text('Topluluk'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
