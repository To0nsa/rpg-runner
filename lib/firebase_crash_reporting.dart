import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_environment.dart';

bool _installed = false;

/// Android beta diagnostics use only the verified project's Crashlytics instance.
/// No account identifiers, payloads, auth errors or exception messages are added.
Future<void> initializeAndroidCrashReporting(
  FirebaseEnvironment environment,
) async {
  final crashlytics = FirebaseCrashlytics.instance;
  final enabled = kReleaseMode && environment != FirebaseEnvironment.dev;
  await crashlytics.setCrashlyticsCollectionEnabled(enabled);
  if (!enabled || _installed) return;
  await crashlytics.setCustomKey('environment', environment.name);
  installCrashErrorHandlers(
    (error, stack, fatal) => crashlytics.recordError(
      error,
      stack,
      fatal: fatal,
      printDetails: false,
    ),
  );
  _installed = true;
}

/// Keeps stack frames while removing exception text that can contain credentials
/// or player data. Failed diagnostics must not recursively report themselves.
@visibleForTesting
void installCrashErrorHandlers(
  Future<void> Function(String errorType, StackTrace? stack, bool fatal) record,
) {
  Future<void> report(Object error, StackTrace? stack, bool fatal) async {
    try {
      await record('Unhandled ${error.runtimeType}', stack, fatal);
    } catch (_) {
      // Crash reporting is best effort and cannot become a second app failure.
    }
  }

  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    previousFlutterHandler?.call(details);
    unawaited(report(details.exception, details.stack, false));
  };
  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(report(error, stack, true));
    previousPlatformHandler?.call(error, stack);
    return true;
  };
}
