import 'dart:io';
import 'dart:ui' show Size;

import 'package:path/path.dart' as p;

import '../../chunks/chunk_store.dart';
import '../../chunks/chunk_v2_collision_expansion.dart';
import '../../domain/authoring_types.dart';
import '../../terrain_authoring/polygon_authoring_migration_required.dart';
import '../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../workspace/editor_workspace.dart';
import '../../workspace/repository_png_catalog.dart';
import '../models/models.dart';
import 'prefab_domain_models.dart';
import 'prefab_visual_bounds_resolver.dart';
import 'prefab_v3_collision_commit.dart';
import 'prefab_v3_catalog_commit.dart';
import 'prefab_v3_catalog_validation.dart';
import 'prefab_v3_lifecycle_commit.dart';
import 'prefab_v3_metadata_commit.dart';
import '../store/prefab_store.dart';
import '../validation/prefab_validation.dart';

/// Returns only collision errors introduced into captured current Chunk source
/// by [candidateData]. Existing baseline errors are consumed as a multiset so
/// an unchanged invalid Chunk is not misattributed to the Prefab edit.
List<ValidationIssue> introducedPrefabV3DownstreamCollisionErrors({
  required PrefabV3Document original,
  required PrefabV3FileData candidateData,
}) {
  final introduced = <ValidationIssue>[];
  for (var index = 0; index < original.downstreamChunks.length; index += 1) {
    final source = original.downstreamChunks[index];
    final before = expandChunkV2Collision(
      chunk: source.data,
      prefabs: original.data.prefabs,
      sourcePath: source.sourcePath,
      chunkIndex: index,
    );
    final after = expandChunkV2Collision(
      chunk: source.data,
      prefabs: candidateData.prefabs,
      sourcePath: source.sourcePath,
      chunkIndex: index,
    );
    final existingErrors = <String, int>{};
    for (final issue in before.issues.where(
      (issue) => issue.severity == ValidationSeverity.error,
    )) {
      final identity = _downstreamIssueIdentity(issue);
      existingErrors.update(identity, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final issue in after.issues.where(
      (issue) => issue.severity == ValidationSeverity.error,
    )) {
      final identity = _downstreamIssueIdentity(issue);
      final priorCount = existingErrors[identity] ?? 0;
      if (priorCount == 0) {
        introduced.add(issue);
      } else {
        existingErrors[identity] = priorCount - 1;
      }
    }
  }
  return List<ValidationIssue>.unmodifiable(introduced);
}

/// Prefab-domain `AuthoringDomainPlugin` implementation.
///
/// Owns repository load/validate/export orchestration and keeps UI routes free
/// of direct file I/O concerns.

/// Plugin entry point for prefab/tile authoring workflows.
///
/// The plugin owns repo load/validate/export orchestration, while canonical
/// ordering and migration logic stay in [PrefabStore].
class PrefabDomainPlugin implements AuthoringDomainPlugin {
  const PrefabDomainPlugin({PrefabStore store = const PrefabStore()})
    : _store = store;

  static const String pluginId = 'prefabs';

  /// Current command for one accepted shared polygon interaction commit.
  static const String commitPrefabPolygonCommandKind = 'commit_prefab_polygon';

  /// Current command for one existing-owner prefab-v3 metadata commit.
  static const String commitPrefabV3MetadataCommandKind =
      'commit_prefab_v3_metadata';

  /// Current command for one prefab-v3 create/duplicate/rename/delete commit.
  static const String commitPrefabV3LifecycleCommandKind =
      'commit_prefab_v3_lifecycle';

  /// Current command for one prefab-v3 slice or retained-module mutation.
  static const String commitPrefabV3CatalogCommandKind =
      'commit_prefab_v3_catalog';

  /// Workspace-relative root scanned for atlas images used by slices.
  static const String _levelAssetsPath = 'assets/images/level';

  static const RepositoryPngCatalog _pngCatalog = RepositoryPngCatalog();

  /// Widget tests run load under fake async where some async file I/O can
  /// stall; keep a deterministic sync fallback for that environment only.
  static final bool _isFlutterTestProcess = Platform.environment.containsKey(
    'FLUTTER_TEST',
  );

  final PrefabStore _store;

  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return switch (_store.detectSourceGeneration(workspace.rootPath)) {
      PrefabSourceGeneration.currentV3 => loadV3FromRepo(workspace),
      PrefabSourceGeneration.legacyV2 =>
        const PolygonAuthoringMigrationRequiredDocument(
          domain: PolygonAuthoringMigrationDomain.prefabs,
          reason: PolygonAuthoringMigrationReason.legacySource,
        ),
      PrefabSourceGeneration.missing =>
        const PolygonAuthoringMigrationRequiredDocument(
          domain: PolygonAuthoringMigrationDomain.prefabs,
          reason: PolygonAuthoringMigrationReason.sourceMissing,
        ),
    };
  }

  /// Strict prefab-v3 load shared by normal selection and owner navigation.
  ///
  /// This method requires strict v3/tile-v2 source. Normal legacy/missing
  /// source resolves to the migration-required document; no migration write is
  /// performed here.
  Future<PrefabV3Document> loadV3FromRepo(EditorWorkspace workspace) async {
    final loadResult = await _store.loadV3(workspace.rootPath);
    final metadata = await _loadWorkspaceMetadata(workspace);
    final downstream = await _loadV3DownstreamMetadata(
      workspace,
      loadResult.prefabData,
    );
    return PrefabV3Document(
      data: loadResult.prefabData,
      tileData: loadResult.tileData,
      visualBoundsByPrefabKey: PrefabVisualBoundsResolver.resolveAll(
        prefabData: loadResult.prefabData,
        tileData: loadResult.tileData,
      ),
      atlasImagePaths: metadata.atlasImagePaths,
      atlasImageSizes: metadata.atlasImageSizes,
      prefabBaselineContents: metadata.prefabBaselineContents,
      tileBaselineContents: metadata.tileBaselineContents,
      downstreamImpacts: downstream.impacts,
      downstreamChunks: downstream.chunks,
    );
  }

  Future<_PrefabDownstreamMetadata> _loadV3DownstreamMetadata(
    EditorWorkspace workspace,
    PrefabV3FileData prefabData,
  ) async {
    final placementChunksByPrefabKey = <String, List<String>>{
      for (final prefab in prefabData.prefabs) prefab.prefabKey: <String>[],
    };
    final placementCountByPrefabKey = <String, int>{
      for (final prefab in prefabData.prefabs) prefab.prefabKey: 0,
    };
    final chunkDirectory = Directory(
      workspace.resolve(ChunkStore.chunksDirectoryPath),
    );
    var chunkSources = const <ChunkV2Source>[];
    if (chunkDirectory.existsSync()) {
      final chunks = await const ChunkStore().loadV2(workspace);
      chunkSources = chunks.sources;
      final prefabKeyById = <String, String>{
        for (final prefab in prefabData.prefabs) prefab.id: prefab.prefabKey,
      };
      for (final source in chunks.sources) {
        for (final placement in source.data.prefabs) {
          final prefabKey = placement.prefabKey.isNotEmpty
              ? placement.prefabKey
              : prefabKeyById[placement.prefabId];
          if (prefabKey == null ||
              !placementCountByPrefabKey.containsKey(prefabKey)) {
            continue;
          }
          placementCountByPrefabKey[prefabKey] =
              placementCountByPrefabKey[prefabKey]! + 1;
          placementChunksByPrefabKey[prefabKey]!.add(source.data.chunkKey);
        }
      }
    }
    return _PrefabDownstreamMetadata(
      impacts: <PrefabV3DownstreamImpact>[
        for (final prefab in prefabData.prefabs)
          PrefabV3DownstreamImpact(
            prefabKey: prefab.prefabKey,
            referencingChunkKeys: placementChunksByPrefabKey[prefab.prefabKey]!,
            placementCount: placementCountByPrefabKey[prefab.prefabKey]!,
          ),
      ],
      chunks: <PrefabV3DownstreamChunk>[
        for (final entry in chunkSources.indexed)
          PrefabV3DownstreamChunk(
            data: entry.$2.data,
            sourcePath: entry.$2.sourcePath,
            baselineContents: entry.$2.baselineContents,
            baselineCollisionErrorIdentities:
                expandChunkV2Collision(
                      chunk: entry.$2.data,
                      prefabs: prefabData.prefabs,
                      sourcePath: entry.$2.sourcePath,
                      chunkIndex: entry.$1,
                    ).issues
                    .where(
                      (issue) => issue.severity == ValidationSeverity.error,
                    )
                    .map(_downstreamIssueIdentity),
          ),
      ],
    );
  }

  Future<_PrefabWorkspaceMetadata> _loadWorkspaceMetadata(
    EditorWorkspace workspace,
  ) async {
    final prefabRelativePath = p.normalize(PrefabStore.prefabDefsPath);
    final tileRelativePath = p.normalize(PrefabStore.tileDefsPath);
    late final String? prefabBaselineContents;
    late final String? tileBaselineContents;
    late final List<String> atlasImagePaths;
    late final Map<String, Size> atlasImageSizes;

    if (_isFlutterTestProcess) {
      prefabBaselineContents = _readIfExistsSync(
        workspace.resolve(prefabRelativePath),
      );
      tileBaselineContents = _readIfExistsSync(
        workspace.resolve(tileRelativePath),
      );
      final images = _pngCatalog.discoverSync(
        workspace,
        roots: const <String>[_levelAssetsPath],
      );
      atlasImagePaths = _pathsFromImages(images);
      atlasImageSizes = _sizesFromImages(images);
    } else {
      prefabBaselineContents = await _readIfExistsAsync(
        workspace.resolve(prefabRelativePath),
      );
      tileBaselineContents = await _readIfExistsAsync(
        workspace.resolve(tileRelativePath),
      );
      final images = await _pngCatalog.discover(
        workspace,
        roots: const <String>[_levelAssetsPath],
      );
      atlasImagePaths = _pathsFromImages(images);
      atlasImageSizes = _sizesFromImages(images);
    }

    return _PrefabWorkspaceMetadata(
      atlasImagePaths: atlasImagePaths,
      atlasImageSizes: atlasImageSizes,
      prefabBaselineContents: prefabBaselineContents,
      tileBaselineContents: tileBaselineContents,
    );
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    if (document is PolygonAuthoringMigrationRequiredDocument) {
      return <ValidationIssue>[
        _requirePrefabMigration(document).toValidationIssue(),
      ];
    }
    if (document is PrefabV3Document) {
      return _validateV3Document(document);
    }
    throw _unexpectedDocument(document);
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    if (document is PolygonAuthoringMigrationRequiredDocument) {
      return _requirePrefabMigration(document).toScene();
    }
    if (document is PrefabV3Document) {
      return PrefabV3Scene(
        data: document.data,
        tileData: document.tileData,
        visualBoundsByPrefabKey: document.visualBoundsByPrefabKey,
        atlasImagePaths: document.atlasImagePaths,
        atlasImageSizes: document.atlasImageSizes,
        downstreamImpacts: document.downstreamImpacts,
      );
    }
    throw _unexpectedDocument(document);
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    if (document is PolygonAuthoringMigrationRequiredDocument) {
      _requirePrefabMigration(document);
      return document;
    }
    if (document is PrefabV3Document) {
      return _applyV3Edit(document, command);
    }
    throw _unexpectedDocument(document);
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    if (document is PolygonAuthoringMigrationRequiredDocument) {
      final migration = _requirePrefabMigration(document);
      throw StateError(
        'polygon_authoring_migration_required: ${migration.message}',
      );
    }
    if (document is! PrefabV3Document) throw _unexpectedDocument(document);
    await _ensureDownstreamSourcesCurrent(workspace, document);
    final blockingIssues = _validateV3Document(document)
        .where((issue) => issue.severity == ValidationSeverity.error)
        .toList();
    if (blockingIssues.isNotEmpty) {
      throw StateError(
        'Cannot export prefab-v3 while validation has '
        '${blockingIssues.length} blocking issue(s).',
      );
    }
    final pending = describePendingChanges(workspace, document: document);
    if (!pending.hasChanges) {
      return ExportResult(
        applied: false,
        artifacts: <ExportArtifact>[
          const ExportArtifact(
            title: 'prefab_summary.md',
            content: '# Prefab Export\n\nchangedFiles: 0\n\nNo prefab-v3 edits detected.',
          ),
        ],
      );
    }
    final plan = _store.buildV3SavePlan(
      prefabData: document.data,
      tileData: document.tileData,
      prefabBaselineContents: document.prefabBaselineContents,
      tileBaselineContents: document.tileBaselineContents,
    );
    _store.applyV3SavePlan(workspace.rootPath, plan: plan);
    return ExportResult(
      applied: true,
      artifacts: <ExportArtifact>[
        ExportArtifact(
          title: 'prefab_summary.md',
          content: _buildSummary(pending.fileDiffs),
        ),
      ],
    );
  }

  @override
  /// Builds deterministic pending file diffs against load-time baselines.
  ///
  /// Baseline content comes from the current document instead of re-reading
  /// files, so this path avoids disk I/O during editor interactions.
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    if (document is PolygonAuthoringMigrationRequiredDocument) {
      _requirePrefabMigration(document);
      return PendingChanges.empty;
    }
    if (document is! PrefabV3Document) throw _unexpectedDocument(document);
    final plan = _store.buildV3SavePlan(
      prefabData: document.data,
      tileData: document.tileData,
      prefabBaselineContents: document.prefabBaselineContents,
      tileBaselineContents: document.tileBaselineContents,
    );
    final changed = plan.files
        .where((file) => file.hasChanges)
        .map(
          (file) => _PrefabFileWrite(
            relativePath: file.relativePath,
            beforeContent: file.beforeContents,
            afterContent: file.afterContents,
          ),
        )
        .toList(growable: false);
    if (changed.isEmpty) {
      return PendingChanges.empty;
    }
    return PendingChanges(
      changedItemIds: document.changedPrefabKeys,
      fileDiffs: changed
          .map(
            (write) => PendingFileDiff(
              relativePath: write.relativePath,
              editCount: _estimateEditCount(
                beforeContent: write.beforeContent,
                afterContent: write.afterContent,
              ),
              unifiedDiff: _buildUnifiedDiff(write),
            ),
          )
          .toList(growable: false),
    );
  }

  PolygonAuthoringMigrationRequiredDocument _requirePrefabMigration(
    PolygonAuthoringMigrationRequiredDocument document,
  ) {
    if (document.domain != PolygonAuthoringMigrationDomain.prefabs) {
      throw StateError(
        'PrefabDomainPlugin received migration state for '
        '${document.domain.pluginId}.',
      );
    }
    return document;
  }

  StateError _unexpectedDocument(AuthoringDocument document) => StateError(
    'PrefabDomainPlugin expected PrefabV3Document but got '
    '${document.runtimeType}.',
  );

  AuthoringDocument _applyV3Edit(
    PrefabV3Document document,
    AuthoringCommand command,
  ) {
    if (command.kind == commitPrefabV3MetadataCommandKind) {
      final prefabKey = command.payload['prefabKey'];
      final commit = command.payload['commit'];
      if (prefabKey is! String || commit is! PrefabV3MetadataCommit) {
        return document;
      }
      final result = const PrefabV3MetadataCommitPolicy().apply(
        document: document,
        prefabKey: prefabKey,
        commit: commit,
      );
      return result.accepted && result.changed
          ? _validatedV3CandidateOrOriginal(document, result.document)
          : document;
    }
    if (command.kind == commitPrefabV3LifecycleCommandKind) {
      final commit = command.payload['commit'];
      if (commit is! PrefabV3LifecycleCommit) return document;
      final result = const PrefabV3LifecycleCommitPolicy().apply(
        document: document,
        commit: commit,
      );
      return result.accepted && result.changed
          ? _validatedV3CandidateOrOriginal(document, result.document)
          : document;
    }
    if (command.kind == commitPrefabV3CatalogCommandKind) {
      final commit = command.payload['commit'];
      if (commit is! PrefabV3CatalogCommit) return document;
      final result = const PrefabV3CatalogCommitPolicy().apply(
        document: document,
        commit: commit,
      );
      return result.accepted && result.changed
          ? _validatedV3CandidateOrOriginal(document, result.document)
          : document;
    }
    if (command.kind != commitPrefabPolygonCommandKind) return document;
    final prefabKey = command.payload['prefabKey'];
    final commit = command.payload['commit'];
    if (prefabKey is! String || commit is! TerrainPolygonInteractionCommit) {
      return document;
    }
    final bounds = document.visualBoundsByPrefabKey[prefabKey];
    final result = const PrefabV3CollisionCommitPolicy().apply(
      data: document.data,
      prefabKey: prefabKey,
      commit: commit,
      sourceWidthPx: bounds?.widthPx,
      sourceHeightPx: bounds?.heightPx,
      sourcePath: PrefabStore.prefabDefsPath,
    );
    if (!result.accepted || !result.changed) return document;
    final candidate = document.copyWith(
      data: result.data,
      changedPrefabKeys: <String>{...document.changedPrefabKeys, prefabKey},
    );
    return _validatedV3CandidateOrOriginal(document, candidate);
  }

  PrefabV3Document _validatedV3CandidateOrOriginal(
    PrefabV3Document original,
    PrefabV3Document candidate,
  ) {
    final hasBlockingIssue = _validateV3Document(candidate)
        .any((issue) => issue.severity == ValidationSeverity.error);
    if (hasBlockingIssue) return original;
    if (introducedPrefabV3DownstreamCollisionErrors(
      original: original,
      candidateData: candidate.data,
    ).isNotEmpty) {
      return original;
    }
    try {
      _store.buildV3SavePlan(
        prefabData: candidate.data,
        tileData: candidate.tileData,
        prefabBaselineContents: candidate.prefabBaselineContents,
        tileBaselineContents: candidate.tileBaselineContents,
      );
    } on PrefabV3SaveException {
      return original;
    }
    return candidate;
  }

  Future<void> _ensureDownstreamSourcesCurrent(
    EditorWorkspace workspace,
    PrefabV3Document document,
  ) async {
    final affectedChunkKeys = document.downstreamImpacts
        .where(
          (impact) => document.changedPrefabKeys.contains(impact.prefabKey),
        )
        .expand((impact) => impact.referencingChunkKeys)
        .toSet();
    for (final entry in document.downstreamChunks.indexed.where(
      (entry) => affectedChunkKeys.contains(entry.$2.data.chunkKey),
    )) {
      final source = entry.$2;
      final file = File(workspace.resolve(source.sourcePath));
      if (!await file.exists() ||
          await file.readAsString() != source.baselineContents) {
        throw StateError(
          'Chunk ${source.data.chunkKey} changed after Prefab review. Reload '
          'before applying collision changes.',
        );
      }
      final result = expandChunkV2Collision(
        chunk: source.data,
        prefabs: document.data.prefabs,
        sourcePath: source.sourcePath,
        chunkIndex: entry.$1,
      );
      final baselineErrors = <String, int>{};
      for (final identity in source.baselineCollisionErrorIdentities) {
        baselineErrors.update(
          identity,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      for (final issue in result.issues.where(
        (issue) => issue.severity == ValidationSeverity.error,
      )) {
        final identity = _downstreamIssueIdentity(issue);
        final priorCount = baselineErrors[identity] ?? 0;
        if (priorCount > 0) {
          baselineErrors[identity] = priorCount - 1;
          continue;
        }
        throw StateError(
          'Prefab collision changes invalidate Chunk ${source.data.id}: '
          '${issue.message}',
        );
      }
    }
  }

  List<ValidationIssue> _validateV3Document(PrefabV3Document document) {
    final issues = validatePrefabV3CatalogDocument(document)
        .map(_toValidationIssue)
        .toList(growable: false);
    issues.sort((left, right) {
      final pathOrder = (left.sourcePath ?? '').compareTo(
        right.sourcePath ?? '',
      );
      if (pathOrder != 0) return pathOrder;
      final codeOrder = left.code.compareTo(right.code);
      return codeOrder != 0 ? codeOrder : left.message.compareTo(right.message);
    });
    return List<ValidationIssue>.unmodifiable(issues);
  }

  ValidationIssue _toValidationIssue(PrefabValidationIssue issue) =>
      ValidationIssue(
        severity: switch (issue.severity) {
          PrefabValidationSeverity.warning => ValidationSeverity.warning,
          PrefabValidationSeverity.error => ValidationSeverity.error,
        },
        code: issue.code,
        message: issue.message,
        sourcePath: issue.sourcePath,
        ownerKey: issue.ownerKey,
        shapeId: issue.shapeId.isEmpty ? null : issue.shapeId,
        elementIndex: issue.shapeId.isEmpty ? null : issue.elementIndex,
      );

  /// Reads a file when present and returns null for missing paths.
  Future<String?> _readIfExistsAsync(String absolutePath) async {
    final file = File(absolutePath);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  /// Test-only sync variant used when async file I/O stalls under fake async.
  String? _readIfExistsSync(String absolutePath) {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsStringSync();
  }

  /// Lightweight line-based edit estimate for UI summaries.
  ///
  /// This is intentionally approximate and not a patch-accurate hunk count.
  int _estimateEditCount({
    required String? beforeContent,
    required String afterContent,
  }) {
    final beforeLines = _splitLines(beforeContent ?? '');
    final afterLines = _splitLines(afterContent);
    final sharedLength = beforeLines.length < afterLines.length
        ? beforeLines.length
        : afterLines.length;

    var changedAtSharedIndices = 0;
    for (var i = 0; i < sharedLength; i += 1) {
      if (beforeLines[i] != afterLines[i]) {
        changedAtSharedIndices += 1;
      }
    }

    final insertedOrRemoved = (beforeLines.length - afterLines.length).abs();
    final estimated = changedAtSharedIndices + insertedOrRemoved;
    return estimated <= 0 ? 1 : estimated;
  }

  String _buildSummary(List<PendingFileDiff> fileDiffs) {
    final lines = <String>[
      '# Prefab Export',
      '',
      'changedFiles: ${fileDiffs.length}',
      '',
      '## Files',
      ...fileDiffs.map((diff) => '- ${diff.relativePath}'),
    ];
    return lines.join('\n');
  }

  String _buildUnifiedDiff(_PrefabFileWrite write) {
    final path = write.relativePath.replaceAll('\\', '/');
    final before = write.beforeContent ?? '';
    final after = write.afterContent;
    final beforeLines = _splitLines(before);
    final afterLines = _splitLines(after);
    final lines = <String>[
      'diff --git a/$path b/$path',
      '--- a/$path',
      '+++ b/$path',
      '@@ -1,${beforeLines.length} +1,${afterLines.length} @@',
      ...beforeLines.map((line) => '-$line'),
      ...afterLines.map((line) => '+$line'),
    ];
    return lines.join('\n');
  }

  /// Splits content into lines with normalized newlines and no trailing blank
  /// line artifact from terminal `\n`.
  List<String> _splitLines(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

  List<String> _pathsFromImages(List<RepositoryPngImage> images) => <String>[
    for (final image in images) image.relativePath,
  ];

  Map<String, Size> _sizesFromImages(List<RepositoryPngImage> images) =>
      <String, Size>{
        for (final image in images)
          if (image.hasValidDimensions)
            image.relativePath: Size(
              image.width!.toDouble(),
              image.height!.toDouble(),
            ),
      };
}

String _downstreamIssueIdentity(ValidationIssue issue) =>
    '${issue.code}|${issue.sourcePath}|${issue.ownerKey}|'
    '${issue.placementKey}|${issue.shapeId}|${issue.elementIndex}';

class _PrefabFileWrite {
  const _PrefabFileWrite({
    required this.relativePath,
    required this.beforeContent,
    required this.afterContent,
  });

  final String relativePath;
  final String? beforeContent;
  final String afterContent;
}

class _PrefabWorkspaceMetadata {
  _PrefabWorkspaceMetadata({
    required List<String> atlasImagePaths,
    required Map<String, Size> atlasImageSizes,
    required this.prefabBaselineContents,
    required this.tileBaselineContents,
  }) : atlasImagePaths = List<String>.unmodifiable(atlasImagePaths),
       atlasImageSizes = Map<String, Size>.unmodifiable(atlasImageSizes);

  final List<String> atlasImagePaths;
  final Map<String, Size> atlasImageSizes;
  final String? prefabBaselineContents;
  final String? tileBaselineContents;
}

class _PrefabDownstreamMetadata {
  _PrefabDownstreamMetadata({
    required Iterable<PrefabV3DownstreamImpact> impacts,
    required Iterable<PrefabV3DownstreamChunk> chunks,
  }) : impacts = List<PrefabV3DownstreamImpact>.unmodifiable(impacts),
       chunks = List<PrefabV3DownstreamChunk>.unmodifiable(chunks);

  final List<PrefabV3DownstreamImpact> impacts;
  final List<PrefabV3DownstreamChunk> chunks;
}
