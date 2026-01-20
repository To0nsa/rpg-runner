import '../entity_id.dart';
import '../world.dart';

/// Despawns any non-player entity with `HealthStore` and `hp <= 0`.
///
/// **Responsibilities**:
/// *   Scans all entities with health.
/// *   Identifies those with zero or negative health points.
/// *   Removes the dead entities from the ECS world.
///
/// **IMPORTANT**: The player is intentionally exempt because player "death" is a
/// different gameplay flow (game over / respawn / end-run) than despawning an
/// entity in-place.
class HealthDespawnSystem {
  /// Internal buffer to hold entities scheduled for destruction this frame.
  /// Used to avoid modifying the entity collection while iterating over it.
  final List<EntityId> _toDespawn = <EntityId>[];

  /// Runs the system logic.
  ///
  void step(
    EcsWorld world, {
    required EntityId player,
  }) {
    final health = world.health;
    // Optimization: If no entities have health components, there's nothing to check.
    if (health.denseEntities.isEmpty) return;

    // Reset buffer for this frame.
    _toDespawn.clear();

    // -- Pass 1: Identification --
    // Iterate over all entities participating in the health system.
    for (var i = 0; i < health.denseEntities.length; i += 1) {
      final e = health.denseEntities[i];
      
      // Safety check: The player should never be despawned by this system.
      if (e == player) continue;
      
      // Enemies are handled by the enemy death state pipeline.
      if (world.enemy.has(e)) continue;

      // If health is depleted, mark for destruction.
      if (health.hp[i] <= 0.0) {
        _toDespawn.add(e);
      }
    }

    // -- Pass 2: Reporting & Destruction --
    // Process the list of doomed entities.
    for (final e in _toDespawn) {
      // Permanently remove the entity and all its components from the world.
      world.destroyEntity(e);
    }
  }
}
