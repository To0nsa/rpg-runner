import 'package:meta/meta.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_source_canonicalizer.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_cache.dart';

import '../domain/authoring_types.dart';
import '../prefabs/models/models.dart';
import '../terrain_authoring/terrain_source_core_adapter.dart';
import '../terrain_authoring/terrain_physics_text.dart';
import 'chunk_domain_models.dart';
import 'chunk_v2_file_data.dart';

/// One immutable, read-only placed-prefab polygon in chunk physics space.
///
/// The polygon vertices are Core's post-transform `1/1024 px` ticks. Source
/// prefab and placement lineage is retained so preview never needs to infer it
/// from display coordinates.
@immutable
final class ChunkV2ExpandedPrefabShape {
  ChunkV2ExpandedPrefabShape({
    required this.chunkKey,
    required this.placementKey,
    required this.prefabKey,
    required this.prefabId,
    required this.prefabRevision,
    required this.shapeId,
    required this.sourcePath,
    required this.placementX,
    required this.placementY,
    required this.scaleTenths,
    required this.flipX,
    required this.flipY,
    required Iterable<TerrainPoint> vertices,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
  }) : vertices = List<TerrainPoint>.unmodifiable(vertices);

  final String chunkKey;
  final String placementKey;
  final String prefabKey;
  final String prefabId;
  final int prefabRevision;
  final String shapeId;
  final String sourcePath;
  final int placementX;
  final int placementY;
  final int scaleTenths;
  final bool flipX;
  final bool flipY;
  final List<TerrainPoint> vertices;
  final TerrainCollisionMode collisionMode;
  final String? surfaceKind;
  final String? materialKey;
}

/// Accepted Core compilation for one staged chunk-v2 collision owner.
@immutable
final class ChunkV2CollisionExpansion {
  ChunkV2CollisionExpansion({
    required this.chunkKey,
    required this.geometry,
    required this.directShapeCount,
    required Iterable<ChunkV2ExpandedPrefabShape> expandedPrefabShapes,
  }) : expandedPrefabShapes = List<ChunkV2ExpandedPrefabShape>.unmodifiable(
         expandedPrefabShapes,
       ),
       traversalCache = TerrainTraversalCache.fromGeometry(geometry);

  final String chunkKey;
  final TerrainGeometry geometry;
  final int directShapeCount;
  final List<ChunkV2ExpandedPrefabShape> expandedPrefabShapes;
  final TerrainTraversalCache traversalCache;

  int get expandedPrefabShapeCount => expandedPrefabShapes.length;
  int get totalShapeCount => geometry.polygons.length;
  int get exposedEdgeCount => geometry.edges.length;
}

/// Deterministic expansion outcome; invalid source never fabricates geometry.
@immutable
final class ChunkV2CollisionExpansionResult {
  ChunkV2CollisionExpansionResult({
    required this.expansion,
    required Iterable<ValidationIssue> issues,
  }) : issues = List<ValidationIssue>.unmodifiable(
         List<ValidationIssue>.of(issues)..sort(_compareIssues),
       );

  final ChunkV2CollisionExpansion? expansion;
  final List<ValidationIssue> issues;

  bool get hasBlockingIssues =>
      issues.any((issue) => issue.severity == ValidationSeverity.error);
}

/// Expands direct and placed prefab collision through the one Core transform.
///
/// Prefab-v3 collision loops are already authored relative to the prefab
/// anchor. Their Core source anchor is therefore zero; the visual prefab anchor
/// must not be subtracted a second time. Placement translation remains the
/// authored anchor position in chunk-local whole pixels.
ChunkV2CollisionExpansionResult expandChunkV2Collision({
  required ChunkV2FileData chunk,
  required Iterable<PrefabV3Def> prefabs,
  required String sourcePath,
  int chunkIndex = 0,
}) {
  final issues = <ValidationIssue>[];
  final inputs = <TerrainPolygonInput>[];
  final placementBySourcePath = <String, String>{};
  final prefabByPlacementKey = <String, PrefabV3Def>{};
  final placementByKey = <String, PlacedPrefabDef>{};
  final prefabRefs = _indexPrefabReferences(prefabs);
  var sourceComplete = true;

  for (final shape in chunk.collisionShapes) {
    final shapePath = '$sourcePath#direct=${shape.shapeId}';
    try {
      inputs.add(
        TerrainSourceCoreAdapter.toPolygonInput(
          shape: shape,
          sourcePath: shapePath,
          chunkIndex: chunkIndex,
          chunkKey: chunk.chunkKey,
        ),
      );
    } on ArgumentError catch (error) {
      sourceComplete = false;
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_collision_source_value_invalid',
          message: 'Chunk ${chunk.chunkKey} shape ${shape.shapeId}: $error',
          sourcePath: shapePath,
          shapeId: shape.shapeId,
        ),
      );
    }
  }

  for (final selection in buildChunkPlacedPrefabSelections(chunk.prefabs)) {
    final placement = selection.prefab;
    final placementKey = selection.selectionKey;
    final placementPath = '$sourcePath#placement=$placementKey';
    final candidates = prefabRefs[placement.resolvedPrefabRef];
    if (candidates == null || candidates.isEmpty) {
      sourceComplete = false;
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
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
      sourceComplete = false;
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
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
    if (!placement.scale.isFinite ||
        !isPrefabPlacementScaleInRange(placement.scale) ||
        !isPrefabPlacementScaleStepAligned(placement.scale)) {
      sourceComplete = false;
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_prefab_placement_scale',
          message:
              'Chunk ${chunk.chunkKey} placement $placementKey scale must be '
              '0.3..3.0 in exact 0.1 steps.',
          sourcePath: placementPath,
          placementKey: placementKey,
        ),
      );
      continue;
    }

    final prefab = candidates.single;
    final scaleTenths = (canonicalPrefabPlacementScale(placement.scale) * 10)
        .round();
    final transform = TerrainSourceCoreAdapter.placementTransform(
      anchorXHalfPixels: 0,
      anchorYHalfPixels: 0,
      translationXHalfPixels: placement.x * 2,
      translationYHalfPixels: placement.y * 2,
      scaleTenths: scaleTenths,
      flipX: placement.flipX,
      flipY: placement.flipY,
    );
    prefabByPlacementKey[placementKey] = prefab;
    placementByKey[placementKey] = placement;
    for (final shape in prefab.collisionShapes) {
      final shapePath =
          '$placementPath#prefab=${prefab.prefabKey}#shape=${shape.shapeId}';
      placementBySourcePath[shapePath] = placementKey;
      try {
        inputs.add(
          TerrainSourceCoreAdapter.toPolygonInput(
            shape: shape,
            sourcePath: shapePath,
            chunkIndex: chunkIndex,
            chunkKey: chunk.chunkKey,
            placementKey: placementKey,
            transform: transform,
          ),
        );
      } on ArgumentError catch (error) {
        sourceComplete = false;
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'prefab_collision_source_value_invalid',
            message:
                'Prefab ${prefab.prefabKey} shape ${shape.shapeId}: $error',
            sourcePath: shapePath,
            placementKey: placementKey,
            shapeId: shape.shapeId,
          ),
        );
      }
    }
  }

  TerrainGeometry? geometry;
  try {
    geometry = const TerrainCompiler().compile(inputs, geometryVersion: 1);
  } on TerrainValidationException catch (error) {
    issues.addAll(
      error.diagnostics.map(
        (diagnostic) => _issueFromCore(
          diagnostic,
          placementKey: placementBySourcePath[diagnostic.sourcePath],
        ),
      ),
    );
  } on ArgumentError catch (error) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'chunk_collision_transform_invalid',
        message: 'Chunk ${chunk.chunkKey} collision transform failed: $error',
        sourcePath: sourcePath,
      ),
    );
  }

  final expandedShapes = <ChunkV2ExpandedPrefabShape>[];
  if (geometry != null) {
    final maxX = chunk.width * terrainPhysicsTicksPerWorldUnit;
    final maxY = chunk.height * terrainPhysicsTicksPerWorldUnit;
    for (final polygon in geometry.polygons) {
      final placementKey = polygon.identity.placementKey;
      for (final vertex in polygon.vertices.asMap().entries) {
        final point = vertex.value;
        if (point.xTicks >= 0 &&
            point.xTicks <= maxX &&
            point.yTicks >= 0 &&
            point.yTicks <= maxY) {
          continue;
        }
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: placementKey == null
                ? 'chunk_collision_shape_out_of_bounds'
                : 'expanded_prefab_vertex_out_of_bounds',
            message: placementKey == null
                ? 'Chunk ${chunk.chunkKey} shape '
                      '${polygon.identity.shapeId} has a transformed vertex '
                      'outside closed bounds 0..${chunk.width} x '
                      '0..${chunk.height} px.'
                : 'Chunk ${chunk.chunkKey} placement $placementKey shape '
                      '${polygon.identity.shapeId} vertex ${vertex.key} is at '
                      '(${TerrainPhysicsText.formatTicks(point.xTicks)}, '
                      '${TerrainPhysicsText.formatTicks(point.yTicks)}) px, '
                      'outside closed '
                      'bounds 0..${chunk.width} x 0..${chunk.height} px.',
            sourcePath: polygon.sourcePath,
            placementKey: placementKey,
            shapeId: polygon.identity.shapeId,
            elementIndex: vertex.key,
          ),
        );
      }
      if (placementKey == null) continue;
      final prefab = prefabByPlacementKey[placementKey];
      final placement = placementByKey[placementKey];
      if (prefab == null || placement == null) continue;
      expandedShapes.add(
        ChunkV2ExpandedPrefabShape(
          chunkKey: chunk.chunkKey,
          placementKey: placementKey,
          prefabKey: prefab.prefabKey,
          prefabId: prefab.id,
          prefabRevision: prefab.revision,
          shapeId: polygon.identity.shapeId,
          sourcePath: polygon.sourcePath,
          placementX: placement.x,
          placementY: placement.y,
          scaleTenths: (canonicalPrefabPlacementScale(placement.scale) * 10)
              .round(),
          flipX: placement.flipX,
          flipY: placement.flipY,
          vertices: polygon.vertices,
          collisionMode: polygon.collisionMode,
          surfaceKind: polygon.surfaceKind,
          materialKey: polygon.materialKey,
        ),
      );
    }
    issues.addAll(
      geometry.diagnostics.map(
        (diagnostic) => _issueFromCore(
          diagnostic,
          placementKey: placementBySourcePath[diagnostic.sourcePath],
        ),
      ),
    );
  }

  return ChunkV2CollisionExpansionResult(
    expansion: geometry == null || !sourceComplete
        ? null
        : ChunkV2CollisionExpansion(
            chunkKey: chunk.chunkKey,
            geometry: geometry,
            directShapeCount: chunk.collisionShapes.length,
            expandedPrefabShapes: expandedShapes,
          ),
    issues: issues,
  );
}

Map<String, List<PrefabV3Def>> _indexPrefabReferences(
  Iterable<PrefabV3Def> prefabs,
) {
  final ordered = List<PrefabV3Def>.of(prefabs)
    ..sort((left, right) => left.prefabKey.compareTo(right.prefabKey));
  final result = <String, List<PrefabV3Def>>{};
  for (final prefab in ordered) {
    for (final reference in <String>{prefab.prefabKey, prefab.id}) {
      result.putIfAbsent(reference, () => <PrefabV3Def>[]).add(prefab);
    }
  }
  return result;
}

ValidationIssue _issueFromCore(
  TerrainDiagnostic diagnostic, {
  String? placementKey,
}) => ValidationIssue(
  severity: terrainDiagnosticIsBlocking(diagnostic)
      ? ValidationSeverity.error
      : ValidationSeverity.warning,
  code: diagnostic.code,
  message: diagnostic.message,
  sourcePath: diagnostic.sourcePath,
  placementKey: placementKey,
  shapeId: diagnostic.shapeId,
  elementIndex: diagnostic.elementIndex,
);

int _compareIssues(ValidationIssue left, ValidationIssue right) {
  var order = (left.sourcePath ?? '').compareTo(right.sourcePath ?? '');
  if (order != 0) return order;
  order = (left.placementKey ?? '').compareTo(right.placementKey ?? '');
  if (order != 0) return order;
  order = (left.shapeId ?? '').compareTo(right.shapeId ?? '');
  if (order != 0) return order;
  order = (left.elementIndex ?? -1).compareTo(right.elementIndex ?? -1);
  if (order != 0) return order;
  return left.code.compareTo(right.code);
}
