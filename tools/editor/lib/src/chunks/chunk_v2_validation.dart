import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_source_canonicalizer.dart';

import '../domain/authoring_types.dart';
import '../terrain_authoring/terrain_source_core_adapter.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'chunk_domain_models.dart';
import 'chunk_v2_collision_expansion.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_staging_models.dart';

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
      issues.add(_issueFromCore(diagnostic));
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
      issues.addAll(error.diagnostics.map(_issueFromCore));
    }
  }
  _sortValidationIssues(issues);
  return List<ValidationIssue>.unmodifiable(issues);
}

/// Validates the strict chunk-v2 staging set including exact prefab expansion.
List<ValidationIssue> validateChunkV2StagingDocument(
  ChunkV2StagingDocument document,
) {
  final issues = <ValidationIssue>[];
  final chunks = List.of(document.chunks)
    ..sort((left, right) => left.chunkKey.compareTo(right.chunkKey));
  final chunkKeys = <String>{};
  final foldedChunkKeys = <String>{};
  final chunkIds = <String>{};

  if (document.availableLevelIds.isEmpty || document.activeLevelId == null) {
    issues.add(
      const ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'chunk_v2_active_level_missing',
        message: 'Chunk-v2 staging requires at least one active level.',
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
    if (sourcePath == null ||
        document.baselineContentsByChunkKey[chunk.chunkKey] == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_v2_source_baseline_missing',
          message:
              'Chunk ${chunk.chunkKey} is missing its staging source baseline.',
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

    issues.addAll(
      expandChunkV2Collision(
        chunk: chunk,
        prefabs: document.prefabData.prefabs,
        sourcePath: sourcePath ?? chunk.chunkKey,
        chunkIndex: chunkIndex,
      ).issues,
    );
  }

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

ValidationIssue _issueFromCore(TerrainDiagnostic diagnostic) => ValidationIssue(
  severity: terrainDiagnosticIsBlocking(diagnostic)
      ? ValidationSeverity.error
      : ValidationSeverity.warning,
  code: diagnostic.code,
  message: diagnostic.message,
  sourcePath: diagnostic.sourcePath,
  shapeId: diagnostic.shapeId,
  elementIndex: diagnostic.elementIndex,
);
