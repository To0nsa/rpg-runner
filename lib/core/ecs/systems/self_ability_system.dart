import '../../combat/status/status.dart';
import '../../util/fixed_math.dart';
import '../stores/self_intent_store.dart';
import '../world.dart';

/// Executes self abilities (parry, block, buffs) based on committed intents.
///
/// **Execution Only**:
/// - Reads committed intents (`tick == currentTick`).
/// - Applies effects (e.g., healing, buffs).
/// - Does **not** deduct resources or start cooldowns.
class SelfAbilitySystem {
  void step(
    EcsWorld world, {
    required int currentTick,
    void Function(StatusRequest request)? queueStatus,
  }) {
    final intents = world.selfIntent;
    if (intents.denseEntities.isEmpty) return;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      final executeTick = intents.tick[ii];

      if (executeTick != currentTick) continue;
      final target = intents.denseEntities[ii];
      if (world.deathState.has(target)) {
        _invalidateIntent(intents, ii);
        continue;
      }

      _applySelfRestores(
        world,
        target: target,
        healthPercentBp: intents.selfRestoreHealthBp[ii],
        manaPercentBp: intents.selfRestoreManaBp[ii],
        staminaPercentBp: intents.selfRestoreStaminaBp[ii],
      );

      if (queueStatus != null) {
        final profileId = intents.selfStatusProfileId[ii];
        if (profileId != StatusProfileId.none) {
          queueStatus(StatusRequest(target: target, profileId: profileId));
        }
      }

      // Invalidate now to ensure no double-execution in same tick
      _invalidateIntent(intents, ii);
    }
  }

  void _invalidateIntent(SelfIntentStore intents, int index) {
    intents.tick[index] = -1;
    intents.commitTick[index] = -1;
  }

  void _applySelfRestores(
    EcsWorld world, {
    required int target,
    required int healthPercentBp,
    required int manaPercentBp,
    required int staminaPercentBp,
  }) {
    if (healthPercentBp > 0) {
      final healthIndex = world.health.tryIndexOf(target);
      if (healthIndex != null) {
        final max = world.health.hpMax[healthIndex];
        if (max > 0) {
          final restore = (max * healthPercentBp) ~/ bpScale;
          final next = world.health.hp[healthIndex] + restore;
          world.health.hp[healthIndex] = next > max ? max : next;
        }
      }
    }

    if (manaPercentBp > 0) {
      final manaIndex = world.mana.tryIndexOf(target);
      if (manaIndex != null) {
        final max = world.mana.manaMax[manaIndex];
        if (max > 0) {
          final restore = (max * manaPercentBp) ~/ bpScale;
          final next = world.mana.mana[manaIndex] + restore;
          world.mana.mana[manaIndex] = next > max ? max : next;
        }
      }
    }

    if (staminaPercentBp > 0) {
      final staminaIndex = world.stamina.tryIndexOf(target);
      if (staminaIndex != null) {
        final max = world.stamina.staminaMax[staminaIndex];
        if (max > 0) {
          final restore = (max * staminaPercentBp) ~/ bpScale;
          final next = world.stamina.stamina[staminaIndex] + restore;
          world.stamina.stamina[staminaIndex] = next > max ? max : next;
        }
      }
    }
  }
}
