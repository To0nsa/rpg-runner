import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/playtest/level_playtest_scenario.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/traps/trap_geometry.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';

/// Uses the real compiled flat terrain in both app and captured Level Play.
/// The explicit matching pattern is test content, never an alternate run option.
LevelDefinition trapRunLevel(
  TrapId id, {
  int zIndex = TrapPlacement.defaultZIndex,
}) => LevelDefinition(
  id: LevelId.field,
  groundTopY: 222,
  noEnemyChunks: 9999,
  earlyPatternChunks: 0,
  easyPatternChunks: 0,
  normalPatternChunks: 100,
  tuning: const CoreTuning(camera: CameraTuning(speedLagMulX: 0)),
  chunkPatternSource: ChunkPatternListSource(
    easyPatterns: [],
    hardPatterns: [],
    normalPatterns: [
      ChunkPattern(
        name: 'field_flat',
        chunkKey: 'field_flat',
        traps: [
          TrapPlacement(
            trapId: id,
            zIndex: zIndex,
            x: id == TrapId.poisonDarts ? 400 : 300,
            y: switch (id) {
              TrapId.spike => 220,
              TrapId.swingingAxe => 140,
              TrapId.poisonDarts => 202,
            },
            facing: id == TrapId.poisonDarts ? Facing.left : Facing.right,
            trigger: switch (id) {
              TrapId.spike => const TrapRect(-40, -40, 80, 48),
              TrapId.swingingAxe => const TrapRect(-40, 40, 80, 90),
              TrapId.poisonDarts => const TrapRect(-130, -32, 140, 64),
            },
          ),
        ],
      ),
    ],
  ),
);

const trapRunSeed = 4401;
const trapRunLoadout = EquippedLoadoutDef();

GameCore trapRunCore(
  PlayerCharacterDefinition character,
  TrapId id, {
  bool editor = false,
  int zIndex = TrapPlacement.defaultZIndex,
}) {
  final level = trapRunLevel(id, zIndex: zIndex);
  if (editor) {
    return GameCore.levelPlaytest(
      scenario: LevelPlaytestScenario(
        levelDefinition: level,
        terrainChunks: stagedAuthoredTerrain.chunks.where(
          (c) => c.chunkKey == 'field_flat',
        ),
        seed: trapRunSeed,
        playerCharacter: character,
        equippedLoadout: trapRunLoadout,
      ),
    );
  }
  return GameCore(
    seed: trapRunSeed,
    levelDefinition: level,
    playerCharacter: character,
    equippedLoadoutOverride: trapRunLoadout,
  );
}

/// Values observed by gameplay/UI, excluding the host's level provenance.
Object trapRunState(GameCore core) {
  final s = core.buildSnapshot();
  return [
    s.tick,
    s.distance,
    s.hud.hp,
    s.hud.lastDamageTick,
    s.gameOver,
    [
      for (final t in s.traps)
        (t.source, t.x, t.y, t.facing, t.phase, t.frameIndex),
    ],
    [
      for (final e in s.entities)
        (
          e.id,
          e.kind,
          e.projectileId,
          e.pos.x,
          e.pos.y,
          e.vel?.x,
          e.vel?.y,
          e.statusVisualMask,
          e.anim,
          e.animFrame,
        ),
    ],
  ];
}
