import 'package:meta/meta.dart';

import '../domain/authoring_types.dart';
import 'chunk_domain_models.dart';
import 'chunk_v2_file_data.dart';

/// Immutable editable metadata owned by one chunk-v2 source record.
///
/// Source identity, dimensions, composition, markers, placements, and polygon
/// geometry are intentionally absent so a metadata command cannot mutate them.
@immutable
final class ChunkV2MetadataSnapshot {
  ChunkV2MetadataSnapshot({
    required this.status,
    required this.levelId,
    required this.difficulty,
    required this.assemblyGroupId,
    required Iterable<String> tags,
    required this.groundBandZIndex,
  }) : tags = List<String>.unmodifiable(tags);

  factory ChunkV2MetadataSnapshot.fromChunk(ChunkV2FileData chunk) =>
      ChunkV2MetadataSnapshot(
        status: chunk.status,
        levelId: chunk.levelId,
        difficulty: chunk.difficulty,
        assemblyGroupId: chunk.assemblyGroupId,
        tags: chunk.tags,
        groundBandZIndex: chunk.groundBandZIndex,
      );

  final String status;
  final String levelId;
  final String difficulty;
  final String assemblyGroupId;
  final List<String> tags;
  final int groundBandZIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChunkV2MetadataSnapshot &&
          status == other.status &&
          levelId == other.levelId &&
          difficulty == other.difficulty &&
          assemblyGroupId == other.assemblyGroupId &&
          _stringListsEqual(tags, other.tags) &&
          groundBandZIndex == other.groundBandZIndex;

  @override
  int get hashCode => Object.hash(
    status,
    levelId,
    difficulty,
    assemblyGroupId,
    Object.hashAll(tags),
    groundBandZIndex,
  );
}

/// One optimistic-concurrency metadata edit for an existing chunk-v2 owner.
@immutable
final class ChunkV2MetadataCommit {
  const ChunkV2MetadataCommit({required this.before, required this.after});

  final ChunkV2MetadataSnapshot before;
  final ChunkV2MetadataSnapshot after;
}

/// Result of applying one typed chunk-v2 metadata commit.
final class ChunkV2MetadataCommitResult {
  ChunkV2MetadataCommitResult({
    required this.chunk,
    required this.accepted,
    required this.changed,
    Iterable<ValidationIssue> issues = const <ValidationIssue>[],
  }) : issues = List<ValidationIssue>.unmodifiable(issues);

  final ChunkV2FileData chunk;
  final bool accepted;
  final bool changed;
  final List<ValidationIssue> issues;
}

/// Fail-closed metadata and revision policy for an existing chunk-v2 owner.
final class ChunkV2MetadataCommitPolicy {
  const ChunkV2MetadataCommitPolicy();

  ChunkV2MetadataCommitResult apply({
    required ChunkV2FileData chunk,
    required ChunkV2MetadataCommit commit,
    required Iterable<String> knownLevelIds,
    required Map<String, Iterable<String>> allowedAssemblyGroupIdsByLevelId,
    String sourcePath = 'chunk.json',
  }) {
    final current = ChunkV2MetadataSnapshot.fromChunk(chunk);
    if (current != commit.before) {
      return _rejected(
        chunk,
        code: 'chunk_v2_metadata_commit_stale',
        message:
            'Chunk ${chunk.chunkKey} changed after this metadata edit began; '
            'reload its current source before committing.',
        sourcePath: sourcePath,
      );
    }
    if (commit.before == commit.after) {
      return ChunkV2MetadataCommitResult(
        chunk: chunk,
        accepted: true,
        changed: false,
      );
    }

    final after = commit.after;
    if (after.status != chunkStatusActive &&
        after.status != chunkStatusDeprecated) {
      return _rejected(
        chunk,
        code: 'chunk_v2_metadata_status_invalid',
        message: 'Chunk ${chunk.chunkKey} has invalid status ${after.status}.',
        sourcePath: sourcePath,
      );
    }
    if (!knownLevelIds.contains(after.levelId)) {
      return _rejected(
        chunk,
        code: 'chunk_v2_metadata_level_unknown',
        message:
            'Chunk ${chunk.chunkKey} references unknown level '
            '${after.levelId}.',
        sourcePath: sourcePath,
      );
    }
    if (!_knownDifficulties.contains(after.difficulty)) {
      return _rejected(
        chunk,
        code: 'chunk_v2_metadata_difficulty_invalid',
        message:
            'Chunk ${chunk.chunkKey} has invalid difficulty '
            '${after.difficulty}.',
        sourcePath: sourcePath,
      );
    }
    if (!stableChunkAssemblyGroupPattern.hasMatch(after.assemblyGroupId)) {
      return _rejected(
        chunk,
        code: 'chunk_v2_metadata_assembly_group_invalid',
        message:
            'Chunk ${chunk.chunkKey} assembly group '
            '${after.assemblyGroupId} is not a stable identifier.',
        sourcePath: sourcePath,
      );
    }
    final allowedGroups =
        allowedAssemblyGroupIdsByLevelId[after.levelId] ??
        const <String>[defaultChunkAssemblyGroupId];
    if (!allowedGroups.contains(after.assemblyGroupId)) {
      return _rejected(
        chunk,
        code: 'chunk_v2_metadata_assembly_group_unknown',
        message:
            'Chunk ${chunk.chunkKey} assembly group '
            '${after.assemblyGroupId} is not declared by level '
            '${after.levelId}.',
        sourcePath: sourcePath,
      );
    }
    if (!_stringListsEqual(after.tags, _canonicalTags(after.tags))) {
      return _rejected(
        chunk,
        code: 'chunk_v2_metadata_tags_noncanonical',
        message:
            'Chunk ${chunk.chunkKey} tags must have trimmed non-empty '
            'entries, be unique, and be ordered lexically before commit.',
        sourcePath: sourcePath,
      );
    }

    return ChunkV2MetadataCommitResult(
      chunk: chunk.copyWith(
        revision: chunk.revision + 1,
        status: after.status,
        levelId: after.levelId,
        difficulty: after.difficulty,
        assemblyGroupId: after.assemblyGroupId,
        tags: after.tags,
        groundBandZIndex: after.groundBandZIndex,
      ),
      accepted: true,
      changed: true,
    );
  }
}

const Set<String> _knownDifficulties = <String>{
  chunkDifficultyEarly,
  chunkDifficultyEasy,
  chunkDifficultyNormal,
  chunkDifficultyHard,
};

ChunkV2MetadataCommitResult _rejected(
  ChunkV2FileData chunk, {
  required String code,
  required String message,
  required String sourcePath,
}) => ChunkV2MetadataCommitResult(
  chunk: chunk,
  accepted: false,
  changed: false,
  issues: <ValidationIssue>[
    ValidationIssue(
      severity: ValidationSeverity.error,
      code: code,
      message: message,
      sourcePath: sourcePath,
    ),
  ],
);

List<String> _canonicalTags(Iterable<String> tags) {
  final canonical =
      tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
  return canonical;
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
