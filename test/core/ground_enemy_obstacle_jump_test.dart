import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/collision/static_world_geometry_index.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/collision_system.dart';
import 'package:runner_core/ecs/systems/enemy_engagement_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/enemy_navigation_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/navigation/utils/jump_template.dart';
import 'package:runner_core/navigation/utils/standability.dart';
import 'package:runner_core/navigation/surface_extractor.dart';
import 'package:runner_core/navigation/surface_graph_builder.dart';
import 'package:runner_core/navigation/surface_navigator.dart';
import 'package:runner_core/navigation/surface_pathfinder.dart';
import 'package:runner_core/navigation/types/surface_graph.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:runner_core/ecs/entity_factory.dart';

void main() {
  test('ground enemy jumps over a wall obstacle on the ground', () {
    final world = EcsWorld();

    const groundTopY = 100.0;
    const enemyHalf = 8.0;
    const wallMinX = 40.0;
    const wallMaxX = 60.0;

    final player = world.createEntity();
    world.transform.add(
      player,
      posX: 160.0,
      posY: groundTopY - enemyHalf,
      velX: 0.0,
      velY: 0.0,
    );
    world.colliderAabb.add(
      player,
      const ColliderAabbDef(halfX: enemyHalf, halfY: enemyHalf),
    );
    world.body.add(
      player,
      const BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
    );
    world.collision.add(player);
    world.collision.grounded[world.collision.indexOf(player)] = true;

    final enemy = EntityFactory(world).createEnemy(
      enemyId: EnemyId.grojib,
      posX: 0.0,
      posY: groundTopY - enemyHalf,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.right,
      body: const BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
      collider: const ColliderAabbDef(halfX: enemyHalf, halfY: enemyHalf),
      health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    const geometry = StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: groundTopY),
      solids: <StaticSolid>[
        // Wall obstacle: blocks horizontal motion, but has no walkable top. This
        // forces a same-ground jump rather than a "step onto the obstacle".
        StaticSolid(
          minX: wallMinX,
          minY: groundTopY - 40.0,
          maxX: wallMaxX,
          maxY: groundTopY,
          sides: StaticSolid.sideLeft | StaticSolid.sideRight,
          oneWayTop: false,
          chunkIndex: 0,
          localSolidIndex: 0,
        ),
      ],
    );
    final staticWorld = StaticWorldGeometryIndex.from(geometry);

    final movement = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 10,
    );
    const physics = PhysicsTuning(gravityY: 200.0);

    final collision = CollisionSystem();
    final gravity = GravitySystem();

    final graphBuilder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 32),
      extractor: SurfaceExtractor(groundPadding: 200.0),
    );
    final jumpTemplate = JumpReachabilityTemplate.build(
      JumpProfile(
        jumpSpeed: 300.0,
        gravityY: physics.gravityY,
        maxAirTicks: 80,
        airSpeedX: 200.0,
        dtSeconds: movement.dtSeconds,
        agentHalfWidth: enemyHalf,
      ),
    );
    final graphResult = graphBuilder.build(
      geometry: geometry,
      jumpTemplate: jumpTemplate,
    );

    final pathfinder = SurfacePathfinder(
      maxExpandedNodes: 128,
      runSpeedX: 200.0,
      edgePenaltySeconds: 0.05,
    );
    final navigationSystem = EnemyNavigationSystem(
      surfaceNavigator: SurfaceNavigator(
        pathfinder: pathfinder,
        repathCooldownTicks: 5,
        takeoffEps: 6.0,
      ),
    );
    final engagementSystem = EnemyEngagementSystem(
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(
          locomotion: GroundEnemyLocomotionTuning(
            speedX: 200.0,
            stopDistanceX: 6.0,
            jumpSpeed: 300.0,
          ),
        ),
        tickHz: 10,
      ),
    );
    final locomotionSystem = GroundEnemyLocomotionSystem(
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(
          locomotion: GroundEnemyLocomotionTuning(
            speedX: 200.0,
            stopDistanceX: 6.0,
            jumpSpeed: 300.0,
          ),
        ),
        tickHz: 10,
      ),
    );
    navigationSystem.setSurfaceGraph(
      graph: graphResult.graph,
      spatialIndex: graphResult.spatialIndex,
      graphVersion: 1,
    );
    locomotionSystem.setSurfaceGraph(graph: graphResult.graph);

    var jumped = false;
    var clearedObstacle = false;
    for (var tick = 0; tick < 250; tick += 1) {
      navigationSystem.step(world, player: player, currentTick: tick);
      engagementSystem.step(world, player: player, currentTick: tick);
      locomotionSystem.step(
        world,
        player: player,
        dtSeconds: movement.dtSeconds,
        currentTick: tick,
      );
      gravity.step(world, movement, physics: physics);
      collision.step(world, movement, staticWorld: staticWorld);

      final ci = world.collision.indexOf(enemy);
      final grounded = world.collision.grounded[ci];
      if (!grounded) jumped = true;

      final ti = world.transform.indexOf(enemy);
      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];
      if (ex > wallMaxX + enemyHalf &&
          grounded &&
          (ey - (groundTopY - enemyHalf)).abs() < 1.0) {
        clearedObstacle = true;
        break;
      }
    }

    expect(jumped, isTrue);
    expect(clearedObstacle, isTrue);
  });

  test(
    'ground enemy still crosses when player is just beyond obstacle edge',
    () {
      final world = EcsWorld();
      const enemyCatalog = EnemyCatalog();
      final grojib = enemyCatalog.get(EnemyId.grojib);

      const groundTopY = 220.0;
      const wallMinX = 180.0;
      const wallMaxX = 244.0;
      const wallHeight = 80.0;
      const playerHalf = 20.0;
      const playerX = 250.0; // edge-adjacent target position

      final player = world.createEntity();
      world.transform.add(
        player,
        posX: playerX,
        posY: groundTopY - playerHalf,
        velX: 0.0,
        velY: 0.0,
      );
      world.colliderAabb.add(
        player,
        const ColliderAabbDef(halfX: playerHalf, halfY: playerHalf),
      );
      world.body.add(
        player,
        const BodyDef(
          isKinematic: false,
          useGravity: true,
          gravityScale: 1.0,
          maxVelY: 9999,
        ),
      );
      world.collision.add(player);
      world.collision.grounded[world.collision.indexOf(player)] = true;

      final enemy = EntityFactory(world).createEnemy(
        enemyId: EnemyId.grojib,
        posX: 40.0,
        posY: groundTopY - (grojib.collider.offsetY + grojib.collider.halfY),
        velX: 0.0,
        velY: 0.0,
        facing: Facing.right,
        body: grojib.body,
        collider: grojib.collider,
        health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 0,
          staminaMax: 0,
          regenPerSecond100: 0,
        ),
      );

      const geometry = StaticWorldGeometry(
        groundPlane: StaticGroundPlane(topY: groundTopY),
        solids: <StaticSolid>[
          StaticSolid(
            minX: wallMinX,
            minY: groundTopY - wallHeight,
            maxX: wallMaxX,
            maxY: groundTopY,
            sides: StaticSolid.sideAll,
            oneWayTop: false,
            chunkIndex: 0,
            localSolidIndex: 0,
          ),
        ],
      );
      final staticWorld = StaticWorldGeometryIndex.from(geometry);

      final movement = MovementTuningDerived.from(
        const MovementTuning(),
        tickHz: 60,
      );
      const physics = PhysicsTuning();
      final collision = CollisionSystem();
      final gravity = GravitySystem();

      final graphBuilder = SurfaceGraphBuilder(
        surfaceGrid: GridIndex2D(cellSize: 32),
        extractor: SurfaceExtractor(groundPadding: 400.0),
      );
      final jumpTemplate = JumpReachabilityTemplate.build(
        JumpProfile(
          jumpSpeed: 500.0,
          gravityY: physics.gravityY,
          maxAirTicks: 120,
          airSpeedX: 300.0,
          dtSeconds: movement.dtSeconds,
          agentHalfWidth: grojib.collider.halfX,
          agentHalfHeight: grojib.collider.halfY,
          collideCeilings: !grojib.body.ignoreCeilings,
          collideLeftWalls: (grojib.body.sideMask & BodyDef.sideLeft) != 0,
          collideRightWalls: (grojib.body.sideMask & BodyDef.sideRight) != 0,
        ),
      );
      final graphResult = graphBuilder.build(
        geometry: geometry,
        jumpTemplate: jumpTemplate,
      );

      final pathfinder = SurfacePathfinder(
        maxExpandedNodes: 256,
        runSpeedX: 300.0,
        edgePenaltySeconds: 0.05,
      );
      final navigationSystem = EnemyNavigationSystem(
        surfaceNavigator: SurfaceNavigator(
          pathfinder: pathfinder,
          repathCooldownTicks: 5,
          takeoffEps: 6.0,
        ),
      );
      final tuning = GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(),
        tickHz: 60,
      );
      final engagementSystem = EnemyEngagementSystem(groundEnemyTuning: tuning);
      final locomotionSystem = GroundEnemyLocomotionSystem(
        groundEnemyTuning: tuning,
      );
      navigationSystem.setSurfaceGraph(
        graph: graphResult.graph,
        spatialIndex: graphResult.spatialIndex,
        graphVersion: 1,
      );
      locomotionSystem.setSurfaceGraph(graph: graphResult.graph);

      final enemyAabb = world.colliderAabb.indexOf(enemy);
      final enemyHalfX = world.colliderAabb.halfX[enemyAabb];
      final enemyHalfY = world.colliderAabb.halfY[enemyAabb];
      final enemyOffsetY = world.colliderAabb.offsetY[enemyAabb];
      final groundY = groundTopY - (enemyOffsetY + enemyHalfY);

      var clearedObstacle = false;
      for (var tick = 0; tick < 900; tick += 1) {
        navigationSystem.step(world, player: player, currentTick: tick);
        engagementSystem.step(world, player: player, currentTick: tick);
        locomotionSystem.step(
          world,
          player: player,
          dtSeconds: movement.dtSeconds,
          currentTick: tick,
        );
        gravity.step(world, movement, physics: physics);
        collision.step(world, movement, staticWorld: staticWorld);

        final ti = world.transform.indexOf(enemy);
        final ci = world.collision.indexOf(enemy);
        final ex = world.transform.posX[ti];
        final ey = world.transform.posY[ti];
        final grounded = world.collision.grounded[ci];
        if (ex > wallMaxX + enemyHalfX &&
            grounded &&
            (ey - groundY).abs() < 1.0) {
          clearedObstacle = true;
          break;
        }
      }

      expect(clearedObstacle, isTrue);
    },
  );

  test(
    'hashash can land on a narrow obstacle top using its own nav graph',
    () {
      final world = EcsWorld();
      const enemyCatalog = EnemyCatalog();
      final grojib = enemyCatalog.get(EnemyId.grojib);
      final hashash = enemyCatalog.get(EnemyId.hashash);

      const groundTopY = 220.0;
      const obstacleTopY = 156.0;
      const obstacleMinX = 128.0;
      const obstacleMaxX = 139.0; // 11 px wide: standable for hashash only
      const playerHalf = 8.0;
      const tickHz = 60;

      final player = world.createEntity();
      world.transform.add(
        player,
        posX: (obstacleMinX + obstacleMaxX) * 0.5,
        posY: obstacleTopY - playerHalf,
        velX: 0.0,
        velY: 0.0,
      );
      world.colliderAabb.add(
        player,
        const ColliderAabbDef(halfX: playerHalf, halfY: playerHalf),
      );
      world.body.add(
        player,
        const BodyDef(
          isKinematic: false,
          useGravity: true,
          gravityScale: 1.0,
          maxVelY: 9999,
        ),
      );
      world.collision.add(player);
      world.collision.grounded[world.collision.indexOf(player)] = true;

      final enemy = EntityFactory(world).createEnemy(
        enemyId: EnemyId.hashash,
        posX: 40.0,
        posY:
            groundTopY - (hashash.collider.offsetY + hashash.collider.halfY),
        velX: 0.0,
        velY: 0.0,
        facing: Facing.right,
        body: hashash.body,
        collider: hashash.collider,
        health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 0,
          staminaMax: 0,
          regenPerSecond100: 0,
        ),
      );

      const geometry = StaticWorldGeometry(
        groundSegments: <StaticGroundSegment>[
          StaticGroundSegment(
            minX: 0.0,
            maxX: obstacleMinX,
            topY: groundTopY,
            chunkIndex: 0,
            localSegmentIndex: 0,
          ),
          StaticGroundSegment(
            minX: obstacleMaxX,
            maxX: 320.0,
            topY: groundTopY,
            chunkIndex: 0,
            localSegmentIndex: 1,
          ),
        ],
        solids: <StaticSolid>[
          StaticSolid(
            minX: obstacleMinX,
            minY: obstacleTopY,
            maxX: obstacleMaxX,
            maxY: groundTopY,
            sides: StaticSolid.sideAll,
            oneWayTop: false,
            chunkIndex: 0,
            localSolidIndex: 0,
          ),
        ],
      );
      final staticWorld = StaticWorldGeometryIndex.from(geometry);

      final movement = MovementTuningDerived.from(
        const MovementTuning(),
        tickHz: tickHz,
      );
      const physics = PhysicsTuning(gravityY: 1200.0);

      final collision = CollisionSystem();
      final gravity = GravitySystem();
      final graphBuilder = SurfaceGraphBuilder(
        surfaceGrid: GridIndex2D(cellSize: 64),
      );

      JumpReachabilityTemplate buildTemplate({
        required double halfWidth,
        required double halfHeight,
        required bool ignoreCeilings,
        required int sideMask,
      }) {
        return JumpReachabilityTemplate.build(
          JumpProfile(
            jumpSpeed: 500.0,
            gravityY: physics.gravityY,
            maxAirTicks: 120,
            airSpeedX: 300.0,
            dtSeconds: movement.dtSeconds,
            agentHalfWidth: halfWidth,
            agentHalfHeight: halfHeight,
            requiredSupportFraction: groundEnemySupportFraction,
            collideCeilings: !ignoreCeilings,
            collideLeftWalls: (sideMask & BodyDef.sideLeft) != 0,
            collideRightWalls: (sideMask & BodyDef.sideRight) != 0,
          ),
        );
      }

      final grojibGraphResult = graphBuilder.build(
        geometry: geometry,
        jumpTemplate: buildTemplate(
          halfWidth: grojib.collider.halfX,
          halfHeight: grojib.collider.halfY,
          ignoreCeilings: grojib.body.ignoreCeilings,
          sideMask: grojib.body.sideMask,
        ),
      );
      final hashashGraphResult = graphBuilder.build(
        geometry: geometry,
        jumpTemplate: buildTemplate(
          halfWidth: hashash.collider.halfX,
          halfHeight: hashash.collider.halfY,
          ignoreCeilings: hashash.body.ignoreCeilings,
          sideMask: hashash.body.sideMask,
        ),
      );

      final pathfinder = SurfacePathfinder(
        maxExpandedNodes: 128,
        runSpeedX: 300.0,
      );
      final navigationSystem = EnemyNavigationSystem(
        surfaceNavigator: SurfaceNavigator(
          pathfinder: pathfinder,
          repathCooldownTicks: 5,
          takeoffEps: 6.0,
        ),
      );
      final tuning = GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(
          locomotion: GroundEnemyLocomotionTuning(
            speedX: 300.0,
            stopDistanceX: 6.0,
            jumpSpeed: 500.0,
          ),
        ),
        tickHz: tickHz,
      );
      final engagementSystem = EnemyEngagementSystem(groundEnemyTuning: tuning);
      final locomotionSystem = GroundEnemyLocomotionSystem(
        groundEnemyTuning: tuning,
      );
      final graphsByEnemy = <EnemyId, SurfaceGraph>{
        EnemyId.grojib: grojibGraphResult.graph,
        EnemyId.hashash: hashashGraphResult.graph,
      };
      navigationSystem.setSurfaceGraphs(
        graphsByEnemy: graphsByEnemy,
        spatialIndex: hashashGraphResult.spatialIndex,
        graphVersion: 1,
      );
      locomotionSystem.setSurfaceGraphs(graphsByEnemy: graphsByEnemy);

      var landedOnObstacleTop = false;
      final expectedTopPosY =
          obstacleTopY - (hashash.collider.offsetY + hashash.collider.halfY);
      for (var tick = 0; tick < 360; tick += 1) {
        navigationSystem.step(world, player: player, currentTick: tick);
        engagementSystem.step(world, player: player, currentTick: tick);
        locomotionSystem.step(
          world,
          player: player,
          dtSeconds: movement.dtSeconds,
          currentTick: tick,
        );
        gravity.step(world, movement, physics: physics);
        collision.step(world, movement, staticWorld: staticWorld);

        final transformIndex = world.transform.indexOf(enemy);
        final collisionIndex = world.collision.indexOf(enemy);
        if (world.collision.grounded[collisionIndex] &&
            (world.transform.posY[transformIndex] - expectedTopPosY).abs() <
                1.0) {
          landedOnObstacleTop = true;
          break;
        }
      }

      expect(landedOnObstacleTop, isTrue);
    },
  );
}
