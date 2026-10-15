import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/firebase_app_check_diagnostics.dart';

void main() {
  test('uses debug attestation only in debug builds', () {
    for (final mode in ['debug', 'profile', 'release']) {
      final diagnostic = AppCheckDiagnostics(
        platform: 'android',
        buildMode: mode,
      );
      expect(diagnostic.provider, mode == 'debug' ? 'debug' : 'play_integrity');
    }
    expect(
      AppCheckDiagnostics(platform: 'web', buildMode: 'release').provider,
      'recaptcha_enterprise',
    );
    expect(
      AppCheckDiagnostics(platform: 'windows', buildMode: 'release').provider,
      'unsupported',
    );
  });

  test(
    'reports acquisition success without retaining or logging the token',
    () async {
      final diagnostic = AppCheckDiagnostics(
        platform: 'android',
        buildMode: 'release',
      );
      Map<String, String>? logged;
      await diagnostic.observeStartup(
        appId: '1:123:android:abcdef',
        activated: true,
        getToken: () async => 'secret-token',
        writeLog: (value) => logged = value,
      );
      expect(logged!['tokenAcquisition'], 'available');
      expect(logged!['appId'], '1:123:android:abcdef');
      expect(jsonEncode(logged), isNot(contains('secret-token')));
      expect(diagnostic.toJson(), logged);
    },
  );

  test('classifies provider errors without exposing their message or blocking startup', () async {
    for (final entry in {
      'API code: 403 body: App attestation failed. secret':
          'attestation_rejected',
      'Too many attempts. secret': 'rate_limited',
      'Network error secret': 'network_error',
      'No AppCheckProvider installed. secret': 'provider_missing',
      'unexpected secret': 'unknown_error',
    }.entries) {
      final diagnostic = AppCheckDiagnostics(
        platform: 'android',
        buildMode: 'debug',
      );
      await diagnostic.observeStartup(
        appId: '1:123:android:abcdef',
        activated: true,
        getToken: () async => throw FirebaseException(
          plugin: 'firebase_app_check',
          code: 'unknown',
          message: entry.key,
        ),
        writeLog: (value) =>
            expect(jsonEncode(value), isNot(contains('secret'))),
      );
      expect(diagnostic.toJson()['tokenAcquisition'], 'failed');
      expect(diagnostic.toJson()['failureReason'], entry.value);
    }
  });

  test(
    'bounds a stalled SDK request and handles empty/skipped tokens',
    () async {
      final diagnostic = AppCheckDiagnostics(
        platform: 'android',
        buildMode: 'debug',
      );
      final gate = Completer<String?>();
      await diagnostic.observeStartup(
        appId: 'app',
        activated: true,
        getToken: () => gate.future,
        timeout: Duration.zero,
        writeLog: (_) {},
      );
      expect(diagnostic.toJson()['tokenAcquisition'], 'timeout');
      gate.complete('late-secret');
      await Future<void>.delayed(Duration.zero);
      expect(diagnostic.toJson()['tokenAcquisition'], 'timeout');
      await diagnostic.observeStartup(
        appId: 'app',
        activated: true,
        getToken: () async => '',
        writeLog: (_) {},
      );
      expect(diagnostic.toJson()['failureReason'], 'empty_token');
      await diagnostic.observeStartup(
        appId: 'app',
        activated: false,
        getToken: () => throw StateError('must not fetch'),
        writeLog: (_) {},
      );
      expect(diagnostic.toJson()['tokenAcquisition'], 'skipped');
    },
  );
}
