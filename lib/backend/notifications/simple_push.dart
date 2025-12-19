// import 'dart:convert';
// import 'dart:io';

// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class SimpleNotifications {
//   static const _topic = 'events_all';
//   static const _prefsKey = 'saved_notifications_v1';

//   final FirebaseMessaging _fcm;
//   final FlutterLocalNotificationsPlugin _local;

//   SimpleNotifications({
//     FirebaseMessaging? fcm,
//     FlutterLocalNotificationsPlugin? local,
//   })  : _fcm = fcm ?? FirebaseMessaging.instance,
//         _local = local ?? FlutterLocalNotificationsPlugin();

//   Future<void> init() async {
//     // Permissions
//     await _fcm.requestPermission(alert: true, badge: true, sound: true);

//     // Local notifications init
//     const android = AndroidInitializationSettings('@mipmap/ic_launcher');
//     const ios = DarwinInitializationSettings();
//     const init = InitializationSettings(android: android, iOS: ios);
//     await _local.initialize(init);

//     // Android channel
//     if (Platform.isAndroid) {
//       const channel = AndroidNotificationChannel(
//         'events_channel',
//         'Events',
//         description: 'Event notifications',
//         importance: Importance.high,
//       );
//       await _local
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//           ?.createNotificationChannel(channel);
//     }

//     // Subscribe to topic
//     await _fcm.subscribeToTopic(_topic);

//     // Foreground handler
//     FirebaseMessaging.onMessage.listen((msg) async {
//       await _showAndSave(msg);
//     });

//     // Background open handler
//     FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
//       await _save(msg); // save anyway
//     });

//     // Cold start: opened from terminated
//     final initial = await _fcm.getInitialMessage();
//     if (initial != null) {
//       await _save(initial);
//     }
//   }

//   Future<void> _showAndSave(RemoteMessage msg) async {
//     await _save(msg);

//     final n = msg.notification;
//     if (n == null) return;

//     await _local.show(
//       DateTime.now().millisecondsSinceEpoch ~/ 1000,
//       n.title ?? 'Bildirim',
//       n.body ?? '',
//       // NotificationDetails(
//       //   android: AndroidNotificationDetails(
//       //     'events_channel',
//       //     'Events',
//       //     importance: Importance.high,
//       //     priority: Priority.high,
//       //   ),
//       //   iOS: const DarwinNotificationDetails(),
//       // ),
//     );
//   }

//   Future<void> _save(RemoteMessage msg) async {
//     final n = msg.notification;
//     if (n == null) return;

//     final item = SavedNotification(
//       title: n.title ?? 'Bildirim',
//       body: n.body ?? '',
//       receivedAt: DateTime.now(),
//       data: msg.data,
//     );

//     final prefs = await SharedPreferences.getInstance();
//     final current = prefs.getStringList(_prefsKey) ?? <String>[];

//     // Keep it bounded to avoid infinite growth
//     const maxItems = 50;
//     current.insert(0, jsonEncode(item.toJson()));
//     if (current.length > maxItems) {
//       current.removeRange(maxItems, current.length);
//     }

//     await prefs.setStringList(_prefsKey, current);
//   }

//   Future<List<SavedNotification>> loadSaved() async {
//     final prefs = await SharedPreferences.getInstance();
//     final list = prefs.getStringList(_prefsKey) ?? <String>[];
//     return list.map((s) {
//       final j = jsonDecode(s) as Map<String, dynamic>;
//       return SavedNotification.fromJson(j);
//     }).toList();
//   }

//   Future<void> clearSaved() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_prefsKey);
//   }
// }

// class SavedNotification {
//   SavedNotification({
//     required this.title,
//     required this.body,
//     required this.receivedAt,
//     required this.data,
//   });

//   final String title;
//   final String body;
//   final DateTime receivedAt;
//   final Map<String, dynamic> data;

//   Map<String, dynamic> toJson() => {
//         'title': title,
//         'body': body,
//         'receivedAt': receivedAt.toIso8601String(),
//         'data': data,
//       };

//   static SavedNotification fromJson(Map<String, dynamic> json) {
//     return SavedNotification(
//       title: (json['title'] as String?) ?? 'Bildirim',
//       body: (json['body'] as String?) ?? '',
//       receivedAt: DateTime.tryParse((json['receivedAt'] as String?) ?? '') ?? DateTime.now(),
//       data: (json['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
//     );
//   }
// }
