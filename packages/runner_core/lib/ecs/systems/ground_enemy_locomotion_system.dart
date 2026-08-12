import 'package:runner_core/ecs/entity_id.dart';

import '../../combat/control_lock.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../snapshots/enums.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../../util/double_math.dart';
import '../../util/velocity_math.dart';
import '../stores/enemies/melee_engagement_store.dart';
import '../world.dart';
import '../world_support_view.dart';

/// Applies movement for ground enemies based on nav + engagement intents.
class GroundEnemyLocomotionSystem {
  GroundEnemyLocomotionSystem({required this.groundEnemyTuning});

  final GroundEnemyTuningDerived groundEnemyTuning;

  final _ActiveJumpTraversal _activeJumpScratch = _ActiveJumpTraversal();

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
    final supportView = WorldSupportView(world);

    final navIntent = world.navIntent;
    for (var i = 0; i < navIntent.denseEntities.length; i += 1) {
      final enemy = navIntent.denseEntities[i];
      if (world.deathState.has(enemy)) continue;
      final enemyTi = world.transform.tryIndexOf(enemy);
      if (enemyTi == null) continue;

      final grounded = supportView.isGrounded(enemy);
      if (world.controlLock.isStunned(enemy, currentTick) ||
          world.controlLock.isLocked(enemy, LockFlag.move, currentTick)) {
        world.transform.velX[enemyTi] = 0.0;
        if (grounded && world.terrainContact.has(enemy)) {
          world.transform.velY[enemyTi] = 0.0;
        }
        _writeLocomotionReferenceSpeed(world, enemy, 0.0);
        // Keep velY for legacy and terrain-airborne falling.
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
        navIntentIndex: i,
        engagementIndex: engagementIndex,
        lockFacingToPlayer: lockFacingToPlayer,
        grounded: grounded,
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
    required int navIntentIndex,
    required int engagementIndex,
    required bool lockFacingToPlayer,
    required bool grounded,
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
      navIntentIndex: navIntentIndex,
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
      grounded: grounded,
      dtSeconds: dtSeconds,
      playerX: playerX,
    );
  }

  void _applyGroundEnemyPhysics(
    EcsWorld world, {
    required int enemyIndex,
    required int enemyTi,
    required int navIntentIndex,
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
    required bool grounded,
    required double dtSeconds,
    required double playerX,
  }) {
    final tuning = groundEnemyTuning;
    final enemy = world.enemy.denseEntities[enemyIndex];
    final terrainGrounded = grounded && world.terrainContact.has(enemy);
    final activeJumpTraversal = _activeJumpTraversal(
      world,
      navIntentIndex: navIntentIndex,
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
    final currentWorldVelX = world.transform.velX[enemyTi];
    final currentVelX = terrainGrounded
        ? _surfaceSpeedAlongWorldX(world, enemy, enemyTi)
        : currentWorldVelX;
    final lockAirborneJumpVelX =
        hasPlan && !grounded && activeJumpTraversal != null;
    final activeJumpEdgeDirX = _resolveEdgeCommitDirX(
      activeJumpTraversal,
      referenceX: ex,
    );
    final activeJumpCruiseAbs = _edgeCruiseAbsSpeed(
      edge: activeJumpTraversal,
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
      activeJumpEdge: activeJumpTraversal,
      facingDirX: facingDirX,
    );

    if (lockAirborneJumpVelX) {
      const edgeOffCourseVelEps = 1.0;
      final offCourse =
          activeJumpEdgeDirX != 0 &&
          (currentWorldVelX * activeJumpEdgeDirX.toDouble()) <=
              edgeOffCourseVelEps;
      if (offCourse && activeJumpCruiseAbs > 0.0) {
        desiredDirX = activeJumpEdgeDirX;
        desiredVelX = desiredDirX.toDouble() * activeJumpCruiseAbs;
        // Recover from wall-induced zero/flip velocity while executing a jump
        // edge so traversal doesn't devolve into vertical hopping in place.
        forcedAirborneVelX = desiredVelX;
      } else {
        desiredVelX = currentWorldVelX;
        if (currentWorldVelX.abs() > 1e-6) {
          desiredDirX = currentWorldVelX > 0.0 ? 1 : -1;
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
        activeJumpTraversal != null &&
        activeJumpTraversal.travelTicks > 0) {
      final edge = activeJumpTraversal;
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
    _writeLocomotionReferenceSpeed(world, enemy, desiredVelX.abs());

    if (jumpNow) {
      if (terrainGrounded) {
        world.terrainContact.clearSupport(enemy);
        final collisionIndex = world.collision.tryIndexOf(enemy);
        if (collisionIndex != null) {
          world.collision.grounded[collisionIndex] = false;
        }
      }
      // Jump edges retain their existing world-X snap/commit velocity and use
      // a world-up launch. Terrain projection resumes only after landing.
      world.transform.velX[enemyTi] = resolvedVelX;
      world.transform.velY[enemyTi] = -tuning.locomotion.jumpSpeed;
    } else if (terrainGrounded) {
      _writeSurfaceVelocity(world, enemy, enemyTi, resolvedVelX);
    } else {
      world.transform.velX[enemyTi] = resolvedVelX;
    }

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
        _stopLocomotion(world, enemy, enemyTi, terrainGrounded);
      } else if (nextVelX < 0.0 && ex <= safeSurfaceMinX + stopDist) {
        _stopLocomotion(world, enemy, enemyTi, terrainGrounded);
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

  double _surfaceSpeedAlongWorldX(
    EcsWorld world,
    EntityId enemy,
    int transformIndex,
  ) {
    final contactIndex = world.terrainContact.indexOf(enemy);
    final tangentX = world.terrainContact.supportTangentXTicks[contactIndex];
    final tangentY = world.terrainContact.supportTangentYTicks[contactIndex];
    if (tangentX == 0) return world.transform.velX[transformIndex];
    final positiveXSign = tangentX > 0 ? 1.0 : -1.0;
    return positiveXSign *
        (world.transform.velX[transformIndex] * tangentX +
            world.transform.velY[transformIndex] * tangentY) /
        terrainDirectionScale;
  }

  void _writeSurfaceVelocity(
    EcsWorld world,
    EntityId enemy,
    int transformIndex,
    double signedSurfaceSpeed,
  ) {
    final contactIndex = world.terrainContact.indexOf(enemy);
    final tangentX = world.terrainContact.supportTangentXTicks[contactIndex];
    final tangentY = world.terrainContact.supportTangentYTicks[contactIndex];
    if (tangentX == 0) {
      world.transform.velX[transformIndex] = signedSurfaceSpeed;
      return;
    }
    final positiveXSign = tangentX > 0 ? 1.0 : -1.0;
    final scale = signedSurfaceSpeed * positiveXSign / terrainDirectionScale;
    world.transform.velX[transformIndex] = tangentX * scale;
    world.transform.velY[transformIndex] = tangentY * scale;
  }

  void _stopLocomotion(
    EcsWorld world,
    EntityId enemy,
    int transformIndex,
    bool terrainGrounded,
  ) {
    world.transform.velX[transformIndex] = 0.0;
    if (terrainGrounded) world.transform.velY[transformIndex] = 0.0;
    _writeLocomotionReferenceSpeed(world, enemy, 0.0);
  }

  void _writeLocomotionReferenceSpeed(
    EcsWorld world,
    EntityId enemy,
    double speed,
  ) {
    if (!world.resolvedMotion.has(enemy)) return;
    world.resolvedMotion.setLocomotionReferenceSpeed(
      enemy,
      ticksPerSecond: physicsCoordinateToTicks(
        speed,
        name: 'enemyLocomotionReferenceSpeed',
      ),
    );
  }

  int _resolveJumpForwardDirX({
    required int commitMoveDirX,
    required bool jumpNow,
    required _ActiveJumpTraversal? activeJumpEdge,
    required int facingDirX,
  }) {
    if (!jumpNow) return 0;
    if (commitMoveDirX != 0) return commitMoveDirX;
    if (activeJumpEdge != null && activeJumpEdge.commitDirX != 0) {
      return activeJumpEdge.commitDirX;
    }
    return facingDirX;
  }

  _ActiveJumpTraversal? _activeJumpTraversal(
    EcsWorld world, {
    required int navIntentIndex,
  }) {
    final intents = world.navIntent;
    if (intents.hasActiveJumpTraversal[navIntentIndex]) {
      return _activeJumpScratch.set(
        takeoffX: intents.activeJumpTakeoffX[navIntentIndex],
        landingX: intents.activeJumpLandingX[navIntentIndex],
        commitDirX: intents.activeJumpCommitDirX[navIntentIndex],
        travelTicks: intents.activeJumpTravelTicks[navIntentIndex],
      );
    }
    return null;
  }

  int _resolveEdgeCommitDirX(
    _ActiveJumpTraversal? edge, {
    required double referenceX,
  }) {
    if (edge == null) return 0;
    if (edge.commitDirX != 0) return edge.commitDirX;
    if (edge.landingX > referenceX) return 1;
    if (edge.landingX < referenceX) return -1;
    return 0;
  }

  double _edgeCruiseAbsSpeed({
    required _ActiveJumpTraversal? edge,
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

final class _ActiveJumpTraversal {
  double takeoffX = 0;
  double landingX = 0;
  int commitDirX = 0;
  int travelTicks = 0;

  _ActiveJumpTraversal set({
    required double takeoffX,
    required double landingX,
    required int commitDirX,
    required int travelTicks,
  }) {
    this.takeoffX = takeoffX;
    this.landingX = landingX;
    this.commitDirX = commitDirX;
    this.travelTicks = travelTicks;
    return this;
  }
}
