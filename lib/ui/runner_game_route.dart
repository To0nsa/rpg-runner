import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'runner_game_widget.dart';
import 'scoped/scoped_preferred_orientations.dart';
import 'scoped/scoped_system_ui_mode.dart';
import 'state/selection_state.dart';

/// Embed-friendly route factory for hosting the mini-game in any Flutter app.
///
/// Host apps can `Navigator.push(createRunnerGameRoute(...))` without depending
/// on this package's development host app (`lib/main.dart`).
///
/// [runSessionId], [runId], and [seed] must come from a server-issued run
/// session ticket.
Route<void> createRunnerGameRoute({
  required String runSessionId,
  required int runId,
  required int seed,
  required LevelId levelId,
  PlayerCharacterId playerCharacterId = PlayerCharacterId.eloise,
  RunMode runMode = RunMode.practice,
  EquippedLoadoutDef equippedLoadout = const EquippedLoadoutDef(),
  bool lockLandscape = true,
  List<DeviceOrientation>? restoreOrientations,
  SystemUiMode restoreSystemUiMode = SystemUiMode.edgeToEdge,
  RouteSettings? settings,
}) {
  if (runSessionId.trim().isEmpty) {
    throw ArgumentError.value(
      runSessionId,
      'runSessionId',
      'runSessionId must be non-empty.',
    );
  }
  if (runId <= 0) {
    throw ArgumentError.value(runId, 'runId', 'runId must be > 0.');
  }
  if (seed <= 0) {
    throw ArgumentError.value(seed, 'seed', 'seed must be > 0.');
  }
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (context) {
      Widget child = RunnerGameWidget(
        runSessionId: runSessionId,
        runId: runId,
        seed: seed,
        levelId: levelId,
        playerCharacterId: playerCharacterId,
        runMode: runMode,
        equippedLoadout: equippedLoadout,
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
        restoreMode: restoreSystemUiMode,
        child: child,
      );

      return Scaffold(body: child);
    },
  );
}
