import 'walk_surface.dart';

enum SurfaceEdgeKind { jump, drop }

class SurfaceEdge {
  const SurfaceEdge({
    required this.to,
    required this.kind,
    required this.takeoffX,
    required this.landingX,
    required this.travelTicks,
    required this.cost,
  });

  final int to;
  final SurfaceEdgeKind kind;
  final double takeoffX;
  final double landingX;
  final int travelTicks;
  final double cost;
}

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

  final List<WalkSurface> surfaces;
  final List<int> edgeOffsets;
  final List<SurfaceEdge> edges;
  final Map<int, int> _indexById;

  int? indexOfSurfaceId(int id) => _indexById[id];

  Iterable<SurfaceEdge> edgesFor(int surfaceIndex) sync* {
    final start = edgeOffsets[surfaceIndex];
    final end = edgeOffsets[surfaceIndex + 1];
    for (var i = start; i < end; i += 1) {
      yield edges[i];
    }
  }
}

