import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../chunks/chunk_domain_plugin.dart';
import '../chunks/chunk_v2_file_codec.dart';
import '../chunks/chunk_v2_models.dart';
import '../domain/authoring_session_semantics.dart';
import '../domain/authoring_types.dart';
import '../levels/level_domain_models.dart';
import '../parallax/parallax_store.dart';
import '../prefabs/domain/prefab_visual_bounds_resolver.dart';
import '../prefabs/store/prefab_store.dart';
import '../terrain_materials/terrain_material_domain_models.dart';
import '../terrain_materials/terrain_material_domain_plugin.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_write_transaction.dart';

/// A bounded layout document projected through the shared chunk geometry tools.
/// The source envelope and save transaction remain owned by Training Field.
final class TrainingFieldDocument extends ChunkV2Document {
  TrainingFieldDocument({
    required ChunkV2Document geometry,
    required this.source,
    required this.baseline,
    required this.dependencies,
  }) : super(
         chunks: geometry.chunks,
         sourcePathByChunkKey: geometry.sourcePathByChunkKey,
         baselineContentsByChunkKey: geometry.baselineContentsByChunkKey,
         prefabData: geometry.prefabData,
         tileData: geometry.tileData,
         visualBoundsByPrefabKey: geometry.visualBoundsByPrefabKey,
         groundTopYByLevelId: {
           'training_field': source.playerStartY.toDouble(),
         },
         levels: geometry.levels,
         parallaxThemes: geometry.parallaxThemes,
         availableLevelIds: const ['training_field'],
         activeLevelId: 'training_field',
         selectedChunkKey: geometry.selectedChunkKey,
         availableTerrainMaterialKeys: geometry.availableTerrainMaterialKeys,
         starterMaterialIssues: geometry.starterMaterialIssues,
         changedChunkKeys: geometry.changedChunkKeys,
       );
  final TrainingFieldSource source;
  final String baseline;
  final Map<String, String> dependencies;

  String encode({int? revision}) => source.encode(
    revision: revision,
    chunks: chunks.map(ChunkV2FileCodec.encode).toList(),
  );
}

/// Independent authoring domain: it never writes normal level/chunk sources.
final class TrainingFieldDomainPlugin
    implements AuthoringDomainPlugin, AuthoringHistoryReconciliation {
  static const pluginId = 'training_field';
  static const setSpawns = 'training_field_set_spawns';
  static const _prefabs = 'assets/authoring/level/prefab_defs.json';
  static const _tiles = 'assets/authoring/level/tile_defs.json';
  final _geometry = ChunkDomainPlugin();
  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    final baseline = await File(workspace.resolve(trainingFieldSourcePath))
        .readAsString();
    final source = TrainingFieldSource.decode(baseline);
    final dependencies = <String, String>{};
    for (final path in [
      _prefabs,
      _tiles,
      'assets/authoring/level/parallax_defs.json',
      'assets/authoring/level/terrain_material_defs.json',
    ]) {
      dependencies[path] = await File(workspace.resolve(path)).readAsString();
    }
    final prefabs = await const PrefabStore().loadV3(workspace.rootPath);
    final themes = await const ParallaxStore().load(workspace);
    final materialPlugin = TerrainMaterialDomainPlugin();
    final materials =
        await materialPlugin.loadFromRepo(workspace) as TerrainMaterialDocument;
    final chunks = source.chunkContents
        .map(
          (text) => ChunkV2FileCodec.decode(
            text,
            sourcePath: trainingFieldSourcePath,
          ),
        )
        .toList();
    final geometry = ChunkV2Document(
      chunks: chunks,
      sourcePathByChunkKey: {
        for (final chunk in chunks) chunk.chunkKey: trainingFieldSourcePath,
      },
      baselineContentsByChunkKey: {
        for (final chunk in chunks)
          chunk.chunkKey: ChunkV2FileCodec.encode(chunk),
      },
      prefabData: prefabs.prefabData,
      tileData: prefabs.tileData,
      visualBoundsByPrefabKey: PrefabVisualBoundsResolver.resolveAll(
        prefabData: prefabs.prefabData,
        tileData: prefabs.tileData,
      ),
      levels: [
        LevelDef(
          levelId: 'training_field',
          revision: source.revision,
          displayName: 'Training Field',
          visualThemeId: source.visualThemeId,
          cameraCenterY: 135,
          groundTopY: source.playerStartY.toDouble(),
          earlyPatternChunks: 0,
          easyPatternChunks: 0,
          normalPatternChunks: 0,
          noEnemyChunks: 0,
          enumOrdinal: 0,
          status: 'active',
        ),
      ],
      parallaxThemes: themes.themes,
      availableLevelIds: const ['training_field'],
      activeLevelId: 'training_field',
      selectedChunkKey: chunks.first.chunkKey,
      availableTerrainMaterialKeys: materials.materials.map((m) => m.key),
      starterMaterialIssues: materialPlugin.validate(materials),
    );
    return TrainingFieldDocument(
      geometry: geometry,
      source: source,
      baseline: baseline,
      dependencies: Map.unmodifiable(dependencies),
    );
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) =>
      _geometry.buildEditableScene(document);

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    final doc = document as TrainingFieldDocument;
    final issues = [..._geometry.validate(doc)];
    try {
      final source = TrainingFieldSource.decode(doc.encode());
      compileTrainingField(
        source: source,
        prefabContents: doc.dependencies[_prefabs]!,
        tileContents: doc.dependencies[_tiles]!,
      );
    } on FormatException catch (error) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'training_field_layout_invalid',
          message: error.message.toString(),
          sourcePath: trainingFieldSourcePath,
          blockingOperations: const {
            AuthoringOperation.build,
            AuthoringOperation.play,
          },
        ),
      );
    }
    if (!doc.parallaxThemes.any(
      (theme) => theme.parallaxThemeId == doc.source.visualThemeId,
    )) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'training_field_theme_missing',
          message: 'Training Field background is missing.',
          sourcePath: trainingFieldSourcePath,
        ),
      );
    }
    return issues;
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final doc = document as TrainingFieldDocument;
    if (command.kind == setSpawns) {
      final next = TrainingFieldSource.decode(
        doc.source.encode(
          playerX: command.payload['playerX'] as int?,
          playerY: command.payload['playerY'] as int?,
          enemyChunk: command.payload['enemyChunk'] as int?,
          enemyX: command.payload['enemyX'] as int?,
          enemyY: command.payload['enemyY'] as int?,
        ),
      );
      if (next.encode() == doc.source.encode()) return doc;
      return TrainingFieldDocument(
        geometry: doc,
        source: next,
        baseline: doc.baseline,
        dependencies: doc.dependencies,
      );
    }
    if (command.kind != ChunkDomainPlugin.commitChunkPolygonCommandKind &&
        command.kind != ChunkDomainPlugin.commitChunkCompositionCommandKind &&
        command.kind != 'set_active_level') {
      throw ArgumentError(
        'Training Field only accepts layout and spawn edits.',
      );
    }
    final edited = _geometry.applyEdit(doc, command) as ChunkV2Document;
    if (identical(edited, doc)) return doc;
    final next = TrainingFieldDocument(
      geometry: edited,
      source: doc.source,
      baseline: doc.baseline,
      dependencies: doc.dependencies,
    );
    // Commands cannot smuggle normal enemy/arena/level metadata into the layout.
    TrainingFieldSource.decode(next.encode());
    return next;
  }

  String _canonicalBaseline(TrainingFieldDocument doc) {
    final source = TrainingFieldSource.decode(doc.baseline);
    return source.encode(
      chunks: source.chunkContents
          .map((text) => ChunkV2FileCodec.encode(ChunkV2FileCodec.decode(text)))
          .toList(),
    );
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final doc = document as TrainingFieldDocument;
    if (doc.encode() == _canonicalBaseline(doc)) return PendingChanges.empty;
    final before = _canonicalBaseline(doc).trimRight().split('\n');
    final after = doc.encode().trimRight().split('\n');
    return PendingChanges(
      changedItemIds: const ['training_field'],
      fileDiffs: [
        PendingFileDiff(
          relativePath: trainingFieldSourcePath,
          editCount: 1,
          unifiedDiff: [
            '--- a/$trainingFieldSourcePath',
            '+++ b/$trainingFieldSourcePath',
            '@@ -1,${before.length} +1,${after.length} @@',
            ...before.map((line) => '-$line'),
            ...after.map((line) => '+$line'),
          ].join('\n'),
        ),
      ],
    );
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    final doc = document as TrainingFieldDocument;
    final issues = validate(doc)
        .where((issue) => issue.blocks(AuthoringOperation.save));
    if (issues.isNotEmpty) {
      return ExportResult(
        applied: false,
        outcome: ExportOutcome.validationFailed,
        message: issues.first.message,
      );
    }
    if (!describePendingChanges(workspace, document: doc).hasChanges) {
      return ExportResult(applied: false);
    }
    final target = File(workspace.resolve(trainingFieldSourcePath));
    final contents = doc.encode(
      revision: TrainingFieldSource.decode(doc.baseline).revision + 1,
    );
    void checkDrift() {
      for (final entry in {
        trainingFieldSourcePath: doc.baseline,
        ...doc.dependencies,
      }.entries) {
        final file = File(workspace.resolve(entry.key));
        if (!file.existsSync() || file.readAsStringSync() != entry.value) {
          throw AuthoringSourceDrift(
            '${entry.key} changed. Reload before saving.',
          );
        }
      }
    }

    try {
      checkDrift();
      WorkspaceWriteTransaction([
        WorkspaceWriteArtifact(path: target.path, contents: contents),
      ]).apply(beforeReplace: checkDrift);
      return ExportResult(applied: true);
    } on WorkspaceWriteTransactionException catch (error) {
      return ExportResult(
        applied: error.outputsCommitted,
        outcome: error.outputsCommitted
            ? ExportOutcome.appliedWithCleanupRequired
            : error.rollbackFailures.isNotEmpty
            ? ExportOutcome.rollbackIncomplete
            : error.cause is AuthoringSourceDrift
            ? ExportOutcome.sourceDrift
            : ExportOutcome.failed,
        message: '$error',
        recovery: error.recovery == null
            ? null
            : _TrainingRecovery(error.recovery!),
      );
    } on AuthoringSourceDrift catch (error) {
      return error.exportResult;
    }
  }

  @override
  AuthoringDocument? restoreContent({
    required AuthoringDocument current,
    required AuthoringDocument historical,
  }) {
    final now = current as TrainingFieldDocument;
    final old = historical as TrainingFieldDocument;
    return TrainingFieldDocument(
      geometry: now.copyWith(chunks: old.chunks),
      source: TrainingFieldSource.decode(
        old.source.encode(revision: now.source.revision),
      ),
      baseline: now.baseline,
      dependencies: now.dependencies,
    );
  }
}

final class _TrainingRecovery implements AuthoringExportRecovery {
  const _TrainingRecovery(this.transaction);
  final WorkspaceWriteRecovery transaction;
  @override
  Future<ExportResult> retry() async {
    transaction.retry();
    return ExportResult(
      applied: transaction.outputsCommitted,
      outcome: transaction.outputsCommitted
          ? ExportOutcome.applied
          : ExportOutcome.failed,
      message: transaction.outputsCommitted
          ? 'Saved layout verified; cleanup completed.'
          : 'Original layout restored. Your edits are retained.',
    );
  }
}
