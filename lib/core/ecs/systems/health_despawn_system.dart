import '../../enemies/enemy_id.dart';
import '../entity_id.dart';
import '../world.dart';

/// Despawns any non-player entity with `HealthStore` and `hp <= 0`.
///
/// IMPORTANT: The player is intentionally exempt because player "death" is a
/// different gameplay flow (game over / respawn / end-run) than despawning an
/// entity in-place.
class HealthDespawnSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  void step(
    EcsWorld world, {
    required EntityId player,
    List<EnemyId>? outEnemiesKilled,
  }) {
    final health = world.health;
    if (health.denseEntities.isEmpty) return;

    _toDespawn.clear();

    for (var i = 0; i < health.denseEntities.length; i += 1) {
      final e = health.denseEntities[i];
      if (e == player) continue;
      if (health.hp[i] <= 0.0) {
        _toDespawn.add(e);
      }
    }

    for (final e in _toDespawn) {
      if (outEnemiesKilled != null && world.enemy.has(e)) {
        final enemyIndex = world.enemy.indexOf(e);
        outEnemiesKilled.add(world.enemy.enemyId[enemyIndex]);
      }
      world.destroyEntity(e);
    }
  }
}
