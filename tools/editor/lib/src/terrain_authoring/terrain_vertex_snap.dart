import 'terrain_polygon_scene_projection.dart';
import 'terrain_source_models.dart';

/// Finds an exact vertex within the visual hit radius, expressed in half pixels.
/// Equal-distance candidates retain the caller's canonical vertex order.
TerrainSourceVertexDef? nearestTerrainVertex(
  Iterable<TerrainSourceVertexDef> vertices,
  TerrainPolygonScenePoint point, {
  required double radiusHalfPixels,
}) {
  final maximumDistanceSquared = radiusHalfPixels * radiusHalfPixels;
  TerrainSourceVertexDef? closest;
  var closestDistanceSquared = double.infinity;
  for (final vertex in vertices) {
    final dx = vertex.xHalfPixels - point.xHalfPixels;
    final dy = vertex.yHalfPixels - point.yHalfPixels;
    final distanceSquared = dx * dx + dy * dy;
    if (distanceSquared > maximumDistanceSquared ||
        distanceSquared >= closestDistanceSquared) {
      continue;
    }
    closest = vertex;
    closestDistanceSquared = distanceSquared;
  }
  return closest;
}
