import '../../combat/damage.dart';
import '../../util/double_math.dart';
import '../world.dart';

class DamageSystem {
  DamageSystem({required this.invulnerabilityTicksOnHit});

  final int invulnerabilityTicksOnHit;
  final List<DamageRequest> _pending = <DamageRequest>[];

  void queue(DamageRequest request) {
    if (request.amount <= 0) return;
    _pending.add(request);
  }

  void step(EcsWorld world, {required int currentTick}) {
    if (_pending.isEmpty) return;

    final health = world.health;
    final invuln = world.invulnerability;
    final lastDamage = world.lastDamage;
    for (final req in _pending) {
      if (!health.has(req.target)) continue;
      final hi = health.indexOf(req.target);
      final prevHp = health.hp[hi];

      // Invulnerability applies only to entities that have `InvulnerabilityStore`
      // attached (currently player-only in V0).
      if (invuln.has(req.target)) {
        final ii = invuln.indexOf(req.target);
        if (invuln.ticksLeft[ii] > 0) continue;
      }

      final nextHp = clampDouble(
        prevHp - req.amount,
        0.0,
        health.hpMax[hi],
      );
      health.hp[hi] = nextHp;

      if (nextHp < prevHp && lastDamage.has(req.target)) {
        final li = lastDamage.indexOf(req.target);
        lastDamage.kind[li] = req.sourceKind;
        lastDamage.amount[li] = req.amount;
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

      if (invulnerabilityTicksOnHit > 0 && invuln.has(req.target)) {
        invuln.ticksLeft[invuln.indexOf(req.target)] = invulnerabilityTicksOnHit;
      }
    }
    _pending.clear();
  }
}
