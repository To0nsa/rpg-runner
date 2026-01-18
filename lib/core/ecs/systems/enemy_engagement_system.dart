import 'dart:math';

import 'package:rpg_runner/core/ecs/entity_id.dart';

import '../../enemies/enemy_id.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../../util/deterministic_rng.dart';
import '../../util/double_math.dart';
import '../stores/enemies/melee_engagement_store.dart';
import '../world.dart';

/// Resolves melee engagement state and desired slots for ground enemies.
class EnemyEngagementSystem {
  EnemyEngagementSystem({required this.groundEnemyTuning});

  final GroundEnemyTuningDerived groundEnemyTuning;

  /// Updates engagement intents for ground enemies.
  void step(
    EcsWorld world, {
    required EntityId player,
  }) {
    if (!world.transform.has(player)) return;

    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];

    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      if (enemies.enemyId[ei] != EnemyId.groundEnemy) continue;

      final enemy = enemies.denseEntities[ei];
      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

      final meleeIndex = world.meleeEngagement.tryIndexOf(enemy);
      if (meleeIndex == null) {
        assert(
          false,
          'EnemyEngagementSystem requires MeleeEngagementStore on melee enemies; add it at spawn time.',
        );
        continue;
      }

      final chaseIndex = world.groundEnemyChaseOffset.tryIndexOf(enemy);
      if (chaseIndex == null) continue;

      final navIntentIndex = world.navIntent.tryIndexOf(enemy);
      if (navIntentIndex == null) {
        assert(
          false,
          'EnemyEngagementSystem requires NavIntentStore on ground enemies; add it at spawn time.',
        );
        continue;
      }

      final engagementIndex = world.engagementIntent.tryIndexOf(enemy);
      if (engagementIndex == null) {
        assert(
          false,
          'EnemyEngagementSystem requires EngagementIntentStore on melee enemies; add it at spawn time.',
        );
        continue;
      }

      _ensureChaseOffsetInitialized(world, chaseIndex, enemy);

      final chaseOffset = world.groundEnemyChaseOffset;
      final chaseOffsetX = chaseOffset.chaseOffsetX[chaseIndex];
      final chaseSpeedScale = chaseOffset.chaseSpeedScale[chaseIndex];

      final navTargetX = world.navIntent.navTargetX[navIntentIndex];

      var state = world.meleeEngagement.state[meleeIndex];
      var ticksLeft = world.meleeEngagement.ticksLeft[meleeIndex];
      var preferredSide = world.meleeEngagement.preferredSide[meleeIndex];
      if (ticksLeft > 0) {
        ticksLeft -= 1;
      }

      final ex = world.transform.posX[ti];
      final dxToPlayer = playerX - ex;
      final distToPlayerX = dxToPlayer.abs();
      final sideNow = dxToPlayer >= 0 ? -1 : 1;
      final collapseDistX = groundEnemyTuning.combat.meleeRangeX +
          groundEnemyTuning.locomotion.stopDistanceX;

      final meleeOffsetMaxX =
          groundEnemyTuning.navigation.chaseOffsetMeleeX.abs();
      final meleeOffsetAbs = min(meleeOffsetMaxX, chaseOffsetX.abs());
      final meleeOffsetX = meleeOffsetAbs == 0.0
          ? 0.0
          : (chaseOffsetX >= 0.0 ? meleeOffsetAbs : -meleeOffsetAbs);

      if (preferredSide == 0 || sideNow != preferredSide) {
        preferredSide = sideNow;
      }

      final engageEnterDist = groundEnemyTuning.combat.meleeRangeX +
          groundEnemyTuning.locomotion.stopDistanceX +
          groundEnemyTuning.engagement.meleeEngageBufferX;
      final engageExitDist =
          engageEnterDist + groundEnemyTuning.engagement.meleeEngageHysteresisX;

      switch (state) {
        case MeleeEngagementState.approach:
          if (distToPlayerX <= engageEnterDist) {
            state = MeleeEngagementState.engage;
            ticksLeft = 0;
          }
          break;
        case MeleeEngagementState.engage:
          if (distToPlayerX > engageExitDist) {
            state = MeleeEngagementState.approach;
            ticksLeft = 0;
          }
          break;
        case MeleeEngagementState.attack:
          if (distToPlayerX > engageExitDist) {
            state = MeleeEngagementState.approach;
            ticksLeft = 0;
          } else if (ticksLeft <= 0) {
            state = MeleeEngagementState.recover;
            ticksLeft = groundEnemyTuning.combat.meleeAnimTicks;
          }
          break;
        case MeleeEngagementState.recover:
          if (distToPlayerX > engageExitDist) {
            state = MeleeEngagementState.approach;
            ticksLeft = 0;
          } else if (ticksLeft <= 0) {
            state = MeleeEngagementState.engage;
          }
          break;
      }

      final engageTargetX =
          navTargetX + preferredSide * groundEnemyTuning.engagement.meleeStandOffX;

      double desiredTargetX;
      var stateSpeedMul = 1.0;
      var arrivalSlowRadiusX = 0.0;
      var speedScale = 1.0;

      if (state == MeleeEngagementState.approach) {
        desiredTargetX = distToPlayerX <= collapseDistX
            ? navTargetX + meleeOffsetX
            : navTargetX + chaseOffsetX;
        speedScale = chaseSpeedScale;
      } else {
        desiredTargetX = engageTargetX;
        arrivalSlowRadiusX =
            groundEnemyTuning.engagement.meleeArriveSlowRadiusX;
        if (state == MeleeEngagementState.attack) {
          stateSpeedMul = groundEnemyTuning.engagement.meleeAttackSpeedMul;
        } else if (state == MeleeEngagementState.recover) {
          stateSpeedMul = groundEnemyTuning.engagement.meleeRecoverSpeedMul;
        }
      }

      final engagementIntent = world.engagementIntent;
      engagementIntent.desiredTargetX[engagementIndex] = desiredTargetX;
      engagementIntent.arrivalSlowRadiusX[engagementIndex] = arrivalSlowRadiusX;
      engagementIntent.stateSpeedMul[engagementIndex] = stateSpeedMul;
      engagementIntent.speedScale[engagementIndex] = speedScale;

      world.meleeEngagement.state[meleeIndex] = state;
      world.meleeEngagement.ticksLeft[meleeIndex] = max(0, ticksLeft);
      world.meleeEngagement.preferredSide[meleeIndex] = preferredSide;
    }
  }

  void _ensureChaseOffsetInitialized(
    EcsWorld world,
    int chaseIndex,
    EntityId enemy,
  ) {
    final chaseOffset = world.groundEnemyChaseOffset;
    if (chaseOffset.initialized[chaseIndex]) return;

    final tuning = groundEnemyTuning;
    var rngState = chaseOffset.rngState[chaseIndex];
    if (rngState == 0) {
      rngState = enemy;
    }

    final maxAbs = tuning.navigation.chaseOffsetMaxX.abs();
    var offsetX = 0.0;
    if (maxAbs > 0.0) {
      rngState = nextUint32(rngState);
      offsetX = rangeDouble(rngState, -maxAbs, maxAbs);
      final minAbs = clampDouble(
        tuning.navigation.chaseOffsetMinAbsX,
        0.0,
        maxAbs,
      );
      final absOffset = offsetX.abs();
      if (absOffset < minAbs) {
        offsetX = offsetX >= 0.0 ? minAbs : -minAbs;
        if (absOffset == 0.0) {
          offsetX = minAbs;
        }
      }
    }

    rngState = nextUint32(rngState);
    final speedScale = rangeDouble(
      rngState,
      tuning.navigation.chaseSpeedScaleMin,
      tuning.navigation.chaseSpeedScaleMax,
    );
    chaseOffset.initialized[chaseIndex] = true;
    chaseOffset.chaseOffsetX[chaseIndex] = offsetX;
    chaseOffset.chaseSpeedScale[chaseIndex] = speedScale;
    chaseOffset.rngState[chaseIndex] = rngState;
  }
}
