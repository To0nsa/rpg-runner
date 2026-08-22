/// Deterministic lookup and runtime-instance binding for staged terrain data.
library;

import '../collision/terrain/terrain_authoring_polygon_signature.dart';
import '../collision/terrain/terrain_authoring_seam_signature.dart';
import '../collision/terrain/terrain_authoring_triangle_signature.dart';
import '../collision/terrain/terrain_polygon.dart';
import 'staged_terrain_data.dart';

/// Read-only staged-terrain lookup used by deterministic stream binding.
///
/// Normal runs use [StagedTerrainArtifactCatalog]. Tooling may layer a
/// validated catalog on top, but consumers cannot mutate or enumerate lookup
/// state through this boundary.
abstract interface class StagedTerrainCatalog {
  StagedTerrainChunkData requireChunk(String chunkKey);

  StagedTerrainChunkBinding bind({
    required String chunkKey,
    required int chunkIndex,
    required int worldOriginXTicks,
  });
}

/// Validates generated staged-terrain structure before runtime selection.
///
/// The generator remains responsible for fresh-source compilation and semantic
/// signature validation. This catalog protects the runtime handoff from a
/// malformed generated record by requiring the expected artifact format and a
/// canonical, unique chunk-key sequence. Constructing it has no gameplay or
/// streaming side effect.
final class StagedTerrainArtifactCatalog implements StagedTerrainCatalog {
  factory StagedTerrainArtifactCatalog({
    required StagedTerrainArtifactData artifact,
  }) {
    if (artifact.formatVersion != stagedTerrainArtifactFormatVersion) {
      throw ArgumentError.value(
        artifact.formatVersion,
        'artifact.formatVersion',
        'Expected staged terrain format $stagedTerrainArtifactFormatVersion.',
      );
    }
    if (artifact.compilerGeometryVersion !=
        stagedTerrainCompilerGeometryVersion) {
      throw ArgumentError.value(
        artifact.compilerGeometryVersion,
        'artifact.compilerGeometryVersion',
        'Expected staged terrain compiler geometry version '
            '$stagedTerrainCompilerGeometryVersion.',
      );
    }
    _requireFormat(
      artifact.authoringPolygonSignatureFormat,
      terrainAuthoringPolygonSignatureFormat,
      'artifact.authoringPolygonSignatureFormat',
    );
    _requireFormat(
      artifact.authoringSeamSignatureFormat,
      terrainAuthoringSeamSignatureFormat,
      'artifact.authoringSeamSignatureFormat',
    );
    _requireDigest(
      artifact.authoringSeamSignature,
      'artifact.authoringSeamSignature',
    );
    _requireFormat(
      artifact.sourceSignatureFormat,
      stagedTerrainSourceSignatureFormat,
      'artifact.sourceSignatureFormat',
    );
    _requireFormat(
      artifact.edgeSignatureFormat,
      stagedTerrainEdgeSignatureFormat,
      'artifact.edgeSignatureFormat',
    );
    _requireFormat(
      artifact.renderEdgeSignatureFormat,
      stagedTerrainRenderEdgeSignatureFormat,
      'artifact.renderEdgeSignatureFormat',
    );
    _requireFormat(
      artifact.placementSignatureFormat,
      stagedTerrainPlacementSignatureFormat,
      'artifact.placementSignatureFormat',
    );
    _requireFormat(
      artifact.triangleSignatureFormat,
      terrainAuthoringTriangleSignatureFormat,
      'artifact.triangleSignatureFormat',
    );

    final chunksByKey = <String, StagedTerrainChunkData>{};
    String? previousKey;
    for (final chunk in artifact.chunks) {
      _validateChunk(chunk);
      if (previousKey != null && previousKey.compareTo(chunk.chunkKey) >= 0) {
        throw ArgumentError.value(
          artifact.chunks,
          'artifact.chunks',
          'Chunk keys must be unique and strictly ascending; found '
              '$previousKey before ${chunk.chunkKey}.',
        );
      }
      chunksByKey[chunk.chunkKey] = chunk;
      previousKey = chunk.chunkKey;
    }

    return StagedTerrainArtifactCatalog._(
      artifact: artifact,
      chunksByKey: Map<String, StagedTerrainChunkData>.unmodifiable(
        chunksByKey,
      ),
    );
  }

  const StagedTerrainArtifactCatalog._({
    required this.artifact,
    required this.chunksByKey,
  });

  /// Original generated artifact whose ordered chunks were admitted.
  final StagedTerrainArtifactData artifact;

  /// Chunk records keyed by their stable authoring identity.
  final Map<String, StagedTerrainChunkData> chunksByKey;

  /// Returns the one generated record matching [chunkKey].
  ///
  /// A missing key is a construction error: a selected runtime chunk cannot
  /// silently fall back to different geometry or an empty record.
  @override
  StagedTerrainChunkData requireChunk(String chunkKey) {
    if (chunkKey.isEmpty) {
      throw ArgumentError.value(chunkKey, 'chunkKey', 'Must not be empty.');
    }
    return chunksByKey[chunkKey] ??
        (throw StateError(
          'Staged terrain artifact has no chunk record for "$chunkKey".',
        ));
  }

  /// Binds a selected authored chunk to one streamed runtime instance.
  ///
  /// [chunkIndex] is the deterministic streamed instance index. It is not
  /// written into generated data, allowing the same local chunk record to be
  /// selected repeatedly while every compiled edge retains unique world
  /// lineage through [StagedTerrainChunkBinding.sourceIdentity].
  @override
  StagedTerrainChunkBinding bind({
    required String chunkKey,
    required int chunkIndex,
    required int worldOriginXTicks,
  }) {
    if (chunkIndex < 0) {
      throw ArgumentError.value(
        chunkIndex,
        'chunkIndex',
        'Must be non-negative for a streamed chunk.',
      );
    }
    return _bindChunk(
      chunk: requireChunk(chunkKey),
      chunkIndex: chunkIndex,
      worldOriginXTicks: worldOriginXTicks,
    );
  }

  static void _validateChunk(StagedTerrainChunkData chunk) {
    if (chunk.chunkKey.isEmpty ||
        chunk.id.isEmpty ||
        chunk.levelId.isEmpty ||
        chunk.difficulty.isEmpty ||
        chunk.assemblyGroupId.isEmpty) {
      throw ArgumentError.value(
        chunk,
        'artifact.chunks',
        'Staged chunk metadata fields must not be empty.',
      );
    }
    if (chunk.revision <= 0 ||
        chunk.tileSize <= 0 ||
        chunk.width <= 0 ||
        chunk.height <= 0) {
      throw ArgumentError.value(
        chunk,
        'artifact.chunks',
        'Staged chunk revision, tileSize, width, and height must be positive.',
      );
    }
    final sourceIds = <StagedTerrainSourceId>{};
    final modeBySourceId =
        <StagedTerrainSourceId, StagedTerrainCollisionMode>{};
    for (final polygon in chunk.polygons) {
      if (polygon.sourcePath.isEmpty ||
          polygon.id.chunkKey != chunk.chunkKey ||
          polygon.sourceVertices.length < 3 ||
          polygon.vertices.length != polygon.sourceVertices.length ||
          !sourceIds.add(polygon.id)) {
        throw ArgumentError.value(
          polygon,
          'artifact.chunks',
          'Staged polygons require matching source/physics loops, a source '
              'path, and unique identities in chunk ${chunk.chunkKey}.',
        );
      }
      modeBySourceId[polygon.id] = polygon.collisionMode;
    }

    final edgeIds = <StagedTerrainEdgeId>{};
    for (final edge in chunk.edges) {
      final sourceMode = modeBySourceId[edge.id.sourceId];
      if (sourceMode == null ||
          sourceMode == StagedTerrainCollisionMode.none ||
          edge.collisionMode == StagedTerrainCollisionMode.none ||
          edge.collisionMode != sourceMode ||
          !edgeIds.add(edge.id)) {
        throw ArgumentError.value(
          edge,
          'artifact.chunks',
          'Staged edges must have unique IDs and matching collidable polygon '
              'roles in chunk ${chunk.chunkKey}.',
        );
      }
    }

    final renderEdgeIds = <StagedTerrainEdgeId>{};
    for (final edge in chunk.renderEdges) {
      final sourceMode = modeBySourceId[edge.id.sourceId];
      if (edge.id.sourceId.placementKey != null ||
          sourceMode == null ||
          sourceMode == StagedTerrainCollisionMode.none ||
          edge.collisionMode == StagedTerrainCollisionMode.none ||
          edge.collisionMode != sourceMode ||
          !renderEdgeIds.add(edge.id)) {
        throw ArgumentError.value(
          edge,
          'artifact.chunks',
          'Terrain render edges must have unique IDs and matching direct '
              'collidable polygon roles in chunk ${chunk.chunkKey}.',
        );
      }
    }
    for (final edge in chunk.renderEdges) {
      if ((edge.previousId != null &&
              !renderEdgeIds.contains(edge.previousId)) ||
          (edge.nextId != null && !renderEdgeIds.contains(edge.nextId))) {
        throw ArgumentError.value(
          edge,
          'artifact.chunks',
          'Terrain render edge adjacency must reference a render edge in '
              'chunk ${chunk.chunkKey}.',
        );
      }
    }
    for (final edge in chunk.edges) {
      if ((edge.previousId != null && !edgeIds.contains(edge.previousId)) ||
          (edge.nextId != null && !edgeIds.contains(edge.nextId))) {
        throw ArgumentError.value(
          edge,
          'artifact.chunks',
          'Staged edge adjacency must reference an edge in chunk '
              '${chunk.chunkKey}.',
        );
      }
    }

    final triangleRecords = <(StagedTerrainSourceId, int, int, int)>{};
    for (final triangle in chunk.triangles) {
      final key = (
        triangle.sourceId,
        triangle.first,
        triangle.second,
        triangle.third,
      );
      if (triangle.sourceId.placementKey != null ||
          !sourceIds.contains(triangle.sourceId) ||
          !triangleRecords.add(key)) {
        throw ArgumentError.value(
          triangle,
          'artifact.chunks',
          'Staged triangles must be unique and owned by a polygon in '
              'chunk ${chunk.chunkKey}.',
        );
      }
    }

    final placedSourceIds = <StagedTerrainSourceId>{};
    for (final lineage in chunk.placementLineage) {
      final sourceId = lineage.sourceId;
      if (sourceId.placementKey == null ||
          !sourceIds.contains(sourceId) ||
          !placedSourceIds.add(sourceId)) {
        throw ArgumentError.value(
          lineage,
          'artifact.chunks',
          'Placement lineage must uniquely reference a placed polygon in '
              'chunk ${chunk.chunkKey}.',
        );
      }
    }
    for (final sourceId in sourceIds) {
      if (sourceId.placementKey != null &&
          !placedSourceIds.contains(sourceId)) {
        throw ArgumentError.value(
          sourceId,
          'artifact.chunks',
          'Placed polygon ${sourceId.shapeId} is missing placement lineage.',
        );
      }
    }

    _requireDigest(
      chunk.authoringPolygonSignature,
      'chunk.authoringPolygonSignature',
    );
    _requireDigest(chunk.sourceSignature, 'chunk.sourceSignature');
    _requireDigest(chunk.edgeSignature, 'chunk.edgeSignature');
    _requireDigest(chunk.renderEdgeSignature, 'chunk.renderEdgeSignature');
    _requireDigest(chunk.placementSignature, 'chunk.placementSignature');
    _requireDigest(chunk.triangleSignature, 'chunk.triangleSignature');
  }
}

/// One-record authoring overlay on an admitted generated artifact.
///
/// The replacement must retain the generated record's stable key and chunk
/// dimensions. Every other lookup delegates to [base], so tooling cannot
/// accidentally replace or synthesize neighboring runtime terrain.
final class StagedTerrainOverlayCatalog implements StagedTerrainCatalog {
  factory StagedTerrainOverlayCatalog({
    required StagedTerrainArtifactCatalog base,
    required StagedTerrainChunkData replacement,
  }) {
    final admitted = base.requireChunk(replacement.chunkKey);
    StagedTerrainArtifactCatalog._validateChunk(replacement);
    if (replacement.tileSize != admitted.tileSize ||
        replacement.width != admitted.width ||
        replacement.height != admitted.height) {
      throw ArgumentError.value(
        replacement,
        'replacement',
        'A staged terrain overlay must retain admitted tileSize, width, and '
            'height for chunk ${replacement.chunkKey}.',
      );
    }
    return StagedTerrainOverlayCatalog._(base: base, replacement: replacement);
  }

  const StagedTerrainOverlayCatalog._({
    required this.base,
    required this.replacement,
  });

  /// Generated catalog used for every non-selected record.
  final StagedTerrainArtifactCatalog base;

  /// Structurally admitted draft replacing one stable generated key.
  final StagedTerrainChunkData replacement;

  @override
  StagedTerrainChunkData requireChunk(String chunkKey) {
    if (chunkKey == replacement.chunkKey) return replacement;
    return base.requireChunk(chunkKey);
  }

  @override
  StagedTerrainChunkBinding bind({
    required String chunkKey,
    required int chunkIndex,
    required int worldOriginXTicks,
  }) {
    if (chunkIndex < 0) {
      throw ArgumentError.value(
        chunkIndex,
        'chunkIndex',
        'Must be non-negative for a streamed chunk.',
      );
    }
    return _bindChunk(
      chunk: requireChunk(chunkKey),
      chunkIndex: chunkIndex,
      worldOriginXTicks: worldOriginXTicks,
    );
  }
}

StagedTerrainChunkBinding _bindChunk({
  required StagedTerrainChunkData chunk,
  required int chunkIndex,
  required int worldOriginXTicks,
}) => StagedTerrainChunkBinding._(
  chunk: chunk,
  chunkIndex: chunkIndex,
  worldOriginXTicks: worldOriginXTicks,
  sourceIds: Set<StagedTerrainSourceId>.unmodifiable(
    chunk.polygons.map((polygon) => polygon.id),
  ),
);

void _requireFormat(String actual, String expected, String name) {
  if (actual == expected) return;
  throw ArgumentError.value(actual, name, 'Expected format $expected.');
}

void _requireDigest(String value, String name) {
  if (_sha256DigestPattern.hasMatch(value)) return;
  throw ArgumentError.value(
    value,
    name,
    'Must be a lowercase SHA-256 hexadecimal digest.',
  );
}

final RegExp _sha256DigestPattern = RegExp(r'^[0-9a-f]{64}$');

/// One staged chunk selected at a specific streamed world position.
///
/// [worldOriginXTicks] uses the `1/1024` world-unit physics grid retained by
/// [StagedTerrainPolygonData.vertices]. It stays separate from generated
/// local data so culling and re-adding a chunk never changes its source facts.
final class StagedTerrainChunkBinding {
  const StagedTerrainChunkBinding._({
    required this.chunk,
    required this.chunkIndex,
    required this.worldOriginXTicks,
    required this.sourceIds,
  });

  final StagedTerrainChunkData chunk;
  final int chunkIndex;
  final int worldOriginXTicks;

  final Set<StagedTerrainSourceId> sourceIds;

  /// Rehydrates one local source identity with this streamed instance index.
  ///
  /// The source record must belong to [chunk]; accepting a foreign identity
  /// would make edge lineage appear valid while addressing another chunk.
  TerrainSourceIdentity sourceIdentity(StagedTerrainSourceId sourceId) {
    if (sourceId.chunkKey != chunk.chunkKey) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'Must belong to staged chunk ${chunk.chunkKey}.',
      );
    }
    if (!sourceIds.contains(sourceId)) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'Is not a polygon source in staged chunk ${chunk.chunkKey}.',
      );
    }
    return TerrainSourceIdentity(
      chunkIndex: chunkIndex,
      chunkKey: sourceId.chunkKey,
      placementKey: sourceId.placementKey,
      shapeId: sourceId.shapeId,
    );
  }
}
