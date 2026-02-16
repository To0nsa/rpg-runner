import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../ecs/stores/damage_queue_store.dart';
import '../../ecs/systems/damage_middleware_system.dart';
import '../../ecs/world.dart';
import '../../events/game_event.dart';
import '../../util/fixed_math.dart';

/// Mitigates incoming hits while a guard-like ability is active and can grant a
/// one-shot riposte buff when authored to do so.
///
/// This is used by multiple abilities (e.g. sword parry, shield block) to keep
/// defense rules centralized and deterministic.
class ParryMiddleware implements DamageMiddleware {
  ParryMiddleware({
    required Set<AbilityKey> abilityIds,
    this.abilityResolver = AbilityCatalog.shared,
    this.defaultDamageIgnoredBp = bpScale,
    this.defaultGrantsRiposte = true,
    this.riposteBonusBp = 10000,
    this.riposteLifetimeTicks = 60,
  }) : _abilityIds = abilityIds,
       assert(
         defaultDamageIgnoredBp >= 0 && defaultDamageIgnoredBp <= bpScale,
         'defaultDamageIgnoredBp must be in range [0, $bpScale].',
       );

  final Set<AbilityKey> _abilityIds;
  final AbilityResolver abilityResolver;
  final int defaultDamageIgnoredBp;
  final bool defaultGrantsRiposte;
  final int riposteBonusBp;
  final int riposteLifetimeTicks;

  @override
  void apply(
    EcsWorld world,
    DamageQueueStore queue,
    int index,
    int currentTick,
  ) {
    final target = queue.target[index];

    if (world.deathState.has(target)) return;
    final ai = world.activeAbility.tryIndexOf(target);
    if (ai == null) return;
    final activeAbilityId = world.activeAbility.abilityId[ai];
    if (activeAbilityId == null || !_abilityIds.contains(activeAbilityId)) {
      return;
    }

    if (world.activeAbility.phase[ai] != AbilityPhase.active) return;

    // "Hit" only: do not block tick-based damage that comes from already-applied statuses.
    if (queue.sourceKind[index] == DeathSourceKind.statusEffect) return;

    final startTick = world.activeAbility.startTick[ai];

    final elapsed = currentTick - startTick;
    final windup = world.activeAbility.windupTicks[ai];
    final activeElapsed = elapsed - windup;
    if (activeElapsed < 0) return;

    final damageIgnoredBp = _resolveDamageIgnoredBp(activeAbilityId);
    var mitigatedHit = false;
    if (damageIgnoredBp >= bpScale) {
      queue.flags[index] |= DamageQueueFlags.canceled;
      mitigatedHit = true;
    } else if (damageIgnoredBp > 0) {
      final reducedAmount = applyBp(queue.amount100[index], -damageIgnoredBp);
      if (reducedAmount <= 0) {
        queue.flags[index] |= DamageQueueFlags.canceled;
      } else {
        queue.amount100[index] = reducedAmount;
      }
      mitigatedHit = true;
    }
    if (!mitigatedHit) {
      return;
    }

    if (!_shouldGrantRiposte(activeAbilityId)) {
      return;
    }

    // Grant riposte only once per activation (first mitigated hit),
    // while still mitigating subsequent hits during the same activation.
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

  int _resolveDamageIgnoredBp(AbilityKey abilityId) {
    final ability = abilityResolver.resolve(abilityId);
    if (ability == null) return defaultDamageIgnoredBp;
    final ignoredBp = ability.damageIgnoredBp;
    if (ignoredBp <= 0) return 0;
    if (ignoredBp >= bpScale) return bpScale;
    return ignoredBp;
  }

  bool _shouldGrantRiposte(AbilityKey abilityId) {
    final ability = abilityResolver.resolve(abilityId);
    if (ability == null) return defaultGrantsRiposte;
    return ability.grantsRiposteOnGuardedHit;
  }
}
