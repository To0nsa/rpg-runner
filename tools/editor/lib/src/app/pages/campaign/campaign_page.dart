import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:tool_ui/tool_ui.dart';

import '../../../campaign/campaign_domain_plugin.dart';
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
import 'campaign_chapter_dialog.dart';
import 'campaign_chapter_section.dart';
import 'campaign_edit_dialogs.dart';
import 'campaign_chapter_rewards_dialog.dart';
import 'campaign_contents.dart';
import 'campaign_route.dart';
import 'campaign_inspector.dart';
import 'campaign_overview.dart';

enum CampaignTab { contents, route, markers }

final class CampaignLocation extends EditorPageLocation {
  const CampaignLocation(
    this.missionId, {
    this.tab = CampaignTab.contents,
    this.chunkSearch = '',
    this.selectedChunkKey,
    this.selectedOccurrenceId,
  });
  final String missionId;
  final CampaignTab tab;
  final String chunkSearch;
  final String? selectedChunkKey, selectedOccurrenceId;
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
  });
  final EditorSessionController controller;
  final CampaignLocation? initialLocation;
  final Future<bool> Function(ChunkCreatorLocation)? onOpenChunk;
  final VoidCallback? onShellStateChanged;
  @override
  State<CampaignPage> createState() => _CampaignPageState();
}

class _CampaignPageState extends State<CampaignPage>
    implements
        EditorPageNavigationState,
        EditorPageSaveHandler,
        EditorPagePlaytestHandler {
  final _play = AuthoredPlaytestSession();
  CampaignDocument? _doc;
  final _compiled = <String, PolygonTerrainRuntimeChunk>{};
  final _panels = ToolThreePanelController();
  late final _search = TextEditingController(
    text: widget.initialLocation?.chunkSearch ?? '',
  );
  late CampaignTab _tab = widget.initialLocation?.tab ?? CampaignTab.contents;
  late String? _selectedChunkKey = widget.initialLocation?.selectedChunkKey;
  late String? _selectedOccurrenceId =
      widget.initialLocation?.selectedOccurrenceId;
  @override
  EditorPageLocation? get navigationLocation => _doc == null
      ? null
      : CampaignLocation(
          _doc!.selectedMissionId,
          tab: _tab,
          chunkSearch: _search.text,
          selectedChunkKey: _selectedChunkKey,
          selectedOccurrenceId: _selectedOccurrenceId,
        );
  @override
  bool get locksEditorShell => _play.locksEditor;
  @override
  bool handlePlaytestShortcut(LogicalKeyboardKey key) {
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
      widget.controller.pendingChanges.hasChanges;
  @override
  Future<EditorPageSaveResult> saveEditorPage() async {
    if (_play.locksEditor) return EditorPageSaveResult.blocked;
    await widget.controller.exportDirectWrite();
    return EditorPageSaveResult.fromSession(widget.controller);
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(_viewChanged);
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
        !d.selected.route.any((o) => o.id == _selectedOccurrenceId)) {
      _selectedOccurrenceId = null;
    }
    if (_selectedOccurrenceId != null) {
      _selectedChunkKey = d.selected.route
          .firstWhere((o) => o.id == _selectedOccurrenceId)
          .chunkKey;
    }
    if (!d.chunks.chunks.any((c) => c.chunkKey == _selectedChunkKey)) {
      _selectedChunkKey = null;
    }
    _doc = d;
    _play.reconcileSource(d);
    _compiled.clear();
    for (final key in d.selected.route.map((o) => o.chunkKey).toSet()) {
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

  Future<void> _settings() async {
    final d = _doc!;
    final value = await showDialog<CampaignMissionSource>(
      context: context,
      builder: (_) => CampaignMissionSettingsDialog(document: d),
    );
    if (mounted && value != null && identical(d, _doc)) _edit(value.toJson());
  }

  Future<void> _chapterRewards(CampaignChapterSource chapter) async {
    final d = _doc!;
    final value = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => CampaignChapterRewardsDialog(chapter: chapter),
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

  Future<void> _chapterSettings([CampaignChapterSource? chapter]) async {
    final d = _doc!;
    final details = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => CampaignChapterDialog(chapter: chapter),
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

  Future<void> _marker() async {
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
    final m = _doc!.selected;
    final c = _doc!.chunks.chunks.firstWhere((c) => c.chunkKey == chunkKey);
    var index = 1;
    while (m.route.any((o) => o.id == 'occurrence_$index')) {
      index++;
    }
    final json = m.toJson();
    (json['route'] as List).insert(after == null ? m.route.length : after + 1, {
      'id': 'occurrence_$index',
      'levelId': c.levelId,
      'chunkKey': c.chunkKey,
    });
    _edit(json);
    if (_doc!.selected.route.any((o) => o.id == 'occurrence_$index')) {
      _tab = CampaignTab.route;
      _selectOccurrence('occurrence_$index');
    }
  }

  void _move(int from, int to) {
    final json = _doc!.selected.toJson();
    final route = json['route'] as List;
    route.insert(to, route.removeAt(from));
    _edit(json);
  }

  void _remove(int index) {
    final m = _doc!.selected;
    final id = m.route[index].id;
    if (m.start?.occurrenceId == id ||
        m.exit?.origin.occurrenceId == id ||
        m.collectibles.any((p) => p.occurrenceId == id) ||
        m.requiredRegions.any((r) => r.origin.occurrenceId == id) ||
        m.requiredEnemies.any((e) => e.occurrenceId == id) ||
        m.requiredRescues.any((e) => e.occurrenceId == id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Remove or replace the mission markers on this occurrence first.',
          ),
        ),
      );
      return;
    }
    final json = m.toJson();
    (json['route'] as List).removeAt(index);
    _edit(json);
  }

  Future<void> _startPlay() async {
    final d = _doc;
    if (d == null) return;
    await _play.prepare(
      source: d,
      isSourceCurrent: () => identical(d, widget.controller.document),
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
    _tab = tab;
    _viewChanged();
  }

  void _selectChunk(ChunkV2FileData chunk) {
    _selectedChunkKey = chunk.chunkKey;
    _selectedOccurrenceId = null;
    _viewChanged();
  }

  void _selectOccurrence(String id) {
    _selectedOccurrenceId = id;
    _selectedChunkKey = _doc!.selected.route
        .firstWhere((o) => o.id == id)
        .chunkKey;
    _viewChanged();
  }

  Future<void> _openChunk(ChunkV2FileData chunk) async {
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
                  thirdLabel: 'Settings',
                  firstFlex: 3,
                  secondFlex: 8,
                  thirdFlex: 4,
                  minimumWideWidth: 1180,
                  first: _library(d),
                  second: _workspace(d, chunk),
                  third: CampaignInspector(
                    mission: d.selected,
                    chunk: chunk,
                    occurrenceId: _selectedOccurrenceId,
                    usedBy: chunk == null
                        ? const []
                        : d.whereUsed(chunk.chunkKey),
                    onSettings: _settings,
                    onEditChunk: chunk == null || widget.onOpenChunk == null
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
                unawaited(_startPlay());
              },
            ),
          ),
      ],
    );
  }

  Widget _library(CampaignDocument d) => ToolPanelCard(
    title: 'Campaign',
    bodyMode: ToolPanelBodyMode.expanded,
    child: ListView(
      key: const ValueKey('campaign_library'),
      children: [
        FilledButton.icon(
          onPressed: d.catalog.chapters.length < 32
              ? () => _chapterSettings()
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Create chapter'),
        ),
        for (var i = 0; i < d.catalog.chapters.length; i++)
          CampaignChapterSection(
            key: ValueKey(d.catalog.chapters[i].id),
            chapter: d.catalog.chapters[i],
            number: i + 1,
            selectedMissionId: d.selected.id,
            onSettings: () => _chapterSettings(d.catalog.chapters[i]),
            onRewards: () => _chapterRewards(d.catalog.chapters[i]),
            onAddMission: () => widget.controller.applyCommand(
              AuthoringCommand(
                kind: CampaignDomainPlugin.addMission,
                payload: {'id': d.catalog.chapters[i].id},
              ),
            ),
            onSelectMission: (id) => widget.controller.applyCommand(
              AuthoringCommand(
                kind: CampaignDomainPlugin.selectMission,
                payload: {'id': id},
              ),
            ),
            onReorderMission: (id, target) => widget.controller.applyCommand(
              AuthoringCommand(
                kind: CampaignDomainPlugin.reorderMission,
                payload: {'id': id, 'targetIndex': target},
              ),
            ),
          ),
      ],
    ),
  );

  Widget _workspace(CampaignDocument d, ChunkV2FileData? chunk) {
    final m = d.selected;
    return ToolPreviewWorkspace(
      scrollKey: const PageStorageKey('campaign_workspace_scroll'),
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
                tooltip: 'Show mission settings',
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
              Text('${m.route.length} / 16 chunks'),
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
        child: _tab == CampaignTab.contents && chunk != null
            ? _chunkPreview(chunk)
            : m.route.isEmpty
            ? const Center(
                child: Text('Add chunks from Contents to build this mission.'),
              )
            : CampaignOverview(
                key: ValueKey(m.id),
                mission: m,
                chunks: d.chunks,
                workspaceRootPath: widget.controller.workspacePath,
              ),
      ),
      tabs: SegmentedButton<CampaignTab>(
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
        ],
        selected: {_tab},
        showSelectedIcon: false,
        onSelectionChanged: (values) => _selectTab(values.single),
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
                selectedChunkKey: _selectedChunkKey,
                onSelected: _selectChunk,
                onAppend: m.route.length >= 16
                    ? null
                    : (chunk) => _add(chunk.chunkKey),
                onEdit: widget.onOpenChunk == null ? null : _openChunk,
                previewBuilder: _chunkPreview,
              ),
            ),
          ),
          CampaignRoute(
            mission: m,
            selectedOccurrenceId: _selectedOccurrenceId,
            onSelected: _selectOccurrence,
            onMove: _move,
            onDuplicate: (i) => _add(m.route[i].chunkKey, after: i),
            onRemove: _remove,
            onEdit: widget.onOpenChunk == null
                ? null
                : (i) {
                    _selectOccurrence(m.route[i].id);
                    widget.onOpenChunk!(
                      ChunkCreatorLocation(
                        levelId: m.route[i].levelId,
                        chunkKey: m.route[i].chunkKey,
                      ),
                    );
                  },
            onBrowse: () => _selectTab(CampaignTab.contents),
          ),
          ListView(
            key: const PageStorageKey('campaign_markers_scroll'),
            padding: const EdgeInsets.all(12),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: m.route.isEmpty ? null : _marker,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Place start / exit / objective'),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Mission markers'),
              for (final key in [
                'start',
                'exit',
                'collectibles',
                'requiredRegions',
                'requiredEnemies',
                'requiredRescues',
              ])
                ..._markers(key, m.toJson()[key]),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _markers(String key, Object? value) {
    final entries = value is List ? value : [?value];
    return [
      for (var i = 0; i < entries.length; i++)
        ListTile(
          dense: true,
          title: Text('$key · ${entries[i]}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove marker',
            onPressed: () {
              final json = _doc!.selected.toJson();
              if (json[key] is List) {
                (json[key] as List).removeAt(i);
              } else {
                json[key] = null;
              }
              _edit(json);
            },
          ),
        ),
    ];
  }
}
