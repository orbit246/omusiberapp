import 'package:flutter/material.dart';

class NotificationsTabView extends StatelessWidget {
  const NotificationsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      key: const PageStorageKey('notifs_tab'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(Icons.notifications, size: 20, color: colorScheme.primary),
                      ),
                      title: const Text(
                        "Yeni bir duyuru yayınlandı",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "2 saat önce • Sistem",
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                    Divider(color: colorScheme.outlineVariant.withOpacity(0.3)),
                  ],
                );
              },
              childCount: 8,
            ),
          ),
        ),
      ],
    );
  }
}