import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/track/authored_chunk_patterns.dart';
import 'package:test/test.dart';

import '../test_support/level_enemy_traversal.dart';

const _bosses = [
  EnemyId.bringerOfDeath,
  EnemyId.voidbornGoddess,
  EnemyId.shoggoth,
  EnemyId.voidcaller,
];
const _keys = [
  'forest_boss_easy_001',
  'forest_voidborn_goddess_easy_001',
  'forest_shoggoth_easy_001',
  'forest_voidcaller_easy_001',
];

void main() {
  final forest = LevelRegistry.byId(LevelId.forest);
  for (final seed in [7, 42, 2026]) {
    test('Forest seed $seed schedules each boss once in consecutive rooms', () {
      final route = LevelTraversalRoute.scheduled(level: forest, seed: seed);
      final first = route.keys.indexOf(_keys.first);
      expect(first, greaterThan(0));
      expect(route.keys.sublist(first, first + 4), _keys);
      for (var i = 0; i < _keys.length; i++) {
        expect(route.keys.where((key) => key == _keys[i]), hasLength(1));
        final pattern = forestEasyPatterns.singleWhere(
          (pattern) => pattern.chunkKey == _keys[i],
        );
        expect(pattern.bossArena!.enemyId, _bosses[i]);
      }
      expect(
        route.keys[first + 4],
        startsWith('forest_enchanted_forest_easy_'),
      );
      // ignore: avoid_print
      print(
        'FOREST_BOSS_ROUTE seed=$seed chunks=${route.keys.length} '
        'firstBoss=$first',
      );
    });
  }

  for (final character in [
    PlayerCharacterRegistry.eloise,
    PlayerCharacterRegistry.eloiseWip,
  ]) {
    test('${character.id.name} clears the four authored arenas continuously', () {
      final segments = forest.assembly!.segments;
      final start = segments.indexWhere(
        (segment) => segment.groupId == 'boss_bringer_of_death',
      );
      // Start at the boss section, retaining its real terrain, spacing, player
      // resources and combat; the next ordinary section supplies the exit.
      final core = GameCore(
        seed: 7,
        playerCharacter: character,
        levelDefinition: forest.copyWith(
          noEnemyChunks: 0,
          clearFirstChunkKey: true,
          assembly: LevelAssemblyDefinition(
            loopSegments: false,
            segments: segments.sublist(start, start + 5),
          ),
        ),
      );
      final defeated = <EnemyId>[];
      final introductions = <EnemyId>{};
      final blessings = <int>{};
      for (var n = 0; n < core.tickHz * 300 && !core.gameOver; n++) {
        final snapshot = core.buildSnapshot();
        final arena = snapshot.bossArena;
        if (arena?.phase == BossArenaPhase.introduction) {
          introductions.add(arena!.enemyId);
        }
        if (arena?.phase == BossArenaPhase.defeated &&
            !defeated.contains(arena!.enemyId)) {
          defeated.add(arena.enemyId);
          expect(
            snapshot.entities.where((e) => e.enemyId?.isBossSummon ?? false),
            isEmpty,
          );
        }
        final blessing = snapshot.bossVictoryBlessing;
        if (blessing != null) blessings.add(blessing.startTick);
        if (defeated.length == 4 && core.playerPosX > 2400) break;
        final actor = snapshot.entities
            .where((entity) => entity.enemyId == arena?.enemyId)
            .firstOrNull;
        final fighting = arena?.phase == BossArenaPhase.combat && actor != null;
        final dx = fighting ? actor.pos.x - snapshot.playerEntity!.pos.x : 0.0;
        final tick = core.tick + 1;
        core.applyCommands([
          MoveAxisCommand(
            tick: tick,
            axis: fighting ? (dx.abs() > 20 ? dx.sign : 0) : 1,
          ),
          AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
          if (fighting && tick % 20 == 0) StrikePressedCommand(tick: tick),
          if (fighting && tick % 45 == 0) ProjectilePressedCommand(tick: tick),
        ]);
        core.stepOneTick();
      }
      expect(
        core.gameOver,
        isFalse,
        reason:
            'tick=${core.tick} HP=${core.buildSnapshot().hud.hp} defeated=$defeated',
      );
      expect(defeated, _bosses);
      expect(introductions, _bosses.toSet());
      expect(blessings, hasLength(4));
      expect(core.playerPosX, greaterThan(2400));
    });
  }
}
