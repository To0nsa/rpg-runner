import 'dart:math';

import 'package:rpg_runner/core/ecs/entity_id.dart';

import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../../tuning/flying_enemy_tuning.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../../util/deterministic_rng.dart';
import '../../util/double_math.dart';
import '../../util/velocity_math.dart';
import '../../navigation/types/surface_graph.dart';
import '../world.dart';

/// Applies movement for enemies based on navigation and engagement intents.
class EnemyLocomotionSystem {
  EnemyLocomotionSystem({
    required this.unocoDemonTuning,
    required this.groundEnemyTuning,
  });

  final UnocoDemonTuningDerived unocoDemonTuning;
  final GroundEnemyTuningDerived groundEnemyTuning;

  SurfaceGraph? _surfaceGraph;

  void setSurfaceGraph({required SurfaceGraph graph}) {
    _surfaceGraph = graph;
  }

  /// Applies locomotion for all enemies.
  void step(
    EcsWorld world, {
    required EntityId player,
    required double groundTopY,
    required double dtSeconds,
  }) {
    if (!world.transform.has(player)) return;

    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];
    final playerY = world.transform.posY[playerTi];

    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final enemy = enemies.denseEntities[ei];
      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];

      switch (enemies.enemyId[ei]) {
        case EnemyId.unocoDemon:
          _steerFlyingEnemy(
            world,
            enemyIndex: ei,
            enemy: enemy,
            enemyTi: ti,
            playerX: playerX,
            playerY: playerY,
            ex: ex,
            ey: ey,
            groundTopY: groundTopY,
            dtSeconds: dtSeconds,
          );
        case EnemyId.groundEnemy:
          _applyGroundEnemyLocomotion(
            world,
            enemyIndex: ei,
            enemy: enemy,
            enemyTi: ti,
            ex: ex,
            dtSeconds: dtSeconds,
          );
      }
    }
  }

  void _applyGroundEnemyLocomotion(
    EcsWorld world, {
    required int enemyIndex,
    required EntityId enemy,
    required int enemyTi,
    required double ex,
    required double dtSeconds,
  }) {
    if (dtSeconds <= 0.0) return;

    final navIndex = world.surfaceNav.tryIndexOf(enemy);
    if (navIndex == null) return;

    final navIntentIndex = world.navIntent.tryIndexOf(enemy);
    if (navIntentIndex == null) {
      assert(
        false,
        'EnemyLocomotionSystem requires NavIntentStore on ground enemies; add it at spawn time.',
      );
      return;
    }

    final engagementIndex = world.engagementIntent.tryIndexOf(enemy);
    if (engagementIndex == null) {
      assert(
        false,
        'EnemyLocomotionSystem requires EngagementIntentStore on ground enemies; add it at spawn time.',
      );
      return;
    }

    final navIntent = world.navIntent;
    final engagementIntent = world.engagementIntent;

    var desiredX = navIntent.desiredX[navIntentIndex];
    if (!navIntent.hasPlan[navIntentIndex]) {
      desiredX = engagementIntent.desiredTargetX[engagementIndex];
      if (navIntent.hasSafeSurface[navIntentIndex]) {
        final minX = navIntent.safeSurfaceMinX[navIntentIndex];
        final maxX = navIntent.safeSurfaceMaxX[navIntentIndex];
        if (minX <= maxX) {
          desiredX = clampDouble(desiredX, minX, maxX);
        }
      }
    }

    final effectiveSpeedScale = navIntent.hasPlan[navIntentIndex]
        ? 1.0
        : engagementIntent.speedScale[engagementIndex];
    final arrivalSlowRadiusX =
        engagementIntent.arrivalSlowRadiusX[engagementIndex];
    final stateSpeedMul = engagementIntent.stateSpeedMul[engagementIndex];

    _applyGroundEnemyPhysics(
      world,
      enemyIndex: enemyIndex,
      enemyTi: enemyTi,
      ex: ex,
      desiredX: desiredX,
      jumpNow: navIntent.jumpNow[navIntentIndex],
      hasPlan: navIntent.hasPlan[navIntentIndex],
      commitMoveDirX: navIntent.commitMoveDirX[navIntentIndex],
      hasSafeSurface: navIntent.hasSafeSurface[navIntentIndex],
      safeSurfaceMinX: navIntent.safeSurfaceMinX[navIntentIndex],
      safeSurfaceMaxX: navIntent.safeSurfaceMaxX[navIntentIndex],
      effectiveSpeedScale: effectiveSpeedScale,
      arrivalSlowRadiusX: arrivalSlowRadiusX,
      stateSpeedMul: stateSpeedMul,
      dtSeconds: dtSeconds,
      navIndex: navIndex,
      graph: _surfaceGraph,
    );
  }

  void _applyGroundEnemyPhysics(
    EcsWorld world, {
    required int enemyIndex,
    required int enemyTi,
    required double ex,
    required double desiredX,
    required bool jumpNow,
    required bool hasPlan,
    required int commitMoveDirX,
    required bool hasSafeSurface,
    required double safeSurfaceMinX,
    required double safeSurfaceMaxX,
    required double effectiveSpeedScale,
    required double arrivalSlowRadiusX,
    required double stateSpeedMul,
    required double dtSeconds,
    required int navIndex,
    required SurfaceGraph? graph,
  }) {
    final tuning = groundEnemyTuning;
    final enemy = world.enemy.denseEntities[enemyIndex];
    final modIndex = world.statModifier.tryIndexOf(enemy);
    final moveSpeedMul = modIndex == null
        ? 1.0
        : world.statModifier.moveSpeedMul[modIndex];
    final dx = desiredX - ex;
    double arrivalScale = 1.0;
    if (arrivalSlowRadiusX > 0.0) {
      arrivalScale = clampDouble(dx.abs() / arrivalSlowRadiusX, 0.0, 1.0);
    }
    final baseSpeed = tuning.locomotion.speedX *
        effectiveSpeedScale *
        stateSpeedMul *
        moveSpeedMul;
    double desiredVelX = 0.0;

    if (commitMoveDirX != 0) {
      final dirX = commitMoveDirX.toDouble();
      world.enemy.facing[enemyIndex] = dirX > 0 ? Facing.right : Facing.left;
      desiredVelX = dirX * baseSpeed;
    } else if (dx.abs() > tuning.locomotion.stopDistanceX) {
      final dirX = dx >= 0 ? 1.0 : -1.0;
      world.enemy.facing[enemyIndex] = dirX > 0 ? Facing.right : Facing.left;
      desiredVelX = dirX * baseSpeed * arrivalScale;
    }

    if (jumpNow) {
      world.transform.velY[enemyTi] = -tuning.locomotion.jumpSpeed;
    }

    final currentVelX = world.transform.velX[enemyTi];
    final nextVelX = applyAccelDecel(
      current: currentVelX,
      desired: desiredVelX,
      dtSeconds: dtSeconds,
      accelPerSecond: tuning.locomotion.accelX,
      decelPerSecond: tuning.locomotion.decelX,
    );

    double? jumpSnapVelX;
    if (hasPlan && jumpNow && graph != null) {
      final activeEdgeIndex = world.surfaceNav.activeEdgeIndex[navIndex];
      if (activeEdgeIndex >= 0 && activeEdgeIndex < graph.edges.length) {
        final edge = graph.edges[activeEdgeIndex];
        if (edge.kind == SurfaceEdgeKind.jump && edge.travelTicks > 0) {
          final travelSeconds = edge.travelTicks * dtSeconds;
          if (travelSeconds > 0.0) {
            final dxAbs = (edge.landingX - ex).abs();
            final requiredAbs = dxAbs / travelSeconds;
            final desiredAbs = desiredVelX.abs();
            final currentAbs = currentVelX.abs();
            final snapAbs = min(desiredAbs, max(currentAbs, requiredAbs));
            if (snapAbs > nextVelX.abs()) {
              final sign = desiredVelX >= 0.0 ? 1.0 : -1.0;
              jumpSnapVelX = sign * snapAbs;
            }
          }
        }
      }
    }

    world.transform.velX[enemyTi] = jumpSnapVelX ?? nextVelX;

    if (!hasPlan && hasSafeSurface) {
      final stopDist = tuning.locomotion.stopDistanceX;
      final nextVelX = world.transform.velX[enemyTi];
      if (nextVelX > 0.0 && ex >= safeSurfaceMaxX - stopDist) {
        world.transform.velX[enemyTi] = 0.0;
      } else if (nextVelX < 0.0 && ex <= safeSurfaceMinX + stopDist) {
        world.transform.velX[enemyTi] = 0.0;
      }
    }
  }

  void _steerFlyingEnemy(
    EcsWorld world, {
    required int enemyIndex,
    required EntityId enemy,
    required int enemyTi,
    required double playerX,
    required double playerY,
    required double ex,
    required double ey,
    required double groundTopY,
    required double dtSeconds,
  }) {
    if (dtSeconds <= 0.0) return;
    final tuning = unocoDemonTuning;

    if (!world.flyingEnemySteering.has(enemy)) {
      assert(
        false,
        'EnemyLocomotionSystem requires FlyingEnemySteeringStore on flying enemies; add it at spawn time.',
      );
      return;
    }

    final steering = world.flyingEnemySteering;
    final si = steering.indexOf(enemy);
    final modIndex = world.statModifier.tryIndexOf(enemy);
    final moveSpeedMul = modIndex == null
        ? 1.0
        : world.statModifier.moveSpeedMul[modIndex];

    var rngState = steering.rngState[si];
    double nextRange(double min, double max) {
      rngState = nextUint32(rngState);
      return rangeDouble(rngState, min, max);
    }

    if (!steering.initialized[si]) {
      steering.initialized[si] = true;
      steering.desiredRangeHoldLeftS[si] = nextRange(
        tuning.base.unocoDemonDesiredRangeHoldMinSeconds,
        tuning.base.unocoDemonDesiredRangeHoldMaxSeconds,
      );
      steering.desiredRange[si] = nextRange(
        tuning.base.unocoDemonDesiredRangeMin,
        tuning.base.unocoDemonDesiredRangeMax,
      );
      steering.flightTargetHoldLeftS[si] = 0.0;
      steering.flightTargetAboveGround[si] = nextRange(
        tuning.base.unocoDemonMinHeightAboveGround,
        tuning.base.unocoDemonMaxHeightAboveGround,
      );
    }

    var desiredRangeHoldLeftS = steering.desiredRangeHoldLeftS[si];
    var desiredRange = steering.desiredRange[si];

    if (desiredRangeHoldLeftS > 0.0) {
      desiredRangeHoldLeftS -= dtSeconds;
    } else {
      desiredRangeHoldLeftS = nextRange(
        tuning.base.unocoDemonDesiredRangeHoldMinSeconds,
        tuning.base.unocoDemonDesiredRangeHoldMaxSeconds,
      );
      desiredRange = nextRange(
        tuning.base.unocoDemonDesiredRangeMin,
        tuning.base.unocoDemonDesiredRangeMax,
      );
    }

    final dx = playerX - ex;
    final distX = dx.abs();
    if (distX > 1e-6) {
      world.enemy.facing[enemyIndex] = dx >= 0 ? Facing.right : Facing.left;
    }

    final slack = tuning.base.unocoDemonHoldSlack;
    double desiredVelX = 0.0;
    if (distX > 1e-6) {
      final dirToPlayerX = dx >= 0 ? 1.0 : -1.0;
      final error = distX - desiredRange;

      if (error.abs() > slack) {
        final slowRadiusX = tuning.base.unocoDemonSlowRadiusX;
        final t = slowRadiusX > 0.0
            ? clampDouble((error.abs() - slack) / slowRadiusX, 0.0, 1.0)
            : 1.0;
        final speed = t * tuning.base.unocoDemonMaxSpeedX;
        desiredVelX = (error > 0.0 ? dirToPlayerX : -dirToPlayerX) * speed;
      }
    }

    var flightTargetHoldLeftS = steering.flightTargetHoldLeftS[si];
    var flightTargetAboveGround = steering.flightTargetAboveGround[si];
    if (flightTargetHoldLeftS > 0.0) {
      flightTargetHoldLeftS -= dtSeconds;
    } else {
      flightTargetHoldLeftS = nextRange(
        tuning.base.unocoDemonFlightTargetHoldMinSeconds,
        tuning.base.unocoDemonFlightTargetHoldMaxSeconds,
      );
      flightTargetAboveGround = nextRange(
        tuning.base.unocoDemonMinHeightAboveGround,
        tuning.base.unocoDemonMaxHeightAboveGround,
      );
    }

    final targetY = groundTopY - flightTargetAboveGround;
    final deltaY = targetY - ey;
    double desiredVelY = clampDouble(
      deltaY * tuning.base.unocoDemonVerticalKp,
      -tuning.base.unocoDemonMaxSpeedY,
      tuning.base.unocoDemonMaxSpeedY,
    );
    if (deltaY.abs() <= tuning.base.unocoDemonVerticalDeadzone) {
      desiredVelY = 0.0;
    }

    desiredVelX *= moveSpeedMul;
    desiredVelY *= moveSpeedMul;
    final currentVelX = world.transform.velX[enemyTi];
    world.transform.velX[enemyTi] = applyAccelDecel(
      current: currentVelX,
      desired: desiredVelX,
      dtSeconds: dtSeconds,
      accelPerSecond: tuning.base.unocoDemonAccelX,
      decelPerSecond: tuning.base.unocoDemonDecelX,
    );
    world.transform.velY[enemyTi] = desiredVelY;

    steering.desiredRangeHoldLeftS[si] = desiredRangeHoldLeftS;
    steering.desiredRange[si] = desiredRange;
    steering.flightTargetHoldLeftS[si] = flightTargetHoldLeftS;
    steering.flightTargetAboveGround[si] = flightTargetAboveGround;
    steering.rngState[si] = rngState;
  }
}
