import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Startup evidence attached to callables as untrusted diagnostic metadata.
/// It never contains tokens, user identity, or raw provider error messages.
final firebaseAppCheckDiagnostics = AppCheckDiagnostics(
  platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
  buildMode: kDebugMode ? 'debug' : (kProfileMode ? 'profile' : 'release'),
);

/// Records one bounded, non-enforcing startup token check, not current validity.
class AppCheckDiagnostics {
  AppCheckDiagnostics({required this.platform, required this.buildMode});

  final String platform;
  final String buildMode;
  String? _appId;
  String _tokenAcquisition = 'not_attempted';
  String _failureReason = 'none';

  String get provider => switch ((platform, buildMode)) {
    ('linux' || 'fuchsia', _) => 'unsupported',
    ('windows', 'profile' || 'release') => 'unsupported',
    (_, 'debug') => 'debug',
    ('android', _) => 'play_integrity',
    ('iOS' || 'macOS', _) => 'app_attest_device_check',
    ('web', _) => 'recaptcha_enterprise',
    _ => 'unsupported',
  };

  Map<String, String> toJson() => {
    'platform': platform,
    'buildMode': buildMode,
    'provider': provider,
    'appId': ?_appId,
    'tokenAcquisition': _tokenAcquisition,
    'tokenAcquisitionScope': 'startup',
    'failureReason': _failureReason,
  };

  /// Uses the SDK cache (no forced refresh); failure must not become enforcement.
  /// Raw errors are classified locally and discarded, including unknown errors.
  Future<void> observeStartup({
    required String appId,
    required bool activated,
    required Future<String?> Function() getToken,
    required void Function(Map<String, String>) writeLog,
    // Bounds extra startup delay while collecting provider evidence.
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _appId = appId;
    _failureReason = 'none';
    if (!activated) {
      _tokenAcquisition = 'skipped';
      _failureReason = 'provider_missing';
    } else {
      try {
        final token = await getToken().timeout(timeout);
        _tokenAcquisition = token == null || token.isEmpty
            ? 'empty'
            : 'available';
        if (_tokenAcquisition == 'empty') _failureReason = 'empty_token';
      } on TimeoutException {
        _tokenAcquisition = 'timeout';
        _failureReason = 'timeout';
      } catch (error) {
        _tokenAcquisition = 'failed';
        _failureReason = _classifyFailure(error);
      }
    }
    writeLog(toJson());
  }
}

String _classifyFailure(Object error) {
  if (error is! FirebaseException) return 'unknown_error';
  final description = '${error.code} ${error.message ?? ''}'.toLowerCase();
  if (description.contains('too many') ||
      description.contains('429') ||
      description.contains('throttl')) {
    return 'rate_limited';
  }
  if (description.contains('network') ||
      description.contains('unreachable') ||
      description.contains('unable to resolve host')) {
    return 'network_error';
  }
  if (description.contains('no appcheckprovider') ||
      description.contains('no app check provider')) {
    return 'provider_missing';
  }
  if (description.contains('403') ||
      description.contains('attestation failed') ||
      description.contains('permission-denied')) {
    return 'attestation_rejected';
  }
  return 'unknown_error';
}

/// Remains visible in release device logs; payload is strictly allowlisted above.
void logFirebaseAppCheckStartup(Map<String, String> diagnostic) {
  // ignore: avoid_print
  print(jsonEncode({'event': 'app_check_startup', ...diagnostic}));
}
