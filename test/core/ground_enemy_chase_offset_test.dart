import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/enemies/enemy_catalog.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/stores/enemies/surface_nav_state_store.dart';
import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/systems/enemy_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/navigation/types/surface_graph.dart';
import 'package:rpg_runner/core/navigation/surface_navigator.dart';
import 'package:rpg_runner/core/navigation/surface_pathfinder.dart';
import 'package:rpg_runner/core/navigation/utils/surface_spatial_index.dart';
import 'package:rpg_runner/core/navigation/types/walk_surface.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spells/spell_catalog.dart';
import 'package:rpg_runner/core/tuning/flying_enemy_tuning.dart';
import 'package:rpg_runner/core/tuning/ground_enemy_tuning.dart';
import 'package:rpg_runner/core/util/deterministic_rng.dart';
import 'package:rpg_runner/core/util/double_math.dart';

import 'test_spawns.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';

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

void main() {
  test('ground enemy chase offsets steer with deterministic target at range', () {
    const seed = 1234;
    const playerX = 200.0;
    const playerY = 0.0;
    const dtSeconds = 1.0 / 60.0;

    const baseTuning = GroundEnemyTuning(
      groundEnemyStopDistanceX: 0.0,
      groundEnemyMeleeRangeX: 2.0,
      groundEnemyChaseOffsetMaxX: 18.0,
      groundEnemyChaseOffsetMinAbsX: 6.0,
      groundEnemyChaseOffsetMeleeX: 3.0,
    );

    final world = EcsWorld(seed: seed);
    final player = EntityFactory(world).createPlayer(
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
    world.collision.grounded[world.collision.indexOf(enemyA)] = true;
    world.collision.grounded[world.collision.indexOf(enemyB)] = true;

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

    // Place the enemies halfway between the player and their chase-offset
    // target so the intended chase direction differs from "chase the player".
    world.transform.posX[world.transform.indexOf(enemyA)] =
        playerX + expectedOffsetA * 0.5;
    world.transform.posX[world.transform.indexOf(enemyB)] =
        playerX + expectedOffsetB * 0.5;

    final probe = SurfaceNavigatorProbe();
    final system = EnemySystem(
      unocoDemonTuning: UnocoDemonTuningDerived.from(
        const UnocoDemonTuning(),
        tickHz: 60,
      ),
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        baseTuning,
        tickHz: 60,
      ),
      surfaceNavigator: probe,
      enemyCatalog: const EnemyCatalog(),
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

    // Nav planning targets the player position (gap-safe); chase offset is
    // applied when there is no plan.
    expect(probe.targetXs[0], closeTo(playerX, 1e-9));
    expect(probe.targetXs[1], closeTo(playerX, 1e-9));

    final chase = world.groundEnemyChaseOffset;
    expect(
      chase.chaseOffsetX[chase.indexOf(enemyA)],
      closeTo(expectedOffsetA, 1e-9),
    );
    expect(
      chase.chaseOffsetX[chase.indexOf(enemyB)],
      closeTo(expectedOffsetB, 1e-9),
    );

    final tiA = world.transform.indexOf(enemyA);
    final tiB = world.transform.indexOf(enemyB);
    expect(world.transform.velX[tiA] * expectedOffsetA, greaterThan(0.0));
    expect(world.transform.velX[tiB] * expectedOffsetB, greaterThan(0.0));
  });

  test('ground enemy melee spread is controlled by groundEnemyChaseOffsetMeleeX', () {
    const seed = 4321;
    const playerX = 10.0;
    const playerY = 0.0;
    const dtSeconds = 1.0 / 60.0;

    final graph = _emptySurfaceGraph();
    final spatialIndex = _emptySpatialIndex()..rebuild(graph.surfaces);

    {
      const baseTuning = GroundEnemyTuning(
        groundEnemyStopDistanceX: 0.0,
        groundEnemyMeleeRangeX: 2.0,
        groundEnemyChaseOffsetMaxX: 18.0,
        groundEnemyChaseOffsetMinAbsX: 6.0,
        groundEnemyChaseOffsetMeleeX: 0.0,
      );

      final world = EcsWorld(seed: seed);
      final player = EntityFactory(world).createPlayer(
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

      final enemy = spawnGroundEnemy(world, posX: playerX, posY: playerY);
      world.collision.grounded[world.collision.indexOf(enemy)] = true;

      final probe = SurfaceNavigatorProbe();
      final system = EnemySystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(
          const UnocoDemonTuning(),
          tickHz: 60,
        ),
        groundEnemyTuning: GroundEnemyTuningDerived.from(
          baseTuning,
          tickHz: 60,
        ),
        surfaceNavigator: probe,
        enemyCatalog: const EnemyCatalog(),
        spells: const SpellCatalog(),
        projectiles: ProjectileCatalogDerived.from(
          const ProjectileCatalog(),
          tickHz: 60,
        ),
      );
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

      expect(probe.targetXs.single, closeTo(playerX, 1e-9));
      final ti = world.transform.indexOf(enemy);
      expect(world.transform.velX[ti], closeTo(0.0, 1e-9));
    }

    {
      const baseTuning = GroundEnemyTuning(
        groundEnemyStopDistanceX: 0.0,
        groundEnemyMeleeRangeX: 2.0,
        groundEnemyChaseOffsetMaxX: 18.0,
        groundEnemyChaseOffsetMinAbsX: 6.0,
        groundEnemyChaseOffsetMeleeX: 3.0,
      );

      final world = EcsWorld(seed: seed);
      final player = EntityFactory(world).createPlayer(
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

      final enemy = spawnGroundEnemy(world, posX: playerX, posY: playerY);
      world.collision.grounded[world.collision.indexOf(enemy)] = true;

      final probe = SurfaceNavigatorProbe();
      final system = EnemySystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(
          const UnocoDemonTuning(),
          tickHz: 60,
        ),
        groundEnemyTuning: GroundEnemyTuningDerived.from(
          baseTuning,
          tickHz: 60,
        ),
        surfaceNavigator: probe,
        enemyCatalog: const EnemyCatalog(),
        spells: const SpellCatalog(),
        projectiles: ProjectileCatalogDerived.from(
          const ProjectileCatalog(),
          tickHz: 60,
        ),
      );
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

      expect(probe.targetXs.single, closeTo(playerX, 1e-9));
      final ti = world.transform.indexOf(enemy);
      expect(world.transform.velX[ti].abs(), greaterThan(0.0));
    }
  });

  test('ground enemies separate during chase via speed scale', () {
    const seed = 999;
    const playerX = 200.0;
    const playerY = 0.0;
    const dtSeconds = 1.0;

    const baseTuning = GroundEnemyTuning(
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
    final player = EntityFactory(world).createPlayer(
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
      unocoDemonTuning: UnocoDemonTuningDerived.from(
        const UnocoDemonTuning(),
        tickHz: 60,
      ),
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        baseTuning,
        tickHz: 60,
      ),
      surfaceNavigator: probe,
      enemyCatalog: const EnemyCatalog(),
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
