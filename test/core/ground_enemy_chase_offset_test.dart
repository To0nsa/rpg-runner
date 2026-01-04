import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/stores/surface_nav_state_store.dart';
import 'package:walkscape_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:walkscape_runner/core/ecs/systems/enemy_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/navigation/surface_graph.dart';
import 'package:walkscape_runner/core/navigation/surface_navigator.dart';
import 'package:walkscape_runner/core/navigation/surface_pathfinder.dart';
import 'package:walkscape_runner/core/navigation/surface_spatial_index.dart';
import 'package:walkscape_runner/core/navigation/walk_surface.dart';
import 'package:walkscape_runner/core/projectiles/projectile_catalog.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/spells/spell_catalog.dart';
import 'package:walkscape_runner/core/tuning/v0_flying_enemy_tuning.dart';
import 'package:walkscape_runner/core/tuning/v0_ground_enemy_tuning.dart';
import 'package:walkscape_runner/core/util/deterministic_rng.dart';
import 'package:walkscape_runner/core/util/double_math.dart';

import 'test_spawns.dart';

class SurfaceNavigatorProbe extends SurfaceNavigator {
  SurfaceNavigatorProbe()
      : super(
          pathfinder: SurfacePathfinder(
            maxExpandedNodes: 1,
            runSpeedX: 1.0,
          ),
        );

  final List<double> targetXs = <double>[];

  @override
  SurfaceNavIntent update({
    required SurfaceNavStateStore navStore,
    required int navIndex,
    required SurfaceGraph graph,
    required SurfaceSpatialIndex spatialIndex,
    required int graphVersion,
    required double entityX,
    required double entityBottomY,
    required double entityHalfWidth,
    required bool entityGrounded,
    required double targetX,
    required double targetBottomY,
    required double targetHalfWidth,
    required bool targetGrounded,
  }) {
    targetXs.add(targetX);
    return SurfaceNavIntent(
      desiredX: targetX,
      jumpNow: false,
      hasPlan: false,
    );
  }
}

SurfaceGraph _emptySurfaceGraph() {
  return SurfaceGraph(
    surfaces: const <WalkSurface>[],
    edgeOffsets: const <int>[0],
    edges: const <SurfaceEdge>[],
    indexById: const <int, int>{},
  );
}

SurfaceSpatialIndex _emptySpatialIndex() {
  return SurfaceSpatialIndex(
    index: GridIndex2D(cellSize: 32),
  );
}

double _expectedChaseOffset({
  required int seed,
  required int entityId,
  required double maxAbsX,
  required double minAbsX,
}) {
  final maxAbs = maxAbsX.abs();
  if (maxAbs <= 0.0) return 0.0;
  var rngState = seedFrom(seed, entityId);
  rngState = nextUint32(rngState);
  var offsetX = rangeDouble(rngState, -maxAbs, maxAbs);
  final minAbs = clampDouble(minAbsX, 0.0, maxAbs);
  final absOffset = offsetX.abs();
  if (absOffset < minAbs) {
    offsetX = offsetX >= 0.0 ? minAbs : -minAbs;
    if (absOffset == 0.0) {
      offsetX = minAbs;
    }
  }
  return offsetX;
}

double _expectedMeleeOffset({
  required double chaseOffsetX,
  required double meleeMaxAbsX,
}) {
  final meleeAbs = min(meleeMaxAbsX.abs(), chaseOffsetX.abs());
  if (meleeAbs == 0.0) return 0.0;
  return chaseOffsetX >= 0.0 ? meleeAbs : -meleeAbs;
}

void main() {
  test('ground enemy chase offsets steer with deterministic target at range', () {
    const seed = 1234;
    const playerX = 200.0;
    const playerY = 0.0;
    const dtSeconds = 1.0 / 60.0;

    const baseTuning = V0GroundEnemyTuning(
      groundEnemyStopDistanceX: 0.0,
      groundEnemyMeleeRangeX: 2.0,
      groundEnemyChaseOffsetMaxX: 18.0,
      groundEnemyChaseOffsetMinAbsX: 6.0,
      groundEnemyChaseOffsetMeleeX: 3.0,
    );

    final world = EcsWorld(seed: seed);
    final player = world.createPlayer(
      posX: playerX,
      posY: playerY,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final enemyA = spawnGroundEnemy(world, posX: 0.0, posY: 0.0);
    final enemyB = spawnGroundEnemy(world, posX: 0.0, posY: 0.0);

    final probe = SurfaceNavigatorProbe();
    final system = EnemySystem(
      flyingEnemyTuning: V0FlyingEnemyTuningDerived.from(
        const V0FlyingEnemyTuning(),
        tickHz: 60,
      ),
      groundEnemyTuning: V0GroundEnemyTuningDerived.from(
        baseTuning,
        tickHz: 60,
      ),
      surfaceNavigator: probe,
      spells: const SpellCatalog(),
      projectiles: ProjectileCatalogDerived.from(
        const ProjectileCatalog(),
        tickHz: 60,
      ),
    );

    final graph = _emptySurfaceGraph();
    final spatialIndex = _emptySpatialIndex();
    spatialIndex.rebuild(graph.surfaces);
    system.setSurfaceGraph(
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
    );

    system.stepSteering(
      world,
      player: player,
      groundTopY: 0.0,
      dtSeconds: dtSeconds,
    );

    expect(probe.targetXs.length, 2);

    final expectedOffsetA = _expectedChaseOffset(
      seed: seed,
      entityId: enemyA,
      maxAbsX: baseTuning.groundEnemyChaseOffsetMaxX,
      minAbsX: baseTuning.groundEnemyChaseOffsetMinAbsX,
    );
    final expectedOffsetB = _expectedChaseOffset(
      seed: seed,
      entityId: enemyB,
      maxAbsX: baseTuning.groundEnemyChaseOffsetMaxX,
      minAbsX: baseTuning.groundEnemyChaseOffsetMinAbsX,
    );

    expect(probe.targetXs[0], closeTo(playerX + expectedOffsetA, 1e-9));
    expect(probe.targetXs[1], closeTo(playerX + expectedOffsetB, 1e-9));
  });

  test('ground enemy chase offsets keep a small melee spread', () {
    const seed = 4321;
    const playerX = 10.0;
    const playerY = 0.0;
    const dtSeconds = 1.0 / 60.0;

    const baseTuning = V0GroundEnemyTuning(
      groundEnemyStopDistanceX: 0.0,
      groundEnemyMeleeRangeX: 2.0,
      groundEnemyChaseOffsetMaxX: 18.0,
      groundEnemyChaseOffsetMinAbsX: 6.0,
      groundEnemyChaseOffsetMeleeX: 3.0,
    );

    final world = EcsWorld(seed: seed);
    final player = world.createPlayer(
      posX: playerX,
      posY: playerY,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final enemyA = spawnGroundEnemy(world, posX: 11.0, posY: 0.0);
    final enemyB = spawnGroundEnemy(world, posX: 9.0, posY: 0.0);

    final probe = SurfaceNavigatorProbe();
    final system = EnemySystem(
      flyingEnemyTuning: V0FlyingEnemyTuningDerived.from(
        const V0FlyingEnemyTuning(),
        tickHz: 60,
      ),
      groundEnemyTuning: V0GroundEnemyTuningDerived.from(
        baseTuning,
        tickHz: 60,
      ),
      surfaceNavigator: probe,
      spells: const SpellCatalog(),
      projectiles: ProjectileCatalogDerived.from(
        const ProjectileCatalog(),
        tickHz: 60,
      ),
    );

    final graph = _emptySurfaceGraph();
    final spatialIndex = _emptySpatialIndex();
    spatialIndex.rebuild(graph.surfaces);
    system.setSurfaceGraph(
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
    );

    system.stepSteering(
      world,
      player: player,
      groundTopY: 0.0,
      dtSeconds: dtSeconds,
    );

    expect(probe.targetXs.length, 2);

    final expectedOffsetA = _expectedChaseOffset(
      seed: seed,
      entityId: enemyA,
      maxAbsX: baseTuning.groundEnemyChaseOffsetMaxX,
      minAbsX: baseTuning.groundEnemyChaseOffsetMinAbsX,
    );
    final expectedOffsetB = _expectedChaseOffset(
      seed: seed,
      entityId: enemyB,
      maxAbsX: baseTuning.groundEnemyChaseOffsetMaxX,
      minAbsX: baseTuning.groundEnemyChaseOffsetMinAbsX,
    );

    final meleeOffsetA = _expectedMeleeOffset(
      chaseOffsetX: expectedOffsetA,
      meleeMaxAbsX: baseTuning.groundEnemyChaseOffsetMeleeX,
    );
    final meleeOffsetB = _expectedMeleeOffset(
      chaseOffsetX: expectedOffsetB,
      meleeMaxAbsX: baseTuning.groundEnemyChaseOffsetMeleeX,
    );

    expect(probe.targetXs[0], closeTo(playerX + meleeOffsetA, 1e-9));
    expect(probe.targetXs[1], closeTo(playerX + meleeOffsetB, 1e-9));
    expect((probe.targetXs[0] - playerX).abs(), lessThanOrEqualTo(
      baseTuning.groundEnemyChaseOffsetMeleeX,
    ));
    expect((probe.targetXs[1] - playerX).abs(), lessThanOrEqualTo(
      baseTuning.groundEnemyChaseOffsetMeleeX,
    ));
  });

  test('ground enemies separate during chase via speed scale', () {
    const seed = 999;
    const playerX = 200.0;
    const playerY = 0.0;
    const dtSeconds = 1.0;

    const baseTuning = V0GroundEnemyTuning(
      groundEnemySpeedX: 300.0,
      groundEnemyStopDistanceX: 0.0,
      groundEnemyAccelX: 600.0,
      groundEnemyDecelX: 400.0,
      groundEnemyMeleeRangeX: 2.0,
      groundEnemyChaseOffsetMaxX: 18.0,
      groundEnemyChaseOffsetMinAbsX: 6.0,
      groundEnemyChaseOffsetMeleeX: 0.0,
      groundEnemyChaseSpeedScaleMin: 0.92,
      groundEnemyChaseSpeedScaleMax: 1.08,
    );

    final world = EcsWorld(seed: seed);
    final player = world.createPlayer(
      posX: playerX,
      posY: playerY,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final enemyA = spawnGroundEnemy(world, posX: 0.0, posY: 0.0);
    final enemyB = spawnGroundEnemy(world, posX: 0.0, posY: 0.0);

    final probe = SurfaceNavigatorProbe();
    final system = EnemySystem(
      flyingEnemyTuning: V0FlyingEnemyTuningDerived.from(
        const V0FlyingEnemyTuning(),
        tickHz: 60,
      ),
      groundEnemyTuning: V0GroundEnemyTuningDerived.from(
        baseTuning,
        tickHz: 60,
      ),
      surfaceNavigator: probe,
      spells: const SpellCatalog(),
      projectiles: ProjectileCatalogDerived.from(
        const ProjectileCatalog(),
        tickHz: 60,
      ),
    );

    final graph = _emptySurfaceGraph();
    final spatialIndex = _emptySpatialIndex();
    spatialIndex.rebuild(graph.surfaces);
    system.setSurfaceGraph(
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
    );

    system.stepSteering(
      world,
      player: player,
      groundTopY: 0.0,
      dtSeconds: dtSeconds,
    );

    final tiA = world.transform.indexOf(enemyA);
    final tiB = world.transform.indexOf(enemyB);
    expect(world.transform.velX[tiA], isNot(closeTo(world.transform.velX[tiB], 1e-9)));
  });
}
