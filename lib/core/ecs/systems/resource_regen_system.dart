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
  ResourceRegenSystem({required int tickHz}) : _tickHz = tickHz;

  final int _tickHz;

  void step(EcsWorld world) {
    _regenHealth(world);
    _regenMana(world);
    _regenStamina(world);
  }

  void _regenHealth(EcsWorld world) {
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
      
      final regen = store.regenPerSecond100[i];
      if (regen <= 0) continue;

      final accum = store.regenAccumulator[i] + regen;
      final delta = accum ~/ _tickHz;
      if (delta > 0) {
        final next = current + delta;
        store.hp[i] = next > max ? max : next;
      }
      store.regenAccumulator[i] = accum - (delta * _tickHz);
    }
  }

  void _regenMana(EcsWorld world) {
    final store = world.mana;
    final deathState = world.deathState;
    final count = store.denseEntities.length;
    for (var i = 0; i < count; i += 1) {
      if (deathState.has(store.denseEntities[i])) continue;
      final max = store.manaMax[i];
      if (max <= 0) continue;
      
      final current = store.mana[i];
      if (current >= max) continue;
      
      final regen = store.regenPerSecond100[i];
      if (regen <= 0) continue;

      final accum = store.regenAccumulator[i] + regen;
      final delta = accum ~/ _tickHz;
      if (delta > 0) {
        final next = current + delta;
        store.mana[i] = next > max ? max : next;
      }
      store.regenAccumulator[i] = accum - (delta * _tickHz);
    }
  }

  void _regenStamina(EcsWorld world) {
    final store = world.stamina;
    final deathState = world.deathState;
    final count = store.denseEntities.length;
    for (var i = 0; i < count; i += 1) {
      if (deathState.has(store.denseEntities[i])) continue;
      final max = store.staminaMax[i];
      if (max <= 0) continue;
      
      final current = store.stamina[i];
      if (current >= max) continue;
      
      final regen = store.regenPerSecond100[i];
      if (regen <= 0) continue;

      final accum = store.regenAccumulator[i] + regen;
      final delta = accum ~/ _tickHz;
      if (delta > 0) {
        final next = current + delta;
        store.stamina[i] = next > max ? max : next;
      }
      store.regenAccumulator[i] = accum - (delta * _tickHz);
    }
  }
}
