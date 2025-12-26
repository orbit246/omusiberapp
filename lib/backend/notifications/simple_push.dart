import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimpleNotifications {
  static const _topic = 'events_all';
  static const _prefsKey = 'saved_notifications_v1';

  final FirebaseMessaging _fcm;

  SimpleNotifications({FirebaseMessaging? fcm})
    : _fcm = fcm ?? FirebaseMessaging.instance;

  Future<void> init() async {
    // Permissions
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Subscribe to topic
    await _fcm.subscribeToTopic(_topic);

    // Foreground handler
    FirebaseMessaging.onMessage.listen((msg) async {
      await _save(msg);
    });

    // Background open handler
    FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
      await _save(msg); // save anyway
    });

    // Cold start: opened from terminated
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      await _save(initial);
    }
  }

  Future<void> _save(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;

    final item = SavedNotification(
      title: n.title ?? 'Bildirim',
      body: n.body ?? '',
      receivedAt: DateTime.now(),
      data: msg.data,
    );

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_prefsKey) ?? <String>[];

    // Keep it bounded to avoid infinite growth
    const maxItems = 50;
    current.insert(0, jsonEncode(item.toJson()));
    if (current.length > maxItems) {
      current.removeRange(maxItems, current.length);
    }

    await prefs.setStringList(_prefsKey, current);
  }

  Future<List<SavedNotification>> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? <String>[];
    return list.map((s) {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return SavedNotification.fromJson(j);
    }).toList();
  }

  Future<void> clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

class SavedNotification {
  SavedNotification({
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.data,
  });

  final String title;
  final String body;
  final DateTime receivedAt;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'receivedAt': receivedAt.toIso8601String(),
    'data': data,
  };

  static SavedNotification fromJson(Map<String, dynamic> json) {
    return SavedNotification(
      title: (json['title'] as String?) ?? 'Bildirim',
      body: (json['body'] as String?) ?? '',
      receivedAt:
          DateTime.tryParse((json['receivedAt'] as String?) ?? '') ??
          DateTime.now(),
      data:
          (json['data'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
    );
  }
}
