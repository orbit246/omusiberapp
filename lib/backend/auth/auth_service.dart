import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  final String allowedDomain = 'school.edu';

  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      return null; // user cancelled
    }

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) {
      throw Exception('No user from credential');
    }

    final email = user.email ?? '';
    if (!email.endsWith('@$allowedDomain')) {
      await _auth.signOut();
      throw Exception('Only $allowedDomain emails can sign in.');
    }

    final studentId = extractStudentId(email);

    await _upsertStudentProfile(user, studentId);

    return user;
  }

  String extractStudentId(String email) {
    final parts = email.split('@');
    if (parts.length != 2) {
      throw Exception('Invalid email format');
    }
    return parts[0];
  }

  Future<void> _upsertStudentProfile(User user, String studentId) async {
    final docRef = _firestore.collection('students').doc(studentId);

    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await docRef.set({
      'studentId': studentId,
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName ?? '',
      'photoUrl': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isAllowed': false, // default locked until you approve
      'role': 'student',
    });
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
