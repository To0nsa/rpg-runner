import '../world.dart';

/// Decrements active action cooldowns for all entities each tick.
class CooldownSystem {
  /// Runs the cooldown logic.
  ///
  /// Iterates over all entities with a [CooldownStore] and reduces their
  /// remaining tick counts by 1 for all cooldown groups, clamping at 0.
  void step(EcsWorld world) {
    world.cooldown.tickAll();
  }
}
