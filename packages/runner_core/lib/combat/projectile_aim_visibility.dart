import '../collision/terrain/terrain_edge_index.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_polygon.dart';
import '../collision/terrain/terrain_query_buffer.dart';

/// Checks auto-aim sight against the currently published terrain edge index.
///
/// The query buffer is reused while the index is unchanged. A streamed terrain
/// publication replaces the buffer together with its index at the next query.
final class ProjectileAimVisibility {
  ProjectileAimVisibility(this._indexProvider);

  final TerrainEdgeIndex Function() _indexProvider;
  TerrainEdgeIndex? _index;
  TerrainQueryBuffer? _buffer;

  /// Whether a straight shot from the launch point to the predicted target is
  /// unobstructed by a solid edge or the blocking side of a one-way edge.
  bool isClear(double fromX, double fromY, double toX, double toY) {
    final index = _indexProvider();
    if (!identical(index, _index)) {
      _index = index;
      _buffer = index.createQueryBuffer();
    }
    final buffer = _buffer!;
    final startX = physicsCoordinateToTicks(fromX);
    final startY = physicsCoordinateToTicks(fromY);
    final endX = physicsCoordinateToTicks(toX);
    final endY = physicsCoordinateToTicks(toY);
    index.queryBounds(
      minX: startX < endX ? startX : endX,
      minY: startY < endY ? startY : endY,
      maxX: startX > endX ? startX : endX,
      maxY: startY > endY ? startY : endY,
      buffer: buffer,
    );

    final rayX = endX - startX;
    final rayY = endY - startY;
    for (var i = 0; i < buffer.candidateCount; i += 1) {
      final edge = buffer.edgeAt(i, index.edges);
      if (edge.collisionMode == TerrainCollisionMode.oneWay) {
        final startSide =
            (startX - edge.start.xTicks) * edge.outwardNormal.xTicks +
            (startY - edge.start.yTicks) * edge.outwardNormal.yTicks;
        final directionDot =
            rayX * edge.outwardNormal.xTicks + rayY * edge.outwardNormal.yTicks;
        if (startSide < -terrainContactEpsilonTicks * terrainDirectionScale ||
            directionDot >= 0) {
          continue;
        }
      }

      final edgeX = edge.end.xTicks - edge.start.xTicks;
      final edgeY = edge.end.yTicks - edge.start.yTicks;
      var denominator = rayX * edgeY - rayY * edgeX;
      if (denominator == 0) continue;
      final offsetX = edge.start.xTicks - startX;
      final offsetY = edge.start.yTicks - startY;
      var rayNumerator = offsetX * edgeY - offsetY * edgeX;
      var edgeNumerator = offsetX * rayY - offsetY * rayX;
      if (denominator < 0) {
        denominator = -denominator;
        rayNumerator = -rayNumerator;
        edgeNumerator = -edgeNumerator;
      }
      // The launch and target points may touch terrain; only an edge strictly
      // between them hides the target. Edge endpoints still block the sightline.
      if (rayNumerator > 0 &&
          rayNumerator < denominator &&
          edgeNumerator >= 0 &&
          edgeNumerator <= denominator) {
        return false;
      }
    }
    return true;
  }
}
