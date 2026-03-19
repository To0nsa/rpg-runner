import 'dart:math';

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../enemies/enemy_catalog.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../../util/deterministic_rng.dart';
import '../../util/double_math.dart';
import '../../util/fixed_math.dart';
import '../entity_id.dart';
import '../stores/enemies/melee_engagement_store.dart';
import '../world.dart';

/// Resolves melee engagement state and desired slots for ground enemies.
class EnemyEngagementSystem {
  EnemyEngagementSystem({
    required this.groundEnemyTuning,
    this.enemyCatalog = const EnemyCatalog(),
    this.abilities = AbilityCatalog.shared,
  });

  final GroundEnemyTuningDerived groundEnemyTuning;
  final EnemyCatalog enemyCatalog;
  final AbilityResolver abilities;

  /// Updates engagement intents for ground enemies.
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (!world.transform.has(player)) return;

    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];

    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final enemy = enemies.denseEntities[ei];
      final archetype = enemyCatalog.get(enemies.enemyId[ei]);
      final primaryMeleeAbilityId = archetype.primaryMeleeAbilityId;
      if (primaryMeleeAbilityId == null) continue;

      if (world.deathState.has(enemy)) continue;
      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

      if (world.controlLock.isStunned(enemy, currentTick)) continue;

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
      final actionSpeedBp = _actionSpeedBpForEntity(world, enemy);

      final navTargetX = world.navIntent.navTargetX[navIntentIndex];

      var state = world.meleeEngagement.state[meleeIndex];
      var ticksLeft = world.meleeEngagement.ticksLeft[meleeIndex];
      var preferredSide = world.meleeEngagement.preferredSide[meleeIndex];
      var strikeStartTick = world.meleeEngagement.strikeStartTick[meleeIndex];
      var plannedHitTick = world.meleeEngagement.plannedHitTick[meleeIndex];
      var strikeAbilityId = world.meleeEngagement.strikeAbilityId[meleeIndex];
      final currentStrikeTiming = strikeAbilityId == null
          ? null
          : _resolveMeleeTiming(
              abilities.resolve(strikeAbilityId),
              actionSpeedBp,
            );
      if (ticksLeft > 0) {
        ticksLeft -= 1;
      }

      final ex = world.transform.posX[ti];
      final dxToPlayer = playerX - ex;
      final distToPlayerX = dxToPlayer.abs();
      final sideNow = dxToPlayer >= 0 ? -1 : 1;
      final collapseDistX =
          groundEnemyTuning.combat.meleeRangeX +
          groundEnemyTuning.locomotion.stopDistanceX;

      final meleeOffsetMaxX = groundEnemyTuning.navigation.chaseOffsetMeleeX
          .abs();
      final meleeOffsetAbs = min(meleeOffsetMaxX, chaseOffsetX.abs());
      final meleeOffsetX = meleeOffsetAbs == 0.0
          ? 0.0
          : (chaseOffsetX >= 0.0 ? meleeOffsetAbs : -meleeOffsetAbs);

      if (preferredSide == 0 || sideNow != preferredSide) {
        preferredSide = sideNow;
      }

      final engageEnterDist =
          groundEnemyTuning.combat.meleeRangeX +
          groundEnemyTuning.locomotion.stopDistanceX +
          groundEnemyTuning.engagement.meleeEngageBufferX;
      final engageExitDist =
          engageEnterDist + groundEnemyTuning.engagement.meleeEngageHysteresisX;

      switch (state) {
        case MeleeEngagementState.approach:
          if (distToPlayerX <= engageEnterDist) {
            state = MeleeEngagementState.engage;
            ticksLeft = 0;
            strikeStartTick = -1;
            plannedHitTick = -1;
            strikeAbilityId = null;
          }
          break;
        case MeleeEngagementState.engage:
          if (distToPlayerX > engageExitDist) {
            state = MeleeEngagementState.approach;
            ticksLeft = 0;
            strikeStartTick = -1;
            plannedHitTick = -1;
            strikeAbilityId = null;
          } else {
            // Cooldown-gated transition into strike.
            final ci = world.cooldown.tryIndexOf(enemy);
            if (ci != null) {
              final selectedAbilityId = _selectMeleeAbilityId(
                world,
                enemy: enemy,
                archetype: archetype,
                primaryMeleeAbilityId: primaryMeleeAbilityId,
              );
              final selectedAbility = abilities.resolve(selectedAbilityId);
              final selectedTiming = _resolveMeleeTiming(
                selectedAbility,
                actionSpeedBp,
              );
              if (selectedAbility == null || selectedTiming == null) {
                break;
              }
              final cooldownGroupId = selectedAbility.effectiveCooldownGroup(
                AbilitySlot.primary,
              );
              final cooldownReady = !world.cooldown.isOnCooldown(
                enemy,
                cooldownGroupId,
              );
              final inMeleeRange =
                  distToPlayerX <= groundEnemyTuning.combat.meleeRangeX;
              if (cooldownReady && inMeleeRange) {
                state = MeleeEngagementState.strike;
                ticksLeft = selectedTiming.totalTicks;
                strikeStartTick = currentTick;
                plannedHitTick = currentTick + selectedTiming.windupTicks;
                strikeAbilityId = selectedAbilityId;
              }
            }
          }
          break;
        case MeleeEngagementState.strike:
          if (ticksLeft <= 0) {
            state = MeleeEngagementState.recover;
            ticksLeft = currentStrikeTiming?.totalTicks ?? 0;
            strikeStartTick = -1;
            plannedHitTick = -1;
            strikeAbilityId = null;
          }
          break;
        case MeleeEngagementState.recover:
          if (ticksLeft <= 0) {
            state = MeleeEngagementState.engage;
            strikeStartTick = -1;
            plannedHitTick = -1;
            strikeAbilityId = null;
          }
          break;
      }

      final engageTargetX =
          navTargetX +
          preferredSide * groundEnemyTuning.engagement.meleeStandOffX;

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
        if (state == MeleeEngagementState.strike) {
          stateSpeedMul = groundEnemyTuning.engagement.meleeStrikeSpeedMul;
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
      world.meleeEngagement.strikeStartTick[meleeIndex] = strikeStartTick;
      world.meleeEngagement.plannedHitTick[meleeIndex] = plannedHitTick;
      world.meleeEngagement.strikeAbilityId[meleeIndex] = strikeAbilityId;
    }
  }

  AbilityKey _selectMeleeAbilityId(
    EcsWorld world, {
    required EntityId enemy,
    required EnemyArchetype archetype,
    required AbilityKey primaryMeleeAbilityId,
  }) {
    final comboMeleeAbilityId = archetype.comboMeleeAbilityId;
    if (comboMeleeAbilityId != null) {
      final comboIndex = world.meleeCombo.tryIndexOf(enemy);
      if (comboIndex != null && world.meleeCombo.armed[comboIndex]) {
        return comboMeleeAbilityId;
      }
    }
    return primaryMeleeAbilityId;
  }

  _MeleeTiming? _resolveMeleeTiming(AbilityDef? ability, int actionSpeedBp) {
    if (ability == null) return null;
    if (ability.hitDelivery is! MeleeHitDelivery) return null;
    final windupTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.windupTicks),
      actionSpeedBp,
    );
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final totalBaseTicks =
        ability.windupTicks + ability.activeTicks + ability.recoveryTicks;
    final totalTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(totalBaseTicks),
      actionSpeedBp,
    );
    final clampedTotalTicks = max(totalTicks, windupTicks + activeTicks);
    return _MeleeTiming(
      windupTicks: windupTicks,
      totalTicks: clampedTotalTicks,
    );
  }

  int _actionSpeedBpForEntity(EcsWorld world, EntityId entity) {
    final modifierIndex = world.statModifier.tryIndexOf(entity);
    if (modifierIndex == null) return bpScale;
    return world.statModifier.actionSpeedBp[modifierIndex];
  }

  int _scaleTicksForActionSpeed(int ticks, int actionSpeedBp) {
    if (ticks <= 0) return 0;
    final clampedSpeedBp = clampInt(actionSpeedBp, 1000, 20000);
    if (clampedSpeedBp == bpScale) return ticks;
    return (ticks * bpScale + clampedSpeedBp - 1) ~/ clampedSpeedBp;
  }

  int _scaleAbilityTicks(int ticks) {
    if (ticks <= 0) return 0;
    if (groundEnemyTuning.tickHz == _abilityTickHz) return ticks;
    final seconds = ticks / _abilityTickHz;
    return (seconds * groundEnemyTuning.tickHz).ceil();
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

  static const int _abilityTickHz = 60;
}

class _MeleeTiming {
  const _MeleeTiming({required this.windupTicks, required this.totalTicks});

  final int windupTicks;
  final int totalTicks;
}
