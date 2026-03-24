import 'package:runner_core/ecs/entity_id.dart';

import '../../snapshots/enums.dart';
import '../../tuning/flying_enemy_tuning.dart';
import '../../util/deterministic_rng.dart';
import '../../util/double_math.dart';
import '../../util/velocity_math.dart';
import '../collider_aabb_utils.dart';
import '../stores/enemies/flying_enemy_combat_mode_store.dart';
import '../world.dart';

/// Applies movement for flying enemies based on steering behaviors.
class FlyingEnemyLocomotionSystem {
  FlyingEnemyLocomotionSystem({required this.unocoDemonTuning});

  final UnocoDemonTuningDerived unocoDemonTuning;

  /// Applies locomotion for all flying enemies.
  void step(
    EcsWorld world, {
    required EntityId player,
    required double groundTopY,
    required double dtSeconds,
    required int currentTick,
  }) {
    if (dtSeconds <= 0.0) return;
    if (!world.transform.has(player)) return;

    final playerTi = world.transform.indexOf(player);
    var playerCenterX = world.transform.posX[playerTi];
    var playerCenterY = world.transform.posY[playerTi];
    if (world.colliderAabb.has(player)) {
      final playerAi = world.colliderAabb.indexOf(player);
      playerCenterX = colliderCenterX(
        world,
        entity: player,
        transformIndex: playerTi,
        colliderIndex: playerAi,
      );
      playerCenterY += world.colliderAabb.offsetY[playerAi];
    }

    final steering = world.flyingEnemySteering;
    for (var i = 0; i < steering.denseEntities.length; i += 1) {
      final enemy = steering.denseEntities[i];
      if (world.deathState.has(enemy)) continue;
      final enemyTi = world.transform.tryIndexOf(enemy);
      if (enemyTi == null) continue;

      if (world.controlLock.isStunned(enemy, currentTick)) {
        // Option B: Freeze in place.
        world.transform.velX[enemyTi] = 0.0;
        world.transform.velY[enemyTi] = 0.0;
        continue;
      }

      final enemyIndex = world.enemy.tryIndexOf(enemy);
      if (enemyIndex == null) {
        assert(
          false,
          'FlyingEnemyLocomotionSystem requires EnemyStore on flying enemies; add it at spawn time.',
        );
        continue;
      }

      final ex = world.transform.posX[enemyTi];
      final ey = world.transform.posY[enemyTi];
      _steerFlyingEnemy(
        world,
        enemyIndex: enemyIndex,
        enemy: enemy,
        enemyTi: enemyTi,
        steeringIndex: i,
        playerCenterX: playerCenterX,
        playerCenterY: playerCenterY,
        ex: ex,
        ey: ey,
        groundTopY: groundTopY,
        dtSeconds: dtSeconds,
      );
    }
  }

  void _steerFlyingEnemy(
    EcsWorld world, {
    required int enemyIndex,
    required EntityId enemy,
    required int enemyTi,
    required int steeringIndex,
    required double playerCenterX,
    required double playerCenterY,
    required double ex,
    required double ey,
    required double groundTopY,
    required double dtSeconds,
  }) {
    final tuning = unocoDemonTuning;
    final steering = world.flyingEnemySteering;

    final modIndex = world.statModifier.tryIndexOf(enemy);
    final moveSpeedMul = modIndex == null
        ? 1.0
        : world.statModifier.moveSpeedMul[modIndex];

    var rngState = steering.rngState[steeringIndex];
    double nextRange(double min, double max) {
      rngState = nextUint32(rngState);
      return rangeDouble(rngState, min, max);
    }

    if (!steering.initialized[steeringIndex]) {
      steering.initialized[steeringIndex] = true;
      steering.desiredRangeHoldLeftS[steeringIndex] = nextRange(
        tuning.base.unocoDemonDesiredRangeHoldMinSeconds,
        tuning.base.unocoDemonDesiredRangeHoldMaxSeconds,
      );
      steering.desiredRange[steeringIndex] = nextRange(
        tuning.base.unocoDemonDesiredRangeMin,
        tuning.base.unocoDemonDesiredRangeMax,
      );
      steering.flightTargetHoldLeftS[steeringIndex] = 0.0;
      steering.flightTargetAboveGround[steeringIndex] = nextRange(
        tuning.base.unocoDemonMinHeightAboveGround,
        tuning.base.unocoDemonMaxHeightAboveGround,
      );
    }

    var desiredRangeHoldLeftS = steering.desiredRangeHoldLeftS[steeringIndex];
    var desiredRange = steering.desiredRange[steeringIndex];

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

    final modeIndex = world.flyingEnemyCombatMode.tryIndexOf(enemy);
    if (modeIndex == null) {
      assert(
        false,
        'FlyingEnemyLocomotionSystem requires FlyingEnemyCombatModeStore on flying enemies; add it at spawn time.',
      );
      return;
    }
    if (world.flyingEnemyCombatMode.mode[modeIndex] ==
        FlyingEnemyCombatMode.meleeFallback) {
      desiredRange = _fallbackMeleeContactRange;
    }
    final locomotionMode =
        world.flyingEnemyCombatMode.mode[modeIndex] ==
            FlyingEnemyCombatMode.meleeFallback
        ? _FlyingLocomotionMode.approachStrike
        : _FlyingLocomotionMode.hover;

    final dx = playerCenterX - ex;
    final distX = dx.abs();
    if (distX > 1e-6) {
      world.enemy.facing[enemyIndex] = dx >= 0 ? Facing.right : Facing.left;
    }

    final slack = locomotionMode == _FlyingLocomotionMode.approachStrike
        ? _approachStrikeSlackX
        : tuning.base.unocoDemonHoldSlack;
    var desiredVelX = 0.0;
    if (distX > 1e-6) {
      final dirToPlayerX = dx >= 0 ? 1.0 : -1.0;
      final error = distX - desiredRange;

      if (error.abs() > slack) {
        final slowRadiusX =
            locomotionMode == _FlyingLocomotionMode.approachStrike
            ? 0.0
            : tuning.base.unocoDemonSlowRadiusX;
        final t = slowRadiusX > 0.0
            ? clampDouble((error.abs() - slack) / slowRadiusX, 0.0, 1.0)
            : 1.0;
        final speed = t * tuning.base.unocoDemonMaxSpeedX;
        desiredVelX = (error > 0.0 ? dirToPlayerX : -dirToPlayerX) * speed;
      }
    }

    var flightTargetHoldLeftS = steering.flightTargetHoldLeftS[steeringIndex];
    var flightTargetAboveGround =
        steering.flightTargetAboveGround[steeringIndex];
    late final double targetY;
    if (locomotionMode == _FlyingLocomotionMode.hover) {
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
      targetY = groundTopY - flightTargetAboveGround;
    } else {
      targetY = playerCenterY;
    }
    final deltaY = targetY - ey;
    var desiredVelY = clampDouble(
      deltaY * tuning.base.unocoDemonVerticalKp,
      -tuning.base.unocoDemonMaxSpeedY,
      tuning.base.unocoDemonMaxSpeedY,
    );
    final verticalDeadzone =
        locomotionMode == _FlyingLocomotionMode.approachStrike
        ? _approachStrikeDeadzoneY
        : tuning.base.unocoDemonVerticalDeadzone;
    if (deltaY.abs() <= verticalDeadzone) {
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

    steering.desiredRangeHoldLeftS[steeringIndex] = desiredRangeHoldLeftS;
    steering.desiredRange[steeringIndex] = desiredRange;
    steering.flightTargetHoldLeftS[steeringIndex] = flightTargetHoldLeftS;
    steering.flightTargetAboveGround[steeringIndex] = flightTargetAboveGround;
    steering.rngState[steeringIndex] = rngState;
  }

  static const double _fallbackMeleeContactRange = 0.0;
  static const double _approachStrikeSlackX = 0.0;
  static const double _approachStrikeDeadzoneY = 0.0;
}

enum _FlyingLocomotionMode { hover, approachStrike }
