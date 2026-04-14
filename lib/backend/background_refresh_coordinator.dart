import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:omusiber/backend/app_startup_controller.dart';

typedef BackgroundRefreshTask = Future<void> Function();

class BackgroundRefreshCoordinator {
  BackgroundRefreshCoordinator({
    required AppStartupController startupController,
    required Duration delay,
    required BackgroundRefreshTask refresh,
    bool Function()? canRefresh,
  }) : _startupController = startupController,
       _delay = delay,
       _refresh = refresh,
       _canRefresh = canRefresh;

  final AppStartupController _startupController;
  final Duration _delay;
  final BackgroundRefreshTask _refresh;
  final bool Function()? _canRefresh;

  Timer? _timer;
  bool _refreshQueued = false;
  bool _disposed = false;

  bool get isRefreshQueued => _refreshQueued;

  void schedule() {
    if (_disposed || _refreshQueued || !(_canRefresh?.call() ?? true)) {
      return;
    }

    final delay = _startupController.startupDeferral(_delay);
    _timer?.cancel();

    if (delay == Duration.zero) {
      _run();
      return;
    }

    _timer = Timer(delay, () {
      if (_disposed || _refreshQueued || !(_canRefresh?.call() ?? true)) {
        return;
      }
      _run();
    });
  }

  Future<void> runNow() async {
    if (_disposed || _refreshQueued) {
      return;
    }
    await _run();
  }

  Future<void> _run() async {
    _refreshQueued = true;
    try {
      await _refresh();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'background_refresh_coordinator',
        ),
      );
    } finally {
      _refreshQueued = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
