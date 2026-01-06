import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/combat/faction.dart';
import 'package:walkscape_runner/core/ecs/spatial/broadphase_grid.dart';
import 'package:walkscape_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/faction_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/tuning/spatial_grid_tuning.dart';

void main() {
  test('BroadphaseGrid query matches brute-force overlap set', () {
    final world = EcsWorld();
    final rng = Random(1);

    // Create a deterministic set of damageable colliders.
    for (var i = 0; i < 200; i += 1) {
      final e = world.createEntity();

      final x = rng.nextDouble() * 800.0 - 400.0;
      final y = rng.nextDouble() * 400.0 - 200.0;
      final halfX = 4.0 + rng.nextDouble() * 24.0;
      final halfY = 4.0 + rng.nextDouble() * 24.0;

      world.transform.add(e, posX: x, posY: y, velX: 0.0, velY: 0.0);
      world.colliderAabb.add(e, ColliderAabbDef(halfX: halfX, halfY: halfY));
      world.health.add(e, const HealthDef(hp: 1, hpMax: 1, regenPerSecond: 0));
      world.faction.add(
        e,
        FactionDef(faction: rng.nextBool() ? Faction.player : Faction.enemy),
      );
    }

    // Ensure there is at least one multi-cell target to validate dedup.
    final big = world.createEntity();
    world.transform.add(big, posX: -10.0, posY: 20.0, velX: 0.0, velY: 0.0);
    world.colliderAabb.add(big, const ColliderAabbDef(halfX: 100.0, halfY: 60.0));
    world.health.add(big, const HealthDef(hp: 1, hpMax: 1, regenPerSecond: 0));
    world.faction.add(big, const FactionDef(faction: Faction.enemy));

    final broadphase = BroadphaseGrid(
      index: GridIndex2D(cellSize: SpatialGridTuning.v0BroadphaseCellSize),
    )..rebuild(world);

    final candidates = <int>[];
    for (var q = 0; q < 80; q += 1) {
      final minX = rng.nextDouble() * 800.0 - 400.0;
      final minY = rng.nextDouble() * 400.0 - 200.0;
      final maxX = minX + 10.0 + rng.nextDouble() * 140.0;
      final maxY = minY + 10.0 + rng.nextDouble() * 140.0;

      broadphase.queryAabbMinMax(
        minX: minX,
        minY: minY,
        maxX: maxX,
        maxY: maxY,
        outTargetIndices: candidates,
      );

      // Broadphase should return unique target indices.
      expect(candidates.length, candidates.toSet().length, reason: 'q=$q');

      final fromBroadphase = <int>[];
      for (final ti in candidates) {
        final cx = broadphase.targets.centerX[ti];
        final cy = broadphase.targets.centerY[ti];
        final hx = broadphase.targets.halfX[ti];
        final hy = broadphase.targets.halfY[ti];

        final tMinX = cx - hx;
        final tMaxX = cx + hx;
        final tMinY = cy - hy;
        final tMaxY = cy + hy;

        final overlaps =
            minX < tMaxX && maxX > tMinX && minY < tMaxY && maxY > tMinY;
        if (overlaps) {
          fromBroadphase.add(broadphase.targets.entities[ti]);
        }
      }
      fromBroadphase.sort();

      final brute = <int>[];
      for (var ti = 0; ti < broadphase.targets.length; ti += 1) {
        final cx = broadphase.targets.centerX[ti];
        final cy = broadphase.targets.centerY[ti];
        final hx = broadphase.targets.halfX[ti];
        final hy = broadphase.targets.halfY[ti];

        final tMinX = cx - hx;
        final tMaxX = cx + hx;
        final tMinY = cy - hy;
        final tMaxY = cy + hy;

        final overlaps =
            minX < tMaxX && maxX > tMinX && minY < tMaxY && maxY > tMinY;
        if (overlaps) {
          brute.add(broadphase.targets.entities[ti]);
        }
      }
      brute.sort();

      expect(fromBroadphase, brute, reason: 'q=$q');
    }
  });
}

