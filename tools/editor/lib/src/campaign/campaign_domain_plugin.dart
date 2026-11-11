import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../chunks/chunk_domain_plugin.dart';
import '../chunks/chunk_v2_file_codec.dart';
import '../chunks/chunk_v2_models.dart';
import '../domain/authoring_history_revision.dart';
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
  }) : selectedMissionId =
           catalog.missions.any((m) => m.id == selectedMissionId)
           ? selectedMissionId!
           : catalog.missions.first.id;
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

  /// Accepts title/description/mapX/mapY in details; selects a fresh draft mission.
  static const createChapter = 'campaign_create_chapter';

  /// Appends an excluded draft to chapter id, inheriting only its last mission's region/theme.
  static const addMission = 'campaign_add_mission';

  /// Replaces metadata in details only when expectedChapter still matches.
  static const editChapter = 'campaign_edit_chapter';

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
    if (command.kind == createChapter) {
      final details = command.payload['details'] as Map;
      final title = details['title'] as Map;
      final chapterId = _allocateId(
        title['en'] as String,
        doc.catalog.chapters.map((c) => c.id).toSet(),
      );
      final mission = _draftMission(doc, chapterId, 1, doc.selected);
      chapters.add({
        'id': chapterId,
        for (final key in ['title', 'description', 'mapX', 'mapY'])
          key: details[key],
        'rewardCharacterId': null,
        'missions': [mission.toJson()],
      });
      return doc.withCatalog(
        CampaignCatalogSource.decode(jsonEncode(json)),
        selection: mission.id,
      );
    }
    if (command.kind == editChapter || command.kind == addMission) {
      final chapter = chapters
          .cast<Map>()
          .where((c) => c['id'] == id)
          .firstOrNull;
      if (chapter == null) throw ArgumentError('Unknown chapter $id.');
      if (command.kind == editChapter) {
        if (jsonEncode(command.payload['expectedChapter']) !=
            jsonEncode(chapter)) {
          throw StateError('Chapter changed; reload this form.');
        }
        final details = command.payload['details'] as Map;
        for (final key in ['title', 'description', 'mapX', 'mapY']) {
          chapter[key] = details[key];
        }
        final next = CampaignCatalogSource.decode(jsonEncode(json));
        return next.encode() == doc.catalog.encode()
            ? doc
            : doc.withCatalog(next);
      }
      final missions = chapter['missions'] as List;
      final mission = _draftMission(
        doc,
        chapter['id'] as String,
        missions.length + 1,
        CampaignMissionSource.decode(missions.last),
      );
      missions.add(mission.toJson());
      return doc.withCatalog(
        CampaignCatalogSource.decode(jsonEncode(json)),
        selection: mission.id,
      );
    }
    if (command.kind == setChapterReward) {
      final chapter = chapters
          .cast<Map>()
          .where((c) => c['id'] == id)
          .firstOrNull;
      if (chapter == null) throw ArgumentError('Unknown chapter $id.');
      final currentRewards = doc.catalog.chapters
          .firstWhere((c) => c.id == id)
          .rewardsToJson();
      if (jsonEncode(command.payload['expectedRewards']) !=
          jsonEncode(currentRewards)) {
        throw StateError('Chapter reward changed; reload this form.');
      }
      final rewards = command.payload['rewards'];
      if (rewards is! Map ||
          rewards.length != currentRewards.length ||
          !currentRewards.keys.every(rewards.containsKey)) {
        throw ArgumentError('Complete chapter rewards are required.');
      }
      if (jsonEncode(rewards) == jsonEncode(currentRewards)) {
        return doc;
      }
      chapter.addAll(Map<String, Object?>.from(rewards));
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
    final persisted = CampaignCatalogSource.decode(now.baseline);
    // Persisted identities may already own account progress. Undo may remove
    // unsaved drafts, but cannot delete or recycle a saved chapter or mission.
    if (persisted.chapters.any(
          (c) => !old.catalog.chapters.any((o) => o.id == c.id),
        ) ||
        persisted.missions.any(
          (m) => !old.catalog.missions.any((o) => o.id == m.id),
        )) {
      return null;
    }
    final json = old.catalog.toJson()..['revision'] = now.catalog.revision;
    for (final chapter in json['chapters'] as List) {
      for (final mission in chapter['missions'] as List) {
        final existing = now.catalog.missions
            .where((m) => m.id == mission['id'])
            .firstOrNull;
        final saved = persisted.missions
            .where((m) => m.id == mission['id'])
            .firstOrNull;
        final desired = CampaignMissionSource.decode(mission);
        mission['revision'] = reconcileAuthoringHistoryRevision(
          currentRevision: existing?.revision,
          persistedRevision: saved?.revision,
          restoresPersistedContent:
              saved != null && _sameMission(desired, saved),
          preservesCurrentContent:
              existing != null && _sameMission(desired, existing),
        );
      }
    }
    return now.withCatalog(CampaignCatalogSource.decode(jsonEncode(json)));
  }
}

bool _sameMission(CampaignMissionSource a, CampaignMissionSource b) =>
    jsonEncode(a.toJson()..remove('revision')) ==
    jsonEncode(b.toJson()..remove('revision'));

/// New drafts inherit only the region/background, never content or rewards.
CampaignMissionSource _draftMission(
  CampaignDocument document,
  String chapterId,
  int number,
  CampaignMissionSource template,
) => CampaignMissionSource.decode({
  'id': _allocateId(
    '${chapterId.length > 40 ? chapterId.substring(0, 40) : chapterId}_mission_$number',
    document.catalog.missions.map((m) => m.id).toSet(),
  ),
  'revision': 1,
  'includeInBuild': false,
  'title': {'en': 'Mission $number', 'fr': 'Mission $number'},
  'description': {
    'en': 'Describe this mission.',
    'fr': 'Décris cette mission.',
  },
  'levelId': template.levelId,
  'visualThemeId': template.visualThemeId,
  'firstClearXp': 0,
  'rewardAbilityId': null,
  'combatAllowed': true,
  'route': [],
  'start': null,
  'exit': null,
  'collectibles': [],
  'requiredRegions': [],
  'requiredEnemies': [],
  'requiredRescues': [],
});

String _allocateId(String name, Set<String> existing) {
  var base = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (base.isEmpty || !RegExp(r'^[a-z]').hasMatch(base)) base = 'chapter_$base';
  // Leave room for suffixes and the 64-character mission wire identity limit.
  if (base.length > 52) base = base.substring(0, 52);
  var id = base;
  for (var suffix = 2; existing.contains(id); suffix++) {
    id = '${base}_$suffix';
  }
  return id;
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
