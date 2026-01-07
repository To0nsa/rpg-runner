import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/combat/faction.dart';
import 'package:walkscape_runner/core/ecs/hit/hit_resolver.dart';
import 'package:walkscape_runner/core/ecs/spatial/broadphase_grid.dart';
import 'package:walkscape_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/faction_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/tuning/spatial_grid_tuning.dart';

void main() {
  test('HitResolver returns overlaps in EntityId order', () {
    final world = EcsWorld();

    final owner = world.createEntity();
    world.transform.add(owner, posX: 0, posY: 0, velX: 0, velY: 0);
    world.faction.add(owner, const FactionDef(faction: Faction.player));

    // Create targets in a scrambled creation order so dense ordering is irrelevant.
    final b = world.createEntity(); // id 2
    world.transform.add(b, posX: 10, posY: 0, velX: 0, velY: 0);
    world.colliderAabb.add(b, const ColliderAabbDef(halfX: 10, halfY: 10));
    world.health.add(b, const HealthDef(hp: 1, hpMax: 1, regenPerSecond: 0));
    world.faction.add(b, const FactionDef(faction: Faction.enemy));

    final a = world.createEntity(); // id 3
    world.transform.add(a, posX: 10, posY: 0, velX: 0, velY: 0);
    world.colliderAabb.add(a, const ColliderAabbDef(halfX: 10, halfY: 10));
    world.health.add(a, const HealthDef(hp: 1, hpMax: 1, regenPerSecond: 0));
    world.faction.add(a, const FactionDef(faction: Faction.enemy));

    final c = world.createEntity(); // id 4 friendly
    world.transform.add(c, posX: 10, posY: 0, velX: 0, velY: 0);
    world.colliderAabb.add(c, const ColliderAabbDef(halfX: 10, halfY: 10));
    world.health.add(c, const HealthDef(hp: 1, hpMax: 1, regenPerSecond: 0));
    world.faction.add(c, const FactionDef(faction: Faction.player));

    final broadphase = BroadphaseGrid(
      index: GridIndex2D(cellSize: const SpatialGridTuning().broadphaseCellSize),
    )..rebuild(world);

    final resolver = HitResolver();
    final out = <int>[];
    resolver.collectOrderedOverlapsCenters(
      broadphase: broadphase,
      centerX: 10,
      centerY: 0,
      halfX: 10,
      halfY: 10,
      owner: owner,
      sourceFaction: Faction.player,
      outTargetIndices: out,
    );

    // Friendly target is filtered, owner is excluded, remaining targets are ordered by EntityId.
    expect(out.map((ti) => broadphase.targets.entities[ti]).toList(), [b, a]);

    final first = resolver.firstOrderedOverlapCenters(
      broadphase: broadphase,
      centerX: 10,
      centerY: 0,
      halfX: 10,
      halfY: 10,
      owner: owner,
      sourceFaction: Faction.player,
    );
    expect(first, isNotNull);
    expect(broadphase.targets.entities[first!], b);
  });

  test('HitResolver matches brute-force overlap set (seeded)', () {
    final world = EcsWorld();
    final rng = Random(2);

    final owner = world.createEntity();
    world.transform.add(owner, posX: 0, posY: 0, velX: 0, velY: 0);
    world.faction.add(owner, const FactionDef(faction: Faction.player));

    for (var i = 0; i < 200; i += 1) {
      final e = world.createEntity();
      world.transform.add(
        e,
        posX: rng.nextDouble() * 600.0 - 300.0,
        posY: rng.nextDouble() * 300.0 - 150.0,
        velX: 0.0,
        velY: 0.0,
      );
      world.colliderAabb.add(
        e,
        ColliderAabbDef(
          halfX: 4.0 + rng.nextDouble() * 24.0,
          halfY: 4.0 + rng.nextDouble() * 24.0,
        ),
      );
      world.health.add(e, const HealthDef(hp: 1, hpMax: 1, regenPerSecond: 0));
      world.faction.add(
        e,
        FactionDef(faction: rng.nextBool() ? Faction.enemy : Faction.player),
      );
    }

    final broadphase = BroadphaseGrid(
      index: GridIndex2D(cellSize: const SpatialGridTuning().broadphaseCellSize),
    )..rebuild(world);

    final resolver = HitResolver();
    final out = <int>[];

    for (var q = 0; q < 80; q += 1) {
      final centerX = rng.nextDouble() * 600.0 - 300.0;
      final centerY = rng.nextDouble() * 300.0 - 150.0;
      final halfX = 5.0 + rng.nextDouble() * 60.0;
      final halfY = 5.0 + rng.nextDouble() * 60.0;

      resolver.collectOrderedOverlapsCenters(
        broadphase: broadphase,
        centerX: centerX,
        centerY: centerY,
        halfX: halfX,
        halfY: halfY,
        owner: owner,
        sourceFaction: Faction.player,
        outTargetIndices: out,
      );

      final fromResolver = out
          .map((ti) => broadphase.targets.entities[ti])
          .toList()
        ..sort();

      final brute = <int>[];
      for (var ti = 0; ti < broadphase.targets.length; ti += 1) {
        final target = broadphase.targets.entities[ti];
        if (target == owner) continue;
        if (broadphase.targets.factions[ti] == Faction.player) continue;

        final overlaps = (centerX - halfX) <
                (broadphase.targets.centerX[ti] + broadphase.targets.halfX[ti]) &&
            (centerX + halfX) >
                (broadphase.targets.centerX[ti] - broadphase.targets.halfX[ti]) &&
            (centerY - halfY) <
                (broadphase.targets.centerY[ti] + broadphase.targets.halfY[ti]) &&
            (centerY + halfY) >
                (broadphase.targets.centerY[ti] - broadphase.targets.halfY[ti]);
        if (overlaps) brute.add(target);
      }
      brute.sort();

      expect(fromResolver, brute, reason: 'q=$q');
    }
  });
}
