import '../../combat/damage.dart';
import '../../util/double_math.dart';
import '../world.dart';

class DamageSystem {
  final List<DamageRequest> _pending = <DamageRequest>[];

  void queue(DamageRequest request) {
    if (request.amount <= 0) return;
    _pending.add(request);
  }

  void step(EcsWorld world) {
    if (_pending.isEmpty) return;

    final health = world.health;
    for (final req in _pending) {
      if (!health.has(req.target)) continue;
      final hi = health.indexOf(req.target);
      health.hp[hi] = clampDouble(
        health.hp[hi] - req.amount,
        0.0,
        health.hpMax[hi],
      );
    }
    _pending.clear();
  }
}
