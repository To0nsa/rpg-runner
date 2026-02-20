import 'package:rpg_runner/core/ecs/entity_id.dart';

import '../../navigation/types/surface_graph.dart';
import '../../snapshots/enums.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../../util/double_math.dart';
import '../../util/velocity_math.dart';
import '../stores/enemies/melee_engagement_store.dart';
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
    required int currentTick,
  }) {
    if (dtSeconds <= 0.0) return;
    if (!world.transform.has(player)) return;

    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];

    final navIntent = world.navIntent;
    for (var i = 0; i < navIntent.denseEntities.length; i += 1) {
      final enemy = navIntent.denseEntities[i];
      if (world.deathState.has(enemy)) continue;
      final enemyTi = world.transform.tryIndexOf(enemy);
      if (enemyTi == null) continue;

      if (world.controlLock.isStunned(enemy, currentTick)) {
        world.transform.velX[enemyTi] = 0.0;
        // Keep velY for falling
        continue;
      }

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

      final meleeIndex = world.meleeEngagement.tryIndexOf(enemy);
      if (meleeIndex == null) {
        assert(
          false,
          'GroundEnemyLocomotionSystem requires MeleeEngagementStore on ground enemies; add it at spawn time.',
        );
        continue;
      }
      final meleeState = world.meleeEngagement.state[meleeIndex];
      final lockFacingToPlayer =
          meleeState == MeleeEngagementState.engage ||
          meleeState == MeleeEngagementState.strike ||
          meleeState == MeleeEngagementState.recover;

      final ex = world.transform.posX[enemyTi];
      _applyGroundEnemyLocomotion(
        world,
        enemyIndex: enemyIndex,
        enemyTi: enemyTi,
        navIndex: navIndex,
        navIntentIndex: i,
        engagementIndex: engagementIndex,
        lockFacingToPlayer: lockFacingToPlayer,
        ex: ex,
        playerX: playerX,
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
    required bool lockFacingToPlayer,
    required double ex,
    required double playerX,
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

    final hasPlan = navIntent.hasPlan[navIntentIndex];
    final effectiveSpeedScale = hasPlan
        ? 1.0
        : engagementIntent.speedScale[engagementIndex];
    // Traversal plans (especially jump edges) should not inherit melee
    // approach/strike slowdown multipliers, or enemies can under-speed jumps
    // and appear to "jump in place" on ledges.
    final arrivalSlowRadiusX = hasPlan
        ? 0.0
        : engagementIntent.arrivalSlowRadiusX[engagementIndex];
    final stateSpeedMul = hasPlan
        ? 1.0
        : engagementIntent.stateSpeedMul[engagementIndex];

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
      lockFacingToPlayer: lockFacingToPlayer,
      dtSeconds: dtSeconds,
      graph: _surfaceGraph,
      playerX: playerX,
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
    required bool lockFacingToPlayer,
    required double dtSeconds,
    required SurfaceGraph? graph,
    required double playerX,
  }) {
    final tuning = groundEnemyTuning;
    final enemy = world.enemy.denseEntities[enemyIndex];
    final enemyCi = world.collision.tryIndexOf(enemy);
    final grounded = enemyCi != null && world.collision.grounded[enemyCi];
    final activeJumpEdge = _activeJumpEdge(
      world,
      navIndex: navIndex,
      graph: graph,
    );
    final modIndex = world.statModifier.tryIndexOf(enemy);
    final moveSpeedMul = modIndex == null
        ? 1.0
        : world.statModifier.moveSpeedMul[modIndex];
    final dx = desiredX - ex;
    double arrivalScale = 1.0;
    if (arrivalSlowRadiusX > 0.0) {
      arrivalScale = clampDouble(dx.abs() / arrivalSlowRadiusX, 0.0, 1.0);
    }
    final baseSpeed =
        tuning.locomotion.speedX *
        effectiveSpeedScale *
        stateSpeedMul *
        moveSpeedMul;
    final currentVelX = world.transform.velX[enemyTi];
    final lockAirborneJumpVelX = hasPlan && !grounded && activeJumpEdge != null;
    final activeJumpEdgeDirX = _resolveEdgeCommitDirX(
      activeJumpEdge,
      referenceX: ex,
    );
    final activeJumpCruiseAbs = _edgeCruiseAbsSpeed(
      edge: activeJumpEdge,
      dtSeconds: dtSeconds,
      maxSpeedAbs: baseSpeed,
    );
    double desiredVelX = 0.0;
    int desiredDirX = 0;
    double? forcedAirborneVelX;
    final facingDirX = world.enemy.facing[enemyIndex] == Facing.right ? 1 : -1;
    final jumpDirX = _resolveJumpForwardDirX(
      commitMoveDirX: commitMoveDirX,
      jumpNow: jumpNow,
      activeJumpEdge: activeJumpEdge,
      facingDirX: facingDirX,
    );

    if (lockAirborneJumpVelX) {
      const edgeOffCourseVelEps = 1.0;
      final offCourse =
          activeJumpEdgeDirX != 0 &&
          (currentVelX * activeJumpEdgeDirX.toDouble()) <= edgeOffCourseVelEps;
      if (offCourse && activeJumpCruiseAbs > 0.0) {
        desiredDirX = activeJumpEdgeDirX;
        desiredVelX = desiredDirX.toDouble() * activeJumpCruiseAbs;
        // Recover from wall-induced zero/flip velocity while executing a jump
        // edge so traversal doesn't devolve into vertical hopping in place.
        forcedAirborneVelX = desiredVelX;
      } else {
        desiredVelX = currentVelX;
        if (currentVelX.abs() > 1e-6) {
          desiredDirX = currentVelX > 0.0 ? 1 : -1;
        }
      }
    } else if (commitMoveDirX != 0) {
      desiredDirX = commitMoveDirX;
      desiredVelX = desiredDirX.toDouble() * baseSpeed;
    } else if (dx.abs() > tuning.locomotion.stopDistanceX) {
      desiredDirX = dx >= 0 ? 1 : -1;
      desiredVelX = desiredDirX.toDouble() * baseSpeed * arrivalScale;
    }

    if (jumpNow && jumpDirX != 0 && !hasPlan) {
      desiredDirX = jumpDirX;
      // Avoid takeoff slowdowns that can produce "jump in place" behavior.
      if (desiredVelX.abs() < baseSpeed) {
        desiredVelX = jumpDirX.toDouble() * baseSpeed;
      }
    }

    if (jumpNow) {
      world.transform.velY[enemyTi] = -tuning.locomotion.jumpSpeed;
    }

    final nextVelX = applyAccelDecel(
      current: currentVelX,
      desired: desiredVelX,
      dtSeconds: dtSeconds,
      accelPerSecond: tuning.locomotion.accelX,
      decelPerSecond: tuning.locomotion.decelX,
    );

    double? jumpSnapVelX;
    if (hasPlan &&
        jumpNow &&
        activeJumpEdge != null &&
        activeJumpEdge.travelTicks > 0) {
      final edge = activeJumpEdge;
      final travelSeconds = edge.travelTicks * dtSeconds;
      if (travelSeconds > 0.0) {
        final dxAbs = (edge.landingX - ex).abs();
        final requiredAbs = dxAbs / travelSeconds;
        final snapAbs = clampDouble(requiredAbs, 0.0, baseSpeed);
        if (snapAbs > 0.0) {
          final sign = edge.commitDirX != 0
              ? edge.commitDirX.toDouble()
              : (desiredVelX > 0.0
                    ? 1.0
                    : (desiredVelX < 0.0
                          ? -1.0
                          : (edge.landingX >= ex ? 1.0 : -1.0)));
          jumpSnapVelX = sign * snapAbs;
        }
      }
    }

    if (jumpNow && jumpDirX != 0 && !hasPlan) {
      final candidateVelX = jumpSnapVelX ?? nextVelX;
      if (candidateVelX.abs() < baseSpeed) {
        jumpSnapVelX = jumpDirX.toDouble() * baseSpeed;
      }
    }

    final resolvedVelX = jumpSnapVelX ?? forcedAirborneVelX ?? nextVelX;

    world.transform.velX[enemyTi] = resolvedVelX;

    if (commitMoveDirX != 0) {
      world.enemy.facing[enemyIndex] = commitMoveDirX > 0
          ? Facing.right
          : Facing.left;
    } else {
      if (grounded) {
        if (desiredDirX != 0) {
          world.enemy.facing[enemyIndex] = desiredDirX > 0
              ? Facing.right
              : Facing.left;
        }
      } else {
        const airFacingVelDeadzone = 1.0;
        final vx = world.transform.velX[enemyTi];
        if (vx.abs() > airFacingVelDeadzone) {
          world.enemy.facing[enemyIndex] = vx > 0 ? Facing.right : Facing.left;
        }
      }
    }

    if (!hasPlan && hasSafeSurface) {
      final stopDist = tuning.locomotion.stopDistanceX;
      final nextVelX = world.transform.velX[enemyTi];
      if (nextVelX > 0.0 && ex >= safeSurfaceMaxX - stopDist) {
        world.transform.velX[enemyTi] = 0.0;
      } else if (nextVelX < 0.0 && ex <= safeSurfaceMinX + stopDist) {
        world.transform.velX[enemyTi] = 0.0;
      }
    }

    if (lockFacingToPlayer) {
      final dxToPlayer = playerX - ex;
      if (dxToPlayer.abs() > 1e-6) {
        world.enemy.facing[enemyIndex] = dxToPlayer >= 0
            ? Facing.right
            : Facing.left;
      }
    }
  }

  int _resolveJumpForwardDirX({
    required int commitMoveDirX,
    required bool jumpNow,
    required SurfaceEdge? activeJumpEdge,
    required int facingDirX,
  }) {
    if (!jumpNow) return 0;
    if (commitMoveDirX != 0) return commitMoveDirX;
    if (activeJumpEdge != null && activeJumpEdge.commitDirX != 0) {
      return activeJumpEdge.commitDirX;
    }
    return facingDirX;
  }

  SurfaceEdge? _activeJumpEdge(
    EcsWorld world, {
    required int navIndex,
    required SurfaceGraph? graph,
  }) {
    if (graph == null) return null;
    final activeEdgeIndex = world.surfaceNav.activeEdgeIndex[navIndex];
    if (activeEdgeIndex < 0 || activeEdgeIndex >= graph.edges.length) {
      return null;
    }
    final edge = graph.edges[activeEdgeIndex];
    return edge.kind == SurfaceEdgeKind.jump ? edge : null;
  }

  int _resolveEdgeCommitDirX(SurfaceEdge? edge, {required double referenceX}) {
    if (edge == null) return 0;
    if (edge.commitDirX != 0) return edge.commitDirX;
    if (edge.landingX > referenceX) return 1;
    if (edge.landingX < referenceX) return -1;
    return 0;
  }

  double _edgeCruiseAbsSpeed({
    required SurfaceEdge? edge,
    required double dtSeconds,
    required double maxSpeedAbs,
  }) {
    if (edge == null || edge.travelTicks <= 0 || dtSeconds <= 0.0) return 0.0;
    final travelSeconds = edge.travelTicks * dtSeconds;
    if (travelSeconds <= 0.0) return 0.0;
    final edgeDxAbs = (edge.landingX - edge.takeoffX).abs();
    final requiredAbs = edgeDxAbs / travelSeconds;
    return clampDouble(requiredAbs, 0.0, maxSpeedAbs);
  }
}
