import 'package:flutter/material.dart';

import 'app/ui_routes.dart';
import 'theme/ui_tokens.dart';

/// Development-only menu used by the standalone host app (`lib/main.dart`).
///
/// Not part of the embeddable runner API. Host apps should integrate the game
/// via `RunnerGameWidget` / `createRunnerGameRoute` (see `lib/runner.dart`).
class DevMenuPage extends StatelessWidget {
  const DevMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Scaffold(
      backgroundColor: ui.colors.background,
      appBar: AppBar(
        title: Text(
          'rpg Runner (Dev)',
          style: ui.text.title.copyWith(
            color: ui.colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ui.colors.background,
        iconTheme: IconThemeData(color: ui.colors.textPrimary),
      ),
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).pushNamed(UiRoutes.hub);
          },
          child: const Text('Menu'),
        ),
      ),
    );
  }
}
