import 'dart:math' as math;

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
import 'package:runner_core/players/characters/eloise.dart';
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
  double playerStartX = 300,
}) => GameCore(
  seed: 7,
  tickHz: hz,
  playerCharacter: PlayerCharacterRegistry.eloise,
  equippedLoadoutOverride: loadout,
  levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
    tuning: LevelRegistry.byId(LevelId.field).tuning.copyWith(
      track: LevelRegistry.byId(LevelId.field).tuning.track
          .copyWith(playerStartX: playerStartX),
    ),
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
    test(
      'Shoggoth breaks five melee actions with a teleport and orb in replay, $hz Hz',
      () {
        final direct = _core(hz, bossId: EnemyId.shoggoth);
        final replay = _core(hz, bossId: EnemyId.shoggoth);
        final frames = <ReplayCommandFrameV1>[];
        AnimKey? previous;
        var meleeActions = 0;
        var retreated = false;
        var cast = false;
        var released = false;
        double? landingX;
        final trace = <String>[];
        for (var n = 0; n < hz * 25 && !direct.gameOver; n++) {
          final before = direct.buildSnapshot();
          final boss = before.entities
              .where((e) => e.enemyId == EnemyId.shoggoth)
              .firstOrNull;
          final dx = boss == null ? 0.0 : boss.pos.x - direct.playerPosX;
          // Bait repeated melee with normal pursuit input, then let the marked
          // retreat and its orb finish. No attacks or health overrides are used.
          final axis = landingX == null && dx.abs() > 40 ? dx.sign : 0.0;
          final tick = direct.tick + 1;
          frames.add(ReplayCommandFrameV1(tick: tick, moveAxis: axis));
          direct.applyCommands([MoveAxisCommand(tick: tick, axis: axis)]);
          direct.stepOneTick();
          final after = direct.buildSnapshot();
          final actor = after.entities
              .where((e) => e.enemyId == EnemyId.shoggoth)
              .firstOrNull;
          if (actor == null) continue;
          if (actor.anim != previous) {
            trace.add(
              '$tick ${actor.anim} at ${actor.pos.x}, HP=${after.hud.hp}',
            );
            if (actor.anim == AnimKey.strike || actor.anim == AnimKey.strike2) {
              meleeActions++;
              expect(
                landingX,
                isNull,
                reason: 'retreat must cast before melee resumes',
              );
            }
            if (actor.anim == AnimKey.teleportOut) {
              expect(meleeActions, 5, reason: trace.join('\n'));
              expect(actor.teleportDestination, isNotNull);
              landingX = actor.teleportDestination!.x;
              expect(
                (landingX - before.playerEntity!.pos.x).abs(),
                closeTo(150, 1),
              );
            }
            if (actor.anim == AnimKey.cast) {
              expect(retreated, isTrue, reason: trace.join('\n'));
              cast = true;
            }
          }
          retreated |= landingX != null && (actor.pos.x - landingX).abs() < 1;
          released = after.entities.any(
            (e) => e.projectileId == ProjectileId.shoggothOrb,
          );
          previous = actor.anim;
          if (released) break;
        }
        expect(meleeActions, 5, reason: trace.join('\n'));
        expect(retreated, isTrue, reason: trace.join('\n'));
        expect(cast && released, isTrue, reason: trace.join('\n'));
        final result = runReplaySimulation(
          core: replay,
          totalTicks: direct.tick,
          commandStream: frames,
        );
        expect(result.runEnded, isNull);
        final a = direct.buildSnapshot(), b = replay.buildSnapshot();
        expect(b.bossArena!.hp100, 30000);
        expect(b.hud.hp, a.hud.hp);
        expect(
          b.entities.map(
            (e) => [
              e.id,
              e.enemyId,
              e.projectileId,
              e.pos.x,
              e.pos.y,
              e.anim,
              e.animFrame,
            ],
          ),
          a.entities.map(
            (e) => [
              e.id,
              e.enemyId,
              e.projectileId,
              e.pos.x,
              e.pos.y,
              e.anim,
              e.animFrame,
            ],
          ),
        );
      },
    );

    for (final bossId in [EnemyId.shoggoth, EnemyId.voidbornGoddess]) {
      test(
        '$bossId flies after a real jump and hovers in recovery in replay, $hz Hz',
        () {
          final direct = _core(hz, bossId: bossId);
          final replay = _core(hz, bossId: bossId);
          final frames = <ReplayCommandFrameV1>[];
          int? comboTick;
          double? floorY;
          double? recoveryY;
          var jumped = false;
          var lift = 0.0;
          var playerLift = 0.0;
          var airborneHit = false;
          final flightTrace = <String>[];
          double? playerFloor;
          final activeEnd =
              (.4 * hz).ceil() +
              ((bossId == EnemyId.shoggoth ? .4 : .9) * hz).ceil();
          for (var n = 0; n < hz * 15 && !direct.gameOver; n++) {
            final before = direct.buildSnapshot();
            final boss = before.entities
                .where((e) => e.enemyId == bossId)
                .firstOrNull;
            final dx = boss == null ? 0.0 : boss.pos.x - direct.playerPosX;
            final axis = comboTick != null
                ? (bossId == EnemyId.shoggoth && dx.abs() < 43 ? -dx.sign : 0.0)
                : dx.abs() > 55
                ? dx.sign
                : 0.0;
            final tick = direct.tick + 1;
            final jump =
                comboTick != null &&
                !jumped &&
                (bossId != EnemyId.shoggoth ||
                    tick - comboTick >= (.2 * hz).ceil());
            if (jump) {
              jumped = true;
              playerFloor = direct.playerPosY;
            }
            frames.add(
              ReplayCommandFrameV1(
                tick: tick,
                moveAxis: axis,
                pressedMask: jump ? ReplayCommandFrameV1.pressedJumpBit : 0,
              ),
            );
            direct.applyCommands([
              MoveAxisCommand(tick: tick, axis: axis),
              if (jump) JumpPressedCommand(tick: tick),
            ]);
            direct.stepOneTick();
            final after = direct.buildSnapshot();
            final actor = after.entities
                .where((e) => e.enemyId == bossId)
                .firstOrNull;
            if (actor == null) continue;
            if (actor.anim == AnimKey.strike && comboTick == null) {
              comboTick = tick;
              floorY = actor.pos.y;
            }
            if (comboTick == null) continue;
            lift = math.max(lift, floorY! - actor.pos.y);
            if (playerFloor != null)
              playerLift = math.max(
                playerLift,
                playerFloor - direct.playerPosY,
              );
            flightTrace.add(
              '$tick age=${tick - comboTick} player=${after.playerEntity!.pos} boss=${actor.pos} hp=${after.hud.hp} anim=${actor.anim} frame=${actor.animFrame}',
            );
            airborneHit |=
                actor.anim == AnimKey.strike &&
                floorY - actor.pos.y > 30 &&
                after.hud.hp < before.hud.hp;
            final age = tick - comboTick;
            if (age >= activeEnd && age < activeEnd + (.3 * hz).ceil()) {
              recoveryY ??= actor.pos.y;
              expect(actor.pos.y, recoveryY);
            }
            if (age >= activeEnd + (.3 * hz).ceil() - 1) break;
          }
          expect(jumped, isTrue);
          expect(playerLift, greaterThan(45));
          expect(lift, greaterThan(30));
          expect(airborneHit, isTrue, reason: flightTrace.join('\n'));
          expect(recoveryY, isNotNull);
          final result = runReplaySimulation(
            core: replay,
            totalTicks: direct.tick,
            commandStream: frames,
          );
          expect(result.runEnded, isNull);
          final a = direct.buildSnapshot(), b = replay.buildSnapshot();
          expect(b.hud.hp, a.hud.hp);
          expect(
            b.entities.map(
              (e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame],
            ),
            a.entities.map(
              (e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame],
            ),
          );
        },
      );
    }
    test('Shoggoth follows during melee strikes and replays at $hz Hz', () {
      final direct = _core(hz, bossId: EnemyId.shoggoth);
      final replay = _core(hz, bossId: EnemyId.shoggoth);
      final frames = <ReplayCommandFrameV1>[];
      int? sweepTick;
      var activeTravel = 0.0;
      var recoveryObserved = false;
      for (var n = 0; n < hz * 12 && !direct.gameOver; n++) {
        final before = direct.buildSnapshot();
        final boss = before.entities
            .where((e) => e.enemyId == EnemyId.shoggoth)
            .firstOrNull;
        final dx = boss == null ? 0.0 : boss.pos.x - direct.playerPosX;
        // Enter melee range, then retreat throughout the committed combo.
        final axis = boss?.anim == AnimKey.strike
            ? -dx.sign
            : (dx.abs() > 55 ? dx.sign : 0.0);
        final tick = direct.tick + 1;
        frames.add(ReplayCommandFrameV1(tick: tick, moveAxis: axis));
        direct.applyCommands([MoveAxisCommand(tick: tick, axis: axis)]);
        direct.stepOneTick();
        final actor = direct
            .buildSnapshot()
            .entities
            .where((e) => e.enemyId == EnemyId.shoggoth)
            .firstOrNull;
        if (actor?.anim == AnimKey.strike && sweepTick == null)
          sweepTick = tick;
        if (sweepTick == null || boss == null || actor == null) continue;
        final age = tick - sweepTick;
        final windup = (.4 * hz).ceil();
        final recovery = windup + (.4 * hz).ceil();
        if (age >= windup && age < recovery) {
          expect(actor.anim, AnimKey.strike);
          final displacement = actor.pos.x - boss.pos.x;
          expect(displacement * dx, lessThanOrEqualTo(0));
          activeTravel += displacement.abs();
        }
        if (age >= recovery && age < recovery + (.3 * hz).ceil()) {
          expect(actor.pos.x, boss.pos.x);
          recoveryObserved = true;
        }
        if (age >= recovery + (.3 * hz).ceil() - 1) break;
      }
      expect(sweepTick, isNotNull);
      expect(activeTravel, greaterThan(10));
      expect(recoveryObserved, isTrue);
      final result = runReplaySimulation(
        core: replay,
        totalTicks: direct.tick,
        commandStream: frames,
      );
      expect(result.runEnded, isNull);
      final a = direct.buildSnapshot(), b = replay.buildSnapshot();
      expect(b.hud.hp, a.hud.hp);
      expect(b.bossArena!.hp100, a.bossArena!.hp100);
      expect(
        b.entities.map((e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame]),
        a.entities.map((e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame]),
      );
    });

    for (final bossId in [EnemyId.shoggoth, EnemyId.voidbornGoddess]) {
      test('$bossId turns during casting and aims at release in replay, $hz Hz', () {
        final direct = _core(
          hz,
          bossId: bossId,
          playerStartX: bossId == EnemyId.shoggoth ? 175 : 300,
        );
        final replay = _core(
          hz,
          bossId: bossId,
          playerStartX: bossId == EnemyId.shoggoth ? 175 : 300,
        );
        final frames = <ReplayCommandFrameV1>[];
        final seenOrbs = <int>{};
        Facing? castFacing;
        var crossingAxis = 0.0;
        var turned = false;
        var verifiedRelease = false;
        var wasCasting = false;
        final trace = <String>[];
        for (var n = 0; n < hz * 40 && !direct.gameOver; n++) {
          final before = direct.buildSnapshot();
          final boss = before.entities
              .where((e) => e.enemyId == bossId)
              .firstOrNull;
          final dx = boss == null ? 0.0 : boss.pos.x - direct.playerPosX;
          final casting = boss?.anim == AnimKey.cast;
          final axis = casting
              ? crossingAxis
              : (bossId == EnemyId.shoggoth
                    ? 0.0
                    : (dx.abs() > 110 ? dx.sign : 0.0));
          final tick = direct.tick + 1;
          // Jump near Shoggoth's hands so his release remains visible instead
          // of immediately colliding with the crossing player's body.
          final jump =
              boss != null &&
              ((!casting && dx.abs() < 180) ||
                  (bossId == EnemyId.shoggoth && casting && dx.abs() < 100));
          final dash = casting && !turned && dx.abs() > 50;
          frames.add(
            ReplayCommandFrameV1(
              tick: tick,
              moveAxis: axis,
              pressedMask:
                  (jump ? ReplayCommandFrameV1.pressedJumpBit : 0) |
                  (dash ? ReplayCommandFrameV1.pressedDashBit : 0),
            ),
          );
          direct.applyCommands([
            MoveAxisCommand(tick: tick, axis: axis),
            if (jump) JumpPressedCommand(tick: tick),
            if (dash) DashPressedCommand(tick: tick),
          ]);
          direct.stepOneTick();
          final after = direct.buildSnapshot();
          final actor = after.entities
              .where((e) => e.enemyId == bossId)
              .firstOrNull;
          if (actor?.anim == AnimKey.cast) {
            if (!wasCasting) {
              castFacing = actor!.facing;
              crossingAxis = (actor.pos.x - direct.playerPosX).sign;
              turned = false;
            }
            turned |= actor!.facing != castFacing;
          }
          for (final orb in after.entities.where(
            (e) =>
                e.projectileId ==
                (bossId == EnemyId.shoggoth
                    ? ProjectileId.shoggothOrb
                    : ProjectileId.goddessOrb),
          )) {
            if (!seenOrbs.add(orb.id)) continue;
            expect(actor, isNotNull);
            if (bossId == EnemyId.shoggoth) {
              expect(
                orb.pos.x,
                closeTo(
                  actor!.pos.x + (actor.facing == Facing.left ? -35 : 35),
                  1e-9,
                ),
              );
              expect(orb.pos.y, closeTo(actor.pos.y + 14, 1e-9));
            } else {
              final target = after.playerEntity!;
              final dx =
                  target.pos.x + eloiseCatalog.colliderOffsetX - actor!.pos.x;
              final dy =
                  target.pos.y + eloiseCatalog.colliderOffsetY - actor.pos.y;
              final length = math.sqrt(dx * dx + dy * dy);
              expect(actor.facing, dx > 0 ? Facing.right : Facing.left);
              expect(orb.pos.x, closeTo(actor.pos.x + 30 * dx / length, 1e-9));
              expect(orb.pos.y, closeTo(actor.pos.y + 30 * dy / length, 1e-9));
            }
            if (turned && actor.anim == AnimKey.cast) verifiedRelease = true;
          }
          wasCasting = actor?.anim == AnimKey.cast;
          if (n % hz == 0)
            trace.add(
              '$tick player=${after.playerEntity?.pos} boss=${actor?.pos} ${actor?.anim}',
            );
          if (verifiedRelease) break;
        }
        expect(verifiedRelease, isTrue, reason: trace.join('\n'));
        final result = runReplaySimulation(
          core: replay,
          totalTicks: direct.tick,
          commandStream: frames,
        );
        expect(result.runEnded, isNull);
        final a = direct.buildSnapshot(), b = replay.buildSnapshot();
        expect(b.hud.hp, a.hud.hp);
        expect(
          b.entities.map(
            (e) => [
              e.id,
              e.pos.x,
              e.pos.y,
              e.facing,
              e.anim,
              e.animFrame,
              e.rotationRad,
            ],
          ),
          a.entities.map(
            (e) => [
              e.id,
              e.pos.x,
              e.pos.y,
              e.facing,
              e.anim,
              e.animFrame,
              e.rotationRad,
            ],
          ),
        );
      });
    }

    for (final bossId in [EnemyId.voidbornGoddess, EnemyId.shoggoth]) {
      test('$bossId spell knockback and dark Weaken replay at $hz Hz', () {
        final direct = _core(hz, bossId: bossId, playerStartX: 175),
            replay = _core(hz, bossId: bossId, playerStartX: 175);
        final frames = <ReplayCommandFrameV1>[];
        int? hitTick;
        double? hitX;
        for (var n = 0; n < 20 * hz && !direct.gameOver; n++) {
          final tick = direct.tick + 1;
          frames.add(ReplayCommandFrameV1(tick: tick));
          direct.applyCommands(const []);
          direct.stepOneTick();
          final player = direct.buildSnapshot().playerEntity!;
          if ((player.statusVisualMask & EntityStatusVisualMask.weaken) != 0 &&
              hitTick == null) {
            hitTick = tick;
            hitX = player.pos.x;
          }
          if (hitTick != null && tick >= hitTick + (.3 * hz).ceil()) break;
        }
        expect(
          hitTick,
          isNotNull,
          reason: 'A real boss spell must apply the dark status.',
        );
        expect(
          (direct.playerPosX - hitX!).abs(),
          greaterThan(5),
          reason:
              'The accepted spell must move the player through Core terrain.',
        );
        final result = runReplaySimulation(
          core: replay,
          totalTicks: direct.tick,
          commandStream: frames,
        );
        expect(result.runEnded, isNull);
        final a = direct.buildSnapshot(), b = replay.buildSnapshot();
        expect(b.hud.hp, a.hud.hp);
        expect(
          b.entities.map(
            (e) => [
              e.id,
              e.pos.x,
              e.pos.y,
              e.anim,
              e.animFrame,
              e.statusVisualMask,
            ],
          ),
          a.entities.map(
            (e) => [
              e.id,
              e.pos.x,
              e.pos.y,
              e.anim,
              e.animFrame,
              e.statusVisualMask,
            ],
          ),
        );
      });
    }

    test('Shoggoth swarms and final-phase return charge replay at $hz Hz', () {
      final direct = _core(hz, bossId: EnemyId.shoggoth);
      final replay = _core(hz, bossId: EnemyId.shoggoth);
      final frames = <ReplayCommandFrameV1>[];
      final summons = <int>{};
      final chargeTicks = <int>[];
      var summonCasts = 0;
      var finalPhase = false;
      var returned = false;
      var supportedMinions = false;
      final trace = <String>[];
      EntityRenderSnapshot? previousBoss;
      for (var n = 0; n < hz * 60 && !direct.gameOver; n++) {
        final before = direct.buildSnapshot();
        final boss = before.entities
            .where((e) => e.enemyId == EnemyId.shoggoth)
            .firstOrNull;
        final dx = boss == null ? 0.0 : boss.pos.x - direct.playerPosX;
        finalPhase |=
            before.bossArena != null && before.bossArena!.hp100 <= 10500;
        // Earn all three waves using ordinary attacks, then bait a charge by making
        // space. Jump over the committed first pass and let its counter finish.
        final escape = direct.playerPosX < 90
            ? 1.0
            : direct.playerPosX > 510
            ? -1.0
            : -dx.sign;
        final minionsAlive = before.entities.any(
          (e) => e.enemyId == EnemyId.shoggothMinion && e.anim != AnimKey.death,
        );
        final baitAxis = direct.playerPosX < 150
            ? 1.0
            : direct.playerPosX > 450
            ? -1.0
            : dx.abs() < 120
            ? -dx.sign
            : 0.0;
        final axis = finalPhase
            ? (boss?.anim == AnimKey.strike2
                  ? 0.0
                  : !minionsAlive
                  ? baitAxis
                  : dx.abs() < 160
                  ? escape
                  : 0.0)
            : (dx.abs() > 20 ? dx.sign : 0.0);
        final tick = direct.tick + 1;
        final strike = !finalPhase && n % (hz / 3).round() == 0;
        final shot = !finalPhase && n % (hz * .75).round() == 0;
        final jump =
            finalPhase &&
            boss?.anim == AnimKey.strike2 &&
            chargeTicks.isNotEmpty &&
            // A late-warning jump clears both halves, including the finisher.
            tick == chargeTicks.last + (.35 * hz).ceil();
        final dash =
            finalPhase &&
            minionsAlive &&
            dx.abs() < 140 &&
            boss?.anim != AnimKey.strike2;
        frames.add(
          ReplayCommandFrameV1(
            tick: tick,
            moveAxis: axis,
            aimDirX: dx >= 0 ? 1 : -1,
            aimDirY: 0,
            pressedMask:
                (strike ? ReplayCommandFrameV1.pressedStrikeBit : 0) |
                (shot ? ReplayCommandFrameV1.pressedProjectileBit : 0) |
                (jump ? ReplayCommandFrameV1.pressedJumpBit : 0) |
                (dash ? ReplayCommandFrameV1.pressedDashBit : 0),
          ),
        );
        direct.applyCommands([
          MoveAxisCommand(tick: tick, axis: axis),
          AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
          if (strike) StrikePressedCommand(tick: tick),
          if (shot) ProjectilePressedCommand(tick: tick),
          if (jump) JumpPressedCommand(tick: tick),
          if (dash) DashPressedCommand(tick: tick),
        ]);
        direct.stepOneTick();
        final after = direct.buildSnapshot();
        for (final e in after.entities.where(
          (e) => e.enemyId == EnemyId.shoggothMinion,
        )) {
          summons.add(e.id);
        }
        final actor = after.entities
            .where((e) => e.enemyId == EnemyId.shoggoth)
            .firstOrNull;
        supportedMinions |=
            actor?.anim == AnimKey.cast &&
            after.entities.any(
              (e) =>
                  e.enemyId == EnemyId.shoggothMinion &&
                  e.anim != AnimKey.death,
            );
        if (actor?.anim == AnimKey.ranged &&
            previousBoss?.anim != AnimKey.ranged)
          summonCasts++;
        if (actor?.anim == AnimKey.strike2 &&
            (previousBoss?.anim != AnimKey.strike2 ||
                actor!.animFrame! < previousBoss!.animFrame!)) {
          if (chargeTicks.isNotEmpty &&
              tick - chargeTicks.last <= (90 * hz / 60).ceil()) {
            returned = true;
          }
          chargeTicks.add(tick);
        }
        if (chargeTicks.isNotEmpty &&
            chargeTicks.length < 3 &&
            n % (hz / 5).round() == 0)
          trace.add(
            "$tick HP=${after.bossArena?.hp100} player=${after.playerEntity!.pos} boss=${actor?.pos} ${actor?.anim}",
          );
        previousBoss = actor;
        if (returned && tick - chargeTicks.last > 2 * hz) break;
      }
      expect(summonCasts, 3);
      expect(summons, isNotEmpty);
      expect(supportedMinions, isTrue);
      expect(
        returned,
        isTrue,
        reason:
            'HP=${direct.buildSnapshot().hud.hp}, charges=$chargeTicks\n${trace.join("\n")}',
      );
      final result = runReplaySimulation(
        core: replay,
        totalTicks: direct.tick,
        commandStream: frames,
      );
      expect(result.runEnded, isNull);
      final a = direct.buildSnapshot(), b = replay.buildSnapshot();
      expect(a.bossArena!.hpMax100, 30000);
      expect(b.bossArena!.hp100, a.bossArena!.hp100);
      expect(b.hud.hp, a.hud.hp);
      expect(
        b.entities.map(
          (e) => [e.id, e.enemyId, e.pos.x, e.pos.y, e.anim, e.animFrame],
        ),
        a.entities.map(
          (e) => [e.id, e.enemyId, e.pos.x, e.pos.y, e.anim, e.animFrame],
        ),
      );
    });

    test('Goddess counters two landed projectiles and replays at $hz Hz', () {
      const loadout = EquippedLoadoutDef(
        projectileSlotSpellId: ProjectileId.holyBolt,
      );
      final direct = _core(
        hz,
        bossId: EnemyId.voidbornGoddess,
        loadout: loadout,
      );
      final replay = _core(
        hz,
        bossId: EnemyId.voidbornGoddess,
        loadout: loadout,
      );
      final frames = <ReplayCommandFrameV1>[];
      var landed = 0;
      int? secondHitTick;
      var vanished = false;
      var countered = false;
      for (var n = 0; n < hz * 15 && !direct.gameOver; n++) {
        final before = direct.buildSnapshot();
        final boss = before.entities
            .where((e) => e.enemyId == EnemyId.voidbornGoddess)
            .firstOrNull;
        final dx = boss == null ? 0.0 : boss.pos.x - direct.playerPosX;
        final axis = dx.abs() > 200 ? dx.sign : 0.0;
        final tick = direct.tick + 1;
        final shot = landed < 2 && n % ((hz * .75).round()) == 0;
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
        if (arena != null &&
            before.bossArena != null &&
            arena.hp100 < before.bossArena!.hp100) {
          landed++;
          if (landed == 2) secondHitTick = tick;
        }
        if (secondHitTick == null) continue;
        final actor = after.entities.singleWhere(
          (e) => e.enemyId == EnemyId.voidbornGoddess,
        );
        vanished |= actor.anim == AnimKey.teleportOut;
        if (vanished && actor.anim == AnimKey.strike) {
          expect(
            tick - secondHitTick,
            lessThanOrEqualTo((8 * hz / 60).ceil() + 1),
          );
          // The dodge commits before this tick's player knockback movement.
          expect(
            (actor.pos.x - before.playerEntity!.pos.x).abs(),
            closeTo(35, 1),
          );
          countered = true;
          break;
        }
      }
      expect(landed, 2);
      expect(countered, isTrue);
      final result = runReplaySimulation(
        core: replay,
        totalTicks: direct.tick,
        commandStream: frames,
      );
      expect(result.runEnded, isNull);
      final a = direct.buildSnapshot(), b = replay.buildSnapshot();
      expect(a.bossArena!.hpMax100, 30000);
      expect(b.bossArena!.hp100, a.bossArena!.hp100);
      expect(b.hud.hp, a.hud.hp);
      expect(
        b.entities.map((e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame]),
        a.entities.map((e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame]),
      );
    });

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
