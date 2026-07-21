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
  /// Creates one compiler-owned edge record.
  ///
  /// Endpoints, directions, joins, and bounds must be derived together by the
  /// terrain compiler; direct callers must preserve those invariants.
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

  /// Stable source lineage and canonical tie order.
  final TerrainEdgeId id;

  /// Directed start point in 1/1024-world-unit physics ticks.
  final TerrainPoint start;

  /// Directed end point in 1/1024-world-unit physics ticks.
  final TerrainPoint end;

  /// Quantized unit direction from [start] to [end].
  final TerrainDirection tangent;

  /// Quantized clockwise Y-down outward unit normal.
  final TerrainDirection outwardNormal;

  /// Physical sidedness, independent from semantic metadata.
  final TerrainCollisionMode collisionMode;

  /// Optional gameplay surface classifier retained without interpretation.
  final String? surfaceKind;

  /// Optional material classifier retained without interpretation.
  final String? materialKey;

  /// Compatible exposed edge entering [start], if one exists.
  final TerrainEdgeId? previousId;

  /// Compatible exposed edge leaving [end], if one exists.
  final TerrainEdgeId? nextId;

  /// Endpoint context at [start] for later ghost-vertex filtering.
  final TerrainVertexJoin startJoin;

  /// Endpoint context at [end] for later ghost-vertex filtering.
  final TerrainVertexJoin endJoin;

  /// Tight inclusive bounds in 1/1024-world-unit physics ticks.
  final TerrainAabb bounds;

  /// Directed horizontal span in physics ticks.
  int get dxTicks => end.xTicks - start.xTicks;

  /// Directed vertical span in physics ticks.
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
