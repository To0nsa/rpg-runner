import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/ecs/stores/enemies/enemy_store.dart';
import 'package:runner_core/bosses/boss_arena_system.dart';
import 'package:runner_core/camera/autoscroll_camera.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/systems/control_lock_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/authored_chunk_patterns.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/score_tuning.dart';
import 'package:test/test.dart';

BossArenaDefinition _definition() => BossArenaDefinition(
  id: 'test_bringer',
  enemyId: EnemyId.bringerOfDeath,
  spawnX: 440,
  minX: 24,
  maxX: 576,
);

void main() {
  test('entrance clears charge progress while preserving held input', () {
    final f = _Fixture();
    f.world.abilityCharge.add(f.player);
    final charge = f.world.abilityCharge;
    final i = charge.indexOf(f.player);
    final slot = AbilitySlot.projectile;
    final offset = charge.slotOffsetForDenseIndex(i, slot);
    charge.heldMask[i] = 1 << slot.index;
    charge.currentHoldTicksBySlot[offset] = 180;
    charge.releasedHoldTicksBySlot[offset] = 180;
    charge.releasedTickBySlot[offset] = 1;
    f.enter();
    expect(charge.slotHeld(f.player, slot), isTrue);
    expect(charge.currentHoldTicks(f.player, slot), 0);
    expect(charge.releasedTickBySlot[offset], -1);
  });

  test(
    'outside actors are isolated and recycled IDs retain unrelated protection',
    () {
      final f = _Fixture();
      final ambient = f.world.createEntity();
      f.world.enemy.add(ambient, const EnemyDef(enemyId: EnemyId.grojib));
      f.enter();
      expect(f.world.arenaSuspension.has(ambient), isTrue);
      expect(f.world.arenaProtection.has(ambient), isTrue);
      f.world.destroyEntity(ambient);
      expect(f.world.createEntity(), ambient);
      f.world.invulnerability.add(ambient);
      f.system.endRun(f.world, f.player);
      expect(f.world.arenaSuspension.has(ambient), isFalse);
      expect(f.world.arenaProtection.has(ambient), isFalse);
      expect(f.world.invulnerability.has(ambient), isTrue);
    },
  );

  test('hold starts only when the entire arena is framed', () {
    final f = _Fixture();
    f.system.afterCamera(
      f.world,
      player: f.player,
      camera: _camera(299),
      tick: 1,
    );
    expect(f.system.snapshot(f.world), isNull);
    expect(f.world.actorMotionBounds.has(f.player), isFalse);
    f.system.afterCamera(
      f.world,
      player: f.player,
      camera: _camera(300),
      tick: 2,
    );
    expect(f.system.snapshot(f.world)!.phase, BossArenaPhase.introduction);
    expect(
      f.world.actorMotionBounds.frozen[f.world.actorMotionBounds.indexOf(
        f.player,
      )],
      isTrue,
    );
    expect(f.spawns, 0);
  });

  test('entrance has one spawn and releases on its quantized catalog tick', () {
    final f = _Fixture()..enter();
    f.prepare(2);
    expect(f.spawns, 1);
    expect(
      f.world.spawnState.animTicks[f.world.spawnState.indexOf(f.boss!)],
      70,
    );
    for (var tick = 3; tick < 72; tick++) {
      f.prepare(tick);
      expect(f.system.snapshot(f.world)!.playerHeld, isTrue);
    }
    f.prepare(72);
    expect(f.system.snapshot(f.world)!.phase, BossArenaPhase.combat);
    expect(f.world.invulnerability.has(f.boss!), isFalse);
    expect(
      f.world.actorMotionBounds.frozen[f.world.actorMotionBounds.indexOf(
        f.player,
      )],
      isFalse,
    );
    expect(f.spawns, 1);
  });

  test(
    'combat defeat waits for corpse cleanup, releases once, never respawns',
    () {
      final f = _Fixture()..enter();
      f.prepare(2);
      f.prepare(74);
      f.world.health.hp[f.world.health.indexOf(f.boss!)] = 0;
      f.system.resolve(f.world, playerDead: false);
      expect(f.system.snapshot(f.world)!.phase, BossArenaPhase.defeated);
      f.prepare(75);
      expect(f.system.cameraStopX, 300);
      f.world.destroyEntity(f.boss!);
      f.prepare(76);
      expect(f.system.cameraStopX, isNull);
      expect(f.world.actorMotionBounds.has(f.player), isFalse);
      f.system.synchronize([f.chunk], 600);
      f.prepare(77);
      expect(f.spawns, 1);
    },
  );

  test('missing boss and simultaneous player death cannot resolve victory', () {
    final lost = _Fixture()..enter();
    lost.prepare(2);
    lost.prepare(74);
    lost.world.destroyEntity(lost.boss!);
    lost.system.resolve(lost.world, playerDead: false);
    expect(lost.system.failed, isTrue);
    final simultaneous = _Fixture()..enter();
    simultaneous.prepare(2);
    simultaneous.prepare(74);
    simultaneous.world.health.hp[simultaneous.world.health.indexOf(
          simultaneous.boss!,
        )] =
        0;
    simultaneous.system.resolve(simultaneous.world, playerDead: true);
    expect(simultaneous.system.failed, isTrue);
  });

  test('recycled entity IDs cannot keep a defeated arena locked', () {
    final f = _Fixture()..enter();
    f.prepare(2);
    f.prepare(74);
    f.world.health.hp[f.world.health.indexOf(f.boss!)] = 0;
    f.system.resolve(f.world, playerDead: false);
    f.world.destroyEntity(f.boss!);
    expect(f.world.createEntity(), f.boss);
    f.prepare(75);
    expect(f.system.cameraStopX, isNull);
  });

  test(
    'entrance, fight and corpse time exclude survival points; bonus is fixed',
    () {
      final counts = List.filled(EnemyId.values.length, 0)
        ..[EnemyId.bringerOfDeath.index] = 1;
      final score = buildRunScoreBreakdown(
        tick: 1200,
        excludedScoreTicks: 600,
        distanceUnits: 0,
        collectibles: 0,
        collectibleScore: 0,
        enemyKillCounts: counts,
        tuning: const ScoreTuning(),
        tickHz: 60,
      );
      expect(
        score.rows.singleWhere((r) => r.kind == RunScoreRowKind.time).points,
        50,
      );
      expect(
        score.rows
            .singleWhere((r) => r.kind == RunScoreRowKind.enemyKill)
            .points,
        1000,
      );
      expect(score.totalPoints, 1050);
    },
  );

  for (final character in [
    PlayerCharacterRegistry.eloise,
    PlayerCharacterRegistry.eloiseWip,
  ]) {
    test(
      '${character.id.name} scythe damage uses shared shove against movement input',
      () {
        final core = _core(character: character);
        while (core.buildSnapshot().bossArena?.phase != BossArenaPhase.combat &&
            core.tick < 300) {
          _step(core);
        }
        final boss = core.buildSnapshot().entities.singleWhere(
          (e) => e.enemyId == EnemyId.bringerOfDeath,
        );
        core.setPlayerPosXYUnsafeForTest(boss.pos.x - 60, core.playerPosY);
        core.setPlayerVelXY(0, 0);
        final initialHp = core.buildSnapshot().hud.hp;
        var damaged = false;
        for (var i = 0; i < 360 && !core.gameOver; i++) {
          _step(core);
          if (core.buildSnapshot().hud.hp < initialHp) {
            expect(
              core
                  .buildSnapshot()
                  .entities
                  .singleWhere((e) => e.enemyId == EnemyId.bringerOfDeath)
                  .anim,
              AnimKey.strike,
            );
            damaged = true;
            break;
          }
        }
        expect(damaged, isTrue);
        final hitX = core.playerPosX;
        for (var i = 0; i < 17; i++) {
          _step(core, axis: 1);
        }
        expect(hitX - core.playerPosX, closeTo(112, .1));
      },
    );
    for (final hz in [30, 60, 90]) {
      test(
        '${character.id.name} $hz Hz holds through entrance then permits bounded combat',
        () {
          final core = _core(character: character, hz: hz);
          final introductionTicks = 10 * (.12 * hz).round();
          _step(core, axis: 1, attack: true, jump: true, dash: true);
          final held = core.buildSnapshot().playerEntity!.pos;
          expect(core.buildSnapshot().bossArena!.playerHeld, isTrue);
          for (var n = 0; n < introductionTicks; n++) {
            _step(core, axis: 1, attack: true, jump: true, dash: true);
            final snapshot = core.buildSnapshot();
            expect(snapshot.camera.centerX, 300);
            expect(snapshot.playerEntity!.pos.x, held.x);
            expect(snapshot.playerEntity!.pos.y, held.y);
            expect(snapshot.bossArena!.hp100, 12000);
            expect(snapshot.playerEntity!.anim, isNot(AnimKey.strike));
          }
          _step(core, axis: 1);
          expect(core.buildSnapshot().bossArena!.phase, BossArenaPhase.combat);
          for (var n = 0; n < hz * 2 && !core.gameOver; n++) {
            _step(
              core,
              axis: n < hz ? 1 : -1,
              dash: n % 20 == 0,
              jump: n % 30 == 0,
            );
            final s = core.buildSnapshot();
            expect(s.camera.centerX, 300);
            expect(s.playerEntity!.pos.x, inInclusiveRange(24, 576));
            final boss = s.entities.singleWhere(
              (e) => e.enemyId == EnemyId.bringerOfDeath,
            );
            expect(boss.pos.x, inInclusiveRange(24, 576));
          }
        },
      );
    }
  }

  test(
    'same commands replay the entrance and both attack selections identically',
    () {
      final a = _core(), b = _core();
      final attackKeys = <AnimKey>{};
      for (var n = 0; n < 600 && !a.gameOver; n++) {
        final axis = n < 170
            ? 0.0
            : n < 205
            ? 1.0
            : 0.0;
        for (final core in [a, b]) {
          _step(core, axis: axis);
        }
        final sa = a.buildSnapshot(), sb = b.buildSnapshot();
        expect(sb.bossArena?.phase, sa.bossArena?.phase);
        expect(sb.bossArena?.hp100, sa.bossArena?.hp100);
        expect(sb.playerEntity!.pos.x, sa.playerEntity!.pos.x);
        expect(sb.hud.hp, sa.hud.hp);
        expect(sb.camera.centerX, sa.camera.centerX);
        for (final e in sa.entities.where(
          (e) => e.enemyId == EnemyId.bringerOfDeath,
        )) {
          attackKeys.add(e.anim);
          final other = sb.entities.singleWhere((o) => o.id == e.id);
          expect(other.anim, e.anim);
          expect(other.animFrame, e.animFrame);
        }
      }
      expect(
        attackKeys,
        containsAll([AnimKey.spawn, AnimKey.cast, AnimKey.strike]),
      );
      a.giveUp();
      final end = a.drainEvents().whereType<RunEndedEvent>().single;
      expect(end.stats.excludedScoreTicks, greaterThan(0));
      expect(end.stats.enemyKillCounts[EnemyId.bringerOfDeath.index], 0);
    },
  );

  test(
    'real Forest arena stops at its full viewport after the preceding chunk',
    () {
      final boss = forestEasyPatterns.singleWhere(
        (p) => p.chunkKey == 'forest_boss_easy_001',
      );
      final first = forestEarlyPatterns.firstWhere(
        (p) => p.chunkKey == 'forest_default_early_001',
      );
      final core = GameCore(
        seed: 7,
        playerCharacter: PlayerCharacterRegistry.eloise,
        levelDefinition: LevelRegistry.byId(LevelId.forest).copyWith(
          earlyPatternChunks: 1,
          easyPatternChunks: 10,
          noEnemyChunks: 1,
          clearAssembly: true,
          chunkPatternSource: ChunkPatternListSource(
            earlyPatterns: [first],
            easyPatterns: [boss],
            normalPatterns: const [],
          ),
        ),
      );
      var reached = false;
      for (var n = 0; n < 1000 && !core.gameOver; n++) {
        _step(core, axis: 1);
        final s = core.buildSnapshot();
        if (s.bossArena?.playerHeld == true) {
          expect(s.camera.centerX, 900);
          expect(s.camera.centerX - s.camera.viewWidth / 2, 600);
          expect(s.camera.centerX + s.camera.viewWidth / 2, 1200);
          reached = true;
          break;
        }
        expect(s.camera.centerX, lessThanOrEqualTo(900));
      }
      expect(reached, isTrue);
    },
  );

  for (final character in [
    PlayerCharacterRegistry.eloise,
    PlayerCharacterRegistry.eloiseWip,
  ]) {
    for (final hz in [30, 60, 90]) {
      for (final platformX in [175.0, 215.0, 255.0]) {
        test(
          '${character.id.name} pillar expels platform camper x=$platformX at $hz Hz while boss stays grounded',
          () {
            final core = _platformCore(character: character, hz: hz);
            while (core.buildSnapshot().bossArena?.phase !=
                    BossArenaPhase.combat &&
                core.tick < hz * 5) {
              _step(core);
            }
            expect(
              core.buildSnapshot().bossArena?.phase,
              BossArenaPhase.combat,
            );
            final bossY = core
                .buildSnapshot()
                .entities
                .singleWhere((e) => e.enemyId == EnemyId.bringerOfDeath)
                .pos
                .y;
            // The authored platform top is 133; the arena floor is 224.
            core.setPlayerPosXYUnsafeForTest(platformX, core.playerPosY - 91);
            core.setPlayerVelXY(0, 0);
            _step(core);
            expect(core.playerGrounded, isTrue);
            final initialX = core.playerPosX;
            final initialY = core.playerPosY;
            final initialHp = core.buildSnapshot().hud.hp;
            var damaged = false;
            for (var i = 0; i < hz * 8 && !core.gameOver; i++) {
              _step(core);
              final boss = core.buildSnapshot().entities.singleWhere(
                (e) => e.enemyId == EnemyId.bringerOfDeath,
              );
              expect(boss.pos.y, closeTo(bossY, .002));
              if (core.buildSnapshot().hud.hp < initialHp) {
                damaged = true;
                break;
              }
            }
            expect(
              damaged,
              isTrue,
              reason: 'Pillar must actually hit the platform.',
            );
            _step(core);
            final direction = (core.playerPosX - initialX).sign;
            final trace = <String>[];
            expect(direction, isNot(0));
            for (var i = 0; i < (hz * .28).ceil() - 1; i++) {
              _step(core, axis: -direction);
              final debug = core.buildTerrainPlayerDebugSnapshot()!;
              trace.add(
                '${core.tick} x=${core.playerPosX} y=${core.playerPosY} req=${debug.requestedXTicks} res=${debug.resolvedXTicks} diag=${debug.diagnostic} contacts=${debug.blockingContacts.map((c) => c.edgeId.canonicalKey)}',
              );
            }
            expect(
              (core.playerPosX - initialX).abs(),
              closeTo(112, .1),
              reason: trace.join('\n'),
            );
            expect(
              (core.playerPosX - initialX).abs(),
              greaterThanOrEqualTo(48),
            );
            expect(core.playerPosY, greaterThan(initialY + 1));
            expect(core.gameOver, isFalse);
          },
        );
      }
    }
    test(
      '${character.id.name} defeats the boss through real combat and resumes scrolling',
      () {
        final core = _core(character: character);
        var defeated = false, released = false;
        for (var n = 0; n < 6000 && !core.gameOver; n++) {
          final s = core.buildSnapshot();
          final boss = s.entities
              .where((e) => e.enemyId == EnemyId.bringerOfDeath)
              .firstOrNull;
          final dx = boss == null ? 0.0 : boss.pos.x - s.playerEntity!.pos.x;
          final t = core.tick + 1;
          core.applyCommands([
            MoveAxisCommand(tick: t, axis: dx.abs() > 20 ? dx.sign : 0),
            AimDirCommand(tick: t, x: dx >= 0 ? 1 : -1, y: 0),
            if (n % 20 == 0) StrikePressedCommand(tick: t),
            if (n % 45 == 0) ProjectilePressedCommand(tick: t),
          ]);
          core.stepOneTick();
          final after = core.buildSnapshot();
          defeated |= after.bossArena?.phase == BossArenaPhase.defeated;
          if (defeated && after.bossArena == null) {
            for (var k = 0; k < 10; k++) {
              _step(core, axis: 1);
            }
            expect(core.buildSnapshot().camera.centerX, greaterThan(300));
            released = true;
            break;
          }
        }
        expect(
          defeated,
          isTrue,
          reason: 'HP=${core.buildSnapshot().hud.hp}, tick=${core.tick}',
        );
        expect(released, isTrue);
        core.giveUp();
        final end = core.drainEvents().whereType<RunEndedEvent>().single;
        expect(end.stats.enemyKillCounts[EnemyId.bringerOfDeath.index], 1);
      },
    );
  }
}

CameraState _camera(double x) =>
    CameraState(centerX: x, targetX: x, centerY: 135, targetY: 135, speedX: 0);

GameCore _platformCore({
  required PlayerCharacterDefinition character,
  required int hz,
}) => GameCore(
  seed: 7,
  tickHz: hz,
  playerCharacter: character,
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

GameCore _core({PlayerCharacterDefinition? character, int hz = 60}) => GameCore(
  seed: 7,
  tickHz: hz,
  playerCharacter: character ?? PlayerCharacterRegistry.eloise,
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
          bossArena: _definition(),
        ),
      ],
    ),
  ),
);
void _step(
  GameCore core, {
  double axis = 0,
  bool attack = false,
  bool jump = false,
  bool dash = false,
}) {
  final tick = core.tick + 1;
  core.applyCommands([
    MoveAxisCommand(tick: tick, axis: axis),
    if (attack) StrikePressedCommand(tick: tick),
    if (jump) JumpPressedCommand(tick: tick),
    if (dash) DashPressedCommand(tick: tick),
  ]);
  core.stepOneTick();
}

class _Fixture {
  _Fixture() {
    player = world.createEntity();
    world.transform.add(player, posX: 300, posY: 198, velX: 0, velY: 0);
    world.colliderAabb.add(player, const ColliderAabbDef(halfX: 8, halfY: 24));
    world.health.add(
      player,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.controlLock.addEntity(player);
    chunk = ActiveTrackChunkSnapshot(
      index: 0,
      startX: 0,
      endX: 600,
      patternName: 'arena',
      chunkKey: 'arena',
      bossArena: _definition(),
    );
    system.synchronize([chunk], 600);
  }
  final world = EcsWorld();
  final system = BossArenaSystem(tickHz: 60);
  late final int player;
  late final ActiveTrackChunkSnapshot chunk;
  int? boss;
  int spawns = 0;
  void enter() =>
      system.afterCamera(world, player: player, camera: _camera(300), tick: 1);
  void prepare(int tick) {
    system.prepare(
      world,
      player: player,
      tick: tick,
      spawn: (chunk, tick) {
        spawns++;
        final a = const EnemyCatalog().get(EnemyId.bringerOfDeath);
        return boss = EntityFactory(world).createEnemy(
          enemyId: EnemyId.bringerOfDeath,
          posX: 440,
          posY: 198,
          velX: 0,
          velY: 0,
          facing: Facing.left,
          body: a.body,
          collider: a.collider,
          health: a.health,
          mana: a.mana,
          stamina: a.stamina,
        );
      },
    );
    ControlLockSystem().step(world, currentTick: tick);
    system.control(world, player: player, tick: tick);
  }
}
