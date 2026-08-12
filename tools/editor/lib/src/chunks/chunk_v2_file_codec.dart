import '../domain/strict_authoring_json.dart';
import '../domain/strict_authoring_metadata_codec.dart';
import '../terrain_authoring/strict_terrain_source_codec.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'chunk_domain_models.dart';
import 'chunk_v2_file_data.dart';

/// Strict normal-layer codec for one chunk-schema-v2 polygon source file.
///
/// It performs no filesystem I/O; transactional stores own source writes.
/// Unknown, missing, legacy, wrong-type, off-grid, and noncanonical values fail
/// closed. Geometry acceptance remains a separate Core-owned validation gate.
abstract final class ChunkV2FileCodec {
  /// Parses canonical schema-v2 source without v1 defaults or coercion.
  static ChunkV2FileData decode(
    String raw, {
    String sourcePath = 'chunk.json',
  }) {
    final root = StrictAuthoringJson.decodeRoot(raw, sourcePath: sourcePath);
    StrictAuthoringJson.requireKeys(
      root,
      sourcePath: sourcePath,
      allowed: const <String>{
        'schemaVersion',
        'chunkKey',
        'id',
        'revision',
        'status',
        'levelId',
        'tileSize',
        'width',
        'height',
        'difficulty',
        'assemblyGroupId',
        'tags',
        'tileLayers',
        'prefabs',
        'markers',
        'groundBandZIndex',
        'collisionShapes',
      },
      required: const <String>{
        'schemaVersion',
        'chunkKey',
        'id',
        'revision',
        'status',
        'levelId',
        'tileSize',
        'width',
        'height',
        'difficulty',
        'assemblyGroupId',
        'tags',
        'tileLayers',
        'prefabs',
        'markers',
        'collisionShapes',
      },
    );
    StrictAuthoringJson.requireSchemaVersion(
      root['schemaVersion'],
      chunkSchemaVersionV2,
      sourcePath: '$sourcePath.schemaVersion',
    );
    final status = StrictAuthoringJson.enumString(
      root['status'],
      const <String>{chunkStatusActive, chunkStatusDeprecated},
      sourcePath: '$sourcePath.status',
    );
    final difficulty =
        StrictAuthoringJson.enumString(root['difficulty'], const <String>{
          chunkDifficultyEarly,
          chunkDifficultyEasy,
          chunkDifficultyNormal,
          chunkDifficultyHard,
        }, sourcePath: '$sourcePath.difficulty');
    final tileLayers = StrictAuthoringJson.objectList(
      root['tileLayers'],
      sourcePath: '$sourcePath.tileLayers',
      parse: PolygonAuthoringMetadataCodec.decodeTileLayer,
    );
    StrictAuthoringJson.requireStrictStringOrder(
      tileLayers.map((layer) => layer.id),
      sourcePath: '$sourcePath.tileLayers',
    );
    final prefabs = StrictAuthoringJson.objectList(
      root['prefabs'],
      sourcePath: '$sourcePath.prefabs',
      parse: PolygonAuthoringMetadataCodec.decodePlacement,
    );
    StrictAuthoringJson.requireComparatorOrder(
      prefabs,
      comparePlacedPrefabsDeterministic,
      sourcePath: '$sourcePath.prefabs',
    );
    final markers = StrictAuthoringJson.objectList(
      root['markers'],
      sourcePath: '$sourcePath.markers',
      parse: PolygonAuthoringMetadataCodec.decodeMarker,
    );
    StrictAuthoringJson.requireComparatorOrder(
      markers,
      comparePlacedMarkersDeterministic,
      sourcePath: '$sourcePath.markers',
    );
    return ChunkV2FileData(
      chunkKey: StrictAuthoringJson.nonEmptyString(
        root['chunkKey'],
        sourcePath: '$sourcePath.chunkKey',
      ),
      id: StrictAuthoringJson.nonEmptyString(
        root['id'],
        sourcePath: '$sourcePath.id',
      ),
      revision: StrictAuthoringJson.positiveInt(
        root['revision'],
        sourcePath: '$sourcePath.revision',
      ),
      status: status,
      levelId: StrictAuthoringJson.nonEmptyString(
        root['levelId'],
        sourcePath: '$sourcePath.levelId',
      ),
      tileSize: StrictAuthoringJson.positiveInt(
        root['tileSize'],
        sourcePath: '$sourcePath.tileSize',
      ),
      width: StrictAuthoringJson.positiveInt(
        root['width'],
        sourcePath: '$sourcePath.width',
      ),
      height: StrictAuthoringJson.positiveInt(
        root['height'],
        sourcePath: '$sourcePath.height',
      ),
      difficulty: difficulty,
      assemblyGroupId: StrictAuthoringJson.nonEmptyString(
        root['assemblyGroupId'],
        sourcePath: '$sourcePath.assemblyGroupId',
      ),
      tags: StrictAuthoringJson.canonicalTags(
        root['tags'],
        sourcePath: '$sourcePath.tags',
      ),
      tileLayers: tileLayers,
      prefabs: prefabs,
      markers: markers,
      groundBandZIndex: root.containsKey('groundBandZIndex')
          ? StrictAuthoringJson.integer(
              root['groundBandZIndex'],
              sourcePath: '$sourcePath.groundBandZIndex',
            )
          : 0,
      collisionShapes: StrictTerrainSourceCodec.decodeShapes(
        root['collisionShapes'],
        sourcePath: '$sourcePath.collisionShapes',
      ),
    );
  }

  /// Emits canonical schema-v2 JSON with one final newline.
  ///
  /// Canonicalization happens on collection copies. The supplied immutable
  /// snapshot retains author order so validation can still diagnose it.
  static String encode(ChunkV2FileData data) {
    final tileLayers = List<TileLayerDef>.of(data.tileLayers)
      ..sort((left, right) => left.id.compareTo(right.id));
    final prefabs = List<PlacedPrefabDef>.of(data.prefabs)
      ..sort(comparePlacedPrefabsDeterministic);
    final markers = List<PlacedMarkerDef>.of(data.markers)
      ..sort(comparePlacedMarkersDeterministic);
    final canonical = data.copyWith(
      tags: _canonicalTags(data.tags),
      tileLayers: tileLayers,
      prefabs: prefabs,
      markers: markers,
      collisionShapes: canonicalTerrainSourceShapes(data.collisionShapes),
    );
    final encoded = StrictAuthoringJson.encode(canonical.toJson());
    decode(encoded);
    return encoded;
  }
}

List<String> _canonicalTags(Iterable<String> tags) {
  final normalized =
      tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
  return normalized;
}
