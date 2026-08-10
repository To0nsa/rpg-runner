import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_source_canonicalizer.dart';

import '../domain/authoring_types.dart';
import '../terrain_authoring/terrain_authoring_capacity_issues.dart';
import '../terrain_authoring/terrain_source_core_adapter.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'chunk_domain_models.dart';
import 'chunk_v2_collision_expansion.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_marker_contract.dart';
import 'chunk_v2_seam_analysis.dart';
import 'chunk_v2_models.dart';

/// Validates one chunk's direct polygon owner with Core geometry authority.
///
/// Closed owner bounds remain a chunk authoring rule; canonical loops,
/// topology, overlap, identities, and hard limits remain Core-owned.
List<ValidationIssue> validateChunkV2CollisionShapes({
  required ChunkV2FileData chunk,
  required Iterable<TerrainSourceShapeDef> collisionShapes,
  required String sourcePath,
  int chunkIndex = 0,
}) {
  final shapes = List<TerrainSourceShapeDef>.unmodifiable(collisionShapes);
  final issues = <ValidationIssue>[];
  var coreGeometryAccepted = true;
  for (final shape in shapes) {
    final shapePath = '$sourcePath:${shape.shapeId}';
    final capacityIssue = polygonVertexSoftTargetIssue(
      ownerLabel: 'Chunk ${chunk.chunkKey}',
      shapeId: shape.shapeId,
      vertexCount: shape.vertices.length,
      sourcePath: shapePath,
      ownerKey: chunk.chunkKey,
    );
    if (capacityIssue != null) {
      issues.add(_validationIssueFromTerrain(capacityIssue));
    }
    final outside = shape.vertices.where(
      (vertex) =>
          vertex.xHalfPixels < 0 ||
          vertex.xHalfPixels > chunk.width * 2 ||
          vertex.yHalfPixels < 0 ||
          vertex.yHalfPixels > chunk.height * 2,
    );
    if (outside.isNotEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_collision_shape_out_of_bounds',
          message:
              'Chunk ${chunk.chunkKey} shape ${shape.shapeId} has '
              '${outside.length} vertex/vertices outside closed bounds '
              '0..${chunk.width} x 0..${chunk.height} px.',
          sourcePath: sourcePath,
          ownerKey: chunk.chunkKey,
          shapeId: shape.shapeId,
        ),
      );
    }
    final review = TerrainSourceCoreAdapter.review(
      shape: shape,
      sourcePath: shapePath,
      chunkIndex: chunkIndex,
      chunkKey: chunk.chunkKey,
      requireCanonical: true,
    );
    for (final diagnostic in review.diagnostics) {
      issues.add(_issueFromCore(diagnostic, ownerKey: chunk.chunkKey));
      if (terrainDiagnosticIsBlocking(diagnostic)) {
        coreGeometryAccepted = false;
      }
    }
  }
  if (coreGeometryAccepted) {
    try {
      const TerrainCompiler().compile(
        shapes.map(
          (shape) => TerrainSourceCoreAdapter.toPolygonInput(
            shape: shape,
            sourcePath: '$sourcePath:${shape.shapeId}',
            chunkIndex: chunkIndex,
            chunkKey: chunk.chunkKey,
          ),
        ),
        geometryVersion: 1,
      );
    } on TerrainValidationException catch (error) {
      issues.addAll(
        error.diagnostics.map(
          (diagnostic) => _issueFromCore(diagnostic, ownerKey: chunk.chunkKey),
        ),
      );
    }
  }
  _sortValidationIssues(issues);
  return List<ValidationIssue>.unmodifiable(issues);
}

/// Validates the strict chunk-v2 set including exact prefab expansion.
List<ValidationIssue> validateChunkV2Document(ChunkV2Document document) {
  final issues = <ValidationIssue>[];
  final chunks = List.of(document.chunks)
    ..sort((left, right) => left.chunkKey.compareTo(right.chunkKey));
  final chunkKeys = <String>{};
  final foldedChunkKeys = <String>{};
  final chunkIds = <String>{};
  final currentChunkKeys = document.chunks
      .map((chunk) => chunk.chunkKey)
      .toSet();
  final createdChunkKeys = document.createdChunkKeys.toSet();
  final collisionExpansions = <String, ChunkV2CollisionExpansionResult>{};

  for (final createdChunkKey in createdChunkKeys) {
    if (!currentChunkKeys.contains(createdChunkKey)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_v2_created_owner_missing',
          message:
              'Created chunk owner $createdChunkKey is missing from the '
              'current document.',
        ),
      );
    }
  }

  if (document.availableLevelIds.isEmpty || document.activeLevelId == null) {
    issues.add(
      const ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'chunk_v2_active_level_missing',
        message: 'Chunk-v2 requires at least one active level.',
      ),
    );
  } else if (!document.availableLevelIds.contains(document.activeLevelId)) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'chunk_v2_active_level_unknown',
        message: 'Unknown active level ${document.activeLevelId}.',
      ),
    );
  }

  for (var chunkIndex = 0; chunkIndex < chunks.length; chunkIndex += 1) {
    final chunk = chunks[chunkIndex];
    final sourcePath = document.sourcePathByChunkKey[chunk.chunkKey];
    final baseline = document.baselineContentsByChunkKey[chunk.chunkKey];
    final isCreated = createdChunkKeys.contains(chunk.chunkKey);
    if (sourcePath == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_v2_source_path_missing',
          message:
              'Chunk ${chunk.chunkKey} is missing its current source path.',
        ),
      );
    } else if (!isCreated && baseline == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_v2_source_baseline_missing',
          message:
              'Chunk ${chunk.chunkKey} is missing its current source baseline.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (isCreated && baseline != null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_v2_created_owner_has_baseline',
          message:
              'Created chunk ${chunk.chunkKey} must not claim existing source '
              'baseline bytes.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (!ChunkKey(chunk.chunkKey).isValid) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'malformed_chunk_key',
          message: 'Chunk key ${chunk.chunkKey} is not stable.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (!chunkKeys.add(chunk.chunkKey)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_chunk_key',
          message: 'Duplicate chunk key ${chunk.chunkKey}.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (!foldedChunkKeys.add(chunk.chunkKey.toLowerCase())) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'case_colliding_chunk_key',
          message: 'Case-insensitive chunk key collision: ${chunk.chunkKey}.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (!chunkIds.add(chunk.id)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_chunk_id',
          message: 'Duplicate chunk id ${chunk.id}.',
          sourcePath: sourcePath,
        ),
      );
    }

    final hasGroundContext = isChunkV2MarkerGroundContextValid(
      document.groundTopYByLevelId[chunk.levelId],
    );
    if (chunk.markers.isNotEmpty && !hasGroundContext) {
      final marker = chunk.markers.first;
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'marker_level_ground_context_missing',
          message: chunkV2MarkerContractMessage(
            chunk: chunk,
            marker: marker,
            code: 'marker_level_ground_context_missing',
          ),
          sourcePath: sourcePath,
        ),
      );
    }
    for (final marker in chunk.markers) {
      for (final code in chunkV2MarkerContractCodes(
        chunk: chunk,
        marker: marker,
        hasGroundContext: hasGroundContext,
        includeGroundContext: false,
      )) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: code,
            message: chunkV2MarkerContractMessage(
              chunk: chunk,
              marker: marker,
              code: code,
            ),
            sourcePath: sourcePath,
          ),
        );
      }
    }

    final expansion = expandChunkV2Collision(
      chunk: chunk,
      prefabs: document.prefabData.prefabs,
      sourcePath: sourcePath ?? chunk.chunkKey,
      chunkIndex: chunkIndex,
    );
    collisionExpansions[chunk.chunkKey] = expansion;
    issues.addAll(expansion.issues);
  }

  issues.addAll(
    analyzeChunkV2Seams(
      chunks: chunks,
      levels: document.levels,
      collisionExpansionByChunkKey: collisionExpansions,
      sourcePathByChunkKey: document.sourcePathByChunkKey,
    ).issues,
  );

  _sortValidationIssues(issues);
  return List<ValidationIssue>.unmodifiable(issues);
}

void _sortValidationIssues(List<ValidationIssue> issues) {
  issues.sort((left, right) {
    var order = (left.sourcePath ?? '').compareTo(right.sourcePath ?? '');
    if (order != 0) return order;
    order = left.code.compareTo(right.code);
    if (order != 0) return order;
    return left.message.compareTo(right.message);
  });
}

ValidationIssue _issueFromCore(
  TerrainDiagnostic diagnostic, {
  required String ownerKey,
}) => _validationIssueFromTerrain(
  TerrainAuthoringIssue.fromCore(
    diagnostic: diagnostic,
    ownerKey: ownerKey,
    placementKey: null,
  ),
);

ValidationIssue _validationIssueFromTerrain(TerrainAuthoringIssue issue) =>
    ValidationIssue(
      severity: switch (issue.severity) {
        TerrainAuthoringIssueSeverity.warning => ValidationSeverity.warning,
        TerrainAuthoringIssueSeverity.error => ValidationSeverity.error,
      },
      code: issue.code,
      message: issue.message,
      sourcePath: issue.sourcePath,
      ownerKey: issue.ownerKey,
      placementKey: issue.placementKey,
      shapeId: issue.shapeId,
      elementIndex: issue.elementIndex,
    );
