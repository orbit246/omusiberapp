import 'package:flutter/material.dart';
import 'package:omusiber/pages/new_view/master_view.dart';
import 'package:omusiber/pages/notifications_page.dart';
import 'package:omusiber/pages/saved_events_page.dart';

class AppNavigationBar extends StatefulWidget {
  const AppNavigationBar({super.key, this.currentIndex = 0});

  final int currentIndex;

  @override
  State<AppNavigationBar> createState() => App_NavigationBarState();
}

class App_NavigationBarState extends State<AppNavigationBar> {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: widget.currentIndex,
      onTap: (index) {
        if (index == widget.currentIndex) {
          return;
        }

        final Widget destination = switch (index) {
          0 => const MasterView(initialTabIndex: 0),
          1 => const MasterView(initialTabIndex: 1),
          2 => const NotificationsPage(),
          _ => const SavedEventsPage(),
        };

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: "Haberler"),
        BottomNavigationBarItem(icon: Icon(Icons.event), label: "Etkinlikler"),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_on), label: "Bildirimler"),
      ],
    );
  }
}
