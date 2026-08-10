import 'package:meta/meta.dart';

import '../domain/authoring_types.dart';
import 'chunk_domain_models.dart';
import 'chunk_store.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_models.dart';
import 'chunk_v2_validation.dart';

/// Immutable optimistic-concurrency snapshot for chunk-v2 lifecycle edits.
@immutable
final class ChunkV2LifecycleSnapshot {
  ChunkV2LifecycleSnapshot._({
    required Iterable<_ChunkV2LifecycleOwner> owners,
    required Iterable<_ChunkV2LifecycleSource> sources,
    required this.activeLevelId,
    required Iterable<String> levelTokens,
  }) : _owners = List<_ChunkV2LifecycleOwner>.unmodifiable(owners),
       _sources = List<_ChunkV2LifecycleSource>.unmodifiable(sources),
       _levelTokens = List<String>.unmodifiable(levelTokens);

  factory ChunkV2LifecycleSnapshot.fromDocument(ChunkV2Document document) {
    final created = document.createdChunkKeys.toSet();
    final owners =
        document.chunks
            .map(
              (chunk) => _ChunkV2LifecycleOwner(
                chunkKey: chunk.chunkKey,
                id: chunk.id,
                revision: chunk.revision,
                created: created.contains(chunk.chunkKey),
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.chunkKey.compareTo(right.chunkKey));
    final sourceKeys = <String>{
      ...document.sourcePathByChunkKey.keys,
      ...document.baselineContentsByChunkKey.keys,
    }.toList(growable: false)..sort();
    final sources = sourceKeys
        .map(
          (chunkKey) => _ChunkV2LifecycleSource(
            chunkKey: chunkKey,
            sourcePath: document.sourcePathByChunkKey[chunkKey],
            baselineContents: document.baselineContentsByChunkKey[chunkKey],
          ),
        )
        .toList(growable: false);
    final levelTokens =
        document.levels
            .map(
              (level) => <String>[
                level.levelId,
                '${level.revision}',
                ...level.chunkThemeGroups,
              ].join('\u0000'),
            )
            .toList(growable: false)
          ..sort();
    return ChunkV2LifecycleSnapshot._(
      owners: owners,
      sources: sources,
      activeLevelId: document.activeLevelId,
      levelTokens: levelTokens,
    );
  }

  final List<_ChunkV2LifecycleOwner> _owners;
  final List<_ChunkV2LifecycleSource> _sources;
  final String? activeLevelId;
  final List<String> _levelTokens;
}

@immutable
sealed class ChunkV2LifecycleOperation {
  const ChunkV2LifecycleOperation();
}

/// Creates one empty, deprecated owner in the active level.
@immutable
final class ChunkV2CreateOperation extends ChunkV2LifecycleOperation {
  const ChunkV2CreateOperation({required this.id});

  final String id;
}

/// Copies one complete owner under a fresh stable key and revision 1.
@immutable
final class ChunkV2DuplicateOperation extends ChunkV2LifecycleOperation {
  const ChunkV2DuplicateOperation({
    required this.sourceChunkKey,
    this.targetId,
  });

  final String sourceChunkKey;
  final String? targetId;
}

/// Renames one owner while retaining its stable chunk key.
@immutable
final class ChunkV2RenameOperation extends ChunkV2LifecycleOperation {
  const ChunkV2RenameOperation({required this.chunkKey, required this.nextId});

  final String chunkKey;
  final String nextId;
}

/// Removes one owner; a loaded owner retains baseline deletion evidence.
@immutable
final class ChunkV2DeleteOperation extends ChunkV2LifecycleOperation {
  const ChunkV2DeleteOperation({required this.chunkKey});

  final String chunkKey;
}

/// One stale-checked lifecycle mutation.
@immutable
final class ChunkV2LifecycleCommit {
  const ChunkV2LifecycleCommit({required this.before, required this.operation});

  final ChunkV2LifecycleSnapshot before;
  final ChunkV2LifecycleOperation operation;
}

/// Outcome of one chunk-v2 lifecycle mutation.
final class ChunkV2LifecycleCommitResult {
  ChunkV2LifecycleCommitResult({
    required this.document,
    required this.accepted,
    required this.changed,
    Iterable<ValidationIssue> issues = const <ValidationIssue>[],
  }) : issues = List<ValidationIssue>.unmodifiable(issues);

  final ChunkV2Document document;
  final bool accepted;
  final bool changed;
  final List<ValidationIssue> issues;
}

/// Deterministic lifecycle, ownership, and validation policy for chunk v2.
final class ChunkV2LifecycleCommitPolicy {
  const ChunkV2LifecycleCommitPolicy({ChunkStore store = const ChunkStore()})
    : _store = store;

  final ChunkStore _store;

  ChunkV2LifecycleCommitResult apply({
    required ChunkV2Document document,
    required ChunkV2LifecycleCommit commit,
  }) {
    final current = ChunkV2LifecycleSnapshot.fromDocument(document);
    if (!_snapshotsEqual(current, commit.before)) {
      return _rejected(
        document,
        code: 'chunk_v2_lifecycle_commit_stale',
        message:
            'Chunk ownership changed after this lifecycle edit began; reload '
            'the current source set before committing.',
      );
    }

    final candidate = switch (commit.operation) {
      final ChunkV2CreateOperation operation => _create(document, operation),
      final ChunkV2DuplicateOperation operation => _duplicate(
        document,
        operation,
      ),
      final ChunkV2RenameOperation operation => _rename(document, operation),
      final ChunkV2DeleteOperation operation => _delete(document, operation),
    };
    if (identical(candidate, document)) {
      return ChunkV2LifecycleCommitResult(
        document: document,
        accepted: true,
        changed: false,
      );
    }
    if (candidate is _LifecycleRejection) {
      return _rejected(
        document,
        code: candidate.code,
        message: candidate.message,
        chunkKey: candidate.chunkKey,
      );
    }

    final next = candidate as ChunkV2Document;
    final issues = validateChunkV2Document(next);
    if (issues.any((issue) => issue.severity == ValidationSeverity.error)) {
      return ChunkV2LifecycleCommitResult(
        document: document,
        accepted: false,
        changed: false,
        issues: issues,
      );
    }
    try {
      _store.buildV2SavePlan(document: next);
    } on StateError catch (error) {
      return _rejected(
        document,
        code: 'chunk_v2_lifecycle_ownership_invalid',
        message: 'Chunk lifecycle ownership is invalid: ${error.message}',
      );
    }
    return ChunkV2LifecycleCommitResult(
      document: next,
      accepted: true,
      changed: true,
      issues: issues,
    );
  }

  Object _create(ChunkV2Document document, ChunkV2CreateOperation operation) {
    final idIssue = _idIssue(document, operation.id);
    if (idIssue != null) return idIssue;
    final activeLevelId = document.activeLevelId;
    if (activeLevelId == null) {
      return const _LifecycleRejection(
        code: 'chunk_v2_create_active_level_missing',
        message: 'Create chunk requires an active level.',
      );
    }
    final templates =
        document.chunks
            .where((chunk) => chunk.levelId == activeLevelId)
            .toList(growable: false)
          ..sort(_compareChunks);
    if (templates.isEmpty) {
      return _LifecycleRejection(
        code: 'chunk_v2_create_authority_missing',
        message:
            'Create chunk requires an existing $activeLevelId owner to '
            'provide locked tile size and dimensions.',
      );
    }
    final template = templates.first;
    final chunkKey = _allocateChunkKey(
      document.sourcePathByChunkKey.keys.toSet(),
      operation.id,
    );
    final level = document.levels
        .where((entry) => entry.levelId == activeLevelId)
        .firstOrNull;
    final groups = level?.chunkThemeGroups.toList(growable: false)?..sort();
    final assemblyGroupId = groups == null || groups.isEmpty
        ? defaultChunkAssemblyGroupId
        : (groups.contains(defaultChunkAssemblyGroupId)
              ? defaultChunkAssemblyGroupId
              : groups.first);
    final chunk = ChunkV2FileData(
      chunkKey: chunkKey,
      id: operation.id,
      revision: 1,
      status: chunkStatusDeprecated,
      levelId: activeLevelId,
      tileSize: template.tileSize,
      width: template.width,
      height: template.height,
      difficulty: chunkDifficultyNormal,
      assemblyGroupId: assemblyGroupId,
      tags: const <String>[],
      tileLayers: const <TileLayerDef>[],
      prefabs: const <PlacedPrefabDef>[],
      markers: const <PlacedMarkerDef>[],
      groundBandZIndex: 0,
      collisionShapes: const [],
    );
    return _addCreatedOwner(document, chunk);
  }

  Object _duplicate(
    ChunkV2Document document,
    ChunkV2DuplicateOperation operation,
  ) {
    final source = document.chunks
        .where((chunk) => chunk.chunkKey == operation.sourceChunkKey)
        .firstOrNull;
    if (source == null) {
      return _LifecycleRejection(
        code: 'chunk_v2_duplicate_source_missing',
        message: 'Cannot duplicate unknown chunk ${operation.sourceChunkKey}.',
        chunkKey: operation.sourceChunkKey,
      );
    }
    final targetId = operation.targetId ?? _allocateCopyId(document, source.id);
    final idIssue = _idIssue(document, targetId);
    if (idIssue != null) return idIssue;
    final chunkKey = _allocateChunkKey(
      document.sourcePathByChunkKey.keys.toSet(),
      targetId,
    );
    return _addCreatedOwner(
      document,
      source.copyWith(
        chunkKey: chunkKey,
        id: targetId,
        revision: 1,
        status: chunkStatusActive,
      ),
    );
  }

  Object _rename(ChunkV2Document document, ChunkV2RenameOperation operation) {
    final index = document.chunks.indexWhere(
      (chunk) => chunk.chunkKey == operation.chunkKey,
    );
    if (index < 0) {
      return _LifecycleRejection(
        code: 'chunk_v2_rename_owner_missing',
        message: 'Cannot rename unknown chunk ${operation.chunkKey}.',
        chunkKey: operation.chunkKey,
      );
    }
    final current = document.chunks[index];
    if (current.id == operation.nextId) return document;
    final idIssue = _idIssue(
      document,
      operation.nextId,
      exceptChunkKey: operation.chunkKey,
    );
    if (idIssue != null) return idIssue;
    final renamed = current.copyWith(
      id: operation.nextId,
      revision: current.revision + 1,
    );
    final chunks = document.chunks.toList(growable: false);
    chunks[index] = renamed;
    Map<String, String>? sourcePaths;
    if (document.createdChunkKeys.contains(operation.chunkKey)) {
      sourcePaths = Map<String, String>.of(document.sourcePathByChunkKey);
      sourcePaths[operation.chunkKey] = _store.canonicalV2SourcePath(renamed);
    }
    return document.copyWith(
      chunks: _sortedChunks(chunks),
      sourcePathByChunkKey: sourcePaths,
      changedChunkKeys: <String>{
        ...document.changedChunkKeys,
        operation.chunkKey,
      },
    );
  }

  Object _delete(ChunkV2Document document, ChunkV2DeleteOperation operation) {
    final current = document.chunks
        .where((chunk) => chunk.chunkKey == operation.chunkKey)
        .firstOrNull;
    if (current == null) {
      return _LifecycleRejection(
        code: 'chunk_v2_delete_owner_missing',
        message: 'Cannot delete unknown chunk ${operation.chunkKey}.',
        chunkKey: operation.chunkKey,
      );
    }
    final chunks = document.chunks
        .where((chunk) => chunk.chunkKey != operation.chunkKey)
        .toList(growable: false);
    final isCreated = document.createdChunkKeys.contains(operation.chunkKey);
    if (!isCreated) {
      return document.copyWith(
        chunks: chunks,
        changedChunkKeys: <String>{
          ...document.changedChunkKeys,
          operation.chunkKey,
        },
      );
    }
    final sourcePaths = Map<String, String>.of(document.sourcePathByChunkKey)
      ..remove(operation.chunkKey);
    final changed = document.changedChunkKeys.toSet()
      ..remove(operation.chunkKey);
    final created = document.createdChunkKeys.toSet()
      ..remove(operation.chunkKey);
    return document.copyWith(
      chunks: chunks,
      sourcePathByChunkKey: sourcePaths,
      changedChunkKeys: changed,
      createdChunkKeys: created,
    );
  }

  ChunkV2Document _addCreatedOwner(
    ChunkV2Document document,
    ChunkV2FileData chunk,
  ) {
    final sourcePaths = Map<String, String>.of(document.sourcePathByChunkKey);
    sourcePaths[chunk.chunkKey] = _store.canonicalV2SourcePath(chunk);
    return document.copyWith(
      chunks: _sortedChunks(<ChunkV2FileData>[...document.chunks, chunk]),
      sourcePathByChunkKey: sourcePaths,
      changedChunkKeys: <String>{...document.changedChunkKeys, chunk.chunkKey},
      createdChunkKeys: <String>{...document.createdChunkKeys, chunk.chunkKey},
    );
  }
}

_LifecycleRejection? _idIssue(
  ChunkV2Document document,
  String id, {
  String? exceptChunkKey,
}) {
  if (!_stableChunkId.hasMatch(id)) {
    return _LifecycleRejection(
      code: 'chunk_v2_lifecycle_id_invalid',
      message:
          'Chunk id "$id" must start with a lowercase letter and contain '
          'only lowercase letters, digits, and underscores.',
      chunkKey: exceptChunkKey,
    );
  }
  final collision = document.chunks.any(
    (chunk) => chunk.chunkKey != exceptChunkKey && chunk.id == id,
  );
  if (collision) {
    return _LifecycleRejection(
      code: 'chunk_v2_lifecycle_id_collision',
      message: 'Chunk id "$id" is already owned.',
      chunkKey: exceptChunkKey,
    );
  }
  return null;
}

String _allocateCopyId(ChunkV2Document document, String sourceId) {
  final existingIds = document.chunks.map((chunk) => chunk.id).toSet();
  final base = '${sourceId}_copy';
  if (!existingIds.contains(base)) return base;
  var suffix = 2;
  while (existingIds.contains('${base}_$suffix')) {
    suffix += 1;
  }
  return '${base}_$suffix';
}

String _allocateChunkKey(Set<String> claimedKeys, String id) {
  if (!claimedKeys.contains(id)) return id;
  var suffix = 2;
  while (claimedKeys.contains('${id}_$suffix')) {
    suffix += 1;
  }
  return '${id}_$suffix';
}

List<ChunkV2FileData> _sortedChunks(Iterable<ChunkV2FileData> chunks) =>
    chunks.toList(growable: false)..sort(_compareChunks);

int _compareChunks(ChunkV2FileData left, ChunkV2FileData right) {
  final levelOrder = left.levelId.compareTo(right.levelId);
  if (levelOrder != 0) return levelOrder;
  final idOrder = left.id.compareTo(right.id);
  return idOrder != 0 ? idOrder : left.chunkKey.compareTo(right.chunkKey);
}

bool _snapshotsEqual(
  ChunkV2LifecycleSnapshot left,
  ChunkV2LifecycleSnapshot right,
) {
  if (left.activeLevelId != right.activeLevelId) return false;
  if (left._owners.length != right._owners.length) return false;
  for (var index = 0; index < left._owners.length; index += 1) {
    if (left._owners[index] != right._owners[index]) return false;
  }
  if (left._sources.length != right._sources.length) return false;
  for (var index = 0; index < left._sources.length; index += 1) {
    if (left._sources[index] != right._sources[index]) return false;
  }
  if (left._levelTokens.length != right._levelTokens.length) return false;
  for (var index = 0; index < left._levelTokens.length; index += 1) {
    if (left._levelTokens[index] != right._levelTokens[index]) return false;
  }
  return true;
}

ChunkV2LifecycleCommitResult _rejected(
  ChunkV2Document document, {
  required String code,
  required String message,
  String? chunkKey,
}) => ChunkV2LifecycleCommitResult(
  document: document,
  accepted: false,
  changed: false,
  issues: <ValidationIssue>[
    ValidationIssue(
      severity: ValidationSeverity.error,
      code: code,
      message: message,
      sourcePath: chunkKey == null
          ? null
          : document.sourcePathByChunkKey[chunkKey],
    ),
  ],
);

@immutable
final class _ChunkV2LifecycleOwner {
  const _ChunkV2LifecycleOwner({
    required this.chunkKey,
    required this.id,
    required this.revision,
    required this.created,
  });

  final String chunkKey;
  final String id;
  final int revision;
  final bool created;

  @override
  bool operator ==(Object other) =>
      other is _ChunkV2LifecycleOwner &&
      chunkKey == other.chunkKey &&
      id == other.id &&
      revision == other.revision &&
      created == other.created;

  @override
  int get hashCode => Object.hash(chunkKey, id, revision, created);
}

@immutable
final class _ChunkV2LifecycleSource {
  const _ChunkV2LifecycleSource({
    required this.chunkKey,
    required this.sourcePath,
    required this.baselineContents,
  });

  final String chunkKey;
  final String? sourcePath;
  final String? baselineContents;

  @override
  bool operator ==(Object other) =>
      other is _ChunkV2LifecycleSource &&
      chunkKey == other.chunkKey &&
      sourcePath == other.sourcePath &&
      baselineContents == other.baselineContents;

  @override
  int get hashCode => Object.hash(chunkKey, sourcePath, baselineContents);
}

final class _LifecycleRejection {
  const _LifecycleRejection({
    required this.code,
    required this.message,
    this.chunkKey,
  });

  final String code;
  final String message;
  final String? chunkKey;
}

final RegExp _stableChunkId = RegExp(r'^[a-z][a-z0-9_]*$');
