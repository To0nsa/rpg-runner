import 'dart:convert';

import '../chunks/chunk_domain_models.dart';
import '../prefabs/models/models.dart';
import '../terrain_authoring/terrain_source_models.dart';
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
  _requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{
      'id',
      'sourceImagePath',
      'x',
      'y',
      'width',
      'height',
      'tags',
    },
    required: const <String>{
      'id',
      'sourceImagePath',
      'x',
      'y',
      'width',
      'height',
    },
  );
  return AtlasSliceDef(
    id: _nonEmptyString(json['id'], sourcePath: '$sourcePath.id'),
    sourceImagePath: _nonEmptyString(
      json['sourceImagePath'],
      sourcePath: '$sourcePath.sourceImagePath',
    ),
    x: _int(json['x'], sourcePath: '$sourcePath.x'),
    y: _int(json['y'], sourcePath: '$sourcePath.y'),
    width: _positiveInt(json['width'], sourcePath: '$sourcePath.width'),
    height: _positiveInt(json['height'], sourcePath: '$sourcePath.height'),
    tags: json.containsKey('tags')
        ? _canonicalTags(json['tags'], sourcePath: '$sourcePath.tags')
        : const <String>[],
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
  final json = _object(raw, sourcePath: sourcePath);
  final type = _enumString(json['type'], const <String>{
    'atlas_slice',
    'platform_module',
  }, sourcePath: '$sourcePath.type');
  if (type == 'atlas_slice') {
    _requireKeys(
      json,
      sourcePath: sourcePath,
      allowed: const <String>{'type', 'sliceId'},
      required: const <String>{'type', 'sliceId'},
    );
    return PrefabVisualSource.atlasSlice(
      _nonEmptyString(json['sliceId'], sourcePath: '$sourcePath.sliceId'),
    );
  }
  _requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{'type', 'moduleId'},
    required: const <String>{'type', 'moduleId'},
  );
  return PrefabVisualSource.platformModule(
    _nonEmptyString(json['moduleId'], sourcePath: '$sourcePath.moduleId'),
  );
}

TileLayerDef _decodeTileLayer(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  _requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{'id', 'kind', 'visible'},
    required: const <String>{'id', 'kind', 'visible'},
  );
  return TileLayerDef(
    id: _nonEmptyString(json['id'], sourcePath: '$sourcePath.id'),
    kind: _nonEmptyString(json['kind'], sourcePath: '$sourcePath.kind'),
    visible: _bool(json['visible'], sourcePath: '$sourcePath.visible'),
  );
}

PlacedPrefabDef _decodePlacement(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  _requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{
      'prefabId',
      'prefabKey',
      'x',
      'y',
      'zIndex',
      'snapToGrid',
      'scale',
      'flipX',
      'flipY',
    },
    required: const <String>{'prefabId', 'x', 'y', 'zIndex', 'snapToGrid'},
  );
  final scale = json.containsKey('scale')
      ? _scale(json['scale'], sourcePath: '$sourcePath.scale')
      : defaultPrefabPlacementScale;
  return PlacedPrefabDef(
    prefabId: _nonEmptyString(
      json['prefabId'],
      sourcePath: '$sourcePath.prefabId',
    ),
    prefabKey: json.containsKey('prefabKey')
        ? _nonEmptyString(
            json['prefabKey'],
            sourcePath: '$sourcePath.prefabKey',
          )
        : '',
    x: _int(json['x'], sourcePath: '$sourcePath.x'),
    y: _int(json['y'], sourcePath: '$sourcePath.y'),
    zIndex: _int(json['zIndex'], sourcePath: '$sourcePath.zIndex'),
    snapToGrid: _bool(json['snapToGrid'], sourcePath: '$sourcePath.snapToGrid'),
    scale: scale,
    flipX: json.containsKey('flipX')
        ? _bool(json['flipX'], sourcePath: '$sourcePath.flipX')
        : false,
    flipY: json.containsKey('flipY')
        ? _bool(json['flipY'], sourcePath: '$sourcePath.flipY')
        : false,
  );
}

PlacedMarkerDef _decodeMarker(
  Map<String, Object?> json, {
  required String sourcePath,
}) {
  _requireKeys(
    json,
    sourcePath: sourcePath,
    allowed: const <String>{
      'markerId',
      'x',
      'y',
      'chancePercent',
      'salt',
      'placement',
    },
    required: const <String>{
      'markerId',
      'x',
      'y',
      'chancePercent',
      'salt',
      'placement',
    },
  );
  final chancePercent = _int(
    json['chancePercent'],
    sourcePath: '$sourcePath.chancePercent',
  );
  if (chancePercent < 0 || chancePercent > 100) {
    throw FormatException('$sourcePath.chancePercent must be from 0 to 100.');
  }
  return PlacedMarkerDef(
    markerId: _nonEmptyString(
      json['markerId'],
      sourcePath: '$sourcePath.markerId',
    ),
    x: _int(json['x'], sourcePath: '$sourcePath.x'),
    y: _int(json['y'], sourcePath: '$sourcePath.y'),
    chancePercent: chancePercent,
    salt: _int(json['salt'], sourcePath: '$sourcePath.salt'),
    placement: _enumString(json['placement'], const <String>{
      markerPlacementGround,
      markerPlacementHighestSurfaceAtX,
      markerPlacementObstacleTop,
    }, sourcePath: '$sourcePath.placement'),
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
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (error) {
    throw FormatException('$sourcePath is malformed JSON: ${error.message}');
  }
  return _object(decoded, sourcePath: sourcePath);
}

Map<String, Object?> _object(Object? raw, {required String sourcePath}) {
  if (raw is! Map<Object?, Object?> || raw.keys.any((key) => key is! String)) {
    throw FormatException('$sourcePath must be an object.');
  }
  return <String, Object?>{
    for (final entry in raw.entries) entry.key! as String: entry.value,
  };
}

List<T> _objectList<T>(
  Object? raw, {
  required String sourcePath,
  required T Function(Map<String, Object?> json, {required String sourcePath})
  parse,
}) {
  if (raw is! List<Object?>) {
    throw FormatException('$sourcePath must be an array.');
  }
  return <T>[
    for (var index = 0; index < raw.length; index += 1)
      parse(
        _object(raw[index], sourcePath: '$sourcePath[$index]'),
        sourcePath: '$sourcePath[$index]',
      ),
  ];
}

void _requireKeys(
  Map<String, Object?> json, {
  required String sourcePath,
  required Set<String> allowed,
  required Set<String> required,
}) {
  final unknown = json.keys.where((key) => !allowed.contains(key)).toList()
    ..sort();
  if (unknown.isNotEmpty) {
    throw FormatException('$sourcePath has unknown field ${unknown.first}.');
  }
  final missing = required.where((key) => !json.containsKey(key)).toList()
    ..sort();
  if (missing.isNotEmpty) {
    throw FormatException('$sourcePath is missing field ${missing.first}.');
  }
}

void _requireSchemaVersion(
  Object? raw,
  int expected, {
  required String sourcePath,
}) {
  if (raw is! int || raw != expected) {
    throw FormatException('$sourcePath must be exactly $expected.');
  }
}

String _nonEmptyString(Object? raw, {required String sourcePath}) {
  if (raw is! String || raw.isEmpty || raw.trim() != raw) {
    throw FormatException('$sourcePath must be a non-empty trimmed string.');
  }
  return raw;
}

String _enumString(
  Object? raw,
  Set<String> accepted, {
  required String sourcePath,
}) {
  final value = _nonEmptyString(raw, sourcePath: sourcePath);
  if (!accepted.contains(value)) {
    final choices = accepted.toList()..sort();
    throw FormatException('$sourcePath must be one of ${choices.join(', ')}.');
  }
  return value;
}

int _int(Object? raw, {required String sourcePath}) {
  if (raw is! int) throw FormatException('$sourcePath must be an integer.');
  return raw;
}

int _positiveInt(Object? raw, {required String sourcePath}) {
  final value = _int(raw, sourcePath: sourcePath);
  if (value <= 0) throw FormatException('$sourcePath must be positive.');
  return value;
}

bool _bool(Object? raw, {required String sourcePath}) {
  if (raw is! bool) throw FormatException('$sourcePath must be a boolean.');
  return raw;
}

double _scale(Object? raw, {required String sourcePath}) {
  if (raw is! num || !raw.isFinite) {
    throw FormatException('$sourcePath must be a finite number.');
  }
  final value = raw.toDouble();
  if (!isPrefabPlacementScaleInRange(value) ||
      !isPrefabPlacementScaleStepAligned(value)) {
    throw FormatException(
      '$sourcePath must use an accepted 0.3-3.0 scale in 0.1 steps.',
    );
  }
  return canonicalPrefabPlacementScale(value);
}

List<String> _canonicalTags(Object? raw, {required String sourcePath}) {
  if (raw is! List<Object?>) {
    throw FormatException('$sourcePath must be an array.');
  }
  final tags = <String>[];
  for (var index = 0; index < raw.length; index += 1) {
    tags.add(_nonEmptyString(raw[index], sourcePath: '$sourcePath[$index]'));
  }
  _requireStrictIdOrder(tags, sourcePath: sourcePath);
  return tags;
}

void _requireStrictIdOrder(
  Iterable<String> values, {
  required String sourcePath,
}) {
  String? previous;
  for (final value in values) {
    if (previous != null && previous.compareTo(value) >= 0) {
      throw FormatException(
        '$sourcePath must be strictly ordered with no duplicates.',
      );
    }
    previous = value;
  }
}

void _requireUniqueStrings(
  Iterable<String> values, {
  required String sourcePath,
  required bool caseInsensitive,
}) {
  final seen = <String>{};
  for (final value in values) {
    final identity = caseInsensitive ? value.toLowerCase() : value;
    if (!seen.add(identity)) {
      throw FormatException('$sourcePath must contain unique values.');
    }
  }
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
  for (var index = 1; index < values.length; index += 1) {
    if (compare(values[index - 1], values[index]) >= 0) {
      throw FormatException(
        '$sourcePath must be in canonical order without duplicates.',
      );
    }
  }
}

String _encode(Map<String, Object> json) =>
    '${const JsonEncoder.withIndent('  ').convert(json)}\n';
