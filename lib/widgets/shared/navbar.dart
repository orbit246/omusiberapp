import 'package:flutter/material.dart';
import 'package:omusiber/pages/notifications_page.dart';
import 'package:omusiber/pages/profile_page.dart';
import 'package:omusiber/pages/saved_events_page.dart';
import 'package:omusiber/pages/updated_page.dart';

class AppNavigationBar extends StatefulWidget {
  const AppNavigationBar({super.key});

  @override
  State<AppNavigationBar> createState() => App_NavigationBarState();
}

class App_NavigationBarState extends State<AppNavigationBar> {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: SimplifiedHomePageState.selectedIndexNotifier.value,
      onTap: (index) {
        setState(() {
          SimplifiedHomePageState.selectedIndexNotifier.value = index;

          // Update the UI or perform any other actions based on the selected index
          // For example, you might want to navigate to a different page
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) {
                switch (index) {
                  case 0:
                    return SimplifiedHomePageState(); // Replace with your actual event page widget
                  case 1:
                    return NotificationsPage(); // Replace with your actual profile page widget
                    case 2:
                    return SavedEventsPage();
                  default:
                    return SavedEventsPage(); // Fallback to a default page
                }
              },
            ),
          );
        });
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.event), label: "Etkinlikler"),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_on), label: "Bildirimler"),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "Kaydedilenler"),
      ],
    );
  }
}
