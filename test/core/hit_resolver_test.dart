import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/hit/capsule_hit_utils.dart';
import 'package:runner_core/ecs/hit/hit_resolver.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/spatial_grid_tuning.dart';

import 'support/combat_test_support.dart';

void main() {
  test('HitResolver returns capsule overlaps in EntityId order', () {
    final world = EcsWorld();

    final owner = world.createEntity();
    world.transform.add(owner, posX: 0, posY: 0, velX: 0, velY: 0);
    world.faction.add(owner, const FactionDef(faction: Faction.player));

    final first = _addTarget(world, x: 10, faction: Faction.enemy);
    final second = _addTarget(world, x: 10, faction: Faction.enemy);
    _addTarget(world, x: 10, faction: Faction.player);
    attachMissingCombatCapsules(world);

    final broadphase = _broadphase(world);
    final resolver = HitResolver();
    final out = <int>[];
    resolver.collectOrderedOverlapsCapsule(
      broadphase: broadphase,
      ax: 0,
      ay: 0,
      bx: 10,
      by: 0,
      radius: 2,
      owner: owner,
      sourceFaction: Faction.player,
      outTargetIndices: out,
    );

    expect(out.map((ti) => broadphase.targets.entities[ti]).toList(), [
      first,
      second,
    ]);
    final selected = resolver.firstOrderedOverlapCapsule(
      broadphase: broadphase,
      ax: 0,
      ay: 0,
      bx: 10,
      by: 0,
      radius: 2,
      owner: owner,
      sourceFaction: Faction.player,
    );
    expect(selected, isNotNull);
    expect(broadphase.targets.entities[selected!], first);
  });

  test('HitResolver skips lower-ID AABB-corner false positive', () {
    final world = EcsWorld();
    final owner = world.createEntity();
    world.transform.add(owner, posX: 0, posY: 0, velX: 0, velY: 0);
    world.faction.add(owner, const FactionDef(faction: Faction.player));

    final cornerOnly = _addTarget(world, x: 3.9, y: 11.9);
    final realHit = _addTarget(world, x: 0, y: 6);
    attachMissingCombatCapsules(world);
    final broadphase = _broadphase(world);

    final selected = HitResolver().firstOrderedOverlapCapsule(
      broadphase: broadphase,
      ax: 0,
      ay: -4,
      bx: 0,
      by: 4,
      radius: 2,
      owner: owner,
      sourceFaction: Faction.player,
    );

    expect(selected, isNotNull);
    expect(broadphase.targets.entities[selected!], realHit);
    expect(broadphase.targets.entities[selected], isNot(cornerOnly));
  });

  test('HitResolver matches brute-force capsule overlap set (seeded)', () {
    final world = EcsWorld();
    final rng = Random(2);
    final owner = world.createEntity();
    world.transform.add(owner, posX: 0, posY: 0, velX: 0, velY: 0);
    world.faction.add(owner, const FactionDef(faction: Faction.player));

    for (var i = 0; i < 200; i += 1) {
      final halfX = 4.0 + rng.nextDouble() * 12.0;
      _addTarget(
        world,
        x: rng.nextDouble() * 600.0 - 300.0,
        y: rng.nextDouble() * 300.0 - 150.0,
        halfX: halfX,
        halfY: halfX + rng.nextDouble() * 18.0,
        faction: rng.nextBool() ? Faction.enemy : Faction.player,
      );
    }
    attachMissingCombatCapsules(world);
    final broadphase = _broadphase(world);
    final resolver = HitResolver();
    final out = <int>[];

    for (var q = 0; q < 80; q += 1) {
      final ax = rng.nextDouble() * 600.0 - 300.0;
      final ay = rng.nextDouble() * 300.0 - 150.0;
      final bx = ax + rng.nextDouble() * 80.0 - 40.0;
      final by = ay + rng.nextDouble() * 80.0 - 40.0;
      final radius = 1.0 + rng.nextDouble() * 20.0;

      resolver.collectOrderedOverlapsCapsule(
        broadphase: broadphase,
        ax: ax,
        ay: ay,
        bx: bx,
        by: by,
        radius: radius,
        owner: owner,
        sourceFaction: Faction.player,
        outTargetIndices: out,
      );

      final fromResolver = out
          .map((ti) => broadphase.targets.entities[ti])
          .toList();
      final brute = <int>[];
      for (var ti = 0; ti < broadphase.targets.length; ti += 1) {
        if (broadphase.targets.factions[ti] == Faction.player) continue;
        if (capsulesOverlap(
          firstAx: ax,
          firstAy: ay,
          firstBx: bx,
          firstBy: by,
          firstRadius: radius,
          secondAx: broadphase.targets.capsuleAx[ti],
          secondAy: broadphase.targets.capsuleAy[ti],
          secondBx: broadphase.targets.capsuleBx[ti],
          secondBy: broadphase.targets.capsuleBy[ti],
          secondRadius: broadphase.targets.capsuleRadius[ti],
        )) {
          brute.add(broadphase.targets.entities[ti]);
        }
      }
      brute.sort();
      expect(fromResolver, brute, reason: 'q=$q');
    }
  });

  test('broadphase rejects a damageable actor without a capsule', () {
    final world = EcsWorld();
    _addTarget(world, x: 0);

    expect(
      () => _broadphase(world),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('has no WorldContactCapsuleStore entry'),
        ),
      ),
    );
  });

  test('cached capsule and AABB use quantized facing-aware offset', () {
    final world = EcsWorld();
    final target = _addTarget(world, x: 20, halfX: 2, halfY: 6);
    world.movement.add(target, facing: Facing.left, artFacing: Facing.right);
    world.worldContactCapsule.add(
      target,
      WorldContactCapsuleDef(
        radius: 2,
        verticalHalfSegment: 4,
        offsetX: 0.3,
        offsetY: 1,
      ),
    );

    final targets = _broadphase(world).targets;
    expect(targets.centerX.single, closeTo(20 - 307 / 1024, 1e-12));
    expect(targets.centerY.single, 1);
    expect(targets.halfX.single, 2);
    expect(targets.halfY.single, 6);
    expect(targets.capsuleAy.single, -3);
    expect(targets.capsuleBy.single, 5);
  });
}

int _addTarget(
  EcsWorld world, {
  required double x,
  double y = 0,
  double halfX = 2,
  double halfY = 6,
  Faction faction = Faction.enemy,
}) {
  final entity = world.createEntity();
  world.transform.add(entity, posX: x, posY: y, velX: 0, velY: 0);
  world.colliderAabb.add(entity, ColliderAabbDef(halfX: halfX, halfY: halfY));
  world.health.add(
    entity,
    const HealthDef(hp: 100, hpMax: 100, regenPerSecond100: 0),
  );
  world.faction.add(entity, FactionDef(faction: faction));
  return entity;
}

BroadphaseGrid _broadphase(EcsWorld world) => BroadphaseGrid(
  index: GridIndex2D(cellSize: const SpatialGridTuning().broadphaseCellSize),
)..rebuild(world);
