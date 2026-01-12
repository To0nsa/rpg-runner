import 'package:flutter/material.dart';

import 'ui/dev_menu_page.dart';

/// Development-only host app for running the mini-game standalone.
///
/// The runner is intended to be embedded in another Flutter app via
/// `RunnerGameWidget` / `createRunnerGameRoute` (see `lib/runner.dart`).
/// Keep `main.dart` free of assumptions that would prevent embedding.
void main() {
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
