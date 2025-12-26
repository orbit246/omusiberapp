import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';
import 'package:omusiber/widgets/home/simple_appbar.dart';
import 'package:omusiber/widgets/shared/navbar.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<SavedNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = SimpleNotifications().loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppNavigationBar(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SimpleAppbar(title: "Bildirimler"),
      ),
      body: SafeArea(
        child: FutureBuilder<List<SavedNotification>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Hata: ${snapshot.error}"));
            }

            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "Henüz bildirim yok",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _notificationsFuture = SimpleNotifications().loadSaved();
                });
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: notifications.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'dd MMM HH:mm',
                                ).format(notif.receivedAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(notif.body),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
