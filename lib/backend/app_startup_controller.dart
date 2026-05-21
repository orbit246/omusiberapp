import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';
import 'package:omusiber/backend/startup_logger.dart';
import 'package:omusiber/firebase_options.dart';
import 'package:omusiber/pages/agreement_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppStartupStage { idle, booting, waitingForAgreement, ready, failed }

class AppStartupController extends ChangeNotifier {
  AppStartupController._();

  static final AppStartupController instance = AppStartupController._();

  static const String _agreementPrefsKey = 'startup_agreement_acceptance_v1';
  static const Duration _startupWarmupWindow = Duration(seconds: 10);
  static const Duration _localFallbackActivationDelay = Duration(seconds: 10);
  static final Stopwatch _startupStopwatch = Stopwatch()..start();

  AppStartupStage _stage = AppStartupStage.idle;
  Object? _lastError;
  Future<void>? _startFuture;
  bool _firebaseReady = false;
  bool _authenticatedSessionReady = false;
  bool _localFallbackIdentityEnabled = false;
  bool _needsAgreement = false;
  bool _backgroundMessageHandlerRegistrationScheduled = false;
  bool _backgroundMessageHandlerRegistered = false;
  Timer? _localFallbackTimer;

  AppStartupStage get stage => _stage;
  Object? get lastError => _lastError;
  bool get isFirebaseReady => _firebaseReady;
  bool get hasAuthenticatedSession => _authenticatedSessionReady;
  bool get shouldUseLocalFallbackIdentity => _localFallbackIdentityEnabled;
  bool get isBooting => _stage == AppStartupStage.booting;
  bool get needsAgreement => _needsAgreement;
  bool get canUseAuthenticatedApis =>
      _stage == AppStartupStage.ready && _authenticatedSessionReady;
  bool get isInStartupWarmup =>
      _startupStopwatch.elapsed < _startupWarmupWindow;

  Duration startupDeferral(Duration requestedDelay) {
    final remaining = _startupWarmupWindow - _startupStopwatch.elapsed;
    if (remaining <= Duration.zero || requestedDelay <= Duration.zero) {
      return Duration.zero;
    }
    return remaining < requestedDelay ? remaining : requestedDelay;
  }

  Future<void> start() {
    StartupLogger.log(
      'AppStartupController.start() called '
      'existingFuture=${_startFuture != null} stage=${_stage.name}',
    );
    return _startFuture ??= _performStartup();
  }

  Future<void> retry() async {
    _startFuture = null;
    await start();
  }

  Future<bool> ensureFirebaseReady() async {
    await start();
    return _firebaseReady;
  }

  Future<bool> ensureAuthenticatedSession() async {
    await start();

    if (!_firebaseReady) {
      return false;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _setAuthenticatedSessionReady();
      return true;
    }

    try {
      await FirebaseAuth.instance.signInAnonymously();
      _setAuthenticatedSessionReady();
      return true;
    } catch (error) {
      _lastError = error;
      notifyListeners();
      return false;
    }
  }

  Future<void> acceptAgreements(AgreementsAcceptance acceptance) async {
    await ensureFirebaseReady();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _agreementPrefsKey,
      jsonEncode({
        ...acceptance.toJson(),
        'acceptedAt': DateTime.now().toIso8601String(),
      }),
    );

    _lastError = null;
    _needsAgreement = false;
    _stage = AppStartupStage.ready;
    notifyListeners();
  }

  void markReady() {
    if (_stage == AppStartupStage.ready && _lastError == null) {
      return;
    }
    _lastError = null;
    _stage = AppStartupStage.ready;
    notifyListeners();
  }

  Future<void> _performStartup() async {
    StartupLogger.log('AppStartupController._performStartup() entered');
    _stage = AppStartupStage.booting;
    _lastError = null;
    _needsAgreement = false;
    notifyListeners();

    try {
      await StartupLogger.logAsync('Firebase.initializeApp()', () {
        return Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      });
      _firebaseReady = true;
      _localFallbackTimer?.cancel();
      _localFallbackIdentityEnabled = false;
      StartupLogger.log('Firebase initialized');
    } catch (error) {
      _firebaseReady = false;
      _lastError = error;
      _scheduleLocalFallbackIdentityActivation();
      StartupLogger.log(
        'Firebase startup failed, continuing with local fallback identity: $error',
      );
    }

    if (_firebaseReady) {
      unawaited(_captureLaunchIntentInBackground());
      _scheduleBackgroundMessageHandlerRegistration();

      try {
        final currentUser = await StartupLogger.logAsync(
          'FirebaseAuth.instance.currentUser check',
          () async => FirebaseAuth.instance.currentUser,
        );
        StartupLogger.log(
          'FirebaseAuth currentUser result=${currentUser == null ? 'null' : currentUser.uid}',
        );

        if (currentUser != null) {
          _authenticatedSessionReady = true;
          StartupLogger.log(
            'Existing Firebase user found; marking startup ready',
          );
        } else {
          unawaited(_ensureAnonymousSessionInBackground());
        }
      } catch (error) {
        StartupLogger.log('FirebaseAuth currentUser check skipped: $error');
        unawaited(_ensureAnonymousSessionInBackground());
      }
    }

    final hasAccepted = await StartupLogger.logAsync(
      'SharedPreferences agreement acceptance check',
      _hasStoredAgreementAcceptance,
    );
    StartupLogger.log('Agreement accepted=$hasAccepted');
    _needsAgreement = !hasAccepted;
    if (_needsAgreement) {
      StartupLogger.log(
        'No stored agreement acceptance found; continuing startup and showing agreement banner',
      );
    } else {
      StartupLogger.log('Stored agreement acceptance found');
    }

    _stage = AppStartupStage.ready;
    notifyListeners();
  }

  Future<void> _ensureAnonymousSessionInBackground() async {
    try {
      final ready = await StartupLogger.logAsync(
        'FirebaseAuth anonymous fallback sign-in',
        ensureAuthenticatedSession,
      );
      StartupLogger.log('Anonymous fallback sign-in ready=$ready');
    } catch (error) {
      StartupLogger.log('Anonymous fallback sign-in skipped: $error');
    }
  }

  Future<void> _captureLaunchIntentInBackground() async {
    try {
      await StartupLogger.logAsync(
        'SimpleNotifications.captureLaunchIntent()',
        () {
          return SimpleNotifications.captureLaunchIntent().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              throw TimeoutException(
                'SimpleNotifications.captureLaunchIntent() timed out.',
              );
            },
          );
        },
      );
    } catch (error) {
      StartupLogger.log('Launch intent capture skipped: $error');
    }
  }

  void _setAuthenticatedSessionReady() {
    final shouldNotify =
        !_authenticatedSessionReady ||
        _stage != AppStartupStage.ready ||
        _lastError != null;
    _authenticatedSessionReady = true;
    _lastError = null;
    _stage = AppStartupStage.ready;
    if (shouldNotify) {
      notifyListeners();
    }
  }

  void _scheduleLocalFallbackIdentityActivation() {
    if (_localFallbackIdentityEnabled) {
      return;
    }

    _localFallbackTimer?.cancel();
    _localFallbackTimer = Timer(_localFallbackActivationDelay, () {
      if (_firebaseReady || _localFallbackIdentityEnabled) {
        return;
      }
      _localFallbackIdentityEnabled = true;
      StartupLogger.log(
        'Firebase remained unavailable for ${_localFallbackActivationDelay.inSeconds} seconds; enabling local fallback identity.',
      );
      notifyListeners();
    });
  }

  Future<bool> _hasStoredAgreementAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_agreementPrefsKey);
    return raw != null && raw.isNotEmpty;
  }

  void _scheduleBackgroundMessageHandlerRegistration() {
    if (_backgroundMessageHandlerRegistrationScheduled ||
        _backgroundMessageHandlerRegistered) {
      return;
    }

    _backgroundMessageHandlerRegistrationScheduled = true;
    final delay = startupDeferral(const Duration(seconds: 8));
    StartupLogger.log(
      'FirebaseMessaging.onBackgroundMessage() registration scheduled '
      'in ${delay.inMilliseconds} ms',
    );

    Timer(delay, () {
      StartupLogger.logSync(
        'FirebaseMessaging.onBackgroundMessage() registration',
        () {
          FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler,
          );
        },
      );
      _backgroundMessageHandlerRegistered = true;
    });
  }
}
