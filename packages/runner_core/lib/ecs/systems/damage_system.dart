import '../../abilities/ability_def.dart';
import '../../abilities/forced_interrupt_policy.dart';
import '../../combat/damage_type.dart';
import '../../combat/damage_credit.dart';
import '../combat_eligibility.dart';
import '../../combat/status/status.dart';
import '../../events/game_event.dart';
import '../../stats/character_stats_resolver.dart';
import '../../stats/resolved_stats_cache.dart';
import '../../util/deterministic_rng.dart';
import '../../util/fixed_math.dart';
import '../../weapons/weapon_proc.dart';
import 'ability_interrupt.dart';
import 'knockback_system.dart';
import '../entity_id.dart';
import '../stores/damage_queue_store.dart';
import '../world.dart';

/// Reports an accepted hit after protection, defense, and resistance checks.
/// [appliedAmount100] is post-mitigation damage before remaining-HP clamping.
/// [source] is the request's source entity, or null for unattributed/detached hits.
/// [credit] retains player ownership for hits whose source entity has expired.
typedef DamageAppliedCallback = void Function({
  required int target,
  required EntityId? source,
  required int appliedAmount100,
  required DeathSourceKind sourceKind,
  required DamageType damageType,
  required DamageCredit credit,
});

/// Positive HP reduction after all defenses, capped by the target's remaining HP.
typedef ParticipationDamageCallback = void Function({
  required EntityId target,
  required int hpLost100,
  required DamageCredit credit,
});

/// Central system for validating and applying damage to entities.
///
/// Handles:
/// 1.  Processing queued [DamageRequest]s.
/// 2.  Checking invulnerability frames (i-frames).
/// 3.  Reducing [HealthStore] HP.
/// 4.  Recording [LastDamageStore] details (source, amount) for UI/logic.
/// 5.  Applying post-hit invulnerability.
class DamageSystem {
  DamageSystem({
    required this.invulnerabilityTicksOnHit,
    required int rngSeed,
    this.tickHz = 60,
    CharacterStatsResolver statsResolver = const CharacterStatsResolver(),
    ResolvedStatsCache? statsCache,
    this.forcedInterruptPolicy = ForcedInterruptPolicy.defaultPolicy,
  }) : _rngState = seedFrom(rngSeed, 0x44a3c2f1),
       _statsCache = statsCache ?? ResolvedStatsCache(resolver: statsResolver);

  /// Number of ticks an entity is invulnerable after taking damage.
  final int invulnerabilityTicksOnHit;
  final int tickHz;
  final ResolvedStatsCache _statsCache;
  final ForcedInterruptPolicy forcedInterruptPolicy;

  int _rngState;
  static const int _critBonusBp = 5000; // +50% on crit.

  /// Processes all pending damage requests.
  void step(
    EcsWorld world, {
    required int currentTick,
    void Function(StatusRequest request)? queueStatus,
    DamageAppliedCallback? onDamageApplied,
    ParticipationDamageCallback? onParticipationDamage,
  }) {
    final queue = world.damageQueue;
    if (queue.length == 0) return;

    final health = world.health;
    final invuln = world.invulnerability;
    final lastDamage = world.lastDamage;
    final resistance = world.damageResistance;
    final vulnerable = world.vulnerable;
    final weaken = world.weaken;

    for (var i = 0; i < queue.length; i += 1) {
      if ((queue.flags[i] & DamageQueueFlags.canceled) != 0) continue;

      final target = queue.target[i];
      if (isCombatProtected(world, target)) continue;
      final amount100 = queue.amount100[i];
      final critChanceBp = queue.critChanceBp[i];
      final composition = queue.damageType[i];
      final damageType = composition.primaryType;
      final procs = queue.procs[i];
      final sourceKind = queue.sourceKind[i];
      final sourceEntity = queue.sourceEntity[i];
      final comboHit = queue.comboHit[i]?.source == sourceEntity
          ? queue.comboHit[i]
          : null;
      final sourceEnemyId = queue.sourceEnemyId[i];
      final sourceProjectileId = queue.sourceProjectileId[i];

      // 1. Resolve Health component.
      // Use tryIndexOf (returns int?) to combine "has check" and "get index"
      // into a single lookup for performance.
      final hi = health.tryIndexOf(target);
      if (hi == null || health.hp[hi] <= 0 || world.deathState.has(target)) {
        continue;
      }

      // 2. Resolve Invulnerability component (optional).
      final ii = invuln.tryIndexOf(target);

      if (ii != null && !invuln.allowsHit(ii, comboHit)) {
        continue; // Damage negated.
      }

      // 3. Apply outgoing-source modifiers (e.g. weaken).
      var amountAfterSourceModifiers = amount100;
      if (sourceEntity != null) {
        final wi = weaken.tryIndexOf(sourceEntity);
        if (wi != null && weaken.ticksLeft[wi] > 0) {
          amountAfterSourceModifiers = applyBp(
            amountAfterSourceModifiers,
            -weaken.magnitude[wi],
          );
          if (amountAfterSourceModifiers < 0) {
            amountAfterSourceModifiers = 0;
          }
        }
      }

      // 4. Resolve outgoing critical strike (if any).
      var amountAfterCrit = amountAfterSourceModifiers;
      var didCrit = false;
      if (critChanceBp >= bpScale) {
        amountAfterCrit = applyBp(amountAfterCrit, _critBonusBp);
        didCrit = true;
      } else if (critChanceBp > 0) {
        _rngState = nextUint32(_rngState);
        if ((_rngState % bpScale) < critChanceBp) {
          amountAfterCrit = applyBp(amountAfterCrit, _critBonusBp);
          didCrit = true;
        }
      }
      if (amountAfterCrit < 0) amountAfterCrit = 0;

      // 5. Apply global defense (if the target has equipped gear stats).
      var amountAfterDefense = amountAfterCrit;
      final resolvedStats = _statsCache.resolveForEntity(world, target);
      amountAfterDefense = resolvedStats.applyDefense(amountAfterDefense);

      // 6. Split once after shared modifiers, then resist each typed share.
      final ri = resistance.tryIndexOf(target);
      int resist(int amount, DamageType type) {
        final baseMod = ri == null ? 0 : resistance.modBpForIndex(ri, type);
        final gearMod = resolvedStats.incomingDamageModBpForDamageType(type);
        final result = applyBp(amount, baseMod + gearMod);
        return result < 0 ? 0 : result;
      }

      var appliedAmount = 0;
      if (composition is DamageType) {
        appliedAmount = resist(amountAfterDefense, composition);
      } else {
        for (final part in composition.split(amountAfterDefense)) {
          appliedAmount += resist(part.amount100, part.type);
        }
      }
      final vi = vulnerable.tryIndexOf(target);
      if (vi != null && vulnerable.ticksLeft[vi] > 0) {
        appliedAmount = applyBp(appliedAmount, vulnerable.magnitude[vi]);
        if (appliedAmount < 0) appliedAmount = 0;
      }

      final prevHp = health.hp[hi];
      final nextHp = clampInt(prevHp - appliedAmount, 0, health.hpMax[hi]);
      health.hp[hi] = nextHp;
      final didKill = prevHp > 0 && nextHp == 0;

      // 7. Record Last Damage details (if store exists).
      // Only useful if damage was actually taken.
      if (nextHp < prevHp) {
        if (sourceEntity != null) {
          world.npc.recordMeleeHit(
            sourceEntity,
            target,
            queue.sourceMeleeAbilityId[i],
          );
        }
        onParticipationDamage?.call(
          target: target,
          hpLost100: prevHp - nextHp,
          credit: queue.credit[i],
        );
        _interruptOnDamageTaken(world, target);
        final knockback = queue.knockback[i];
        if (knockback != null && nextHp > 0) {
          KnockbackSystem.queueAfterDamage(
            world,
            target: target,
            hit: knockback,
            currentTick: currentTick,
            tickHz: tickHz,
          );
        }

        final li = lastDamage.tryIndexOf(target);
        if (li != null) {
          lastDamage.kind[li] = sourceKind;
          lastDamage.amount100[li] = appliedAmount;
          lastDamage.tick[li] = currentTick;
          lastDamage.sourceTrap[li] = queue.sourceTrap[i];

          if (sourceEnemyId != null) {
            lastDamage.enemyId[li] = sourceEnemyId;
            lastDamage.hasEnemyId[li] = true;
          } else {
            lastDamage.hasEnemyId[li] = false;
          }

          if (sourceProjectileId != null) {
            lastDamage.projectileId[li] = sourceProjectileId;
            lastDamage.hasProjectileId[li] = true;
            lastDamage.sourceProjectileId[li] = sourceProjectileId;
            lastDamage.hasSourceProjectileId[li] = true;
          } else {
            lastDamage.hasProjectileId[li] = false;
            lastDamage.hasSourceProjectileId[li] = false;
          }
        }

        onDamageApplied?.call(
          target: target,
          source: sourceEntity,
          appliedAmount100: appliedAmount,
          sourceKind: sourceKind,
          damageType: damageType,
          credit: queue.credit[i],
        );

        world.reactiveDamageEventQueue.add(
          targetEntity: target,
          source: sourceEntity,
          appliedDamage100: appliedAmount,
          previousHp100: prevHp,
          nextHpAfterDamage100: nextHp,
          maxHpAtApply100: health.hpMax[hi],
          type: damageType,
        );
      }

      // 8. Queue status effects for non-zero damage requests.
      if (queueStatus != null && amount100 > 0 && procs.isNotEmpty) {
        for (final proc in procs) {
          if (proc.statusProfileId == StatusProfileId.none) continue;

          EntityId? statusTarget;
          switch (proc.hook) {
            case ProcHook.onHit:
              statusTarget = target;
              break;
            case ProcHook.onCrit:
              if (!didCrit) continue;
              statusTarget = target;
              break;
            case ProcHook.onKill:
              if (!didKill || sourceEntity == null) continue;
              statusTarget = sourceEntity;
              break;
            case ProcHook.onBlock:
              continue;
          }

          final chance = proc.chanceBp;
          if (chance <= 0) continue;
          if (chance < bpScale) {
            _rngState = nextUint32(_rngState);
            if ((_rngState % bpScale) >= chance) {
              continue;
            }
          }

          queueStatus(
            StatusRequest(
              target: statusTarget,
              profileId: proc.statusProfileId,
              tuning: proc.statusTuning,
              damageType: damageType,
              sourceTrap: queue.sourceTrap[i],
              credit: queue.credit[i],
              acceptedHitTick:
                  proc.hook == ProcHook.onHit || proc.hook == ProcHook.onCrit
                  ? currentTick
                  : null,
            ),
          );
        }
      }

      // 9. Apply new Invulnerability frames.
      if (invulnerabilityTicksOnHit > 0 && ii != null) {
        invuln.grantPostHit(
          ii,
          invulnerabilityTicksOnHit,
          comboHit: nextHp < prevHp ? comboHit : null,
        );
      }
    }
    queue.clear();
  }

  void _interruptOnDamageTaken(EcsWorld world, int entity) {
    if (!world.activeAbility.has(entity)) return;
    final activeIndex = world.activeAbility.indexOf(entity);
    final activeAbilityId = world.activeAbility.abilityId[activeIndex];
    if (!forcedInterruptPolicy.abilityAllowsForcedInterrupt(
      activeAbilityId,
      ForcedInterruptCause.damageTaken,
    )) {
      return;
    }
    AbilityInterrupt.clearActiveAndTransient(
      world,
      entity: entity,
      startDeferredCooldown: true,
    );
  }
}
