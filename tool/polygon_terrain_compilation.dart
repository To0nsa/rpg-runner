import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_source_canonicalizer.dart';

import 'polygon_terrain_source.dart';

/// One stable blocking staged-generator diagnostic.
final class PolygonTerrainGenerationIssue
    implements Comparable<PolygonTerrainGenerationIssue> {
  const PolygonTerrainGenerationIssue({
    required this.code,
    required this.message,
    required this.sourcePath,
    this.placementKey,
    this.shapeId,
    this.elementIndex,
  });

  final String code;
  final String message;
  final String sourcePath;
  final String? placementKey;
  final String? shapeId;
  final int? elementIndex;

  @override
  int compareTo(PolygonTerrainGenerationIssue other) {
    var order = sourcePath.compareTo(other.sourcePath);
    if (order != 0) return order;
    order = (placementKey ?? '').compareTo(other.placementKey ?? '');
    if (order != 0) return order;
    order = (shapeId ?? '').compareTo(other.shapeId ?? '');
    if (order != 0) return order;
    order = (elementIndex ?? -1).compareTo(other.elementIndex ?? -1);
    return order != 0 ? order : code.compareTo(other.code);
  }
}

/// Stable prefab placement lineage retained beside compiled local geometry.
final class PolygonTerrainPlacementLineage {
  const PolygonTerrainPlacementLineage({
    required this.chunkKey,
    required this.placementKey,
    required this.prefabKey,
    required this.prefabId,
    required this.prefabRevision,
    required this.shapeId,
    required this.placementX,
    required this.placementY,
    required this.scaleTenths,
    required this.flipX,
    required this.flipY,
  });

  final String chunkKey;
  final String placementKey;
  final String prefabKey;
  final String prefabId;
  final int prefabRevision;
  final String shapeId;
  final int placementX;
  final int placementY;
  final int scaleTenths;
  final bool flipX;
  final bool flipY;

  String canonicalRecord() => _canonicalRecord(<String>[
    'authoring-placement-v1',
    chunkKey,
    placementKey,
    prefabKey,
    prefabId,
    prefabRevision.toString(),
    shapeId,
    placementX.toString(),
    placementY.toString(),
    scaleTenths.toString(),
    flipX ? '1' : '0',
    flipY ? '1' : '0',
  ]);
}

/// One exact triangle referencing a Core-normalized polygon loop.
final class PolygonTerrainTriangle {
  const PolygonTerrainTriangle({
    required this.chunkKey,
    required this.placementKey,
    required this.shapeId,
    required this.first,
    required this.second,
    required this.third,
  });

  final String chunkKey;
  final String? placementKey;
  final String shapeId;
  final int first;
  final int second;
  final int third;

  String canonicalRecord() => _canonicalRecord(<String>[
    'authoring-triangles-v1',
    chunkKey,
    placementKey ?? '',
    shapeId,
    first.toString(),
    second.toString(),
    third.toString(),
  ]);
}

/// Accepted local staged terrain for one chunk-v2 source file.
final class PolygonTerrainCompiledChunk {
  PolygonTerrainCompiledChunk({
    required this.chunk,
    required this.geometry,
    required Iterable<PolygonTerrainPlacementLineage> placementLineage,
    required Iterable<PolygonTerrainTriangle> triangles,
  }) : placementLineage = List<PolygonTerrainPlacementLineage>.unmodifiable(
         placementLineage,
       ),
       triangles = List<PolygonTerrainTriangle>.unmodifiable(triangles);

  final PolygonTerrainChunkSource chunk;
  final TerrainGeometry geometry;
  final List<PolygonTerrainPlacementLineage> placementLineage;
  final List<PolygonTerrainTriangle> triangles;

  List<String> placementRecords() => List<String>.unmodifiable(
    placementLineage.map((lineage) => lineage.canonicalRecord()),
  );

  List<String> triangleRecords() => List<String>.unmodifiable(
    triangles.map((triangle) => triangle.canonicalRecord()),
  );

  String placementSignature() => _signature(placementRecords());

  String triangleSignature() => _signature(triangleRecords());
}

/// Deterministic compile result; issues never coexist with fabricated output.
final class PolygonTerrainCompilationResult {
  PolygonTerrainCompilationResult({
    required this.compiled,
    required Iterable<PolygonTerrainGenerationIssue> issues,
  }) : issues = List<PolygonTerrainGenerationIssue>.unmodifiable(
         List<PolygonTerrainGenerationIssue>.of(issues)..sort(),
       );

  final PolygonTerrainCompiledChunk? compiled;
  final List<PolygonTerrainGenerationIssue> issues;
}

/// Expands current-schema collision and delegates all geometry to Core.
PolygonTerrainCompilationResult compilePolygonTerrainChunk({
  required PolygonTerrainChunkSource chunk,
  required PolygonTerrainPrefabSourceSet prefabSources,
  required String sourcePath,
}) {
  final issues = <PolygonTerrainGenerationIssue>[];
  final inputs = <TerrainPolygonInput>[];
  final placementByPath = <String, String>{};
  final placementLineage = <PolygonTerrainPlacementLineage>[];
  final prefabRefs = _indexPrefabReferences(prefabSources.prefabs);

  for (final shape in chunk.collisionShapes) {
    final shapePath = '$sourcePath#direct=${shape.shapeId}';
    try {
      inputs.add(
        _polygonInput(
          chunkKey: chunk.chunkKey,
          shape: shape,
          sourcePath: shapePath,
        ),
      );
    } on ArgumentError catch (error) {
      issues.add(
        PolygonTerrainGenerationIssue(
          code: 'chunk_collision_source_value_invalid',
          message: error.toString(),
          sourcePath: shapePath,
          shapeId: shape.shapeId,
        ),
      );
    }
  }

  for (final selection in chunk.placementSelections()) {
    final placement = selection.placement;
    final placementKey = selection.placementKey;
    final placementPath = '$sourcePath#placement=$placementKey';
    final candidates = prefabRefs[placement.resolvedPrefabRef];
    if (candidates == null || candidates.isEmpty) {
      issues.add(
        PolygonTerrainGenerationIssue(
          code: 'unknown_prefab_reference',
          message:
              'Chunk ${chunk.chunkKey} placement $placementKey references '
              'unknown prefab ${placement.resolvedPrefabRef}.',
          sourcePath: placementPath,
          placementKey: placementKey,
        ),
      );
      continue;
    }
    if (candidates.length != 1) {
      issues.add(
        PolygonTerrainGenerationIssue(
          code: 'ambiguous_prefab_reference',
          message:
              'Chunk ${chunk.chunkKey} placement $placementKey resolves '
              '${placement.resolvedPrefabRef} to more than one prefab.',
          sourcePath: placementPath,
          placementKey: placementKey,
        ),
      );
      continue;
    }
    final prefab = candidates.single;
    final transform = TerrainSourceTransform(
      reflectX: placement.flipX,
      reflectY: placement.flipY,
      scaleNumerator: placement.scaleTenths,
      scaleDenominator: 10,
      translateXSourceTicks: placement.x * 2,
      translateYSourceTicks: placement.y * 2,
    );
    for (final shape in prefab.collisionShapes) {
      final shapePath =
          '$placementPath#prefab=${prefab.prefabKey}#shape=${shape.shapeId}';
      placementByPath[shapePath] = placementKey;
      try {
        inputs.add(
          _polygonInput(
            chunkKey: chunk.chunkKey,
            placementKey: placementKey,
            shape: shape,
            sourcePath: shapePath,
            transform: transform,
          ),
        );
        placementLineage.add(
          PolygonTerrainPlacementLineage(
            chunkKey: chunk.chunkKey,
            placementKey: placementKey,
            prefabKey: prefab.prefabKey,
            prefabId: prefab.id,
            prefabRevision: prefab.revision,
            shapeId: shape.shapeId,
            placementX: placement.x,
            placementY: placement.y,
            scaleTenths: placement.scaleTenths,
            flipX: placement.flipX,
            flipY: placement.flipY,
          ),
        );
      } on ArgumentError catch (error) {
        issues.add(
          PolygonTerrainGenerationIssue(
            code: 'prefab_collision_source_value_invalid',
            message: error.toString(),
            sourcePath: shapePath,
            placementKey: placementKey,
            shapeId: shape.shapeId,
          ),
        );
      }
    }
  }

  TerrainGeometry? geometry;
  var coreSourcesAccepted = true;
  for (final input in inputs) {
    final review = const TerrainSourceCanonicalizer().review(
      input,
      requireCanonical: true,
    );
    for (final diagnostic in review.diagnostics) {
      issues.add(
        PolygonTerrainGenerationIssue(
          code: diagnostic.code,
          message: diagnostic.message,
          sourcePath: diagnostic.sourcePath,
          placementKey: placementByPath[diagnostic.sourcePath],
          shapeId: diagnostic.shapeId,
          elementIndex: diagnostic.elementIndex,
        ),
      );
      if (terrainDiagnosticIsBlocking(diagnostic)) {
        coreSourcesAccepted = false;
      }
    }
  }
  if (coreSourcesAccepted) {
    try {
      geometry = const TerrainCompiler().compile(inputs, geometryVersion: 1);
    } on TerrainValidationException catch (error) {
      issues.addAll(
        error.diagnostics.map(
          (diagnostic) => PolygonTerrainGenerationIssue(
            code: diagnostic.code,
            message: diagnostic.message,
            sourcePath: diagnostic.sourcePath,
            placementKey: placementByPath[diagnostic.sourcePath],
            shapeId: diagnostic.shapeId,
            elementIndex: diagnostic.elementIndex,
          ),
        ),
      );
    } on ArgumentError catch (error) {
      issues.add(
        PolygonTerrainGenerationIssue(
          code: 'terrain_transform_invalid',
          message: error.toString(),
          sourcePath: sourcePath,
        ),
      );
    }
  }

  if (geometry != null) {
    final maxX = chunk.width * terrainPhysicsTicksPerWorldUnit;
    final maxY = chunk.height * terrainPhysicsTicksPerWorldUnit;
    for (final polygon in geometry.polygons) {
      for (final vertex in polygon.vertices.asMap().entries) {
        final point = vertex.value;
        if (point.xTicks >= 0 &&
            point.xTicks <= maxX &&
            point.yTicks >= 0 &&
            point.yTicks <= maxY) {
          continue;
        }
        issues.add(
          PolygonTerrainGenerationIssue(
            code: polygon.identity.placementKey == null
                ? 'chunk_collision_shape_out_of_bounds'
                : 'expanded_prefab_vertex_out_of_bounds',
            message:
                'Transformed vertex is outside closed chunk bounds '
                '0..${chunk.width} x 0..${chunk.height} px.',
            sourcePath: polygon.sourcePath,
            placementKey: polygon.identity.placementKey,
            shapeId: polygon.identity.shapeId,
            elementIndex: vertex.key,
          ),
        );
      }
    }
  }

  if (geometry == null || issues.isNotEmpty) {
    return PolygonTerrainCompilationResult(compiled: null, issues: issues);
  }

  placementLineage.sort((left, right) {
    var order = left.placementKey.compareTo(right.placementKey);
    return order != 0 ? order : left.shapeId.compareTo(right.shapeId);
  });
  final triangles = <PolygonTerrainTriangle>[];
  for (final polygon in geometry.polygons) {
    triangles.addAll(_triangulate(polygon));
  }
  triangles.sort((left, right) {
    var order = left.chunkKey.compareTo(right.chunkKey);
    if (order != 0) return order;
    order = (left.placementKey ?? '').compareTo(right.placementKey ?? '');
    if (order != 0) return order;
    order = left.shapeId.compareTo(right.shapeId);
    if (order != 0) return order;
    order = left.first.compareTo(right.first);
    if (order != 0) return order;
    order = left.second.compareTo(right.second);
    return order != 0 ? order : left.third.compareTo(right.third);
  });
  return PolygonTerrainCompilationResult(
    compiled: PolygonTerrainCompiledChunk(
      chunk: chunk,
      geometry: geometry,
      placementLineage: placementLineage,
      triangles: triangles,
    ),
    issues: const <PolygonTerrainGenerationIssue>[],
  );
}

TerrainPolygonInput _polygonInput({
  required String chunkKey,
  required PolygonTerrainShapeSource shape,
  required String sourcePath,
  String? placementKey,
  TerrainSourceTransform transform = const TerrainSourceTransform(),
}) => TerrainPolygonInput(
  sourcePath: sourcePath,
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: chunkKey,
    placementKey: placementKey,
    shapeId: shape.shapeId,
  ),
  vertices: shape.vertices.map(
    (vertex) => SourceTerrainPoint(vertex.xHalfPixels, vertex.yHalfPixels),
  ),
  collisionMode: shape.collisionMode,
  surfaceKind: shape.surfaceKind,
  materialKey: shape.materialKey,
  transform: transform,
);

Map<String, List<PolygonTerrainPrefabSource>> _indexPrefabReferences(
  List<PolygonTerrainPrefabSource> prefabs,
) {
  final result = <String, List<PolygonTerrainPrefabSource>>{};
  for (final prefab in prefabs) {
    for (final reference in <String>{prefab.prefabKey, prefab.id}) {
      result.putIfAbsent(reference, () => []).add(prefab);
    }
  }
  return result;
}

List<PolygonTerrainTriangle> _triangulate(TerrainPolygon polygon) {
  final vertices = polygon.vertices;
  if (vertices.length < 3) {
    throw StateError('Core returned a polygon with fewer than three vertices.');
  }
  final remaining = <int>[
    for (var index = 0; index < vertices.length; index += 1) index,
  ];
  final triangles = <PolygonTerrainTriangle>[];
  while (remaining.length > 3) {
    var earPosition = -1;
    for (var position = 0; position < remaining.length; position += 1) {
      final previous = remaining[(position - 1) % remaining.length];
      final current = remaining[position];
      final next = remaining[(position + 1) % remaining.length];
      if (_cross(vertices[previous], vertices[current], vertices[next]) <=
          BigInt.zero) {
        continue;
      }
      var containsVertex = false;
      for (final candidate in remaining) {
        if (candidate == previous ||
            candidate == current ||
            candidate == next) {
          continue;
        }
        if (_insideTriangle(
          vertices[candidate],
          vertices[previous],
          vertices[current],
          vertices[next],
        )) {
          containsVertex = true;
          break;
        }
      }
      if (!containsVertex) {
        earPosition = position;
        break;
      }
    }
    if (earPosition < 0) {
      throw StateError(
        'Could not triangulate ${polygon.sourcePath}:${polygon.identity.shapeId}.',
      );
    }
    final previous = remaining[(earPosition - 1) % remaining.length];
    final current = remaining[earPosition];
    final next = remaining[(earPosition + 1) % remaining.length];
    triangles.add(_triangle(polygon, previous, current, next));
    remaining.removeAt(earPosition);
  }
  triangles.add(_triangle(polygon, remaining[0], remaining[1], remaining[2]));

  final expectedArea = _polygonArea(vertices);
  final triangleArea = triangles.fold<BigInt>(BigInt.zero, (sum, triangle) {
    return sum +
        _cross(
          vertices[triangle.first],
          vertices[triangle.second],
          vertices[triangle.third],
        );
  });
  if (triangles.length != vertices.length - 2 ||
      expectedArea <= BigInt.zero ||
      triangleArea != expectedArea) {
    throw StateError(
      'Triangulation area/count mismatch for '
      '${polygon.sourcePath}:${polygon.identity.shapeId}.',
    );
  }
  return triangles;
}

PolygonTerrainTriangle _triangle(
  TerrainPolygon polygon,
  int first,
  int second,
  int third,
) => PolygonTerrainTriangle(
  chunkKey: polygon.identity.chunkKey,
  placementKey: polygon.identity.placementKey,
  shapeId: polygon.identity.shapeId,
  first: first,
  second: second,
  third: third,
);

bool _insideTriangle(
  TerrainPoint point,
  TerrainPoint first,
  TerrainPoint second,
  TerrainPoint third,
) =>
    _cross(first, second, point) >= BigInt.zero &&
    _cross(second, third, point) >= BigInt.zero &&
    _cross(third, first, point) >= BigInt.zero;

BigInt _polygonArea(List<TerrainPoint> vertices) {
  var area = BigInt.zero;
  for (var index = 0; index < vertices.length; index += 1) {
    final current = vertices[index];
    final next = vertices[(index + 1) % vertices.length];
    area +=
        BigInt.from(current.xTicks) * BigInt.from(next.yTicks) -
        BigInt.from(next.xTicks) * BigInt.from(current.yTicks);
  }
  return area;
}

BigInt _cross(TerrainPoint first, TerrainPoint second, TerrainPoint third) =>
    BigInt.from(second.xTicks - first.xTicks) *
        BigInt.from(third.yTicks - first.yTicks) -
    BigInt.from(second.yTicks - first.yTicks) *
        BigInt.from(third.xTicks - first.xTicks);

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');

String _signature(Iterable<String> records) =>
    sha256.convert(utf8.encode(records.join('\n'))).toString();
