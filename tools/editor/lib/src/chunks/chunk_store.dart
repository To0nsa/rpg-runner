import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../workspace/editor_workspace.dart';
import '../workspace/level_context_resolver.dart' as level_context;
import '../workspace/repository_authoring_paths.dart';
import '../workspace/workspace_file_io.dart';
import '../workspace/workspace_write_transaction.dart';
import 'chunk_v2_file_codec.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_models.dart';

/// One strict chunk-v2 source snapshot retained for current-schema editing.
class ChunkV2Source {
  const ChunkV2Source({
    required this.data,
    required this.sourcePath,
    required this.baselineContents,
  });

  final ChunkV2FileData data;
  final String sourcePath;
  final String baselineContents;
}

/// Complete all-v2 chunk source set loaded by the current source path.
class ChunkV2LoadResult {
  ChunkV2LoadResult({required Iterable<ChunkV2Source> sources})
    : sources = List<ChunkV2Source>.unmodifiable(sources);

  final List<ChunkV2Source> sources;
}

/// Schema family shared by every chunk file in one authoring workspace.
enum ChunkSourceGeneration { missing, legacyV1, currentV2 }

/// Stable failure from the explicit chunk-v2 write proof.
final class ChunkV2SaveException implements Exception {
  const ChunkV2SaveException({
    required this.code,
    required this.message,
    this.cause,
    this.rollbackComplete,
    this.outputsCommitted = false,
  });

  final String code;
  final String message;
  final Object? cause;
  final bool? rollbackComplete;
  final bool outputsCommitted;

  @override
  String toString() => '$code: $message';
}

class ChunkStore {
  static const String chunksDirectoryPath =
      RepositoryAuthoringPaths.chunksDirectory;
  static const String levelDefsPath = level_context.defaultLevelDefsPath;
  static const String levelIdSourcePath =
      level_context.defaultLevelIdSourcePath;
  static const String trackTuningSourcePath =
      'packages/runner_core/lib/tuning/track_tuning.dart';
  static const String spatialContractSourcePath =
      'packages/runner_core/lib/contracts/spatial_contract.dart';
  static const String levelWorldConstantsSourcePath =
      'packages/runner_core/lib/levels/level_world_constants.dart';

  const ChunkStore();

  /// Selects the normal chunk document family from the complete source tree.
  ///
  /// Every file must declare the same exact supported integer version. A mixed,
  /// malformed, or future tree fails before either codec can partially load it.
  /// An absent source set is reported separately from a legacy generation.
  ChunkSourceGeneration detectSourceGeneration(EditorWorkspace workspace) {
    final chunkFiles = _listChunkFiles(workspace);
    if (chunkFiles.isEmpty) {
      return ChunkSourceGeneration.missing;
    }
    ChunkSourceGeneration? detected;
    for (final file in chunkFiles) {
      final relativePath = WorkspaceFileIo.toWorkspaceRelativePath(
        workspace,
        file.path,
      );
      final raw = file.readAsStringSync();
      final parsed = _parseJsonMap(raw);
      if (parsed == null) {
        throw FormatException(
          'Malformed chunk JSON in $relativePath: expected an object.',
        );
      }
      final schemaVersion = parsed['schemaVersion'];
      if (schemaVersion is! int) {
        throw FormatException(
          'Malformed schemaVersion in $relativePath: expected an integer.',
        );
      }
      final generation = switch (schemaVersion) {
        1 => ChunkSourceGeneration.legacyV1,
        chunkSchemaVersionV2 => ChunkSourceGeneration.currentV2,
        _ => throw FormatException(
          'Unsupported chunk schemaVersion $schemaVersion in $relativePath.',
        ),
      };
      final previous = detected;
      if (previous != null && previous != generation) {
        throw StateError(
          'chunk_mixed_schema_generation: expected ${previous.name}, but '
          '$relativePath declares ${generation.name}.',
        );
      }
      detected = generation;
    }
    return detected!;
  }

  /// Strictly loads an all-v2 chunk source tree.
  ///
  /// Normal loading selects this path only after [detectSourceGeneration]
  /// proves that every source file is v2. Repository writes remain controlled
  /// by the separate export cutover gate.
  Future<ChunkV2LoadResult> loadV2(EditorWorkspace workspace) async {
    final chunkFiles = _listChunkFiles(workspace);
    if (chunkFiles.isEmpty) {
      throw StateError(
        'chunk_v2_source_missing: expected JSON files under '
        '${workspace.resolve(chunksDirectoryPath)}.',
      );
    }

    final sources = <ChunkV2Source>[];
    final sourcePathByFoldedChunkKey = <String, String>{};
    for (final file in chunkFiles) {
      final relativePath = WorkspaceFileIo.toWorkspaceRelativePath(
        workspace,
        file.path,
      );
      final raw = await file.readAsString();
      final data = ChunkV2FileCodec.decode(raw, sourcePath: relativePath);
      final foldedChunkKey = data.chunkKey.toLowerCase();
      final existingPath = sourcePathByFoldedChunkKey[foldedChunkKey];
      if (existingPath != null) {
        throw StateError(
          'chunk_v2_duplicate_chunk_key: ${data.chunkKey} is owned by both '
          '$existingPath and $relativePath.',
        );
      }
      sourcePathByFoldedChunkKey[foldedChunkKey] = relativePath;
      sources.add(
        ChunkV2Source(
          data: data,
          sourcePath: relativePath,
          baselineContents: raw,
        ),
      );
    }
    return ChunkV2LoadResult(sources: sources);
  }

  ChunkSavePlan buildV2SavePlan({required ChunkV2Document document}) {
    final chunks = List<ChunkV2FileData>.of(document.chunks)
      ..sort(_compareChunkV2ForMemory);
    final currentChunkKeys = chunks.map((chunk) => chunk.chunkKey).toSet();
    final createdChunkKeys = document.createdChunkKeys.toSet();

    final writes = <ChunkFileWrite>[];
    final finalOwnerByFoldedPath = <String, String>{};
    for (final chunk in chunks) {
      final isCreated = createdChunkKeys.contains(chunk.chunkKey);
      final sourcePath = document.sourcePathByChunkKey[chunk.chunkKey];
      final baseline = document.baselineContentsByChunkKey[chunk.chunkKey];
      if (sourcePath == null) {
        throw StateError('chunk_v2_source_path_missing: ${chunk.chunkKey}.');
      }
      final safeSourcePath = _requireWorkspaceRelativePath(
        sourcePath,
        chunkKey: chunk.chunkKey,
      );
      if (isCreated == (baseline != null)) {
        throw StateError(
          isCreated
              ? 'chunk_v2_created_owner_has_baseline: ${chunk.chunkKey}.'
              : 'chunk_v2_source_baseline_missing: ${chunk.chunkKey}.',
        );
      }

      final targetPath = isCreated
          ? canonicalV2SourcePath(chunk)
          : _resolveV2TargetChunkPath(chunk, sourcePath: safeSourcePath);
      if (isCreated && !p.equals(safeSourcePath, targetPath)) {
        throw StateError(
          'chunk_v2_created_owner_path_noncanonical: ${chunk.chunkKey}.',
        );
      }
      final foldedTargetPath = _portableRelativePath(targetPath).toLowerCase();
      final existingOwner = finalOwnerByFoldedPath[foldedTargetPath];
      if (existingOwner != null) {
        throw StateError(
          'chunk_v2_target_path_collision: $existingOwner and '
          '${chunk.chunkKey} both target $targetPath.',
        );
      }
      finalOwnerByFoldedPath[foldedTargetPath] = chunk.chunkKey;

      final after = ChunkV2FileCodec.encode(chunk);
      final previousPath = !isCreated && !p.equals(safeSourcePath, targetPath)
          ? safeSourcePath
          : null;
      if (baseline == after && previousPath == null) continue;
      writes.add(
        ChunkFileWrite(
          chunkKey: chunk.chunkKey,
          chunkId: chunk.id,
          relativePath: _portableRelativePath(targetPath),
          previousRelativePath: previousPath == null
              ? null
              : _portableRelativePath(previousPath),
          beforeContent: baseline,
          afterContent: after,
        ),
      );
    }

    for (final createdChunkKey in createdChunkKeys) {
      if (!currentChunkKeys.contains(createdChunkKey)) {
        throw StateError('chunk_v2_created_owner_missing: $createdChunkKey.');
      }
    }
    for (final entry in document.baselineContentsByChunkKey.entries) {
      if (currentChunkKeys.contains(entry.key)) continue;
      final sourcePath = document.sourcePathByChunkKey[entry.key];
      if (sourcePath == null) {
        throw StateError('chunk_v2_deleted_owner_path_missing: ${entry.key}.');
      }
      final safeSourcePath = _requireWorkspaceRelativePath(
        sourcePath,
        chunkKey: entry.key,
      );
      final foldedSourcePath = safeSourcePath.toLowerCase();
      final replacementOwner = finalOwnerByFoldedPath[foldedSourcePath];
      if (replacementOwner != null) {
        throw StateError(
          'chunk_v2_deleted_source_path_reused: ${entry.key} and '
          '$replacementOwner claim $sourcePath.',
        );
      }
      writes.add(
        ChunkFileWrite(
          chunkKey: entry.key,
          chunkId: entry.key,
          relativePath: safeSourcePath,
          beforeContent: entry.value,
          afterContent: '',
          deleteFile: true,
        ),
      );
    }

    writes.sort((left, right) {
      final pathOrder = left.relativePath.compareTo(right.relativePath);
      return pathOrder != 0
          ? pathOrder
          : left.chunkKey.compareTo(right.chunkKey);
    });
    _ensureNoCaseInsensitivePathCollision(writes);
    final changedChunkKeys = writes.map((write) => write.chunkKey).toSet()
      ..addAll(document.changedChunkKeys);
    return ChunkSavePlan(
      writes: List<ChunkFileWrite>.unmodifiable(writes),
      changedChunkKeys: List<String>.unmodifiable(
        changedChunkKeys.toList()..sort(),
      ),
    );
  }

  /// Applies one reviewed chunk-v2 plan to an all-current workspace.
  ///
  /// The complete source tree is rechecked after staging. Writes, managed
  /// moves, and deletions then commit through one rollback-safe transaction;
  /// installed files are byte-verified and strictly decoded before backups are
  /// removed. Normal plugin export reaches this only after schema detection has
  /// selected a complete v2 tree; it cannot migrate legacy source.
  void applyV2SavePlan(
    EditorWorkspace workspace, {
    required ChunkV2Document document,
    required ChunkSavePlan savePlan,
  }) {
    final rebuilt = buildV2SavePlan(document: document);
    if (!_savePlansEqual(rebuilt, savePlan)) {
      throw const ChunkV2SaveException(
        code: 'chunk_v2_save_plan_stale',
        message: 'Chunk-v2 save plan no longer matches the staged document.',
      );
    }
    try {
      _requireV2SourcesFresh(workspace, document);
    } on _ChunkV2SaveAbort catch (error) {
      throw ChunkV2SaveException(code: error.code, message: error.message);
    }
    if (!savePlan.hasChanges) return;

    final finalPaths = _v2FinalPathByChunkKey(
      document,
      savePlan,
    ).values.map((path) => _portableRelativePath(path).toLowerCase()).toSet();
    final artifacts = <WorkspaceWriteArtifact>[];
    for (final write in savePlan.writes) {
      if (write.deleteFile) {
        artifacts.add(
          WorkspaceWriteArtifact.delete(
            path: workspace.resolve(write.relativePath),
          ),
        );
        continue;
      }
      artifacts.add(
        WorkspaceWriteArtifact(
          path: workspace.resolve(write.relativePath),
          contents: write.afterContent,
        ),
      );
      final previousPath = write.previousRelativePath;
      if (previousPath == null ||
          p.equals(previousPath, write.relativePath) ||
          finalPaths.contains(
            _portableRelativePath(previousPath).toLowerCase(),
          )) {
        continue;
      }
      artifacts.add(
        WorkspaceWriteArtifact.delete(path: workspace.resolve(previousPath)),
      );
    }

    final transaction = WorkspaceWriteTransaction(artifacts);
    try {
      transaction.apply(
        beforeReplace: () => _requireV2SourcesFresh(workspace, document),
        verifyReplacements: () =>
            _requireV2PlanInstalled(workspace, document, savePlan),
      );
    } on WorkspaceWriteTransactionException catch (error, stackTrace) {
      final abort = error.cause is _ChunkV2SaveAbort
          ? error.cause as _ChunkV2SaveAbort
          : null;
      Error.throwWithStackTrace(
        ChunkV2SaveException(
          code: abort?.code ?? 'chunk_v2_save_transaction_failed',
          message:
              abort?.message ??
              'The chunk-v2 source transaction failed and attempted recovery.',
          cause: error.cause,
          rollbackComplete: error.rollbackComplete,
          outputsCommitted: error.outputsCommitted,
        ),
        stackTrace,
      );
    }
  }

  List<File> _listChunkFiles(EditorWorkspace workspace) {
    final chunkDirectory = Directory(workspace.resolve(chunksDirectoryPath));
    if (!chunkDirectory.existsSync()) {
      return const <File>[];
    }
    final files =
        chunkDirectory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.json'))
            .toList(growable: false)
          ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Map<String, Object?>? _parseJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
    } on Object {
      return null;
    }
    return null;
  }

  /// Canonical repository-relative source ownership for a chunk-v2 record.
  String canonicalV2SourcePath(ChunkV2FileData chunk) => _portableRelativePath(
    p.join(
      chunksDirectoryPath,
      _slugify(chunk.levelId),
      '${_slugify(chunk.id)}.json',
    ),
  );

  String _resolveV2TargetChunkPath(
    ChunkV2FileData chunk, {
    required String sourcePath,
  }) {
    final normalizedSourcePath = _portableRelativePath(sourcePath);
    return _isEditorManagedChunkPath(normalizedSourcePath)
        ? canonicalV2SourcePath(chunk)
        : normalizedSourcePath;
  }

  String _requireWorkspaceRelativePath(
    String path, {
    required String chunkKey,
  }) {
    final normalized = _portableRelativePath(path);
    if (path.trim().isEmpty ||
        normalized == '.' ||
        p.isAbsolute(path) ||
        normalized == '..' ||
        normalized.startsWith('../')) {
      throw StateError('chunk_v2_source_path_outside_workspace: $chunkKey.');
    }
    return normalized;
  }

  bool _isEditorManagedChunkPath(String relativePath) {
    final normalizedPath = p.normalize(relativePath);
    final normalizedChunksPath = p.normalize(chunksDirectoryPath);
    if (normalizedPath == normalizedChunksPath) {
      return false;
    }
    if (!p.isWithin(normalizedChunksPath, normalizedPath)) {
      return false;
    }
    final pathWithinChunks = p.normalize(
      p.relative(normalizedPath, from: normalizedChunksPath),
    );
    if (pathWithinChunks == '.' || pathWithinChunks.startsWith('..')) {
      return false;
    }
    final segments = p.split(pathWithinChunks);
    if (segments.isEmpty || segments.length > 2) {
      return false;
    }
    return segments.last.toLowerCase().endsWith('.json');
  }

  void _requireV2SourcesFresh(
    EditorWorkspace workspace,
    ChunkV2Document document,
  ) {
    final expectedByFoldedPath = <String, String>{};
    for (final entry in document.baselineContentsByChunkKey.entries) {
      final sourcePath = document.sourcePathByChunkKey[entry.key];
      if (sourcePath == null) {
        throw _ChunkV2SaveAbort(
          code: 'chunk_v2_save_baseline_path_missing',
          message: 'Baseline owner ${entry.key} has no source path.',
        );
      }
      expectedByFoldedPath[_portableRelativePath(sourcePath).toLowerCase()] =
          entry.value;
    }
    final actualFiles = _listChunkFiles(workspace);
    final actualByFoldedPath = <String, File>{};
    for (final file in actualFiles) {
      final relativePath = _portableRelativePath(
        WorkspaceFileIo.toWorkspaceRelativePath(workspace, file.path),
      );
      actualByFoldedPath[relativePath.toLowerCase()] = file;
    }
    if (actualByFoldedPath.length != expectedByFoldedPath.length ||
        !actualByFoldedPath.keys.toSet().containsAll(
          expectedByFoldedPath.keys,
        )) {
      throw const _ChunkV2SaveAbort(
        code: 'chunk_v2_save_source_set_drift',
        message:
            'Chunk source files changed after load; reload before applying '
            'the save plan.',
      );
    }
    for (final entry in expectedByFoldedPath.entries) {
      if (actualByFoldedPath[entry.key]!.readAsStringSync() != entry.value) {
        throw _ChunkV2SaveAbort(
          code: 'chunk_v2_save_source_drift',
          message:
              'Chunk source changed after load at '
              '${actualByFoldedPath[entry.key]!.path}.',
        );
      }
    }
  }

  Map<String, String> _v2FinalPathByChunkKey(
    ChunkV2Document document,
    ChunkSavePlan savePlan,
  ) {
    final writeByChunkKey = <String, ChunkFileWrite>{
      for (final write in savePlan.writes)
        if (!write.deleteFile) write.chunkKey: write,
    };
    return <String, String>{
      for (final chunk in document.chunks)
        chunk.chunkKey:
            writeByChunkKey[chunk.chunkKey]?.relativePath ??
            document.sourcePathByChunkKey[chunk.chunkKey]!,
    };
  }

  void _requireV2PlanInstalled(
    EditorWorkspace workspace,
    ChunkV2Document document,
    ChunkSavePlan savePlan,
  ) {
    final chunksByKey = <String, ChunkV2FileData>{
      for (final chunk in document.chunks) chunk.chunkKey: chunk,
    };
    final expectedByFoldedPath = <String, (String, String)>{};
    for (final entry in _v2FinalPathByChunkKey(document, savePlan).entries) {
      final path = _portableRelativePath(entry.value);
      expectedByFoldedPath[path.toLowerCase()] = (
        path,
        ChunkV2FileCodec.encode(chunksByKey[entry.key]!),
      );
    }
    final actualByFoldedPath = <String, File>{};
    for (final file in _listChunkFiles(workspace)) {
      final relativePath = _portableRelativePath(
        WorkspaceFileIo.toWorkspaceRelativePath(workspace, file.path),
      );
      actualByFoldedPath[relativePath.toLowerCase()] = file;
    }
    if (actualByFoldedPath.length != expectedByFoldedPath.length ||
        !actualByFoldedPath.keys.toSet().containsAll(
          expectedByFoldedPath.keys,
        )) {
      throw const _ChunkV2SaveAbort(
        code: 'chunk_v2_save_post_validation_failed',
        message: 'Installed chunk-v2 source set differs from the save plan.',
      );
    }
    for (final entry in expectedByFoldedPath.entries) {
      final expected = entry.value;
      final actual = actualByFoldedPath[entry.key]!.readAsStringSync();
      if (actual != expected.$2) {
        throw _ChunkV2SaveAbort(
          code: 'chunk_v2_save_post_validation_failed',
          message: 'Installed bytes differ for ${expected.$1}.',
        );
      }
      try {
        ChunkV2FileCodec.decode(actual, sourcePath: expected.$1);
      } on Object catch (error) {
        throw _ChunkV2SaveAbort(
          code: 'chunk_v2_save_post_validation_failed',
          message: 'Installed source is not strict chunk v2 at ${expected.$1}.',
          cause: error,
        );
      }
    }
  }

  void _ensureNoCaseInsensitivePathCollision(List<ChunkFileWrite> writes) {
    final seen = <String, ChunkFileWrite>{};
    for (final write in writes) {
      final lowerPath = write.relativePath.toLowerCase();
      final existing = seen[lowerPath];
      if (existing == null) {
        seen[lowerPath] = write;
        continue;
      }
      throw StateError(
        'Case-insensitive filename collision: '
        '${existing.relativePath} (${existing.chunkKey}) vs '
        '${write.relativePath} (${write.chunkKey}).',
      );
    }
  }
}

bool _savePlansEqual(ChunkSavePlan left, ChunkSavePlan right) {
  if (left.changedChunkKeys.length != right.changedChunkKeys.length ||
      left.writes.length != right.writes.length) {
    return false;
  }
  for (var index = 0; index < left.changedChunkKeys.length; index += 1) {
    if (left.changedChunkKeys[index] != right.changedChunkKeys[index]) {
      return false;
    }
  }
  for (var index = 0; index < left.writes.length; index += 1) {
    final a = left.writes[index];
    final b = right.writes[index];
    if (a.chunkKey != b.chunkKey ||
        a.chunkId != b.chunkId ||
        a.relativePath != b.relativePath ||
        a.previousRelativePath != b.previousRelativePath ||
        a.beforeContent != b.beforeContent ||
        a.afterContent != b.afterContent ||
        a.deleteFile != b.deleteFile) {
      return false;
    }
  }
  return true;
}

final class _ChunkV2SaveAbort implements Exception {
  const _ChunkV2SaveAbort({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => '$code: $message';
}

class ChunkSavePlan {
  const ChunkSavePlan({required this.writes, required this.changedChunkKeys});

  final List<ChunkFileWrite> writes;
  final List<String> changedChunkKeys;

  bool get hasChanges => writes.isNotEmpty;
}

class ChunkFileWrite {
  const ChunkFileWrite({
    required this.chunkKey,
    required this.chunkId,
    required this.relativePath,
    this.previousRelativePath,
    required this.beforeContent,
    required this.afterContent,
    this.deleteFile = false,
  });

  final String chunkKey;
  final String chunkId;
  final String relativePath;
  final String? previousRelativePath;
  final String? beforeContent;
  final String afterContent;
  final bool deleteFile;
}

int _compareChunkV2ForMemory(ChunkV2FileData a, ChunkV2FileData b) {
  final levelCompare = a.levelId.compareTo(b.levelId);
  if (levelCompare != 0) return levelCompare;
  final idCompare = a.id.compareTo(b.id);
  return idCompare != 0 ? idCompare : a.chunkKey.compareTo(b.chunkKey);
}

String _portableRelativePath(String path) =>
    p.normalize(path).replaceAll('\\', '/');

String _slugify(String raw) {
  final lower = raw.toLowerCase().trim();
  if (lower.isEmpty) {
    return 'chunk';
  }
  final slug = lower.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  if (slug.isEmpty) {
    return 'chunk';
  }
  return slug;
}
