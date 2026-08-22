import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_polygon_signature.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_triangle_signature.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_source_canonicalizer.dart';
import 'package:runner_core/collision/terrain/terrain_triangulator.dart';

import 'polygon_terrain_source.dart';

/// Generator-facing name for Core's portable terrain-authoring issue envelope.
typedef PolygonTerrainGenerationIssue = TerrainAuthoringIssue;

/// Stable prefab placement lineage retained beside compiled local geometry.
final class PolygonTerrainPlacementLineage
    implements Comparable<PolygonTerrainPlacementLineage> {
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

  @override
  int compareTo(PolygonTerrainPlacementLineage other) {
    var order = chunkKey.compareTo(other.chunkKey);
    if (order != 0) return order;
    order = placementKey.compareTo(other.placementKey);
    return order != 0 ? order : shapeId.compareTo(other.shapeId);
  }

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

/// Generator-facing name for Core's shared render-triangle record contract.
typedef PolygonTerrainTriangle = TerrainAuthoringTriangleRecord;

/// Accepted local staged terrain for one chunk-v2 source file.
final class PolygonTerrainCompiledChunk {
  PolygonTerrainCompiledChunk({
    required this.chunk,
    required this.geometry,
    required this.renderGeometry,
    required this.renderEdgeGeometry,
    required Map<TerrainSourceIdentity, TerrainAuthoringPolygonMode>
    modeBySourceIdentity,
    required Iterable<TerrainAuthoringPolygonRecord> authoringPolygons,
    required Iterable<PolygonTerrainPlacementLineage> placementLineage,
    required Iterable<PolygonTerrainTriangle> triangles,
  }) : modeBySourceIdentity = Map.unmodifiable(modeBySourceIdentity),
       authoringPolygons = List<TerrainAuthoringPolygonRecord>.unmodifiable(
         List<TerrainAuthoringPolygonRecord>.of(authoringPolygons)..sort(),
       ),
       placementLineage = List<PolygonTerrainPlacementLineage>.unmodifiable(
         List<PolygonTerrainPlacementLineage>.of(placementLineage)..sort(),
       ),
       triangles = List<PolygonTerrainTriangle>.unmodifiable(
         List<PolygonTerrainTriangle>.of(triangles)..sort(),
       ) {
    _rejectDuplicateComparable(
      this.placementLineage,
      'placement lineage identity',
    );
    _rejectDuplicateComparable(this.triangles, 'triangle identity');
  }

  final PolygonTerrainChunkSource chunk;

  /// Gameplay collision geometry. Render-only polygons are absent.
  final TerrainGeometry geometry;

  /// Canonical direct Chunk geometry used for terrain fills.
  ///
  /// Includes every direct authored terrain role and excludes placed Prefab
  /// collision, whose visual is supplied by the Prefab sprite layer.
  final TerrainGeometry renderGeometry;

  /// Direct Chunk collision geometry used only for terrain edge decoration.
  ///
  /// Placed Prefab colliders remain in [geometry], but cannot split or cancel
  /// the Chunk-authored boundaries that establish the terrain's visual skin.
  final TerrainGeometry renderEdgeGeometry;
  final Map<TerrainSourceIdentity, TerrainAuthoringPolygonMode>
  modeBySourceIdentity;
  final List<TerrainAuthoringPolygonRecord> authoringPolygons;
  final List<PolygonTerrainPlacementLineage> placementLineage;
  final List<PolygonTerrainTriangle> triangles;

  List<String> authoringPolygonRecords() =>
      canonicalTerrainAuthoringPolygonRecords(authoringPolygons);

  List<String> placementRecords() => List<String>.unmodifiable(
    placementLineage.map((lineage) => lineage.canonicalRecord()),
  );

  List<String> triangleRecords() =>
      canonicalTerrainAuthoringTriangleRecords(triangles);

  String placementSignature() => _signature(placementRecords());

  String triangleSignature() => terrainAuthoringTriangleSignature(triangles);

  String authoringPolygonSignature() =>
      terrainAuthoringPolygonSignature(authoringPolygons);
}

/// Deterministic compile result; issues never coexist with fabricated output.
final class PolygonTerrainCompilationResult {
  PolygonTerrainCompilationResult({
    required this.compiled,
    required Iterable<PolygonTerrainGenerationIssue> issues,
  }) : issues = canonicalTerrainAuthoringIssues(issues);

  final PolygonTerrainCompiledChunk? compiled;
  final List<PolygonTerrainGenerationIssue> issues;
}

/// Strictly parses and compiles one current-schema terrain source pair.
///
/// File-level parse failures cannot reliably expose an authored owner key, so
/// their canonical workspace-relative file identity becomes the owner key.
/// Successfully parsed geometry delegates to [compilePolygonTerrainChunk].
PolygonTerrainCompilationResult compilePolygonTerrainSourceText({
  required String prefabSource,
  required String prefabSourcePath,
  required String chunkSource,
  required String chunkSourcePath,
}) {
  prefabSourcePath = canonicalPolygonTerrainSourcePath(prefabSourcePath);
  chunkSourcePath = canonicalPolygonTerrainSourcePath(chunkSourcePath);
  final issues = <PolygonTerrainGenerationIssue>[];
  PolygonTerrainPrefabSourceSet? prefabs;
  PolygonTerrainChunkSource? chunk;
  try {
    prefabs = decodePolygonTerrainPrefabs(
      prefabSource,
      sourcePath: prefabSourcePath,
    );
  } on FormatException catch (error) {
    issues.add(
      _errorIssue(
        code: 'prefab_source_invalid',
        message: error.message.toString(),
        sourcePath: prefabSourcePath,
        ownerKey: prefabSourcePath,
      ),
    );
  }
  try {
    chunk = decodePolygonTerrainChunk(chunkSource, sourcePath: chunkSourcePath);
  } on FormatException catch (error) {
    issues.add(
      _errorIssue(
        code: 'chunk_source_invalid',
        message: error.message.toString(),
        sourcePath: chunkSourcePath,
        ownerKey: chunkSourcePath,
      ),
    );
  }
  if (prefabs == null || chunk == null) {
    return PolygonTerrainCompilationResult(compiled: null, issues: issues);
  }
  return compilePolygonTerrainChunk(
    chunk: chunk,
    prefabSources: prefabs,
    sourcePath: chunkSourcePath,
  );
}

/// Expands terrain source, then partitions render-only polygons from physics.
PolygonTerrainCompilationResult compilePolygonTerrainChunk({
  required PolygonTerrainChunkSource chunk,
  required PolygonTerrainPrefabSourceSet prefabSources,
  required String sourcePath,
}) {
  sourcePath = canonicalPolygonTerrainSourcePath(sourcePath);
  final issues = <PolygonTerrainGenerationIssue>[];
  final reviewInputs = <TerrainPolygonInput>[];
  final renderInputs = <TerrainPolygonInput>[];
  final renderEdgeInputs = <TerrainPolygonInput>[];
  final collisionInputs = <TerrainPolygonInput>[];
  final modeBySourceIdentity =
      <TerrainSourceIdentity, TerrainAuthoringPolygonMode>{};
  final placementByPath = <String, String>{};
  final ownerByPath = <String, String>{};
  final placementLineage = <PolygonTerrainPlacementLineage>[];
  final prefabRefs = _indexPrefabReferences(prefabSources.prefabs);
  final referencedPrefabs = <String, PolygonTerrainPrefabSource>{};

  for (final shape in chunk.collisionShapes) {
    final shapePath = '$sourcePath#direct=${shape.shapeId}';
    ownerByPath[shapePath] = chunk.chunkKey;
    try {
      final input = _polygonInput(
        chunkKey: chunk.chunkKey,
        shape: shape,
        sourcePath: shapePath,
      );
      reviewInputs.add(input);
      renderInputs.add(input);
      modeBySourceIdentity[input.identity] = shape.collisionMode;
      if (shape.collisionMode != TerrainAuthoringPolygonMode.none) {
        renderEdgeInputs.add(input);
        collisionInputs.add(input);
      }
    } on ArgumentError catch (error) {
      issues.add(
        _errorIssue(
          code: 'chunk_collision_source_value_invalid',
          message: error.toString(),
          sourcePath: shapePath,
          ownerKey: chunk.chunkKey,
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
        _errorIssue(
          code: 'unknown_prefab_reference',
          message:
              'Chunk ${chunk.chunkKey} placement $placementKey references '
              'unknown prefab ${placement.resolvedPrefabRef}.',
          sourcePath: placementPath,
          ownerKey: chunk.chunkKey,
          placementKey: placementKey,
        ),
      );
      continue;
    }
    if (candidates.length != 1) {
      issues.add(
        _errorIssue(
          code: 'ambiguous_prefab_reference',
          message:
              'Chunk ${chunk.chunkKey} placement $placementKey resolves '
              '${placement.resolvedPrefabRef} to more than one prefab.',
          sourcePath: placementPath,
          ownerKey: chunk.chunkKey,
          placementKey: placementKey,
        ),
      );
      continue;
    }
    final prefab = candidates.single;
    referencedPrefabs[prefab.prefabKey] = prefab;
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
      ownerByPath[shapePath] = prefab.prefabKey;
      if (shape.collisionMode == TerrainAuthoringPolygonMode.none) {
        issues.add(
          _errorIssue(
            code: 'prefab_render_only_shape_forbidden',
            message:
                'Prefab ${prefab.prefabKey} shape ${shape.shapeId} uses none; '
                'render-only terrain is owned directly by chunks.',
            sourcePath: shapePath,
            ownerKey: prefab.prefabKey,
            placementKey: placementKey,
            shapeId: shape.shapeId,
          ),
        );
        continue;
      }
      try {
        final input = _polygonInput(
          chunkKey: chunk.chunkKey,
          placementKey: placementKey,
          shape: shape,
          sourcePath: shapePath,
          transform: transform,
        );
        reviewInputs.add(input);
        collisionInputs.add(input);
        modeBySourceIdentity[input.identity] = shape.collisionMode;
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
          _errorIssue(
            code: 'prefab_collision_source_value_invalid',
            message: error.toString(),
            sourcePath: shapePath,
            ownerKey: prefab.prefabKey,
            placementKey: placementKey,
            shapeId: shape.shapeId,
          ),
        );
      }
    }
  }

  TerrainGeometry? renderGeometry;
  TerrainGeometry? renderEdgeGeometry;
  TerrainGeometry? geometry;
  var coreSourcesAccepted = true;
  for (final input in reviewInputs) {
    final review = const TerrainSourceCanonicalizer().review(
      input,
      requireCanonical: true,
    );
    for (final diagnostic in review.diagnostics) {
      issues.add(
        TerrainAuthoringIssue.fromCore(
          diagnostic: diagnostic,
          ownerKey: ownerByPath[diagnostic.sourcePath] ?? chunk.chunkKey,
          placementKey: placementByPath[diagnostic.sourcePath],
        ),
      );
      if (terrainDiagnosticIsBlocking(diagnostic)) {
        coreSourcesAccepted = false;
      }
    }
  }
  if (coreSourcesAccepted) {
    try {
      renderGeometry = const TerrainCompiler().compile(
        renderInputs,
        geometryVersion: 1,
      );
      renderEdgeGeometry = const TerrainCompiler().compile(
        renderEdgeInputs,
        geometryVersion: 1,
      );
      geometry = const TerrainCompiler().compile(
        collisionInputs,
        geometryVersion: 1,
      );
    } on TerrainValidationException catch (error) {
      issues.addAll(
        error.diagnostics.map(
          (diagnostic) => TerrainAuthoringIssue.fromCore(
            diagnostic: diagnostic,
            ownerKey: ownerByPath[diagnostic.sourcePath] ?? chunk.chunkKey,
            placementKey: placementByPath[diagnostic.sourcePath],
          ),
        ),
      );
    } on ArgumentError catch (error) {
      issues.add(
        _errorIssue(
          code: 'terrain_transform_invalid',
          message: error.toString(),
          sourcePath: sourcePath,
          ownerKey: chunk.chunkKey,
        ),
      );
    }
  }

  if (geometry != null && renderGeometry != null) {
    final maxX = chunk.width * terrainPhysicsTicksPerWorldUnit;
    final maxY = chunk.height * terrainPhysicsTicksPerWorldUnit;
    final polygonsByIdentity = <TerrainSourceIdentity, TerrainPolygon>{
      for (final polygon in geometry.polygons) polygon.identity: polygon,
      for (final polygon in renderGeometry.polygons) polygon.identity: polygon,
    };
    final polygons = polygonsByIdentity.values.toList()
      ..sort((left, right) => left.identity.compareTo(right.identity));
    for (final polygon in polygons) {
      for (final vertex in polygon.vertices.asMap().entries) {
        final point = vertex.value;
        if (point.xTicks >= 0 &&
            point.xTicks <= maxX &&
            point.yTicks >= 0 &&
            point.yTicks <= maxY) {
          continue;
        }
        issues.add(
          _errorIssue(
            code: polygon.identity.placementKey == null
                ? 'chunk_collision_shape_out_of_bounds'
                : 'expanded_prefab_vertex_out_of_bounds',
            message:
                'Transformed vertex is outside closed chunk bounds '
                '0..${chunk.width} x 0..${chunk.height} px.',
            sourcePath: polygon.sourcePath,
            ownerKey: ownerByPath[polygon.sourcePath] ?? chunk.chunkKey,
            placementKey: polygon.identity.placementKey,
            shapeId: polygon.identity.shapeId,
            elementIndex: vertex.key,
          ),
        );
      }
    }
  }

  if (geometry == null ||
      renderGeometry == null ||
      renderEdgeGeometry == null ||
      issues.isNotEmpty) {
    return PolygonTerrainCompilationResult(compiled: null, issues: issues);
  }

  placementLineage.sort((left, right) {
    var order = left.placementKey.compareTo(right.placementKey);
    return order != 0 ? order : left.shapeId.compareTo(right.shapeId);
  });
  final triangles = <PolygonTerrainTriangle>[];
  for (final polygon in renderGeometry.polygons) {
    triangles.addAll(
      const TerrainTriangulator()
          .triangulate(polygon)
          .map(
            (triangle) => PolygonTerrainTriangle(
              chunkKey: polygon.identity.chunkKey,
              placementKey: polygon.identity.placementKey,
              shapeId: polygon.identity.shapeId,
              first: triangle.first,
              second: triangle.second,
              third: triangle.third,
            ),
          ),
    );
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
  final authoringPolygons = <TerrainAuthoringPolygonRecord>[
    for (final shape in chunk.collisionShapes)
      _authoringPolygonRecord(
        ownerKind: TerrainAuthoringPolygonOwnerKind.chunk,
        ownerKey: chunk.chunkKey,
        ownerId: chunk.id,
        ownerRevision: chunk.revision,
        shape: shape,
      ),
    for (final prefab in referencedPrefabs.values)
      for (final shape in prefab.collisionShapes)
        _authoringPolygonRecord(
          ownerKind: TerrainAuthoringPolygonOwnerKind.prefab,
          ownerKey: prefab.prefabKey,
          ownerId: prefab.id,
          ownerRevision: prefab.revision,
          shape: shape,
        ),
  ];
  return PolygonTerrainCompilationResult(
    compiled: PolygonTerrainCompiledChunk(
      chunk: chunk,
      geometry: geometry,
      renderGeometry: renderGeometry,
      renderEdgeGeometry: renderEdgeGeometry,
      modeBySourceIdentity: modeBySourceIdentity,
      authoringPolygons: authoringPolygons,
      placementLineage: placementLineage,
      triangles: triangles,
    ),
    issues: const <PolygonTerrainGenerationIssue>[],
  );
}

TerrainAuthoringPolygonRecord _authoringPolygonRecord({
  required TerrainAuthoringPolygonOwnerKind ownerKind,
  required String ownerKey,
  required String ownerId,
  required int ownerRevision,
  required PolygonTerrainShapeSource shape,
}) => TerrainAuthoringPolygonRecord(
  ownerKind: ownerKind,
  ownerKey: ownerKey,
  ownerId: ownerId,
  ownerRevision: ownerRevision,
  shapeId: shape.shapeId,
  vertices: shape.vertices.map(
    (vertex) => SourceTerrainPoint(vertex.xHalfPixels, vertex.yHalfPixels),
  ),
  mode: shape.collisionMode,
  surfaceKind: shape.surfaceKind,
  materialKey: shape.materialKey,
);

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
  collisionMode: switch (shape.collisionMode) {
    TerrainAuthoringPolygonMode.solid ||
    TerrainAuthoringPolygonMode.none => TerrainCollisionMode.solid,
    TerrainAuthoringPolygonMode.oneWay => TerrainCollisionMode.oneWay,
  },
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

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');

String _signature(Iterable<String> records) =>
    sha256.convert(utf8.encode(records.join('\n'))).toString();

PolygonTerrainGenerationIssue _errorIssue({
  required String code,
  required String message,
  required String sourcePath,
  required String ownerKey,
  String? placementKey,
  String? shapeId,
  int? elementIndex,
}) => TerrainAuthoringIssue(
  severity: TerrainAuthoringIssueSeverity.error,
  code: code,
  message: message,
  sourcePath: sourcePath,
  ownerKey: ownerKey,
  placementKey: placementKey,
  shapeId: shapeId,
  elementIndex: elementIndex,
);

void _rejectDuplicateComparable<T extends Comparable<T>>(
  List<T> records,
  String description,
) {
  for (var index = 1; index < records.length; index += 1) {
    if (records[index - 1].compareTo(records[index]) == 0) {
      throw ArgumentError('Duplicate staged $description at index $index.');
    }
  }
}
