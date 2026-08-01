import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const String _webSiteKey = String.fromEnvironment(
  'FIREBASE_APP_CHECK_WEB_SITE_KEY',
);
const String _debugToken = String.fromEnvironment(
  'FIREBASE_APP_CHECK_DEBUG_TOKEN',
);
const String _windowsDebugToken = String.fromEnvironment(
  'FIREBASE_APP_CHECK_WINDOWS_DEBUG_TOKEN',
);

enum AppCheckActivationOutcome {
  activated,
  skippedUnsupported,
  skippedMissingConfiguration,
}

/// Activates App Check after Firebase initialization and before Firebase APIs.
///
/// Release web builds require `FIREBASE_APP_CHECK_WEB_SITE_KEY`. Windows has
/// no production attestation provider, so only an explicitly configured debug
/// token is accepted in debug builds.
Future<AppCheckActivationOutcome> activateFirebaseAppCheck() async {
  if (kIsWeb) {
    if (kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: WebDebugProvider(
          debugToken: _debugToken.trim().isEmpty ? null : _debugToken.trim(),
        ),
      );
      return AppCheckActivationOutcome.activated;
    }
    if (_webSiteKey.trim().isEmpty) {
      throw StateError(
        'FIREBASE_APP_CHECK_WEB_SITE_KEY is required for release web builds.',
      );
    }
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(_webSiteKey.trim()),
    );
    return AppCheckActivationOutcome.activated;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? AndroidDebugProvider(
                debugToken: _debugToken.trim().isEmpty
                    ? null
                    : _debugToken.trim(),
              )
            : const AndroidPlayIntegrityProvider(),
      );
      return AppCheckActivationOutcome.activated;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      await FirebaseAppCheck.instance.activate(
        providerApple: kDebugMode
            ? AppleDebugProvider(
                debugToken: _debugToken.trim().isEmpty
                    ? null
                    : _debugToken.trim(),
              )
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      return AppCheckActivationOutcome.activated;
    case TargetPlatform.windows:
      if (!kDebugMode) {
        throw UnsupportedError(
          'Release Windows builds are unsupported because Firebase App Check '
          'has no production attestation provider.',
        );
      }
      if (_windowsDebugToken.trim().isEmpty) {
        debugPrint(
          'Firebase App Check skipped on Windows: only an explicitly '
          'registered debug token is supported.',
        );
        return AppCheckActivationOutcome.skippedMissingConfiguration;
      }
      await FirebaseAppCheck.instance.activate(
        providerWindows: WindowsDebugProvider(
          debugToken: _windowsDebugToken.trim(),
        ),
      );
      return AppCheckActivationOutcome.activated;
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      if (!kDebugMode) {
        throw UnsupportedError(
          'Release ${defaultTargetPlatform.name} builds are unsupported '
          'because Firebase App Check has no production attestation provider.',
        );
      }
      return AppCheckActivationOutcome.skippedUnsupported;
  }
}
