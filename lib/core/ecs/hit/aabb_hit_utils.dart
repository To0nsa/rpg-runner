import '../../combat/faction.dart';
import '../entity_id.dart';
import '../world.dart';

/// Shared helpers for hit resolution math + filtering.
///
/// IMPORTANT:
/// - Keep these helpers allocation-free and deterministic.
/// - Systems still own iteration/selection rules (e.g. "first hit wins") until
///   Hit Resolution Module is fully unified.

/// Checks if two factions are allied.
///
/// Used for friendly-fire logic (skipping hits on allies).
bool areAllies(Faction a, Faction b) => a == b;

/// Per-tick cache of "damageable collider targets" to reduce repeated sparse
/// lookups in hot loops.
///
/// A target is included if it has:
/// - `HealthStore` (source list)
/// - `FactionStore` (for friendly-fire filtering)
/// - `TransformStore` + `ColliderAabbStore` (for overlap tests)
///
/// Determinism: preserves `HealthStore.denseEntities` iteration order.
class DamageableTargetCache {
  /// The [EntityId] of the target.
  final List<EntityId> entities = <EntityId>[];
  /// The [Faction] of the target.
  final List<Faction> factions = <Faction>[];

  // World-space collider center and half extents (Parallel arrays).
  final List<double> centerX = <double>[];
  final List<double> centerY = <double>[];
  final List<double> halfX = <double>[];
  final List<double> halfY = <double>[];

  int get length => entities.length;
  bool get isEmpty => entities.isEmpty;

  /// Rebuilds the cache by iterating directly over all entities with Health.
  ///
  /// This is an O(N) operation where N is the number of entities with Health,
  /// but it avoids O(log N) or hashing costs during the hot hit-check loop.
  void rebuild(EcsWorld world) {
    // 1. Reset state.
    entities.clear();
    factions.clear();
    centerX.clear();
    centerY.clear();
    halfX.clear();
    halfY.clear();

    final health = world.health;
    if (health.denseEntities.isEmpty) return;

    // 2. Iterate source (HealthStore) to find potential targets.
    for (var i = 0; i < health.denseEntities.length; i += 1) {
      final e = health.denseEntities[i];

      // 3. Filter: Must have Faction, Transform, and Collider.
      // (Using tryIndexOf avoids exception overhead for missing components)
      final fi = world.faction.tryIndexOf(e);
      if (fi == null) continue;
      final ti = world.transform.tryIndexOf(e);
      if (ti == null) continue;
      final aabbi = world.colliderAabb.tryIndexOf(e);
      if (aabbi == null) continue;

      // 4. Pre-calculate world-space AABB to save work during hit tests.
      // (Transform Pos + Collider Offset)
      final cx = world.transform.posX[ti] + world.colliderAabb.offsetX[aabbi];
      final cy = world.transform.posY[ti] + world.colliderAabb.offsetY[aabbi];

      // 5. Commit valid target to cache.
      entities.add(e);
      factions.add(world.faction.faction[fi]);
      centerX.add(cx);
      centerY.add(cy);
      halfX.add(world.colliderAabb.halfX[aabbi]);
      halfY.add(world.colliderAabb.halfY[aabbi]);
    }
  }
}

/// Checks strict overlap between two AABBs defined by Min/Max coordinates.
///
/// Returns true if they overlap. Touching edges does NOT count as overlap.
bool aabbOverlapsMinMax({
  required double aMinX,
  required double aMaxX,
  required double aMinY,
  required double aMaxY,
  required double bMinX,
  required double bMaxX,
  required double bMinY,
  required double bMaxY,
}) {
  // Classic Separating Axis Theorem (SAT):
  // Overlap exists if and only if ranges overlap on BOTH X and Y axes.
  // (Start of A < End of B) AND (End of A > Start of B)
  return aMinX < bMaxX && aMaxX > bMinX && aMinY < bMaxY && aMaxY > bMinY;
}

/// Checks strict overlap between two AABBs defined by Center/Half-Extents.
bool aabbOverlapsCenters({
  required double aCenterX,
  required double aCenterY,
  required double aHalfX,
  required double aHalfY,
  required double bCenterX,
  required double bCenterY,
  required double bHalfX,
  required double bHalfY,
}) {
  return aabbOverlapsMinMax(
    aMinX: aCenterX - aHalfX,
    aMaxX: aCenterX + aHalfX,
    aMinY: aCenterY - aHalfY,
    aMaxY: aCenterY + aHalfY,
    bMinX: bCenterX - bHalfX,
    bMaxX: bCenterX + bHalfX,
    bMinY: bCenterY - bHalfY,
    bMaxY: bCenterY + bHalfY,
  );
}

/// Helper that resolves entity indices to world components and checks overlap.
bool aabbOverlapsWorldColliders(
  EcsWorld world, {
  required int aTransformIndex,
  required int aAabbIndex,
  required int bTransformIndex,
  required int bAabbIndex,
}) {
  // 1. Resolve world-space AABB for Entity A.
  final aCenterX = world.transform.posX[aTransformIndex] +
      world.colliderAabb.offsetX[aAabbIndex];
  final aCenterY = world.transform.posY[aTransformIndex] +
      world.colliderAabb.offsetY[aAabbIndex];
  final aHalfX = world.colliderAabb.halfX[aAabbIndex];
  final aHalfY = world.colliderAabb.halfY[aAabbIndex];

  // 2. Resolve world-space AABB for Entity B.
  final bCenterX = world.transform.posX[bTransformIndex] +
      world.colliderAabb.offsetX[bAabbIndex];
  final bCenterY = world.transform.posY[bTransformIndex] +
      world.colliderAabb.offsetY[bAabbIndex];
  final bHalfX = world.colliderAabb.halfX[bAabbIndex];
  final bHalfY = world.colliderAabb.halfY[bAabbIndex];

  // 3. Check overlap.
  return aabbOverlapsCenters(
    aCenterX: aCenterX,
    aCenterY: aCenterY,
    aHalfX: aHalfX,
    aHalfY: aHalfY,
    bCenterX: bCenterX,
    bCenterY: bCenterY,
    bHalfX: bHalfX,
    bHalfY: bHalfY,
  );
}
