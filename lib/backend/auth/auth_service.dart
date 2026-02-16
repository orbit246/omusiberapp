import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';

class AuthService {
  // --- DEPENDENCIES ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: <String>['email']);
  final UserProfileService _profileService = UserProfileService();

  // --- SETTINGS ---
  final String allowedDomain = 'stu.omu.edu.tr';

  /// Helper to get headers with Firebase ID token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _auth.currentUser?.getIdToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  /// Google Sign-In + Firebase Auth.
  Future<User?> signInWithGoogle() async {
    try {
      print('Starting Google Sign In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign In cancelled by user.');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      User? user;
      final currentUser = _auth.currentUser;

      // Capture anonymous profile for migration if needed
      UserProfile? anonProfile;
      if (currentUser != null && currentUser.isAnonymous) {
        anonProfile = await _profileService.fetchUserProfile(currentUser.uid);
      }

      if (currentUser != null && currentUser.isAnonymous) {
        try {
          print('Linking Google account to anonymous session...');
          final userCred = await currentUser.linkWithCredential(credential);
          user = userCred.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            print(
              'Google account already exists. Signing in explicitly (dropping anon session)...',
            );
            final userCred = await _auth.signInWithCredential(credential);
            user = userCred.user;

            // Migrate profile to the new UID since it changed
            if (user != null && anonProfile != null) {
              print('Migrating anonymous profile to new OAuth account...');
              await _profileService.migrateProfile(
                currentUser.uid,
                user.uid,
                anonProfile,
              );
            }
          } else {
            rethrow;
          }
        }
      } else {
        print('Signing in to Firebase...');
        final userCred = await _auth.signInWithCredential(credential);
        user = userCred.user;
      }

      if (user == null) {
        throw Exception('Firebase sign-in returned no user.');
      }

      final String? email = user.email;
      if (email == null || !email.endsWith('@$allowedDomain')) {
        print('Email domain check failed for: $email');
        await signOut();
        throw AuthException(
          'Erişim reddedildi: Sadece @$allowedDomain uzantılı öğrenci mailleri kabul edilmektedir.',
        );
      }

      print('Google Sign In successful for: ${user.email}');
      return user;
    } catch (e) {
      print('Google Sign In failed: $e');
      await signOut();
      throw _handleAuthError(e);
    }
  }

  /// Anonymous Sign-In
  Future<User?> signInAnonymously({
    required bool acceptedTos,
    required bool acceptedPrivacy,
  }) async {
    if (!acceptedTos || !acceptedPrivacy) {
      throw AuthException(
        'Hizmet şartlarını ve gizlilik politikasını kabul etmelisiniz.',
      );
    }

    try {
      final UserCredential userCred = await _auth.signInAnonymously();
      return userCred.user;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Extract student ID from email
  String _extractStudentId(String email) {
    final parts = email.split('@');
    if (parts.length != 2) {
      throw Exception('Invalid email format');
    }
    return parts[0].trim().toLowerCase();
  }

  /// Check if the current user is in the whitelist via Backend API.
  Future<bool> isWhitelisted() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/auth/check-whitelist'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isWhitelisted'] ?? false;
      }
      return false;
    } catch (e) {
      print('Whitelist check failed: $e');
      return false;
    }
  }

  /// Sign out from Google and Firebase, then immediately sign in anonymously.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      await _auth.signOut();
      print('Signed out from Firebase. Creating fallback anonymous session...');
      await signInAnonymously(acceptedTos: true, acceptedPrivacy: true);
    } catch (e) {
      print('Error during sign out / anon-sign-in: $e');
    }
  }

  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }
}

class AuthException implements Exception {
  final String message;
  final String? code;
  AuthException(this.message, {this.code});
  @override
  String toString() => 'AuthException: $message';
}

AuthException _handleAuthError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'user-not-found':
        return AuthException('Kullanıcı bulunamadı.', code: e.code);
      case 'wrong-password':
        return AuthException('Hatalı şifre.', code: e.code);
      case 'email-already-in-use':
        return AuthException(
          'Bu e-posta adresi zaten kullanımda.',
          code: e.code,
        );
      case 'credential-already-in-use':
        return AuthException(
          'Bu hesap zaten başka bir kullanıcıyla eşleşmiş.',
          code: e.code,
        );
      case 'network-request-failed':
        return AuthException(
          'İnternet bağlantınızı kontrol edin.',
          code: e.code,
        );
      case 'user-disabled':
        return AuthException('Bu hesap devre dışı bırakılmış.', code: e.code);
      case 'too-many-requests':
        return AuthException(
          'Çok fazla deneme yaptınız. Lütfen daha sonra tekrar deneyin.',
          code: e.code,
        );
      case 'operation-not-allowed':
        return AuthException(
          'Bu giriş yöntemi şu anda aktif değil.',
          code: e.code,
        );
      case 'invalid-email':
        return AuthException('Geçersiz e-posta formatı.', code: e.code);
      default:
        return AuthException('Bir hata oluştu: ${e.message}', code: e.code);
    }
  } else if (e is AuthException) {
    return e;
  } else {
    return AuthException('Beklenmeyen bir hata oluştu: $e');
  }
}
