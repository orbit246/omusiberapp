import 'dart:convert';
import 'package:firebase_core/firebase_core.dart'; // Added
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await SimpleNotifications.saveMessage(message);
}

class SimpleNotifications {
  static const _topic = 'events_all';

  final FirebaseMessaging _fcm;

  SimpleNotifications({FirebaseMessaging? fcm})
    : _fcm = fcm ?? FirebaseMessaging.instance;

  static bool _isInitializing = false;
  static const String _staticPrefsKey = 'saved_notifications_v1';

  Future<void> init() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      // Background handler must be set before init or inside init but as top-level
      // FirebaseMessaging.onBackgroundMessage is usually set in main.dart
      // FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler); // This should be called in main.dart

      // Permissions
      await requestPermission();

      // Subscribe to topic
      await _fcm.subscribeToTopic(_topic);

      // Foreground handler
      FirebaseMessaging.onMessage.listen((msg) async {
        await saveMessage(msg);
      });

      // Background open handler
      FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
        await saveMessage(msg); // save anyway
      });

      // Cold start: opened from terminated
      final initial = await _fcm.getInitialMessage();
      if (initial != null) {
        await saveMessage(initial);
      }
    } catch (e) {
      // General error during init
    } finally {
      // _isInitializing stays true? Or resets?
    }
  }

  Future<void> requestPermission() async {
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      // "A request for permissions is already running" or denied
    }
  }

  /// Returns true if permission is granted, false otherwise.
  Future<bool> checkPermission() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Saves a message to notification history.
  /// Static so it can be called from background handlers.
  static Future<void> saveMessage(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;

    final item = SavedNotification(
      title: n.title ?? 'Bildirim',
      body: n.body ?? '',
      receivedAt: DateTime.now(),
      data: msg.data,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_staticPrefsKey) ?? <String>[];

      // Prevent duplicate saving of the same message ID
      if (msg.messageId != null &&
          current.any((s) => s.contains(msg.messageId!))) {
        return;
      }

      // Keep it bounded to avoid infinite growth
      const maxItems = 50;
      current.insert(
        0,
        jsonEncode(item.toJson()..['messageId'] = msg.messageId),
      );
      if (current.length > maxItems) {
        current.removeRange(maxItems, current.length);
      }

      await prefs.setStringList(_staticPrefsKey, current);
    } catch (e) {
      // Silently fail if storage error
    }
  }

  Future<List<SavedNotification>> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_staticPrefsKey) ?? <String>[];
    return list.map((s) {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return SavedNotification.fromJson(j);
    }).toList();
  }

  Future<void> clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_staticPrefsKey);
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
