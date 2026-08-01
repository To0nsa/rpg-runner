import '../domain/authoring_types.dart';
import '../terrain_authoring/terrain_polygon_interaction.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_validation.dart';

/// Result of applying one shared polygon interaction commit to a chunk owner.
final class ChunkV2CollisionCommitResult {
  ChunkV2CollisionCommitResult({
    required this.chunk,
    required this.accepted,
    required this.changed,
    required Iterable<ValidationIssue> issues,
  }) : issues = List<ValidationIssue>.unmodifiable(issues);

  final ChunkV2FileData chunk;
  final bool accepted;
  final bool changed;
  final List<ValidationIssue> issues;
}

/// Chunk-owned validation and revision policy for polygon commits.
///
/// The shared reducer owns gesture geometry. This boundary verifies commit
/// freshness, canonical owner ordering, closed chunk bounds, and Core geometry
/// before replacing one immutable chunk and advancing its revision exactly
/// once. Rejected and no-op commits preserve the original chunk identity.
final class ChunkV2CollisionCommitPolicy {
  const ChunkV2CollisionCommitPolicy();

  ChunkV2CollisionCommitResult apply({
    required ChunkV2FileData chunk,
    required TerrainPolygonInteractionCommit commit,
    String sourcePath = 'chunk.json',
    int chunkIndex = 0,
  }) {
    if (!_shapeListsEqual(chunk.collisionShapes, commit.beforeShapes)) {
      return _rejected(
        chunk,
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_polygon_commit_stale',
          message:
              'Chunk ${chunk.id} changed after this polygon gesture began; '
              'reload its current collision source before committing.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (_shapeListsEqual(commit.beforeShapes, commit.afterShapes)) {
      return ChunkV2CollisionCommitResult(
        chunk: chunk,
        accepted: true,
        changed: false,
        issues: const <ValidationIssue>[],
      );
    }

    late final List<TerrainSourceShapeDef> canonicalShapes;
    try {
      canonicalShapes = canonicalTerrainSourceShapes(commit.afterShapes);
    } on ArgumentError catch (error) {
      return _rejected(
        chunk,
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_collision_shape_identity_invalid',
          message: 'Chunk ${chunk.id} has invalid shape identity: $error',
          sourcePath: sourcePath,
        ),
      );
    }
    if (!_shapeListsEqual(canonicalShapes, commit.afterShapes)) {
      return _rejected(
        chunk,
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_collision_shape_order_noncanonical',
          message:
              'Chunk ${chunk.id} collision shapes must be ordered by stable '
              'shape ID before commit.',
          sourcePath: sourcePath,
        ),
      );
    }

    final issues = validateChunkV2CollisionShapes(
      chunk: chunk,
      collisionShapes: canonicalShapes,
      sourcePath: sourcePath,
      chunkIndex: chunkIndex,
    );
    if (issues.any((issue) => issue.severity == ValidationSeverity.error)) {
      return ChunkV2CollisionCommitResult(
        chunk: chunk,
        accepted: false,
        changed: false,
        issues: issues,
      );
    }

    return ChunkV2CollisionCommitResult(
      chunk: chunk.copyWith(
        revision: chunk.revision + 1,
        collisionShapes: canonicalShapes,
      ),
      accepted: true,
      changed: true,
      issues: issues,
    );
  }
}

ChunkV2CollisionCommitResult _rejected(
  ChunkV2FileData chunk,
  ValidationIssue issue,
) => ChunkV2CollisionCommitResult(
  chunk: chunk,
  accepted: false,
  changed: false,
  issues: <ValidationIssue>[issue],
);

bool _shapeListsEqual(
  List<TerrainSourceShapeDef> left,
  List<TerrainSourceShapeDef> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
