import '../entity_id.dart';
import '../world.dart';

/// Determines when temporary entities should expire.
///
/// **Responsibilities**:
/// *   Decrements the life timer (`LifetimeStore.ticksLeft`) for all participating entities every tick.
/// *   Despawns entities when their timer reaches zero.
///
/// **Usage**:
/// Generic system used for particles, projectiles, transient UI markers, or timed buffs
/// that need to clean themselves up automatically.
class LifetimeSystem {
  /// Buffer for entities to destroy.
  /// Used to avoid `ConcurrentModificationException` when modifying the ECS state during iteration.
  final List<EntityId> _toDespawn = <EntityId>[];

  /// Executes the system logic.
  void step(EcsWorld world) {
    final lifetimes = world.lifetime;
    // Optimization: Skip processing if no timed entities exist.
    if (lifetimes.denseEntities.isEmpty) return;

    // Reset the buffer for this frame.
    _toDespawn.clear();

    // Iterate over all entities with a lifetime component.
    for (var li = 0; li < lifetimes.denseEntities.length; li += 1) {
      final e = lifetimes.denseEntities[li];
      
      // Decrement the timer (Tick down).
      lifetimes.ticksLeft[li]--;
      
      // If time has run out (or was force-set to <= 0), mark for destruction.
      if (lifetimes.ticksLeft[li] <= 0) {
        _toDespawn.add(e);
      }
    }

    // Process the destruction queue.
    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}

