import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omusiber/backend/app_startup_controller.dart';

class ApiIdentityService {
  ApiIdentityService._();

  static final ApiIdentityService instance = ApiIdentityService._();

  static const String _localIdentityKey = 'api_local_identity_v1';

  Future<String> getLocalPersistentId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_localIdentityKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final random = Random();
    final generated =
        'local-firebase-failed-${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(1 << 32)}';
    await prefs.setString(_localIdentityKey, generated);
    return generated;
  }

  Future<String?> tryGetFirebaseUid() async {
    if (!AppStartupController.instance.isFirebaseReady) {
      return null;
    }

    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (error) {
      debugPrint('ApiIdentityService uid fallback activated: $error');
      return null;
    }
  }

  Future<String?> tryGetFirebaseToken({bool forceRefresh = false}) async {
    if (!AppStartupController.instance.isFirebaseReady) {
      return null;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return null;
      }

      final token = await user.getIdToken(forceRefresh);
      if (token == null || token.trim().isEmpty) {
        return null;
      }
      return token;
    } catch (error) {
      debugPrint('ApiIdentityService token fallback activated: $error');
      return null;
    }
  }

  Future<Map<String, String>> buildHeaders({
    Map<String, String> baseHeaders = const <String, String>{},
    bool includeJsonContentType = false,
    bool forceRefreshToken = false,
  }) async {
    final firebaseUid = await tryGetFirebaseUid();
    final token = await tryGetFirebaseToken(forceRefresh: forceRefreshToken);
    final useLocalFallback =
        AppStartupController.instance.shouldUseLocalFallbackIdentity &&
        token == null;
    final localId = useLocalFallback ? await getLocalPersistentId() : null;

    return <String, String>{
      ...baseHeaders,
      if (includeJsonContentType) 'Content-Type': 'application/json',
      if (localId != null) 'X-Client-Local-Id': localId,
      if (token != null) 'X-Identity-Mode': 'firebase',
      if (token == null && localId != null) 'X-Identity-Mode': 'local-fallback',
      if (firebaseUid != null && firebaseUid.isNotEmpty)
        'X-Firebase-Uid': firebaseUid,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
