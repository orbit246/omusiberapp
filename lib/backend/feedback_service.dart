import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackModel {
  final String id;
  final String subject;
  final String message;
  final String? email;
  final DateTime timestamp;

  FeedbackModel({
    required this.id,
    required this.subject,
    required this.message,
    this.email,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'message': message,
    'email': email,
    'timestamp': timestamp.toIso8601String(),
  };

  factory FeedbackModel.fromJson(Map<String, dynamic> json) => FeedbackModel(
    id: json['id'] as String,
    subject: json['subject'] as String,
    message: json['message'] as String,
    email: json['email'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  static const _historyKey = 'feedback_history_v1';
  String get _baseUrl => Constants.baseUrl;

  Future<bool> sendFeedback({
    required String subject,
    required String message,
    String? email,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final now = DateTime.now();

      print("📝 [FeedbackService] Sending feedback to: $_baseUrl/feedback");
      final response = await http.post(
        Uri.parse('$_baseUrl/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'subject': subject,
          'message': message,
          'email': email,
          'userId': user?.uid,
          'platform': 'android',
          'timestamp': now.toIso8601String(),
        }),
      );

      print("📝 [FeedbackService] Status code: ${response.statusCode}");
      if (response.statusCode != 200 && response.statusCode != 201) {
        print("📝 [FeedbackService] Response body: ${response.body}");
      }

      final success = response.statusCode == 200 || response.statusCode == 201;

      if (success) {
        await _saveLocally(
          FeedbackModel(
            id: now.millisecondsSinceEpoch.toString(),
            subject: subject,
            message: message,
            email: email,
            timestamp: now,
          ),
        );
      }

      return success;
    } catch (e) {
      print("📝 [FeedbackService] Error sending feedback: $e");
      return false;
    }
  }

  Future<void> _saveLocally(FeedbackModel feedback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getFeedbackHistory();
      current.insert(0, feedback);

      // Limit to last 20 feedbacks
      if (current.length > 20) current.removeRange(20, current.length);

      final list = current.map((e) => json.encode(e.toJson())).toList();
      await prefs.setStringList(_historyKey, list);
      print(
        "📝 [FeedbackService] Feedback saved locally. Total: ${current.length}",
      );
    } catch (e) {
      print("📝 [FeedbackService] Error saving feedback locally: $e");
    }
  }

  Future<List<FeedbackModel>> getFeedbackHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_historyKey) ?? [];
      return list.map((e) => FeedbackModel.fromJson(json.decode(e))).toList();
    } catch (e) {
      return [];
    }
  }
}
