import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

GameCore _forest(int seed, int hz, PlayerCharacterDefinition character) {
  final forest = LevelRegistry.byId(LevelId.forest);
  final segments = forest.assembly!.segments;
  final start = segments.indexWhere((s) => s.groupId == 'boss_shoggoth');
  return GameCore(
    seed: seed,
    tickHz: hz,
    playerCharacter: character,
    levelDefinition: forest.copyWith(
      noEnemyChunks: 0,
      clearFirstChunkKey: true,
      assembly: LevelAssemblyDefinition(
        loopSegments: false,
        segments: segments.sublist(start, start + 2),
      ),
    ),
  );
}

void main() {
  for (final hz in [30, 60, 90]) {
    for (final seed in [7, 42, 2026]) {
      for (final character in [
        PlayerCharacterRegistry.eloise,
        PlayerCharacterRegistry.eloiseWip,
      ]) {
        test(
          'authored Shoggoth arena clears at $hz Hz seed=$seed ${character.id.name}',
          () {
            final core = _forest(seed, hz, character);
            final summons = <int>{};
            var defeated = false;
            var released = false;
            var lowestBossHp = 30000;
            for (var n = 0; n < hz * 90 && !core.gameOver; n++) {
              final wasDefeated = defeated;
              final before = core.buildSnapshot();
              final boss = before.entities
                  .where((e) => e.enemyId == EnemyId.shoggoth)
                  .firstOrNull;
              final arena = before.bossArena;
              if (arena?.enemyId == EnemyId.shoggoth) {
                expect(arena!.hpMax100, 30000);
                lowestBossHp = arena.hp100 < lowestBossHp
                    ? arena.hp100
                    : lowestBossHp;
                defeated |= arena.phase == BossArenaPhase.defeated;
              }
              for (final summon in before.entities.where(
                (e) => e.enemyId == EnemyId.shoggothMinion,
              )) {
                summons.add(summon.id);
                expect(summon.pos.x, inInclusiveRange(24, 576));
                expect(lowestBossHp, lessThanOrEqualTo(24000));
              }
              if (boss != null) expect(boss.pos.x, inInclusiveRange(16, 584));
              if (defeated) {
                if (wasDefeated) {
                  expect(
                    before.entities.where(
                      (e) => e.enemyId == EnemyId.shoggothMinion,
                    ),
                    isEmpty,
                  );
                }
                if (core.playerPosX > 600) {
                  released = true;
                  break;
                }
              }
              final dx = boss == null ? 0.0 : boss.pos.x - core.playerPosX;
              final tick = core.tick + 1;
              core.applyCommands([
                MoveAxisCommand(
                  tick: tick,
                  axis: defeated
                      ? 1
                      : dx.abs() > 20
                      ? dx.sign
                      : 0,
                ),
                AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
                if (boss?.anim == AnimKey.strike2 && dx.abs() < 180)
                  JumpPressedCommand(tick: tick),
                if (!defeated && n % (hz / 3).round() == 0)
                  StrikePressedCommand(tick: tick),
                if (!defeated && n % (hz * .75).round() == 0)
                  ProjectilePressedCommand(tick: tick),
              ]);
              core.stepOneTick();
            }
            expect(summons, isNotEmpty);
            expect(
              defeated,
              isTrue,
              reason:
                  'tick=${core.tick} HP=${core.buildSnapshot().hud.hp} bossHP=$lowestBossHp',
            );
            expect(released, isTrue);
          },
        );
      }
    }

    test(
      'blocked approach snapshot marks the captured destination until return, $hz Hz',
      () {
        final core = _blockedCore(hz);
        Vec2? destination;
        var warningTicks = 0;
        var returned = false;
        final trace = <String>[];
        for (var n = 0; n < hz * 25 && !core.gameOver; n++) {
          final tick = core.tick + 1;
          core.applyCommands([MoveAxisCommand(tick: tick, axis: 0)]);
          core.stepOneTick();
          final boss = core
              .buildSnapshot()
              .entities
              .where((e) => e.enemyId == EnemyId.shoggoth)
              .firstOrNull;
          if (boss == null) continue;
          if (n % hz == 0) {
            trace.add(
              "$tick player=${core.playerPosX},${core.playerPosY} boss=${boss.pos} ${boss.anim} mark=${boss.teleportDestination}",
            );
          }
          if (boss.teleportDestination != null) {
            destination ??= boss.teleportDestination;
            expect(boss.anim, AnimKey.teleportOut);
            expect(boss.teleportDestination, destination);
            warningTicks++;
          } else if (destination != null && boss.anim == AnimKey.spawn) {
            expect(boss.pos.x, destination.x);
            expect(boss.pos.y, closeTo(destination.y, .1));
            returned = true;
            break;
          }
        }
        expect(returned, isTrue, reason: trace.join("\n"));
        expect(warningTicks, (36 * hz / 60).ceil());
      },
    );
  }
}

GameCore _blockedCore(int hz) => GameCore.terrainMotionHarness(
  seed: 7,
  tickHz: hz,
  playerCharacter: PlayerCharacterRegistry.eloise,
  levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
    noEnemyChunks: 0,
    earlyPatternChunks: 0,
    clearAssembly: true,
    clearFirstChunkKey: true,
    chunkPatternSource: ChunkPatternListSource(
      easyPatterns: const [],
      normalPatterns: [
        ChunkPattern(
          name: 'field_default_normal_001',
          chunkKey: 'field_default_normal_001',
          bossArena: BossArenaDefinition(
            id: 'blocked_shoggoth',
            enemyId: EnemyId.shoggoth,
            spawnX: 440,
            minX: 24,
            maxX: 576,
          ),
        ),
      ],
    ),
  ),
  terrainGeometry: const TerrainCompiler().compile([
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/floor',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: 'floor',
      ),
      surfaceKind: 'ground',
      vertices: [(-1000, 222), (5000, 222), (5000, 600), (-1000, 600)],
    ),
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/wall',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: 'wall',
      ),
      surfaceKind: 'obstacle',
      vertices: [(365, 0), (400, 0), (400, 222), (365, 222)],
    ),
  ], geometryVersion: 17),
);
