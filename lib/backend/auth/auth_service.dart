import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // --- DEPENDENCIES ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // google_sign_in 6.x: normal constructor is available again
  // google_sign_in 6.x: normal constructor is available again
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: <String>['email']);

  // --- SETTINGS ---
  // "ogr.omu.edu.tr" is the standard student email domain for OMÜ.
  final String allowedDomain = 'stu.omu.edu.tr';

  /// Google Sign-In + Firebase Auth + Firestore profile upsert.
  Future<User?> signInWithGoogle() async {
    try {
      print('Starting Google Sign In...');
      // 1. Trigger the Google sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        print('Google Sign In cancelled by user.');
        return null;
      }

      // 2. Get auth details (tokens)
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Build Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Link or Sign in to Firebase
      User? user;
      final currentUser = _auth.currentUser;

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
            // The Google account already exists, so we can't link.
            // We just sign in to that account, effectively switching users.
            final userCred = await _auth.signInWithCredential(credential);
            user = userCred.user;
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

      // 5. Enforce email domain
      final String? email = user.email;
      if (email == null || !email.endsWith('@$allowedDomain')) {
        print('Email domain check failed for: $email');
        await signOut();
        throw AuthException(
          'Erişim reddedildi: Sadece @$allowedDomain uzantılı öğrenci mailleri kabul edilmektedir.',
        );
      }

      // 6. Upsert Firestore user profile
      // Use UID as document ID, but store studentId inside
      final String studentId = _extractStudentId(email);
      await _upsertStudentProfile(user, studentId);

      print('Google Sign In successful for: ${user.email}');
      return user;
    } catch (e) {
      print('Google Sign In failed: $e');
      await signOut(); // Ensure clean state
      throw _handleAuthError(e);
    }
  }

  /// Anonymous Sign-In
  /// Requires user to have accepted TOS/Privacy Agreement in the UI.
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
      final User? user = userCred.user;

      if (user == null) {
        throw AuthException('Misafir girişi başarısız oldu (Kullanıcı yok).');
      }

      // Upsert anonymous profile
      await _upsertAnonymousProfile(
        user,
        acceptedTos: acceptedTos,
        acceptedPrivacy: acceptedPrivacy,
      );

      return user;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Extract student ID from email (before '@')
  String _extractStudentId(String email) {
    final parts = email.split('@');
    if (parts.length != 2) {
      throw Exception('Invalid email format');
    }
    return parts[0].trim().toLowerCase();
  }

  /// Create or update student document in Firestore
  Future<void> _upsertStudentProfile(User user, String studentId) async {
    // Document ID is now the User UID (not studentId)
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('students')
        .doc(user.uid);

    // Use merge: true to avoid overwriting unknown fields in the future
    await docRef.set(<String, dynamic>{
      'studentId': studentId, // Stored as a field
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName ?? '',
      'photoUrl': user.photoURL ?? '',

      'lastLoginAt': FieldValue.serverTimestamp(),
      'isAllowed': true,
      'role': 'student',
      // Implicitly accepted because they are students?
      // Or we can add default true for them if needed, but usually this is for Anon.
      'acceptedTos': true,
      'acceptedPrivacy': true,
    }, SetOptions(merge: true));
  }

  /// Create or update anonymous user document in Firestore
  Future<void> _upsertAnonymousProfile(
    User user, {
    required bool acceptedTos,
    required bool acceptedPrivacy,
  }) async {
    // Document ID is the User UID
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('students')
        .doc(user.uid);

    await docRef.set(<String, dynamic>{
      'studentId': 'anon_${user.uid}',
      'uid': user.uid,
      'email': null,
      'name': 'Misafir Kullanıcı',
      'photoUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isAllowed': true,
      'role': 'anonymous',
      'acceptedTos': acceptedTos,
      'acceptedPrivacy': acceptedPrivacy,
    }, SetOptions(merge: true));
  }

  /// Sign out from Google and Firebase
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // ignore
    }

    try {
      await _auth.signOut();
    } catch (_) {
      // ignore
    }
  }
}

/// Custom Exception for Auth Failures
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message';
}

/// Helper to map Firebase Auth errors to Turkish user-friendly messages
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
