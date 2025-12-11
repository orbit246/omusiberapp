import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // --- DEPENDENCIES ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // google_sign_in 6.x: normal constructor is available again
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  // --- SETTINGS ---
  final String allowedDomain = 'school.edu'; // change to your real domain

  /// Google Sign-In + Firebase Auth + Firestore profile upsert.
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
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

      // 4. Sign in to Firebase
      final UserCredential userCred =
          await _auth.signInWithCredential(credential);
      final User? user = userCred.user;

      if (user == null) {
        throw Exception('Firebase sign-in returned no user.');
      }

      // 5. Enforce email domain
      final String? email = user.email;
      if (email == null || !email.endsWith('@$allowedDomain')) {
        await signOut();
        throw Exception(
          'Access denied: Only @$allowedDomain emails are allowed.',
        );
      }

      // 6. Upsert Firestore user profile
      final String studentId = _extractStudentId(email);
      await _upsertStudentProfile(user, studentId);

      return user;
    } on FirebaseAuthException {
      // Firebase-specific error
      await signOut();
      rethrow;
    } catch (_) {
      // Any other error
      await signOut();
      rethrow;
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
    final DocumentReference<Map<String, dynamic>> docRef =
        _firestore.collection('students').doc(studentId);

    // Use merge: true to avoid overwriting unknown fields in the future
    await docRef.set(<String, dynamic>{
      'studentId': studentId,
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName ?? '',
      'photoUrl': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isAllowed': false,
      'role': 'student',
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
