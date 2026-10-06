import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/track/authored_chunk_patterns.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';

/// Real authored arena with normal character resources and committed combat.
GameCore bossVictoryCore({int hz = 60, PlayerCharacterDefinition? character}) =>
    GameCore(
      seed: 7,
      tickHz: hz,
      playerCharacter: character ?? PlayerCharacterRegistry.eloise,
      levelDefinition: LevelRegistry.byId(LevelId.forest).copyWith(
        noEnemyChunks: 0,
        earlyPatternChunks: 0,
        easyPatternChunks: 10,
        clearAssembly: true,
        clearFirstChunkKey: true,
        chunkPatternSource: ChunkPatternListSource(
          easyPatterns: [
            forestEasyPatterns.singleWhere(
              (p) => p.chunkKey == 'forest_boss_easy_001',
            ),
          ],
          normalPatterns: const [],
        ),
      ),
    );

List<Command> bossVictoryCommands(GameCore core) {
  final snapshot = core.buildSnapshot();
  final tick = core.tick + 1;
  if (snapshot.bossArena?.phase != BossArenaPhase.combat) {
    return [MoveAxisCommand(tick: tick, axis: 0)];
  }
  final boss = snapshot.entities.singleWhere(
    (e) => e.enemyId == EnemyId.bringerOfDeath,
  );
  final dx = boss.pos.x - snapshot.playerEntity!.pos.x;
  return [
    MoveAxisCommand(tick: tick, axis: dx.abs() > 20 ? dx.sign : 0),
    AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
    if (tick % (core.tickHz / 3).round() == 0) StrikePressedCommand(tick: tick),
    if (tick % (core.tickHz * .75).round() == 0)
      ProjectilePressedCommand(tick: tick),
  ];
}

void advanceToBossBlessing(GameCore core) {
  for (var i = 0; i < core.tickHz * 90 && !core.gameOver; i++) {
    core.applyCommands(bossVictoryCommands(core));
    core.stepOneTick();
    if (core.buildSnapshot().bossVictoryBlessing != null) return;
  }
  throw StateError(
    'Boss blessing not reached: tick=${core.tick}, HP=${core.buildSnapshot().hud.hp}',
  );
}
