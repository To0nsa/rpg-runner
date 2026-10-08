import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

import '../lib/src/replay_simulation.dart';

GameCore _core(int hz, {EnemyId bossId = EnemyId.bringerOfDeath}) => GameCore(
  seed: 7,
  tickHz: hz,
  playerCharacter: PlayerCharacterRegistry.eloise,
  levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
    noEnemyChunks: 0,
    earlyPatternChunks: 0,
    clearAssembly: true,
    clearFirstChunkKey: true,
    chunkPatternSource: ChunkPatternListSource(
      easyPatterns: [],
      normalPatterns: [
        ChunkPattern(
          name: 'field_default_normal_001',
          chunkKey: 'field_default_normal_001',
          bossArena: BossArenaDefinition(
            id: 'replay_boss',
            enemyId: bossId,
            spawnX: 440,
            minX: 24,
            maxX: 576,
          ),
        ),
      ],
    ),
  ),
);

void main() {
  for (final hz in [30, 60, 90]) {
    test('all three beam combo pulses damage and replay at $hz Hz', () {
      final direct = _core(hz, bossId: EnemyId.voidcaller);
      final replay = _core(hz, bossId: EnemyId.voidcaller);
      final hitTicks = <int>[];
      for (var n = 0; n < hz * 8 && hitTicks.length < 3; n++) {
        final before = direct.buildSnapshot().hud.hp;
        direct.applyCommands(const []);
        direct.stepOneTick();
        if (direct.buildSnapshot().hud.hp < before) hitTicks.add(direct.tick);
      }
      final pulseInterval = 2 * (.08 * hz).round();
      expect(hitTicks, hasLength(3));
      expect(hitTicks[1] - hitTicks[0], pulseInterval);
      expect(hitTicks[2] - hitTicks[1], pulseInterval);
      expect(pulseInterval, lessThan((.25 * hz).ceil()));
      final result = runReplaySimulation(
        core: replay,
        totalTicks: direct.tick,
        commandStream: const [],
      );
      expect(result.runEnded, isNull);
      expect(replay.buildSnapshot().hud.hp, direct.buildSnapshot().hud.hp);
      expect(replay.playerPosX, direct.playerPosX);
      expect(replay.playerPosY, direct.playerPosY);
    });
    test(
      'accepted pillar damage, weaken and bounded shove replay at $hz Hz',
      () {
        final direct = _core(hz), replay = _core(hz);
        final initialX = direct.playerPosX;
        final initialHp = direct.buildSnapshot().hud.hp;
        var minimumX = initialX;
        final ticks = hz * 5;
        for (var i = 0; i < ticks; i++) {
          direct.applyCommands(const []);
          direct.stepOneTick();
          if (direct.playerPosX < minimumX) minimumX = direct.playerPosX;
        }
        expect(direct.buildSnapshot().hud.hp, lessThan(initialHp));
        expect(
          direct.buildSnapshot().playerEntity!.statusVisualMask &
              EntityStatusVisualMask.weaken,
          isNonZero,
        );
        expect(minimumX, lessThan(initialX));
        final result = runReplaySimulation(
          core: replay,
          totalTicks: ticks,
          commandStream: const [],
        );
        expect(result.runEnded, isNull);
        expect(replay.playerPosX, direct.playerPosX);
        expect(replay.playerPosY, direct.playerPosY);
        expect(replay.buildSnapshot().hud.hp, direct.buildSnapshot().hud.hp);
        expect(
          replay.buildSnapshot().playerEntity!.statusVisualMask,
          direct.buildSnapshot().playerEntity!.statusVisualMask,
        );
        expect(
          replay.buildSnapshot().bossArena?.phase,
          direct.buildSnapshot().bossArena?.phase,
        );
      },
    );
    test('boss entrance, combat clear and score replay at $hz Hz', () {
      final direct = _core(hz), replay = _core(hz);
      final frames = <ReplayCommandFrameV1>[];
      var defeated = false, released = false;
      for (var n = 0; n < hz * 90 && !direct.gameOver; n++) {
        final s = direct.buildSnapshot();
        final boss = s.entities
            .where((e) => e.enemyId == EnemyId.bringerOfDeath)
            .firstOrNull;
        final dx = boss == null ? 0.0 : boss.pos.x - s.playerEntity!.pos.x;
        final axis = dx.abs() > 20 ? dx.sign : 0.0;
        final tick = direct.tick + 1;
        final strike = n % ((hz / 3).round()) == 0;
        final shot = n % ((hz * .75).round()) == 0;
        frames.add(
          ReplayCommandFrameV1(
            tick: tick,
            moveAxis: axis,
            aimDirX: dx >= 0 ? 1 : -1,
            aimDirY: 0,
            pressedMask:
                (strike ? ReplayCommandFrameV1.pressedStrikeBit : 0) |
                (shot ? ReplayCommandFrameV1.pressedProjectileBit : 0),
          ),
        );
        direct.applyCommands([
          MoveAxisCommand(tick: tick, axis: axis),
          AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
          if (strike) StrikePressedCommand(tick: tick),
          if (shot) ProjectilePressedCommand(tick: tick),
        ]);
        direct.stepOneTick();
        defeated |=
            direct.buildSnapshot().bossArena?.phase == BossArenaPhase.defeated;
        if (defeated && direct.buildSnapshot().bossArena == null) {
          released = true;
          break;
        }
      }
      expect(released, isTrue);
      final result = runReplaySimulation(
        core: replay,
        totalTicks: direct.tick,
        commandStream: frames,
      );
      expect(result.runEnded, isNull);
      expect(replay.buildSnapshot().bossArena, isNull);
      expect(replay.distance, direct.distance);
      expect(replay.buildSnapshot().hud.hp, direct.buildSnapshot().hud.hp);
      direct.giveUp();
      replay.giveUp();
      final a = direct.drainEvents().whereType<RunEndedEvent>().single;
      final b = replay.drainEvents().whereType<RunEndedEvent>().single;
      expect(b.stats.enemyKillCounts, a.stats.enemyKillCounts);
      expect(b.stats.excludedScoreTicks, a.stats.excludedScoreTicks);
      expect(b.stats.enemyKillCounts[EnemyId.bringerOfDeath.index], 1);
      int score(RunEndedEvent event) => buildRunScoreBreakdown(
        tick: event.tick,
        excludedScoreTicks: event.stats.excludedScoreTicks,
        distanceUnits: event.distance,
        collectibles: event.stats.collectibles,
        collectibleScore: event.stats.collectibleScore,
        enemyKillCounts: event.stats.enemyKillCounts,
        tuning: direct.scoreTuning,
        tickHz: hz,
      ).totalPoints;
      expect(score(b), score(a));
    });
  }
}
