import 'package:meta/meta.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';

import 'chunk_v2_collision_expansion.dart';

/// Read-only Core edge plus its Core-derived traversal measurement.
@immutable
final class ChunkV2CompiledEdgeInspection {
  const ChunkV2CompiledEdgeInspection({
    required this.edge,
    required this.absoluteSlopeAngleUnits,
  });

  final TerrainEdge edge;
  final int absoluteSlopeAngleUnits;
}

/// Resolves exact compiled facts for [edgeId] from one immutable expansion.
ChunkV2CompiledEdgeInspection? inspectChunkV2CompiledEdge(
  ChunkV2CollisionExpansion expansion,
  TerrainEdgeId? edgeId,
) {
  if (edgeId == null) return null;
  final edge = expansion.geometry.edgeById[edgeId];
  if (edge == null) return null;
  return ChunkV2CompiledEdgeInspection(
    edge: edge,
    absoluteSlopeAngleUnits:
        expansion.traversalCache[edgeId].absoluteSlopeAngleUnits,
  );
}

/// Selects the nearest compiled finite edge within a world-space radius.
///
/// This is an editor selection rule only. It reads Core edges and resolves
/// equal distances by canonical edge ID; it never reconstructs collision.
TerrainEdgeId? hitTestChunkV2CompiledEdge({
  required ChunkV2CollisionExpansion expansion,
  required double worldX,
  required double worldY,
  required double radiusWorld,
}) {
  if (!worldX.isFinite || !worldY.isFinite) {
    throw ArgumentError('Compiled-edge hit point must be finite.');
  }
  if (!radiusWorld.isFinite || radiusWorld < 0) {
    throw ArgumentError.value(
      radiusWorld,
      'radiusWorld',
      'Must be finite and non-negative.',
    );
  }
  final pointX = worldX * terrainPhysicsTicksPerWorldUnit;
  final pointY = worldY * terrainPhysicsTicksPerWorldUnit;
  final maximumDistanceSquared =
      radiusWorld *
      radiusWorld *
      terrainPhysicsTicksPerWorldUnit *
      terrainPhysicsTicksPerWorldUnit;
  TerrainEdge? best;
  var bestDistanceSquared = double.infinity;
  for (final edge in expansion.geometry.edges) {
    final distanceSquared = _distanceSquaredToEdge(pointX, pointY, edge);
    if (distanceSquared > maximumDistanceSquared) continue;
    if (best == null ||
        distanceSquared < bestDistanceSquared ||
        (distanceSquared == bestDistanceSquared &&
            edge.id.compareTo(best.id) < 0)) {
      best = edge;
      bestDistanceSquared = distanceSquared;
    }
  }
  return best?.id;
}

double _distanceSquaredToEdge(double x, double y, TerrainEdge edge) {
  final startX = edge.start.xTicks.toDouble();
  final startY = edge.start.yTicks.toDouble();
  final dx = edge.dxTicks.toDouble();
  final dy = edge.dyTicks.toDouble();
  final lengthSquared = dx * dx + dy * dy;
  final projection = ((x - startX) * dx + (y - startY) * dy) / lengthSquared;
  final t = projection.clamp(0.0, 1.0);
  final nearestX = startX + dx * t;
  final nearestY = startY + dy * t;
  final distanceX = x - nearestX;
  final distanceY = y - nearestY;
  return distanceX * distanceX + distanceY * distanceY;
}
