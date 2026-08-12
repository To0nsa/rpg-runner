/// Converts admitted staged terrain records into one world-space Core geometry.
library;

import '../collision/terrain/terrain_edge.dart';
import '../collision/terrain/terrain_edge_id.dart';
import '../collision/terrain/terrain_geometry.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_polygon.dart';
import 'staged_terrain_catalog.dart';
import 'staged_terrain_data.dart';

/// Builds immutable world-space terrain from selected staged chunk instances.
///
/// The generated artifact already owns canonicalization, exposed-edge
/// selection, triangulation, and semantic verification. This adapter only
/// rehydrates stable streamed instance identity and translates local physics
/// X coordinates. It rejects malformed record references rather than
/// recompiling or silently repairing generated terrain.
final class StagedTerrainWorldGeometryBuilder {
  const StagedTerrainWorldGeometryBuilder();

  /// Creates one canonical world-space geometry publication candidate.
  ///
  /// [geometryVersion] is assigned by the future tick-boundary publisher, not
  /// by generated source. Bindings must have distinct streamed indices so
  /// equal chunk selections remain distinguishable in collision tie-breaks.
  TerrainGeometry build({
    required Iterable<StagedTerrainChunkBinding> bindings,
    required int geometryVersion,
  }) {
    if (geometryVersion < 0) {
      throw ArgumentError.value(
        geometryVersion,
        'geometryVersion',
        'Must be non-negative.',
      );
    }
    final orderedBindings = List<StagedTerrainChunkBinding>.of(bindings)
      ..sort((left, right) => left.chunkIndex.compareTo(right.chunkIndex));
    for (var index = 1; index < orderedBindings.length; index += 1) {
      if (orderedBindings[index - 1].chunkIndex ==
          orderedBindings[index].chunkIndex) {
        throw ArgumentError.value(
          bindings,
          'bindings',
          'Streamed chunk indices must be unique.',
        );
      }
    }

    final polygons = <TerrainPolygon>[];
    final edges = <TerrainEdge>[];
    for (final binding in orderedBindings) {
      for (final polygon in binding.chunk.polygons) {
        polygons.add(_buildPolygon(binding, polygon));
      }
      for (final edge in binding.chunk.edges) {
        edges.add(_buildEdge(binding, edge));
      }
    }
    return TerrainGeometry(
      version: geometryVersion,
      polygons: polygons,
      edges: edges,
    );
  }

  TerrainPolygon _buildPolygon(
    StagedTerrainChunkBinding binding,
    StagedTerrainPolygonData polygon,
  ) {
    _requireNonEmpty(polygon.sourcePath, 'polygon.sourcePath');
    final identity = binding.sourceIdentity(polygon.id);
    if (polygon.sourceVertices.length < 3 ||
        polygon.vertices.length != polygon.sourceVertices.length) {
      throw ArgumentError.value(
        polygon,
        'polygon',
        'Staged polygons require matching source/physics loops with at least '
            'three vertices.',
      );
    }
    return TerrainPolygon(
      sourcePath: polygon.sourcePath,
      identity: identity,
      sourceVertices: polygon.sourceVertices.map(
        (point) => SourceTerrainPoint(point.xTicks, point.yTicks),
      ),
      vertices: polygon.vertices.map((point) => _worldPoint(binding, point)),
      collisionMode: _collisionMode(polygon.collisionMode),
      surfaceKind: polygon.surfaceKind,
      materialKey: polygon.materialKey,
    );
  }

  TerrainEdge _buildEdge(
    StagedTerrainChunkBinding binding,
    StagedTerrainEdgeData edge,
  ) {
    final start = _worldPoint(binding, edge.start);
    final end = _worldPoint(binding, edge.end);
    if (start == end) {
      throw ArgumentError.value(
        edge,
        'edge',
        'Staged exposed edges must have distinct endpoints.',
      );
    }
    return TerrainEdge(
      id: _edgeId(binding, edge.id),
      start: start,
      end: end,
      tangent: TerrainDirection(edge.tangent.xTicks, edge.tangent.yTicks),
      outwardNormal: TerrainDirection(
        edge.outwardNormal.xTicks,
        edge.outwardNormal.yTicks,
      ),
      collisionMode: _collisionMode(edge.collisionMode),
      surfaceKind: edge.surfaceKind,
      materialKey: edge.materialKey,
      previousId: edge.previousId == null
          ? null
          : _edgeId(binding, edge.previousId!),
      nextId: edge.nextId == null ? null : _edgeId(binding, edge.nextId!),
      startJoin: _vertexJoin(edge.startJoin),
      endJoin: _vertexJoin(edge.endJoin),
      bounds: TerrainAabb(
        minX: start.xTicks < end.xTicks ? start.xTicks : end.xTicks,
        minY: start.yTicks < end.yTicks ? start.yTicks : end.yTicks,
        maxX: start.xTicks > end.xTicks ? start.xTicks : end.xTicks,
        maxY: start.yTicks > end.yTicks ? start.yTicks : end.yTicks,
      ),
    );
  }

  TerrainPoint _worldPoint(
    StagedTerrainChunkBinding binding,
    StagedTerrainPoint local,
  ) => TerrainPoint(local.xTicks + binding.worldOriginXTicks, local.yTicks);

  TerrainEdgeId _edgeId(
    StagedTerrainChunkBinding binding,
    StagedTerrainEdgeId edgeId,
  ) => binding
      .sourceIdentity(edgeId.sourceId)
      .edgeId(edgeId.localEdgeIndex, subEdgeIndex: edgeId.subEdgeIndex);

  TerrainCollisionMode _collisionMode(StagedTerrainCollisionMode mode) =>
      switch (mode) {
        StagedTerrainCollisionMode.solid => TerrainCollisionMode.solid,
        StagedTerrainCollisionMode.oneWay => TerrainCollisionMode.oneWay,
      };

  TerrainVertexJoin _vertexJoin(StagedTerrainVertexJoin join) => switch (join) {
    StagedTerrainVertexJoin.exposed => TerrainVertexJoin.exposed,
    StagedTerrainVertexJoin.connected => TerrainVertexJoin.connected,
    StagedTerrainVertexJoin.smooth => TerrainVertexJoin.smooth,
  };
}

void _requireNonEmpty(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}
