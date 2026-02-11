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
  // google_sign_in 6.x: normal constructor is available again
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
    // serverClientId is often required for Android release builds to verify the token correctly on backend
    // serverClientId: "YOUR_WEB_CLIENT_ID_FROM_FIREBASE_CONSOLE.apps.googleusercontent.com",
  );

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
      try {
        await _upsertStudentProfile(user, studentId);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          print(
            'Warning: Failed to create student profile due to permissions: ${e.message}',
          );
        } else {
          print('Warning: Failed to create student profile: $e');
        }
      } catch (e) {
        print('Warning: Failed to create student profile: $e');
      }

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
      try {
        await _upsertAnonymousProfile(
          user,
          acceptedTos: acceptedTos,
          acceptedPrivacy: acceptedPrivacy,
        );
      } on FirebaseException catch (e) {
        // If the backend refuses to write (e.g. permission-denied),
        // we should still allow the user to log in rather than blocking them entirely.
        if (e.code == 'permission-denied') {
          print(
            'Warning: Failed to create anonymous profile due to permissions: ${e.message}',
          );
        } else {
          // If it's another error, we might want to know, but likely non-fatal for login session
          print('Warning: Failed to create anonymous profile: $e');
        }
      } catch (e) {
        print('Warning: Failed to create anonymous profile: $e');
      }

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

  /// Check if the current user is in the 'allowedStudents' whitelist.
  /// NOTE: This requires Firestore rules to allow 'read' access to 'allowedStudents/{id}' for the owner.
  Future<bool> isWhitelisted() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.email == null) {
      print("User is null or anonymous or email is null");
      return false;
    }

    try {
      final studentId = _extractStudentId(user.email!);
      final doc = await _firestore
          .collection('allowedStudents')
          .doc(studentId)
          .get();

      print("Whitelist check result: ${doc.exists}");
      return doc.exists;
    } catch (e) {
      print('Whitelist check failed (Rules likely prevent read): $e');
      return false;
    }
  }

  /// Sign out from Google and Firebase, then immediately sign in anonymously.
  /// This ensures the user is "dropped" back to an anonymous session instead of the Agreements page.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // ignore
    }

    try {
      await _auth.signOut();
      print('Signed out from Firebase. Creating fallback anonymous session...');

      // Implicitly accept TOS/Privacy because the user was already using the app.
      await signInAnonymously(acceptedTos: true, acceptedPrivacy: true);
    } catch (e) {
      print('Error during sign out / anon-sign-in: $e');
      // If anon sign-in fails, the user remains signed out.
    }
  }

  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
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
  } else if (e is FirebaseException) {
    // Handle generic Firebase errors (Firestore, Storage, etc.)
    return AuthException('Firebase hatası: ${e.message}', code: e.code);
  } else if (e is AuthException) {
    return e;
  } else {
    return AuthException('Beklenmeyen bir hata oluştu: $e');
  }
}
