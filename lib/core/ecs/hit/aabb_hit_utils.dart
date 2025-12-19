import '../../combat/faction.dart';
import '../world.dart';

// Shared helpers for hit resolution math + filtering.
//
// IMPORTANT:
// - Keep these helpers allocation-free and deterministic.
// - Systems still own iteration/selection rules (e.g. "first hit wins") until
//   Milestone 9 (Hit Resolution Module).

bool isFriendlyFire(Faction a, Faction b) => a == b;

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

