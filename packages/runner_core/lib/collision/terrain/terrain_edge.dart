import 'terrain_edge_id.dart';
import 'terrain_numeric.dart';
import 'terrain_polygon.dart';

/// Endpoint context retained for later ghost-vertex collision filtering.
enum TerrainVertexJoin {
  /// No compatible adjacent exposed edge exists.
  exposed,

  /// An adjacent edge exists and forms a geometric corner.
  connected,

  /// An adjacent edge continues in the same quantized direction.
  smooth,
}

/// Immutable exposed collision segment compiled from canonical terrain.
class TerrainEdge {
  const TerrainEdge({
    required this.id,
    required this.start,
    required this.end,
    required this.tangent,
    required this.outwardNormal,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
    required this.previousId,
    required this.nextId,
    required this.startJoin,
    required this.endJoin,
    required this.bounds,
  });

  final TerrainEdgeId id;
  final TerrainPoint start;
  final TerrainPoint end;
  final TerrainDirection tangent;
  final TerrainDirection outwardNormal;
  final TerrainCollisionMode collisionMode;
  final String? surfaceKind;
  final String? materialKey;
  final TerrainEdgeId? previousId;
  final TerrainEdgeId? nextId;
  final TerrainVertexJoin startJoin;
  final TerrainVertexJoin endJoin;
  final TerrainAabb bounds;

  int get dxTicks => end.xTicks - start.xTicks;
  int get dyTicks => end.yTicks - start.yTicks;

  @override
  bool operator ==(Object other) =>
      other is TerrainEdge &&
      id == other.id &&
      start == other.start &&
      end == other.end &&
      tangent == other.tangent &&
      outwardNormal == other.outwardNormal &&
      collisionMode == other.collisionMode &&
      surfaceKind == other.surfaceKind &&
      materialKey == other.materialKey &&
      previousId == other.previousId &&
      nextId == other.nextId &&
      startJoin == other.startJoin &&
      endJoin == other.endJoin &&
      bounds.minX == other.bounds.minX &&
      bounds.minY == other.bounds.minY &&
      bounds.maxX == other.bounds.maxX &&
      bounds.maxY == other.bounds.maxY;

  /// Object hashes are suitable for collections, never deterministic digests.
  @override
  int get hashCode => Object.hash(
    id,
    start,
    end,
    tangent,
    outwardNormal,
    collisionMode,
    surfaceKind,
    materialKey,
    previousId,
    nextId,
    startJoin,
    endJoin,
    bounds.minX,
    bounds.minY,
    bounds.maxX,
    bounds.maxY,
  );
}
