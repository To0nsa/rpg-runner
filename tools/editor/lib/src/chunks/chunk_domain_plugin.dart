import '../domain/authoring_types.dart';
import '../levels/level_store.dart';
import '../prefabs/domain/prefab_visual_bounds_resolver.dart';
import '../prefabs/store/prefab_store.dart';
import '../terrain_authoring/terrain_polygon_interaction.dart';
import '../terrain_authoring/polygon_authoring_migration_required.dart';
import '../workspace/editor_workspace.dart';
import 'chunk_store.dart';
import 'chunk_v2_collision_expansion.dart';
import 'chunk_v2_collision_commit.dart';
import 'chunk_v2_composition_commit.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_lifecycle_commit.dart';
import 'chunk_v2_metadata_commit.dart';
import 'chunk_v2_seam_analysis.dart';
import 'chunk_v2_models.dart';
import 'chunk_v2_validation.dart';

class ChunkDomainPlugin implements AuthoringDomainPlugin {
  ChunkDomainPlugin({
    ChunkStore store = const ChunkStore(),
    PrefabStore prefabStore = const PrefabStore(),
    LevelStore levelStore = const LevelStore(),
  }) : _store = store,
       _prefabStore = prefabStore,
       _levelStore = levelStore;

  static const String pluginId = 'chunks';

  /// Current command for one accepted chunk-local polygon interaction commit.
  static const String commitChunkPolygonCommandKind = 'commit_chunk_polygon';

  /// Current command for one existing owner's typed metadata commit.
  static const String commitChunkMetadataCommandKind =
      'commit_chunk_v2_metadata';

  /// Current command for one existing owner's strict composition replacement.
  static const String commitChunkCompositionCommandKind =
      'commit_chunk_v2_composition';

  /// Current command for one stale-checked lifecycle operation.
  static const String commitChunkLifecycleCommandKind =
      'commit_chunk_v2_lifecycle';

  final ChunkStore _store;
  final PrefabStore _prefabStore;
  final LevelStore _levelStore;
  String? _preferredActiveLevelId;

  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return switch (_store.detectSourceGeneration(workspace)) {
      ChunkSourceGeneration.currentV2 => loadV2FromRepo(workspace),
      ChunkSourceGeneration.legacyV1 =>
        const PolygonAuthoringMigrationRequiredDocument(
          domain: PolygonAuthoringMigrationDomain.chunks,
          reason: PolygonAuthoringMigrationReason.legacySource,
        ),
      ChunkSourceGeneration.missing =>
        const PolygonAuthoringMigrationRequiredDocument(
          domain: PolygonAuthoringMigrationDomain.chunks,
          reason: PolygonAuthoringMigrationReason.sourceMissing,
        ),
    };
  }

  /// Strict all-v2 load shared by normal selection and owner navigation.
  ///
  /// This also requires strict prefab-v3/tile-v2 source so placement preview
  /// expands one coherent future-source generation. Normal legacy/missing
  /// source resolves to the migration-required document.
  Future<ChunkV2Document> loadV2FromRepo(EditorWorkspace workspace) async {
    final chunkLoad = await _store.loadV2(workspace);
    final prefabLoad = await _prefabStore.loadV3(workspace.rootPath);
    final levelLoad = await _levelStore.load(workspace);
    final chunks = chunkLoad.sources.map((source) => source.data).toList()
      ..sort((left, right) {
        var order = left.levelId.compareTo(right.levelId);
        if (order != 0) return order;
        order = left.id.compareTo(right.id);
        return order != 0 ? order : left.chunkKey.compareTo(right.chunkKey);
      });
    final sourcePathByChunkKey = <String, String>{};
    final baselineContentsByChunkKey = <String, String>{};
    for (final source in chunkLoad.sources) {
      sourcePathByChunkKey[source.data.chunkKey] = source.sourcePath;
      baselineContentsByChunkKey[source.data.chunkKey] =
          source.baselineContents;
    }
    final availableLevelIds = chunks.map((chunk) => chunk.levelId).toSet()
      ..removeWhere((levelId) => levelId.isEmpty);
    final sortedLevelIds = availableLevelIds.toList()..sort();
    final preferredLevelId = _preferredActiveLevelId;
    final activeLevelId =
        preferredLevelId != null && availableLevelIds.contains(preferredLevelId)
        ? preferredLevelId
        : (sortedLevelIds.isEmpty ? null : sortedLevelIds.first);
    _preferredActiveLevelId = activeLevelId;
    return ChunkV2Document(
      chunks: chunks,
      sourcePathByChunkKey: sourcePathByChunkKey,
      baselineContentsByChunkKey: baselineContentsByChunkKey,
      prefabData: prefabLoad.prefabData,
      tileData: prefabLoad.tileData,
      visualBoundsByPrefabKey: PrefabVisualBoundsResolver.resolveAll(
        prefabData: prefabLoad.prefabData,
        tileData: prefabLoad.tileData,
      ),
      groundTopYByLevelId: <String, double>{
        for (final level in levelLoad.levels) level.levelId: level.groundTopY,
      },
      levels: levelLoad.levels,
      availableLevelIds: sortedLevelIds,
      activeLevelId: activeLevelId,
    );
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    if (document is PolygonAuthoringMigrationRequiredDocument) {
      return <ValidationIssue>[
        _requireChunkMigration(document).toValidationIssue(),
      ];
    }
    if (document is ChunkV2Document) {
      return validateChunkV2Document(document);
    }
    throw _unexpectedDocument(document);
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    if (document is PolygonAuthoringMigrationRequiredDocument) {
      return _requireChunkMigration(document).toScene();
    }
    if (document is! ChunkV2Document) throw _unexpectedDocument(document);
    final activeLevelId = document.activeLevelId;
    final chunks =
        document.chunks
            .where((chunk) => chunk.levelId == activeLevelId)
            .toList()
          ..sort((left, right) {
            final idOrder = left.id.compareTo(right.id);
            return idOrder != 0
                ? idOrder
                : left.chunkKey.compareTo(right.chunkKey);
          });
    final sourcePaths = <String, String>{
      for (final chunk in chunks)
        chunk.chunkKey: ?document.sourcePathByChunkKey[chunk.chunkKey],
    };
    final collisionExpansions = <String, ChunkV2CollisionExpansionResult>{};
    for (var chunkIndex = 0; chunkIndex < chunks.length; chunkIndex += 1) {
      final chunk = chunks[chunkIndex];
      collisionExpansions[chunk.chunkKey] = expandChunkV2Collision(
        chunk: chunk,
        prefabs: document.prefabData.prefabs,
        sourcePath: sourcePaths[chunk.chunkKey] ?? chunk.chunkKey,
        chunkIndex: chunkIndex,
      );
    }
    final seamAnalysis = analyzeChunkV2Seams(
      chunks: chunks,
      levels: document.levels.where(
        (level) => level.levelId == document.activeLevelId,
      ),
      collisionExpansionByChunkKey: collisionExpansions,
      sourcePathByChunkKey: document.sourcePathByChunkKey,
    );
    return ChunkV2Scene(
      chunks: chunks,
      sourcePathByChunkKey: sourcePaths,
      prefabData: document.prefabData,
      tileData: document.tileData,
      visualBoundsByPrefabKey: document.visualBoundsByPrefabKey,
      groundTopYByLevelId: document.groundTopYByLevelId,
      collisionExpansionByChunkKey: collisionExpansions,
      seamAnalysis: seamAnalysis,
      availableLevelIds: document.availableLevelIds,
      activeLevelId: document.activeLevelId,
    );
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    if (document is PolygonAuthoringMigrationRequiredDocument) {
      _requireChunkMigration(document);
      return document;
    }
    if (document is! ChunkV2Document) throw _unexpectedDocument(document);
    if (command.kind == 'set_active_level') {
      final levelId = command.payload['levelId'];
      if (levelId is! String ||
          levelId == document.activeLevelId ||
          !document.availableLevelIds.contains(levelId)) {
        return document;
      }
      _preferredActiveLevelId = levelId;
      return document.copyWith(activeLevelId: levelId);
    }
    return _applyV2Edit(document, command);
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    if (document is PolygonAuthoringMigrationRequiredDocument) {
      final migration = _requireChunkMigration(document);
      throw StateError(
        'polygon_authoring_migration_required: ${migration.message}',
      );
    }
    if (document is! ChunkV2Document) throw _unexpectedDocument(document);
    final blockingIssues = validateChunkV2Document(
      document,
    ).where((issue) => issue.severity == ValidationSeverity.error).toList();
    if (blockingIssues.isNotEmpty) {
      throw StateError(
        'Cannot export chunk-v2 while validation has '
        '${blockingIssues.length} blocking issue(s).',
      );
    }
    final pending = describePendingChanges(workspace, document: document);
    if (!pending.hasChanges) {
      return ExportResult(
        applied: false,
        artifacts: <ExportArtifact>[
          const ExportArtifact(
            title: 'chunk_summary.md',
            content:
                '# Chunk Export\n\nchangedChunks: 0\nchangedFiles: 0\n\nNo chunk-v2 edits detected.',
          ),
        ],
      );
    }
    final savePlan = _store.buildV2SavePlan(document: document);
    _store.applyV2SavePlan(workspace, document: document, savePlan: savePlan);
    return ExportResult(
      applied: true,
      artifacts: <ExportArtifact>[
        ExportArtifact(
          title: 'chunk_summary.md',
          content: _buildSummary(savePlan),
        ),
      ],
    );
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    if (document is PolygonAuthoringMigrationRequiredDocument) {
      _requireChunkMigration(document);
      return PendingChanges.empty;
    }
    if (document is! ChunkV2Document) throw _unexpectedDocument(document);
    final savePlan = _store.buildV2SavePlan(document: document);
    final writes = savePlan.writes;
    if (writes.isEmpty) return PendingChanges.empty;
    return PendingChanges(
      changedItemIds: savePlan.changedChunkKeys,
      fileDiffs: writes
          .map(
            (write) => PendingFileDiff(
              relativePath: write.relativePath,
              editCount: 1,
              unifiedDiff: _buildUnifiedDiff(write),
            ),
          )
          .toList(growable: false),
    );
  }

  AuthoringDocument _applyV2Edit(
    ChunkV2Document document,
    AuthoringCommand command,
  ) {
    if (command.kind == commitChunkLifecycleCommandKind) {
      final commit = command.payload['commit'];
      if (commit is! ChunkV2LifecycleCommit) return document;
      final result = ChunkV2LifecycleCommitPolicy(
        store: _store,
      ).apply(document: document, commit: commit);
      return result.accepted && result.changed ? result.document : document;
    }
    final chunkKey = command.payload['chunkKey'];
    if (chunkKey is! String) return document;
    final chunkIndex = document.chunks.indexWhere(
      (chunk) => chunk.chunkKey == chunkKey,
    );
    if (chunkIndex < 0) return document;
    final chunk = document.chunks[chunkIndex];
    late final ChunkV2FileData nextChunk;
    Map<String, String>? nextSourcePaths;
    switch (command.kind) {
      case commitChunkPolygonCommandKind:
        final commit = command.payload['commit'];
        if (commit is! TerrainPolygonInteractionCommit) return document;
        final result = const ChunkV2CollisionCommitPolicy().apply(
          chunk: chunk,
          commit: commit,
          sourcePath: document.sourcePathByChunkKey[chunkKey] ?? chunkKey,
          chunkIndex: chunkIndex,
        );
        if (!result.accepted || !result.changed) return document;
        nextChunk = result.chunk;
        break;
      case commitChunkMetadataCommandKind:
        final commit = command.payload['commit'];
        if (commit is! ChunkV2MetadataCommit) return document;
        final result = const ChunkV2MetadataCommitPolicy().apply(
          chunk: chunk,
          commit: commit,
          knownLevelIds: document.availableLevelIds,
          allowedAssemblyGroupIdsByLevelId: <String, Iterable<String>>{
            for (final level in document.levels)
              level.levelId: level.chunkThemeGroups,
          },
          sourcePath: document.sourcePathByChunkKey[chunkKey] ?? chunkKey,
        );
        if (!result.accepted || !result.changed) return document;
        nextChunk = result.chunk;
        if (document.createdChunkKeys.contains(chunkKey)) {
          nextSourcePaths = Map<String, String>.of(
            document.sourcePathByChunkKey,
          );
          nextSourcePaths[chunkKey] = _store.canonicalV2SourcePath(nextChunk);
        }
        break;
      case commitChunkCompositionCommandKind:
        final commit = command.payload['commit'];
        if (commit is! ChunkV2CompositionCommit) return document;
        final result = const ChunkV2CompositionCommitPolicy().apply(
          document: document,
          chunkIndex: chunkIndex,
          commit: commit,
        );
        if (!result.accepted || !result.changed) return document;
        nextChunk = result.chunk;
        break;
      default:
        return document;
    }
    final chunks = document.chunks.toList(growable: false);
    chunks[chunkIndex] = nextChunk;
    final candidate = document.copyWith(
      chunks: chunks,
      sourcePathByChunkKey: nextSourcePaths,
      changedChunkKeys: <String>{...document.changedChunkKeys, chunkKey},
    );
    return _validatedV2CandidateOrOriginal(document, candidate);
  }

  ChunkV2Document _validatedV2CandidateOrOriginal(
    ChunkV2Document original,
    ChunkV2Document candidate,
  ) {
    final hasBlockingIssue = validateChunkV2Document(
      candidate,
    ).any((issue) => issue.severity == ValidationSeverity.error);
    if (hasBlockingIssue) return original;
    try {
      _store.buildV2SavePlan(document: candidate);
    } on StateError {
      return original;
    }
    return candidate;
  }

  String _buildSummary(ChunkSavePlan savePlan) {
    final lines = <String>[
      '# Chunk Export',
      '',
      'changedChunks: ${savePlan.changedChunkKeys.length}',
      'changedFiles: ${savePlan.writes.length}',
      '',
      '## Files',
      ...savePlan.writes.map(
        (write) => write.deleteFile
            ? '- DELETE ${write.relativePath} (${write.chunkKey})'
            : '- ${write.relativePath} (${write.chunkId})',
      ),
    ];
    return lines.join('\n');
  }

  String _buildUnifiedDiff(ChunkFileWrite write) {
    final path = write.relativePath.replaceAll('\\', '/');
    final beforePath = (write.previousRelativePath ?? write.relativePath)
        .replaceAll('\\', '/');
    final before = write.beforeContent ?? '';
    final after = write.afterContent;
    final beforeLines = _splitLines(before);
    final afterLines = _splitLines(after);
    if (write.deleteFile) {
      final lines = <String>[
        'diff --git a/$path b/$path',
        'deleted file mode 100644',
        '--- a/$path',
        '+++ /dev/null',
        '@@ -1,${beforeLines.length} +0,0 @@',
        ...beforeLines.map((line) => '-$line'),
      ];
      return lines.join('\n');
    }
    final lines = <String>[
      'diff --git a/$beforePath b/$path',
      '--- a/$beforePath',
      '+++ b/$path',
      '@@ -1,${beforeLines.length} +1,${afterLines.length} @@',
      ...beforeLines.map((line) => '-$line'),
      ...afterLines.map((line) => '+$line'),
    ];
    return lines.join('\n');
  }

  List<String> _splitLines(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

  PolygonAuthoringMigrationRequiredDocument _requireChunkMigration(
    PolygonAuthoringMigrationRequiredDocument document,
  ) {
    if (document.domain != PolygonAuthoringMigrationDomain.chunks) {
      throw StateError(
        'ChunkDomainPlugin received migration state for '
        '${document.domain.pluginId}.',
      );
    }
    return document;
  }

  StateError _unexpectedDocument(AuthoringDocument document) => StateError(
    'ChunkDomainPlugin expected ChunkV2Document but got '
    '${document.runtimeType}.',
  );
}
