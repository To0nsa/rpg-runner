import '../chunks/chunk_domain_models.dart';
import '../prefabs/models/models.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'polygon_authoring_metadata_codec.dart';
import 'polygon_authoring_target_models.dart';
import 'strict_migration_json.dart';

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
  }) {
    final root = _decodeRoot(raw, sourcePath: sourcePath);
    _requireKeys(
      root,
      sourcePath: sourcePath,
      allowed: const <String>{'schemaVersion', 'slices', 'prefabs'},
      required: const <String>{'schemaVersion', 'slices', 'prefabs'},
    );
    _requireSchemaVersion(
      root['schemaVersion'],
      polygonPrefabSchemaVersion,
      sourcePath: '$sourcePath.schemaVersion',
    );
    final slices = _objectList(
      root['slices'],
      sourcePath: '$sourcePath.slices',
      parse: _decodeSlice,
    );
    _requireStrictIdOrder(
      slices.map((slice) => slice.id),
      sourcePath: '$sourcePath.slices',
    );
    final prefabs = _objectList(
      root['prefabs'],
      sourcePath: '$sourcePath.prefabs',
      parse: _decodePrefab,
    );
    _requirePrefabOrder(prefabs, sourcePath: '$sourcePath.prefabs');
    _requireUniqueStrings(
      prefabs.map((prefab) => prefab.prefabKey),
      sourcePath: '$sourcePath.prefabs.prefabKey',
      caseInsensitive: true,
    );
    return PrefabV3TargetDocument(slices: slices, prefabs: prefabs);
  }

  /// Emits the canonical prefab-v3 file representation with a final newline.
  static String encodePrefabV3(PrefabV3TargetDocument document) =>
      _encode(document.toJson());

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
      collisionShapes: _decodeShapes(
        root['collisionShapes'],
        sourcePath: '$sourcePath.collisionShapes',
      ),
    );
  }

  /// Emits the canonical chunk-v2 file representation with a final newline.
  static String encodeChunkV2(ChunkV2TargetDocument document) =>
      _encode(document.toJson());
}

AtlasSliceDef _decodeSlice(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  return PolygonAuthoringMetadataCodec.decodeSlice(
    json,
    sourcePath: sourcePath,
  );
}

PrefabV3TargetDef _decodePrefab(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  _requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{
      'prefabKey',
      'id',
      'revision',
      'status',
      'kind',
      'visualSource',
      'anchorXPx',
      'anchorYPx',
      'collisionShapes',
      'tags',
    },
    required: const <String>{
      'prefabKey',
      'id',
      'revision',
      'status',
      'kind',
      'visualSource',
      'anchorXPx',
      'anchorYPx',
      'collisionShapes',
      'tags',
    },
  );
  final statusRaw = _enumString(json['status'], const <String>{
    'active',
    'deprecated',
  }, sourcePath: '$sourcePath.status');
  final kindRaw = _enumString(json['kind'], const <String>{
    'obstacle',
    'platform',
    'decoration',
  }, sourcePath: '$sourcePath.kind');
  return PrefabV3TargetDef(
    prefabKey: _nonEmptyString(
      json['prefabKey'],
      sourcePath: '$sourcePath.prefabKey',
    ),
    id: _nonEmptyString(json['id'], sourcePath: '$sourcePath.id'),
    revision: _positiveInt(
      json['revision'],
      sourcePath: '$sourcePath.revision',
    ),
    status: parsePrefabStatus(statusRaw),
    kind: parsePrefabKind(kindRaw),
    visualSource: _decodeVisualSource(
      json['visualSource'],
      sourcePath: '$sourcePath.visualSource',
    ),
    anchorXPx: _int(json['anchorXPx'], sourcePath: '$sourcePath.anchorXPx'),
    anchorYPx: _int(json['anchorYPx'], sourcePath: '$sourcePath.anchorYPx'),
    collisionShapes: _decodeShapes(
      json['collisionShapes'],
      sourcePath: '$sourcePath.collisionShapes',
    ),
    tags: _canonicalTags(json['tags'], sourcePath: '$sourcePath.tags'),
  );
}

PrefabVisualSource _decodeVisualSource(
  Object? raw, {
  required String sourcePath,
}) {
  return PolygonAuthoringMetadataCodec.decodeVisualSource(
    raw,
    sourcePath: sourcePath,
  );
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

List<TerrainSourceShapeDef> _decodeShapes(
  Object? raw, {
  required String sourcePath,
}) {
  if (raw is! List<Object?>) {
    throw FormatException('$sourcePath must be an array.');
  }
  final shapes = <TerrainSourceShapeDef>[];
  for (var index = 0; index < raw.length; index += 1) {
    final shapePath = '$sourcePath[$index]';
    final json = _object(raw[index], sourcePath: shapePath);
    _requireKeys(
      json,
      sourcePath: shapePath,
      allowed: const <String>{
        'shapeId',
        'collisionMode',
        'vertices',
        'surfaceKind',
        'materialKey',
      },
      required: const <String>{'shapeId', 'collisionMode', 'vertices'},
    );
    if (json.containsKey('surfaceKind')) {
      _nonEmptyString(
        json['surfaceKind'],
        sourcePath: '$shapePath.surfaceKind',
      );
    }
    if (json.containsKey('materialKey')) {
      _nonEmptyString(
        json['materialKey'],
        sourcePath: '$shapePath.materialKey',
      );
    }
    final vertices = json['vertices'];
    if (vertices is! List<Object?>) {
      throw FormatException('$shapePath.vertices must be an array.');
    }
    for (var vertexIndex = 0; vertexIndex < vertices.length; vertexIndex += 1) {
      _requireKeys(
        _object(
          vertices[vertexIndex],
          sourcePath: '$shapePath.vertices[$vertexIndex]',
        ),
        sourcePath: '$shapePath.vertices[$vertexIndex]',
        allowed: const <String>{'x', 'y'},
        required: const <String>{'x', 'y'},
      );
    }
    shapes.add(TerrainSourceShapeDef.fromJson(json, sourcePath: shapePath));
  }
  _requireStrictIdOrder(
    shapes.map((shape) => shape.shapeId),
    sourcePath: sourcePath,
  );
  return canonicalTerrainSourceShapes(shapes);
}

Map<String, Object?> _decodeRoot(String raw, {required String sourcePath}) {
  return StrictMigrationJson.decodeRoot(raw, sourcePath: sourcePath);
}

Map<String, Object?> _object(Object? raw, {required String sourcePath}) {
  return StrictMigrationJson.object(raw, sourcePath: sourcePath);
}

List<T> _objectList<T>(
  Object? raw, {
  required String sourcePath,
  required T Function(Map<String, Object?> json, {required String sourcePath})
  parse,
}) {
  return StrictMigrationJson.objectList(
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
  StrictMigrationJson.requireKeys(
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
  StrictMigrationJson.requireSchemaVersion(
    raw,
    expected,
    sourcePath: sourcePath,
  );
}

String _nonEmptyString(Object? raw, {required String sourcePath}) {
  return StrictMigrationJson.nonEmptyString(raw, sourcePath: sourcePath);
}

String _enumString(
  Object? raw,
  Set<String> accepted, {
  required String sourcePath,
}) {
  return StrictMigrationJson.enumString(raw, accepted, sourcePath: sourcePath);
}

int _int(Object? raw, {required String sourcePath}) {
  return StrictMigrationJson.integer(raw, sourcePath: sourcePath);
}

int _positiveInt(Object? raw, {required String sourcePath}) {
  return StrictMigrationJson.positiveInt(raw, sourcePath: sourcePath);
}

List<String> _canonicalTags(Object? raw, {required String sourcePath}) {
  return StrictMigrationJson.canonicalTags(raw, sourcePath: sourcePath);
}

void _requireStrictIdOrder(
  Iterable<String> values, {
  required String sourcePath,
}) {
  StrictMigrationJson.requireStrictStringOrder(values, sourcePath: sourcePath);
}

void _requireUniqueStrings(
  Iterable<String> values, {
  required String sourcePath,
  required bool caseInsensitive,
}) {
  StrictMigrationJson.requireUniqueStrings(
    values,
    sourcePath: sourcePath,
    caseInsensitive: caseInsensitive,
  );
}

void _requirePrefabOrder(
  List<PrefabV3TargetDef> prefabs, {
  required String sourcePath,
}) {
  for (var index = 1; index < prefabs.length; index += 1) {
    final previous = prefabs[index - 1];
    final current = prefabs[index];
    final order = previous.id.compareTo(current.id);
    if (order > 0 ||
        (order == 0 && previous.prefabKey.compareTo(current.prefabKey) >= 0)) {
      throw FormatException(
        '$sourcePath must be ordered by id then prefabKey without duplicates.',
      );
    }
  }
}

void _requireComparatorOrder<T>(
  List<T> values,
  int Function(T left, T right) compare, {
  required String sourcePath,
}) {
  StrictMigrationJson.requireComparatorOrder(
    values,
    compare,
    sourcePath: sourcePath,
  );
}

String _encode(Map<String, Object> json) => StrictMigrationJson.encode(json);
