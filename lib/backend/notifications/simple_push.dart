import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:omusiber/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SimpleNotifications.ensureInitialized();
  await SimpleNotifications.handleRemoteMessage(
    message,
    showForegroundNotification: false,
    showBackgroundDataNotification: true,
  );
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

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  SimpleNotifications({FirebaseMessaging? fcm}) : _fcm = fcm;

  final FirebaseMessaging? _fcm;

  FirebaseMessaging get _messaging => _fcm ?? FirebaseMessaging.instance;

  static bool _isInitialized = false;
  static bool _listenersRegistered = false;
  static Future<void>? _initializationFuture;
  static const String _staticPrefsKey = 'saved_notifications_v1';
  static const String _permissionPromptedKey =
      'notification_permission_prompted_v1';

  Future<void> init() async {
    try {
      await ensureInitialized();
      await _messaging.setAutoInitEnabled(true);

      // Ensure foreground notifications are shown
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!_listenersRegistered) {
        _listenersRegistered = true;

        FirebaseMessaging.onMessage.listen((msg) async {
          await handleRemoteMessage(
            msg,
            showForegroundNotification: true,
            showBackgroundDataNotification: false,
          );
        });

        FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
          await saveMessage(msg);
        });
      }

      await _configureRemoteRegistration();
      await _requestPermissionIfNeeded();

      // Cold start: opened from terminated
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        await saveMessage(initial);
      }
    } catch (e) {
      debugPrint('SimpleNotifications init error: $e');
    } finally {
      try {
        await _messaging.setAutoInitEnabled(false);
      } catch (e) {
        debugPrint('SimpleNotifications auto-init disable failed: $e');
      }
    }
  }

  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }

    _initializationFuture = _initializeCore();
    try {
      await _initializationFuture;
      _isInitialized = true;
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  Future<bool> ensurePermissionForDisplay() async {
    final hasPermission = await checkPermission();
    if (hasPermission) return true;
    return requestPermission();
  }

  Future<void> _requestPermissionIfNeeded() async {
    if (await checkPermission()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_permissionPromptedKey) ?? false;
    if (alreadyPrompted) {
      return;
    }

    await requestPermission();
    await prefs.setBool(_permissionPromptedKey, true);
  }

  Future<bool> requestPermission() async {
    try {
      await ensureInitialized();

      if (defaultTargetPlatform == TargetPlatform.android) {
        await _androidNotifications?.requestNotificationsPermission();
        return (await _androidNotifications?.areNotificationsEnabled()) ??
            false;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      return await checkPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  /// Returns true if permission is granted, false otherwise.
  Future<bool> checkPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return (await _androidNotifications?.areNotificationsEnabled()) ?? false;
    }

    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _configureRemoteRegistration() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final apnsToken = await _waitForApnsToken();
      if (apnsToken == null) {
        debugPrint(
          'APNs token not available yet. Skipping FCM token/topic registration for now.',
        );
        return;
      }
      debugPrint('APNs token received.');
    }

    await _messaging.subscribeToTopic(_topic);

    final token = await _messaging.getToken();
    debugPrint('FCM token: $token');
    _messaging.onTokenRefresh.listen((updatedToken) {
      debugPrint('FCM token refreshed: $updatedToken');
    });
  }

  Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final token = await _messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) {
        return token;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  static Future<void> _initializeCore() async {
    await _initLocalNotifications();
    await _registerAndroidChannels();
  }

  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );
    await _localNotifications.initialize(initSettings);
  }

  static AndroidFlutterLocalNotificationsPlugin? get _androidNotifications =>
      _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  static Future<void> _registerAndroidChannels() async {
    final androidPlugin = _androidNotifications;
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(_generalChannel);
    await androidPlugin.createNotificationChannel(_eventsChannel);
    await androidPlugin.createNotificationChannel(_announcementsChannel);
  }

  static Future<void> handleRemoteMessage(
    RemoteMessage msg, {
    required bool showForegroundNotification,
    required bool showBackgroundDataNotification,
  }) async {
    await saveMessage(msg);

    if (showForegroundNotification) {
      await _showLocalNotification(msg);
      return;
    }

    if (showBackgroundDataNotification && msg.notification == null) {
      await _showLocalNotification(msg);
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage msg) async {
    final content = _extractContent(msg);
    if (content == null) return;

    final channel = _resolveChannel(msg);

    await _localNotifications.show(
      msg.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content.title,
      content.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(msg.data),
    );
  }

  static AndroidNotificationChannel _resolveChannel(RemoteMessage msg) {
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
    final content = _extractContent(msg);
    if (content == null) return;

    final item = SavedNotification(
      title: content.title,
      body: content.body,
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

  static _NotificationContent? _extractContent(RemoteMessage msg) {
    final notification = msg.notification;
    final data = msg.data;

    final title =
        notification?.title ??
        data['title']?.toString() ??
        data['notification_title']?.toString() ??
        'Bildirim';

    final body =
        notification?.body ??
        data['body']?.toString() ??
        data['message']?.toString() ??
        data['notification_body']?.toString() ??
        '';

    if (title.trim().isEmpty && body.trim().isEmpty) {
      return null;
    }

    return _NotificationContent(title: title, body: body);
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

class _NotificationContent {
  const _NotificationContent({required this.title, required this.body});

  final String title;
  final String body;
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
