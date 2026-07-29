/// Physical sidedness authored independently from surface and material tags.
enum TerrainSourceCollisionMode { solid, oneWay }

/// Exact vertex on the authoring half-pixel grid.
///
/// Coordinates are stored as integer half-pixel ticks: `1` represents
/// `0.5 px`. JSON conversion rejects values outside that grid instead of
/// rounding them.
final class TerrainSourceVertexDef {
  const TerrainSourceVertexDef({
    required this.xHalfPixels,
    required this.yHalfPixels,
  });

  /// Horizontal position in half-pixel ticks.
  final int xHalfPixels;

  /// Vertical position in half-pixel ticks.
  final int yHalfPixels;

  /// Parses `{x, y}` pixel coordinates without losing half-pixel precision.
  factory TerrainSourceVertexDef.fromJson(
    Map<String, Object?> json, {
    String sourcePath = r'$vertex',
  }) {
    return TerrainSourceVertexDef(
      xHalfPixels: _halfPixelTicksFromJson(
        json['x'],
        sourcePath: '$sourcePath.x',
      ),
      yHalfPixels: _halfPixelTicksFromJson(
        json['y'],
        sourcePath: '$sourcePath.y',
      ),
    );
  }

  /// Emits exact pixel coordinates using only integers or one `.5` fraction.
  Map<String, Object> toJson() => <String, Object>{
    'x': _halfPixelTicksToJson(xHalfPixels),
    'y': _halfPixelTicksToJson(yHalfPixels),
  };

  @override
  bool operator ==(Object other) =>
      other is TerrainSourceVertexDef &&
      xHalfPixels == other.xHalfPixels &&
      yHalfPixels == other.yHalfPixels;

  @override
  int get hashCode => Object.hash(xHalfPixels, yHalfPixels);
}

/// Immutable authored collision loop with stable owner-local identity.
///
/// Vertex order is geometry order and is preserved exactly. Cross-shape
/// ordering and owner-local ID uniqueness are enforced by
/// [canonicalTerrainSourceShapes].
final class TerrainSourceShapeDef {
  factory TerrainSourceShapeDef({
    required String shapeId,
    required Iterable<TerrainSourceVertexDef> vertices,
    TerrainSourceCollisionMode collisionMode = TerrainSourceCollisionMode.solid,
    String? surfaceKind,
    String? materialKey,
  }) {
    _requireStableShapeId(shapeId);
    _requireOptionalMetadata(surfaceKind, fieldName: 'surfaceKind');
    _requireOptionalMetadata(materialKey, fieldName: 'materialKey');
    return TerrainSourceShapeDef._(
      shapeId: shapeId,
      vertices: List<TerrainSourceVertexDef>.unmodifiable(vertices),
      collisionMode: collisionMode,
      surfaceKind: surfaceKind,
      materialKey: materialKey,
    );
  }

  const TerrainSourceShapeDef._({
    required this.shapeId,
    required this.vertices,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
  });

  /// Stable lowercase identifier within the owning prefab or chunk.
  final String shapeId;

  /// Ordered polygon loop in exact half-pixel coordinates.
  final List<TerrainSourceVertexDef> vertices;

  /// Whether the compiled boundary is solid or one-way.
  final TerrainSourceCollisionMode collisionMode;

  /// Optional gameplay surface classifier preserved without interpretation.
  final String? surfaceKind;

  /// Optional render/material classifier preserved without interpretation.
  final String? materialKey;

  /// Parses one strict source shape while preserving authored vertex order.
  factory TerrainSourceShapeDef.fromJson(
    Map<String, Object?> json, {
    String sourcePath = r'$shape',
  }) {
    final shapeId = json['shapeId'];
    if (shapeId is! String) {
      throw FormatException('$sourcePath.shapeId must be a string.');
    }
    try {
      _requireStableShapeId(shapeId);
    } on ArgumentError catch (error) {
      throw FormatException('$sourcePath.shapeId: ${error.message}');
    }

    final rawCollisionMode = json['collisionMode'];
    if (rawCollisionMode is! String) {
      throw FormatException('$sourcePath.collisionMode must be a string.');
    }
    final collisionMode = _collisionModeFromJson(
      rawCollisionMode,
      sourcePath: '$sourcePath.collisionMode',
    );

    final rawVertices = json['vertices'];
    if (rawVertices is! List<Object?>) {
      throw FormatException('$sourcePath.vertices must be an array.');
    }
    final vertices = <TerrainSourceVertexDef>[];
    for (var index = 0; index < rawVertices.length; index += 1) {
      final rawVertex = rawVertices[index];
      if (rawVertex is! Map<String, Object?>) {
        throw FormatException(
          '$sourcePath.vertices[$index] must be an object.',
        );
      }
      vertices.add(
        TerrainSourceVertexDef.fromJson(
          rawVertex,
          sourcePath: '$sourcePath.vertices[$index]',
        ),
      );
    }

    final surfaceKind = _optionalMetadataFromJson(
      json['surfaceKind'],
      sourcePath: '$sourcePath.surfaceKind',
    );
    final materialKey = _optionalMetadataFromJson(
      json['materialKey'],
      sourcePath: '$sourcePath.materialKey',
    );

    return TerrainSourceShapeDef(
      shapeId: shapeId,
      vertices: vertices,
      collisionMode: collisionMode,
      surfaceKind: surfaceKind,
      materialKey: materialKey,
    );
  }

  /// Emits canonical field names while retaining the polygon loop order.
  Map<String, Object> toJson() => <String, Object>{
    'shapeId': shapeId,
    'collisionMode': _collisionModeToJson(collisionMode),
    'vertices': vertices
        .map((vertex) => vertex.toJson())
        .toList(growable: false),
    'surfaceKind': ?surfaceKind,
    'materialKey': ?materialKey,
  };

  @override
  bool operator ==(Object other) {
    if (other is! TerrainSourceShapeDef ||
        shapeId != other.shapeId ||
        collisionMode != other.collisionMode ||
        surfaceKind != other.surfaceKind ||
        materialKey != other.materialKey ||
        vertices.length != other.vertices.length) {
      return false;
    }
    for (var index = 0; index < vertices.length; index += 1) {
      if (vertices[index] != other.vertices[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    shapeId,
    collisionMode,
    surfaceKind,
    materialKey,
    Object.hashAll(vertices),
  );
}

/// Validates owner-local shape IDs and returns stable `shapeId` order.
///
/// Exact and case-folded duplicates are rejected. Vertex lists are never
/// reordered or normalized by this operation.
List<TerrainSourceShapeDef> canonicalTerrainSourceShapes(
  Iterable<TerrainSourceShapeDef> shapes,
) {
  final sorted = List<TerrainSourceShapeDef>.of(shapes)
    ..sort((left, right) => left.shapeId.compareTo(right.shapeId));
  final exactIds = <String>{};
  final foldedIds = <String>{};
  for (final shape in sorted) {
    if (!exactIds.add(shape.shapeId)) {
      throw ArgumentError.value(
        shape.shapeId,
        'shapes',
        'Duplicate terrain shape ID.',
      );
    }
    final folded = shape.shapeId.toLowerCase();
    if (!foldedIds.add(folded)) {
      throw ArgumentError.value(
        shape.shapeId,
        'shapes',
        'Case-insensitive terrain shape ID collision.',
      );
    }
  }
  return List<TerrainSourceShapeDef>.unmodifiable(sorted);
}

/// Parses and owner-validates a source shape array in stable ID order.
List<TerrainSourceShapeDef> terrainSourceShapesFromJson(
  Object? raw, {
  String sourcePath = r'$collisionShapes',
}) {
  if (raw is! List<Object?>) {
    throw FormatException('$sourcePath must be an array.');
  }
  final shapes = <TerrainSourceShapeDef>[];
  for (var index = 0; index < raw.length; index += 1) {
    final rawShape = raw[index];
    if (rawShape is! Map<String, Object?>) {
      throw FormatException('$sourcePath[$index] must be an object.');
    }
    shapes.add(
      TerrainSourceShapeDef.fromJson(
        rawShape,
        sourcePath: '$sourcePath[$index]',
      ),
    );
  }
  try {
    return canonicalTerrainSourceShapes(shapes);
  } on ArgumentError catch (error) {
    throw FormatException('$sourcePath: ${error.message}');
  }
}

/// Serializes owner-valid shapes in stable ID order.
List<Map<String, Object>> terrainSourceShapesToJson(
  Iterable<TerrainSourceShapeDef> shapes,
) => canonicalTerrainSourceShapes(
  shapes,
).map((shape) => shape.toJson()).toList(growable: false);

const int _maxExactHalfPixelTicks = (1 << 52) - 1;
final RegExp _stableShapeIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

int _halfPixelTicksFromJson(Object? raw, {required String sourcePath}) {
  int halfPixelTicks;
  if (raw is int) {
    halfPixelTicks = raw * 2;
  } else if (raw is double && raw.isFinite) {
    final scaled = raw * 2;
    if (!scaled.isFinite || scaled != scaled.truncateToDouble()) {
      throw FormatException('$sourcePath must be divisible exactly by 0.5.');
    }
    halfPixelTicks = scaled.toInt();
  } else {
    throw FormatException('$sourcePath must be a finite number.');
  }
  if (halfPixelTicks.abs() > _maxExactHalfPixelTicks) {
    throw FormatException(
      '$sourcePath exceeds the exact canonical JSON coordinate range.',
    );
  }
  return halfPixelTicks;
}

Object _halfPixelTicksToJson(int halfPixelTicks) {
  if (halfPixelTicks.abs() > _maxExactHalfPixelTicks) {
    throw ArgumentError.value(
      halfPixelTicks,
      'halfPixelTicks',
      'Exceeds the exact canonical JSON coordinate range.',
    );
  }
  if (halfPixelTicks.isEven) {
    return halfPixelTicks ~/ 2;
  }
  return halfPixelTicks / 2;
}

void _requireStableShapeId(String shapeId) {
  if (!_stableShapeIdPattern.hasMatch(shapeId)) {
    throw ArgumentError.value(
      shapeId,
      'shapeId',
      'Must match ${_stableShapeIdPattern.pattern}.',
    );
  }
}

void _requireOptionalMetadata(String? value, {required String fieldName}) {
  if (value != null && value.trim().isEmpty) {
    throw ArgumentError.value(value, fieldName, 'Must be null or non-empty.');
  }
}

String? _optionalMetadataFromJson(Object? raw, {required String sourcePath}) {
  if (raw == null) {
    return null;
  }
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$sourcePath must be null or a non-empty string.');
  }
  return raw;
}

TerrainSourceCollisionMode _collisionModeFromJson(
  String raw, {
  required String sourcePath,
}) => switch (raw) {
  'solid' => TerrainSourceCollisionMode.solid,
  'oneWay' => TerrainSourceCollisionMode.oneWay,
  _ => throw FormatException('$sourcePath must be solid or oneWay.'),
};

String _collisionModeToJson(TerrainSourceCollisionMode collisionMode) =>
    switch (collisionMode) {
      TerrainSourceCollisionMode.solid => 'solid',
      TerrainSourceCollisionMode.oneWay => 'oneWay',
    };
