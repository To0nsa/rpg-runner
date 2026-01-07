import '../world.dart';

/// Decrements active action cooldowns (melee, cast) for all entities each tick.
class CooldownSystem {
  /// Runs the cooldown logic.
  ///
  /// Iterates over all entities with a [CooldownStore] and reduces their
  /// remaining tick counts by 1, clamping at 0.
  void step(EcsWorld world) {
    final store = world.cooldown;
    // Iterate over dense arrays for cache efficiency.
    for (var i = 0; i < store.denseEntities.length; i += 1) {
      if (store.castCooldownTicksLeft[i] > 0) {
        store.castCooldownTicksLeft[i] -= 1;
      }
      if (store.meleeCooldownTicksLeft[i] > 0) {
        store.meleeCooldownTicksLeft[i] -= 1;
      }
    }
  }
}
