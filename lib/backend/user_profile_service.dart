import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';
import 'package:omusiber/models/user_badge.dart';

class UserProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Helper to get headers with Firebase ID token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _auth.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch user badges from the backend API
  Future<List<UserBadge>> fetchUserBadges(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('${Constants.baseUrl}/users/$userId/badges'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> badgeStrings = data['badges'] ?? [];
        return UserBadge.fromStringList(badgeStrings.cast<String>());
      }
      return [];
    } catch (e) {
      print('Error fetching badges: $e');
      return [];
    }
  }

  /// Search for a user by their school ID
  Future<UserProfile?> searchUserByStudentId(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Constants.baseUrl}/users/search?studentId=${studentId.trim()}',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final badges = await fetchUserBadges(data['uid']);
        return UserProfile.fromFirestore(data, data['uid'], badges: badges);
      }
      return null;
    } catch (e) {
      print('Error searching user: $e');
      return null;
    }
  }

  /// Update user privacy setting
  Future<void> updatePrivacySetting(String uid, bool isPrivate) async {
    try {
      final response = await http.patch(
        Uri.parse('${Constants.baseUrl}/users/profile'),
        headers: await _getHeaders(),
        body: json.encode({'isPrivate': isPrivate}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update privacy setting: ${response.body}');
      }
    } catch (e) {
      print('Error updating privacy setting: $e');
      rethrow;
    }
  }

  /// Update user profile details
  Future<void> updateUserProfile(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('${Constants.baseUrl}/users/profile'),
        headers: await _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update user profile: ${response.body}');
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Fetch a full user profile by UID
  Future<UserProfile?> fetchUserProfile(String uid) async {
    try {
      // If fetching "me", we can use a special endpoint or just the uid
      final url = uid == _auth.currentUser?.uid
          ? '${Constants.baseUrl}/users/me'
          : '${Constants.baseUrl}/users/$uid';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final badges = await fetchUserBadges(uid);
        return UserProfile.fromFirestore(data, uid, badges: badges);
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
}
