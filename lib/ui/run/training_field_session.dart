import 'package:flutter/foundation.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/training/authored_training_field.dart';

import '../../game/game_controller.dart';
import '../../game/input/aim_preview.dart';
import '../../game/input/runner_input_router.dart';
import '../../game/runner_flame_game.dart';
import '../../game/runner_gameplay_runtime.dart';
import '../../game/terrain/prepared_terrain_assets.dart';

/// A local, disposable build test. No tickets, recorder, rewards or AppState.
final class TrainingFieldSession extends ChangeNotifier {
  TrainingFieldSession({
    required PlayerCharacterDefinition character,
    required EquippedLoadoutDef loadout,
  }) {
    runtime = RunnerGameplayRuntime(
      core: GameCore.trainingField(
        definition: trainingFieldDefinition,
        playerCharacter: character,
        equippedLoadout: loadout,
        terrainPreparation: PreparedTerrainAssets().prepare,
      ),
    );
    game.loadState.addListener(_changed);
  }
  late final RunnerGameplayRuntime runtime;
  GameController get controller => runtime.controller;
  RunnerInputRouter get input => runtime.input;
  RunnerFlameGame get game => runtime.game;
  AimPreviewModel get projectilePreview => runtime.projectilePreview;
  AimPreviewModel get meleePreview => runtime.meleePreview;
  bool _stopped = false;
  bool _disposed = false;
  bool get ready => game.loadState.value.phase == RunLoadPhase.worldReady;
  bool get failed => game.loadState.value.phase == RunLoadPhase.failed;

  void _changed() {
    if (!_stopped) notifyListeners();
  }

  /// Cancels work while retaining notifiers until the previous view unmounts.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    game.loadState.removeListener(_changed);
    runtime.stop();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
    runtime.dispose();
    super.dispose();
  }
}
