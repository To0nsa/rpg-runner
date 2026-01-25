import '../../combat/status/status.dart';
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
  }) : _rngState = seedFrom(rngSeed, 0x44a3c2f1);

  /// Number of ticks an entity is invulnerable after taking damage.
  final int invulnerabilityTicksOnHit;

  int _rngState;
  
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
    
    for (var i = 0; i < queue.length; i += 1) {
      if ((queue.flags[i] & DamageQueueFlags.canceled) != 0) continue;

      final target = queue.target[i];
      final amount100 = queue.amount100[i];
      final damageType = queue.damageType[i];
      final statusProfileId = queue.statusProfileId[i];
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

      // 3. Apply resistance/vulnerability modifier.
      final ri = resistance.tryIndexOf(target);
      final modBp = ri == null ? 0 : resistance.modBpForIndex(ri, damageType);
      var appliedAmount = applyBp(amount100, modBp);
      if (appliedAmount < 0) appliedAmount = 0;

      final prevHp = health.hp[hi];
      final nextHp = clampInt(
        prevHp - appliedAmount,
        0,
        health.hpMax[hi],
      );
      health.hp[hi] = nextHp;

      // 4. Record Last Damage details (if store exists).
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

      // 5. Queue status effects (independent of HP loss).
      if (queueStatus != null) {
        if (statusProfileId != StatusProfileId.none) {
          queueStatus(
            StatusRequest(
              target: target,
              profileId: statusProfileId,
              damageType: damageType,
            ),
          );
        }
        if (procs.isNotEmpty) {
          for (final proc in procs) {
            if (proc.hook != ProcHook.onHit) continue;
            if (proc.statusProfileId == StatusProfileId.none) continue;
            _rngState = nextUint32(_rngState);
            if ((_rngState % bpScale) < proc.chanceBp) {
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
      }

      // 6. Apply new Invulnerability frames.
      if (invulnerabilityTicksOnHit > 0 && ii != null) {
        invuln.ticksLeft[ii] = invulnerabilityTicksOnHit;
      }
    }
    queue.clear();
  }
}
