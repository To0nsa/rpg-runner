import 'dart:convert';

import 'polygon_terrain_source.dart';

/// Current schema version for authored tile slices and platform modules.
const int polygonTileSchemaVersion = 2;

/// One cell within a platform-module visual source.
final class PolygonTileModuleCellSource {
  const PolygonTileModuleCellSource({
    required this.sliceId,
    required this.gridX,
    required this.gridY,
  });

  final String sliceId;
  final int gridX;
  final int gridY;
}

/// One immutable platform-module visual source.
final class PolygonTileModuleSource {
  PolygonTileModuleSource({
    required this.id,
    required this.revision,
    required this.status,
    required this.tileSize,
    required Iterable<PolygonTileModuleCellSource> cells,
  }) : cells = List<PolygonTileModuleCellSource>.unmodifiable(cells);

  final String id;
  final int revision;
  final String status;
  final int tileSize;
  final List<PolygonTileModuleCellSource> cells;
}

/// Strict tile-v2 source catalog used by runtime visual materialization.
final class PolygonTileSourceSet {
  PolygonTileSourceSet({
    required Iterable<PolygonTerrainSliceSource> slices,
    required Iterable<PolygonTileModuleSource> modules,
  }) : slices = List<PolygonTerrainSliceSource>.unmodifiable(slices),
       modules = List<PolygonTileModuleSource>.unmodifiable(modules);

  final List<PolygonTerrainSliceSource> slices;
  final List<PolygonTileModuleSource> modules;
}

/// Decodes the strict current tile-v2 catalog without repository I/O.
PolygonTileSourceSet decodePolygonTileSources(
  String raw, {
  String sourcePath = 'tile_defs.json',
}) {
  final root = _root(raw, sourcePath);
  _keys(
    root,
    sourcePath,
    allowed: const <String>{'schemaVersion', 'tileSlices', 'platformModules'},
    required: const <String>{'schemaVersion', 'tileSlices', 'platformModules'},
  );
  final schemaVersion = _integer(
    root['schemaVersion'],
    '$sourcePath.schemaVersion',
  );
  if (schemaVersion != polygonTileSchemaVersion) {
    throw FormatException(
      '$sourcePath.schemaVersion must be $polygonTileSchemaVersion.',
    );
  }

  final slices = <PolygonTerrainSliceSource>[];
  final sliceObjects = _objectList(
    root['tileSlices'],
    '$sourcePath.tileSlices',
  );
  for (var index = 0; index < sliceObjects.length; index += 1) {
    final path = '$sourcePath.tileSlices[$index]';
    final json = sliceObjects[index];
    _keys(
      json,
      path,
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
    if (json.containsKey('tags')) _stringList(json['tags'], '$path.tags');
    slices.add(
      PolygonTerrainSliceSource(
        id: _string(json['id'], '$path.id'),
        sourceImagePath: _string(
          json['sourceImagePath'],
          '$path.sourceImagePath',
        ),
        x: _integer(json['x'], '$path.x'),
        y: _integer(json['y'], '$path.y'),
        width: _positiveInt(json['width'], '$path.width'),
        height: _positiveInt(json['height'], '$path.height'),
      ),
    );
  }
  _strictUniqueOrder(slices.map((slice) => slice.id), '$sourcePath.tileSlices');

  final modules = <PolygonTileModuleSource>[];
  final moduleObjects = _objectList(
    root['platformModules'],
    '$sourcePath.platformModules',
  );
  for (var index = 0; index < moduleObjects.length; index += 1) {
    final path = '$sourcePath.platformModules[$index]';
    final json = moduleObjects[index];
    _keys(
      json,
      path,
      allowed: const <String>{'id', 'revision', 'status', 'tileSize', 'cells'},
      required: const <String>{'id', 'revision', 'status', 'tileSize', 'cells'},
    );
    final cells = <PolygonTileModuleCellSource>[];
    final occupied = <(int, int)>{};
    final cellObjects = _objectList(json['cells'], '$path.cells');
    for (var cellIndex = 0; cellIndex < cellObjects.length; cellIndex += 1) {
      final cellPath = '$path.cells[$cellIndex]';
      final cell = cellObjects[cellIndex];
      _keys(
        cell,
        cellPath,
        allowed: const <String>{'sliceId', 'gridX', 'gridY'},
        required: const <String>{'sliceId', 'gridX', 'gridY'},
      );
      final parsed = PolygonTileModuleCellSource(
        sliceId: _string(cell['sliceId'], '$cellPath.sliceId'),
        gridX: _integer(cell['gridX'], '$cellPath.gridX'),
        gridY: _integer(cell['gridY'], '$cellPath.gridY'),
      );
      if (!occupied.add((parsed.gridX, parsed.gridY))) {
        throw FormatException(
          '$path.cells must contain unique grid positions.',
        );
      }
      if (cells.isNotEmpty && _compareCells(cells.last, parsed) >= 0) {
        throw FormatException(
          '$path.cells must be in canonical order without duplicates.',
        );
      }
      cells.add(parsed);
    }
    modules.add(
      PolygonTileModuleSource(
        id: _string(json['id'], '$path.id'),
        revision: _positiveInt(json['revision'], '$path.revision'),
        status: _enum(json['status'], const <String>{
          'active',
          'deprecated',
        }, '$path.status'),
        tileSize: _positiveInt(json['tileSize'], '$path.tileSize'),
        cells: cells,
      ),
    );
  }
  for (var index = 1; index < modules.length; index += 1) {
    if (_compareModules(modules[index - 1], modules[index]) >= 0) {
      throw FormatException(
        '$sourcePath.platformModules must be in canonical order without duplicates.',
      );
    }
  }
  _uniqueFolded(
    modules.map((module) => module.id),
    '$sourcePath.platformModules.id',
  );
  return PolygonTileSourceSet(slices: slices, modules: modules);
}

Map<String, Object?> _root(String raw, String path) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (error) {
    throw FormatException('$path: ${error.message}');
  }
  return _object(decoded, path);
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$path must be an object.');
  }
  return value;
}

List<Map<String, Object?>> _objectList(Object? value, String path) {
  if (value is! List<Object?>) throw FormatException('$path must be an array.');
  return <Map<String, Object?>>[
    for (var index = 0; index < value.length; index += 1)
      _object(value[index], '$path[$index]'),
  ];
}

void _keys(
  Map<String, Object?> json,
  String path, {
  required Set<String> allowed,
  required Set<String> required,
}) {
  final unknown = json.keys.where((key) => !allowed.contains(key)).toList()
    ..sort();
  if (unknown.isNotEmpty) {
    throw FormatException('$path contains unknown key "${unknown.first}".');
  }
  final missing = required.where((key) => !json.containsKey(key)).toList()
    ..sort();
  if (missing.isNotEmpty) {
    throw FormatException('$path is missing required key "${missing.first}".');
  }
}

String _string(Object? value, String path) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('$path must be a non-empty trimmed string.');
  }
  return value;
}

String _enum(Object? value, Set<String> accepted, String path) {
  final parsed = _string(value, path);
  if (!accepted.contains(parsed)) {
    throw FormatException('$path must be one of ${accepted.join(', ')}.');
  }
  return parsed;
}

int _integer(Object? value, String path) {
  if (value is! int) throw FormatException('$path must be an integer.');
  return value;
}

int _positiveInt(Object? value, String path) {
  final parsed = _integer(value, path);
  if (parsed <= 0) throw FormatException('$path must be greater than zero.');
  return parsed;
}

void _stringList(Object? value, String path) {
  if (value is! List<Object?>) throw FormatException('$path must be an array.');
  final parsed = <String>[];
  for (var index = 0; index < value.length; index += 1) {
    parsed.add(_string(value[index], '$path[$index]'));
  }
  _strictUniqueOrder(parsed, path);
}

void _strictUniqueOrder(Iterable<String> values, String path) {
  String? previous;
  for (final value in values) {
    if (previous != null && previous.compareTo(value) >= 0) {
      throw FormatException(
        '$path must be in canonical order without duplicates.',
      );
    }
    previous = value;
  }
  _uniqueFolded(values, path);
}

void _uniqueFolded(Iterable<String> values, String path) {
  final seen = <String>{};
  for (final value in values) {
    if (!seen.add(value.toLowerCase())) {
      throw FormatException('$path must be unique ignoring case.');
    }
  }
}

int _compareCells(
  PolygonTileModuleCellSource left,
  PolygonTileModuleCellSource right,
) {
  var order = left.gridY.compareTo(right.gridY);
  if (order != 0) return order;
  order = left.gridX.compareTo(right.gridX);
  return order != 0 ? order : left.sliceId.compareTo(right.sliceId);
}

int _compareModules(
  PolygonTileModuleSource left,
  PolygonTileModuleSource right,
) {
  final statusOrder = (left.status == 'active' ? 0 : 1).compareTo(
    right.status == 'active' ? 0 : 1,
  );
  if (statusOrder != 0) return statusOrder;
  final idOrder = left.id.compareTo(right.id);
  if (idOrder != 0) return idOrder;
  return left.revision.compareTo(right.revision);
}
