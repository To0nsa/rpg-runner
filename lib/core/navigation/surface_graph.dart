import 'walk_surface.dart';

/// The type of transition between two surfaces.
enum SurfaceEdgeKind {
  /// An active jump (requires jump input).
  jump,
  
  /// A passive drop (walking off an edge).
  drop,
}

/// A directed edge in the navigation graph.
///
/// Represents a traversable connection from one [WalkSurface] to another.
class SurfaceEdge {
  const SurfaceEdge({
    required this.to,
    required this.kind,
    required this.takeoffX,
    required this.landingX,
    required this.travelTicks,
    required this.cost,
  });

  /// Index of the destination surface in [SurfaceGraph.surfaces].
  final int to;
  
  /// Type of traversal (Jump or Drop).
  final SurfaceEdgeKind kind;
  
  /// World X coordinate where the entity leaves the source surface.
  final double takeoffX;
  
  /// World X coordinate where the entity lands on the destination surface.
  final double landingX;
  
  /// Estimated travel time in simulation ticks.
  final int travelTicks;
  
  /// Pathfinding cost (typically based on time or distance).
  final double cost;
}

/// An immutable navigation graph built from [WalkSurface]s.
///
/// **Structure**:
/// - **Nodes**: [surfaces] (indexed 0..N-1).
/// - **Edges**: Stored in [edges], with [edgeOffsets] providing CSR-style indexing.
///
/// **CSR (Compressed Sparse Row) Format**:
/// - `edgeOffsets[i]` is the start index in [edges] for surface `i`.
/// - `edgeOffsets[i+1]` is the end index (exclusive).
/// - This allows O(1) lookup of outgoing edges for any surface.
class SurfaceGraph {
  SurfaceGraph({
    required List<WalkSurface> surfaces,
    required List<int> edgeOffsets,
    required List<SurfaceEdge> edges,
    required Map<int, int> indexById,
  })  : surfaces = List<WalkSurface>.unmodifiable(surfaces),
        edgeOffsets = List<int>.unmodifiable(edgeOffsets),
        edges = List<SurfaceEdge>.unmodifiable(edges),
        _indexById = Map<int, int>.unmodifiable(indexById);

  /// All walkable surfaces (graph nodes).
  final List<WalkSurface> surfaces;
  
  /// CSR row pointers into [edges]. Length = surfaces.length + 1.
  final List<int> edgeOffsets;
  
  /// All edges (graph arcs), grouped by source surface.
  final List<SurfaceEdge> edges;
  
  /// Lookup: Surface ID -> index in [surfaces].
  final Map<int, int> _indexById;

  /// Returns the index of a surface by its packed [id], or null if not found.
  int? indexOfSurfaceId(int id) => _indexById[id];

  /// Yields all outgoing edges from [surfaceIndex].
  Iterable<SurfaceEdge> edgesFor(int surfaceIndex) sync* {
    final start = edgeOffsets[surfaceIndex];
    final end = edgeOffsets[surfaceIndex + 1];
    for (var i = start; i < end; i += 1) {
      yield edges[i];
    }
  }
}

