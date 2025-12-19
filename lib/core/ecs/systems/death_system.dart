import '../entity_id.dart';
import '../world.dart';

class DeathSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  void step(EcsWorld world, {required EntityId player}) {
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
      world.destroyEntity(e);
    }
  }
}

