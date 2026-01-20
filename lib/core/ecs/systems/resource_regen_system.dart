import '../../util/double_math.dart';
import '../world.dart';

/// Periodically regenerates Health, Mana, and Stamina for all entities.
///
/// **Responsibilities**:
/// - Iterates over all entities with [Health], [Mana], or [Stamina].
/// - Applies regeneration rates (`regenPerSecond`) scaled by `dtSeconds`.
/// - Clamps values to `[0, Max]`.
///
/// **Performance**:
/// - Uses direct dense array iteration (Structure of Arrays) for cache efficiency.
/// - Skips full resources and zero-regen entities early.
class ResourceRegenSystem {
  void step(EcsWorld world, {required double dtSeconds}) {
    _regenHealth(world, dtSeconds);
    _regenMana(world, dtSeconds);
    _regenStamina(world, dtSeconds);
  }

  void _regenHealth(EcsWorld world, double dtSeconds) {
    final store = world.health;
    final deathState = world.deathState;
    final count = store.denseEntities.length;
    // Iterate contiguous arrays directly (SoA pattern).
    for (var i = 0; i < count; i += 1) {
      if (deathState.has(store.denseEntities[i])) continue;
      final max = store.hpMax[i];
      if (max <= 0) continue;
      
      final current = store.hp[i];
      if (current >= max) continue;
      
      final regen = store.regenPerSecond[i];
      if (regen <= 0) continue;
      
      store.hp[i] = clampDouble(current + regen * dtSeconds, 0.0, max);
    }
  }

  void _regenMana(EcsWorld world, double dtSeconds) {
    final store = world.mana;
    final deathState = world.deathState;
    final count = store.denseEntities.length;
    for (var i = 0; i < count; i += 1) {
      if (deathState.has(store.denseEntities[i])) continue;
      final max = store.manaMax[i];
      if (max <= 0) continue;
      
      final current = store.mana[i];
      if (current >= max) continue;
      
      final regen = store.regenPerSecond[i];
      if (regen <= 0) continue;
      
      store.mana[i] = clampDouble(current + regen * dtSeconds, 0.0, max);
    }
  }

  void _regenStamina(EcsWorld world, double dtSeconds) {
    final store = world.stamina;
    final deathState = world.deathState;
    final count = store.denseEntities.length;
    for (var i = 0; i < count; i += 1) {
      if (deathState.has(store.denseEntities[i])) continue;
      final max = store.staminaMax[i];
      if (max <= 0) continue;
      
      final current = store.stamina[i];
      if (current >= max) continue;
      
      final regen = store.regenPerSecond[i];
      if (regen <= 0) continue;
      
      store.stamina[i] = clampDouble(current + regen * dtSeconds, 0.0, max);
    }
  }
}
