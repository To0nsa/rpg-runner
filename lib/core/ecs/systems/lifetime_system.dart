import '../entity_id.dart';
import '../world.dart';

/// Decrements `LifetimeStore.ticksLeft` and despawns entities when it reaches 0.
///
/// This is intentionally generic so any timed entity type can reuse it
/// (projectiles, pickups, hazards, VFX, etc.).
class LifetimeSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  void step(EcsWorld world) {
    final lifetimes = world.lifetime;
    if (lifetimes.denseEntities.isEmpty) return;

    _toDespawn.clear();

    for (var li = 0; li < lifetimes.denseEntities.length; li += 1) {
      final e = lifetimes.denseEntities[li];
      final ticksLeft = lifetimes.ticksLeft[li];
      if (ticksLeft <= 0) {
        _toDespawn.add(e);
        continue;
      }

      final next = ticksLeft - 1;
      lifetimes.ticksLeft[li] = next;
      if (next <= 0) {
        _toDespawn.add(e);
      }
    }

    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}

