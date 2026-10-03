import 'package:flutter/material.dart';

import 'ui/app/firebase_app_services.dart';
import 'ui/app/ui_app.dart';

/// Production app entry point for the rpg-runner game.
///
/// The runner can also be embedded in other Flutter apps via
/// `RunnerGameWidget` / `createRunnerGameRoute` (see `lib/runner.dart`).
/// Embedding apps should initialize Firebase, activate App Check where
/// supported, and initialize any other services themselves.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(UiApp(services: createFirebaseAppServices()));
}
