import '../../abilities/ability_def.dart';
import '../../ecs/stores/damage_queue_store.dart';
import '../../ecs/systems/damage_middleware_system.dart';
import '../../ecs/world.dart';
import '../../events/game_event.dart';

/// Cancels incoming hits while a parry-like ability is active and grants a one-shot riposte buff.
///
/// This is used by multiple abilities (e.g. sword parry, shield block) to keep
/// defense rules centralized and deterministic.
class ParryMiddleware implements DamageMiddleware {
  ParryMiddleware({
    required Set<AbilityKey> abilityIds,
    this.riposteBonusBp = 10000,
    this.riposteLifetimeTicks = 60,
  }) : _abilityIds = abilityIds;

  final Set<AbilityKey> _abilityIds;
  final int riposteBonusBp;
  final int riposteLifetimeTicks;

  @override
  void apply(EcsWorld world, DamageQueueStore queue, int index, int currentTick) {
    final target = queue.target[index];

    if (world.deathState.has(target)) return;
    final ai = world.activeAbility.tryIndexOf(target);
    if (ai == null) return;
    if (!_abilityIds.contains(world.activeAbility.abilityId[ai])) return;

    if (world.activeAbility.phase[ai] != AbilityPhase.active) return;

    // "Hit" only: do not block tick-based damage that comes from already-applied statuses.
    if (queue.sourceKind[index] == DeathSourceKind.statusEffect) return;

    final startTick = world.activeAbility.startTick[ai];

    final elapsed = currentTick - startTick;
    final windup = world.activeAbility.windupTicks[ai];
    final activeElapsed = elapsed - windup;
    if (activeElapsed < 0) return;

    // Always cancel hits during the active parry window.
    queue.flags[index] |= DamageQueueFlags.canceled;

    // Grant riposte only once per activation (first blocked hit),
    // while still canceling subsequent hits during the same activation.
    final consumeIndex = world.parryConsume.indexOfOrAdd(target);
    if (world.parryConsume.consumedStartTick[consumeIndex] == startTick) {
      return;
    }
    world.parryConsume.consumedStartTick[consumeIndex] = startTick;

    // Grant a one-shot bonus that is consumed on the next landed melee hit.
    world.riposte.grant(
      target,
      expiresAtTick: currentTick + riposteLifetimeTicks,
      bonusBp: riposteBonusBp,
    );
  }
}

