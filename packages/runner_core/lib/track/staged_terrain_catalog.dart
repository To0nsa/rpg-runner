/// Deterministic lookup and runtime-instance binding for staged terrain data.
library;

import '../collision/terrain/terrain_polygon.dart';
import 'staged_terrain_data.dart';

/// Validates generated staged-terrain structure before runtime selection.
///
/// The generator remains responsible for fresh-source compilation and semantic
/// signature validation. This catalog protects the runtime handoff from a
/// malformed generated record by requiring the expected artifact format and a
/// canonical, unique chunk-key sequence. Constructing it has no gameplay or
/// streaming side effect.
final class StagedTerrainArtifactCatalog {
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
    if (artifact.compilerGeometryVersion < 0) {
      throw ArgumentError.value(
        artifact.compilerGeometryVersion,
        'artifact.compilerGeometryVersion',
        'Must be non-negative.',
      );
    }

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
    final chunk = requireChunk(chunkKey);
    return StagedTerrainChunkBinding._(
      chunk: chunk,
      chunkIndex: chunkIndex,
      worldOriginXTicks: worldOriginXTicks,
      sourceIds: Set<StagedTerrainSourceId>.unmodifiable(
        chunk.polygons.map((polygon) => polygon.id),
      ),
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
    for (final polygon in chunk.polygons) {
      if (polygon.id.chunkKey != chunk.chunkKey || !sourceIds.add(polygon.id)) {
        throw ArgumentError.value(
          polygon,
          'artifact.chunks',
          'Staged polygon identities must be unique and belong to '
              'chunk ${chunk.chunkKey}.',
        );
      }
    }
  }
}

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
