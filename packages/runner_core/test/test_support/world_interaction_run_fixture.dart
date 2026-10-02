import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/playtest/level_playtest_scenario.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';

/// Normal and captured hosts share a real seeded Forest opening. The test-only
/// initial placement starts airborne above its third-chunk shrine; all contact
/// thereafter is resolved by actual player physics. This is a mechanic fixture,
/// not evidence of traversing the preceding route.
GameCore worldInteractionRunCore(
  PlayerCharacterDefinition character, {
  bool editor = false,
  int tickHz = 60,
}) {
  final level = LevelRegistry.byId(LevelId.forest).copyWith(
    noEnemyChunks: 9999,
    tuning: const CoreTuning(camera: CameraTuning(speedLagMulX: 0)),
  );
  final core = editor
      ? GameCore.levelPlaytest(
          scenario: LevelPlaytestScenario(
            levelDefinition: level,
            terrainChunks: stagedAuthoredTerrain.chunks.where(
              (c) => c.levelId == 'forest' && c.status == 'active',
            ),
            seed: 15,
            tickHz: tickHz,
            playerCharacter: character,
            equippedLoadout: const EquippedLoadoutDef(),
          ),
        )
      : GameCore(
          seed: 15,
          tickHz: tickHz,
          levelDefinition: level,
          playerCharacter: character,
          equippedLoadoutOverride: const EquippedLoadoutDef(),
        );
  final shrine = core.buildSnapshot().interactions.first;
  core.setPlayerPosXYUnsafeForTest(shrine.x, shrine.y - 80);
  return core;
}

Object worldInteractionRunState(GameCore core) {
  final s = core.buildSnapshot();
  return [
    s.tick,
    s.paused,
    s.gameOver,
    core.playerPosX,
    core.playerPosY,
    core.playerVelX,
    core.playerVelY,
    s.hud.hp,
    s.hud.mana,
    s.hud.stamina,
    [for (final b in s.hud.blessings) (b.id, b.grantedAtTick)],
    [
      for (final i in s.interactions)
        (i.instanceId, i.x, i.y, i.active, i.elapsedTicks),
    ],
  ];
}
