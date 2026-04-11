import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';
import 'package:omusiber/firebase_options.dart';
import 'package:omusiber/pages/agreement_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppStartupStage { idle, booting, waitingForAgreement, ready, failed }

class AppStartupController extends ChangeNotifier {
  AppStartupController._();

  static final AppStartupController instance = AppStartupController._();

  static const String _agreementPrefsKey = 'startup_agreement_acceptance_v1';
  static const Duration _startupWarmupWindow = Duration(seconds: 10);
  static final Stopwatch _startupStopwatch = Stopwatch()..start();

  AppStartupStage _stage = AppStartupStage.idle;
  Object? _lastError;
  Future<void>? _startFuture;
  bool _firebaseReady = false;

  AppStartupStage get stage => _stage;
  Object? get lastError => _lastError;
  bool get isFirebaseReady => _firebaseReady;
  bool get isBooting => _stage == AppStartupStage.booting;
  bool get needsAgreement => _stage == AppStartupStage.waitingForAgreement;
  bool get canUseAuthenticatedApis => _stage == AppStartupStage.ready;
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

    if (!_firebaseReady || needsAgreement) {
      return false;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      markReady();
      return true;
    }

    try {
      await FirebaseAuth.instance.signInAnonymously();
      markReady();
      return true;
    } catch (error) {
      _lastError = error;
      _stage = AppStartupStage.failed;
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
    _stage = AppStartupStage.booting;
    _lastError = null;
    notifyListeners();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseReady = true;

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _stage = AppStartupStage.ready;
        notifyListeners();
        return;
      }

      final hasAccepted = await _hasStoredAgreementAcceptance();
      if (!hasAccepted) {
        _stage = AppStartupStage.waitingForAgreement;
        notifyListeners();
        return;
      }

      _stage = AppStartupStage.ready;
      notifyListeners();
    } catch (error) {
      _lastError = error;
      _stage = AppStartupStage.failed;
      _startFuture = null;
      notifyListeners();
    }
  }

  Future<bool> _hasStoredAgreementAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_agreementPrefsKey);
    return raw != null && raw.isNotEmpty;
  }
}
