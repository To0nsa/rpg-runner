import 'package:flutter/material.dart';

import 'menus/runner_menu_page.dart';

/// Development-only menu used by the standalone host app (`lib/main.dart`).
///
/// Not part of the embeddable runner API. Host apps should integrate the game
/// via `RunnerGameWidget` / `createRunnerGameRoute` (see `lib/runner.dart`).
class DevMenuPage extends StatelessWidget {
  const DevMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Walkscape Runner (Dev)',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color.fromARGB(255, 6, 21, 48),
      ),
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const RunnerMenuPage(),
              ),
            );
          },
          child: const Text('Menu'),
        ),
      ),
    );
  }
}
