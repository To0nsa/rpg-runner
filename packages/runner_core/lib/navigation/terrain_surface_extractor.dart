import '../collision/terrain/terrain_edge.dart';
import '../collision/terrain/terrain_edge_id.dart';
import '../collision/terrain/terrain_geometry.dart';
import '../collision/terrain/terrain_numeric.dart';
import 'types/terrain_navigation_surface.dart';

/// Extracts one canonical actor-neutral surface set from polygon terrain.
///
/// Extraction keeps every exposed upward-facing non-vertical segment,
/// including slopes that a particular enemy cannot traverse. Profile-specific
/// filtering belongs to graph construction and runtime support queries.
class TerrainSurfaceExtractor {
  const TerrainSurfaceExtractor();

  /// Builds a shared immutable set using [geometry.version] unchanged.
  TerrainSurfaceSet extract(TerrainGeometry geometry) {
    final edges = <TerrainEdge>[
      for (final edge in geometry.edges)
        if (edge.dxTicks > 0 && edge.outwardNormal.yTicks < 0) edge,
    ]..sort((left, right) => left.id.compareTo(right.id));
    if (edges.isEmpty) {
      return TerrainSurfaceSet(
        geometryVersion: geometry.version,
        surfaces: const <TerrainNavigationSurface>[],
      );
    }

    final startingAt = <TerrainPoint, List<int>>{};
    final endingAt = <TerrainPoint, List<int>>{};
    for (var index = 0; index < edges.length; index += 1) {
      startingAt.putIfAbsent(edges[index].start, () => <int>[]).add(index);
      endingAt.putIfAbsent(edges[index].end, () => <int>[]).add(index);
    }

    final proposedPrevious = List<int?>.filled(edges.length, null);
    final proposedNext = List<int?>.filled(edges.length, null);
    for (var index = 0; index < edges.length; index += 1) {
      proposedPrevious[index] = _uniqueCompatible(
        edges[index],
        endingAt[edges[index].start],
        edges,
      );
      proposedNext[index] = _uniqueCompatible(
        edges[index],
        startingAt[edges[index].end],
        edges,
      );
    }

    final previous = List<int?>.filled(edges.length, null);
    final next = List<int?>.filled(edges.length, null);
    for (var index = 0; index < edges.length; index += 1) {
      final previousIndex = proposedPrevious[index];
      if (previousIndex != null && proposedNext[previousIndex] == index) {
        previous[index] = previousIndex;
      }
      final nextIndex = proposedNext[index];
      if (nextIndex != null && proposedPrevious[nextIndex] == index) {
        next[index] = nextIndex;
      }
    }

    final parents = List<int>.generate(edges.length, (index) => index);
    for (var index = 0; index < edges.length; index += 1) {
      final nextIndex = next[index];
      if (nextIndex != null) _unionCanonical(parents, index, nextIndex);
    }
    final chainIdByRoot = <int, TerrainEdgeId>{};
    for (var index = 0; index < edges.length; index += 1) {
      final root = _findRoot(parents, index);
      final current = chainIdByRoot[root];
      if (current == null || edges[index].id.compareTo(current) < 0) {
        chainIdByRoot[root] = edges[index].id;
      }
    }

    final surfaces = <TerrainNavigationSurface>[];
    for (var index = 0; index < edges.length; index += 1) {
      final edge = edges[index];
      final previousIndex = previous[index];
      final nextIndex = next[index];
      surfaces.add(
        TerrainNavigationSurface(
          id: edge.id,
          start: edge.start,
          end: edge.end,
          tangent: edge.tangent,
          outwardNormal: edge.outwardNormal,
          collisionMode: edge.collisionMode,
          surfaceKind: edge.surfaceKind,
          materialKey: edge.materialKey,
          previousId: previousIndex == null ? null : edges[previousIndex].id,
          nextId: nextIndex == null ? null : edges[nextIndex].id,
          startKind: _endpointKind(edge, previousIndex, edges),
          endKind: _endpointKind(edge, nextIndex, edges),
          chainId: chainIdByRoot[_findRoot(parents, index)]!,
        ),
      );
    }

    return TerrainSurfaceSet(
      geometryVersion: geometry.version,
      surfaces: surfaces,
    );
  }
}

int? _uniqueCompatible(
  TerrainEdge edge,
  List<int>? candidates,
  List<TerrainEdge> edges,
) {
  if (candidates == null) return null;
  int? match;
  for (final candidateIndex in candidates) {
    final candidate = edges[candidateIndex];
    if (candidate.id == edge.id || !_isCompatible(edge, candidate)) continue;
    if (match != null) return null;
    match = candidateIndex;
  }
  return match;
}

bool _isCompatible(TerrainEdge left, TerrainEdge right) =>
    left.collisionMode == right.collisionMode &&
    left.surfaceKind == right.surfaceKind &&
    left.materialKey == right.materialKey;

TerrainSurfaceEndpointKind _endpointKind(
  TerrainEdge edge,
  int? adjacentIndex,
  List<TerrainEdge> edges,
) {
  if (adjacentIndex == null) return TerrainSurfaceEndpointKind.ledge;
  return edge.tangent == edges[adjacentIndex].tangent
      ? TerrainSurfaceEndpointKind.smooth
      : TerrainSurfaceEndpointKind.corner;
}

int _findRoot(List<int> parents, int index) {
  var root = index;
  while (parents[root] != root) {
    root = parents[root];
  }
  var current = index;
  while (parents[current] != current) {
    final next = parents[current];
    parents[current] = root;
    current = next;
  }
  return root;
}

void _unionCanonical(List<int> parents, int left, int right) {
  final leftRoot = _findRoot(parents, left);
  final rightRoot = _findRoot(parents, right);
  if (leftRoot == rightRoot) return;
  if (leftRoot < rightRoot) {
    parents[rightRoot] = leftRoot;
  } else {
    parents[leftRoot] = rightRoot;
  }
}
