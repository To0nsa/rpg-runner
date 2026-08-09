/// Immutable generated records for terrain staged ahead of runtime streaming.
library;

/// Schema version of [StagedTerrainArtifactData].
const int stagedTerrainArtifactFormatVersion = 2;

/// Collision behavior retained without depending on compiler implementation
/// enums in generated data.
enum StagedTerrainCollisionMode { solid, oneWay }

/// Endpoint context retained for runtime ghost-vertex filtering.
enum StagedTerrainVertexJoin { exposed, connected, smooth }

/// One integer point whose unit is defined by its containing record.
final class StagedTerrainPoint {
  const StagedTerrainPoint(this.xTicks, this.yTicks);

  final int xTicks;
  final int yTicks;
}

/// Stable chunk-local source lineage with no streamed chunk instance index.
final class StagedTerrainSourceId implements Comparable<StagedTerrainSourceId> {
  factory StagedTerrainSourceId({
    required String chunkKey,
    required String shapeId,
    String? placementKey,
  }) {
    if (chunkKey.isEmpty || shapeId.isEmpty) {
      throw ArgumentError('Staged terrain source keys must not be empty.');
    }
    if (placementKey != null && placementKey.isEmpty) {
      throw ArgumentError('A present placement key must not be empty.');
    }
    return StagedTerrainSourceId._(
      chunkKey: chunkKey,
      placementKey: placementKey,
      shapeId: shapeId,
    );
  }

  const StagedTerrainSourceId._({
    required this.chunkKey,
    required this.placementKey,
    required this.shapeId,
  });

  final String chunkKey;
  final String? placementKey;
  final String shapeId;

  @override
  int compareTo(StagedTerrainSourceId other) {
    var order = chunkKey.compareTo(other.chunkKey);
    if (order != 0) return order;
    order = _compareNullable(placementKey, other.placementKey);
    return order != 0 ? order : shapeId.compareTo(other.shapeId);
  }

  @override
  bool operator ==(Object other) =>
      other is StagedTerrainSourceId &&
      chunkKey == other.chunkKey &&
      placementKey == other.placementKey &&
      shapeId == other.shapeId;

  @override
  int get hashCode => Object.hash(chunkKey, placementKey, shapeId);
}

/// Stable local edge lineage whose runtime instance index is bound later.
final class StagedTerrainEdgeId implements Comparable<StagedTerrainEdgeId> {
  factory StagedTerrainEdgeId({
    required StagedTerrainSourceId sourceId,
    required int localEdgeIndex,
    required int subEdgeIndex,
  }) {
    if (localEdgeIndex < 0 || subEdgeIndex < 0) {
      throw ArgumentError('Staged terrain edge indices must be non-negative.');
    }
    return StagedTerrainEdgeId._(
      sourceId: sourceId,
      localEdgeIndex: localEdgeIndex,
      subEdgeIndex: subEdgeIndex,
    );
  }

  const StagedTerrainEdgeId._({
    required this.sourceId,
    required this.localEdgeIndex,
    required this.subEdgeIndex,
  });

  final StagedTerrainSourceId sourceId;
  final int localEdgeIndex;
  final int subEdgeIndex;

  @override
  int compareTo(StagedTerrainEdgeId other) {
    var order = sourceId.compareTo(other.sourceId);
    if (order != 0) return order;
    order = localEdgeIndex.compareTo(other.localEdgeIndex);
    return order != 0 ? order : subEdgeIndex.compareTo(other.subEdgeIndex);
  }

  @override
  bool operator ==(Object other) =>
      other is StagedTerrainEdgeId &&
      sourceId == other.sourceId &&
      localEdgeIndex == other.localEdgeIndex &&
      subEdgeIndex == other.subEdgeIndex;

  @override
  int get hashCode => Object.hash(sourceId, localEdgeIndex, subEdgeIndex);
}

/// One canonical source loop and its exactly transformed physics loop.
final class StagedTerrainPolygonData {
  StagedTerrainPolygonData({
    required this.sourcePath,
    required this.id,
    required Iterable<StagedTerrainPoint> sourceVertices,
    required Iterable<StagedTerrainPoint> vertices,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
  }) : sourceVertices = List<StagedTerrainPoint>.unmodifiable(sourceVertices),
       vertices = List<StagedTerrainPoint>.unmodifiable(vertices);

  final String sourcePath;
  final StagedTerrainSourceId id;

  /// Canonical loop in authored half-world-unit ticks.
  final List<StagedTerrainPoint> sourceVertices;

  /// Transformed loop in 1/1024-world-unit physics ticks.
  final List<StagedTerrainPoint> vertices;

  final StagedTerrainCollisionMode collisionMode;
  final String? surfaceKind;
  final String? materialKey;
}

/// One compiler-owned exposed edge in chunk-local physics coordinates.
final class StagedTerrainEdgeData {
  const StagedTerrainEdgeData({
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
  });

  final StagedTerrainEdgeId id;
  final StagedTerrainPoint start;
  final StagedTerrainPoint end;
  final StagedTerrainPoint tangent;
  final StagedTerrainPoint outwardNormal;
  final StagedTerrainCollisionMode collisionMode;
  final String? surfaceKind;
  final String? materialKey;
  final StagedTerrainEdgeId? previousId;
  final StagedTerrainEdgeId? nextId;
  final StagedTerrainVertexJoin startJoin;
  final StagedTerrainVertexJoin endJoin;
}

/// Render triangle indexing the matching normalized polygon [vertices].
final class StagedTerrainTriangleData {
  factory StagedTerrainTriangleData({
    required StagedTerrainSourceId sourceId,
    required int first,
    required int second,
    required int third,
  }) {
    if (first < 0 || second < 0 || third < 0) {
      throw ArgumentError(
        'Staged terrain triangle indices must be non-negative.',
      );
    }
    return StagedTerrainTriangleData._(
      sourceId: sourceId,
      first: first,
      second: second,
      third: third,
    );
  }

  const StagedTerrainTriangleData._({
    required this.sourceId,
    required this.first,
    required this.second,
    required this.third,
  });

  final StagedTerrainSourceId sourceId;
  final int first;
  final int second;
  final int third;
}

/// Prefab revision and exact transform that produced one placed source loop.
final class StagedTerrainPlacementLineageData {
  const StagedTerrainPlacementLineageData({
    required this.sourceId,
    required this.prefabKey,
    required this.prefabId,
    required this.prefabRevision,
    required this.placementX,
    required this.placementY,
    required this.scaleTenths,
    required this.flipX,
    required this.flipY,
  });

  final StagedTerrainSourceId sourceId;
  final String prefabKey;
  final String prefabId;
  final int prefabRevision;
  final int placementX;
  final int placementY;
  final int scaleTenths;
  final bool flipX;
  final bool flipY;
}

/// Complete staged local geometry and provenance for one authored chunk.
final class StagedTerrainChunkData {
  StagedTerrainChunkData({
    required this.chunkKey,
    required this.id,
    required this.revision,
    required this.status,
    required this.levelId,
    required this.tileSize,
    required this.width,
    required this.height,
    required this.difficulty,
    required this.assemblyGroupId,
    required this.authoringPolygonSignature,
    required this.sourceSignature,
    required this.edgeSignature,
    required this.placementSignature,
    required this.triangleSignature,
    required Iterable<StagedTerrainPolygonData> polygons,
    required Iterable<StagedTerrainEdgeData> edges,
    required Iterable<StagedTerrainTriangleData> triangles,
    required Iterable<StagedTerrainPlacementLineageData> placementLineage,
  }) : polygons = List<StagedTerrainPolygonData>.unmodifiable(polygons),
       edges = List<StagedTerrainEdgeData>.unmodifiable(edges),
       triangles = List<StagedTerrainTriangleData>.unmodifiable(triangles),
       placementLineage = List<StagedTerrainPlacementLineageData>.unmodifiable(
         placementLineage,
       );

  final String chunkKey;
  final String id;
  final int revision;
  final String status;
  final String levelId;
  final int tileSize;
  final int width;
  final int height;
  final String difficulty;
  final String assemblyGroupId;
  final String authoringPolygonSignature;
  final String sourceSignature;
  final String edgeSignature;
  final String placementSignature;
  final String triangleSignature;
  final List<StagedTerrainPolygonData> polygons;
  final List<StagedTerrainEdgeData> edges;
  final List<StagedTerrainTriangleData> triangles;
  final List<StagedTerrainPlacementLineageData> placementLineage;
}

/// Self-describing staged generated artifact; it is not runtime authority.
final class StagedTerrainArtifactData {
  StagedTerrainArtifactData({
    required this.formatVersion,
    required this.compilerGeometryVersion,
    required this.authoringPolygonSignatureFormat,
    required this.sourceSignatureFormat,
    required this.edgeSignatureFormat,
    required this.placementSignatureFormat,
    required this.triangleSignatureFormat,
    required Iterable<StagedTerrainChunkData> chunks,
  }) : chunks = List<StagedTerrainChunkData>.unmodifiable(chunks);

  final int formatVersion;
  final int compilerGeometryVersion;
  final String authoringPolygonSignatureFormat;
  final String sourceSignatureFormat;
  final String edgeSignatureFormat;
  final String placementSignatureFormat;
  final String triangleSignatureFormat;
  final List<StagedTerrainChunkData> chunks;
}

int _compareNullable(String? left, String? right) {
  if (identical(left, right)) return 0;
  if (left == null) return -1;
  if (right == null) return 1;
  return left.compareTo(right);
}
