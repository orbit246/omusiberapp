import 'package:flutter/material.dart';
import 'package:omusiber/pages/updated_page.dart';
import 'package:omusiber/widgets/event_toggle.dart';
import 'package:omusiber/widgets/profile/profile_stat_widget.dart';
import 'package:omusiber/widgets/shared/navbar.dart';

class AnonProfilePage extends StatefulWidget {
  const AnonProfilePage({super.key});

  @override
  State<AnonProfilePage> createState() => AnonProfilePageState();
}

class AnonProfilePageState extends State<AnonProfilePage> {
  bool _isAnonymous = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: AppNavigationBar(),

      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person, size: 100),
                const SizedBox(height: 20),
                Text(
                  'Henüz Giriş Yapmadınız.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                        minimumSize: MaterialStateProperty.all(const Size(150, 50)),
                      ),
                  onPressed: () {
                    setState(() {});
                  },
                  child: Text(
                    'Giriş Yap',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
