import 'dart:convert';

import 'package:runner_core/collision/terrain/terrain_authoring_polygon_signature.dart';

const int polygonPrefabSchemaVersion = 3;
const int polygonChunkSchemaVersion = 2;
const int _defaultScaleTenths = 10;
const int _minScaleTenths = 3;
const int _maxScaleTenths = 30;
const int _maxExactHalfPixelTicks = (1 << 52) - 1;

final RegExp _stableShapeId = RegExp(r'^[a-z][a-z0-9_]*$');

/// Converts a workspace-relative source path to platform-neutral `/` form.
///
/// Traversal, absolute, empty-segment, and drive-qualified paths fail closed
/// so two host spellings cannot alias one generated source identity.
String canonicalPolygonTerrainSourcePath(String sourcePath) {
  if (sourcePath.isEmpty) {
    throw ArgumentError.value(sourcePath, 'sourcePath', 'Must not be empty.');
  }
  final normalized = sourcePath.replaceAll('\\', '/');
  final segments = normalized.split('/');
  if (normalized.startsWith('/') ||
      segments.any(
        (segment) =>
            segment.isEmpty ||
            segment == '.' ||
            segment == '..' ||
            segment.contains(':'),
      )) {
    throw ArgumentError.value(
      sourcePath,
      'sourcePath',
      'Must be a canonical workspace-relative path.',
    );
  }
  return segments.join('/');
}

/// Exact parsed vertex retained before Core range and topology validation.
final class PolygonTerrainSourcePoint {
  const PolygonTerrainSourcePoint({
    required this.xHalfPixels,
    required this.yHalfPixels,
  });

  final int xHalfPixels;
  final int yHalfPixels;
}

/// One strict prefab atlas slice used by runtime visual materialization.
final class PolygonTerrainSliceSource {
  const PolygonTerrainSliceSource({
    required this.id,
    required this.sourceImagePath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String id;
  final String sourceImagePath;
  final int x;
  final int y;
  final int width;
  final int height;
}

/// Prefab visual reference retained independently of Flutter and Flame.
final class PolygonTerrainPrefabVisualSource {
  const PolygonTerrainPrefabVisualSource({
    required this.type,
    required this.referenceId,
  });

  final String type;
  final String referenceId;
}

/// One strict prefab-v3 collision source used by staged generation.
final class PolygonTerrainPrefabSource {
  PolygonTerrainPrefabSource({
    required this.prefabKey,
    required this.id,
    required this.revision,
    required this.status,
    this.kind = 'decoration',
    this.anchorXPx = 0,
    this.anchorYPx = 0,
    this.visualSource,
    required Iterable<PolygonTerrainShapeSource> collisionShapes,
  }) : collisionShapes = List<PolygonTerrainShapeSource>.unmodifiable(
         collisionShapes,
       );

  final String prefabKey;
  final String id;
  final int revision;
  final String status;
  final String kind;
  final int anchorXPx;
  final int anchorYPx;
  final PolygonTerrainPrefabVisualSource? visualSource;
  final List<PolygonTerrainShapeSource> collisionShapes;
}

/// One exact current-schema terrain loop before render/collision partitioning.
final class PolygonTerrainShapeSource {
  PolygonTerrainShapeSource({
    required this.shapeId,
    required Iterable<PolygonTerrainSourcePoint> vertices,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
  }) : vertices = List<PolygonTerrainSourcePoint>.unmodifiable(vertices);

  final String shapeId;
  final List<PolygonTerrainSourcePoint> vertices;
  final TerrainAuthoringPolygonMode collisionMode;
  final String? surfaceKind;
  final String? materialKey;
}

/// One strict chunk-v2 prefab placement with exact scale tenths.
final class PolygonTerrainPlacementSource {
  const PolygonTerrainPlacementSource({
    required this.prefabId,
    required this.prefabKey,
    required this.x,
    required this.y,
    required this.zIndex,
    required this.snapToGrid,
    required this.scaleTenths,
    required this.flipX,
    required this.flipY,
  });

  final String prefabId;
  final String? prefabKey;
  final int x;
  final int y;
  final int zIndex;
  final bool snapToGrid;
  final int scaleTenths;
  final bool flipX;
  final bool flipY;

  String get resolvedPrefabRef => prefabKey ?? prefabId;
}

/// Stable placement identity shared with the editor and Core edge lineage.
final class PolygonTerrainPlacementSelection {
  const PolygonTerrainPlacementSelection({
    required this.placementKey,
    required this.placement,
  });

  final String placementKey;
  final PolygonTerrainPlacementSource placement;
}

/// One strict chunk-v2 spawn marker retained for Core pattern materialization.
final class PolygonTerrainMarkerSource {
  const PolygonTerrainMarkerSource({
    required this.markerId,
    required this.x,
    required this.y,
    required this.chancePercent,
    required this.salt,
    required this.placement,
  });

  final String markerId;
  final int x;
  final int y;
  final int chancePercent;
  final int salt;
  final String placement;
}

/// One strict chunk-v2 source file needed by staged terrain compilation.
final class PolygonTerrainChunkSource {
  PolygonTerrainChunkSource({
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
    required Iterable<PolygonTerrainPlacementSource> placements,
    Iterable<PolygonTerrainMarkerSource> markers =
        const <PolygonTerrainMarkerSource>[],
    required Iterable<PolygonTerrainShapeSource> collisionShapes,
  }) : placements = List<PolygonTerrainPlacementSource>.unmodifiable(
         placements,
       ),
       markers = List<PolygonTerrainMarkerSource>.unmodifiable(markers),
       collisionShapes = List<PolygonTerrainShapeSource>.unmodifiable(
         collisionShapes,
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
  final List<PolygonTerrainPlacementSource> placements;
  final List<PolygonTerrainMarkerSource> markers;
  final List<PolygonTerrainShapeSource> collisionShapes;

  List<PolygonTerrainPlacementSelection> placementSelections() {
    final counts = <String, int>{};
    return List<PolygonTerrainPlacementSelection>.unmodifiable(
      placements.map((placement) {
        final location =
            '${placement.resolvedPrefabRef}|${placement.x}|${placement.y}';
        final ordinal = counts[location] ?? 0;
        counts[location] = ordinal + 1;
        return PolygonTerrainPlacementSelection(
          placementKey: '$location|$ordinal',
          placement: placement,
        );
      }),
    );
  }
}

/// Strict prefab-v3 parser for the staged generator boundary.
///
/// Collision vertices must use whole source pixels. The shared point type keeps
/// half-pixel ticks so exact placement transforms remain integer-only.
PolygonTerrainPrefabSourceSet decodePolygonTerrainPrefabs(
  String raw, {
  String sourcePath = 'prefab_defs.json',
}) {
  final root = _root(raw, sourcePath);
  _keys(
    root,
    sourcePath,
    allowed: const {'schemaVersion', 'slices', 'prefabs'},
    required: const {'schemaVersion', 'slices', 'prefabs'},
  );
  _schema(
    root['schemaVersion'],
    polygonPrefabSchemaVersion,
    '$sourcePath.schemaVersion',
  );

  final slices = _objectList(root['slices'], '$sourcePath.slices');
  final sliceIds = <String>[];
  final sliceSources = <PolygonTerrainSliceSource>[];
  for (var index = 0; index < slices.length; index += 1) {
    final path = '$sourcePath.slices[$index]';
    final slice = slices[index];
    _keys(
      slice,
      path,
      allowed: const {
        'id',
        'sourceImagePath',
        'x',
        'y',
        'width',
        'height',
        'tags',
      },
      required: const {'id', 'sourceImagePath', 'x', 'y', 'width', 'height'},
    );
    final id = _string(slice['id'], '$path.id');
    sliceIds.add(id);
    sliceSources.add(
      PolygonTerrainSliceSource(
        id: id,
        sourceImagePath: _string(
          slice['sourceImagePath'],
          '$path.sourceImagePath',
        ),
        x: _integer(slice['x'], '$path.x'),
        y: _integer(slice['y'], '$path.y'),
        width: _positiveInt(slice['width'], '$path.width'),
        height: _positiveInt(slice['height'], '$path.height'),
      ),
    );
    if (slice.containsKey('tags')) _tags(slice['tags'], '$path.tags');
  }
  _strictOrder(sliceIds, '$sourcePath.slices');

  final prefabObjects = _objectList(root['prefabs'], '$sourcePath.prefabs');
  final prefabs = <PolygonTerrainPrefabSource>[];
  for (var index = 0; index < prefabObjects.length; index += 1) {
    final path = '$sourcePath.prefabs[$index]';
    final json = prefabObjects[index];
    _keys(
      json,
      path,
      allowed: const {
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
      required: const {
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
    final visualPath = '$path.visualSource';
    final visual = _object(json['visualSource'], visualPath);
    final visualType = _enum(visual['type'], const {
      'atlas_slice',
      'platform_module',
    }, '$visualPath.type');
    if (visualType == 'atlas_slice') {
      _keys(
        visual,
        visualPath,
        allowed: const {'type', 'sliceId'},
        required: const {'type', 'sliceId'},
      );
      _string(visual['sliceId'], '$visualPath.sliceId');
    } else {
      _keys(
        visual,
        visualPath,
        allowed: const {'type', 'moduleId'},
        required: const {'type', 'moduleId'},
      );
      _string(visual['moduleId'], '$visualPath.moduleId');
    }
    _integer(json['anchorXPx'], '$path.anchorXPx');
    _integer(json['anchorYPx'], '$path.anchorYPx');
    final kind = _enum(json['kind'], const {
      'obstacle',
      'platform',
      'decoration',
    }, '$path.kind');
    _tags(json['tags'], '$path.tags');
    final collisionShapes = _shapes(
      json['collisionShapes'],
      '$path.collisionShapes',
      allowRenderOnly: false,
      requireWholePixels: true,
    );
    final requiredMode = kind == 'platform'
        ? TerrainAuthoringPolygonMode.oneWay
        : TerrainAuthoringPolygonMode.solid;
    if (kind == 'decoration' && collisionShapes.isNotEmpty) {
      throw FormatException(
        '$path.collisionShapes must be empty when kind is decoration.',
      );
    }
    for (
      var shapeIndex = 0;
      shapeIndex < collisionShapes.length;
      shapeIndex += 1
    ) {
      if (collisionShapes[shapeIndex].collisionMode != requiredMode) {
        throw FormatException(
          '$path.collisionShapes[$shapeIndex].collisionMode must be '
          '${kind == 'platform' ? 'oneWay' : 'solid'} when kind is $kind.',
        );
      }
    }
    prefabs.add(
      PolygonTerrainPrefabSource(
        prefabKey: _string(json['prefabKey'], '$path.prefabKey'),
        id: _string(json['id'], '$path.id'),
        revision: _positiveInt(json['revision'], '$path.revision'),
        status: _enum(json['status'], const {
          'active',
          'deprecated',
        }, '$path.status'),
        kind: kind,
        anchorXPx: _integer(json['anchorXPx'], '$path.anchorXPx'),
        anchorYPx: _integer(json['anchorYPx'], '$path.anchorYPx'),
        visualSource: PolygonTerrainPrefabVisualSource(
          type: visualType,
          referenceId: _string(
            visual[visualType == 'platform_module' ? 'moduleId' : 'sliceId'],
            '$visualPath.${visualType == 'platform_module' ? 'moduleId' : 'sliceId'}',
          ),
        ),
        collisionShapes: collisionShapes,
      ),
    );
  }
  for (var index = 1; index < prefabs.length; index += 1) {
    if (_comparePrefabs(prefabs[index - 1], prefabs[index]) >= 0) {
      throw FormatException(
        '$sourcePath.prefabs must be in canonical order without duplicates.',
      );
    }
  }
  _unique(
    prefabs.map((prefab) => prefab.prefabKey),
    '$sourcePath.prefabs.prefabKey',
    caseInsensitive: true,
  );
  return PolygonTerrainPrefabSourceSet(prefabs, slices: sliceSources);
}

/// Immutable strict prefab collection with deterministic reference lookup.
final class PolygonTerrainPrefabSourceSet {
  PolygonTerrainPrefabSourceSet(
    Iterable<PolygonTerrainPrefabSource> prefabs, {
    Iterable<PolygonTerrainSliceSource> slices =
        const <PolygonTerrainSliceSource>[],
  }) : prefabs = List<PolygonTerrainPrefabSource>.unmodifiable(prefabs),
       slices = List<PolygonTerrainSliceSource>.unmodifiable(slices);

  final List<PolygonTerrainPrefabSource> prefabs;
  final List<PolygonTerrainSliceSource> slices;
}

/// Strict chunk-v2 parser for the staged generator boundary.
PolygonTerrainChunkSource decodePolygonTerrainChunk(
  String raw, {
  String sourcePath = 'chunk.json',
}) {
  final root = _root(raw, sourcePath);
  _keys(
    root,
    sourcePath,
    allowed: const {
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
    required: const {
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
  _schema(
    root['schemaVersion'],
    polygonChunkSchemaVersion,
    '$sourcePath.schemaVersion',
  );
  _tags(root['tags'], '$sourcePath.tags');
  if (root.containsKey('groundBandZIndex')) {
    _integer(root['groundBandZIndex'], '$sourcePath.groundBandZIndex');
  }

  final layers = _objectList(root['tileLayers'], '$sourcePath.tileLayers');
  final layerIds = <String>[];
  for (var index = 0; index < layers.length; index += 1) {
    final path = '$sourcePath.tileLayers[$index]';
    final layer = layers[index];
    _keys(
      layer,
      path,
      allowed: const {'id', 'kind', 'visible'},
      required: const {'id', 'kind', 'visible'},
    );
    layerIds.add(_string(layer['id'], '$path.id'));
    _string(layer['kind'], '$path.kind');
    _boolean(layer['visible'], '$path.visible');
  }
  _strictOrder(layerIds, '$sourcePath.tileLayers');

  final placementObjects = _objectList(root['prefabs'], '$sourcePath.prefabs');
  final placements = <PolygonTerrainPlacementSource>[];
  for (var index = 0; index < placementObjects.length; index += 1) {
    final path = '$sourcePath.prefabs[$index]';
    final json = placementObjects[index];
    _keys(
      json,
      path,
      allowed: const {
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
      required: const {'prefabId', 'x', 'y', 'zIndex', 'snapToGrid'},
    );
    placements.add(
      PolygonTerrainPlacementSource(
        prefabId: _string(json['prefabId'], '$path.prefabId'),
        prefabKey: json.containsKey('prefabKey')
            ? _string(json['prefabKey'], '$path.prefabKey')
            : null,
        x: _integer(json['x'], '$path.x'),
        y: _integer(json['y'], '$path.y'),
        zIndex: _integer(json['zIndex'], '$path.zIndex'),
        snapToGrid: _boolean(json['snapToGrid'], '$path.snapToGrid'),
        scaleTenths: json.containsKey('scale')
            ? _scaleTenths(json['scale'], '$path.scale')
            : _defaultScaleTenths,
        flipX: json.containsKey('flipX')
            ? _boolean(json['flipX'], '$path.flipX')
            : false,
        flipY: json.containsKey('flipY')
            ? _boolean(json['flipY'], '$path.flipY')
            : false,
      ),
    );
  }
  for (var index = 1; index < placements.length; index += 1) {
    if (_comparePlacements(placements[index - 1], placements[index]) >= 0) {
      throw FormatException(
        '$sourcePath.prefabs must be in canonical order without duplicates.',
      );
    }
  }

  final markers = _objectList(root['markers'], '$sourcePath.markers');
  final markerOrder = <_MarkerOrder>[];
  final markerSources = <PolygonTerrainMarkerSource>[];
  for (var index = 0; index < markers.length; index += 1) {
    final path = '$sourcePath.markers[$index]';
    final json = markers[index];
    _keys(
      json,
      path,
      allowed: const {
        'markerId',
        'x',
        'y',
        'chancePercent',
        'salt',
        'placement',
      },
      required: const {
        'markerId',
        'x',
        'y',
        'chancePercent',
        'salt',
        'placement',
      },
    );
    final chance = _integer(json['chancePercent'], '$path.chancePercent');
    if (chance < 0 || chance > 100) {
      throw FormatException('$path.chancePercent must be from 0 to 100.');
    }
    final markerId = _string(json['markerId'], '$path.markerId');
    final x = _integer(json['x'], '$path.x');
    final y = _integer(json['y'], '$path.y');
    final salt = _integer(json['salt'], '$path.salt');
    final placement = _enum(json['placement'], const {
      'ground',
      'highestSurfaceAtX',
      'obstacleTop',
    }, '$path.placement');
    markerOrder.add(
      _MarkerOrder(
        markerId: markerId,
        x: x,
        y: y,
        chance: chance,
        salt: salt,
        placement: placement,
      ),
    );
    markerSources.add(
      PolygonTerrainMarkerSource(
        markerId: markerId,
        x: x,
        y: y,
        chancePercent: chance,
        salt: salt,
        placement: placement,
      ),
    );
  }
  for (var index = 1; index < markerOrder.length; index += 1) {
    if (_compareMarkers(markerOrder[index - 1], markerOrder[index]) >= 0) {
      throw FormatException(
        '$sourcePath.markers must be in canonical order without duplicates.',
      );
    }
  }

  return PolygonTerrainChunkSource(
    chunkKey: _string(root['chunkKey'], '$sourcePath.chunkKey'),
    id: _string(root['id'], '$sourcePath.id'),
    revision: _positiveInt(root['revision'], '$sourcePath.revision'),
    status: _enum(root['status'], const {
      'active',
      'deprecated',
    }, '$sourcePath.status'),
    levelId: _string(root['levelId'], '$sourcePath.levelId'),
    tileSize: _positiveInt(root['tileSize'], '$sourcePath.tileSize'),
    width: _positiveInt(root['width'], '$sourcePath.width'),
    height: _positiveInt(root['height'], '$sourcePath.height'),
    difficulty: _enum(root['difficulty'], const {
      'early',
      'easy',
      'normal',
      'hard',
    }, '$sourcePath.difficulty'),
    assemblyGroupId: _string(
      root['assemblyGroupId'],
      '$sourcePath.assemblyGroupId',
    ),
    placements: placements,
    markers: markerSources,
    collisionShapes: _shapes(
      root['collisionShapes'],
      '$sourcePath.collisionShapes',
      allowRenderOnly: true,
      requireWholePixels: true,
    ),
  );
}

List<PolygonTerrainShapeSource> _shapes(
  Object? raw,
  String sourcePath, {
  required bool allowRenderOnly,
  required bool requireWholePixels,
}) {
  final objects = _objectList(raw, sourcePath);
  final shapes = <PolygonTerrainShapeSource>[];
  for (var index = 0; index < objects.length; index += 1) {
    final path = '$sourcePath[$index]';
    final json = objects[index];
    _keys(
      json,
      path,
      allowed: const {
        'shapeId',
        'collisionMode',
        'vertices',
        'surfaceKind',
        'materialKey',
      },
      required: const {'shapeId', 'collisionMode', 'vertices'},
    );
    final shapeId = _string(json['shapeId'], '$path.shapeId');
    if (!_stableShapeId.hasMatch(shapeId)) {
      throw FormatException(
        '$path.shapeId must match ${_stableShapeId.pattern}.',
      );
    }
    final verticesRaw = json['vertices'];
    if (verticesRaw is! List<Object?>) {
      throw FormatException('$path.vertices must be an array.');
    }
    final vertices = <PolygonTerrainSourcePoint>[];
    for (
      var vertexIndex = 0;
      vertexIndex < verticesRaw.length;
      vertexIndex += 1
    ) {
      final vertexPath = '$path.vertices[$vertexIndex]';
      final vertex = _object(verticesRaw[vertexIndex], vertexPath);
      _keys(
        vertex,
        vertexPath,
        allowed: const {'x', 'y'},
        required: const {'x', 'y'},
      );
      final xHalfPixels = _halfPixelTicks(vertex['x'], '$vertexPath.x');
      final yHalfPixels = _halfPixelTicks(vertex['y'], '$vertexPath.y');
      if (requireWholePixels && xHalfPixels.isOdd) {
        throw FormatException(
          '$vertexPath.x must be a whole-pixel coordinate.',
        );
      }
      if (requireWholePixels && yHalfPixels.isOdd) {
        throw FormatException(
          '$vertexPath.y must be a whole-pixel coordinate.',
        );
      }
      vertices.add(
        PolygonTerrainSourcePoint(
          xHalfPixels: xHalfPixels,
          yHalfPixels: yHalfPixels,
        ),
      );
    }
    shapes.add(
      PolygonTerrainShapeSource(
        shapeId: shapeId,
        vertices: vertices,
        collisionMode: switch (_enum(
          json['collisionMode'],
          allowRenderOnly
              ? const {'none', 'solid', 'oneWay'}
              : const {'solid', 'oneWay'},
          '$path.collisionMode',
        )) {
          'solid' => TerrainAuthoringPolygonMode.solid,
          'oneWay' => TerrainAuthoringPolygonMode.oneWay,
          'none' => TerrainAuthoringPolygonMode.none,
          _ => throw StateError('Unreachable collision mode.'),
        },
        surfaceKind: json.containsKey('surfaceKind')
            ? _string(json['surfaceKind'], '$path.surfaceKind')
            : null,
        materialKey: json.containsKey('materialKey')
            ? _string(json['materialKey'], '$path.materialKey')
            : null,
      ),
    );
  }
  _strictOrder(shapes.map((shape) => shape.shapeId), sourcePath);
  return List<PolygonTerrainShapeSource>.unmodifiable(shapes);
}

Map<String, Object?> _root(String raw, String sourcePath) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (error) {
    throw FormatException('$sourcePath is malformed JSON: ${error.message}');
  }
  return _object(decoded, sourcePath);
}

Map<String, Object?> _object(Object? raw, String sourcePath) {
  if (raw is! Map<Object?, Object?> || raw.keys.any((key) => key is! String)) {
    throw FormatException('$sourcePath must be an object.');
  }
  return <String, Object?>{
    for (final entry in raw.entries) entry.key! as String: entry.value,
  };
}

List<Map<String, Object?>> _objectList(Object? raw, String sourcePath) {
  if (raw is! List<Object?>) {
    throw FormatException('$sourcePath must be an array.');
  }
  return <Map<String, Object?>>[
    for (var index = 0; index < raw.length; index += 1)
      _object(raw[index], '$sourcePath[$index]'),
  ];
}

void _keys(
  Map<String, Object?> json,
  String sourcePath, {
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

void _schema(Object? raw, int expected, String sourcePath) {
  if (raw is! int || raw != expected) {
    throw FormatException('$sourcePath must be exactly $expected.');
  }
}

String _string(Object? raw, String sourcePath) {
  if (raw is! String || raw.isEmpty || raw.trim() != raw) {
    throw FormatException('$sourcePath must be a non-empty trimmed string.');
  }
  return raw;
}

String _enum(Object? raw, Set<String> accepted, String sourcePath) {
  final value = _string(raw, sourcePath);
  if (!accepted.contains(value)) {
    final choices = accepted.toList()..sort();
    throw FormatException('$sourcePath must be one of ${choices.join(', ')}.');
  }
  return value;
}

int _integer(Object? raw, String sourcePath) {
  if (raw is! int) throw FormatException('$sourcePath must be an integer.');
  return raw;
}

int _positiveInt(Object? raw, String sourcePath) {
  final value = _integer(raw, sourcePath);
  if (value <= 0) throw FormatException('$sourcePath must be positive.');
  return value;
}

bool _boolean(Object? raw, String sourcePath) {
  if (raw is! bool) throw FormatException('$sourcePath must be a boolean.');
  return raw;
}

int _scaleTenths(Object? raw, String sourcePath) {
  if (raw is! num || !raw.isFinite) {
    throw FormatException('$sourcePath must be a finite number.');
  }
  final scaled = raw.toDouble() * 10;
  final tenths = scaled.round();
  if ((scaled - tenths).abs() >= 1e-9 ||
      tenths < _minScaleTenths ||
      tenths > _maxScaleTenths) {
    throw FormatException(
      '$sourcePath must use an accepted 0.3-3.0 scale in 0.1 steps.',
    );
  }
  return tenths;
}

int _halfPixelTicks(Object? raw, String sourcePath) {
  int ticks;
  if (raw is int) {
    ticks = raw * 2;
  } else if (raw is double && raw.isFinite) {
    final scaled = raw * 2;
    if (!scaled.isFinite || scaled != scaled.truncateToDouble()) {
      throw FormatException('$sourcePath must be divisible exactly by 0.5.');
    }
    ticks = scaled.toInt();
  } else {
    throw FormatException('$sourcePath must be a finite number.');
  }
  if (ticks.abs() > _maxExactHalfPixelTicks) {
    throw FormatException(
      '$sourcePath exceeds the exact canonical JSON coordinate range.',
    );
  }
  return ticks;
}

void _tags(Object? raw, String sourcePath) {
  if (raw is! List<Object?>) {
    throw FormatException('$sourcePath must be an array.');
  }
  _strictOrder(<String>[
    for (var index = 0; index < raw.length; index += 1)
      _string(raw[index], '$sourcePath[$index]'),
  ], sourcePath);
}

void _strictOrder(Iterable<String> values, String sourcePath) {
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

void _unique(
  Iterable<String> values,
  String sourcePath, {
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

int _comparePrefabs(
  PolygonTerrainPrefabSource left,
  PolygonTerrainPrefabSource right,
) {
  final id = left.id.compareTo(right.id);
  return id != 0 ? id : left.prefabKey.compareTo(right.prefabKey);
}

int _comparePlacements(
  PolygonTerrainPlacementSource left,
  PolygonTerrainPlacementSource right,
) {
  var order = left.zIndex.compareTo(right.zIndex);
  if (order != 0) return order;
  order = left.y.compareTo(right.y);
  if (order != 0) return order;
  order = left.x.compareTo(right.x);
  if (order != 0) return order;
  order = left.resolvedPrefabRef.compareTo(right.resolvedPrefabRef);
  if (order != 0) return order;
  order = _compareBool(left.snapToGrid, right.snapToGrid);
  if (order != 0) return order;
  order = left.scaleTenths.compareTo(right.scaleTenths);
  if (order != 0) return order;
  order = _compareBool(left.flipX, right.flipX);
  if (order != 0) return order;
  order = _compareBool(left.flipY, right.flipY);
  return order != 0 ? order : left.prefabId.compareTo(right.prefabId);
}

int _compareBool(bool left, bool right) => left == right ? 0 : (left ? 1 : -1);

final class _MarkerOrder {
  const _MarkerOrder({
    required this.markerId,
    required this.x,
    required this.y,
    required this.chance,
    required this.salt,
    required this.placement,
  });

  final String markerId;
  final int x;
  final int y;
  final int chance;
  final int salt;
  final String placement;
}

int _compareMarkers(_MarkerOrder left, _MarkerOrder right) {
  var order = left.y.compareTo(right.y);
  if (order != 0) return order;
  order = left.x.compareTo(right.x);
  if (order != 0) return order;
  order = left.markerId.compareTo(right.markerId);
  if (order != 0) return order;
  order = left.placement.compareTo(right.placement);
  if (order != 0) return order;
  order = left.chance.compareTo(right.chance);
  return order != 0 ? order : left.salt.compareTo(right.salt);
}
