import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Opt-in device startup evidence; never logs account, ticket or replay data.
/// Enable with --dart-define=RUN_STARTUP_TRACE=true in debug/profile builds.
/// Wall durations overlap and are not simulation inputs or additive CPU costs.
abstract final class RunStartupDiagnostics {
  static const enabled =
      !kReleaseMode && bool.fromEnvironment('RUN_STARTUP_TRACE');

  static void emit(String phase, Map<String, Object?> values) {
    if (!enabled) return;
    debugPrintSynchronously(
      'RUN_STARTUP_TRACE ${jsonEncode({'phase': phase, ...values})}',
    );
  }

  /// Observes completion without changing errors, retries or dependency order.
  static Future<T> measure<T>(String phase, Future<T> Function() action) async {
    if (!enabled) return action();
    final watch = Stopwatch()..start();
    var succeeded = false;
    try {
      final result = await action();
      succeeded = true;
      return result;
    } finally {
      emit(phase, {
        'elapsedMs': watch.elapsedMicroseconds / 1000,
        'succeeded': succeeded,
      });
    }
  }
}
