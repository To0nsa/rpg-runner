import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/collision/static_world_geometry.dart';
import 'package:walkscape_runner/core/collision/static_world_geometry_index.dart';
import 'package:walkscape_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/systems/collision_system.dart';
import 'package:walkscape_runner/core/ecs/systems/enemy_system.dart';
import 'package:walkscape_runner/core/ecs/systems/gravity_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/navigation/jump_template.dart';
import 'package:walkscape_runner/core/navigation/surface_graph_builder.dart';
import 'package:walkscape_runner/core/navigation/surface_navigator.dart';
import 'package:walkscape_runner/core/navigation/surface_pathfinder.dart';
import 'package:walkscape_runner/core/projectiles/projectile_catalog.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/spells/spell_catalog.dart';
import 'package:walkscape_runner/core/tuning/flying_enemy_tuning.dart';
import 'package:walkscape_runner/core/tuning/ground_enemy_tuning.dart';
import 'package:walkscape_runner/core/tuning/movement_tuning.dart';
import 'package:walkscape_runner/core/tuning/navigation_tuning.dart';
import 'package:walkscape_runner/core/tuning/physics_tuning.dart';

import 'test_spawns.dart';

JumpReachabilityTemplate _jumpTemplate({
  required GroundEnemyTuning base,
  required MovementTuningDerived movement,
  required PhysicsTuning physics,
  required double agentHalfWidth,
}) {
  // Mirrors the GameCore logic: allow some margin over the analytically computed
  // air time so gap jumps remain reachable even with discrete integration.
  final gravity = physics.gravityY;
  final jumpSpeed = base.groundEnemyJumpSpeed.abs();
  final baseAirSeconds = gravity <= 0 ? 1.0 : (2.0 * jumpSpeed) / gravity;
  final maxAirTicks = (baseAirSeconds * 1.5 / movement.dtSeconds).ceil();

  return JumpReachabilityTemplate.build(
    JumpProfile(
      jumpSpeed: jumpSpeed,
      gravityY: physics.gravityY,
      maxAirTicks: maxAirTicks,
      airSpeedX: base.groundEnemySpeedX,
      dtSeconds: movement.dtSeconds,
      agentHalfWidth: agentHalfWidth,
    ),
  );
}

void main() {
  test('multiple ground enemies jump across the same gap without falling', () {
    final world = EcsWorld(seed: 1337);

    const groundTopY = 100.0;
    const enemyHalf = 8.0;

    final movement = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 60,
    );
    const physics = PhysicsTuning(gravityY: 1200.0);
    const navTuning = NavigationTuning();
    const groundEnemyBase = GroundEnemyTuning(
      groundEnemySpeedX: 300.0,
      groundEnemyStopDistanceX: 6.0,
      groundEnemyJumpSpeed: 500.0,
    );

    final player = world.createPlayer(
      posX: 280.0,
      posY: groundTopY - enemyHalf,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: enemyHalf, halfY: enemyHalf),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final enemies = <int>[
      spawnGroundEnemy(
        world,
        posX: 40.0,
        posY: groundTopY - enemyHalf,
        body: const BodyDef(isKinematic: false, useGravity: true, maxVelY: 9999),
      ),
      spawnGroundEnemy(
        world,
        posX: 64.0,
        posY: groundTopY - enemyHalf,
        body: const BodyDef(isKinematic: false, useGravity: true, maxVelY: 9999),
      ),
      spawnGroundEnemy(
        world,
        posX: 88.0,
        posY: groundTopY - enemyHalf,
        body: const BodyDef(isKinematic: false, useGravity: true, maxVelY: 9999),
      ),
    ];
    for (final e in enemies) {
      world.collision.grounded[world.collision.indexOf(e)] = true;
    }

    const gapMinX = 120.0;
    const gapMaxX = 200.0;
    const rightSegMinX = gapMaxX;

    const geometry = StaticWorldGeometry(
      groundPlane: null,
      groundSegments: <StaticGroundSegment>[
        StaticGroundSegment(
          minX: 0,
          maxX: gapMinX,
          topY: groundTopY,
          chunkIndex: 0,
          localSegmentIndex: 0,
        ),
        StaticGroundSegment(
          minX: gapMaxX,
          maxX: 400,
          topY: groundTopY,
          chunkIndex: 0,
          localSegmentIndex: 1,
        ),
      ],
      groundGaps: <StaticGroundGap>[
        StaticGroundGap(minX: gapMinX, maxX: gapMaxX),
      ],
    );
    final staticWorld = StaticWorldGeometryIndex.from(geometry);

    final graphBuilder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 64),
      takeoffSampleMaxStep: navTuning.takeoffSampleMaxStep,
    );
    final graphResult = graphBuilder.build(
      geometry: geometry,
      jumpTemplate: _jumpTemplate(
        base: groundEnemyBase,
        movement: movement,
        physics: physics,
        agentHalfWidth: enemyHalf,
      ),
    );

    final system = EnemySystem(
      flyingEnemyTuning: FlyingEnemyTuningDerived.from(
        const FlyingEnemyTuning(),
        tickHz: 60,
      ),
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        groundEnemyBase,
        tickHz: 60,
      ),
      surfaceNavigator: SurfaceNavigator(
        pathfinder: SurfacePathfinder(
          maxExpandedNodes: navTuning.maxExpandedNodes,
          runSpeedX: groundEnemyBase.groundEnemySpeedX,
          edgePenaltySeconds: navTuning.edgePenaltySeconds,
        ),
        repathCooldownTicks: navTuning.repathCooldownTicks,
        surfaceEps: navTuning.surfaceEps,
        takeoffEps: groundEnemyBase.groundEnemyStopDistanceX,
      ),
      spells: const SpellCatalog(),
      projectiles: ProjectileCatalogDerived.from(
        const ProjectileCatalog(),
        tickHz: 60,
      ),
    );
    system.setSurfaceGraph(
      graph: graphResult.graph,
      spatialIndex: graphResult.spatialIndex,
      graphVersion: 1,
    );

    final gravity = GravitySystem();
    final collision = CollisionSystem();

    for (var tick = 0; tick < 600; tick += 1) {
      system.stepSteering(
        world,
        player: player,
        groundTopY: groundTopY,
        dtSeconds: movement.dtSeconds,
      );

      gravity.step(world, movement, physics: physics);
      collision.step(world, movement, staticWorld: staticWorld);

      for (final e in enemies) {
        final ti = world.transform.indexOf(e);
        final ex = world.transform.posX[ti];
        final ey = world.transform.posY[ti];
        if (ex > gapMinX && ex < gapMaxX) {
          // Being above the gap is fine (jumping). Falling into it is not.
          expect(
            ey,
            lessThan(groundTopY + 60.0),
            reason: 'enemy $e appears to be falling inside the gap (x=$ex y=$ey)',
          );
        }
      }
    }

    for (final e in enemies) {
      final ti = world.transform.indexOf(e);
      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];
      expect(ex, greaterThan(rightSegMinX + 10.0));
      expect((ey - (groundTopY - enemyHalf)).abs(), lessThan(2.0));
    }
  });

  test('multiple ground enemies still clear a wide gap when starting from rest at takeoff', () {
    final world = EcsWorld(seed: 4242);

    const groundTopY = 100.0;
    const enemyHalf = 8.0;

    final movement = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 60,
    );
    const physics = PhysicsTuning(gravityY: 1200.0);
    const navTuning = NavigationTuning();
    const groundEnemyBase = GroundEnemyTuning(
      groundEnemySpeedX: 300.0,
      groundEnemyStopDistanceX: 6.0,
      groundEnemyAccelX: 600.0,
      groundEnemyDecelX: 400.0,
      groundEnemyJumpSpeed: 400.0,
    );

    const gapMinX = 200.0;
    const gapMaxX = 350.0;
    const rightSegMinX = gapMaxX;
    const takeoffX = gapMinX - enemyHalf;

    final player = world.createPlayer(
      posX: 480.0,
      posY: groundTopY - enemyHalf,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: enemyHalf, halfY: enemyHalf),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final enemies = <int>[
      spawnGroundEnemy(
        world,
        posX: takeoffX,
        posY: groundTopY - enemyHalf,
        body: const BodyDef(isKinematic: false, useGravity: true, maxVelY: 9999),
      ),
      spawnGroundEnemy(
        world,
        posX: takeoffX - 6.0,
        posY: groundTopY - enemyHalf,
        body: const BodyDef(isKinematic: false, useGravity: true, maxVelY: 9999),
      ),
      spawnGroundEnemy(
        world,
        posX: takeoffX - 12.0,
        posY: groundTopY - enemyHalf,
        body: const BodyDef(isKinematic: false, useGravity: true, maxVelY: 9999),
      ),
    ];
    for (final e in enemies) {
      final ti = world.transform.indexOf(e);
      world.transform.velX[ti] = 0.0;
      world.transform.velY[ti] = 0.0;
      world.collision.grounded[world.collision.indexOf(e)] = true;
    }

    const geometry = StaticWorldGeometry(
      groundPlane: null,
      groundSegments: <StaticGroundSegment>[
        StaticGroundSegment(
          minX: 0,
          maxX: gapMinX,
          topY: groundTopY,
          chunkIndex: 0,
          localSegmentIndex: 0,
        ),
        StaticGroundSegment(
          minX: gapMaxX,
          maxX: 700,
          topY: groundTopY,
          chunkIndex: 0,
          localSegmentIndex: 1,
        ),
      ],
      groundGaps: <StaticGroundGap>[
        StaticGroundGap(minX: gapMinX, maxX: gapMaxX),
      ],
    );
    final staticWorld = StaticWorldGeometryIndex.from(geometry);

    final graphBuilder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 64),
      takeoffSampleMaxStep: navTuning.takeoffSampleMaxStep,
    );
    final graphResult = graphBuilder.build(
      geometry: geometry,
      jumpTemplate: _jumpTemplate(
        base: groundEnemyBase,
        movement: movement,
        physics: physics,
        agentHalfWidth: enemyHalf,
      ),
    );

    final system = EnemySystem(
      flyingEnemyTuning: FlyingEnemyTuningDerived.from(
        const FlyingEnemyTuning(),
        tickHz: 60,
      ),
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        groundEnemyBase,
        tickHz: 60,
      ),
      surfaceNavigator: SurfaceNavigator(
        pathfinder: SurfacePathfinder(
          maxExpandedNodes: navTuning.maxExpandedNodes,
          runSpeedX: groundEnemyBase.groundEnemySpeedX,
          edgePenaltySeconds: navTuning.edgePenaltySeconds,
        ),
        repathCooldownTicks: navTuning.repathCooldownTicks,
        surfaceEps: navTuning.surfaceEps,
        takeoffEps: groundEnemyBase.groundEnemyStopDistanceX,
      ),
      spells: const SpellCatalog(),
      projectiles: ProjectileCatalogDerived.from(
        const ProjectileCatalog(),
        tickHz: 60,
      ),
    );
    system.setSurfaceGraph(
      graph: graphResult.graph,
      spatialIndex: graphResult.spatialIndex,
      graphVersion: 1,
    );

    final gravity = GravitySystem();
    final collision = CollisionSystem();

    for (var tick = 0; tick < 300; tick += 1) {
      system.stepSteering(
        world,
        player: player,
        groundTopY: groundTopY,
        dtSeconds: movement.dtSeconds,
      );

      gravity.step(world, movement, physics: physics);
      collision.step(world, movement, staticWorld: staticWorld);

      for (final e in enemies) {
        final ti = world.transform.indexOf(e);
        final ex = world.transform.posX[ti];
        final ey = world.transform.posY[ti];
        if (ex > gapMinX && ex < gapMaxX) {
          // Being above the gap is fine (jumping). Falling into it is not.
          expect(
            ey,
            lessThan(groundTopY + 60.0),
            reason: 'enemy $e appears to be falling inside the gap (x=$ex y=$ey)',
          );
        }
      }
    }

    for (final e in enemies) {
      final ti = world.transform.indexOf(e);
      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];
      expect(ex, greaterThan(rightSegMinX + 10.0));
      expect((ey - (groundTopY - enemyHalf)).abs(), lessThan(2.0));
    }
  });

  test('when player is airborne, enemies do not walk into the gap (no-plan fallback clamps to surface)', () {
    final world = EcsWorld(seed: 2025);

    const groundTopY = 100.0;
    const enemyHalf = 8.0;

    final movement = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 60,
    );
    const physics = PhysicsTuning(gravityY: 1200.0);
    const navTuning = NavigationTuning();
    const groundEnemyBase = GroundEnemyTuning(
      groundEnemySpeedX: 300.0,
      groundEnemyStopDistanceX: 6.0,
      groundEnemyJumpSpeed: 500.0,
    );

    final player = world.createPlayer(
      posX: 280.0,
      posY: 20.0, // airborne
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      grounded: false,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: enemyHalf, halfY: enemyHalf),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );
    world.collision.grounded[world.collision.indexOf(player)] = false;

    final enemy = spawnGroundEnemy(
      world,
      posX: 88.0,
      posY: groundTopY - enemyHalf,
      body: const BodyDef(isKinematic: false, useGravity: true, maxVelY: 9999),
    );
    world.collision.grounded[world.collision.indexOf(enemy)] = true;

    const gapMinX = 120.0;
    const gapMaxX = 200.0;

    const geometry = StaticWorldGeometry(
      groundPlane: null,
      groundSegments: <StaticGroundSegment>[
        StaticGroundSegment(
          minX: 0,
          maxX: gapMinX,
          topY: groundTopY,
          chunkIndex: 0,
          localSegmentIndex: 0,
        ),
        StaticGroundSegment(
          minX: gapMaxX,
          maxX: 400,
          topY: groundTopY,
          chunkIndex: 0,
          localSegmentIndex: 1,
        ),
      ],
      groundGaps: <StaticGroundGap>[
        StaticGroundGap(minX: gapMinX, maxX: gapMaxX),
      ],
    );
    final staticWorld = StaticWorldGeometryIndex.from(geometry);

    final graphBuilder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 64),
      takeoffSampleMaxStep: navTuning.takeoffSampleMaxStep,
    );
    final graphResult = graphBuilder.build(
      geometry: geometry,
      jumpTemplate: _jumpTemplate(
        base: groundEnemyBase,
        movement: movement,
        physics: physics,
        agentHalfWidth: enemyHalf,
      ),
    );

    final system = EnemySystem(
      flyingEnemyTuning: FlyingEnemyTuningDerived.from(
        const FlyingEnemyTuning(),
        tickHz: 60,
      ),
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        groundEnemyBase,
        tickHz: 60,
      ),
      surfaceNavigator: SurfaceNavigator(
        pathfinder: SurfacePathfinder(
          maxExpandedNodes: navTuning.maxExpandedNodes,
          runSpeedX: groundEnemyBase.groundEnemySpeedX,
          edgePenaltySeconds: navTuning.edgePenaltySeconds,
        ),
        repathCooldownTicks: navTuning.repathCooldownTicks,
        surfaceEps: navTuning.surfaceEps,
        takeoffEps: groundEnemyBase.groundEnemyStopDistanceX,
      ),
      spells: const SpellCatalog(),
      projectiles: ProjectileCatalogDerived.from(
        const ProjectileCatalog(),
        tickHz: 60,
      ),
    );
    system.setSurfaceGraph(
      graph: graphResult.graph,
      spatialIndex: graphResult.spatialIndex,
      graphVersion: 1,
    );

    final gravity = GravitySystem();
    final collision = CollisionSystem();

    for (var tick = 0; tick < 300; tick += 1) {
      system.stepSteering(
        world,
        player: player,
        groundTopY: groundTopY,
        dtSeconds: movement.dtSeconds,
      );

      gravity.step(world, movement, physics: physics);
      collision.step(world, movement, staticWorld: staticWorld);

      final ti = world.transform.indexOf(enemy);
      final ai = world.colliderAabb.indexOf(enemy);
      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];

      final centerX = ex + world.colliderAabb.offsetX[ai];
      final halfX = world.colliderAabb.halfX[ai];
      final minX = centerX - halfX;
      final maxX = centerX + halfX;

      // It's OK for the enemy to "lean over" the gap (partial overlap with the
      // last ground segment), but it should not fully leave the ledge while
      // the player is airborne (no navigation target surface).
      if (maxX > gapMinX && minX < gapMaxX) {
        expect(
          minX,
          lessThanOrEqualTo(gapMinX + 1e-3),
          reason:
              'enemy fully left the ledge into the gap (centerX=$centerX minX=$minX y=$ey)',
        );
      }

      // And it should never start falling deep into the gap in this scenario.
      expect(
        ey,
        lessThan(groundTopY + 60.0),
        reason: 'enemy appears to be falling into the gap (x=$ex y=$ey)',
      );
    }
  });
}
