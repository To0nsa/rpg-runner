import '../../combat/faction.dart';
import '../entity_id.dart';
import '../world.dart';

// Shared helpers for hit resolution math + filtering.
//
// IMPORTANT:
// - Keep these helpers allocation-free and deterministic.
// - Systems still own iteration/selection rules (e.g. "first hit wins") until
//   Milestone 10 (Hit Resolution Module).

bool areAllies(Faction a, Faction b) => a == b;

/// Per-tick cache of "damageable collider targets" to reduce repeated sparse
/// lookups in hot loops.
///
/// A target is included iff it has:
/// - `HealthStore` (source list)
/// - `FactionStore` (for friendly-fire filtering)
/// - `TransformStore` + `ColliderAabbStore` (for overlap tests)
///
/// Determinism: preserves `HealthStore.denseEntities` iteration order.
class DamageableTargetCache {
  final List<EntityId> entities = <EntityId>[];
  final List<Faction> factions = <Faction>[];

  // World-space collider center and half extents.
  final List<double> centerX = <double>[];
  final List<double> centerY = <double>[];
  final List<double> halfX = <double>[];
  final List<double> halfY = <double>[];

  int get length => entities.length;
  bool get isEmpty => entities.isEmpty;

  void rebuild(EcsWorld world) {
    entities.clear();
    factions.clear();
    centerX.clear();
    centerY.clear();
    halfX.clear();
    halfY.clear();

    final health = world.health;
    if (health.denseEntities.isEmpty) return;

    for (var i = 0; i < health.denseEntities.length; i += 1) {
      final e = health.denseEntities[i];

      final fi = world.faction.tryIndexOf(e);
      if (fi == null) continue;
      final ti = world.transform.tryIndexOf(e);
      if (ti == null) continue;
      final aabbi = world.colliderAabb.tryIndexOf(e);
      if (aabbi == null) continue;

      final cx = world.transform.posX[ti] + world.colliderAabb.offsetX[aabbi];
      final cy = world.transform.posY[ti] + world.colliderAabb.offsetY[aabbi];

      entities.add(e);
      factions.add(world.faction.faction[fi]);
      centerX.add(cx);
      centerY.add(cy);
      halfX.add(world.colliderAabb.halfX[aabbi]);
      halfY.add(world.colliderAabb.halfY[aabbi]);
    }
  }
}

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
  return aMinX < bMaxX && aMaxX > bMinX && aMinY < bMaxY && aMaxY > bMinY;
}

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

/// AABB overlap between two entities whose AABBs are defined by
/// `Transform` + `ColliderAabb`.
bool aabbOverlapsWorldColliders(
  EcsWorld world, {
  required int aTransformIndex,
  required int aAabbIndex,
  required int bTransformIndex,
  required int bAabbIndex,
}) {
  final aCenterX = world.transform.posX[aTransformIndex] +
      world.colliderAabb.offsetX[aAabbIndex];
  final aCenterY = world.transform.posY[aTransformIndex] +
      world.colliderAabb.offsetY[aAabbIndex];
  final aHalfX = world.colliderAabb.halfX[aAabbIndex];
  final aHalfY = world.colliderAabb.halfY[aAabbIndex];

  final bCenterX = world.transform.posX[bTransformIndex] +
      world.colliderAabb.offsetX[bAabbIndex];
  final bCenterY = world.transform.posY[bTransformIndex] +
      world.colliderAabb.offsetY[bAabbIndex];
  final bHalfX = world.colliderAabb.halfX[bAabbIndex];
  final bHalfY = world.colliderAabb.halfY[bAabbIndex];

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
