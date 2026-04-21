import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/profile_identity.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  // --- DEPENDENCIES ---
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: <String>['email']);
  final UserProfileService _profileService = UserProfileService();

  /// Helper to get headers with Firebase ID token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _auth.currentUser?.getIdToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  /// Google Sign-In + Firebase Auth.
  Future<User?> signInWithGoogle() async {
    try {
      await AppStartupController.instance.ensureFirebaseReady();
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

      final user = await _authenticateWithCredential(
        credential,
        providerLabel: 'Google',
      );
      if (user == null) {
        throw Exception('Firebase sign-in returned no user.');
      }

      print('Google Sign In successful for: ${user.email}');
      await _syncProfileFromAuthUser(user);
      AppStartupController.instance.markReady();
      return user;
    } catch (e) {
      print('Google Sign In failed: $e');
      await signOut();
      throw _handleAuthError(e);
    }
  }

  Future<User?> signInWithApple() async {
    try {
      await AppStartupController.instance.ensureFirebaseReady();
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        throw AuthException('Apple ile giriş bu cihazda kullanılamıyor.');
      }

      final rawNonce = _generateNonce();
      final hashedNonce = _sha256OfString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw AuthException('Apple kimlik doğrulaması tamamlanamadı.');
      }

      final credential = OAuthProvider(
        'apple.com',
      ).credential(idToken: identityToken, rawNonce: rawNonce);

      final fallbackName =
          [appleCredential.givenName, appleCredential.familyName]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .join(' ')
              .trim();

      final user = await _authenticateWithCredential(
        credential,
        providerLabel: 'Apple',
      );
      if (user == null) {
        throw AuthException(
          'Apple ile giriş tamamlandı fakat kullanıcı alınamadı.',
        );
      }

      await _syncProfileFromAuthUser(
        user,
        fallbackDisplayName: fallbackName.isEmpty ? null : fallbackName,
      );
      AppStartupController.instance.markReady();
      return user;
    } catch (e) {
      print('Apple Sign In failed: $e');
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
      await AppStartupController.instance.ensureFirebaseReady();
      final UserCredential userCred = await _auth.signInAnonymously();
      AppStartupController.instance.markReady();
      return userCred.user;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Check if the current user is in the whitelist via Backend API.
  Future<bool> isWhitelisted() async {
    final ready = await AppStartupController.instance
        .ensureAuthenticatedSession();
    if (!ready) {
      return false;
    }

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
  Future<void> signOut({bool createAnonymousFallback = true}) async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}

      await AppStartupController.instance.ensureFirebaseReady();
      await _auth.signOut();
      if (createAnonymousFallback) {
        print('Signed out from Firebase. Creating fallback anonymous session...');
        await signInAnonymously(acceptedTos: true, acceptedPrivacy: true);
      }
    } catch (e) {
      print('Error during sign out / anon-sign-in: $e');
    }
  }

  bool get isSignedInWithApple {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((provider) => provider.providerId == 'apple.com');
  }

  Future<AppleDeletionAuthorization?> prepareAppleDeletionAuthorization() async {
    if (!isSignedInWithApple) {
      return null;
    }

    try {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        return null;
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
      );

      final authorizationCode = credential.authorizationCode.trim();
      if (authorizationCode.isEmpty) {
        return null;
      }

      return AppleDeletionAuthorization(
        authorizationCode: authorizationCode,
        userIdentifier: credential.userIdentifier,
      );
    } catch (e) {
      print('Apple deletion authorization failed: $e');
      return null;
    }
  }

  Future<void> clearLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    UserProfileService.clearCaches();
  }

  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<User?> _authenticateWithCredential(
    AuthCredential credential, {
    required String providerLabel,
  }) async {
    User? user;
    final currentUser = _auth.currentUser;

    UserProfile? anonProfile;
    if (currentUser != null && currentUser.isAnonymous) {
      anonProfile = await _profileService.fetchUserProfile(currentUser.uid);
    }

    if (currentUser != null && currentUser.isAnonymous) {
      try {
        print('Linking $providerLabel account to anonymous session...');
        final userCred = await currentUser.linkWithCredential(credential);
        user = userCred.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          print(
            '$providerLabel account already exists. Signing in explicitly (dropping anon session)...',
          );
          final userCred = await _auth.signInWithCredential(credential);
          user = userCred.user;

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
      print('Signing in to Firebase with $providerLabel...');
      final userCred = await _auth.signInWithCredential(credential);
      user = userCred.user;
    }

    return user;
  }

  Future<void> _syncProfileFromAuthUser(
    User user, {
    String? fallbackDisplayName,
  }) async {
    try {
      final resolvedName = (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : fallbackDisplayName?.trim();

      final updates = <String, dynamic>{
        'email': user.email,
        'photoUrl': user.photoURL,
      };

      if (resolvedName != null && resolvedName.isNotEmpty) {
        updates['name'] = resolvedName;
      }

      final derivedStudentId = extractStudentIdFromEmail(user.email);
      if (derivedStudentId != null) {
        updates['studentId'] = derivedStudentId;
      }

      await _profileService.updateUserProfile(user.uid, updates);
    } catch (e) {
      print('Profile sync after auth failed: $e');
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
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

class AppleDeletionAuthorization {
  const AppleDeletionAuthorization({
    required this.authorizationCode,
    this.userIdentifier,
  });

  final String authorizationCode;
  final String? userIdentifier;
}
