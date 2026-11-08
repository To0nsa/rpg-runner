import '../abilities/blink_mobility_def.dart';
import '../collision/terrain/capsule_segment_kernel.dart';
import '../collision/terrain/terrain_edge_id.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_polygon.dart';
import '../collision/terrain/terrain_traversal_profile.dart';
import 'terrain_placement_query.dart';

/// Selects the first solid blocker along a horizontal full-capsule sweep.
/// Only the destination is committed: intermediate terrain is crossed by blink.
TerrainPoint? resolveTerrainBlink({
  required TerrainPlacementQuery placement,
  required TerrainPoint origin,
  required TerrainPlacementCapsule capsule,
  required TerrainTraversalProfile profile,
  required int direction,
  required BlinkMobilityDef blink,
}) {
  assert(direction == -1 || direction == 1);
  final distance = physicsCoordinateToTicks(blink.openDistance);
  final kernel = CapsuleSegmentKernel();
  final hit = CapsuleSweepHit();
  TerrainEdgeId? first;
  var firstTime = double.infinity;
  // Geometry edges have stable source order, including equal-time contacts.
  for (final edge in placement.geometry.edges) {
    if (edge.collisionMode != TerrainCollisionMode.solid) continue;
    kernel.sweepAtCenter(
      centerXTicks: origin.xTicks + capsule.resolvedOffsetXTicks,
      centerYTicks: origin.yTicks + capsule.offsetYTicks,
      radiusTicks: capsule.radiusTicks,
      verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      displacementXTicks: direction * distance,
      displacementYTicks: 0,
      edge: edge,
      out: hit,
    );
    // Tangential floor contact does not obstruct a horizontal blink.
    if (!hit.hit || hit.normalXTicks * direction >= 0) continue;
    if (hit.timeOfImpact < firstTime) {
      firstTime = hit.timeOfImpact;
      first = edge.id;
    }
  }
  var targetX = origin.xTicks + direction * distance;
  if (first != null) {
    if (firstTime * distance >
        physicsCoordinateToTicks(blink.maxApproachDistance) +
            terrainContactEpsilonTicks) {
      return null;
    }
    TerrainPolygon? obstacle;
    for (final polygon in placement.geometry.polygons) {
      final id = polygon.identity;
      if (id.chunkIndex == first.chunkIndex &&
          id.chunkKey == first.chunkKey &&
          id.placementKey == first.placementKey &&
          id.shapeId == first.shapeId) {
        obstacle = polygon;
        break;
      }
    }
    if (obstacle == null) return null;
    final bounds = obstacle.bounds;
    if (bounds.maxX - bounds.minX >
        physicsCoordinateToTicks(blink.maxObstacleWidth)) {
      return null;
    }
    final farX = direction > 0 ? bounds.maxX : bounds.minX;
    targetX =
        farX +
        direction *
            (capsule.radiusTicks +
                physicsCoordinateToTicks(blink.exitClearance)) -
        capsule.resolvedOffsetXTicks;
    if ((targetX - origin.xTicks) * direction <= 0) return null;
  }
  final target = TerrainPoint(targetX, origin.yTicks);
  final result = placement.validateClearance(
    TerrainClearancePlacementRequest(
      bodyCenter: target,
      capsule: capsule,
      traversalProfile: profile,
      oneWayClearancePolicy: TerrainOneWayClearancePolicy.ignore,
      expectedGeometryVersion: placement.geometry.version,
    ),
  );
  return placement.canCommit(result) ? target : null;
}
