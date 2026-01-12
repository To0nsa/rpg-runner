import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'ui/dev_menu_page.dart';

/// Development-only host app for running the mini-game standalone.
///
/// The runner is intended to be embedded in another Flutter app via
/// `RunnerGameWidget` / `createRunnerGameRoute` (see `lib/runner.dart`).
/// Keep `main.dart` free of assumptions that would prevent embedding; embedding
/// apps should initialize Firebase (and any other app services) themselves.
///
/// This dev host initializes Firebase so Firebase-backed features work when
/// running the runner in isolation.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const _DevApp());
}

class _DevApp extends StatelessWidget {
  const _DevApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rpg Runner (Dev)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 6, 21, 48),
        ),
        useMaterial3: true,
      ),
      home: const DevMenuPage(),
    );
  }
}
