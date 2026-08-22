/// Builds staged terrain render data paired with published collision geometry.
library;

import '../collision/terrain/terrain_geometry.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_polygon.dart';
import '../snapshots/staged_terrain_render_snapshot.dart';
import 'staged_terrain_catalog.dart';
import 'staged_terrain_data.dart';
import 'staged_terrain_world_geometry.dart';

/// Converts generated terrain records into an immutable render candidate.
///
/// Every collidable polygon must exactly match caller-supplied
/// [TerrainGeometry]. Direct Chunk polygons become terrain fills, including
/// render-only roles; placed Prefab polygons are verified for collision but
/// excluded from fills and material edges because their sprites own visuals.
final class StagedTerrainRenderSnapshotBuilder {
  const StagedTerrainRenderSnapshotBuilder();

  /// Creates render polygons from staged records and collision [geometry].
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
    final stagedPolygonsById =
        <
          TerrainSourceIdentity,
          (StagedTerrainChunkBinding, StagedTerrainPolygonData)
        >{};
    final trianglesById =
        <TerrainSourceIdentity, List<StagedTerrainTriangleData>>{};

    for (final binding in bindingList) {
      for (final polygon in binding.chunk.polygons) {
        final sourceId = binding.sourceIdentity(polygon.id);
        if (stagedPolygonsById.containsKey(sourceId)) {
          throw ArgumentError.value(
            bindings,
            'bindings',
            'Staged render polygon identities must be unique.',
          );
        }
        stagedPolygonsById[sourceId] = (binding, polygon);
      }
      for (final triangle in binding.chunk.triangles) {
        if (triangle.sourceId.placementKey != null) {
          throw ArgumentError.value(
            triangle,
            'triangle',
            'Placed Prefab collision cannot own terrain render triangles.',
          );
        }
        final sourceId = binding.sourceIdentity(triangle.sourceId);
        final staged = stagedPolygonsById[sourceId];
        if (staged == null) {
          throw ArgumentError.value(
            triangle,
            'triangle',
            'Must reference a staged polygon in the same chunk binding.',
          );
        }
        _validateTriangle(triangle, staged.$2.vertices.length);
        (trianglesById[sourceId] ??= <StagedTerrainTriangleData>[]).add(
          triangle,
        );
      }
    }

    final renderPolygons = <StagedTerrainPolygonRenderSnapshot>[];
    final orderedIds = stagedPolygonsById.keys.toList()..sort();
    final consumedCollisionIds = <TerrainSourceIdentity>{};
    for (final sourceId in orderedIds) {
      final staged = stagedPolygonsById[sourceId]!;
      final binding = staged.$1;
      final record = staged.$2;
      final collisionPolygon = polygonsById[sourceId];
      final vertices = record.vertices
          .map(
            (point) => TerrainPoint(
              point.xTicks + binding.worldOriginXTicks,
              point.yTicks,
            ),
          )
          .toList(growable: false);
      if (record.collisionMode == StagedTerrainCollisionMode.none) {
        if (collisionPolygon != null) {
          throw StateError(
            'Render-only staged polygon ${sourceId.chunkKey}/'
            '${sourceId.shapeId} entered collision geometry.',
          );
        }
      } else {
        if (collisionPolygon == null) {
          throw StateError(
            'Collidable staged polygon ${sourceId.chunkKey}/'
            '${sourceId.shapeId} is missing from collision geometry.',
          );
        }
        _validateCollisionPolygon(record, collisionPolygon, vertices);
        consumedCollisionIds.add(sourceId);
      }
      final triangles =
          trianglesById[sourceId] ?? const <StagedTerrainTriangleData>[];
      if (sourceId.placementKey != null) {
        if (record.collisionMode == StagedTerrainCollisionMode.none ||
            triangles.isNotEmpty) {
          throw StateError(
            'Placed Prefab polygon ${sourceId.chunkKey}/${sourceId.shapeId} '
            'must be collision-only.',
          );
        }
        continue;
      }
      if (triangles.length != vertices.length - 2) {
        throw StateError(
          'Staged polygon ${sourceId.chunkKey}/${sourceId.shapeId} has '
          '${triangles.length} triangles for ${vertices.length} vertices.',
        );
      }
      triangles.sort(_compareTriangles);
      renderPolygons.add(
        StagedTerrainPolygonRenderSnapshot(
          sourceId: sourceId,
          vertices: vertices,
          triangles: triangles.map(
            (triangle) => StagedTerrainRenderTriangleSnapshot(
              first: triangle.first,
              second: triangle.second,
              third: triangle.third,
            ),
          ),
          materialKey: record.materialKey,
        ),
      );
    }
    if (consumedCollisionIds.length != polygonsById.length) {
      final unmatched = polygonsById.keys
          .where((sourceId) => !consumedCollisionIds.contains(sourceId))
          .first;
      throw StateError(
        'Collision polygon ${unmatched.chunkKey}/${unmatched.shapeId} has no '
        'matching staged render record.',
      );
    }
    final renderEdges = const StagedTerrainWorldGeometryBuilder()
        .buildRenderEdges(bindings: bindingList);
    final renderIds = renderPolygons.map((polygon) => polygon.sourceId).toSet();
    for (final edge in renderEdges) {
      final id = edge.id;
      final sourceId = TerrainSourceIdentity(
        chunkIndex: id.chunkIndex,
        chunkKey: id.chunkKey,
        placementKey: id.placementKey,
        shapeId: id.shapeId,
      );
      if (!renderIds.contains(sourceId)) {
        throw StateError(
          'Terrain render edge $id has no matching direct terrain fill.',
        );
      }
    }
    return StagedTerrainRenderSnapshot(
      geometryVersion: geometry.version,
      polygons: renderPolygons,
      edges: renderEdges,
    );
  }
}

void _validateTriangle(StagedTerrainTriangleData triangle, int vertexCount) {
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

void _validateCollisionPolygon(
  StagedTerrainPolygonData record,
  TerrainPolygon polygon,
  List<TerrainPoint> vertices,
) {
  final expectedMode = switch (record.collisionMode) {
    StagedTerrainCollisionMode.solid => TerrainCollisionMode.solid,
    StagedTerrainCollisionMode.oneWay => TerrainCollisionMode.oneWay,
    StagedTerrainCollisionMode.none => throw StateError(
      'Render-only staged polygon reached collision validation.',
    ),
  };
  if (polygon.sourcePath != record.sourcePath ||
      polygon.collisionMode != expectedMode ||
      polygon.surfaceKind != record.surfaceKind ||
      polygon.materialKey != record.materialKey ||
      polygon.sourceVertices.length != record.sourceVertices.length ||
      polygon.vertices.length != vertices.length) {
    throw StateError(
      'Staged polygon ${polygon.identity.chunkKey}/'
      '${polygon.identity.shapeId} does not match collision geometry.',
    );
  }
  for (var index = 0; index < record.sourceVertices.length; index += 1) {
    final staged = record.sourceVertices[index];
    final compiled = polygon.sourceVertices[index];
    if (compiled.xTicks != staged.xTicks || compiled.yTicks != staged.yTicks) {
      throw StateError(
        'Staged polygon ${polygon.identity.chunkKey}/'
        '${polygon.identity.shapeId} source vertex $index drifted from '
        'collision.',
      );
    }
  }
  for (var index = 0; index < vertices.length; index += 1) {
    if (polygon.vertices[index] != vertices[index]) {
      throw StateError(
        'Staged polygon ${polygon.identity.chunkKey}/'
        '${polygon.identity.shapeId} vertex $index drifted from collision.',
      );
    }
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
