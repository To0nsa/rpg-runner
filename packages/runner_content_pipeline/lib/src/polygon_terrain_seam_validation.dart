import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';
import 'package:runner_core/collision/terrain/terrain_boundary_signature.dart';

import 'polygon_terrain_compilation.dart';
import 'polygon_terrain_seam_manifest.dart';

/// Generator-facing seam issues use Core's portable authoring envelope.
typedef PolygonTerrainSeamValidationIssue = TerrainAuthoringIssue;

/// One checked scheduler transition and its exact Core boundary comparison.
final class PolygonTerrainValidatedSeam {
  const PolygonTerrainValidatedSeam({
    required this.transition,
    required this.comparison,
  });

  final TerrainAuthoringSeamTransition transition;
  final TerrainBoundaryComparison comparison;
}

/// Only staged chunk collection accepted by the renderer.
///
/// Construction is private so every render must first pass
/// [validatePolygonTerrainSeams], even for an intentionally empty scheduler
/// manifest used by an isolated compiler fixture.
final class PolygonTerrainValidatedBatch {
  PolygonTerrainValidatedBatch._({
    required Iterable<PolygonTerrainCompiledChunk> chunks,
    required this.seamSignature,
    required Iterable<PolygonTerrainValidatedSeam> seams,
  }) : chunks = List<PolygonTerrainCompiledChunk>.unmodifiable(chunks),
       seams = List<PolygonTerrainValidatedSeam>.unmodifiable(seams);

  final List<PolygonTerrainCompiledChunk> chunks;
  final TerrainAuthoringSeamSignature seamSignature;
  final List<PolygonTerrainValidatedSeam> seams;
}

/// Fail-closed result; invalid seam input never coexists with a render batch.
final class PolygonTerrainSeamValidationResult {
  PolygonTerrainSeamValidationResult({
    required this.batch,
    required Iterable<PolygonTerrainSeamValidationIssue> issues,
  }) : issues = canonicalTerrainAuthoringIssues(issues);

  final PolygonTerrainValidatedBatch? batch;
  final List<PolygonTerrainSeamValidationIssue> issues;
}

/// Validates every manifest transition against compiled local boundaries.
PolygonTerrainSeamValidationResult validatePolygonTerrainSeams({
  required Iterable<PolygonTerrainCompiledChunk> chunks,
  required PolygonTerrainSeamManifest manifest,
}) {
  final ordered = List<PolygonTerrainCompiledChunk>.of(chunks)
    ..sort(_compareChunks);
  final issues = <PolygonTerrainSeamValidationIssue>[];
  final chunkByKey = <String, PolygonTerrainCompiledChunk>{};
  final foldedKey = <String, String>{};
  for (final compiled in ordered) {
    final key = compiled.chunk.chunkKey;
    if (chunkByKey.containsKey(key)) {
      issues.add(
        _seamIssue(
          code: 'staged_seam_chunk_duplicate',
          message: 'Duplicate compiled chunk key $key.',
          sourcePath: manifest.sourcePath,
          ownerKey: key,
        ),
      );
      continue;
    }
    final folded = key.toLowerCase();
    final previous = foldedKey[folded];
    if (previous != null) {
      issues.add(
        _seamIssue(
          code: 'staged_seam_chunk_case_collision',
          message: 'Compiled chunk key $key case-collides with $previous.',
          sourcePath: manifest.sourcePath,
          ownerKey: key,
        ),
      );
      continue;
    }
    chunkByKey[key] = compiled;
    foldedKey[folded] = key;
  }

  final seams = <PolygonTerrainValidatedSeam>[];
  for (final transition in manifest.signature.transitions) {
    final left = chunkByKey[transition.leftChunkKey];
    final right = chunkByKey[transition.rightChunkKey];
    final missing = <String>{
      if (left == null) transition.leftChunkKey,
      if (right == null) transition.rightChunkKey,
    }.toList()..sort();
    if (missing.isNotEmpty) {
      for (final missingKey in missing) {
        issues.add(
          _seamIssue(
            code: 'staged_seam_chunk_missing',
            message:
                '${transition.canonicalRecord} references missing compiled '
                'chunk $missingKey.',
            sourcePath: manifest.sourcePath,
            ownerKey: missingKey,
          ),
        );
      }
      continue;
    }
    final resolvedLeft = left!;
    final resolvedRight = right!;
    final wrongLevelOwners = <String, PolygonTerrainCompiledChunk>{
      if (resolvedLeft.chunk.levelId != transition.levelId)
        resolvedLeft.chunk.chunkKey: resolvedLeft,
      if (resolvedRight.chunk.levelId != transition.levelId)
        resolvedRight.chunk.chunkKey: resolvedRight,
    }.values;
    if (wrongLevelOwners.isNotEmpty) {
      for (final compiled in wrongLevelOwners) {
        issues.add(
          _seamIssue(
            code: 'staged_seam_level_mismatch',
            message:
                '${transition.canonicalRecord} belongs to level '
                '${transition.levelId}, but compiled Chunk '
                '${compiled.chunk.chunkKey} belongs to '
                '${compiled.chunk.levelId}.',
            sourcePath: manifest.sourcePath,
            ownerKey: compiled.chunk.chunkKey,
          ),
        );
      }
      continue;
    }

    final leftBoundary = buildTerrainBoundarySignature(
      chunkKey: resolvedLeft.chunk.chunkKey,
      chunkWidth: resolvedLeft.chunk.width,
      geometry: resolvedLeft.geometry,
      side: TerrainBoundarySide.right,
    );
    final rightBoundary = buildTerrainBoundarySignature(
      chunkKey: resolvedRight.chunk.chunkKey,
      chunkWidth: resolvedRight.chunk.width,
      geometry: resolvedRight.geometry,
      side: TerrainBoundarySide.left,
    );
    final comparison = compareTerrainBoundaries(
      left: leftBoundary,
      right: rightBoundary,
    );
    seams.add(
      PolygonTerrainValidatedSeam(
        transition: transition,
        comparison: comparison,
      ),
    );
    if (!comparison.isCompatible) {
      issues.add(
        _seamIssue(
          code: 'staged_reachable_seam_mismatch',
          message:
              '${transition.canonicalRecord} has incompatible compiled '
              'boundaries at physics ticks '
              '[${comparison.mismatchYTicks.join(', ')}]; right '
              '${leftBoundary.digest} ${leftBoundary.physicalRecord}; left '
              '${rightBoundary.digest} ${rightBoundary.physicalRecord}.',
          sourcePath: manifest.sourcePath,
          ownerKey: transition.rightChunkKey,
        ),
      );
    }
  }

  if (issues.isNotEmpty) {
    return PolygonTerrainSeamValidationResult(batch: null, issues: issues);
  }
  return PolygonTerrainSeamValidationResult(
    batch: PolygonTerrainValidatedBatch._(
      chunks: ordered,
      seamSignature: manifest.signature,
      seams: seams,
    ),
    issues: const <PolygonTerrainSeamValidationIssue>[],
  );
}

PolygonTerrainSeamValidationIssue _seamIssue({
  required String code,
  required String message,
  required String sourcePath,
  required String ownerKey,
}) => TerrainAuthoringIssue(
  severity: TerrainAuthoringIssueSeverity.error,
  code: code,
  message: message,
  sourcePath: sourcePath,
  ownerKey: ownerKey,
  placementKey: null,
  shapeId: null,
  elementIndex: null,
);

int _compareChunks(
  PolygonTerrainCompiledChunk left,
  PolygonTerrainCompiledChunk right,
) {
  var order = left.chunk.chunkKey.compareTo(right.chunk.chunkKey);
  if (order != 0) return order;
  order = left.chunk.id.compareTo(right.chunk.id);
  return order != 0
      ? order
      : left.chunk.revision.compareTo(right.chunk.revision);
}
