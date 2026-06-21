import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/notifications/notification_navigation_intent.dart';
import 'package:omusiber/backend/user_profile_service.dart';
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
  static const List<String> _defaultTopics = <String>[
    'news',
    'events_all',
    'community_all',
  ];
  static const String _androidNotificationIcon = 'launcher_icon';
  static const String _defaultChannelId = 'akademiz_general';
  static const String _lastNewsDepartmentTopicKey = 'lastNewsDepartmentTopic';
  static const String _legacyLastNewsFacultyTopicKey = 'lastNewsFacultyTopic';
  static const String _newsDepartmentTopicPrefix = 'news-department-';

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
  final UserProfileService _profileService = UserProfileService();

  FirebaseMessaging get _messaging => _fcm ?? FirebaseMessaging.instance;

  static bool _isInitialized = false;
  static bool _listenersRegistered = false;
  static bool _remoteRegistrationConfigured = false;
  static bool _remoteRegistrationRetryScheduled = false;
  static bool _launchIntentCaptured = false;
  static Future<void>? _initializationFuture;
  static const String _staticPrefsKey = 'saved_notifications_v1';
  static const String _enablePromptSeenKey =
      'notification_enable_prompt_seen_v1';

  Future<void> init() async {
    try {
      await ensureInitialized();
      if (!AppStartupController.instance.isFirebaseReady) {
        debugPrint(
          'SimpleNotifications init skipped because Firebase is unavailable.',
        );
        return;
      }
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
          _handleOpenedRemoteMessage(msg);
        });
      }

      if (await checkPermission()) {
        await _configureRemoteRegistration();
      }

      // Cold start: opened from terminated
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        await saveMessage(initial);
        _handleOpenedRemoteMessage(initial);
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

  static Future<void> captureLaunchIntent() async {
    if (_launchIntentCaptured) {
      return;
    }

    _launchIntentCaptured = true;
    await ensureInitialized();

    try {
      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        NotificationNavigationIntentService.instance.queueFromPayload(payload);
      }
    } catch (e) {
      debugPrint('Local notification launch capture failed: $e');
    }

    if (AppStartupController.instance.isFirebaseReady) {
      try {
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          await saveMessage(initialMessage);
          _handleOpenedRemoteMessage(initialMessage);
        }
      } catch (e) {
        debugPrint('Remote notification launch capture failed: $e');
      }
    }
  }

  Future<bool> ensurePermissionForDisplay() async {
    final hasPermission = await checkPermission();
    if (hasPermission) return true;
    return requestPermission();
  }

  Future<bool> shouldShowEnablePrompt() async {
    if (await checkPermission()) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_enablePromptSeenKey) ?? false);
  }

  Future<void> markEnablePromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enablePromptSeenKey, true);
  }

  Future<void> showTestNotification() async {
    await ensureInitialized();

    final item = SavedNotification(
      title: 'Test Bildirimi',
      body: 'Bu bildirim test amaciyla uygulama icinden gonderildi.',
      receivedAt: DateTime.now(),
      data: <String, dynamic>{'type': 'test', 'source': 'local_debug_button'},
    );

    await _saveNotificationItem(item);
    await _showNotificationContent(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: item.title,
      body: item.body,
      channel: _generalChannel,
      payload: jsonEncode(item.data),
    );
  }

  Future<bool> requestPermission() async {
    try {
      await ensureInitialized();

      if (defaultTargetPlatform == TargetPlatform.android) {
        await _androidNotifications?.requestNotificationsPermission();
        final granted =
            (await _androidNotifications?.areNotificationsEnabled()) ?? false;
        if (granted) {
          await _configureRemoteRegistration(forceRefresh: true);
        }
        return granted;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        if (!AppStartupController.instance.isFirebaseReady) {
          return false;
        }
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        if (granted) {
          await _configureRemoteRegistration(forceRefresh: true);
        }
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

    if (!AppStartupController.instance.isFirebaseReady) {
      return false;
    }

    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _configureRemoteRegistration({bool forceRefresh = false}) async {
    if (_remoteRegistrationConfigured && !forceRefresh) {
      return;
    }

    if (!AppStartupController.instance.isFirebaseReady) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final apnsToken = await _waitForApnsToken();
      if (apnsToken == null) {
        debugPrint(
          'APNs token not available yet. Skipping FCM token/topic registration for now.',
        );
        _scheduleRemoteRegistrationRetry();
        return;
      }
      debugPrint('APNs token received.');
    }

    for (final topic in _defaultTopics) {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to FCM topic: $topic');
    }
    await syncNewsDepartmentTopicFromCurrentProfile();

    final token = await _messaging.getToken();
    debugPrint('FCM token: $token');
    _messaging.onTokenRefresh.listen((updatedToken) {
      debugPrint('FCM token refreshed: $updatedToken');
    });
    _remoteRegistrationConfigured = true;
    _remoteRegistrationRetryScheduled = false;
  }

  Future<void> syncNewsDepartmentTopicFromCurrentProfile() async {
    try {
      if (!AppStartupController.instance.isFirebaseReady) {
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await syncNewsDepartmentTopic(departmentKey: null);
        return;
      }

      final profile = await _profileService.fetchUserProfile(user.uid);
      if (profile == null) {
        await syncNewsDepartmentTopic(departmentKey: null);
        return;
      }

      final departmentKey = profile.departmentKey?.trim();
      if (departmentKey == null || departmentKey.isEmpty) {
        await syncNewsDepartmentTopic(departmentKey: null);
        return;
      }

      await syncNewsDepartmentTopic(departmentKey: departmentKey);
    } catch (e) {
      debugPrint('News department topic profile sync failed: $e');
    }
  }

  Future<void> syncNewsDepartmentTopic({required String? departmentKey}) async {
    try {
      if (!AppStartupController.instance.isFirebaseReady) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final oldTopic =
          prefs.getString(_lastNewsDepartmentTopicKey) ??
          prefs.getString(_legacyLastNewsFacultyTopicKey);
      final normalizedDepartmentKey = departmentKey?.trim();
      final newTopic =
          normalizedDepartmentKey == null || normalizedDepartmentKey.isEmpty
          ? null
          : '$_newsDepartmentTopicPrefix$normalizedDepartmentKey';

      if (oldTopic != null && oldTopic != newTopic) {
        await _messaging.unsubscribeFromTopic(oldTopic);
        debugPrint('Unsubscribed from FCM topic: $oldTopic');
      }

      if (newTopic != null && oldTopic != newTopic) {
        await _messaging.subscribeToTopic(newTopic);
        await prefs.setString(_lastNewsDepartmentTopicKey, newTopic);
        await prefs.remove(_legacyLastNewsFacultyTopicKey);
        debugPrint('Subscribed to FCM topic: $newTopic');
      }

      if (newTopic == null) {
        await prefs.remove(_lastNewsDepartmentTopicKey);
        await prefs.remove(_legacyLastNewsFacultyTopicKey);
      }
    } catch (e) {
      debugPrint('News department topic sync failed: $e');
    }
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

  void _scheduleRemoteRegistrationRetry() {
    if (_remoteRegistrationRetryScheduled) {
      return;
    }

    _remoteRegistrationRetryScheduled = true;
    Future<void>.delayed(const Duration(seconds: 5), () async {
      _remoteRegistrationRetryScheduled = false;
      try {
        await _configureRemoteRegistration(forceRefresh: true);
      } catch (e) {
        debugPrint('Remote registration retry failed: $e');
      }
    });
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
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );
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

  static void _handleLocalNotificationResponse(NotificationResponse response) {
    NotificationNavigationIntentService.instance.queueFromPayload(
      response.payload,
    );
  }

  static void _handleOpenedRemoteMessage(RemoteMessage msg) {
    NotificationNavigationIntentService.instance.queueFromData(msg.data);
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

    await _showNotificationContent(
      id:
          msg.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: content.title,
      body: content.body,
      channel: channel,
      payload: jsonEncode(msg.data),
    );
  }

  static Future<void> _showNotificationContent({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationChannel channel,
    String? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: _androidNotificationIcon,
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
      payload: payload,
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

    await _saveNotificationItem(item, messageId: msg.messageId);
  }

  static Future<void> _saveNotificationItem(
    SavedNotification item, {
    String? messageId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_staticPrefsKey) ?? <String>[];

      // Prevent duplicate saving of the same message ID
      if (messageId != null && current.any((s) => s.contains(messageId))) {
        return;
      }

      // Keep it bounded to avoid infinite growth
      const maxItems = 50;
      current.insert(0, jsonEncode(item.toJson()..['messageId'] = messageId));
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
