import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';

/// Goddess combat on authored Field terrain, using large finite player pools
/// to isolate supply from survival/AI tuning. Zero resource regen exposes pickup
/// restoration exactly; neither replay nor direct execution mutates the world.
GameCore bossResourceSupplyCore({
  int hz = 60,
  PlayerCharacterDefinition? character,
}) {
  final base = character ?? PlayerCharacterRegistry.eloise;
  return GameCore(
    seed: 7,
    tickHz: hz,
    playerCharacter: base.copyWith(
      tuning: base.tuning.copyWith(
        resource: const ResourceTuning(
          playerHpMax: 10000,
          playerManaMax: 1000,
          playerStaminaMax: 1000,
          playerManaRegenPerSecond: 0,
          playerStaminaRegenPerSecond: 0,
        ),
      ),
    ),
    levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
      noEnemyChunks: 0,
      earlyPatternChunks: 0,
      easyPatternChunks: 10,
      normalPatternChunks: 0,
      clearAssembly: true,
      clearFirstChunkKey: true,
      chunkPatternSource: ChunkPatternListSource(
        easyPatterns: [
          ChunkPattern(
            name: 'field_default_easy_004',
            chunkKey: 'field_default_easy_004',
            bossArena: BossArenaDefinition(
              id: 'supply_goddess',
              enemyId: EnemyId.voidbornGoddess,
              spawnX: 440,
              minX: 24,
              maxX: 576,
            ),
          ),
        ],
      ),
    ),
  );
}

EntityRenderSnapshot? resourceGem(GameCore core) => core
    .buildSnapshot()
    .entities
    .where(
      (e) =>
          e.pickupVariant == PickupVariant.restorationMana ||
          e.pickupVariant == PickupVariant.restorationStamina,
    )
    .firstOrNull;

/// Fight until the milestone, then walk to the visible gem without spending.
List<Command> bossResourceSupplyCommands(GameCore core) {
  final snapshot = core.buildSnapshot();
  final tick = core.tick + 1;
  final gem = resourceGem(core);
  if (gem != null) {
    final dx = gem.pos.x - core.playerPosX;
    return [MoveAxisCommand(tick: tick, axis: dx.abs() > 2 ? dx.sign : 0)];
  }
  if (snapshot.bossArena?.phase != BossArenaPhase.combat) {
    return [MoveAxisCommand(tick: tick, axis: 1)];
  }
  final boss = snapshot.entities.singleWhere(
    (e) => e.enemyId == EnemyId.voidbornGoddess,
  );
  final dx = boss.pos.x - core.playerPosX;
  return [
    MoveAxisCommand(tick: tick, axis: dx.abs() > 25 ? dx.sign : 0),
    AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
    if (tick % (core.tickHz / 3).round() == 0) StrikePressedCommand(tick: tick),
    if (tick % (core.tickHz * .75).round() == 0)
      ProjectilePressedCommand(tick: tick),
  ];
}
