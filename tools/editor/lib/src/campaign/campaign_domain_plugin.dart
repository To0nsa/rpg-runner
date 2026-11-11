import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../chunks/chunk_domain_plugin.dart';
import '../chunks/chunk_v2_file_codec.dart';
import '../chunks/chunk_v2_models.dart';
import '../domain/authoring_session_semantics.dart';
import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_write_transaction.dart';

final class CampaignDocument extends AuthoringDocument {
  CampaignDocument({
    required this.catalog,
    required this.baseline,
    required this.chunks,
    required this.dependencies,
    String? selectedMissionId,
  }) : selectedMissionId = selectedMissionId ?? catalog.missions.first.id;
  final CampaignCatalogSource catalog;
  final String baseline;
  final ChunkV2Document chunks;
  final Map<String, String> dependencies;
  final String selectedMissionId;
  CampaignMissionSource get selected =>
      catalog.missions.firstWhere((m) => m.id == selectedMissionId);
  CompiledCampaignMission compile(CampaignMissionSource mission) =>
      compileCampaignMission(
        source: mission,
        chunkContentsByKey: {
          for (final c in chunks.chunks) c.chunkKey: ChunkV2FileCodec.encode(c),
        },
        prefabContents:
            dependencies['assets/authoring/level/prefab_defs.json']!,
        tileContents: dependencies['assets/authoring/level/tile_defs.json']!,
      );
  List<String> whereUsed(String chunkKey) => [
    for (final m in catalog.missions)
      if (m.route.any((o) => o.chunkKey == chunkKey)) m.title['en']!,
  ];
  CampaignDocument withCatalog(
    CampaignCatalogSource value, {
    String? selection,
  }) => CampaignDocument(
    catalog: value,
    baseline: baseline,
    chunks: chunks,
    dependencies: dependencies,
    selectedMissionId: selection ?? selectedMissionId,
  );
}

final class CampaignScene extends EditableScene {
  const CampaignScene(this.document);
  final CampaignDocument document;
}

/// Owns mission intent and its one source transaction. Chunk geometry remains in
/// Chunk Creator; returning reloads current dependencies instead of retained bytes.
final class CampaignDomainPlugin
    implements
        AuthoringDomainPlugin,
        AuthoringSessionSemantics,
        AuthoringHistoryReconciliation {
  static const pluginId = 'campaign';
  static const selectMission = 'campaign_select_mission';
  static const replaceMission = 'campaign_replace_mission';
  static const reorderMission = 'campaign_reorder_mission';

  /// Sets only the chapter reward; expectedRewardCharacterId guards stale forms.
  static const setChapterReward = 'campaign_set_chapter_reward';
  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    final baseline = await File(workspace.resolve(campaignSourcePath))
        .readAsString();
    final catalog = CampaignCatalogSource.decode(baseline);
    final chunks = await ChunkDomainPlugin().loadV2FromRepo(workspace);
    final dependencies = <String, String>{};
    for (final path in [
      'assets/authoring/level/prefab_defs.json',
      'assets/authoring/level/tile_defs.json',
      'assets/authoring/level/level_defs.json',
      'assets/authoring/level/parallax_defs.json',
      'assets/authoring/level/terrain_material_defs.json',
      ...chunks.sourcePathByChunkKey.values,
    ]) {
      final relative =
          (p.isAbsolute(path)
                  ? p.relative(path, from: workspace.rootPath)
                  : path)
              .replaceAll('\\', '/');
      dependencies[relative] = await File(workspace.resolve(relative))
          .readAsString();
    }
    return CampaignDocument(
      catalog: catalog,
      baseline: baseline,
      chunks: chunks,
      dependencies: Map.unmodifiable(dependencies),
    );
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    final doc = document as CampaignDocument;
    final issues = <ValidationIssue>[];
    for (final mission in doc.catalog.missions) {
      try {
        if (!doc.chunks.levels.any((l) => l.levelId == mission.levelId) ||
            !doc.chunks.parallaxThemes.any(
              (t) => t.parallaxThemeId == mission.visualThemeId,
            )) {
          throw const FormatException('Unknown level or visual theme.');
        }
        doc.compile(mission);
      } on Object catch (e) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'campaign_mission_not_ready',
            message: '${mission.title['en']}: $e',
            sourcePath: campaignSourcePath,
            ownerKey: mission.id,
            blockingOperations: {
              if (mission.id == doc.selectedMissionId) AuthoringOperation.play,
              if (mission.includeInBuild) AuthoringOperation.build,
            },
          ),
        );
      }
    }
    return issues;
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) =>
      CampaignScene(document as CampaignDocument);

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final doc = document as CampaignDocument;
    if (command.kind == selectMission) {
      final id = command.payload['id'] as String;
      if (!doc.catalog.missions.any((m) => m.id == id)) {
        throw ArgumentError('Unknown mission $id.');
      }
      return id == doc.selectedMissionId
          ? doc
          : doc.withCatalog(doc.catalog, selection: id);
    }
    final json = doc.catalog.toJson();
    final chapters = json['chapters'] as List;
    final id = command.payload['id'];
    if (command.kind == setChapterReward) {
      final chapter = chapters
          .cast<Map>()
          .where((c) => c['id'] == id)
          .firstOrNull;
      if (chapter == null) throw ArgumentError('Unknown chapter $id.');
      if (!command.payload.containsKey('expectedRewardCharacterId') ||
          command.payload['expectedRewardCharacterId'] !=
              chapter['rewardCharacterId']) {
        throw StateError('Chapter reward changed; reload this form.');
      }
      if (!command.payload.containsKey('rewardCharacterId')) {
        throw ArgumentError('A chapter reward or explicit null is required.');
      }
      if (chapter['rewardCharacterId'] ==
          command.payload['rewardCharacterId']) {
        return doc;
      }
      chapter['rewardCharacterId'] = command.payload['rewardCharacterId'];
      return doc.withCatalog(CampaignCatalogSource.decode(jsonEncode(json)));
    }
    final chapter = chapters.cast<Map>().firstWhere(
      (c) => (c['missions'] as List).any((m) => m['id'] == id),
    );
    final missions = chapter['missions'] as List;
    final index = missions.indexWhere((m) => m['id'] == id);
    if (command.kind == replaceMission) {
      final old = CampaignMissionSource.decode(missions[index]);
      if (command.payload['expectedRevision'] != old.revision) {
        throw StateError('Mission changed; reload this form.');
      }
      final next = CampaignMissionSource.decode(
        jsonDecode(jsonEncode(command.payload['mission'])),
      );
      if (next.id != old.id) throw ArgumentError('Mission IDs are stable.');
      if (jsonEncode(next.toJson()) == jsonEncode(old.toJson())) return doc;
      missions[index] = next.toJson()..['revision'] = old.revision + 1;
    } else if (command.kind == reorderMission) {
      final target = command.payload['targetIndex'] as int;
      if (target < 0 || target >= missions.length) {
        throw ArgumentError('Invalid mission order.');
      }
      if (index == target) return doc;
      missions.insert(target, missions.removeAt(index));
    } else {
      throw ArgumentError('Unsupported campaign command ${command.kind}.');
    }
    return doc.withCatalog(CampaignCatalogSource.decode(jsonEncode(json)));
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final doc = document as CampaignDocument;
    final before = CampaignCatalogSource.decode(doc.baseline).encode();
    final after = doc.catalog.encode();
    if (before == after) return PendingChanges.empty;
    return PendingChanges(
      changedItemIds: [for (final m in doc.catalog.missions) m.id],
      fileDiffs: [
        PendingFileDiff(
          relativePath: campaignSourcePath,
          editCount: 1,
          unifiedDiff:
              '--- a/$campaignSourcePath\n+++ b/$campaignSourcePath\n${before.split('\n').map((l) => '-$l').join('\n')}\n${after.split('\n').map((l) => '+$l').join('\n')}',
        ),
      ],
    );
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    final doc = document as CampaignDocument;
    if (!describePendingChanges(workspace, document: doc).hasChanges) {
      return ExportResult(applied: false);
    }
    void guard() {
      for (final e in {
        campaignSourcePath: doc.baseline,
        ...doc.dependencies,
      }.entries) {
        final f = File(workspace.resolve(e.key));
        if (!f.existsSync() || f.readAsStringSync() != e.value) {
          throw AuthoringSourceDrift('${e.key} changed. Reload before saving.');
        }
      }
    }

    final json = doc.catalog.toJson()
      ..['revision'] = CampaignCatalogSource.decode(doc.baseline).revision + 1;
    final text = CampaignCatalogSource.decode(jsonEncode(json)).encode();
    try {
      guard();
      WorkspaceWriteTransaction([
        WorkspaceWriteArtifact(
          path: workspace.resolve(campaignSourcePath),
          contents: text,
        ),
      ]).apply(beforeReplace: guard);
      return ExportResult(applied: true);
    } on AuthoringSourceDrift catch (e) {
      return e.exportResult;
    } on WorkspaceWriteTransactionException catch (e) {
      return ExportResult(
        applied: e.outputsCommitted,
        outcome: e.outputsCommitted
            ? ExportOutcome.appliedWithCleanupRequired
            : e.rollbackFailures.isNotEmpty
            ? ExportOutcome.rollbackIncomplete
            : e.cause is AuthoringSourceDrift
            ? ExportOutcome.sourceDrift
            : ExportOutcome.failed,
        message: '$e',
        recovery: e.recovery == null ? null : _CampaignRecovery(e.recovery!),
      );
    }
  }

  @override
  bool isPresentationCommand(AuthoringCommand command) =>
      command.kind == selectMission;
  @override
  AuthoringDocument retainPresentation({
    required AuthoringDocument current,
    required AuthoringDocument restored,
  }) => (restored as CampaignDocument).withCatalog(
    restored.catalog,
    selection: (current as CampaignDocument).selectedMissionId,
  );
  @override
  AuthoringDocument? restoreContent({
    required AuthoringDocument current,
    required AuthoringDocument historical,
  }) {
    final now = current as CampaignDocument;
    final old = historical as CampaignDocument;
    final json = old.catalog.toJson()..['revision'] = now.catalog.revision;
    for (final chapter in json['chapters'] as List) {
      for (final mission in chapter['missions'] as List) {
        mission['revision'] =
            now.catalog.missions
                .firstWhere((m) => m.id == mission['id'])
                .revision +
            1;
      }
    }
    return now.withCatalog(CampaignCatalogSource.decode(jsonEncode(json)));
  }
}

final class _CampaignRecovery implements AuthoringExportRecovery {
  const _CampaignRecovery(this.transaction);
  final WorkspaceWriteRecovery transaction;
  @override
  Future<ExportResult> retry() async {
    transaction.retry();
    return ExportResult(
      applied: transaction.outputsCommitted,
      outcome: transaction.outputsCommitted
          ? ExportOutcome.applied
          : ExportOutcome.failed,
    );
  }
}
