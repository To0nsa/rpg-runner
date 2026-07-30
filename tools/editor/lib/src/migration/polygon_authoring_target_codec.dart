import '../chunks/chunk_domain_models.dart';
import '../domain/strict_authoring_json.dart';
import '../domain/strict_authoring_metadata_codec.dart';
import '../prefabs/store/prefab_v3_file_codec.dart';
import '../terrain_authoring/strict_terrain_source_codec.dart';
import 'polygon_authoring_target_models.dart';

/// Strict structural codec for staged prefab-v3 and chunk-v2 source.
///
/// Unknown, missing, legacy, off-grid, noncanonical-order, and wrong-type
/// values fail instead of being defaulted or normalized. Geometry acceptance
/// remains Core-owned and is a separate validation gate.
abstract final class PolygonAuthoringTargetCodec {
  /// Parses one complete prefab-v3 file without legacy compatibility behavior.
  static PrefabV3TargetDocument decodePrefabV3(
    String raw, {
    String sourcePath = 'prefab_defs.json',
  }) => PrefabV3FileCodec.decode(raw, sourcePath: sourcePath);

  /// Emits the canonical prefab-v3 file representation with a final newline.
  static String encodePrefabV3(PrefabV3TargetDocument document) =>
      PrefabV3FileCodec.encode(document);

  /// Parses one complete chunk-v2 file without accepting v1 ground fields.
  static ChunkV2TargetDocument decodeChunkV2(
    String raw, {
    String sourcePath = 'chunk.json',
  }) {
    final root = _decodeRoot(raw, sourcePath: sourcePath);
    _requireKeys(
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
    _requireSchemaVersion(
      root['schemaVersion'],
      polygonChunkSchemaVersion,
      sourcePath: '$sourcePath.schemaVersion',
    );
    final status = _enumString(root['status'], const <String>{
      chunkStatusActive,
      chunkStatusDeprecated,
    }, sourcePath: '$sourcePath.status');
    final difficulty = _enumString(root['difficulty'], const <String>{
      chunkDifficultyEarly,
      chunkDifficultyEasy,
      chunkDifficultyNormal,
      chunkDifficultyHard,
    }, sourcePath: '$sourcePath.difficulty');
    final tags = _canonicalTags(root['tags'], sourcePath: '$sourcePath.tags');
    final tileLayers = _objectList(
      root['tileLayers'],
      sourcePath: '$sourcePath.tileLayers',
      parse: _decodeTileLayer,
    );
    _requireStrictIdOrder(
      tileLayers.map((layer) => layer.id),
      sourcePath: '$sourcePath.tileLayers',
    );
    final prefabs = _objectList(
      root['prefabs'],
      sourcePath: '$sourcePath.prefabs',
      parse: _decodePlacement,
    );
    _requireComparatorOrder(
      prefabs,
      comparePlacedPrefabsDeterministic,
      sourcePath: '$sourcePath.prefabs',
    );
    final markers = _objectList(
      root['markers'],
      sourcePath: '$sourcePath.markers',
      parse: _decodeMarker,
    );
    _requireComparatorOrder(
      markers,
      comparePlacedMarkersDeterministic,
      sourcePath: '$sourcePath.markers',
    );
    return ChunkV2TargetDocument(
      chunkKey: _nonEmptyString(
        root['chunkKey'],
        sourcePath: '$sourcePath.chunkKey',
      ),
      id: _nonEmptyString(root['id'], sourcePath: '$sourcePath.id'),
      revision: _positiveInt(
        root['revision'],
        sourcePath: '$sourcePath.revision',
      ),
      status: status,
      levelId: _nonEmptyString(
        root['levelId'],
        sourcePath: '$sourcePath.levelId',
      ),
      tileSize: _positiveInt(
        root['tileSize'],
        sourcePath: '$sourcePath.tileSize',
      ),
      width: _positiveInt(root['width'], sourcePath: '$sourcePath.width'),
      height: _positiveInt(root['height'], sourcePath: '$sourcePath.height'),
      difficulty: difficulty,
      assemblyGroupId: _nonEmptyString(
        root['assemblyGroupId'],
        sourcePath: '$sourcePath.assemblyGroupId',
      ),
      tags: tags,
      tileLayers: tileLayers,
      prefabs: prefabs,
      markers: markers,
      groundBandZIndex: root.containsKey('groundBandZIndex')
          ? _int(
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

  /// Emits the canonical chunk-v2 file representation with a final newline.
  static String encodeChunkV2(ChunkV2TargetDocument document) =>
      _encode(document.toJson());
}

TileLayerDef _decodeTileLayer(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  return PolygonAuthoringMetadataCodec.decodeTileLayer(
    json,
    sourcePath: sourcePath,
  );
}

PlacedPrefabDef _decodePlacement(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  return PolygonAuthoringMetadataCodec.decodePlacement(
    json,
    sourcePath: sourcePath,
  );
}

PlacedMarkerDef _decodeMarker(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  return PolygonAuthoringMetadataCodec.decodeMarker(
    json,
    sourcePath: sourcePath,
  );
}

Map<String, Object?> _decodeRoot(String raw, {required String sourcePath}) {
  return StrictAuthoringJson.decodeRoot(raw, sourcePath: sourcePath);
}

List<T> _objectList<T>(
  Object? raw, {
  required String sourcePath,
  required T Function(Map<String, Object?> json, {required String sourcePath})
  parse,
}) {
  return StrictAuthoringJson.objectList(
    raw,
    sourcePath: sourcePath,
    parse: parse,
  );
}

void _requireKeys(
  Map<String, Object?> json, {
  required String sourcePath,
  required Set<String> allowed,
  required Set<String> required,
}) {
  StrictAuthoringJson.requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: allowed,
    required: required,
  );
}

void _requireSchemaVersion(
  Object? raw,
  int expected, {
  required String sourcePath,
}) {
  StrictAuthoringJson.requireSchemaVersion(
    raw,
    expected,
    sourcePath: sourcePath,
  );
}

String _nonEmptyString(Object? raw, {required String sourcePath}) {
  return StrictAuthoringJson.nonEmptyString(raw, sourcePath: sourcePath);
}

String _enumString(
  Object? raw,
  Set<String> accepted, {
  required String sourcePath,
}) {
  return StrictAuthoringJson.enumString(raw, accepted, sourcePath: sourcePath);
}

int _int(Object? raw, {required String sourcePath}) {
  return StrictAuthoringJson.integer(raw, sourcePath: sourcePath);
}

int _positiveInt(Object? raw, {required String sourcePath}) {
  return StrictAuthoringJson.positiveInt(raw, sourcePath: sourcePath);
}

List<String> _canonicalTags(Object? raw, {required String sourcePath}) {
  return StrictAuthoringJson.canonicalTags(raw, sourcePath: sourcePath);
}

void _requireStrictIdOrder(
  Iterable<String> values, {
  required String sourcePath,
}) {
  StrictAuthoringJson.requireStrictStringOrder(values, sourcePath: sourcePath);
}

void _requireComparatorOrder<T>(
  List<T> values,
  int Function(T left, T right) compare, {
  required String sourcePath,
}) {
  StrictAuthoringJson.requireComparatorOrder(
    values,
    compare,
    sourcePath: sourcePath,
  );
}

String _encode(Map<String, Object> json) => StrictAuthoringJson.encode(json);
