import '../../combat/status/status.dart';
import '../../stats/character_stats_resolver.dart';
import '../../util/deterministic_rng.dart';
import '../../util/fixed_math.dart';
import '../../weapons/weapon_proc.dart';
import '../stores/damage_queue_store.dart';
import '../world.dart';

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
    CharacterStatsResolver statsResolver = const CharacterStatsResolver(),
  }) : _rngState = seedFrom(rngSeed, 0x44a3c2f1),
       _statsResolver = statsResolver;

  /// Number of ticks an entity is invulnerable after taking damage.
  final int invulnerabilityTicksOnHit;
  final CharacterStatsResolver _statsResolver;

  int _rngState;
  static const int _critDamageBonusBp = 5000; // +50% on crit.

  /// Processes all pending damage requests.
  void step(
    EcsWorld world, {
    required int currentTick,
    void Function(StatusRequest request)? queueStatus,
  }) {
    final queue = world.damageQueue;
    if (queue.length == 0) return;

    final health = world.health;
    final invuln = world.invulnerability;
    final lastDamage = world.lastDamage;
    final resistance = world.damageResistance;
    final loadout = world.equippedLoadout;

    for (var i = 0; i < queue.length; i += 1) {
      if ((queue.flags[i] & DamageQueueFlags.canceled) != 0) continue;

      final target = queue.target[i];
      final amount100 = queue.amount100[i];
      final critChanceBp = queue.critChanceBp[i];
      final damageType = queue.damageType[i];
      final procs = queue.procs[i];
      final sourceKind = queue.sourceKind[i];
      final sourceEnemyId = queue.sourceEnemyId[i];
      final sourceProjectileId = queue.sourceProjectileId[i];
      final sourceProjectileItemId = queue.sourceProjectileItemId[i];

      // 1. Resolve Health component.
      // Use tryIndexOf (returns int?) to combine "has check" and "get index"
      // into a single lookup for performance.
      final hi = health.tryIndexOf(target);
      if (hi == null) continue;

      // 2. Resolve Invulnerability component (optional).
      final ii = invuln.tryIndexOf(target);

      // Invulnerability applies only to entities that have `InvulnerabilityStore`
      // attached.
      if (ii != null && invuln.ticksLeft[ii] > 0) {
        continue; // Damage negated.
      }

      // 3. Resolve outgoing critical strike (if any).
      var amountAfterCrit = amount100;
      if (critChanceBp >= bpScale) {
        amountAfterCrit = applyBp(amountAfterCrit, _critDamageBonusBp);
      } else if (critChanceBp > 0) {
        _rngState = nextUint32(_rngState);
        if ((_rngState % bpScale) < critChanceBp) {
          amountAfterCrit = applyBp(amountAfterCrit, _critDamageBonusBp);
        }
      }
      if (amountAfterCrit < 0) amountAfterCrit = 0;

      // 4. Apply global defense (if the target has equipped gear stats).
      var amountAfterDefense = amountAfterCrit;
      final li = loadout.tryIndexOf(target);
      if (li != null) {
        final resolved = _statsResolver.resolveEquipped(
          mask: loadout.mask[li],
          mainWeaponId: loadout.mainWeaponId[li],
          offhandWeaponId: loadout.offhandWeaponId[li],
          projectileItemId: loadout.projectileItemId[li],
          spellBookId: loadout.spellBookId[li],
          accessoryId: loadout.accessoryId[li],
        );
        amountAfterDefense = resolved.applyDefense(amountAfterDefense);
      }

      // 5. Apply resistance/vulnerability modifier.
      final ri = resistance.tryIndexOf(target);
      final modBp = ri == null ? 0 : resistance.modBpForIndex(ri, damageType);
      var appliedAmount = applyBp(amountAfterDefense, modBp);
      if (appliedAmount < 0) appliedAmount = 0;

      final prevHp = health.hp[hi];
      final nextHp = clampInt(prevHp - appliedAmount, 0, health.hpMax[hi]);
      health.hp[hi] = nextHp;

      // 6. Record Last Damage details (if store exists).
      // Only useful if damage was actually taken.
      if (nextHp < prevHp) {
        final li = lastDamage.tryIndexOf(target);
        if (li != null) {
          lastDamage.kind[li] = sourceKind;
          lastDamage.amount100[li] = appliedAmount;
          lastDamage.tick[li] = currentTick;

          if (sourceEnemyId != null) {
            lastDamage.enemyId[li] = sourceEnemyId;
            lastDamage.hasEnemyId[li] = true;
          } else {
            lastDamage.hasEnemyId[li] = false;
          }

          if (sourceProjectileId != null) {
            lastDamage.projectileId[li] = sourceProjectileId;
            lastDamage.hasProjectileId[li] = true;
          } else {
            lastDamage.hasProjectileId[li] = false;
          }

          if (sourceProjectileItemId != null) {
            lastDamage.projectileItemId[li] = sourceProjectileItemId;
            lastDamage.hasProjectileItemId[li] = true;
          } else {
            lastDamage.hasProjectileItemId[li] = false;
          }
        }
      }

      // 7. Queue status effects for non-zero damage requests.
      if (queueStatus != null && amount100 > 0 && procs.isNotEmpty) {
        for (final proc in procs) {
          if (proc.hook != ProcHook.onHit) continue;
          if (proc.statusProfileId == StatusProfileId.none) continue;
          final chance = proc.chanceBp;
          if (chance >= bpScale) {
            queueStatus(
              StatusRequest(
                target: target,
                profileId: proc.statusProfileId,
                damageType: damageType,
              ),
            );
            continue;
          }
          if (chance <= 0) continue;
          _rngState = nextUint32(_rngState);
          if ((_rngState % bpScale) < chance) {
            queueStatus(
              StatusRequest(
                target: target,
                profileId: proc.statusProfileId,
                damageType: damageType,
              ),
            );
          }
        }
      }

      // 8. Apply new Invulnerability frames.
      if (invulnerabilityTicksOnHit > 0 && ii != null) {
        invuln.ticksLeft[ii] = invulnerabilityTicksOnHit;
      }
    }
    queue.clear();
  }
}
