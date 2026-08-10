import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/level_context_resolver.dart' as level_context;
import '../workspace/repository_authoring_paths.dart';
import '../workspace/workspace_file_io.dart';
import '../workspace/workspace_write_transaction.dart';
import 'chunk_domain_models.dart';
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
        chunkSchemaVersion => ChunkSourceGeneration.legacyV1,
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

  Future<ChunkDocument> load(
    EditorWorkspace workspace, {
    String? preferredActiveLevelId,
  }) async {
    final loadIssues = <ValidationIssue>[];
    final chunks = <LevelChunkDef>[];
    final baselineByChunkKey = <String, ChunkSourceBaseline>{};
    final runtimeAuthority = _loadRuntimeAuthority(workspace);

    final chunkFiles = _listChunkFiles(workspace);
    final discoveredLevelIds = <String>{};
    for (final file in chunkFiles) {
      final relativePath = WorkspaceFileIo.toWorkspaceRelativePath(
        workspace,
        file.path,
      );
      String raw;
      try {
        raw = await file.readAsString();
      } on Object catch (error) {
        loadIssues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'chunk_read_failed',
            message: 'Failed to read chunk file: $error',
            sourcePath: relativePath,
          ),
        );
        continue;
      }

      final map = _parseJsonMap(raw);
      if (map == null) {
        loadIssues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'chunk_invalid_json',
            message: 'Chunk file is not a valid JSON object.',
            sourcePath: relativePath,
          ),
        );
        continue;
      }

      final migratedMap = _migrateChunkJson(map);
      loadIssues.addAll(
        _collectRawShapeIssues(migratedMap, sourcePath: relativePath),
      );
      var chunk = LevelChunkDef.fromJson(migratedMap);
      if (chunk.chunkKey.isEmpty) {
        chunk = chunk.copyWith(
          chunkKey: p.basenameWithoutExtension(relativePath).trim(),
        );
      }
      final normalizedChunk = normalizeChunkToAuthority(
        chunk.normalized(),
        runtimeChunkWidth: runtimeAuthority.chunkWidth,
        lockedChunkHeight: runtimeAuthority.lockedChunkHeight,
        runtimeGroundTopY: runtimeAuthority.groundTopY,
      );
      chunk = normalizedChunk;
      chunks.add(chunk);
      discoveredLevelIds.add(chunk.levelId);

      if (baselineByChunkKey.containsKey(chunk.chunkKey)) {
        loadIssues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_chunk_key_in_files',
            message: 'Duplicate chunkKey in source files: ${chunk.chunkKey}',
            sourcePath: relativePath,
          ),
        );
        continue;
      }

      baselineByChunkKey[chunk.chunkKey] = ChunkSourceBaseline(
        levelId: chunk.levelId,
        sourcePath: relativePath,
        fingerprint: WorkspaceFileIo.fingerprint(raw),
      );
    }

    final levelOptions = level_context.resolveLevelOptions(
      workspace,
      discoveredLevelIds: discoveredLevelIds,
    );
    final assemblyGroupOptionsByLevelId = _resolveAssemblyGroupOptions(
      workspace,
      levelIds: levelOptions.options,
    );
    final activeLevelId = level_context.resolveActiveLevelId(
      options: levelOptions.options,
      preferredLevelId: preferredActiveLevelId,
    );
    final sortedChunks = List<LevelChunkDef>.from(chunks)
      ..sort(_compareChunksForMemory);
    final sortedLevelIds = List<String>.from(levelOptions.options)..sort();

    return ChunkDocument(
      chunks: sortedChunks,
      baselineByChunkKey: Map<String, ChunkSourceBaseline>.unmodifiable(
        baselineByChunkKey,
      ),
      availableLevelIds: List<String>.unmodifiable(sortedLevelIds),
      assemblyGroupOptionsByLevelId: Map<String, List<String>>.unmodifiable(
        assemblyGroupOptionsByLevelId.map(
          (levelId, groupIds) =>
              MapEntry(levelId, List<String>.unmodifiable(groupIds)),
        ),
      ),
      activeLevelId: activeLevelId,
      levelOptionSource: levelOptions.source,
      runtimeGridSnap: runtimeAuthority.gridSnap,
      runtimeChunkWidth: runtimeAuthority.chunkWidth,
      lockedChunkHeight: runtimeAuthority.lockedChunkHeight,
      runtimeGroundTopY: runtimeAuthority.groundTopY,
      loadIssues: List<ValidationIssue>.unmodifiable(loadIssues),
    );
  }

  ChunkSavePlan buildSavePlan(
    EditorWorkspace workspace, {
    required ChunkDocument document,
  }) {
    final encoder = const JsonEncoder.withIndent('  ');
    final normalizedChunks = document.chunks.map((chunk) => chunk.normalized());
    final sortedChunks = normalizedChunks.toList(growable: false)
      ..sort(_compareChunksForMemory);
    final currentChunkKeys = sortedChunks
        .map((chunk) => chunk.chunkKey)
        .toSet();

    final writes = <ChunkFileWrite>[];
    final claimedPathsLower = <String>{};
    for (final chunk in sortedChunks) {
      final baseline = document.baselineByChunkKey[chunk.chunkKey];
      final plannedPath = _resolveTargetChunkPath(chunk, baseline: baseline);
      final relativePath = plannedPath.targetPath;
      final previousRelativePath = plannedPath.previousPath;
      final file = File(workspace.resolve(relativePath));
      final beforeContent = file.existsSync() ? file.readAsStringSync() : null;
      final afterContent = '${encoder.convert(chunk.toJson())}\n';

      if (beforeContent == afterContent && previousRelativePath == null) {
        continue;
      }

      writes.add(
        ChunkFileWrite(
          chunkKey: chunk.chunkKey,
          chunkId: chunk.id,
          relativePath: p.normalize(relativePath),
          previousRelativePath: previousRelativePath,
          beforeContent: beforeContent,
          afterContent: afterContent,
        ),
      );
      claimedPathsLower.add(p.normalize(relativePath).toLowerCase());
      if (previousRelativePath != null) {
        claimedPathsLower.add(p.normalize(previousRelativePath).toLowerCase());
      }
    }

    for (final entry in document.baselineByChunkKey.entries) {
      final chunkKey = entry.key;
      if (currentChunkKeys.contains(chunkKey)) {
        continue;
      }
      final baselinePath = p.normalize(entry.value.sourcePath);
      if (claimedPathsLower.contains(baselinePath.toLowerCase())) {
        continue;
      }
      final file = File(workspace.resolve(baselinePath));
      if (!file.existsSync()) {
        continue;
      }
      writes.add(
        ChunkFileWrite(
          chunkKey: chunkKey,
          chunkId: chunkKey,
          relativePath: baselinePath,
          beforeContent: file.readAsStringSync(),
          afterContent: '',
          deleteFile: true,
        ),
      );
      claimedPathsLower.add(baselinePath.toLowerCase());
    }

    _ensureNoCaseInsensitivePathCollision(writes);

    return ChunkSavePlan(
      writes: List<ChunkFileWrite>.unmodifiable(writes),
      changedChunkKeys: List<String>.unmodifiable(
        writes.map((write) => write.chunkKey).toList(growable: false),
      ),
    );
  }

  /// Builds a deterministic, read-only save plan for a staged chunk-v2 tree.
  ///
  /// This method performs no filesystem reads or writes. Existing owner bytes
  /// come exclusively from strict load baselines; new owners must be declared
  /// explicitly; deleted owners retain their baseline long enough to describe
  /// removal. Enabling writes remains a separate Phase 4 cutover gate.
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

  Future<void> save(
    EditorWorkspace workspace, {
    required ChunkDocument document,
    required ChunkSavePlan savePlan,
  }) async {
    if (savePlan.writes.isEmpty) {
      return;
    }

    _verifyNoSourceDrift(
      workspace,
      document: document,
      writes: savePlan.writes,
    );

    for (final write in savePlan.writes) {
      final targetFile = File(workspace.resolve(write.relativePath));
      if (write.deleteFile) {
        if (targetFile.existsSync()) {
          targetFile.deleteSync();
        }
        continue;
      }
      WorkspaceFileIo.atomicWrite(targetFile, write.afterContent);
      final previousRelativePath = write.previousRelativePath;
      if (previousRelativePath == null) {
        continue;
      }
      if (p.equals(previousRelativePath, write.relativePath)) {
        continue;
      }
      final previousFile = File(workspace.resolve(previousRelativePath));
      if (previousFile.existsSync()) {
        previousFile.deleteSync();
      }
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

  Map<String, List<String>> _resolveAssemblyGroupOptions(
    EditorWorkspace workspace, {
    required Iterable<String> levelIds,
  }) {
    final fromLevelDefs = level_context.extractLevelChunkThemeGroups(workspace);
    final resolved = <String, List<String>>{};
    final uniqueLevelIds = <String>{
      ...levelIds,
      ...fromLevelDefs.keys,
    }.toList(growable: false)..sort();
    for (final levelId in uniqueLevelIds) {
      final declaredGroups = fromLevelDefs[levelId];
      if (declaredGroups == null || declaredGroups.isEmpty) {
        resolved[levelId] = const <String>[defaultChunkAssemblyGroupId];
      } else {
        resolved[levelId] = declaredGroups;
      }
    }
    return resolved;
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

  Map<String, Object?> _migrateChunkJson(Map<String, Object?> raw) {
    // Migration hook scaffold for future schema upgrades.
    return raw;
  }

  List<ValidationIssue> _collectRawShapeIssues(
    Map<String, Object?> raw, {
    required String sourcePath,
  }) {
    final issues = <ValidationIssue>[];
    void add(String code, String message) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: code,
          message: message,
          sourcePath: sourcePath,
        ),
      );
    }

    final schemaVersion = raw['schemaVersion'];
    if (schemaVersion is! int || schemaVersion <= 0) {
      add(
        'invalid_schema_version',
        'schemaVersion must be a positive integer in source JSON.',
      );
    }

    final chunkKey = raw['chunkKey'];
    if (chunkKey is! String || chunkKey.trim().isEmpty) {
      add('missing_chunk_key', 'chunkKey must be a non-empty string.');
    } else if (!RegExp(r'^[a-z0-9_]+$').hasMatch(chunkKey.trim())) {
      add(
        'malformed_chunk_key',
        'chunkKey must contain only lowercase letters, digits, and underscore.',
      );
    }

    final revision = raw['revision'];
    if (revision is! int || revision <= 0) {
      add(
        'invalid_revision',
        'revision must be a positive integer in source JSON.',
      );
    }

    final assemblyGroupId = raw['assemblyGroupId'];
    if (assemblyGroupId != null) {
      if (assemblyGroupId is! String || assemblyGroupId.trim().isEmpty) {
        add(
          'invalid_assembly_group_id',
          'assemblyGroupId must be a non-empty string when present.',
        );
      } else if (!stableChunkAssemblyGroupPattern.hasMatch(
        assemblyGroupId.trim(),
      )) {
        add(
          'invalid_assembly_group_id',
          'assemblyGroupId must match '
              '${stableChunkAssemblyGroupPattern.pattern}.',
        );
      }
    }

    _validateStringArray(
      raw['tags'],
      fieldName: 'tags',
      sourcePath: sourcePath,
      issues: issues,
    );

    _validateObjectArray(
      raw['tileLayers'],
      fieldName: 'tileLayers',
      arrayCode: 'malformed_tile_layers_array',
      entryCode: 'malformed_tile_layers_entry',
      sourcePath: sourcePath,
      issues: issues,
    );
    _validateObjectArray(
      raw['prefabs'],
      fieldName: 'prefabs',
      arrayCode: 'malformed_prefabs_array',
      entryCode: 'malformed_prefabs_entry',
      sourcePath: sourcePath,
      issues: issues,
    );
    _validateObjectArray(
      raw['markers'],
      fieldName: 'markers',
      arrayCode: 'malformed_markers_array',
      entryCode: 'malformed_markers_entry',
      sourcePath: sourcePath,
      issues: issues,
    );

    final groundProfile = raw['groundProfile'];
    if (groundProfile is! Map<String, Object?>) {
      add(
        'invalid_ground_profile',
        'groundProfile must be an object in source JSON.',
      );
    } else {
      final kind = groundProfile['kind'];
      if (kind is! String || kind.trim().isEmpty) {
        add(
          'invalid_ground_profile_kind',
          'groundProfile.kind must be a non-empty string.',
        );
      }
      final topY = groundProfile['topY'];
      if (topY is! int) {
        add(
          'invalid_ground_profile_top_y',
          'groundProfile.topY must be an integer.',
        );
      }
    }

    final groundBandZIndex = raw['groundBandZIndex'];
    if (groundBandZIndex != null && groundBandZIndex is! int) {
      add(
        'invalid_ground_band_z_index',
        'groundBandZIndex must be an integer when present.',
      );
    }

    final groundGaps = raw['groundGaps'];
    if (groundGaps is! List<Object?>) {
      add(
        'malformed_ground_gaps_entries',
        'groundGaps must be an array in source JSON.',
      );
      return issues;
    }
    for (var i = 0; i < groundGaps.length; i += 1) {
      final entry = groundGaps[i];
      if (entry is! Map<String, Object?>) {
        add(
          'malformed_ground_gaps_entries',
          'groundGaps[$i] must be an object.',
        );
        continue;
      }
      if (entry['gapId'] is! String ||
          (entry['gapId'] as String).trim().isEmpty) {
        add(
          'missing_gap_id',
          'groundGaps[$i].gapId must be a non-empty string.',
        );
      }
      if (entry['type'] is! String ||
          (entry['type'] as String).trim().isEmpty) {
        add(
          'invalid_gap_type',
          'groundGaps[$i].type must be a non-empty string.',
        );
      }
      if (entry['x'] is! int) {
        add('invalid_gap_x', 'groundGaps[$i].x must be an integer.');
      }
      if (entry['width'] is! int) {
        add('invalid_gap_width', 'groundGaps[$i].width must be an integer.');
      }
    }

    return issues;
  }

  _RuntimeTrackAuthority _loadRuntimeAuthority(EditorWorkspace workspace) {
    final tuningFile = File(workspace.resolve(trackTuningSourcePath));
    final spatialContractFile = File(
      workspace.resolve(spatialContractSourcePath),
    );
    final levelWorldConstantsFile = File(
      workspace.resolve(levelWorldConstantsSourcePath),
    );
    final tuningSource = tuningFile.existsSync()
        ? tuningFile.readAsStringSync()
        : '';
    final spatialContractSource = spatialContractFile.existsSync()
        ? spatialContractFile.readAsStringSync()
        : '';
    final levelWorldSource = levelWorldConstantsFile.existsSync()
        ? levelWorldConstantsFile.readAsStringSync()
        : '';

    final chunkWidth = _extractDoubleDefault(
      tuningSource,
      pattern: RegExp(r'this\.chunkWidth\s*=\s*([0-9]+(?:\.[0-9]+)?)'),
      fallback: 600.0,
    );
    final gridSnap = _extractDoubleDefault(
      tuningSource,
      pattern: RegExp(r'this\.gridSnap\s*=\s*([0-9]+(?:\.[0-9]+)?)'),
      fallback: 16.0,
    );
    final groundTopY = _extractIntDefault(
      levelWorldSource,
      pattern: RegExp(
        r'const\s+int\s+defaultLevelGroundTopYInt\s*=\s*([0-9]+)',
      ),
      fallback: defaultRuntimeGroundTopY,
    );
    final viewportHeight = _extractIntDefault(
      spatialContractSource,
      pattern: RegExp(r'const\s+int\s+virtualViewportHeight\s*=\s*([0-9]+)'),
      fallback: defaultLockedChunkHeight,
    );
    return _RuntimeTrackAuthority(
      chunkWidth: chunkWidth,
      gridSnap: gridSnap,
      lockedChunkHeight: lockedChunkHeightForViewportHeight(viewportHeight),
      groundTopY: groundTopY,
    );
  }

  double _extractDoubleDefault(
    String source, {
    required RegExp pattern,
    required double fallback,
  }) {
    final match = pattern.firstMatch(source);
    if (match == null) {
      return fallback;
    }
    final raw = match.group(1);
    if (raw == null) {
      return fallback;
    }
    return double.tryParse(raw) ?? fallback;
  }

  int _extractIntDefault(
    String source, {
    required RegExp pattern,
    required int fallback,
  }) {
    final match = pattern.firstMatch(source);
    if (match == null) {
      return fallback;
    }
    final raw = match.group(1);
    if (raw == null) {
      return fallback;
    }
    return int.tryParse(raw) ?? fallback;
  }

  /// Deterministic filename policy:
  /// - Canonical path is `<chunks>/<slug(levelId)>/<slug(id)>.json`.
  /// - Editor-managed legacy paths are migrated to canonical on save.
  /// - Custom/manual source paths are preserved.
  _PlannedChunkPath _resolveTargetChunkPath(
    LevelChunkDef chunk, {
    required ChunkSourceBaseline? baseline,
  }) {
    final canonicalPath = _canonicalChunkPath(chunk);
    if (baseline == null) {
      return _PlannedChunkPath(targetPath: canonicalPath);
    }
    final baselinePath = p.normalize(baseline.sourcePath);
    if (!_isEditorManagedChunkPath(baselinePath)) {
      return _PlannedChunkPath(targetPath: baselinePath);
    }
    if (p.equals(baselinePath, canonicalPath)) {
      return _PlannedChunkPath(targetPath: baselinePath);
    }
    return _PlannedChunkPath(
      targetPath: canonicalPath,
      previousPath: baselinePath,
    );
  }

  String _canonicalChunkPath(LevelChunkDef chunk) {
    final levelDirectory = _slugify(chunk.levelId);
    final fileName = '${_slugify(chunk.id)}.json';
    return p.normalize(p.join(chunksDirectoryPath, levelDirectory, fileName));
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

  void _verifyNoSourceDrift(
    EditorWorkspace workspace, {
    required ChunkDocument document,
    required List<ChunkFileWrite> writes,
  }) {
    for (final write in writes) {
      final baseline = document.baselineByChunkKey[write.chunkKey];
      if (baseline == null) {
        continue;
      }
      final baselineFile = File(workspace.resolve(baseline.sourcePath));
      if (!baselineFile.existsSync()) {
        throw StateError(
          'Source drift detected for ${write.chunkKey}: '
          '${baseline.sourcePath} no longer exists. Reload before export.',
        );
      }
      final currentFingerprint = WorkspaceFileIo.fingerprint(
        baselineFile.readAsStringSync(),
      );
      if (currentFingerprint != baseline.fingerprint) {
        throw StateError(
          'Source drift detected for ${write.chunkKey} at ${baseline.sourcePath}. '
          'Reload before export.',
        );
      }
    }
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

class _PlannedChunkPath {
  const _PlannedChunkPath({required this.targetPath, this.previousPath});

  final String targetPath;
  final String? previousPath;
}

class _RuntimeTrackAuthority {
  const _RuntimeTrackAuthority({
    required this.chunkWidth,
    required this.gridSnap,
    required this.lockedChunkHeight,
    required this.groundTopY,
  });

  final double chunkWidth;
  final double gridSnap;
  final int lockedChunkHeight;
  final int groundTopY;
}

int _compareChunksForMemory(LevelChunkDef a, LevelChunkDef b) {
  final levelCompare = a.levelId.compareTo(b.levelId);
  if (levelCompare != 0) {
    return levelCompare;
  }
  final idCompare = a.id.compareTo(b.id);
  if (idCompare != 0) {
    return idCompare;
  }
  return a.chunkKey.compareTo(b.chunkKey);
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

void _validateObjectArray(
  Object? raw, {
  required String fieldName,
  required String arrayCode,
  required String entryCode,
  required String sourcePath,
  required List<ValidationIssue> issues,
}) {
  if (raw is! List<Object?>) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: arrayCode,
        message: '$fieldName must be an array in source JSON.',
        sourcePath: sourcePath,
      ),
    );
    return;
  }
  for (var i = 0; i < raw.length; i += 1) {
    if (raw[i] is Map<String, Object?>) {
      continue;
    }
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: entryCode,
        message: '$fieldName[$i] must be an object in source JSON.',
        sourcePath: sourcePath,
      ),
    );
  }
}

void _validateStringArray(
  Object? raw, {
  required String fieldName,
  required String sourcePath,
  required List<ValidationIssue> issues,
}) {
  if (raw is! List<Object?>) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'malformed_${_codeKeyForField(fieldName)}_array',
        message: '$fieldName must be an array of strings in source JSON.',
        sourcePath: sourcePath,
      ),
    );
    return;
  }
  for (var i = 0; i < raw.length; i += 1) {
    if (raw[i] is String) {
      continue;
    }
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'malformed_${_codeKeyForField(fieldName)}_entry',
        message: '$fieldName[$i] must be a string in source JSON.',
        sourcePath: sourcePath,
      ),
    );
  }
}

String _codeKeyForField(String fieldName) {
  return fieldName.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
  );
}
