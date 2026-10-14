import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:run_protocol/board_key.dart';

import 'runner_game_widget.dart';
import 'controls/movement_control_mode.dart';
import 'scoped/scoped_preferred_orientations.dart';
import 'scoped/scoped_system_ui_mode.dart';
import 'state/boards/ghost_replay_cache.dart';
import 'state/ownership/selection_state.dart';

/// Embed-friendly route factory for hosting the mini-game in any Flutter app.
///
/// Host apps can `Navigator.push(createRunnerGameRoute(...))` without depending
/// on this package's development host app (`lib/main.dart`).
///
/// Except for debug-only [isDeveloperPractice] runs, [runSessionId], [runId],
/// [seed] and [tickHz] must come from a server-issued run session ticket.
/// Developer Practice uses the same gameplay without replay or account writes.
/// The hosted widget keeps its loading presentation visible while initial
/// render assets, upcoming terrain, and the selected ghost playback buffer and
/// outlines are prepared and any online replay recorder has opened its file. Required
/// loading failures offer retry and exit; retries before Start reuse the ticket
/// after closing the previous attempt. HUD and controls appear only when ready.
/// The complete initial terrain window is awaited; native startup builds use
/// bounded parallelism while runtime terrain admission stays enforced.
/// Ghost precomputation never advances live gameplay; its run-owned worker and
/// render preparation are released when the route closes.
/// Runtime terrain waits preserve the same run and recorder, hold simulation
/// before the next tick, and offer retry/exit if preparation fails.
/// Authenticated hosts keep their AppState alive after this route closes and
/// forward lifecycle changes to AppState.setRunSubmissionForeground so durable
/// reward verification can finish and refresh ownership on subsequent screens.
/// Mandatory boss arenas keep this route and its run session alive while Core
/// holds entrance controls and later resumes normal running after the fight.
/// [movementControlMode] selects touch presentation; both modes emit the same
/// full-strength movement commands. The host owns persistence of this choice.
Route<void> createRunnerGameRoute({
  required String runSessionId,
  required int runId,
  required int seed,
  int tickHz = 60,
  required LevelId levelId,
  PlayerCharacterId playerCharacterId = PlayerCharacterId.eloise,
  RunMode runMode = RunMode.practice,
  EquippedLoadoutDef equippedLoadout = const EquippedLoadoutDef(),
  String? boardId,
  BoardKey? boardKey,
  GhostReplayBootstrap? ghostReplayBootstrap,
  bool isDeveloperPractice = false,
  MovementControlMode movementControlMode = MovementControlMode.arrows,
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
  if (tickHz <= 0) {
    throw ArgumentError.value(tickHz, 'tickHz', 'tickHz must be > 0.');
  }
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (context) {
      Widget child = RunnerGameWidget(
        movementControlMode: movementControlMode,
        runSessionId: runSessionId,
        runId: runId,
        seed: seed,
        tickHz: tickHz,
        levelId: levelId,
        playerCharacterId: playerCharacterId,
        runMode: runMode,
        equippedLoadout: equippedLoadout,
        boardId: boardId,
        boardKey: boardKey,
        ghostReplayBootstrap: ghostReplayBootstrap,
        isDeveloperPractice: isDeveloperPractice,
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
