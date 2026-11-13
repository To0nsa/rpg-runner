import 'campaign_tutorial_world_preview.dart';

import 'package:runner_core/terrain/water_region.dart';
import 'package:runner_core/track/chunk_pattern.dart';

import 'campaign_steps_tutorial_dialog.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:tool_ui/tool_ui.dart';

import '../../../campaign/campaign_domain_plugin.dart';
import '../../../campaign/campaign_marker_edit.dart';
import '../../../chunks/chunk_v2_file_codec.dart';
import '../../../chunks/chunk_v2_file_data.dart';
import '../../../parallax/parallax_domain_models.dart';
import '../../../domain/authoring_types.dart';
import '../../../playtest/authored_playtest_preparation.dart';
import '../../../session/editor_session_controller.dart';
import '../chunkCreator/chunk_creator_location.dart';
import '../chunkCreator/v2/chunk_composition_preview.dart';
import '../shared/authored_playtest_session.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_page_navigation_state.dart';
import '../shared/editor_native_file_picker.dart';
import '../shared/editor_confirm_delete_dialog.dart';
import '../../../workspace/editor_workspace.dart';
import 'campaign_settings_dialog.dart';
import 'campaign_chapter_dialog.dart';
import 'campaign_chapter_section.dart';
import 'campaign_edit_dialogs.dart';
import 'campaign_rewards_dialog.dart';
import 'campaign_contents.dart';
import 'campaign_route.dart';
import 'campaign_inspector.dart';
import 'campaign_mission_settings.dart';
import 'campaign_journal_preview.dart';
import 'campaign_overview.dart';
import 'campaign_marker_editing.dart';
import 'campaign_workspace.dart';
import 'campaign_tutorial_sequences.dart';
import 'campaign_marker_palette.dart';

enum CampaignTab { contents, route, markers, tutorials }

final class CampaignLocation extends EditorPageLocation {
  const CampaignLocation(
    this.missionId, {
    this.tab = CampaignTab.contents,
    this.chunkSearch = '',
    this.groupFilter = '',
    this.difficultyFilter = '',
    this.selectedChunkKey,
    this.selectedMissionChunkId,
  });
  final String missionId;
  final CampaignTab tab;
  final String chunkSearch;
  final String groupFilter, difficultyFilter;
  final String? selectedChunkKey, selectedMissionChunkId;
  @override
  AuthoringDocument restoreDocumentSelection(
    AuthoringDomainPlugin plugin,
    AuthoringDocument document,
  ) =>
      document is CampaignDocument &&
          document.catalog.missions.any((m) => m.id == missionId)
      ? plugin.applyEdit(
          document,
          AuthoringCommand(
            kind: CampaignDomainPlugin.selectMission,
            payload: {'id': missionId},
          ),
        )
      : document;
}

class CampaignPage extends StatefulWidget {
  const CampaignPage({
    super.key,
    required this.controller,
    this.onOpenChunk,
    this.initialLocation,
    this.onShellStateChanged,
    this.mapFilePicker = pickCampaignMapFilePath,
  });
  final EditorSessionController controller;
  final CampaignLocation? initialLocation;
  final Future<bool> Function(ChunkCreatorLocation)? onOpenChunk;
  final VoidCallback? onShellStateChanged;
  final EditorNativeFilePicker mapFilePicker;
  @override
  State<CampaignPage> createState() => _CampaignPageState();
}

class _CampaignPageState extends State<CampaignPage>
    implements
        EditorPageNavigationState,
        EditorPageLocalDraftState,
        EditorPageSessionShortcutHandler,
        EditorPageSaveHandler,
        EditorPagePlaytestHandler {
  final _play = AuthoredPlaytestSession();
  final _missionSettings = GlobalKey<CampaignMissionSettingsState>();
  bool _visualPreview = false;
  int _selectionRevision = 0;
  late final _markerEditing = CampaignMarkerEditing(widget.controller);
  CampaignDocument? _doc;
  final _compiled = <String, PolygonTerrainRuntimeChunk>{};
  final _panels = ToolThreePanelController();
  late final _search = TextEditingController(
    text: widget.initialLocation?.chunkSearch ?? '',
  );
  late CampaignTab _tab = widget.initialLocation?.tab ?? CampaignTab.contents;
  late String _groupFilter = widget.initialLocation?.groupFilter ?? '';
  late String _difficultyFilter =
      widget.initialLocation?.difficultyFilter ?? '';
  late String? _selectedChunkKey = widget.initialLocation?.selectedChunkKey;
  late String? _selectedMissionChunkId =
      widget.initialLocation?.selectedMissionChunkId;
  @override
  EditorPageLocation? get navigationLocation => _doc == null
      ? null
      : CampaignLocation(
          _doc!.selectedMissionId,
          tab: _tab,
          chunkSearch: _search.text,
          groupFilter: _groupFilter,
          difficultyFilter: _difficultyFilter,
          selectedChunkKey: _selectedChunkKey,
          selectedMissionChunkId: _selectedMissionChunkId,
        );
  @override
  bool get locksEditorShell => _play.locksEditor;
  @override
  bool get hasLocalDraftChanges =>
      _markerEditing.hasDraft ||
      (_missionSettings.currentState?.hasDraft ?? false);
  @override
  bool get canHandleUndoSessionShortcut =>
      !_play.locksEditor && (hasLocalDraftChanges || widget.controller.canUndo);
  @override
  bool get canHandleRedoSessionShortcut =>
      !_play.locksEditor && (hasLocalDraftChanges || widget.controller.canRedo);
  @override
  bool handleUndoSessionShortcut() {
    if (_play.locksEditor) return false;
    if (hasLocalDraftChanges) {
      _markerEditing.cancel();
      _missionSettings.currentState?.cancel();
    } else {
      widget.controller.undo();
    }
    return true;
  }

  @override
  bool handleRedoSessionShortcut() {
    if (_play.locksEditor) return false;
    if (hasLocalDraftChanges) {
      _markerEditing.cancel();
      _missionSettings.currentState?.cancel();
    } else {
      widget.controller.redo();
    }
    return true;
  }

  @override
  bool handlePlaytestShortcut(LogicalKeyboardKey key) {
    if (!_play.locksEditor && _tab == CampaignTab.markers) {
      if (key == LogicalKeyboardKey.escape) {
        _markerEditing.cancel();
        return true;
      }
      if (key == LogicalKeyboardKey.delete && !_visualPreview) {
        _markerEditing.delete();
        return true;
      }
    }
    if (key == LogicalKeyboardKey.f5 && !_play.locksEditor) {
      _startPlay();
      return true;
    }
    return _play.handleShortcut(key);
  }

  @override
  void handlePlaytestAppLifecycleState(AppLifecycleState state) =>
      _play.handleAppLifecycleState(state);
  @override
  bool get canSaveEditorPage =>
      !_play.locksEditor &&
      !widget.controller.isExporting &&
      (hasLocalDraftChanges || widget.controller.pendingChanges.hasChanges);
  @override
  Future<EditorPageSaveResult> saveEditorPage() async {
    if (_play.locksEditor || !_finishDraft()) {
      return EditorPageSaveResult.blocked;
    }
    await widget.controller.exportDirectWrite();
    return EditorPageSaveResult.fromSession(widget.controller);
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(_viewChanged);
    _markerEditing.addListener(_viewChanged);
    _markerEditing.exact.addListener(_viewChanged);
    widget.controller.addListener(_changed);
    _play.addListener(_changed);
    _refresh();
    if (_doc == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.controller.isLoading) {
          widget.controller.loadWorkspace();
        }
      });
    }
  }

  void _refresh() {
    final d = widget.controller.document;
    if (d is! CampaignDocument || identical(d, _doc)) return;
    final previousMissionId =
        _doc?.selectedMissionId ?? widget.initialLocation?.missionId;
    if ((previousMissionId != null &&
            previousMissionId != d.selectedMissionId) ||
        !d.selected.route.any((o) => o.id == _selectedMissionChunkId)) {
      _selectedMissionChunkId = null;
    }
    if (_selectedMissionChunkId != null) {
      _selectedChunkKey = d.selected.route
          .firstWhere((o) => o.id == _selectedMissionChunkId)
          .chunkKey;
    }
    if (!d.chunks.chunks.any((c) => c.chunkKey == _selectedChunkKey)) {
      _selectedChunkKey = null;
    }
    final campaignChunks = d.chunks.chunks.where((c) => c.usage == 'campaign');
    if (!campaignChunks.any((c) => c.assemblyGroupId == _groupFilter)) {
      _groupFilter = '';
    }
    if (!campaignChunks.any((c) => c.difficulty == _difficultyFilter)) {
      _difficultyFilter = '';
    }
    final reuseTerrain =
        identical(_doc?.chunks, d.chunks) &&
        identical(_doc?.dependencies, d.dependencies);
    _doc = d;
    _play.reconcileSource(d);
    if (!reuseTerrain) _compiled.clear();
    for (final key in d.selected.route.map((o) => o.chunkKey).toSet()) {
      if (_compiled.containsKey(key)) continue;
      final source = d.chunks.chunks
          .where((c) => c.chunkKey == key)
          .firstOrNull;
      if (source == null) continue;
      final result = compilePolygonTerrainRuntimeChunkSource(
        prefabSourcePath: 'prefab_defs.json',
        prefabContents:
            d.dependencies['assets/authoring/level/prefab_defs.json']!,
        tileSourcePath: 'tile_defs.json',
        tileContents: d.dependencies['assets/authoring/level/tile_defs.json']!,
        chunkSourcePath: key,
        chunkContents: ChunkV2FileCodec.encode(source),
        requireEncounterReadiness: false,
      );
      if (result.chunk != null) _compiled[key] = result.chunk!;
    }
    _markerEditing.bind(d, Map.of(_compiled));
  }

  void _changed() {
    if (!mounted) return;
    _refresh();
    setState(() {});
    widget.onShellStateChanged?.call();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _play.removeListener(_changed);
    _play.dispose();
    _markerEditing.removeListener(_viewChanged);
    _markerEditing.exact.removeListener(_viewChanged);
    _markerEditing.dispose();
    _search.dispose();
    _panels.dispose();
    super.dispose();
  }

  void _edit(Map<String, Object?> json) {
    final d = _doc!;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: CampaignDomainPlugin.replaceMission,
        payload: {
          'id': d.selected.id,
          'expectedRevision': d.selected.revision,
          'mission': json,
        },
      ),
    );
  }

  bool _finishDraft() =>
      _markerEditing.finishDraft() &&
      (_missionSettings.currentState?.save() ?? true);

  Map<String, List<WaterRegionData>> _tutorialWaterRegions(
    CampaignDocument document,
  ) => {
    for (final occurrence in document.selected.route)
      occurrence.id:
          document.chunks.chunks
              .where((chunk) => chunk.chunkKey == occurrence.chunkKey)
              .firstOrNull
              ?.waterRegions ??
          const [],
  };

  Future<void> _editTutorial(CampaignTutorialSequence initial) async {
    if (!_finishDraft()) return;
    final document = _doc!;
    Widget preview(String id) {
      final key = document.selected.route
          .firstWhere((c) => c.id == id)
          .chunkKey;
      final chunk = document.chunks.chunks
          .where((c) => c.chunkKey == key)
          .firstOrNull;
      if (chunk == null) {
        return const Center(child: Text('Missing chunk.'));
      }
      return CampaignTutorialWorldPreview(
        root: widget.controller.workspacePath,
        chunk: chunk,
        prefabs: document.chunks.prefabData,
        entries: campaignMarkerEntries(document.selected)
            .where((e) => e.position.missionChunkId == id)
            .toList(),
        terrain: ChunkCompositionPreview.joined(
          workspaceRootPath: widget.controller.workspacePath,
          chunk: chunk,
          prefabData: document.chunks.prefabData,
          tileData: document.chunks.tileData,
          visualBoundsByPrefabKey: document.chunks.visualBoundsByPrefabKey,
          parallaxTheme: null,
        ),
      );
    }

    final tutorial = await showDialog<CampaignTutorialSequence>(
      context: context,
      builder: (_) => initial is CampaignSteppedTutorial
          ? CampaignStepsTutorialDialog(
              tutorial: initial,
              shrines: _tutorialShrines(document),
              enemies: document.selected.placements
                  .whereType<CampaignEnemySource>()
                  .where((e) => e.marker.chancePercent == 100)
                  .toList(),
              missionChunkIds: document.selected.route
                  .map((c) => c.id)
                  .toList(),
              worldPreviewBuilder: preview,
            )
          : CampaignTutorialDialog(
              tutorial: initial,
              missionChunkIds: document.selected.route
                  .map((c) => c.id)
                  .toList(),
              waterRegionsByChunk: _tutorialWaterRegions(document),
              spritesByChunk: _tutorialSprites(document),
              gapsByChunk: _tutorialGaps(document),
              platformsByChunk: _tutorialPlatforms(document),
              worldPreviewBuilder: preview,
            ),
    );
    if (!mounted || tutorial == null || !identical(document, _doc)) return;
    final sequences = [
      for (final sequence in document.selected.tutorialSequences)
        if (sequence.id != tutorial.id) sequence,
      tutorial,
    ]..sort((a, b) => a.trigger.index.compareTo(b.trigger.index));
    _edit(
      document.selected.toJson()..addAll({
        'tutorialSequences': sequences.map((s) => s.toJson()).toList(),
        if (tutorial is CampaignBlessingTutorial)
          'blessingObjectiveShrineId': tutorial.shrineId,
      }),
    );
  }

  void _removeTutorial(CampaignTutorialSequence tutorial) {
    if (!_finishDraft()) return;
    _edit(
      _doc!.selected.toJson()
        ..['tutorialSequences'] = [
          for (final sequence in _doc!.selected.tutorialSequences)
            if (sequence.id != tutorial.id) sequence.toJson(),
        ],
    );
  }

  List<CampaignTutorialShrine> _tutorialShrines(CampaignDocument document) => [
    for (final shrine
        in document.selected.placements.whereType<CampaignShrineSource>())
      ..._resolveTutorialShrine(document, shrine),
  ];

  Iterable<CampaignTutorialShrine> _resolveTutorialShrine(
    CampaignDocument document,
    CampaignShrineSource shrine,
  ) sync* {
    final occurrence = document.selected.route
        .where((r) => r.id == shrine.missionChunkId)
        .firstOrNull;
    final chunk = _compiled[occurrence?.chunkKey];
    if (chunk == null) return;
    try {
      yield campaignTutorialShrine(
        shrine.bindingFor(occurrence!.chunkKey),
        chunk.stagedTerrain,
        chunk.pattern.visualSprites,
      );
    } on StateError {
      // An invalid attachment stays unavailable until repaired in Markers.
    }
  }

  Map<String, List<ChunkVisualSpriteRel>> _tutorialSprites(
    CampaignDocument document,
  ) => {
    for (final occurrence in document.selected.route)
      occurrence.id:
          _compiled[occurrence.chunkKey]?.pattern.visualSprites ?? const [],
  };

  Map<String, List<CampaignTutorialGap>> _tutorialGaps(
    CampaignDocument document,
  ) => {
    for (final occurrence in document.selected.route)
      occurrence.id: _compiled[occurrence.chunkKey] == null
          ? const []
          : campaignTutorialGaps(_compiled[occurrence.chunkKey]!.stagedTerrain),
  };

  Map<String, List<CampaignTutorialPlatform>> _tutorialPlatforms(
    CampaignDocument document,
  ) => {
    for (final occurrence in document.selected.route)
      occurrence.id: _compiled[occurrence.chunkKey] == null
          ? const []
          : campaignTutorialPlatforms(
              _compiled[occurrence.chunkKey]!.stagedTerrain,
              _compiled[occurrence.chunkKey]!.pattern.visualSprites,
            ),
  };

  void _setInitialTutorialHud(Set<TutorialHudElement> elements) {
    if (!_finishDraft()) return;
    _edit(
      _doc!.selected.toJson()
        ..['initialTutorialHud'] = elements.map((e) => e.name).toList(),
    );
  }

  Future<void> _missionRewards() async {
    if (!_finishDraft()) return;
    final d = _doc!;
    final value = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => CampaignRewardsDialog.mission(mission: d.selected),
    );
    if (mounted && value != null && identical(d, _doc)) {
      _edit(d.selected.toJson()..addAll(value));
    }
  }

  Future<void> _chapterRewards(CampaignChapterSource chapter) async {
    if (!_finishDraft()) return;
    final d = _doc!;
    final value = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => CampaignRewardsDialog.chapter(chapter: chapter),
    );
    if (!mounted || value == null || !identical(d, _doc)) return;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: CampaignDomainPlugin.setChapterReward,
        payload: {
          'id': chapter.id,
          'expectedRewards': chapter.rewardsToJson(),
          'rewards': value,
        },
      ),
    );
  }

  Future<void> _deleteMission() async {
    if (!_finishDraft()) return;
    final d = _doc!;
    final mission = d.selected;
    final confirmed = await confirmEditorDelete(
      context,
      subject: 'mission',
      name: mission.title['en']!,
      message: 'Delete this mission from the chapter? Later missions move up in the order. Use Save to write the change.',
    );
    if (!mounted || !confirmed || !identical(d, _doc)) return;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: CampaignDomainPlugin.deleteMission,
        payload: {
          'id': mission.id,
          'expectedMission': mission.toJson(),
          'confirmedName': mission.title['en']!,
        },
      ),
    );
  }

  Future<void> _chapterSettings([CampaignChapterSource? chapter]) async {
    if (!_finishDraft()) return;
    final d = _doc!;
    final chapterId = chapter?.id;
    if (chapterId != null) {
      chapter = d.catalog.chapters.firstWhere((entry) => entry.id == chapterId);
    }
    final details = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => CampaignChapterDialog(
        chapter: chapter,
        map: d.catalog.map,
        chapters: d.catalog.chapters,
        campaignTitle: d.catalog.title['en']!,
        workspace: EditorWorkspace(rootPath: widget.controller.workspacePath),
      ),
    );
    if (!mounted || details == null || !identical(d, _doc)) return;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: chapter == null
            ? CampaignDomainPlugin.createChapter
            : CampaignDomainPlugin.editChapter,
        payload: {
          'details': details,
          if (chapter != null) ...{
            'id': chapter.id,
            'expectedChapter': chapter.toJson(),
          },
        },
      ),
    );
  }

  Future<void> _campaignSettings() async {
    if (!_finishDraft()) return;
    final d = _doc!;
    final settings = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => CampaignSettingsDialog(
        catalog: d.catalog,
        workspace: EditorWorkspace(rootPath: widget.controller.workspacePath),
        filePicker: widget.mapFilePicker,
      ),
    );
    if (!mounted || settings == null || !identical(d, _doc)) return;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: CampaignDomainPlugin.editCampaign,
        payload: {
          'expectedSettings': d.catalog.settingsToJson(),
          'settings': settings,
        },
      ),
    );
  }

  Future<void> _previewJournal() async {
    if (!_finishDraft()) return;
    final document = _doc!;
    await showDialog<void>(
      context: context,
      builder: (_) => CampaignJournalPreview(
        catalog: document.catalog,
        missionId: document.selectedMissionId,
      ),
    );
  }

  Future<void> _marker() async {
    if (!_finishDraft()) return;
    final d = _doc!;
    final value = await showDialog<({String kind, Object value})>(
      context: context,
      builder: (_) =>
          CampaignMarkerDialog(mission: d.selected, chunks: _compiled),
    );
    if (!mounted || value == null || !identical(d, _doc)) return;
    final json = d.selected.toJson();
    if (value.kind == 'start' || value.kind == 'exit') {
      json[value.kind] = value.value;
    } else {
      (json[value.kind] as List).add(value.value);
    }
    _edit(json);
  }

  void _add(String chunkKey, {int? after}) {
    if (!_finishDraft()) return;
    final m = _doc!.selected;
    final c = _doc!.chunks.chunks.firstWhere((c) => c.chunkKey == chunkKey);
    final id = nextMissionChunkId(m);
    final json = m.toJson();
    (json['route'] as List).insert(after == null ? m.route.length : after + 1, {
      'id': id,
      'levelId': c.levelId,
      'chunkKey': c.chunkKey,
    });
    _edit(json);
    if (_doc!.selected.route.any((o) => o.id == id)) {
      _selectMissionChunk(id);
    }
  }

  void _move(int from, int to) {
    if (!_finishDraft()) return;
    final json = _doc!.selected.toJson();
    final route = json['route'] as List;
    route.insert(to, route.removeAt(from));
    _edit(json);
  }

  void _remove(int index) {
    if (!_finishDraft()) return;
    final m = _doc!.selected;
    final id = m.route[index].id;
    if (m.tutorialSequences.any((sequence) => sequence.missionChunkId == id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reattach or remove the tutorial sequence on this chunk first.',
          ),
        ),
      );
      return;
    }
    if (m.start?.missionChunkId == id ||
        m.exit?.origin.missionChunkId == id ||
        m.collectibles.any((p) => p.missionChunkId == id) ||
        m.requiredRegions.any((r) => r.origin.missionChunkId == id) ||
        m.placements.any((p) => p.missionChunkId == id) ||
        m.requiredEnemies.any((e) => e.missionChunkId == id) ||
        m.requiredRescues.any((e) => e.missionChunkId == id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Remove or replace the mission markers on this mission chunk first.',
          ),
        ),
      );
      return;
    }
    final json = m.toJson();
    (json['route'] as List).removeAt(index);
    _edit(json);
  }

  Future<void> _startPlay({bool configure = true}) async {
    if (_play.locksEditor) return;
    if (!_finishDraft()) return;
    final d = _doc;
    if (d == null) return;
    final controller = widget.controller;
    final workspace = controller.workspacePath;
    bool current() =>
        mounted &&
        identical(controller, widget.controller) &&
        workspace == widget.controller.workspacePath &&
        identical(d, widget.controller.document);
    if (configure &&
        !await _play.configure(
          context: context,
          title: 'Play mission',
          source: d,
          isSourceCurrent: current,
        )) {
      return;
    }
    if (!current()) return;
    await _play.prepare(
      source: d,
      isSourceCurrent: current,
      capture: () => captureCampaignPlaytestPreparationInput(
        document: d,
        workspaceRoot: widget.controller.workspacePath,
      ),
      runner: preparePlaytestInBackground,
    );
  }

  void _viewChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onShellStateChanged?.call();
  }

  void _selectTab(CampaignTab tab) {
    if (!_finishDraft()) return;
    _markerEditing.candidate = null;
    _markerEditing.error = null;
    _tab = tab;
    _viewChanged();
  }

  void _selectChunk(ChunkV2FileData chunk) {
    _selectedChunkKey = chunk.chunkKey;
    _selectedMissionChunkId = null;
    _viewChanged();
  }

  void _selectMissionChunk(String id) {
    _selectionRevision++;
    _selectedMissionChunkId = id;
    _selectedChunkKey = _doc!.selected.route
        .firstWhere((o) => o.id == id)
        .chunkKey;
    _viewChanged();
  }

  Future<void> _openChunk(ChunkV2FileData chunk) async {
    if (!_finishDraft()) return;
    if (_selectedChunkKey != chunk.chunkKey) _selectChunk(chunk);
    await widget.onOpenChunk?.call(
      ChunkCreatorLocation(levelId: chunk.levelId, chunkKey: chunk.chunkKey),
    );
  }

  Widget _chunkPreview(ChunkV2FileData chunk) => ChunkCompositionPreview(
    workspaceRootPath: widget.controller.workspacePath,
    chunk: chunk,
    prefabData: _doc!.chunks.prefabData,
    tileData: _doc!.chunks.tileData,
    visualBoundsByPrefabKey: _doc!.chunks.visualBoundsByPrefabKey,
    parallaxTheme: findParallaxThemeById(
      _doc!.chunks.parallaxThemes,
      _doc!.selected.visualThemeId,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = _doc;
    if (d == null) return const Center(child: Text('Loading campaign…'));
    final chunk = d.chunks.chunks
        .where((c) => c.chunkKey == _selectedChunkKey)
        .firstOrNull;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: _play.locksEditor,
          child: TickerMode(
            enabled: !_play.locksEditor,
            child: ExcludeFocus(
              excluding: _play.locksEditor,
              child: ToolWorkspaceCard(
                child: ToolThreePanelLayout(
                  key: const ValueKey('campaign_workspace_layout'),
                  controller: _panels,
                  firstLabel: 'Chapters',
                  secondLabel: 'Workspace',
                  thirdLabel: _tab == CampaignTab.markers
                      ? 'Authoring'
                      : 'Mission Settings',
                  firstFlex: 3,
                  secondFlex: 8,
                  thirdFlex: 4,
                  minimumWideWidth: 1180,
                  first: _library(d),
                  second: _workspace(d, chunk),
                  third: IndexedStack(
                    index: _tab == CampaignTab.markers ? 1 : 0,
                    sizing: StackFit.expand,
                    children: [
                      ExcludeFocus(
                        excluding: _tab == CampaignTab.markers,
                        child: CampaignInspector(
                          settings: CampaignMissionSettings(
                            key: _missionSettings,
                            document: d,
                            onApply: (mission) => _edit(mission.toJson()),
                            onDraftChanged: _viewChanged,
                          ),
                          chunk: chunk,
                          missionChunkId: _selectedMissionChunkId,
                          usedBy: chunk == null
                              ? const []
                              : d.whereUsed(chunk.chunkKey),
                          onRewards: _missionRewards,
                          onPreviewJournal: _previewJournal,
                          onEditChunk:
                              chunk == null || widget.onOpenChunk == null
                              ? null
                              : () => _openChunk(chunk),
                          diagnostics: [
                            for (final issue in widget.controller.issues.where(
                              (i) => i.ownerKey == d.selected.id,
                            ))
                              issue.message,
                          ],
                        ),
                      ),
                      TickerMode(
                        enabled: _tab == CampaignTab.markers,
                        child: ExcludeFocus(
                          excluding:
                              _tab != CampaignTab.markers || _visualPreview,
                          child: IgnorePointer(
                            ignoring: _visualPreview,
                            child: Opacity(
                              opacity: _visualPreview ? .45 : 1,
                              child: CampaignMarkerPalette(
                                editing: _markerEditing,
                                onLinkTarget: _marker,
                                onPlace: () => _panels.revealPanel(1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_play.locksEditor)
          Positioned.fill(
            child: AuthoredPlaytestOverlay(
              session: _play,
              subject: 'Mission',
              keyPrefix: 'campaign_play',
              onRetry: () {
                _play.stop();
                unawaited(_startPlay(configure: false));
              },
            ),
          ),
      ],
    );
  }

  Widget _library(CampaignDocument d) => ToolPanelCard(
    title: d.catalog.title['en']!,
    bodyMode: ToolPanelBodyMode.expanded,
    child: ListView(
      key: const ValueKey('campaign_library'),
      children: [
        OutlinedButton.icon(
          onPressed: _campaignSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Campaign settings'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: d.catalog.chapters.length < 32
              ? () => _chapterSettings()
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Create chapter'),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < d.catalog.chapters.length; i++)
          CampaignChapterSection(
            key: ValueKey(d.catalog.chapters[i].id),
            chapter: d.catalog.chapters[i],
            number: i + 1,
            selectedMissionId: d.selected.id,
            onSettings: () => _chapterSettings(d.catalog.chapters[i]),
            onRewards: () => _chapterRewards(d.catalog.chapters[i]),
            onDeleteMission: _deleteMission,
            onAddMission: () {
              if (!_finishDraft()) return;
              widget.controller.applyCommand(
                AuthoringCommand(
                  kind: CampaignDomainPlugin.addMission,
                  payload: {'id': d.catalog.chapters[i].id},
                ),
              );
            },
            onSelectMission: (id) {
              if (!_finishDraft()) return;
              widget.controller.applyCommand(
                AuthoringCommand(
                  kind: CampaignDomainPlugin.selectMission,
                  payload: {'id': id},
                ),
              );
            },
            onReorderMission: (id, target) {
              if (!_finishDraft()) return;
              widget.controller.applyCommand(
                AuthoringCommand(
                  kind: CampaignDomainPlugin.reorderMission,
                  payload: {'id': id, 'targetIndex': target},
                ),
              );
            },
          ),
      ],
    ),
  );

  Widget _workspace(CampaignDocument d, ChunkV2FileData? chunk) {
    final m = d.selected;
    return CampaignWorkspace(
      editingScene: _tab == CampaignTab.markers,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.title['en']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: _tab == CampaignTab.markers
                    ? 'Show marker authoring'
                    : 'Show mission settings',
                onPressed: () => _panels.revealPanel(2),
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _startPlay,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play mission (F5)'),
              ),
              Text(
                '${m.route.length} / ${CampaignMissionDefinition.maxMissionChunks} chunks',
              ),
            ],
          ),
        ],
      ),
      preview: ToolPanelCard(
        key: const ValueKey('campaign_persistent_preview'),
        title: _tab == CampaignTab.contents && chunk != null
            ? 'Chunk preview · ${chunk.chunkKey}'
            : 'Mission route preview',
        bodyMode: ToolPanelBodyMode.expanded,
        child: IndexedStack(
          index: _tab == CampaignTab.contents && chunk != null ? 0 : 1,
          sizing: StackFit.expand,
          children: [
            TickerMode(
              enabled: _tab == CampaignTab.contents,
              child: chunk == null
                  ? const SizedBox.shrink()
                  : _chunkPreview(chunk),
            ),
            TickerMode(
              enabled: _tab != CampaignTab.contents || chunk == null,
              child: ExcludeFocus(
                excluding: _tab == CampaignTab.contents && chunk != null,
                child: CampaignOverview(
                  key: ValueKey(m.id),
                  mission: m,
                  chunks: d.chunks,
                  workspaceRootPath: widget.controller.workspacePath,
                  selectedMissionChunkId: _selectedMissionChunkId,
                  selectionRevision: _selectionRevision,
                  editing: _tab == CampaignTab.markers ? _markerEditing : null,
                  showControls: _tab == CampaignTab.markers,
                  visualPreview: _visualPreview,
                  onVisualPreviewChanged: (value) {
                    if (!_finishDraft()) return;
                    _markerEditing.candidate = null;
                    setState(() => _visualPreview = value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      tabs: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<CampaignTab>(
          key: const ValueKey('campaign_workspace_tabs'),
          segments: const [
            ButtonSegment(
              value: CampaignTab.contents,
              icon: Icon(Icons.grid_view),
              label: Text('Contents'),
            ),
            ButtonSegment(
              value: CampaignTab.route,
              icon: Icon(Icons.view_timeline_outlined),
              label: Text('Route'),
            ),
            ButtonSegment(
              value: CampaignTab.markers,
              icon: Icon(Icons.flag_outlined),
              label: Text('Markers'),
            ),
            ButtonSegment(
              value: CampaignTab.tutorials,
              icon: Icon(Icons.lightbulb_outline),
              label: Text('Tutorial sequences'),
            ),
          ],
          selected: {_tab},
          showSelectedIcon: false,
          onSelectionChanged: (values) => _selectTab(values.single),
        ),
      ),
      content: IndexedStack(
        index: _tab.index,
        children: [
          TickerMode(
            enabled: _tab == CampaignTab.contents,
            child: ExcludeFocus(
              excluding: _tab != CampaignTab.contents,
              child: CampaignContents(
                chunks: d.chunks.chunks,
                searchController: _search,
                groupFilter: _groupFilter,
                difficultyFilter: _difficultyFilter,
                onGroupFilterChanged: (value) {
                  _groupFilter = value;
                  _viewChanged();
                },
                onDifficultyFilterChanged: (value) {
                  _difficultyFilter = value;
                  _viewChanged();
                },
                onClearFilters: () {
                  _groupFilter = '';
                  _difficultyFilter = '';
                  _search.clear();
                  _viewChanged();
                },
                selectedChunkKey: _selectedChunkKey,
                onSelected: _selectChunk,
                onAppend:
                    m.route.length >= CampaignMissionDefinition.maxMissionChunks
                    ? null
                    : (chunk) => _add(chunk.chunkKey),
                onEdit: widget.onOpenChunk == null ? null : _openChunk,
                previewBuilder: _chunkPreview,
              ),
            ),
          ),
          CampaignRoute(
            mission: m,
            selectedMissionChunkId: _selectedMissionChunkId,
            onSelected: _selectMissionChunk,
            onMove: _move,
            onDuplicate: (i) {
              final json = duplicateCampaignMissionChunk(m, i);
              _edit(json);
              _selectMissionChunk(
                (json['route'] as List)[i + 1]['id'] as String,
              );
            },
            onRemove: _remove,
            onEdit: widget.onOpenChunk == null
                ? null
                : (i) {
                    _selectMissionChunk(m.route[i].id);
                    widget.onOpenChunk!(
                      ChunkCreatorLocation(
                        levelId: m.route[i].levelId,
                        chunkKey: m.route[i].chunkKey,
                      ),
                    );
                  },
            onBrowse: () => _selectTab(CampaignTab.contents),
          ),
          const SizedBox.shrink(),
          CampaignTutorialSequences(
            waterRegionsByChunk: _tutorialWaterRegions(_doc!),
            spritesByChunk: _tutorialSprites(_doc!),
            gapsByChunk: _tutorialGaps(_doc!),
            platformsByChunk: _tutorialPlatforms(_doc!),
            shrines: _tutorialShrines(_doc!),
            mission: m,
            onEdit: _editTutorial,
            onRemove: _removeTutorial,
            onInitialHudChanged: _setInitialTutorialHud,
            onPreview: _startPlay,
          ),
        ],
      ),
    );
  }
}
