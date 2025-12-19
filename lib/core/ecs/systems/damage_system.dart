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

  void step(EcsWorld world) {
    if (_pending.isEmpty) return;

    final health = world.health;
    final invuln = world.invulnerability;
    for (final req in _pending) {
      if (!health.has(req.target)) continue;
      final hi = health.indexOf(req.target);

      // Invulnerability applies only to entities that have `InvulnerabilityStore`
      // attached (currently player-only in V0).
      if (invuln.has(req.target)) {
        final ii = invuln.indexOf(req.target);
        if (invuln.ticksLeft[ii] > 0) continue;
      }

      health.hp[hi] = clampDouble(
        health.hp[hi] - req.amount,
        0.0,
        health.hpMax[hi],
      );

      if (invulnerabilityTicksOnHit > 0 && invuln.has(req.target)) {
        invuln.ticksLeft[invuln.indexOf(req.target)] = invulnerabilityTicksOnHit;
      }
    }
    _pending.clear();
  }
}
