import '../../enemies/enemy_id.dart';
import '../../enemies/enemy_catalog.dart';
import '../../enemies/enemy_killed_info.dart';
import '../../util/vec2.dart';
import '../entity_id.dart';
import '../world.dart';

/// Despawns any non-player entity with `HealthStore` and `hp <= 0`.
///
/// **Responsibilities**:
/// *   Scans all entities with health.
/// *   Identifies those with zero or negative health points.
/// *   reports enemy deaths (for score/quests) via [outEnemiesKilled].
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
  /// [outEnemiesKilled] is an optional list that, if provided, will be populated
  /// with the [EnemyId]s of any enemies destroyed this frame.
  void step(
    EcsWorld world, {
    required EntityId player,
    List<EnemyId>? outEnemiesKilled,
    List<EnemyKilledInfo>? outEnemyKilledInfo,
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
      
      // If health is depleted, mark for destruction.
      if (health.hp[i] <= 0.0) {
        _toDespawn.add(e);
      }
    }

    // -- Pass 2: Reporting & Destruction --
    // Process the list of doomed entities.
    for (final e in _toDespawn) {
      // If the caller wants to know about enemy kills (e.g. for scoring)...
      final enemyIndex = world.enemy.tryIndexOf(e);
      if (enemyIndex != null) {
        final enemyId = world.enemy.enemyId[enemyIndex];
        final archetype = const EnemyCatalog().get(enemyId);
        if (outEnemiesKilled != null) {
          outEnemiesKilled.add(enemyId);
        }
        if (outEnemyKilledInfo != null && world.transform.has(e)) {
          final ti = world.transform.indexOf(e);
          outEnemyKilledInfo.add(
            EnemyKilledInfo(
              enemyId: enemyId,
              pos: Vec2(world.transform.posX[ti], world.transform.posY[ti]),
              facing: world.enemy.facing[enemyIndex],
              artFacingDir: archetype.artFacingDir,
            ),
          );
        }
      }
      
      // Permanently remove the entity and all its components from the world.
      world.destroyEntity(e);
    }
  }
}
