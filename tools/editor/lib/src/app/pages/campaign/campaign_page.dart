import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:tool_ui/tool_ui.dart';

import '../../../campaign/campaign_domain_plugin.dart';
import '../../../chunks/chunk_v2_file_codec.dart';
import '../../../domain/authoring_types.dart';
import '../../../playtest/authored_playtest_preparation.dart';
import '../../../session/editor_session_controller.dart';
import '../chunkCreator/chunk_creator_location.dart';
import '../shared/authored_playtest_session.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_page_navigation_state.dart';
import 'campaign_edit_dialogs.dart';

final class CampaignLocation extends EditorPageLocation {
  const CampaignLocation(this.missionId);
  final String missionId;
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
    this.onShellStateChanged,
  });
  final EditorSessionController controller;
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
  String _search = '';
  @override
  EditorPageLocation? get navigationLocation =>
      _doc == null ? null : CampaignLocation(_doc!.selectedMissionId);
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
    final value = await showDialog<({String? characterId})>(
      context: context,
      builder: (_) => CampaignChapterRewardsDialog(chapter: chapter),
    );
    if (!mounted || value == null || !identical(d, _doc)) return;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: CampaignDomainPlugin.setChapterReward,
        payload: {
          'id': chapter.id,
          'expectedRewardCharacterId': chapter.rewardCharacterId,
          'rewardCharacterId': value.characterId,
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

  @override
  Widget build(BuildContext context) {
    final d = _doc;
    if (d == null) return const Center(child: Text('Loading campaign…'));
    final m = d.selected;
    final route = m.route;
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 280,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final chapter in d.catalog.chapters) ...[
                    Text(
                      chapter.title['en']!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(chapter.description['en']!),
                    Text(
                      'Chapter reward: ${chapter.rewardCharacterId == null ? 'None' : 'Willow'} · ${chapter.missions.fold<int>(0, (sum, m) => sum + m.firstClearXp)} XP',
                    ),
                    OutlinedButton(
                      onPressed: () => _chapterRewards(chapter),
                      child: const Text('Chapter rewards'),
                    ),
                    for (var i = 0; i < chapter.missions.length; i++)
                      ListTile(
                        selected: chapter.missions[i].id == m.id,
                        title: Text(
                          '${i + 1}. ${chapter.missions[i].title['en']}',
                        ),
                        subtitle: Text(
                          chapter.missions[i].includeInBuild
                              ? 'Included · previous mission required'
                              : 'Draft · excluded from Build',
                        ),
                        onTap: () => widget.controller.applyCommand(
                          AuthoringCommand(
                            kind: CampaignDomainPlugin.selectMission,
                            payload: {'id': chapter.missions[i].id},
                          ),
                        ),
                        trailing: i == 0
                            ? null
                            : IconButton(
                                tooltip: 'Move mission earlier',
                                icon: const Icon(Icons.arrow_upward),
                                onPressed: () => widget.controller.applyCommand(
                                  AuthoringCommand(
                                    kind: CampaignDomainPlugin.reorderMission,
                                    payload: {
                                      'id': chapter.missions[i].id,
                                      'targetIndex': i - 1,
                                    },
                                  ),
                                ),
                              ),
                      ),
                  ],
                  const Divider(),
                  const Text('Chunk library'),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Owner, group, tier or key',
                    ),
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  ),
                  for (final c in d.chunks.chunks.where(
                    (c) =>
                        '${c.levelId} ${c.assemblyGroupId} ${c.difficulty} ${c.chunkKey} ${c.usage}'
                            .toLowerCase()
                            .contains(_search),
                  ))
                    ListTile(
                      dense: true,
                      title: Text(c.chunkKey),
                      subtitle: Text(
                        '${c.usage} · ${c.difficulty} · ${c.status}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Append occurrence',
                        onPressed: route.length >= 16
                            ? null
                            : () => _add(c.chunkKey),
                        icon: const Icon(Icons.add),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ToolPanelCard(
                    title: m.title['en']!,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(m.description['en']!),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: _settings,
                              child: const Text('Mission settings'),
                            ),
                            OutlinedButton(
                              onPressed: route.isEmpty ? null : _marker,
                              child: const Text(
                                'Place start / exit / objective',
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _startPlay,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play mission (F5)'),
                            ),
                          ],
                        ),
                        const Text(
                          'Exact route order · camera follows both directions · no random assembly. Edit shared geometry in Chunk Creator; Copy to Campaign creates an independent layout.',
                        ),
                        SizedBox(
                          height: 150,
                          child: CustomPaint(
                            painter: _CampaignOverview(m, Map.of(_compiled)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < route.length; i++)
                    Card(
                      child: ListTile(
                        title: Text('${i + 1}. ${route[i].chunkKey}'),
                        subtitle: Text(
                          '${route[i].id} · used by ${d.whereUsed(route[i].chunkKey).join(', ')}',
                        ),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Move left',
                              onPressed: i == 0 ? null : () => _move(i, i - 1),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            IconButton(
                              tooltip: 'Move right',
                              onPressed: i == route.length - 1
                                  ? null
                                  : () => _move(i, i + 1),
                              icon: const Icon(Icons.arrow_forward),
                            ),
                            IconButton(
                              tooltip: 'Duplicate occurrence',
                              onPressed: route.length >= 16
                                  ? null
                                  : () => _add(route[i].chunkKey, after: i),
                              icon: const Icon(Icons.copy),
                            ),
                            IconButton(
                              tooltip: 'Edit shared chunk / copy mode',
                              onPressed: widget.onOpenChunk == null
                                  ? null
                                  : () => widget.onOpenChunk!(
                                      ChunkCreatorLocation(
                                        levelId: route[i].levelId,
                                        chunkKey: route[i].chunkKey,
                                      ),
                                    ),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              tooltip: 'Remove occurrence',
                              onPressed: () => _remove(i),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Text(
                    'Mission markers',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final key in [
                    'start',
                    'exit',
                    'collectibles',
                    'requiredRegions',
                    'requiredEnemies',
                    'requiredRescues',
                  ])
                    ..._markers(key, m.toJson()[key]),
                  for (final issue in widget.controller.issues.where(
                    (i) => i.ownerKey == m.id,
                  ))
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(issue.message),
                    ),
                ],
              ),
            ),
          ],
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

/// Read-only assembled overview. Detailed geometry input stays in the shared
/// Chunk Creator viewport, including its established pan/zoom/grid controls.
class _CampaignOverview extends CustomPainter {
  _CampaignOverview(this.mission, this.chunks);
  final CampaignMissionSource mission;
  final Map<String, PolygonTerrainRuntimeChunk> chunks;
  @override
  void paint(Canvas canvas, Size size) {
    if (mission.route.isEmpty) return;
    final scale = (size.width / (mission.route.length * 600)).clamp(
      0.01,
      size.height / 270,
    );
    canvas.save();
    canvas.scale(scale);
    for (var i = 0; i < mission.route.length; i++) {
      final chunk = chunks[mission.route[i].chunkKey];
      for (final polygon in chunk?.compiled.geometry.polygons ?? []) {
        final path = Path();
        for (var j = 0; j < polygon.vertices.length; j++) {
          final v = polygon.vertices[j];
          final x = v.xTicks / 1024 + i * 600;
          final y = v.yTicks / 1024;
          if (j == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path..close(), Paint()..color = Colors.blueGrey);
      }
      canvas.drawLine(
        Offset(i * 600.0, 0),
        Offset(i * 600.0, 270),
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 1 / scale,
      );
    }
    for (final region in [
      if (mission.exit != null) mission.exit!,
      ...mission.requiredRegions,
    ]) {
      final i = mission.route.indexWhere(
        (o) => o.id == region.origin.occurrenceId,
      );
      if (i >= 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            i * 600 + region.origin.x,
            region.origin.y,
            region.width,
            region.height,
          ),
          Paint()..color = Colors.green.withValues(alpha: .3),
        );
      }
    }
    for (final point in [
      if (mission.start != null) mission.start!,
      ...mission.collectibles,
    ]) {
      final i = mission.route.indexWhere((o) => o.id == point.occurrenceId);
      if (i >= 0) {
        canvas.drawCircle(
          Offset(i * 600 + point.x, point.y),
          5 / scale,
          Paint()..color = Colors.amber,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CampaignOverview oldDelegate) =>
      !identical(mission, oldDelegate.mission) || chunks != oldDelegate.chunks;
}
