import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/authored_chunk_patterns.dart';
import 'package:runner_core/track/chunk_pattern_tier.dart';
import 'package:test/test.dart';

import '../test_support/level_enemy_traversal.dart';

const _bosses = [
  EnemyId.bringerOfDeath,
  EnemyId.shoggoth,
  EnemyId.voidbornGoddess,
];
const _keys = [
  'forest_boss_easy_001',
  'forest_shoggoth_easy_001',
  'forest_voidborn_goddess_easy_001',
];

void main() {
  final forest = LevelRegistry.byId(LevelId.forest);
  for (final seed in [7, 42, 2026]) {
    test(
      'Forest seed $seed schedules easy, normal and hard boss milestones',
      () {
        final route = LevelTraversalRoute.scheduled(level: forest, seed: seed);
        final first = route.keys.indexOf(_keys.first);
        expect(first, greaterThan(0));
        expect(route.keys.where(_keys.contains), _keys);
        expect(route.keys, isNot(contains('forest_voidcaller_easy_001')));
        for (var i = 0; i < _keys.length; i++) {
          expect(route.keys.where((key) => key == _keys[i]), hasLength(1));
          final pattern = [
            ...forestEasyPatterns,
            ...forestNormalPatterns,
            ...forestHardPatterns,
          ].singleWhere((pattern) => pattern.chunkKey == _keys[i]);
          expect(pattern.bossArena!.enemyId, _bosses[i]);
        }
        expect(route.keys[first + 1], startsWith('forest_rocky_grove_normal_'));
        expect(
          route.keys[route.keys.indexOf(_keys[1]) + 1],
          startsWith('forest_rocky_grove_hard_'),
        );
        expect(route.keys.last, _keys.last);
        // ignore: avoid_print
        print(
          'FOREST_BOSS_ROUTE seed=$seed chunks=${route.keys.length} '
          'firstBoss=$first',
        );
      },
    );
  }

  for (final character in [
    PlayerCharacterRegistry.eloise,
    PlayerCharacterRegistry.eloiseWip,
  ]) {
    test('${character.id.name} clears a compressed authored boss sequence continuously', () {
      final segments = forest.assembly!.segments;
      // This combat fixture retains each authored boss room and continuous
      // player resources. The full route, including intervening ordinary
      // sections, is checked separately by the seeded traversal matrix.
      final core = GameCore(
        seed: 7,
        playerCharacter: character,
        levelDefinition: forest.copyWith(
          noEnemyChunks: 0,
          clearFirstChunkKey: true,
          assembly: LevelAssemblyDefinition(
            loopSegments: false,
            segments: [
              ...segments.where(
                (segment) => segment.groupId.startsWith('boss_'),
              ),
              const LevelAssemblySegment(
                segmentId: 'exit',
                groupId: 'default',
                difficulty: ChunkPatternTier.early,
                minChunkCount: 1,
                maxChunkCount: 1,
                requireDistinctChunks: true,
              ),
            ],
          ),
        ),
      );
      final defeated = <EnemyId>[];
      final introductions = <EnemyId>{};
      final blessings = <int>{};
      final trace = <String>[];
      for (var n = 0; n < core.tickHz * 300 && !core.gameOver; n++) {
        final snapshot = core.buildSnapshot();
        final arena = snapshot.bossArena;
        if (arena?.phase == BossArenaPhase.introduction) {
          introductions.add(arena!.enemyId);
        }
        if (arena?.phase == BossArenaPhase.defeated &&
            defeated.contains(arena!.enemyId)) {
          expect(
            snapshot.entities.where((e) => e.enemyId?.isBossSummon ?? false),
            isEmpty,
          );
        }
        if (arena?.phase == BossArenaPhase.defeated &&
            !defeated.contains(arena!.enemyId)) {
          defeated.add(arena.enemyId);
        }
        final blessing = snapshot.bossVictoryBlessing;
        if (blessing != null) blessings.add(blessing.startTick);
        if (defeated.length == 3 && core.playerPosX > 1800) break;
        final actor = snapshot.entities
            .where((entity) => entity.enemyId == arena?.enemyId)
            .firstOrNull;
        final fighting = arena?.phase == BossArenaPhase.combat && actor != null;
        final dx = fighting ? actor.pos.x - snapshot.playerEntity!.pos.x : 0.0;
        final tick = core.tick + 1;
        final goddess = arena?.enemyId == EnemyId.voidbornGoddess;
        final localX = core.playerPosX - 1200;
        final evadeCombo =
            goddess &&
            (actor?.anim == AnimKey.strike ||
                actor?.anim == AnimKey.teleportOut);
        final avoidHands = goddess && actor?.anim == AnimKey.ranged;
        final handGapX =
            119.2 + ((localX - 119.2) / 90.4).round().clamp(0, 4) * 90.4;
        final escapeDirection = localX < 70
            ? 1.0
            : localX > 530
            ? -1.0
            : -dx.sign;
        final axis = avoidHands
            ? ((handGapX - localX).abs() > 2 ? (handGapX - localX).sign : 0.0)
            : evadeCombo
            ? escapeDirection
            : fighting
            ? (dx.abs() > 20 ? dx.sign : 0.0)
            : 1.0;
        final crossGap =
            core.playerPosX >= 1200 &&
            core.playerPosX < 1800 &&
            (axis > 0 && localX > 190 && localX < 222 ||
                axis < 0 && localX > 270 && localX < 302);
        // Jump from the lip and reserve the airborne jump for a descending
        // crossing; an orb shove can consume the first jump before the gap.
        if (core.playerPosX > 1200 && core.tick % 10 == 0) {
          trace.add(
            '${core.tick} pos=${core.playerPosX},${core.playerPosY} grounded=${core.playerGrounded} axis=$axis jump=$crossGap arena=${arena?.enemyId}/${arena?.phase}',
          );
          if (trace.length > 40) trace.removeAt(0);
        }
        core.applyCommands([
          MoveAxisCommand(tick: tick, axis: axis),
          AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
          if (core.playerGrounded && crossGap ||
              goddess && localX > 200 && localX < 292 && core.playerVelY > 0 ||
              goddess && actor?.anim == AnimKey.strike && dx.abs() < 90 ||
              goddess &&
                  actor?.anim == AnimKey.cast &&
                  (actor?.animFrame ?? 0) >= 48 ||
              arena?.enemyId == EnemyId.shoggoth &&
                  actor?.anim == AnimKey.strike2 &&
                  dx.abs() < 180)
            JumpPressedCommand(tick: tick),
          if (evadeCombo && dx.abs() < 55) DashPressedCommand(tick: tick),
          if (fighting && !evadeCombo && !avoidHands && tick % 20 == 0)
            StrikePressedCommand(tick: tick),
          if (fighting && !evadeCombo && !avoidHands && tick % 45 == 0)
            ProjectilePressedCommand(tick: tick),
        ]);
        core.stepOneTick();
      }
      expect(
        core.gameOver,
        isFalse,
        reason:
            'tick=${core.tick} HP=${core.buildSnapshot().hud.hp} defeated=$defeated pos=${core.playerPosX},${core.playerPosY} arena=${core.buildSnapshot().bossArena?.enemyId}\n${trace.join('\n')}',
      );
      expect(defeated, _bosses);
      expect(introductions, _bosses.toSet());
      expect(blessings, hasLength(3));
      expect(core.playerPosX, greaterThan(1800));
    });
  }
}
