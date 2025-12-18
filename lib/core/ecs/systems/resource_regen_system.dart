import 'dart:math';

import '../world.dart';

class ResourceRegenSystem {
  void step(EcsWorld world, {required double dtSeconds}) {
    _regenHealth(world, dtSeconds);
    _regenMana(world, dtSeconds);
    _regenStamina(world, dtSeconds);
  }

  void _regenHealth(EcsWorld world, double dtSeconds) {
    final store = world.health;
    for (var i = 0; i < store.denseEntities.length; i += 1) {
      final max = store.hpMax[i];
      if (max <= 0) continue;
      final current = store.hp[i];
      if (current >= max) continue;
      final regen = store.regenPerSecond[i];
      if (regen <= 0) continue;
      store.hp[i] = _clampDouble(current + regen * dtSeconds, 0, max);
    }
  }

  void _regenMana(EcsWorld world, double dtSeconds) {
    final store = world.mana;
    for (var i = 0; i < store.denseEntities.length; i += 1) {
      final max = store.manaMax[i];
      if (max <= 0) continue;
      final current = store.mana[i];
      if (current >= max) continue;
      final regen = store.regenPerSecond[i];
      if (regen <= 0) continue;
      store.mana[i] = _clampDouble(current + regen * dtSeconds, 0, max);
    }
  }

  void _regenStamina(EcsWorld world, double dtSeconds) {
    final store = world.stamina;
    for (var i = 0; i < store.denseEntities.length; i += 1) {
      final max = store.staminaMax[i];
      if (max <= 0) continue;
      final current = store.stamina[i];
      if (current >= max) continue;
      final regen = store.regenPerSecond[i];
      if (regen <= 0) continue;
      store.stamina[i] = _clampDouble(current + regen * dtSeconds, 0, max);
    }
  }

  double _clampDouble(double v, double lo, double hi) => max(lo, min(hi, v));
}
