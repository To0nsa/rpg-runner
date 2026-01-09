import '../../combat/damage.dart';
import '../../combat/status/status.dart';
import '../../util/double_math.dart';
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
  DamageSystem({required this.invulnerabilityTicksOnHit});

  /// Number of ticks an entity is invulnerable after taking damage.
  final int invulnerabilityTicksOnHit;
  
  // Buffer for damage requests to be processed in `step`.
  final List<DamageRequest> _pending = <DamageRequest>[];

  /// Queues a damage request for the next frame.
  ///
  /// Requests with `amount <= 0` are ignored immediately.
  void queue(DamageRequest request) {
    if (request.amount <= 0 && request.statusProfileId == StatusProfileId.none) {
      return;
    }
    _pending.add(request);
  }

  /// Processes all pending damage requests.
  void step(
    EcsWorld world, {
    required int currentTick,
    void Function(StatusRequest request)? queueStatus,
  }) {
    if (_pending.isEmpty) return;

    final health = world.health;
    final invuln = world.invulnerability;
    final lastDamage = world.lastDamage;
    final resistance = world.damageResistance;
    
    for (final req in _pending) {
      // 1. Resolve Health component.
      // Use tryIndexOf (returns int?) to combine "has check" and "get index"
      // into a single lookup for performance.
      final hi = health.tryIndexOf(req.target);
      if (hi == null) continue;

      // 2. Resolve Invulnerability component (optional).
      final ii = invuln.tryIndexOf(req.target);

      // Invulnerability applies only to entities that have `InvulnerabilityStore`
      // attached.
      if (ii != null && invuln.ticksLeft[ii] > 0) {
        continue; // Damage negated.
      }

      // 3. Apply resistance/vulnerability modifier.
      final ri = resistance.tryIndexOf(req.target);
      final mod = ri == null ? 0.0 : resistance.modForIndex(ri, req.damageType);
      var appliedAmount = req.amount * (1.0 + mod);
      if (appliedAmount < 0.0) appliedAmount = 0.0;

      final prevHp = health.hp[hi];
      final nextHp = clampDouble(
        prevHp - appliedAmount,
        0.0,
        health.hpMax[hi],
      );
      health.hp[hi] = nextHp;

      // 4. Record Last Damage details (if store exists).
      // Only useful if damage was actually taken.
      if (nextHp < prevHp) {
        final li = lastDamage.tryIndexOf(req.target);
        if (li != null) {
          lastDamage.kind[li] = req.sourceKind;
          lastDamage.amount[li] = appliedAmount;
          lastDamage.tick[li] = currentTick;

          if (req.sourceEnemyId != null) {
            lastDamage.enemyId[li] = req.sourceEnemyId!;
            lastDamage.hasEnemyId[li] = true;
          } else {
            lastDamage.hasEnemyId[li] = false;
          }

          if (req.sourceProjectileId != null) {
            lastDamage.projectileId[li] = req.sourceProjectileId!;
            lastDamage.hasProjectileId[li] = true;
          } else {
            lastDamage.hasProjectileId[li] = false;
          }

          if (req.sourceSpellId != null) {
            lastDamage.spellId[li] = req.sourceSpellId!;
            lastDamage.hasSpellId[li] = true;
          } else {
            lastDamage.hasSpellId[li] = false;
          }
        }
      }

      // 5. Queue status effects (independent of HP loss).
      if (queueStatus != null && req.statusProfileId != StatusProfileId.none) {
        queueStatus(
          StatusRequest(
            target: req.target,
            profileId: req.statusProfileId,
            damageType: req.damageType,
          ),
        );
      }

      // 6. Apply new Invulnerability frames.
      if (invulnerabilityTicksOnHit > 0 && ii != null) {
        invuln.ticksLeft[ii] = invulnerabilityTicksOnHit;
      }
    }
    _pending.clear();
  }
}
