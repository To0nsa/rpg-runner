import '../../combat/damage.dart';
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
      final next = (health.hp[hi] - req.amount).clamp(0.0, health.hpMax[hi]);
      health.hp[hi] = next.toDouble();
    }
    _pending.clear();
  }
}

