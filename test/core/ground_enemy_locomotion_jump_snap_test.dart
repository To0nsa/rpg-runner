import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/enemies/enemy_id.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/navigation/types/surface_graph.dart';
import 'package:rpg_runner/core/navigation/types/walk_surface.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/tuning/ground_enemy_tuning.dart';

void main() {
  test(
    'GroundEnemyLocomotionSystem jump snap keeps horizontal commit direction',
    () {
      const dtSeconds = 1.0 / 60.0;
      const travelTicks = 30;
      const locomotionBase = GroundEnemyLocomotionTuning(
        speedX: 300.0,
        stopDistanceX: 1.0,
        accelX: 60.0,
        decelX: 60.0,
        jumpSpeed: 500.0,
      );
      final derived = GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(locomotion: locomotionBase),
        tickHz: 60,
      );

      for (final scenario in <({double startX, double landingX, int dir})>[
        (startX: 40.0, landingX: 160.0, dir: 1),
        (startX: 220.0, landingX: 100.0, dir: -1),
      ]) {
        final world = EcsWorld();

        final player = world.createEntity();
        world.transform.add(player, posX: 0.0, posY: 0.0, velX: 0.0, velY: 0.0);

        final enemy = EntityFactory(world).createEnemy(
          enemyId: EnemyId.grojib,
          posX: scenario.startX,
          posY: 92.0,
          velX: 0.0,
          velY: 0.0,
          facing: Facing.right,
          body: const BodyDef(
            isKinematic: false,
            useGravity: true,
            gravityScale: 1.0,
            maxVelY: 9999,
          ),
          collider: const ColliderAabbDef(halfX: 8.0, halfY: 8.0),
          health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
          mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
          stamina: const StaminaDef(
            stamina: 0,
            staminaMax: 0,
            regenPerSecond100: 0,
          ),
        );

        final navIntentIndex = world.navIntent.indexOf(enemy);
        world.navIntent.hasPlan[navIntentIndex] = true;
        world.navIntent.jumpNow[navIntentIndex] = true;
        world.navIntent.desiredX[navIntentIndex] = scenario.landingX;
        world.navIntent.commitMoveDirX[navIntentIndex] = scenario.dir;
        world.navIntent.hasSafeSurface[navIntentIndex] = false;

        final engagementIndex = world.engagementIntent.indexOf(enemy);
        world.engagementIntent.desiredTargetX[engagementIndex] =
            scenario.landingX;
        world.engagementIntent.arrivalSlowRadiusX[engagementIndex] = 0.0;
        world.engagementIntent.stateSpeedMul[engagementIndex] = 1.0;
        world.engagementIntent.speedScale[engagementIndex] = 1.0;

        world.collision.grounded[world.collision.indexOf(enemy)] = true;
        final navIndex = world.surfaceNav.indexOf(enemy);
        world.surfaceNav.activeEdgeIndex[navIndex] = 0;

        final graph = SurfaceGraph(
          surfaces: const <WalkSurface>[
            WalkSurface(id: 1, xMin: -1000.0, xMax: 1000.0, yTop: 100.0),
          ],
          edgeOffsets: const <int>[0, 1],
          edges: <SurfaceEdge>[
            SurfaceEdge(
              to: 0,
              kind: SurfaceEdgeKind.jump,
              takeoffX: scenario.startX,
              landingX: scenario.landingX,
              commitDirX: scenario.dir,
              travelTicks: travelTicks,
              cost: 1.0,
            ),
          ],
          indexById: const <int, int>{1: 0},
        );

        final locomotionSystem = GroundEnemyLocomotionSystem(
          groundEnemyTuning: derived,
        );
        locomotionSystem.setSurfaceGraph(graph: graph);
        locomotionSystem.step(
          world,
          player: player,
          dtSeconds: dtSeconds,
          currentTick: 0,
        );

        final enemyTi = world.transform.indexOf(enemy);
        final enemyIndex = world.enemy.indexOf(enemy);

        final velX = world.transform.velX[enemyTi];
        final velY = world.transform.velY[enemyTi];
        final requiredAbs =
            (scenario.landingX - scenario.startX).abs() /
            (travelTicks * dtSeconds);

        expect(velX.abs(), greaterThanOrEqualTo(requiredAbs - 1e-6));
        expect(velX.abs(), lessThanOrEqualTo(locomotionBase.speedX + 1e-6));
        expect(velX * scenario.dir, greaterThan(0.0));
        expect(velY, equals(-locomotionBase.jumpSpeed));
        expect(
          world.enemy.facing[enemyIndex],
          scenario.dir > 0 ? Facing.right : Facing.left,
        );
      }
    },
  );

  test('planned jump ignores engagement slowdown multipliers', () {
    const dtSeconds = 1.0 / 60.0;
    const travelTicks = 30;
    const locomotionBase = GroundEnemyLocomotionTuning(
      speedX: 300.0,
      stopDistanceX: 1.0,
      accelX: 60.0,
      decelX: 60.0,
      jumpSpeed: 500.0,
    );
    final derived = GroundEnemyTuningDerived.from(
      const GroundEnemyTuning(locomotion: locomotionBase),
      tickHz: 60,
    );

    final world = EcsWorld();
    final player = world.createEntity();
    world.transform.add(player, posX: 0.0, posY: 0.0, velX: 0.0, velY: 0.0);

    const startX = 40.0;
    const landingX = 160.0;
    final enemy = EntityFactory(world).createEnemy(
      enemyId: EnemyId.grojib,
      posX: startX,
      posY: 92.0,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.right,
      body: const BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
      collider: const ColliderAabbDef(halfX: 8.0, halfY: 8.0),
      health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final navIntentIndex = world.navIntent.indexOf(enemy);
    world.navIntent.hasPlan[navIntentIndex] = true;
    world.navIntent.jumpNow[navIntentIndex] = true;
    world.navIntent.desiredX[navIntentIndex] = landingX;
    world.navIntent.commitMoveDirX[navIntentIndex] = 1;
    world.navIntent.hasSafeSurface[navIntentIndex] = false;

    final engagementIndex = world.engagementIntent.indexOf(enemy);
    // These should be ignored while executing a planned traversal.
    world.engagementIntent.desiredTargetX[engagementIndex] = landingX;
    world.engagementIntent.arrivalSlowRadiusX[engagementIndex] = 9999.0;
    world.engagementIntent.stateSpeedMul[engagementIndex] = 0.25;
    world.engagementIntent.speedScale[engagementIndex] = 0.25;

    world.collision.grounded[world.collision.indexOf(enemy)] = true;
    final navIndex = world.surfaceNav.indexOf(enemy);
    world.surfaceNav.activeEdgeIndex[navIndex] = 0;

    final graph = SurfaceGraph(
      surfaces: const <WalkSurface>[
        WalkSurface(id: 1, xMin: -1000.0, xMax: 1000.0, yTop: 100.0),
      ],
      edgeOffsets: const <int>[0, 1],
      edges: const <SurfaceEdge>[
        SurfaceEdge(
          to: 0,
          kind: SurfaceEdgeKind.jump,
          takeoffX: startX,
          landingX: landingX,
          commitDirX: 1,
          travelTicks: travelTicks,
          cost: 1.0,
        ),
      ],
      indexById: const <int, int>{1: 0},
    );

    final locomotionSystem = GroundEnemyLocomotionSystem(
      groundEnemyTuning: derived,
    );
    locomotionSystem.setSurfaceGraph(graph: graph);
    locomotionSystem.step(
      world,
      player: player,
      dtSeconds: dtSeconds,
      currentTick: 0,
    );

    final enemyTi = world.transform.indexOf(enemy);
    final velX = world.transform.velX[enemyTi];
    final requiredAbs = (landingX - startX).abs() / (travelTicks * dtSeconds);

    expect(velX.abs(), greaterThanOrEqualTo(requiredAbs - 1e-6));
    expect(velX, greaterThan(0.0));
  });

  test(
    'jump snap sign follows active jump edge direction when desiredX is behind',
    () {
      const dtSeconds = 1.0 / 60.0;
      const travelTicks = 30;
      const locomotionBase = GroundEnemyLocomotionTuning(
        speedX: 300.0,
        stopDistanceX: 1.0,
        accelX: 60.0,
        decelX: 60.0,
        jumpSpeed: 500.0,
      );
      final derived = GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(locomotion: locomotionBase),
        tickHz: 60,
      );

      final world = EcsWorld();
      final player = world.createEntity();
      world.transform.add(player, posX: 0.0, posY: 0.0, velX: 0.0, velY: 0.0);

      // Start already to the right of landingX to force desiredX-behind.
      const startX = 200.0;
      const landingX = 160.0;
      final enemy = EntityFactory(world).createEnemy(
        enemyId: EnemyId.grojib,
        posX: startX,
        posY: 92.0,
        velX: 0.0,
        velY: 0.0,
        facing: Facing.right,
        body: const BodyDef(
          isKinematic: false,
          useGravity: true,
          gravityScale: 1.0,
          maxVelY: 9999,
        ),
        collider: const ColliderAabbDef(halfX: 8.0, halfY: 8.0),
        health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 0,
          staminaMax: 0,
          regenPerSecond100: 0,
        ),
      );

      final navIntentIndex = world.navIntent.indexOf(enemy);
      world.navIntent.hasPlan[navIntentIndex] = true;
      world.navIntent.jumpNow[navIntentIndex] = true;
      world.navIntent.desiredX[navIntentIndex] = landingX; // behind entity
      world.navIntent.commitMoveDirX[navIntentIndex] =
          0; // simulate missing intent commit
      world.navIntent.hasSafeSurface[navIntentIndex] = false;

      final engagementIndex = world.engagementIntent.indexOf(enemy);
      world.engagementIntent.desiredTargetX[engagementIndex] = landingX;
      world.engagementIntent.arrivalSlowRadiusX[engagementIndex] = 0.0;
      world.engagementIntent.stateSpeedMul[engagementIndex] = 1.0;
      world.engagementIntent.speedScale[engagementIndex] = 1.0;

      world.collision.grounded[world.collision.indexOf(enemy)] = true;
      final navIndex = world.surfaceNav.indexOf(enemy);
      world.surfaceNav.activeEdgeIndex[navIndex] = 0;

      final graph = SurfaceGraph(
        surfaces: const <WalkSurface>[
          WalkSurface(id: 1, xMin: -1000.0, xMax: 1000.0, yTop: 100.0),
        ],
        edgeOffsets: const <int>[0, 1],
        edges: const <SurfaceEdge>[
          SurfaceEdge(
            to: 0,
            kind: SurfaceEdgeKind.jump,
            takeoffX: 100.0,
            landingX: landingX,
            commitDirX: 1, // authoritative jump direction
            travelTicks: travelTicks,
            cost: 1.0,
          ),
        ],
        indexById: const <int, int>{1: 0},
      );

      final locomotionSystem = GroundEnemyLocomotionSystem(
        groundEnemyTuning: derived,
      );
      locomotionSystem.setSurfaceGraph(graph: graph);
      locomotionSystem.step(
        world,
        player: player,
        dtSeconds: dtSeconds,
        currentTick: 0,
      );

      final enemyTi = world.transform.indexOf(enemy);
      expect(world.transform.velX[enemyTi], greaterThan(0.0));
      expect(world.transform.velY[enemyTi], equals(-locomotionBase.jumpSpeed));
    },
  );

  test(
    'jumpNow without plan still forces forward takeoff from facing direction',
    () {
      const dtSeconds = 1.0 / 60.0;
      const locomotionBase = GroundEnemyLocomotionTuning(
        speedX: 300.0,
        stopDistanceX: 6.0,
        accelX: 60.0,
        decelX: 60.0,
        jumpSpeed: 500.0,
      );
      final derived = GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(locomotion: locomotionBase),
        tickHz: 60,
      );

      for (final scenario in <({Facing facing, int dir})>[
        (facing: Facing.right, dir: 1),
        (facing: Facing.left, dir: -1),
      ]) {
        final world = EcsWorld();
        final player = world.createEntity();
        world.transform.add(player, posX: 0.0, posY: 0.0, velX: 0.0, velY: 0.0);

        final enemy = EntityFactory(world).createEnemy(
          enemyId: EnemyId.grojib,
          posX: 100.0,
          posY: 92.0,
          velX: 0.0,
          velY: 0.0,
          facing: scenario.facing,
          body: const BodyDef(
            isKinematic: false,
            useGravity: true,
            gravityScale: 1.0,
            maxVelY: 9999,
          ),
          collider: const ColliderAabbDef(halfX: 8.0, halfY: 8.0),
          health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
          mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
          stamina: const StaminaDef(
            stamina: 0,
            staminaMax: 0,
            regenPerSecond100: 0,
          ),
        );

        final navIntentIndex = world.navIntent.indexOf(enemy);
        world.navIntent.hasPlan[navIntentIndex] = false;
        world.navIntent.jumpNow[navIntentIndex] = true;
        world.navIntent.desiredX[navIntentIndex] = 100.0; // no chase delta
        world.navIntent.commitMoveDirX[navIntentIndex] = 0;
        world.navIntent.hasSafeSurface[navIntentIndex] = false;

        final engagementIndex = world.engagementIntent.indexOf(enemy);
        world.engagementIntent.desiredTargetX[engagementIndex] = 100.0;
        world.engagementIntent.arrivalSlowRadiusX[engagementIndex] = 12.0;
        world.engagementIntent.stateSpeedMul[engagementIndex] = 1.0;
        world.engagementIntent.speedScale[engagementIndex] = 1.0;

        world.collision.grounded[world.collision.indexOf(enemy)] = true;

        final locomotionSystem = GroundEnemyLocomotionSystem(
          groundEnemyTuning: derived,
        );
        locomotionSystem.step(
          world,
          player: player,
          dtSeconds: dtSeconds,
          currentTick: 0,
        );

        final enemyTi = world.transform.indexOf(enemy);
        final velX = world.transform.velX[enemyTi];
        final velY = world.transform.velY[enemyTi];

        expect(velX.abs(), greaterThanOrEqualTo(locomotionBase.speedX - 1e-6));
        expect(velX * scenario.dir, greaterThan(0.0));
        expect(velY, equals(-locomotionBase.jumpSpeed));
      }
    },
  );
}
