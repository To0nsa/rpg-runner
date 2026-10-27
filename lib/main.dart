import 'package:flutter/material.dart';

import 'ui/app/create_app_services.dart';
import 'ui/app/ui_app.dart';

/// Standalone entry point: local Practice on web, account services on native.
///
/// The runner can also be embedded in other Flutter apps via
/// `RunnerGameWidget` / `createRunnerGameRoute` (see `lib/runner.dart`).
/// Account-backed embedding apps should initialize Firebase, activate App Check where
/// supported, and initialize any other services themselves.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(UiApp(services: createAppServices()));
}
