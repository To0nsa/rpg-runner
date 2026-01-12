import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/levels/level_id.dart';
import '../core/players/player_character_definition.dart';
import 'runner_game_widget.dart';
import 'scoped/scoped_preferred_orientations.dart';
import 'scoped/scoped_system_ui_mode.dart';

/// Embed-friendly route factory for hosting the mini-game in any Flutter app.
///
/// Host apps can `Navigator.push(createRunnerGameRoute(...))` without depending
/// on this package's development host app (`lib/main.dart`).
///
Route<void> createRunnerGameRoute({
  int seed = 1,
  LevelId levelId = LevelId.defaultLevel,
  PlayerCharacterId playerCharacterId = PlayerCharacterId.eloise,
  bool lockLandscape = true,
  List<DeviceOrientation>? restoreOrientations,
}) {
  return MaterialPageRoute<void>(
    builder: (context) {
      Widget child = RunnerGameWidget(
        seed: seed,
        levelId: levelId,
        playerCharacterId: playerCharacterId,
        onExit: () => Navigator.of(context).maybePop(),
      );

      if (lockLandscape) {
        child = ScopedPreferredOrientations(
          preferredOrientations: const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
          restoreOrientations: restoreOrientations,
          child: child,
        );
      }

      // Hide status + nav bars only for this route.
      child = ScopedSystemUiMode(
        mode: SystemUiMode.immersiveSticky,
        restoreMode: SystemUiMode.edgeToEdge,
        child: child,
      );

      return Scaffold(body: child);
    },
  );
}
