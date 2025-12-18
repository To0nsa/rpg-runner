import 'entity_id.dart';
import 'world.dart';

typedef MovementQueryFn =
    void Function(EntityId e, int mi, int ti, int ii, int bi, int ci, int si);

typedef ColliderQueryFn =
    void Function(EntityId e, int ti, int bi, int coli, int aabbi);

class EcsQueries {
  static void forMovementBodies(EcsWorld world, MovementQueryFn fn) {
    final movement = world.movement;
    final entities = movement.denseEntities;

    for (var mi = 0; mi < entities.length; mi += 1) {
      final e = entities[mi];

      final ti = world.transform.tryIndexOf(e);
      if (ti == null) continue;
      final ii = world.playerInput.tryIndexOf(e);
      if (ii == null) continue;
      final bi = world.body.tryIndexOf(e);
      if (bi == null) continue;
      final ci = world.collision.tryIndexOf(e);
      if (ci == null) continue;
      final si = world.stamina.tryIndexOf(e);
      if (si == null) continue;

      fn(e, mi, ti, ii, bi, ci, si);
    }
  }

  static void forColliders(EcsWorld world, ColliderQueryFn fn) {
    final aabb = world.colliderAabb;
    final entities = aabb.denseEntities;

    for (var aabbi = 0; aabbi < entities.length; aabbi += 1) {
      final e = entities[aabbi];

      final ti = world.transform.tryIndexOf(e);
      if (ti == null) continue;
      final bi = world.body.tryIndexOf(e);
      if (bi == null) continue;
      final coli = world.collision.tryIndexOf(e);
      if (coli == null) continue;

      fn(e, ti, bi, coli, aabbi);
    }
  }
}
