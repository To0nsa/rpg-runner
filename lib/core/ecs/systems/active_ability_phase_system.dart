import '../../abilities/ability_def.dart';
import '../../abilities/forced_interrupt_policy.dart';
import '../world.dart';

/// Updates ActiveAbilityState phase timing and handles forced interruptions.
class ActiveAbilityPhaseSystem {
  void step(EcsWorld world, {required int currentTick}) {
    final active = world.activeAbility;
    if (active.denseEntities.isEmpty) return;

    for (var i = 0; i < active.denseEntities.length; i += 1) {
      final entity = active.denseEntities[i];
      final abilityId = active.abilityId[i];
      if (abilityId == null || abilityId.isEmpty) {
        active.phase[i] = AbilityPhase.idle;
        active.elapsedTicks[i] = 0;
        continue;
      }

      if (_isForcedInterrupted(world, entity, abilityId, currentTick)) {
        _clearAbility(world, entity, i);
        _clearBufferedInput(world, entity);
        _clearPendingIntents(world, entity);
        continue;
      }

      final commitTick = active.startTick[i];
      var elapsed = currentTick - commitTick;
      if (elapsed < 0) elapsed = 0;
      active.elapsedTicks[i] = elapsed;

      final total = active.totalTicks[i];
      if (total <= 0 || elapsed >= total) {
        _clearAbility(world, entity, i);
        continue;
      }

      final windup = active.windupTicks[i];
      final activeTicks = active.activeTicks[i];

      if (elapsed < windup) {
        active.phase[i] = AbilityPhase.windup;
      } else if (elapsed < windup + activeTicks) {
        active.phase[i] = AbilityPhase.active;
      } else {
        active.phase[i] = AbilityPhase.recovery;
      }
    }
  }

  bool _isForcedInterrupted(
    EcsWorld world,
    int entity,
    AbilityKey abilityId,
    int currentTick,
  ) {
    final forcedCauses = forcedInterruptCausesForAbility(abilityId);
    if (forcedCauses.contains(ForcedInterruptCause.stun) &&
        world.controlLock.isStunned(entity, currentTick)) {
      return true;
    }
    final hi = world.health.tryIndexOf(entity);
    final hasDeathInterrupt = forcedCauses.contains(ForcedInterruptCause.death);
    if (hasDeathInterrupt && hi != null && world.health.hp[hi] <= 0) {
      return true;
    }
    if (hasDeathInterrupt && world.deathState.has(entity)) return true;
    return false;
  }

  void _clearAbility(EcsWorld world, int entity, int index) {
    world.activeAbility.clear(entity);
    world.activeAbility.phase[index] = AbilityPhase.idle;
    world.activeAbility.elapsedTicks[index] = 0;
  }

  void _clearBufferedInput(EcsWorld world, int entity) {
    if (world.abilityInputBuffer.has(entity)) {
      world.abilityInputBuffer.clear(entity);
    }
  }

  void _clearPendingIntents(EcsWorld world, int entity) {
    if (world.meleeIntent.has(entity)) {
      final i = world.meleeIntent.indexOf(entity);
      world.meleeIntent.tick[i] = -1;
      world.meleeIntent.commitTick[i] = -1;
    }
    if (world.projectileIntent.has(entity)) {
      final i = world.projectileIntent.indexOf(entity);
      world.projectileIntent.tick[i] = -1;
      world.projectileIntent.commitTick[i] = -1;
    }
    if (world.mobilityIntent.has(entity)) {
      final i = world.mobilityIntent.indexOf(entity);
      world.mobilityIntent.tick[i] = -1;
      world.mobilityIntent.commitTick[i] = -1;
    }
    if (world.selfIntent.has(entity)) {
      final i = world.selfIntent.indexOf(entity);
      world.selfIntent.tick[i] = -1;
      world.selfIntent.commitTick[i] = -1;
    }
  }
}
