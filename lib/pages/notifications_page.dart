import 'package:flutter/material.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/home/simple_appbar.dart';
import 'package:omusiber/widgets/notifications/items/event_cancelled.dart';
import 'package:omusiber/widgets/notifications/items/event_created.dart';
import 'package:omusiber/widgets/notifications/items/event_reminder.dart';
import 'package:omusiber/widgets/notifications/notifications_appbar.dart';
import 'package:omusiber/widgets/shared/navbar.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: AppNavigationBar(),
      appBar: PreferredSize(preferredSize: const Size.fromHeight(60), child: SimpleAppbar(title: "Bildirimler")),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                EventCancelled(),
                SizedBox(height: 20),
                EventCreated(),
                SizedBox(height: 20),
                EventReminder(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
