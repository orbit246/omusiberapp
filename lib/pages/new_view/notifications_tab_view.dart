import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';

class NotificationsTabView extends StatefulWidget {
  const NotificationsTabView({super.key});

  @override
  State<NotificationsTabView> createState() => _NotificationsTabViewState();
}

class _NotificationsTabViewState extends State<NotificationsTabView> {
  late Future<List<SavedNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = SimpleNotifications().loadSaved();
  }

  Future<void> _refresh() async {
    setState(() {
      _notificationsFuture = SimpleNotifications().loadSaved();
    });
    await _notificationsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<SavedNotification>>(
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
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off,
                          size: 64,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Henüz bildirim yok",
                          style: TextStyle(
                            fontSize: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            key: const PageStorageKey('notifs_tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await SimpleNotifications().clearSaved();
                          _refresh();
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        label: const Text(
                          "Tümünü Temizle",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final notif = notifications[index];
                    final timeStr = DateFormat(
                      'dd MMM HH:mm',
                    ).format(notif.receivedAt);

                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(
                              Icons.notifications,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            notif.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            timeStr,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Divider(
                          color: colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                      ],
                    );
                  }, childCount: notifications.length),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
