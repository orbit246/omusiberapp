import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

class StartupLogger {
  StartupLogger._();

  static final Stopwatch _stopwatch = Stopwatch();
  static bool _started = false;
  static bool _frameTimingsAttached = false;

  static void start() {
    if (_started) {
      return;
    }

    _started = true;
    _stopwatch.start();
    debugPrint('[Startup +0 ms] App startup timing started');
  }

  static void log(String message) {
    debugPrint('[Startup +${_formatElapsed(_stopwatch.elapsed)}] $message');
  }

  static void logSection(String section) {
    log('--- $section ---');
  }

  static void attachFrameTimingsLogger({int maxFrames = 12}) {
    if (_frameTimingsAttached) {
      return;
    }

    _frameTimingsAttached = true;
    var loggedFrames = 0;
    WidgetsBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      for (final timing in timings) {
        if (loggedFrames >= maxFrames) {
          return;
        }

        loggedFrames += 1;
        log(
          'Frame $loggedFrames: build=${_formatElapsed(timing.buildDuration)} '
          'raster=${_formatElapsed(timing.rasterDuration)} '
          'total=${_formatElapsed(timing.totalSpan)}',
        );
      }
    });
  }

  static void logSync(String step, void Function() action) {
    final stepWatch = Stopwatch()..start();
    log('$step started');

    try {
      action();
      log('$step finished in ${_formatElapsed(stepWatch.elapsed)}');
    } catch (error) {
      log('$step failed after ${_formatElapsed(stepWatch.elapsed)}: $error');
      rethrow;
    }
  }

  static Future<T> logAsync<T>(
    String step,
    Future<T> Function() action,
  ) async {
    final stepWatch = Stopwatch()..start();
    log('$step started');

    try {
      final result = await action();
      log('$step finished in ${_formatElapsed(stepWatch.elapsed)}');
      return result;
    } catch (error) {
      log('$step failed after ${_formatElapsed(stepWatch.elapsed)}: $error');
      rethrow;
    }
  }

  static String _formatElapsed(Duration duration) {
    return '${duration.inMilliseconds} ms';
  }
}
