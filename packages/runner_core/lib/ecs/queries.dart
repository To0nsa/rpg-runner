import 'entity_id.dart';
import 'world.dart';

/// Callback signature for iterating over entities with movement-related components.
///
/// [e] is the Entity ID.
/// [mi], [ti], [ii], [bi] are the **dense indices** for:
/// - [mi]: MovementStore
/// - [ti]: TransformStore
/// - [ii]: PlayerInputStore
/// - [bi]: BodyStore
typedef MovementQueryFn =
    void Function(EntityId e, int mi, int ti, int ii, int bi);

/// Callback signature for iterating over entities with collision-related components.
///
/// [e] is the Entity ID.
/// [ti], [bi], [coli], [aabbi] are the **dense indices** for:
/// - [ti]: TransformStore
/// - [bi]: BodyStore
/// - [coli]: CollisionStateStore
/// - [aabbi]: ColliderAabbStore
typedef ColliderQueryFn =
    void Function(EntityId e, int ti, int bi, int coli, int aabbi);

/// Provides optimized iteration methods for groups of components used in common systems.
///
/// These static methods perform "joins" across multiple component stores. They iterate
/// efficiently by driving the loop with the "primary" store (usually the one expected
/// to have the fewest entities or the one we want to iterate linearly) and checking
/// for the presence of other required components.
class EcsQueries {
  /// Iterates over all entities that have [MovementStore], [TransformStore],
  /// [PlayerInputStore], and [BodyStore].
  ///
  /// This query is typically used by the [MovementSystem] to process player movement.
  /// It effectively filters for "controllable physics bodies".
  static void forMovementBodies(EcsWorld world, MovementQueryFn fn) {
    // We drive iteration with the MovementStore.
    final movement = world.movement;
    final entities = movement.denseEntities;

    for (var mi = 0; mi < entities.length; mi += 1) {
      final e = entities[mi];

      // Check existence and get indices for all other required components.
      final ti = world.transform.tryIndexOf(e);
      if (ti == null) continue;
      final ii = world.playerInput.tryIndexOf(e);
      if (ii == null) continue;
      final bi = world.body.tryIndexOf(e);
      if (bi == null) continue;

      fn(e, mi, ti, ii, bi);
    }
  }

  /// Iterates over all entities that have [ColliderAabbStore], [TransformStore],
  /// [BodyStore], and [CollisionStateStore].
  ///
  /// This query finds all physical objects that can collide. It is used by the
  /// [CollisionSystem] to resolve physics interactions.
  static void forColliders(EcsWorld world, ColliderQueryFn fn) {
    // Drive iteration with the ColliderAabbStore.
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
