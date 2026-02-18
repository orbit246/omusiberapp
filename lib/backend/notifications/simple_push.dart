import 'dart:convert';
import 'package:firebase_core/firebase_core.dart'; // Added
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await SimpleNotifications.saveMessage(message);
}

class SimpleNotifications {
  static const _topic = 'events_all';
  static const String _defaultChannelId = 'akademiz_general';

  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
        _defaultChannelId,
        'Genel Bildirimler',
        description: 'Genel uygulama bildirimleri',
        importance: Importance.defaultImportance,
      );

  static const AndroidNotificationChannel _eventsChannel =
      AndroidNotificationChannel(
        'akademiz_events',
        'Etkinlik Bildirimleri',
        description: 'Etkinlikler ile ilgili bildirimler',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _announcementsChannel =
      AndroidNotificationChannel(
        'akademiz_announcements',
        'Duyuru Bildirimleri',
        description: 'Haber ve duyuru bildirimleri',
        importance: Importance.high,
      );

  final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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

      await _initLocalNotifications();
      await _registerAndroidChannels();

      // Permissions
      await ensurePermissionForDisplay();

      // Ensure foreground notifications are shown
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Subscribe to topic
      await _fcm.subscribeToTopic(_topic);

      // Foreground handler
      FirebaseMessaging.onMessage.listen((msg) async {
        await saveMessage(msg);
        await _showForegroundNotification(msg);
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
      print("SimpleNotifications init error: $e");
    } finally {
      // _isInitializing stays true? Or resets?
    }
  }

  Future<bool> ensurePermissionForDisplay() async {
    final hasPermission = await checkPermission();
    if (hasPermission) return true;
    return requestPermission();
  }

  Future<bool> requestPermission() async {
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
      return await checkPermission();
    } catch (e) {
      // "A request for permissions is already running" or denied
      return false;
    }
  }

  /// Returns true if permission is granted, false otherwise.
  Future<bool> checkPermission() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);
  }

  Future<void> _registerAndroidChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(_generalChannel);
    await androidPlugin.createNotificationChannel(_eventsChannel);
    await androidPlugin.createNotificationChannel(_announcementsChannel);
  }

  Future<void> _showForegroundNotification(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;

    final channel = _resolveChannel(msg);

    await _localNotifications.show(
      msg.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      n.title ?? 'Bildirim',
      n.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
      ),
      payload: jsonEncode(msg.data),
    );
  }

  AndroidNotificationChannel _resolveChannel(RemoteMessage msg) {
    final rawType = (msg.data['type'] ?? msg.data['category'] ?? '')
        .toString()
        .toLowerCase();
    if (rawType.contains('event')) return _eventsChannel;
    if (rawType.contains('news') || rawType.contains('announcement')) {
      return _announcementsChannel;
    }
    return _generalChannel;
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
