/// Builds staged terrain render data from the same world geometry as collision.
library;

import '../collision/terrain/terrain_geometry.dart';
import '../collision/terrain/terrain_polygon.dart';
import '../snapshots/staged_terrain_render_snapshot.dart';
import 'staged_terrain_catalog.dart';
import 'staged_terrain_data.dart';

/// Converts generated triangle records into an immutable render candidate.
///
/// World-space vertices are read from a caller-supplied [TerrainGeometry], so
/// rendering cannot drift from collision through an independent transform or
/// polygon normalization. The only generator-specific facts consumed here are
/// its already-validated triangle indices and material metadata.
final class StagedTerrainRenderSnapshotBuilder {
  const StagedTerrainRenderSnapshotBuilder();

  /// Creates render polygons from [geometry].
  ///
  /// Every polygon must have exactly `vertexCount - 2` non-degenerate indexed
  /// triangles. A malformed generated triangle record blocks the complete
  /// candidate rather than allowing Flame to improvise a fill.
  StagedTerrainRenderSnapshot build({
    required Iterable<StagedTerrainChunkBinding> bindings,
    required TerrainGeometry geometry,
  }) {
    final bindingList = List<StagedTerrainChunkBinding>.of(bindings);
    final polygonsById = <TerrainSourceIdentity, TerrainPolygon>{
      for (final polygon in geometry.polygons) polygon.identity: polygon,
    };
    final trianglesById =
        <TerrainSourceIdentity, List<StagedTerrainTriangleData>>{};

    for (final binding in bindingList) {
      for (final triangle in binding.chunk.triangles) {
        final sourceId = binding.sourceIdentity(triangle.sourceId);
        final polygon = polygonsById[sourceId];
        if (polygon == null) {
          throw ArgumentError.value(
            triangle,
            'triangle',
            'Must reference a polygon in the same staged chunk binding.',
          );
        }
        _validateTriangle(triangle, polygon);
        (trianglesById[sourceId] ??= <StagedTerrainTriangleData>[]).add(
          triangle,
        );
      }
    }

    final renderPolygons = <StagedTerrainPolygonRenderSnapshot>[];
    for (final polygon in geometry.polygons) {
      final triangles =
          trianglesById[polygon.identity] ??
          const <StagedTerrainTriangleData>[];
      if (triangles.length != polygon.vertices.length - 2) {
        throw StateError(
          'Staged polygon ${polygon.identity.chunkKey}/'
          '${polygon.identity.shapeId} has ${triangles.length} triangles for '
          '${polygon.vertices.length} vertices.',
        );
      }
      triangles.sort(_compareTriangles);
      renderPolygons.add(
        StagedTerrainPolygonRenderSnapshot(
          sourceId: polygon.identity,
          vertices: polygon.vertices,
          triangles: triangles.map(
            (triangle) => StagedTerrainRenderTriangleSnapshot(
              first: triangle.first,
              second: triangle.second,
              third: triangle.third,
            ),
          ),
          materialKey: polygon.materialKey,
        ),
      );
    }
    return StagedTerrainRenderSnapshot(
      geometryVersion: geometry.version,
      polygons: renderPolygons,
    );
  }
}

void _validateTriangle(
  StagedTerrainTriangleData triangle,
  TerrainPolygon polygon,
) {
  final vertexCount = polygon.vertices.length;
  if (triangle.first >= vertexCount ||
      triangle.second >= vertexCount ||
      triangle.third >= vertexCount ||
      triangle.first == triangle.second ||
      triangle.second == triangle.third ||
      triangle.first == triangle.third) {
    throw ArgumentError.value(
      triangle,
      'triangle',
      'Must contain three distinct indices within the polygon vertex loop.',
    );
  }
}

int _compareTriangles(
  StagedTerrainTriangleData left,
  StagedTerrainTriangleData right,
) {
  var order = left.first.compareTo(right.first);
  if (order != 0) return order;
  order = left.second.compareTo(right.second);
  return order != 0 ? order : left.third.compareTo(right.third);
}
