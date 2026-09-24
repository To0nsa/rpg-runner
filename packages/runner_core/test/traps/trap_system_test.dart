import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/ecs/systems/npc_combat_lifecycle.dart';
import 'package:runner_core/ecs/hit/capsule_pose_sweep.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/trap_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/lifetime_system.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/systems/projectile_system.dart';
import 'package:runner_core/ecs/systems/trap_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/trap_snapshot.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_geometry.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:test/test.dart';

void main() {
  test('safe NPCs cannot activate traps while active NPCs can', () {
    final f = _Fixture(TrapId.spike);
    final npc = f.actor(200, 128);
    f.world.npc.add(npc, id: NpcId.warrior, chunkStartX: 0, chunkEndX: 600);
    protectNpc(f.world, npc);
    f.step(0);
    expect(f.state.phase, TrapPhase.idle);
    final active = f.actor(200, 128);
    f.world.npc.add(active, id: NpcId.warrior, chunkStartX: 0, chunkEndX: 600);
    f.step(1);
    expect(f.state.phase, TrapPhase.warning);
  });
  for (final id in TrapId.values) {
    for (final windup in [0, 125, 1500]) {
      test('$id uses per-placement damage and $windup ms wind-up', () {
        final f = _Fixture(id, damage100: 123, windupMs: windup);
        final def = TrapCatalog.get(id);
        final firstHit = def.frames[def.firstHarmfulFrame].hitbox;
        f.actor(200, 128);
        if (firstHit != null) f.actor(200 + firstHit.ax, 128 + firstHit.ay);
        final first = (windup * f.hz + 999) ~/ 1000;
        for (var tick = 0; tick < first; tick++) {
          f.step(tick);
          expect(f.world.damageQueue.length, 0);
          expect(f.world.projectile.denseEntities, isEmpty);
        }
        f.step(first);
        expect(f.state.phase, TrapPhase.active);
        if (id == TrapId.poisonDarts) {
          expect(f.world.projectile.damage100.single, 123);
          expect(f.world.projectile.firstHitTick.single, first + 1);
        } else {
          expect(f.world.damageQueue.length, greaterThan(0));
          expect(f.world.damageQueue.amount100, everyElement(123));
        }
        final before = f.world.projectile.denseEntities.length;
        f.step(first + 1);
        if (id == TrapId.poisonDarts) {
          expect(f.world.projectile.denseEntities.length, before);
        }
      });
    }
  }
  for (final id in TrapId.values) {
    for (final hz in [30, 60, 120]) {
      test('$id has a full warning and exact harmful tick at $hz Hz', () {
        final f = _Fixture(id, hz: hz);
        f.actor(200, 128);
        final first = TrapCatalog.get(id).firstHarmfulTick(hz);
        for (var tick = 0; tick < first; tick++) {
          f.step(tick);
          expect(f.state.phase, TrapPhase.warning);
          expect(f.state.frameIndex, TrapCatalog.get(id).frameAtTick(tick, hz));
          expect(f.world.damageQueue.length, 0);
          expect(f.world.projectile.denseEntities, isEmpty);
        }
        f.step(first);
        expect(f.state.phase, TrapPhase.active);
        if (id == TrapId.poisonDarts) {
          expect(
            f.world.projectile.projectileId.single,
            ProjectileId.poisonDart,
          );
          expect(f.world.projectile.firstHitTick.single, first + 1);
        }
      });
    }

    test(
      '$id cancels before harm when resting art or activation bounds leave the camera',
      () {
        for (final cameraRight in [178.0, 148.0]) {
          final f = _Fixture(id);
          f.actor(200, 128);
          f.step(0);
          f.step(1, cameraRight: cameraRight);
          expect(f.state.phase, TrapPhase.cooldown);
          f.step(1000);
          expect(f.state.phase, TrapPhase.waitingForClear);
          expect(f.world.damageQueue.length, 0);
          expect(f.world.projectile.denseEntities, isEmpty);
        }
      },
    );
  }

  test('already occupied trigger starts on first positive camera overlap', () {
    final f = _Fixture(TrapId.spike);
    f.actor(200, 128, faction: Faction.enemy);
    f.step(0, cameraRight: 178); // Resting sprite begins at x=178.
    expect(f.state.phase, TrapPhase.idle);
    f.step(1, cameraRight: 178.01);
    expect(f.state.activationTick, 1);
    expect(f.state.phase, TrapPhase.warning);
  });

  test('dead actors do not activate; living enemies do', () {
    final f = _Fixture(TrapId.spike);
    final actor = f.actor(200, 128, faction: Faction.enemy);
    f.world.health.hp[0] = 0;
    f.step(0);
    expect(f.state.phase, TrapPhase.idle);
    f.world.health.hp[f.world.health.indexOf(actor)] = 1000;
    f.step(1);
    expect(f.state.phase, TrapPhase.warning);
  });

  test('Spike hits both factions once, including a blocked attempt', () {
    final f = _Fixture(TrapId.spike);
    final player = f.actor(200, 120);
    final enemy = f.actor(200, 120, faction: Faction.enemy);
    f.world.invulnerability.add(player);
    f.world.invulnerability.ticksLeft[0] = 10;
    f.step(0);
    f.step(42);
    expect(f.world.damageQueue.target, [player, enemy]);
    expect(f.world.damageQueue.amount100, [500, 500]);
    expect(f.world.damageQueue.sourceEntity, [null, null]);
    expect(f.world.damageQueue.sourceTrap, [f.state.source, f.state.source]);
    DamageSystem(
      invulnerabilityTicksOnHit: 15,
      rngSeed: 1,
    ).step(f.world, currentTick: 42);
    expect(f.world.health.hp, [5000, 4500]);
    f.world.damageQueue.clear();
    f.world.invulnerability.ticksLeft[0] = 0;
    f.step(43);
    expect(f.world.damageQueue.length, 0);
  });

  test('late entrants can be hit during the active phase; visibility loss stops hits', () {
    final f = _Fixture(TrapId.spike);
    final activator = f.actor(170, 128, faction: Faction.enemy);
    f.step(0);
    f.move(activator, 50, 50);
    f.step(42);
    expect(f.world.damageQueue.length, 0);
    final late = f.actor(200, 120);
    f.step(43);
    expect(f.world.damageQueue.target, [late]);
    expect(f.world.traps.buildSnapshots().single.phase, TrapPhase.active);
    f.world.damageQueue.clear();
    f.actor(200, 120);
    f.step(44, cameraRight: 178);
    expect(f.state.phase, TrapPhase.cooldown);
    expect(f.world.damageQueue.length, 0);
  });

  test('cycle, cooldown and an empty trigger are all required to rearm', () {
    final f = _Fixture(TrapId.spike);
    final actor = f.actor(200, 128);
    f.step(0);
    f.step(152);
    expect(f.state.phase, TrapPhase.cooldown);
    f.step(211);
    expect(f.state.phase, TrapPhase.cooldown);
    f.step(212);
    expect(f.state.phase, TrapPhase.waitingForClear);
    f.step(400);
    expect(f.state.activationTick, 0);
    f.move(actor, 0, 0);
    f.step(401);
    expect(f.state.phase, TrapPhase.idle);
    f.move(actor, 200, 128);
    f.step(402);
    expect(f.state.activationTick, 402);
    expect(f.state.phase, TrapPhase.warning);
  });

  test('return to nonharmful Spike art does not hit a new entrant', () {
    final f = _Fixture(TrapId.spike);
    final actor = f.actor(170, 128);
    f.step(0);
    final def = TrapCatalog.get(TrapId.spike);
    f.step(def.frameStartTick(21, 60));
    f.move(actor, 200, 128);
    f.step(def.frameStartTick(22, 60));
    expect(f.world.damageQueue.length, 0);
  });

  test('Axe strikes all blade overlaps, mirrored independently of trigger', () {
    for (final facing in Facing.values) {
      final f = _Fixture(TrapId.swingingAxe, facing: facing);
      f.actor(200, 128);
      final sign = facing == Facing.right ? 1 : -1;
      final player = f.actor(200 + 30.0 * sign, 138);
      final enemy = f.actor(200 + 30.0 * sign, 138, faction: Faction.enemy);
      f.step(0);
      f.step(48);
      expect(f.world.damageQueue.target, [player, enemy]);
      expect(f.world.damageQueue.amount100, [800, 800]);
      expect(f.state.placement.trigger, const TrapRect(-50, -60, 100, 120));
    }
  });

  test('rotating blade envelope covers crossed space and rejects outside', () {
    bool overlaps(double x, double y) => capsulePoseSweepOverlaps(
      previousAx: -20,
      previousAy: 0,
      previousBx: 20,
      previousBy: 0,
      ax: 0,
      ay: -20,
      bx: 0,
      by: 20,
      radius: 1,
      targetAx: x,
      targetAy: y,
      targetBx: x,
      targetBy: y,
      targetRadius: 1,
    );
    expect(overlaps(8, 8), isTrue);
    expect(overlaps(20, 20), isFalse);
  });

  test(
    'dart uses muzzle, shared motion, deferred hit and immutable source',
    () {
      for (final facing in Facing.values) {
        final f = _Fixture(TrapId.poisonDarts, facing: facing);
        f.actor(200, 128);
        final sign = facing == Facing.right ? 1 : -1;
        final victim = f.actor(200 + 22.0 * sign, 126, faction: Faction.enemy);
        f.step(0);
        f.step(30);
        final dart = f.world.projectile.denseEntities.single;
        expect(
          f.world.transform.posX[f.world.transform.indexOf(dart)],
          200 + 22 * sign,
        );
        final hit = ProjectileHitSystem();
        hit.step(f.world, f.grid, currentTick: 30);
        expect(f.world.damageQueue.length, 0);
        final source = f.state.source;
        f.world.traps.synchronize(const [], null); // Launcher culled.
        expect(f.world.projectile.has(dart), isTrue);
        ProjectileSystem().step(
          f.world,
          MovementTuningDerived.from(const MovementTuning(), tickHz: 60),
        );
        expect(
          f.world.transform.posX[f.world.transform.indexOf(dart)],
          closeTo(200 + (22 + 340 / 60) * sign, 1e-10),
        );
        hit.step(f.world, f.grid, currentTick: 31);
        expect(f.world.damageQueue.target, [victim]);
        expect(f.world.damageQueue.amount100, [100]);
        expect(f.world.damageQueue.sourceTrap, [source]);
        expect(f.world.damageQueue.sourceEntity, [null]);
        expect(f.world.projectile.has(dart), isFalse);
      }
    },
  );

  test(
    'launcher waits for its dart to expire even after empty-trigger cooldown',
    () {
      final f = _Fixture(TrapId.poisonDarts);
      final actor = f.actor(200, 128);
      f.step(0);
      f.step(30);
      final dart = f.state.dart!;
      f.move(actor, 0, 0);
      f.step(96);
      f.step(156);
      expect(f.state.phase, TrapPhase.waitingForClear);
      final lifetime = LifetimeSystem();
      for (var tick = 0; tick < 180; tick++) {
        lifetime.step(f.world);
      }
      expect(f.world.projectile.has(dart), isTrue);
      lifetime.step(f.world);
      expect(f.world.projectile.has(dart), isFalse);
      expect(f.state.dart, isNull);
      f.step(211);
      expect(f.state.phase, TrapPhase.idle);
    },
  );

  for (final facing in Facing.values) {
    for (final hz in [30, 60, 120]) {
      test(
        'launcher emerges, fires once and lowers at $hz Hz facing $facing',
        () {
          final f = _Fixture(TrapId.poisonDarts, facing: facing, hz: hz);
          final def = TrapCatalog.get(TrapId.poisonDarts);
          final actor = f.actor(200, 128);
          final framesSeen = <int>{};
          expect(def.frames[f.state.frameIndex].source.y, 48);
          final end = (1600 * hz + 999) ~/ 1000;
          final fire = hz ~/ 2;
          for (var tick = 0; tick < end; tick++) {
            f.step(tick);
            final snapshot = f.world.traps.buildSnapshots().single;
            framesSeen.add(snapshot.frameIndex);
            expect(snapshot.facing, facing);
            expect(snapshot.x, 200);
            expect(snapshot.y, 128);
            if (tick < fire) {
              expect(snapshot.phase, TrapPhase.warning);
              expect(def.frames[snapshot.frameIndex].source.y, 48);
              expect(f.state.dart, isNull);
            } else {
              expect(snapshot.phase, TrapPhase.active);
              expect(f.world.projectile.denseEntities, hasLength(1));
              expect(f.world.projectile.firstHitTick.single, fire + 1);
            }
            expect(f.world.damageQueue.length, 0);
          }
          expect(framesSeen, hasLength(14));
          expect(def.frames[f.state.frameIndex].source.y, 560);
          f.step(end);
          expect(f.state.phase, TrapPhase.cooldown);
          expect(f.state.frameIndex, def.idleFrameIndex);
          f.step(end + hz - 1);
          expect(f.state.phase, TrapPhase.cooldown);
          f.step(end + hz);
          expect(f.state.phase, TrapPhase.waitingForClear);
          f.move(actor, 0, 0);
          f.step(end + hz + 1);
          expect(f.state.phase, TrapPhase.waitingForClear);
          f.world.destroyEntity(f.state.dart!);
          f.step(end + hz + 2);
          expect(f.state.phase, TrapPhase.idle);
          f.move(actor, 200, 128);
          f.step(end + hz + 3);
          expect(f.state.phase, TrapPhase.warning);
          expect(f.state.frameIndex, 0);
          expect(f.state.dart, isNull);
        },
      );
    }
  }

  test('launcher cancels emergence and returns to its lowered idle pose', () {
    for (final tick in [0, 12, 24]) {
      final f = _Fixture(TrapId.poisonDarts);
      f.actor(200, 128);
      f.step(0);
      f.step(tick);
      expect(f.state.frameIndex, tick ~/ 12);
      f.step(tick + 1, cameraRight: 178);
      expect(f.state.phase, TrapPhase.cooldown);
      expect(f.state.frameIndex, 0);
      expect(f.world.projectile.denseEntities, isEmpty);
    }
  });

  test(
    'a tick crossing emergence and firing still creates exactly one dart',
    () {
      final f = _Fixture(TrapId.poisonDarts, hz: 1);
      f.actor(200, 128);
      f.step(0);
      expect(f.state.phase, TrapPhase.warning);
      expect(f.state.dart, isNull);
      f.step(1);
      final dart = f.state.dart;
      expect(dart, isNotNull);
      expect(f.world.projectile.firstHitTick.single, 2);
      f.step(2);
      expect(f.world.projectile.denseEntities, [dart]);
      expect(f.state.phase, TrapPhase.cooldown);
    },
  );

  test('selection refresh retains state; snapshots and culled identities stay stable', () {
    final f = _Fixture(TrapId.spike);
    final catalog = StagedTerrainArtifactCatalog(
      artifact: stagedAuthoredTerrain,
    );
    final chunk = ActiveTrackChunkSnapshot(
      index: 0,
      startX: 0,
      endX: 600,
      patternName: 'field_flat',
      chunkKey: 'field_flat',
      traps: [f.state.placement],
    );
    f.world.traps.states.clear();
    f.world.traps.synchronize([chunk], catalog);
    final state = f.world.traps.states.single;
    f.actor(200, 128);
    f.step(10);
    final snapshot = f.world.traps.buildSnapshots();
    f.world.traps.synchronize([chunk], catalog);
    expect(f.world.traps.states.single, same(state));
    expect(state.activationTick, 10);
    f.step(52);
    expect(snapshot.single.phase, TrapPhase.warning);
    expect(() => snapshot.clear(), throwsUnsupportedError);
    f.world.traps.synchronize(const [], catalog);
    expect(f.world.traps.states, isEmpty);
    expect(snapshot.single.source.chunkKey, 'field_flat');
  });
}

class _Fixture {
  _Fixture(
    TrapId id, {
    this.hz = 60,
    Facing facing = Facing.right,
    int? damage100,
    int? windupMs,
  }) {
    state = TrapState(
      source: TrapSourceRef(
        trapId: id,
        chunkKey: 'field_flat',
        chunkIndex: 0,
        placementOrdinal: 0,
      ),
      originX: 0,
      placement: TrapPlacement(
        trapId: id,
        x: 200,
        y: 128,
        facing: facing,
        damage100: damage100,
        windupMs: windupMs,
        trigger: const TrapRect(-50, -60, 100, 120),
      ),
    );
    world.traps.states.add(state);
    system = TrapSystem(tickHz: hz);
  }
  final int hz;
  final world = EcsWorld();
  final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 32));
  late final TrapState state;
  late final TrapSystem system;
  void step(int tick, {double cameraRight = 600}) {
    grid.rebuild(world);
    system.step(
      world,
      grid,
      currentTick: tick,
      cameraLeft: 0,
      cameraTop: 0,
      cameraRight: cameraRight,
      cameraBottom: 270,
    );
  }

  int actor(double x, double y, {Faction faction = Faction.player}) {
    final id = world.createEntity();
    world.transform.add(id, posX: x, posY: y, velX: 0, velY: 0);
    world.colliderAabb.add(id, const ColliderAabbDef(halfX: 2, halfY: 6));
    world.worldContactCapsule.add(
      id,
      WorldContactCapsuleDef(radius: 2, verticalHalfSegment: 4),
    );
    world.health.add(
      id,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );
    world.faction.add(id, FactionDef(faction: faction));
    return id;
  }

  void move(int id, double x, double y) {
    final index = world.transform.indexOf(id);
    world.transform.posX[index] = x;
    world.transform.posY[index] = y;
  }
}
