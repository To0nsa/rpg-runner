import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

import '../lib/src/replay_simulation.dart';

GameCore _core(
  int hz, {
  EnemyId bossId = EnemyId.bringerOfDeath,
  EquippedLoadoutDef? loadout,
}) => GameCore(
  seed: 7,
  tickHz: hz,
  playerCharacter: PlayerCharacterRegistry.eloise,
  equippedLoadoutOverride: loadout,
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
    for (final (spell, expectedStatus) in [
      (ProjectileId.holyBolt, EntityStatusVisualMask.none),
      (ProjectileId.darkBolt, EntityStatusVisualMask.weaken),
      (ProjectileId.waterBolt, EntityStatusVisualMask.drench),
      (ProjectileId.acidBolt, EntityStatusVisualMask.vulnerable),
    ]) {
      test('$spell respects boss defenses and replays at $hz Hz', () {
        final loadout = EquippedLoadoutDef(projectileSlotSpellId: spell);
        final direct = _core(hz, loadout: loadout);
        final replay = _core(hz, loadout: loadout);
        final frames = <ReplayCommandFrameV1>[];
        int? hitTick;
        var actedAfterHit = false;
        for (var n = 0; n < hz * 12 && !direct.gameOver; n++) {
          final before = direct.buildSnapshot();
          final boss = before.entities
              .where((e) => e.enemyId == EnemyId.bringerOfDeath)
              .firstOrNull;
          final dx = boss == null ? 0.0 : boss.pos.x - direct.playerPosX;
          final axis = dx.abs() > 200 ? dx.sign : 0.0;
          final tick = direct.tick + 1;
          final shot = hitTick == null && n % ((hz * .75).round()) == 0;
          frames.add(
            ReplayCommandFrameV1(
              tick: tick,
              moveAxis: axis,
              aimDirX: dx >= 0 ? 1 : -1,
              aimDirY: 0,
              pressedMask: shot ? ReplayCommandFrameV1.pressedProjectileBit : 0,
            ),
          );
          direct.applyCommands([
            MoveAxisCommand(tick: tick, axis: axis),
            AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
            if (shot) ProjectilePressedCommand(tick: tick),
          ]);
          direct.stepOneTick();
          final after = direct.buildSnapshot();
          final arena = after.bossArena;
          if (arena != null && arena.hp100 < arena.hpMax100) hitTick ??= tick;
          if (hitTick != null) {
            final liveBoss = after.entities.singleWhere(
              (e) => e.enemyId == EnemyId.bringerOfDeath,
            );
            expect(liveBoss.statusVisualMask, expectedStatus);
            actedAfterHit |=
                liveBoss.anim == AnimKey.cast ||
                liveBoss.anim == AnimKey.strike;
            if (tick - hitTick >= hz) break;
          }
        }
        expect(
          hitTick,
          isNotNull,
          reason: 'the spell must actually hit the boss',
        );
        expect(actedAfterHit, isTrue);
        final result = runReplaySimulation(
          core: replay,
          totalTicks: direct.tick,
          commandStream: frames,
        );
        expect(result.runEnded, isNull);
        final a = direct.buildSnapshot(), b = replay.buildSnapshot();
        expect(b.bossArena!.hp100, a.bossArena!.hp100);
        expect(b.hud.hp, a.hud.hp);
        final directBoss = a.entities.singleWhere(
          (e) => e.enemyId == EnemyId.bringerOfDeath,
        );
        final replayBoss = b.entities.singleWhere(
          (e) => e.enemyId == EnemyId.bringerOfDeath,
        );
        expect(replayBoss.statusVisualMask, directBoss.statusVisualMask);
        expect(replayBoss.anim, directBoss.anim);
        expect(replayBoss.pos.x, directBoss.pos.x);
        expect(replay.playerPosX, direct.playerPosX);
      });
    }

    test('mixed Scythe Sweep damage and shove replay at $hz Hz', () {
      final direct = _core(hz), replay = _core(hz);
      final frames = <ReplayCommandFrameV1>[];
      var hitBySweep = false;
      for (var n = 0; n < hz * 12 && !direct.gameOver; n++) {
        final before = direct.buildSnapshot();
        final boss = before.entities
            .where((e) => e.enemyId == EnemyId.bringerOfDeath)
            .firstOrNull;
        final dx = boss == null ? 0.0 : boss.pos.x - direct.playerPosX;
        final axis = dx.abs() > 100 ? dx.sign : 0.0;
        final tick = direct.tick + 1;
        frames.add(ReplayCommandFrameV1(tick: tick, moveAxis: axis));
        direct.applyCommands([MoveAxisCommand(tick: tick, axis: axis)]);
        direct.stepOneTick();
        if (boss?.anim == AnimKey.strike &&
            direct.buildSnapshot().hud.hp < before.hud.hp) {
          hitBySweep = true;
          break;
        }
      }
      expect(hitBySweep, isTrue);
      final result = runReplaySimulation(
        core: replay,
        totalTicks: direct.tick,
        commandStream: frames,
      );
      expect(result.runEnded, isNull);
      expect(replay.buildSnapshot().hud.hp, direct.buildSnapshot().hud.hp);
      expect(replay.playerPosX, direct.playerPosX);
      expect(replay.playerPosY, direct.playerPosY);
    });

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
        int? firstWeakenTick;
        for (var i = 0; i < hz * 5; i++) {
          direct.applyCommands(const []);
          direct.stepOneTick();
          if (direct.playerPosX < minimumX) minimumX = direct.playerPosX;
          if ((direct.buildSnapshot().playerEntity!.statusVisualMask &
                  EntityStatusVisualMask.weaken) !=
              0) {
            firstWeakenTick ??= direct.tick;
          }
          // Observe the full shove while the locally tuned Weaken is active.
          if (firstWeakenTick != null &&
              direct.tick - firstWeakenTick >= (hz / 2).ceil())
            break;
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
          totalTicks: direct.tick,
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
