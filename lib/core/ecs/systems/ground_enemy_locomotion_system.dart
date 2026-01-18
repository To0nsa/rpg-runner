import 'dart:math';

import 'package:rpg_runner/core/ecs/entity_id.dart';

import '../../navigation/types/surface_graph.dart';
import '../../snapshots/enums.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../../util/double_math.dart';
import '../../util/velocity_math.dart';
import '../world.dart';

/// Applies movement for ground enemies based on nav + engagement intents.
class GroundEnemyLocomotionSystem {
  GroundEnemyLocomotionSystem({required this.groundEnemyTuning});

  final GroundEnemyTuningDerived groundEnemyTuning;

  SurfaceGraph? _surfaceGraph;

  void setSurfaceGraph({required SurfaceGraph graph}) {
    _surfaceGraph = graph;
  }

  /// Applies locomotion for all ground enemies.
  void step(
    EcsWorld world, {
    required EntityId player,
    required double dtSeconds,
  }) {
    if (dtSeconds <= 0.0) return;
    if (!world.transform.has(player)) return;

    final navIntent = world.navIntent;
    for (var i = 0; i < navIntent.denseEntities.length; i += 1) {
      final enemy = navIntent.denseEntities[i];
      final enemyTi = world.transform.tryIndexOf(enemy);
      if (enemyTi == null) continue;

      final enemyIndex = world.enemy.tryIndexOf(enemy);
      if (enemyIndex == null) {
        assert(
          false,
          'GroundEnemyLocomotionSystem requires EnemyStore on ground enemies; add it at spawn time.',
        );
        continue;
      }

      final navIndex = world.surfaceNav.tryIndexOf(enemy);
      if (navIndex == null) {
        assert(
          false,
          'GroundEnemyLocomotionSystem requires SurfaceNavStateStore on ground enemies; add it at spawn time.',
        );
        continue;
      }

      final engagementIndex = world.engagementIntent.tryIndexOf(enemy);
      if (engagementIndex == null) {
        assert(
          false,
          'GroundEnemyLocomotionSystem requires EngagementIntentStore on ground enemies; add it at spawn time.',
        );
        continue;
      }

      final ex = world.transform.posX[enemyTi];
      _applyGroundEnemyLocomotion(
        world,
        enemyIndex: enemyIndex,
        enemyTi: enemyTi,
        navIndex: navIndex,
        navIntentIndex: i,
        engagementIndex: engagementIndex,
        ex: ex,
        dtSeconds: dtSeconds,
      );
    }
  }

  void _applyGroundEnemyLocomotion(
    EcsWorld world, {
    required int enemyIndex,
    required int enemyTi,
    required int navIndex,
    required int navIntentIndex,
    required int engagementIndex,
    required double ex,
    required double dtSeconds,
  }) {
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
      navIndex: navIndex,
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
      graph: _surfaceGraph,
    );
  }

  void _applyGroundEnemyPhysics(
    EcsWorld world, {
    required int enemyIndex,
    required int enemyTi,
    required int navIndex,
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
}
