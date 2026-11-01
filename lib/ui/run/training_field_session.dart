import 'package:flutter/foundation.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/training/authored_training_field.dart';

import '../../game/game_controller.dart';
import '../../game/input/aim_preview.dart';
import '../../game/input/runner_input_router.dart';
import '../../game/runner_flame_game.dart';
import '../../game/terrain/prepared_terrain_assets.dart';

/// A local, disposable build test. No tickets, recorder, rewards or AppState.
final class TrainingFieldSession extends ChangeNotifier {
  TrainingFieldSession({
    required PlayerCharacterDefinition character,
    required EquippedLoadoutDef loadout,
  }) {
    controller = GameController(
      core: GameCore.trainingField(
        definition: trainingFieldDefinition,
        playerCharacter: character,
        equippedLoadout: loadout,
        terrainPreparation: PreparedTerrainAssets().prepare,
      ),
    )..setPaused(true);
    input = RunnerInputRouter(controller: controller);
    game = RunnerFlameGame(
      controller: controller,
      input: input,
      playerCharacter: character,
      projectileAimPreview: projectilePreview,
      meleeAimPreview: meleePreview,
    );
    game.loadState.addListener(_changed);
  }
  late final GameController controller;
  late final RunnerInputRouter input;
  late final RunnerFlameGame game;
  final projectilePreview = AimPreviewModel();
  final meleePreview = AimPreviewModel();
  bool _disposed = false;
  bool get ready => game.loadState.value.phase == RunLoadPhase.worldReady;
  bool get failed => game.loadState.value.phase == RunLoadPhase.failed;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    game.loadState.removeListener(_changed);
    game.cancelPreparation();
    controller.shutdown();
    controller.dispose();
    projectilePreview.dispose();
    meleePreview.dispose();
    super.dispose();
  }
}
