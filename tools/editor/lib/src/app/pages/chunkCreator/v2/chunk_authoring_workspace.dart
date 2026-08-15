import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../../../../chunks/chunk_v2_actor_terrain_projection.dart';
import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_compiled_edge_inspection.dart';
import '../../../../chunks/chunk_v2_composition_operation.dart';
import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../../../chunks/chunk_domain_plugin.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_lifecycle_commit.dart';
import '../../../../chunks/chunk_v2_marker_placement_projection.dart';
import '../../../../chunks/chunk_v2_metadata_commit.dart';
import '../../../../chunks/chunk_v2_seam_analysis.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../session/editor_session_controller.dart';
import '../../../../terrain_authoring/terrain_axis_aligned_rectangle.dart';
import '../../../../terrain_authoring/terrain_half_pixel_text.dart';
import '../../../../terrain_authoring/terrain_polygon_duplicate_offset.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_physics_text.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_panel_card.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_workspace_card.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/terrain_material_preview.dart';
import '../../shared/terrain_polygon_rectangle_editor.dart';
import '../../shared/terrain_material_preview_catalog.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import '../../shared/terrain_polygon_vertex_editor.dart';
import 'chunk_actor_terrain_overlay_painter.dart';
import 'chunk_compiled_edge_overlay_painter.dart';
import 'chunk_expanded_collision_overlay_painter.dart';
import 'chunk_marker_placement_overlay_painter.dart';
import 'chunk_marker_scene_gesture.dart';
import 'chunk_polygon_authoring_controller.dart';
import 'chunk_polygon_level_visual_source.dart';
import 'chunk_prefab_scene_gesture.dart';
import 'chunk_scene_coordinator.dart';
import 'chunk_scene_surface.dart';
import 'chunk_scene_visual_source.dart';
import 'chunk_composition_card.dart';
import 'chunk_v2_owner_dialog.dart';

/// Normal current-schema workspace for complete Chunk-v2 authoring.
///
/// A complete current v2 tree selects this workspace through the normal plugin
/// loader. Legacy, mixed, or missing source instead opens the fail-closed
/// migration-required workspace. Source apply cannot perform migration.
class ChunkAuthoringWorkspace extends StatefulWidget {
  const ChunkAuthoringWorkspace({
    super.key,
    required this.controller,
    this.onOpenOwningPrefab,
  });

  final EditorSessionController controller;

  /// Opens a read-only expanded shape's stable owner outside this workspace.
  final ValueChanged<String>? onOpenOwningPrefab;

  @override
  State<ChunkAuthoringWorkspace> createState() =>
      ChunkAuthoringWorkspaceState();
}

class ChunkAuthoringWorkspaceState extends State<ChunkAuthoringWorkspace> {
  static const double _initialZoom = 1;
  static const double _minZoom = 0.25;
  static const double _maxZoom = 8;
  static const double _zoomStep = 0.25;
  static const double _gap = 12;
  static const double _minimumWideWorkspaceWidth = 1080;

  ChunkPolygonAuthoringController? _authoring;
  String? _selectedChunkKey;
  double _zoom = _initialZoom;
  Offset _pan = Offset.zero;
  bool _showCompiledEdges = true;
  bool _inspectCompiledEdges = false;
  bool _showActorTerrain = false;
  ChunkV2TerrainActor _selectedTerrainActor = ChunkV2TerrainActor.eloise;
  ChunkV2CollisionExpansion? _actorProjectionExpansion;
  ChunkV2ActorTerrainProjection? _actorTerrainProjection;
  bool _showMarkerPlacements = false;
  ChunkV2MarkerPlacementProjection? _markerPlacementProjection;
  ChunkV2FileData? _markerProjectionChunk;
  ChunkV2ActorTerrainProjection? _markerProjectionTerrain;
  double? _markerProjectionGroundTopY;
  bool _compositionOperationActive = false;
  final ChunkSceneCoordinator _sceneCoordinator = ChunkSceneCoordinator();
  final ChunkPrefabSceneGesture _prefabGesture = ChunkPrefabSceneGesture();
  final ChunkMarkerSceneGesture _markerGesture = ChunkMarkerSceneGesture();
  String? _selectedPrefabCatalogKey;
  String? _selectedMarkerCatalogId;
  Object? _authoringUiFingerprint;
  TerrainMaterialCatalog? _materialCatalog;

  bool get _hasActiveOperation =>
      (_authoring?.hasActiveOperation ?? false) ||
      _compositionOperationActive ||
      _prefabGesture.hasActiveOperation ||
      _markerGesture.hasActiveOperation;

  bool get hasActiveOperation => _hasActiveOperation;

  bool get hasLocalDraftChanges =>
      _hasActiveOperation || widget.controller.pendingChanges.hasChanges;

  bool get canUndo =>
      _prefabGesture.hasActiveOperation ||
      _markerGesture.hasActiveOperation ||
      (!_compositionOperationActive &&
          (_authoring?.canUndo ?? widget.controller.canUndo));

  bool get canRedo =>
      !_prefabGesture.hasActiveOperation &&
      !_markerGesture.hasActiveOperation &&
      !_compositionOperationActive &&
      (_authoring?.canRedo ?? widget.controller.canRedo);

  /// True when the shell may apply the complete Chunk-v2 source set atomically.
  bool get canApplyToFiles =>
      widget.controller.pendingChanges.hasChanges &&
      !_hasActiveOperation &&
      !widget.controller.isLoading &&
      !widget.controller.isExporting;

  bool handleUndoShortcut() {
    if (_prefabGesture.hasActiveOperation) {
      setState(_prefabGesture.cancel);
      return true;
    }
    if (_markerGesture.hasActiveOperation) {
      setState(_markerGesture.cancel);
      return true;
    }
    if (_compositionOperationActive) return false;
    final authoring = _authoring;
    if (authoring != null) return authoring.undo();
    if (!widget.controller.canUndo) return false;
    widget.controller.undo();
    return true;
  }

  bool handleRedoShortcut() {
    if (_prefabGesture.hasActiveOperation ||
        _markerGesture.hasActiveOperation) {
      return false;
    }
    if (_compositionOperationActive) return false;
    final authoring = _authoring;
    if (authoring != null) return authoring.redo();
    if (!widget.controller.canRedo) return false;
    widget.controller.redo();
    return true;
  }

  @override
  void initState() {
    super.initState();
    _reloadMaterialCatalog();
    _selectInitialOwner();
  }

  @override
  void didUpdateWidget(covariant ChunkAuthoringWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _disposeAuthoring();
    _selectedChunkKey = null;
    _reloadMaterialCatalog();
    _selectInitialOwner();
  }

  @override
  void dispose() {
    _disposeAuthoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = _documentOrNull;
    final scene = _sceneOrNull;
    if (document == null || scene == null) {
      return const Center(
        child: Text('Chunk-v2 current scene is no longer loaded.'),
      );
    }
    _reconcileReloadedOwner(scene);
    final authoring = _authoring;
    final issues = authoring == null
        ? const <ValidationIssue>[]
        : _ownerIssues(authoring);
    return EditorWorkspaceCard(
      key: const ValueKey<String>('chunk_authoring_workspace'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(document, scene),
          const SizedBox(height: _gap),
          Expanded(
            child: _ChunkWorkspaceLayout(
              minimumWideWidth: _minimumWideWorkspaceWidth,
              gap: _gap,
              ownerSidebar: _buildChunkOwnerSidebar(
                document,
                scene,
                authoring?.chunk,
              ),
              scene: authoring == null
                  ? _buildEmptyPanel(
                      key: const ValueKey<String>('chunk_creation_scene'),
                      title: 'Chunk creation scene',
                      message:
                          'This level has no chunk owner. Undo the deletion, '
                          'or switch to a level that still has a dimension '
                          'template.',
                    )
                  : _buildScenePanel(scene, authoring),
              sidebar: _buildChunkSidebar(document, scene, authoring, issues),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ChunkV2Document document, ChunkV2Scene scene) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const Chip(
            avatar: Icon(Icons.science_outlined, size: 18),
            label: Text('Chunk v2 authoring'),
          ),
          DropdownButton<String>(
            key: const ValueKey<String>('chunk_polygon_level_selector'),
            value: scene.activeLevelId,
            items: scene.availableLevelIds
                .map(
                  (levelId) => DropdownMenuItem<String>(
                    value: levelId,
                    child: Text(levelId),
                  ),
                )
                .toList(growable: false),
            onChanged: _selectLevel,
          ),
          DropdownButton<String>(
            key: const ValueKey<String>('chunk_polygon_owner_selector'),
            value:
                scene.chunks.any((chunk) => chunk.chunkKey == _selectedChunkKey)
                ? _selectedChunkKey
                : null,
            hint: const Text('No chunk owner'),
            items:
                (List<ChunkV2FileData>.of(scene.chunks)..sort(_compareChunks))
                    .map(
                      (chunk) => DropdownMenuItem<String>(
                        value: chunk.chunkKey,
                        child: Text(chunk.id),
                      ),
                    )
                    .toList(growable: false),
            onChanged: (chunkKey) {
              if (chunkKey != null) _selectOwner(chunkKey);
            },
          ),
          Text(
            document.changedChunkKeys.isEmpty
                ? 'No pending chunk changes'
                : '${document.changedChunkKeys.length} pending chunk change(s)',
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Current-schema workspace: apply rechecks the complete chunk source '
        'set and commits it atomically. Legacy migration stays read-only; '
        'runtime terrain updates after the generated outputs are refreshed.',
        style: TextStyle(color: Color(0xFFFFD166)),
      ),
    ],
  );

  /// Confirms and applies the complete Chunk-v2 source set through the session.
  Future<void> applyToFiles() async {
    if (!canApplyToFiles) return;
    final pendingChanges = widget.controller.pendingChanges;
    if (!pendingChanges.hasChanges) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply Chunk-v2 Changes'),
        content: Text(
          'Write ${pendingChanges.changedItemIds.length} chunk change(s) '
          'across ${pendingChanges.fileDiffs.length} current-schema file(s)?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.controller.exportDirectWrite();
    if (!mounted) return;
    final error = widget.controller.exportError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Chunk-v2 changes applied.'
              : 'Chunk-v2 apply failed: $error',
        ),
      ),
    );
  }

  Widget _buildOwnerPanel(
    ChunkV2Document document,
    ChunkV2Scene scene,
    ChunkV2FileData? selectedChunk, {
    required bool controlsEnabled,
  }) {
    final chunks = List<ChunkV2FileData>.of(scene.chunks)..sort(_compareChunks);
    return EditorSectionCard(
      key: const ValueKey<String>('chunk_owner_section'),
      title: 'Chunk owners',
      collapsible: true,
      expansionKey: const ValueKey<String>('chunk_owner_section_toggle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildOwnerActions(
            document,
            scene,
            selectedChunk: selectedChunk,
            controlsEnabled: controlsEnabled,
          ),
          const Divider(height: 28),
          if (chunks.isEmpty)
            const Text(
              'No chunk owners remain in this level. Creation requires one '
              'existing owner to provide locked tile size and dimensions.',
            ),
          for (final chunk in chunks)
            Builder(
              builder: (context) {
                final expansion = _expansionFor(chunk.chunkKey)?.expansion;
                return EditorListCard(
                  key: ValueKey<String>(
                    'chunk_polygon_owner_${chunk.chunkKey}',
                  ),
                  isSelected: chunk.chunkKey == selectedChunk?.chunkKey,
                  onTap: () => _selectOwner(chunk.chunkKey),
                  trailing: document.changedChunkKeys.contains(chunk.chunkKey)
                      ? const Tooltip(
                          message: 'Pending geometry changed',
                          child: Icon(Icons.circle, size: 12),
                        )
                      : null,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: chunk.chunkKey == selectedChunk?.chunkKey,
                    title: Text(chunk.id),
                    subtitle: Text(
                      '${chunk.difficulty} · ${chunk.width}×${chunk.height} px · '
                      'rev ${chunk.revision}\n${chunk.status} · '
                      '${chunk.collisionShapes.length} direct · '
                      '${expansion?.expandedPrefabShapeCount ?? 0} expanded',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOwnerActions(
    ChunkV2Document document,
    ChunkV2Scene scene, {
    required ChunkV2FileData? selectedChunk,
    required bool controlsEnabled,
  }) {
    final canCreate = controlsEnabled && scene.chunks.isNotEmpty;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        Tooltip(
          message: scene.chunks.isEmpty
              ? 'Creation needs an existing owner in this level to provide '
                    'locked dimensions.'
              : 'Create an empty deprecated owner.',
          child: FilledButton.icon(
            key: const ValueKey<String>('chunk_v2_owner_create'),
            onPressed: canCreate ? () => _createOwner(document) : null,
            icon: const Icon(Icons.add),
            label: const Text('New'),
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('chunk_v2_owner_edit'),
          onPressed: controlsEnabled && selectedChunk != null
              ? () => _editOwner(document, selectedChunk)
              : null,
          icon: const Icon(Icons.tune),
          label: const Text('Edit'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('chunk_v2_owner_duplicate'),
          onPressed: controlsEnabled && selectedChunk != null
              ? () => _duplicateOwner(document, selectedChunk)
              : null,
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Duplicate'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('chunk_v2_owner_rename'),
          onPressed: controlsEnabled && selectedChunk != null
              ? () => _renameOwner(document, selectedChunk)
              : null,
          icon: const Icon(Icons.drive_file_rename_outline),
          label: const Text('Rename'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('chunk_v2_owner_delete'),
          onPressed: controlsEnabled && selectedChunk != null
              ? () => _deleteOwner(document, scene, selectedChunk)
              : null,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
      ],
    );
  }

  Widget _buildEmptyPanel({
    Key? key,
    required String title,
    required String message,
  }) => EditorPanelCard(
    key: key,
    title: title,
    bodyMode: EditorPanelBodyMode.expanded,
    child: Center(child: Text(message)),
  );

  Widget _buildEmptySidebarPanel({
    required Key key,
    required Key expansionKey,
    required String title,
    required String message,
  }) => EditorSectionCard(
    key: key,
    expansionKey: expansionKey,
    title: title,
    collapsible: true,
    child: Text(message),
  );

  Widget _buildChunkSidebar(
    ChunkV2Document document,
    ChunkV2Scene scene,
    ChunkPolygonAuthoringController? authoring,
    List<ValidationIssue> issues,
  ) {
    final controlsEnabled = !_hasActiveOperation;
    return SingleChildScrollView(
      key: const ValueKey<String>('chunk_authoring_sidebar'),
      primary: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EditorPanelCard(
            key: const ValueKey<String>('chunk_terrain_collision_card'),
            title: 'Terrain collision',
            description: controlsEnabled
                ? 'Direct terrain, reachable seams, and diagnostics.'
                : 'Finish or cancel the active terrain edit to change terrain or composition.',
            collapsible: true,
            expansionKey: const ValueKey<String>(
              'chunk_terrain_collision_card_toggle',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (authoring == null) ...<Widget>[
                  _buildEmptySidebarPanel(
                    key: const ValueKey<String>('chunk_polygon_shapes_panel'),
                    expansionKey: const ValueKey<String>(
                      'chunk_polygon_shapes_panel_toggle',
                    ),
                    title: 'Shapes',
                    message: 'Select or create a chunk owner first.',
                  ),
                  const SizedBox(height: _gap),
                  _buildEmptySidebarPanel(
                    key: const ValueKey<String>('chunk_polygon_seams_panel'),
                    expansionKey: const ValueKey<String>(
                      'chunk_polygon_seams_panel_toggle',
                    ),
                    title: 'Reachable chunk seams',
                    message: 'Select or create a chunk owner first.',
                  ),
                  const SizedBox(height: _gap),
                  _buildEmptySidebarPanel(
                    key: const ValueKey<String>(
                      'chunk_polygon_diagnostics_panel',
                    ),
                    expansionKey: const ValueKey<String>(
                      'chunk_polygon_diagnostics_panel_toggle',
                    ),
                    title: 'Diagnostics',
                    message: 'Select or create a chunk owner first.',
                  ),
                ] else ...<Widget>[
                  _buildShapePanel(authoring),
                  const SizedBox(height: _gap),
                  _buildSeamPanel(authoring),
                  const SizedBox(height: _gap),
                  _buildDiagnosticsPanel(authoring, issues),
                ],
              ],
            ),
          ),
          const SizedBox(height: _gap),
          if (authoring == null)
            EditorPanelCard(
              key: const ValueKey<String>('chunk_composition_card'),
              title: 'Layers, prefabs & markers',
              description: 'Layer metadata and placed chunk content.',
              collapsible: true,
              expansionKey: const ValueKey<String>(
                'chunk_composition_card_toggle',
              ),
              child: const Text('Select or create a chunk owner first.'),
            )
          else
            ChunkCompositionCard(
              controller: widget.controller,
              document: document,
              chunk: authoring.chunk,
              controlsEnabled: controlsEnabled,
              onOperationChanged: _setCompositionOperationActive,
              selectedPrefabKey: _sceneCoordinator.selectedPrefabKey,
              selectedMarkerKey: _sceneCoordinator.selectedMarkerKey,
              onPrefabSelected: (selection) => setState(() {
                _prefabGesture.setTool(ChunkPrefabSceneTool.select);
                _sceneCoordinator.selectPrefab(selection);
              }),
              onMarkerSelected: (selection) => setState(() {
                _markerGesture.setTool(ChunkMarkerSceneTool.select);
                _sceneCoordinator.selectMarker(selection);
                _refreshMarkerPlacementProjection();
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildChunkOwnerSidebar(
    ChunkV2Document document,
    ChunkV2Scene scene,
    ChunkV2FileData? selectedChunk,
  ) => SingleChildScrollView(
    key: const ValueKey<String>('chunk_owner_sidebar'),
    primary: false,
    child: _buildOwnerPanel(
      document,
      scene,
      selectedChunk,
      controlsEnabled: !_hasActiveOperation,
    ),
  );

  Widget _buildScenePanel(
    ChunkV2Scene scene,
    ChunkPolygonAuthoringController authoring,
  ) => EditorPanelCard(
    key: const ValueKey<String>('chunk_creation_scene'),
    title: 'Chunk creation scene',
    bodyMode: EditorPanelBodyMode.expanded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FilterChip(
              key: const ValueKey<String>('chunk_compiled_edges_toggle'),
              label: const Text('Compiled edges'),
              selected: _showCompiledEdges,
              onSelected: (selected) {
                setState(() {
                  _showCompiledEdges = selected;
                  if (!selected) {
                    _inspectCompiledEdges = false;
                    _sceneCoordinator.setCompiledEdgeInspection(false);
                  }
                });
              },
            ),
            FilterChip(
              key: const ValueKey<String>('chunk_compiled_edge_inspect_toggle'),
              label: const Text('Inspect edges'),
              selected: _inspectCompiledEdges,
              onSelected: (selected) {
                setState(() {
                  _inspectCompiledEdges = selected;
                  _sceneCoordinator.setCompiledEdgeInspection(selected);
                  if (selected) {
                    _showCompiledEdges = true;
                  }
                });
              },
            ),
            FilterChip(
              key: const ValueKey<String>('chunk_actor_terrain_toggle'),
              label: const Text('Actor terrain'),
              selected: _showActorTerrain,
              onSelected: (selected) {
                setState(() {
                  _showActorTerrain = selected;
                  if (selected) _refreshActorTerrainProjection();
                });
              },
            ),
            FilterChip(
              key: const ValueKey<String>('chunk_marker_placement_toggle'),
              label: const Text('Marker placement'),
              selected: _showMarkerPlacements,
              onSelected: (selected) {
                setState(() {
                  _showMarkerPlacements = selected;
                  if (selected) {
                    _refreshMarkerPlacementProjection();
                  }
                });
              },
            ),
            DropdownButton<ChunkV2TerrainActor>(
              key: const ValueKey<String>('chunk_actor_terrain_selector'),
              value: _selectedTerrainActor,
              items: ChunkV2TerrainActor.values
                  .map(
                    (actor) => DropdownMenuItem<ChunkV2TerrainActor>(
                      value: actor,
                      child: Text(_terrainActorLabel(actor)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _showActorTerrain
                  ? (actor) {
                      if (actor == null) return;
                      setState(() => _selectedTerrainActor = actor);
                    }
                  : null,
            ),
            EditorZoomControls(
              value: _zoom,
              min: _minZoom,
              max: _maxZoom,
              step: _zoomStep,
              sliderWidth: 140,
              onChanged: _setZoom,
            ),
            OutlinedButton.icon(
              onPressed: _resetViewport,
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Reset view'),
            ),
            SegmentedButton<int>(
              key: const ValueKey<String>('chunk_polygon_snap_selector'),
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(value: 2, label: Text('1 px grid')),
                ButtonSegment<int>(value: 1, label: Text('0.5 px')),
              ],
              selected: <int>{authoring.snapPolicy.stepHalfPixels},
              onSelectionChanged: (selection) {
                authoring.setSnapPolicy(
                  selection.single == 1
                      ? const TerrainPolygonSnapPolicy.halfPixel()
                      : TerrainPolygonSnapPolicy.ownerGridPixels(1),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            SegmentedButton<ChunkSceneDomain>(
              key: const ValueKey<String>('chunk_scene_domain_selector'),
              segments: const <ButtonSegment<ChunkSceneDomain>>[
                ButtonSegment<ChunkSceneDomain>(
                  value: ChunkSceneDomain.terrain,
                  label: Text('Terrain'),
                ),
                ButtonSegment<ChunkSceneDomain>(
                  value: ChunkSceneDomain.prefabs,
                  label: Text('Prefabs'),
                ),
                ButtonSegment<ChunkSceneDomain>(
                  value: ChunkSceneDomain.markers,
                  label: Text('Markers'),
                ),
              ],
              selected: <ChunkSceneDomain>{_sceneCoordinator.sourceDomain},
              onSelectionChanged: _hasActiveOperation
                  ? null
                  : (selection) => _selectSceneDomain(selection.single),
            ),
            if (_sceneCoordinator.sourceDomain == ChunkSceneDomain.terrain)
              for (final tool in terrainPolygonSceneToolbarTools)
                ChoiceChip(
                  key: ValueKey<String>('chunk_polygon_tool_${tool.name}'),
                  label: Text(_toolLabel(tool)),
                  selected: authoring.state.tool == tool,
                  onSelected:
                      _inspectCompiledEdges ||
                          (authoring.state.draft == null &&
                              tool == TerrainPolygonTool.createPolygon) ||
                          (authoring.state.draft != null &&
                              tool != TerrainPolygonTool.createPolygon &&
                              tool != TerrainPolygonTool.moveVertex &&
                              tool != TerrainPolygonTool.insertVertex)
                      ? null
                      : (_) => authoring.setTool(tool),
                )
            else if (_sceneCoordinator.sourceDomain ==
                ChunkSceneDomain.prefabs) ...<Widget>[
              for (final tool in ChunkPrefabSceneTool.values)
                ChoiceChip(
                  key: ValueKey<String>('chunk_prefab_tool_${tool.name}'),
                  label: Text(_prefabToolLabel(tool)),
                  selected: _prefabGesture.tool == tool,
                  onSelected:
                      _prefabGesture.hasActiveOperation ||
                          (tool == ChunkPrefabSceneTool.place &&
                              _selectedCatalogPrefab(scene) == null)
                      ? null
                      : (_) => setState(() => _prefabGesture.setTool(tool)),
                ),
              DropdownButton<String>(
                key: const ValueKey<String>('chunk_prefab_catalog_selector'),
                value: _selectedCatalogPrefab(scene)?.prefabKey,
                hint: const Text('No active prefab'),
                items: _activePrefabCatalog(scene)
                    .map(
                      (prefab) => DropdownMenuItem<String>(
                        value: prefab.prefabKey,
                        child: Text(prefab.id),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _prefabGesture.hasActiveOperation
                    ? null
                    : (prefabKey) =>
                          setState(() => _selectedPrefabCatalogKey = prefabKey),
              ),
            ] else ...<Widget>[
              for (final tool in ChunkMarkerSceneTool.values)
                ChoiceChip(
                  key: ValueKey<String>('chunk_marker_tool_${tool.name}'),
                  label: Text(_markerToolLabel(tool)),
                  selected: _markerGesture.tool == tool,
                  onSelected: _markerGesture.hasActiveOperation
                      ? null
                      : (_) => setState(() => _markerGesture.setTool(tool)),
                ),
              DropdownButton<String>(
                key: const ValueKey<String>('chunk_marker_catalog_selector'),
                value: _selectedMarkerCatalogId ?? chunkMarkerEnemyIds.first,
                items: chunkMarkerEnemyIds
                    .map(
                      (markerId) => DropdownMenuItem<String>(
                        value: markerId,
                        child: Text(markerId),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _markerGesture.hasActiveOperation
                    ? null
                    : (markerId) =>
                          setState(() => _selectedMarkerCatalogId = markerId),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _buildExpansionSummary(authoring),
        const SizedBox(height: 4),
        const Text(
          'Direct terrain polygons are filled as an authoring preview only; '
          'Core-compiled edges remain collision and navigation evidence.',
          key: ValueKey<String>('chunk_polygon_source_fill_notice'),
        ),
        const SizedBox(height: 4),
        _buildSeamSummary(authoring),
        if (_showActorTerrain) ...<Widget>[
          const SizedBox(height: 4),
          _buildActorTerrainSummary(),
        ],
        if (_showMarkerPlacements) ...<Widget>[
          const SizedBox(height: 4),
          _buildMarkerPlacementSummary(),
        ],
        const SizedBox(height: 8),
        Text(
          _inspectCompiledEdges
              ? 'Primary input selects the nearest Core-compiled edge. '
                    'Ctrl+drag pans and Ctrl+scroll zooms.'
              : _sceneCoordinator.sourceDomain == ChunkSceneDomain.prefabs
              ? 'Primary input selects the topmost prefab visual. Ctrl+drag '
                    'pans and Ctrl+scroll zooms.'
              : _sceneCoordinator.sourceDomain == ChunkSceneDomain.markers
              ? 'Primary input selects the topmost authored marker anchor. '
                    'Ctrl+drag pans and Ctrl+scroll zooms.'
              : authoring.state.tool == TerrainPolygonTool.createRectangle
              ? 'Drag across opposite corners to draw a rectangle draft. '
                    'Enter saves it and Escape cancels.'
              : 'Primary input follows the selected tool. Ctrl+drag pans, '
                    'Ctrl+scroll zooms, Enter saves a draft, and Escape '
                    'cancels.',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                math.max(1, constraints.maxWidth),
                math.max(1, constraints.maxHeight),
              );
              final chunk = authoring.chunk;
              final expansion = _expansionFor(chunk.chunkKey)?.expansion;
              final actorProjection = _showActorTerrain
                  ? _actorTerrainProjection
                  : null;
              final markerProjection =
                  (_showMarkerPlacements ||
                      _sceneCoordinator.sourceDomain ==
                          ChunkSceneDomain.markers)
                  ? _markerPlacementProjection
                  : null;
              final visualProjection = ChunkSceneVisualProjection.fromChunk(
                chunk: chunk,
                prefabData: scene.prefabData,
                tileData: scene.tileData,
                visualBoundsByPrefabKey: scene.visualBoundsByPrefabKey,
              );
              final hiddenPrefabSourceIndex = _prefabGesture.hiddenSourceIndex;
              final belowTerrainVisuals = visualProjection
                  .belowTerrain(chunk.groundBandZIndex)
                  .where(
                    (placement) =>
                        placement.sourceIndex != hiddenPrefabSourceIndex,
                  )
                  .toList(growable: false);
              final atOrAboveTerrainVisuals = visualProjection
                  .atOrAboveTerrain(chunk.groundBandZIndex)
                  .where(
                    (placement) =>
                        placement.sourceIndex != hiddenPrefabSourceIndex,
                  )
                  .toList(growable: false);
              final prefabCandidate = _prefabGesture.candidate;
              final prefabCandidateVisual = prefabCandidate == null
                  ? null
                  : ChunkSceneVisualProjection.fromChunk(
                      chunk: chunk.copyWith(
                        prefabs: <PlacedPrefabDef>[prefabCandidate],
                      ),
                      prefabData: scene.prefabData,
                      tileData: scene.tileData,
                      visualBoundsByPrefabKey: scene.visualBoundsByPrefabKey,
                    ).placements.single;
              final transform = TerrainPolygonViewportTransform(
                origin:
                    Offset(
                      (size.width - chunk.width * _zoom) * 0.5,
                      (size.height - chunk.height * _zoom) * 0.5,
                    ) +
                    _pan,
                zoom: _zoom,
              );
              return EditorSceneViewportFrame(
                child: ChunkSceneSurface(
                  controller: authoring,
                  transform: transform,
                  activeDomain: _sceneCoordinator.domain,
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ChunkPolygonLevelVisualSource(
                        key: const ValueKey<String>(
                          'chunk_polygon_parallax_background',
                        ),
                        workspaceRootPath: widget.controller.workspacePath,
                        chunk: chunk,
                        parallaxTheme: scene.activeParallaxTheme,
                        transform: transform,
                        layer: ChunkPolygonLevelVisualLayer.background,
                      ),
                      CustomPaint(
                        painter: _ChunkBoundsPainter(
                          chunk: chunk,
                          transform: transform,
                          paintFill: false,
                        ),
                      ),
                      if (belowTerrainVisuals.isNotEmpty)
                        ChunkSceneVisualSource(
                          key: const ValueKey<String>(
                            'chunk_polygon_visual_below_terrain',
                          ),
                          workspaceRootPath: widget.controller.workspacePath,
                          placements: belowTerrainVisuals,
                          transform: transform,
                        ),
                      ListenableBuilder(
                        listenable: authoring,
                        builder: (context, _) => ChunkPolygonLevelVisualSource(
                          key: const ValueKey<String>(
                            'chunk_polygon_terrain_material_preview',
                          ),
                          workspaceRootPath: widget.controller.workspacePath,
                          chunk: chunk,
                          parallaxTheme: scene.activeParallaxTheme,
                          transform: transform,
                          layer: ChunkPolygonLevelVisualLayer.terrain,
                          terrainShapes: authoring.terrainPreviewShapes,
                        ),
                      ),
                      ChunkPolygonLevelVisualSource(
                        key: const ValueKey<String>(
                          'chunk_polygon_parallax_foreground',
                        ),
                        workspaceRootPath: widget.controller.workspacePath,
                        chunk: chunk,
                        parallaxTheme: scene.activeParallaxTheme,
                        transform: transform,
                        layer: ChunkPolygonLevelVisualLayer.foreground,
                      ),
                      if (_expansionFor(chunk.chunkKey)?.expansion
                          case final expansion?)
                        IgnorePointer(
                          child: CustomPaint(
                            key: const ValueKey<String>(
                              'chunk_expanded_collision_overlay',
                            ),
                            painter: ChunkExpandedCollisionOverlayPainter(
                              expansion: expansion,
                              transform: transform,
                            ),
                          ),
                        ),
                    ],
                  ),
                  foreground: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (atOrAboveTerrainVisuals.isNotEmpty)
                        ChunkSceneVisualSource(
                          key: const ValueKey<String>(
                            'chunk_polygon_visual_at_or_above_terrain',
                          ),
                          workspaceRootPath: widget.controller.workspacePath,
                          placements: atOrAboveTerrainVisuals,
                          transform: transform,
                        ),
                      if (_sceneCoordinator.selectedPrefabKey != null &&
                          !_prefabGesture.hasActiveOperation)
                        CustomPaint(
                          key: const ValueKey<String>(
                            'chunk_prefab_selection_overlay',
                          ),
                          painter: ChunkScenePrefabSelectionPainter(
                            projection: visualProjection,
                            selectedPrefabKey:
                                _sceneCoordinator.selectedPrefabKey,
                            transform: transform,
                          ),
                        ),
                      if (prefabCandidateVisual != null)
                        Opacity(
                          key: const ValueKey<String>(
                            'chunk_prefab_gesture_preview',
                          ),
                          opacity: 0.6,
                          child: ChunkSceneVisualSource(
                            workspaceRootPath: widget.controller.workspacePath,
                            placements: <ChunkScenePlacedVisual>[
                              prefabCandidateVisual,
                            ],
                            transform: transform,
                          ),
                        ),
                      if (actorProjection != null)
                        CustomPaint(
                          key: const ValueKey<String>(
                            'chunk_actor_terrain_overlay',
                          ),
                          painter: ChunkActorTerrainOverlayPainter(
                            projection: actorProjection,
                            actor: _selectedTerrainActor,
                            transform: transform,
                          ),
                        ),
                      if (markerProjection != null)
                        CustomPaint(
                          key: const ValueKey<String>(
                            'chunk_marker_placement_overlay',
                          ),
                          painter: ChunkMarkerPlacementOverlayPainter(
                            projection: markerProjection,
                            transform: transform,
                            selectedMarkerKey:
                                _sceneCoordinator.selectedMarkerKey,
                            suppressedMarkerKey:
                                _markerGesture.hiddenSourceIndex == null
                                ? null
                                : buildChunkPlacedMarkerSelections(
                                        chunk.markers,
                                      )[_markerGesture.hiddenSourceIndex!]
                                      .selectionKey,
                            showResolvedEvidence: _showMarkerPlacements,
                          ),
                        ),
                      if (_markerGesture.candidate case final marker?)
                        CustomPaint(
                          key: const ValueKey<String>(
                            'chunk_marker_gesture_preview',
                          ),
                          painter: ChunkMarkerAnchorPreviewPainter(
                            marker: marker,
                            transform: transform,
                          ),
                        ),
                      if (_showCompiledEdges && expansion != null)
                        CustomPaint(
                          key: const ValueKey<String>(
                            'chunk_compiled_edge_overlay',
                          ),
                          painter: ChunkCompiledEdgeOverlayPainter(
                            expansion: expansion,
                            transform: transform,
                            selectedEdgeId:
                                _sceneCoordinator.selectedCompiledEdgeId,
                          ),
                        ),
                    ],
                  ),
                  onInspectWorldPoint: _inspectCompiledEdges
                      ? (point) =>
                            _inspectCompiledEdge(authoring, worldPoint: point)
                      : null,
                  onBeginDomainGesture: (pointer, point) => _beginDomainGesture(
                    scene: scene,
                    visualProjection: visualProjection,
                    chunk: authoring.chunk,
                    pointer: pointer,
                    worldPoint: point,
                  ),
                  onUpdateDomainGesture: (pointer, point) =>
                      _updateDomainGesture(pointer, point),
                  onEndDomainGesture: (pointer, point) =>
                      _endDomainGesture(pointer, point),
                  onCancelDomainGesture: _cancelDomainGesture,
                  onClearSelection: _cancelGestureOrClearSelection,
                  onDeleteSelection: _deleteSceneSelection,
                  onPanDelta: (delta) => setState(() => _pan += delta),
                  onZoomSteps: (steps) {
                    _setZoom(_zoom + steps * _zoomStep);
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildShapePanel(ChunkPolygonAuthoringController authoring) {
    final shapes = List<TerrainSourceShapeDef>.of(authoring.state.visibleShapes)
      ..sort((left, right) => left.shapeId.compareTo(right.shapeId));
    final selection = authoring.state.selection;
    final selectedShape = _findShape(shapes, selection?.shapeId);
    final draft = authoring.state.draft;
    return EditorSectionCard(
      key: const ValueKey<String>('chunk_polygon_shapes_panel'),
      expansionKey: const ValueKey<String>('chunk_polygon_shapes_panel_toggle'),
      title: 'Shapes',
      collapsible: true,
      child: Column(
        key: const ValueKey<String>('chunk_shape_list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (selectedShape != null) ...<Widget>[
            _buildSelectedShapeHeader(authoring, selectedShape),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('chunk_polygon_new_shape'),
                onPressed: draft != null
                    ? null
                    : () {
                        authoring.setTool(TerrainPolygonTool.createPolygon);
                        authoring.beginCreatePolygon();
                      },
                icon: const Icon(Icons.add),
                label: const Text('New polygon'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('chunk_polygon_new_rectangle'),
                onPressed: draft != null
                    ? null
                    : () =>
                          authoring.setTool(TerrainPolygonTool.createRectangle),
                icon: const Icon(Icons.crop_square),
                label: const Text('New rectangle'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('chunk_polygon_save_draft'),
                onPressed: draft == null ? null : authoring.saveDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
              OutlinedButton(
                key: const ValueKey<String>('chunk_polygon_cancel_draft'),
                onPressed:
                    authoring.hasActiveOperation ||
                        authoring.state.tool ==
                            TerrainPolygonTool.createRectangle
                    ? authoring.cancelActiveOperation
                    : null,
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shapes.isEmpty)
            const Text('No committed direct collision shapes.')
          else
            for (final shape in shapes)
              Builder(
                builder: (context) {
                  final rectangle = TerrainAxisAlignedRectangle.tryFromShape(
                    shape,
                  );
                  return EditorListCard(
                    key: ValueKey<String>(
                      'chunk_polygon_shape_${shape.shapeId}',
                    ),
                    isSelected: selection?.shapeId == shape.shapeId,
                    onTap: () => authoring.select(
                      TerrainPolygonSelection.shape(shape.shapeId),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      selected: selection?.shapeId == shape.shapeId,
                      title: Text(shape.shapeId),
                      subtitle: Text(
                        '${shape.collisionMode.name} · '
                        '${rectangle == null ? '' : 'rectangle · '}'
                        '${shape.vertices.length} vertices',
                      ),
                    ),
                  );
                },
              ),
          if (selectedShape != null) ...<Widget>[
            const SizedBox(height: 8),
            _buildVertexInspector(authoring, selectedShape),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedShapeHeader(
    ChunkPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          OutlinedButton.icon(
            key: const ValueKey<String>('chunk_polygon_duplicate_shape'),
            onPressed: authoring.hasActiveOperation
                ? null
                : () => _duplicateSelectedShape(authoring, shape),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Duplicate'),
          ),
          OutlinedButton.icon(
            key: const ValueKey<String>('chunk_polygon_normalize_shape'),
            onPressed: authoring.normalizeSelectedShape,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Normalize'),
          ),
          OutlinedButton.icon(
            key: const ValueKey<String>('chunk_polygon_delete_shape'),
            onPressed: authoring.deleteSelection,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _buildMetadataInspector(authoring, shape),
    ],
  );

  Widget _buildDiagnosticsPanel(
    ChunkPolygonAuthoringController authoring,
    List<ValidationIssue> issues,
  ) => EditorSectionCard(
    key: const ValueKey<String>('chunk_polygon_diagnostics_panel'),
    expansionKey: const ValueKey<String>(
      'chunk_polygon_diagnostics_panel_toggle',
    ),
    title: 'Diagnostics',
    collapsible: true,
    child: Column(
      key: const ValueKey<String>('chunk_diagnostics_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildCompiledEdgeInspector(authoring),
        _buildExpandedPrefabShapes(authoring),
        if (_showMarkerPlacements) _buildMarkerPlacementInspector(),
        const Divider(height: 28),
        if (issues.isEmpty)
          const Text('No issues for this direct owner.')
        else
          for (final issue in issues)
            ListTile(
              key: ValueKey<String>(
                'chunk_polygon_issue_${issue.code}_${issue.shapeId}_'
                '${issue.elementIndex}',
              ),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                issue.severity == ValidationSeverity.error
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
                color: issue.severity == ValidationSeverity.error
                    ? const Color(0xFFFF7F7F)
                    : const Color(0xFFFFD166),
              ),
              title: Text(issue.code),
              subtitle: Text(issue.message),
              onTap: issue.shapeId == null || issue.placementKey != null
                  ? null
                  : () => _focusIssue(authoring, issue),
            ),
      ],
    ),
  );

  Widget _buildSeamPanel(ChunkPolygonAuthoringController authoring) =>
      EditorSectionCard(
        key: const ValueKey<String>('chunk_polygon_seams_panel'),
        expansionKey: const ValueKey<String>(
          'chunk_polygon_seams_panel_toggle',
        ),
        title: 'Reachable chunk seams',
        collapsible: true,
        child: Column(
          key: const ValueKey<String>('chunk_seam_list'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[_buildSeamInspector(authoring)],
        ),
      );

  Widget _buildExpansionSummary(ChunkPolygonAuthoringController authoring) {
    final result = _expansionFor(authoring.chunkKey);
    final expansion = result?.expansion;
    if (expansion == null) {
      return const Text(
        'Expanded prefab collision unavailable while expansion has blocking '
        'source or compiler issues.',
        key: ValueKey<String>('chunk_collision_expansion_unavailable'),
        style: TextStyle(color: Color(0xFFFFD166)),
      );
    }
    return Text(
      '${expansion.directShapeCount} direct + '
      '${expansion.expandedPrefabShapeCount} expanded = '
      '${expansion.totalShapeCount}/${TerrainGeometryLimits.maxShapesPerChunk} '
      'shapes · ${expansion.exposedEdgeCount}/'
      '${TerrainGeometryLimits.maxExposedEdgesPerChunk} exposed edges',
      key: const ValueKey<String>('chunk_collision_expansion_summary'),
    );
  }

  Widget _buildSeamSummary(ChunkPolygonAuthoringController authoring) {
    final scene = _sceneOrNull;
    if (scene == null) return const SizedBox.shrink();
    final seams = scene.seamAnalysis.seamsForChunk(authoring.chunkKey);
    if (authoring.chunk.status == chunkStatusDeprecated) {
      return const Text(
        'Deprecated chunk · excluded from scheduler seam candidates',
        key: ValueKey<String>('chunk_seam_summary'),
      );
    }
    if (seams.isEmpty) {
      return const Text(
        'No resolved scheduler seam candidates',
        key: ValueKey<String>('chunk_seam_summary'),
        style: TextStyle(color: Color(0xFFFFD166)),
      );
    }
    final failing = seams.where((seam) => !seam.comparison.isCompatible).length;
    final neighbors = <String>{
      for (final seam in seams)
        seam.transition.leftChunkKey == authoring.chunkKey
            ? seam.transition.rightChunkKey
            : seam.transition.leftChunkKey,
    };
    return Text(
      '${neighbors.length} reachable neighbor(s) · ${seams.length} directed '
      'scheduler seam(s) · ${seams.length - failing} compatible · '
      '$failing failing',
      key: const ValueKey<String>('chunk_seam_summary'),
      style: failing == 0 ? null : const TextStyle(color: Color(0xFFFF7F7F)),
    );
  }

  Widget _buildActorTerrainSummary() {
    final projection = _actorTerrainProjection;
    if (projection == null) {
      return const Text(
        'Actor terrain evidence is unavailable while accepted compiled '
        'geometry is unavailable.',
        key: ValueKey<String>('chunk_actor_terrain_unavailable'),
        style: TextStyle(color: Color(0xFFFFD166)),
      );
    }
    final text = switch (_selectedTerrainActor) {
      ChunkV2TerrainActor.eloise =>
        '${projection.groundedView(_selectedTerrainActor)!.eligibleSurfaces.length} '
            'eligible surfaces · player pathfinding graph is not defined',
      ChunkV2TerrainActor.grojib || ChunkV2TerrainActor.hashash =>
        _groundedGraphSummary(projection.groundedView(_selectedTerrainActor)!),
      ChunkV2TerrainActor.unoco =>
        '${projection.unocoSolidBlockerIds.length} solid blockers · '
            '${projection.unocoLocalHoverCandidateIds.length} local-hover '
            'surface candidates · no flight graph',
      ChunkV2TerrainActor.derf =>
        '${projection.derfPerches.where((item) => item.perchEligible).length} '
            'perch-eligible surfaces · 32 px minimum horizontal support span',
    };
    return Text(
      text,
      key: const ValueKey<String>('chunk_actor_terrain_summary'),
    );
  }

  Widget _buildMarkerPlacementSummary() {
    final projection = _markerPlacementProjection;
    if (projection == null) {
      return const Text(
        'Marker placement evidence is unavailable while accepted compiled '
        'geometry or level ground context is unavailable.',
        key: ValueKey<String>('chunk_marker_placement_unavailable'),
        style: TextStyle(color: Color(0xFFFFD166)),
      );
    }
    var accepted = 0;
    var rejected = 0;
    var deferred = 0;
    var inactive = 0;
    for (final outcome in projection.outcomes) {
      switch (outcome.disposition) {
        case ChunkV2MarkerPlacementDisposition.guaranteedAccepted:
        case ChunkV2MarkerPlacementDisposition.conditionalAccepted:
          accepted += 1;
        case ChunkV2MarkerPlacementDisposition.guaranteedRejected:
        case ChunkV2MarkerPlacementDisposition.conditionalRejected:
          rejected += 1;
        case ChunkV2MarkerPlacementDisposition.deferredGuaranteed:
        case ChunkV2MarkerPlacementDisposition.deferredConditional:
          deferred += 1;
        case ChunkV2MarkerPlacementDisposition.disabled:
        case ChunkV2MarkerPlacementDisposition.malformed:
          inactive += 1;
      }
    }
    return Text(
      '${projection.outcomes.length} authored marker(s) · $accepted accepted · '
      '$rejected rejected · $deferred deferred · $inactive inactive/malformed '
      '· 0 RNG draws',
      key: const ValueKey<String>('chunk_marker_placement_summary'),
    );
  }

  String _groundedGraphSummary(ChunkV2GroundedTerrainView view) {
    final graph = view.graph!;
    var walk = 0;
    var jump = 0;
    var drop = 0;
    for (final edge in graph.edges) {
      switch (edge.kind) {
        case TerrainSurfaceEdgeKind.walk:
          walk += 1;
        case TerrainSurfaceEdgeKind.jump:
          jump += 1;
        case TerrainSurfaceEdgeKind.drop:
          drop += 1;
      }
    }
    return '${view.eligibleSurfaces.length} eligible surfaces · '
        '$walk walk / $jump jump / $drop drop directed graph edges';
  }

  Widget _buildCompiledEdgeInspector(
    ChunkPolygonAuthoringController authoring,
  ) {
    final expansion = _expansionFor(authoring.chunkKey)?.expansion;
    final inspection = expansion == null
        ? null
        : inspectChunkV2CompiledEdge(
            expansion,
            _sceneCoordinator.selectedCompiledEdgeId,
          );
    if (inspection == null) {
      return _inspectCompiledEdges
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Divider(height: 28),
                Text(
                  'Select a compiled edge in the scene to inspect exact Core '
                  'facts.',
                  key: ValueKey<String>('chunk_compiled_edge_empty_inspector'),
                ),
              ],
            )
          : const SizedBox.shrink();
    }
    final edge = inspection.edge;
    final placementKey = edge.id.placementKey;
    ChunkV2ExpandedPrefabShape? placedShape;
    if (placementKey != null) {
      for (final shape in expansion!.expandedPrefabShapes) {
        if (shape.placementKey == placementKey &&
            shape.shapeId == edge.id.shapeId) {
          placedShape = shape;
          break;
        }
      }
    }
    final lineage = placedShape == null
        ? 'direct chunk shape ${edge.id.shapeId}'
        : 'prefab ${placedShape.prefabKey} rev ${placedShape.prefabRevision} · '
              'placement $placementKey · shape ${edge.id.shapeId}';
    final relatedIssues = _ownerIssues(authoring)
        .where(
          (issue) =>
              issue.shapeId == edge.id.shapeId &&
              issue.placementKey == placementKey,
        )
        .toList(growable: false);
    return Column(
      key: const ValueKey<String>('chunk_compiled_edge_inspector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 28),
        Text('Compiled edge', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        SelectableText(edge.id.canonicalKey),
        Text(lineage),
        Text(
          'start (${TerrainPhysicsText.formatTicks(edge.start.xTicks)}, '
          '${TerrainPhysicsText.formatTicks(edge.start.yTicks)}) px → '
          'end (${TerrainPhysicsText.formatTicks(edge.end.xTicks)}, '
          '${TerrainPhysicsText.formatTicks(edge.end.yTicks)}) px',
        ),
        Text(
          'tangent (${edge.tangent.xTicks}, ${edge.tangent.yTicks}) / '
          '1024 · outward normal (${edge.outwardNormal.xTicks}, '
          '${edge.outwardNormal.yTicks}) / 1024',
        ),
        Text(
          'absolute slope '
          '${TerrainPhysicsText.formatSlopeAngleUnits(inspection.absoluteSlopeAngleUnits)}° '
          '(${inspection.absoluteSlopeAngleUnits} units)',
        ),
        Text(
          'mode ${edge.collisionMode.name} · '
          'surface ${edge.surfaceKind ?? '—'} · '
          'material ${edge.materialKey ?? '—'}',
        ),
        Text(
          'joins ${edge.startJoin.name} → ${edge.endJoin.name} · '
          'previous ${edge.previousId?.canonicalKey ?? '—'} · '
          'next ${edge.nextId?.canonicalKey ?? '—'}',
        ),
        if (_showActorTerrain && _actorTerrainProjection != null)
          _buildActorEdgeEvidence(edge.id),
        if (relatedIssues.isEmpty)
          const Text('diagnostics none')
        else
          for (final issue in relatedIssues)
            Text('diagnostic ${issue.code}: ${issue.message}'),
      ],
    );
  }

  Widget _buildActorEdgeEvidence(TerrainEdgeId edgeId) {
    final projection = _actorTerrainProjection!;
    final actorLabel = _terrainActorLabel(_selectedTerrainActor);
    switch (_selectedTerrainActor) {
      case ChunkV2TerrainActor.eloise:
      case ChunkV2TerrainActor.grojib:
      case ChunkV2TerrainActor.hashash:
        final view = projection.groundedView(_selectedTerrainActor)!;
        final surfaceIndex = projection.surfaceSet.indexOfId(edgeId);
        final graph = view.graph;
        final outgoing = surfaceIndex == null || graph == null
            ? const <TerrainSurfaceGraphEdge>[]
            : graph.edgesFor(surfaceIndex).toList(growable: false);
        final walk = outgoing
            .where((edge) => edge.kind == TerrainSurfaceEdgeKind.walk)
            .length;
        final jump = outgoing
            .where((edge) => edge.kind == TerrainSurfaceEdgeKind.jump)
            .length;
        final drop = outgoing
            .where((edge) => edge.kind == TerrainSurfaceEdgeKind.drop)
            .length;
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$actorLabel: navigation surface '
            '${surfaceIndex == null ? 'no' : 'yes'} · eligible '
            '${view.isEligible(edgeId) ? 'yes' : 'no'} · max slope '
            '${TerrainPhysicsText.formatSlopeAngleUnits(view.traversalProfile.maxWalkableSlopeAngleUnits)}°'
            '${graph == null ? ' · no player graph' : ' · outgoing $walk walk / $jump jump / $drop drop'}',
            key: const ValueKey<String>('chunk_actor_edge_evidence'),
          ),
        );
      case ChunkV2TerrainActor.unoco:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$actorLabel: solid blocker '
            '${projection.isUnocoSolidBlocker(edgeId) ? 'yes' : 'no'} · '
            'local-hover surface candidate '
            '${projection.isUnocoLocalHoverCandidate(edgeId) ? 'yes' : 'no'} '
            '· one-way terrain ignored · no flight graph',
            key: const ValueKey<String>('chunk_actor_edge_evidence'),
          ),
        );
      case ChunkV2TerrainActor.derf:
        final evidence = projection.derfPerchEvidence(edgeId);
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$actorLabel: upward surface ${evidence == null ? 'no' : 'yes'} · '
            'solid/≤15° ${evidence?.slopeAndModeEligible == true ? 'yes' : 'no'} · '
            'horizontal span '
            '${evidence == null ? '—' : '${TerrainPhysicsText.formatTicks(evidence.surface.dxTicks)} px'} '
            '/ ${TerrainPhysicsText.formatTicks(derfMinimumSupportSpanTicks)} px '
            '${evidence?.supportSpanEligible == true ? 'pass' : 'fail'} · '
            'perch ${evidence?.perchEligible == true ? 'eligible' : 'ineligible'}',
            key: const ValueKey<String>('chunk_actor_edge_evidence'),
          ),
        );
    }
  }

  Widget _buildExpandedPrefabShapes(ChunkPolygonAuthoringController authoring) {
    final expansion = _expansionFor(authoring.chunkKey)?.expansion;
    if (expansion == null || expansion.expandedPrefabShapes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 28),
        Text(
          'Read-only prefab collision',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Edit these source shapes in Prefab Creator; chunk placements own '
          'only their transform.',
        ),
        for (final shape in expansion.expandedPrefabShapes)
          ListTile(
            key: ValueKey<String>(
              'chunk_expanded_shape_${shape.placementKey}_${shape.shapeId}',
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline, size: 18),
            title: Text('${shape.prefabId} · ${shape.shapeId}'),
            subtitle: Text(
              'prefab ${shape.prefabKey} rev ${shape.prefabRevision}\n'
              'placement ${shape.placementKey} · '
              '@ (${shape.placementX}, ${shape.placementY}) · '
              'scale ${(shape.scaleTenths / 10).toStringAsFixed(1)}',
            ),
            isThreeLine: true,
            trailing: widget.onOpenOwningPrefab == null
                ? null
                : OutlinedButton.icon(
                    key: ValueKey<String>(
                      'chunk_open_prefab_${shape.placementKey}_${shape.shapeId}',
                    ),
                    onPressed:
                        widget.controller.isLoading ||
                            widget.controller.isExporting
                        ? null
                        : () => widget.onOpenOwningPrefab!(shape.prefabKey),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open prefab'),
                  ),
          ),
      ],
    );
  }

  Widget _buildSeamInspector(ChunkPolygonAuthoringController authoring) {
    final scene = _sceneOrNull;
    final seams =
        scene?.seamAnalysis.seamsForChunk(authoring.chunkKey) ??
        const <ChunkV2ReachableSeam>[];
    return Column(
      key: const ValueKey<String>('chunk_seam_inspector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Read-only scheduler evidence from exact compiled boundaries. '
          'Material-key differences are retained as advisory evidence and do not block '
          'this physical seam gate.',
        ),
        if (authoring.chunk.status == chunkStatusDeprecated)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'This deprecated chunk is not eligible for runtime selection.',
            ),
          )
        else if (seams.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No seam comparison is available. Check scheduler pool and '
              'compiled-geometry diagnostics.',
            ),
          )
        else
          for (final seam in seams)
            _buildSeamEvidenceCard(authoring.chunkKey, seam),
      ],
    );
  }

  Widget _buildSeamEvidenceCard(
    String selectedChunkKey,
    ChunkV2ReachableSeam seam,
  ) {
    final transition = seam.transition;
    final comparison = seam.comparison;
    final selectedIsLeft = transition.leftChunkKey == selectedChunkKey;
    final neighborKey = selectedIsLeft
        ? transition.rightChunkKey
        : transition.leftChunkKey;
    final direction = selectedIsLeft
        ? 'right → $neighborKey'
        : '$neighborKey → left';
    final mismatchCoordinates = comparison.mismatchYTicks
        .map(TerrainPhysicsText.formatTicks)
        .join(', ');
    return Card(
      key: ValueKey<String>(
        'chunk_seam_${transition.transitionId}_'
        '${transition.leftChunkKey}_${transition.rightChunkKey}',
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          comparison.isCompatible
              ? Icons.link_outlined
              : Icons.link_off_outlined,
          color: comparison.isCompatible
              ? const Color(0xFF8BD3A8)
              : const Color(0xFFFF7F7F),
        ),
        title: Text(
          '$direction · ${comparison.isCompatible ? 'compatible' : 'failing'}',
        ),
        subtitle: Text(
          '${transition.transitionId}\n${transition.description}'
          '${comparison.isCompatible ? '' : '\nmismatch y=[$mismatchCoordinates] px'}'
          '${comparison.materialMismatchVertices.isEmpty ? '' : '\nmaterial evidence at ${comparison.materialMismatchVertices.length} endpoint(s)'}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildMarkerPlacementInspector() {
    final projection = _markerPlacementProjection;
    if (projection == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Divider(height: 28),
          Text(
            'Marker placement diagnostics require accepted compiled geometry '
            'and a resolved level ground plane.',
          ),
        ],
      );
    }
    final selected = projection.outcomeFor(_sceneCoordinator.selectedMarkerKey);
    return Column(
      key: const ValueKey<String>('chunk_marker_placement_inspector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 28),
        Text(
          'Authored marker placement',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Advisory only: source order, chance, and salt are preserved; no '
          'random roll or source mutation occurs. Hashash placement is '
          'deferred by runtime. Procedural collectible/restoration candidates '
          'have no authored marker records and are not fabricated here. '
          'Projectile motion is outside this marker preview; runtime ballistic '
          'projectiles sweep the admitted terrain.',
        ),
        if (projection.outcomes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('This chunk has no authored enemy markers.'),
          )
        else
          for (final outcome in projection.outcomes)
            Card(
              key: ValueKey<String>(
                'chunk_marker_placement_${outcome.selectionKey}',
              ),
              child: ListTile(
                dense: true,
                selected:
                    outcome.selectionKey == _sceneCoordinator.selectedMarkerKey,
                onTap: () => _selectMarkerByKey(
                  authoringChunk: _authoring?.chunk,
                  selectionKey: outcome.selectionKey,
                ),
                leading: Icon(_markerDispositionIcon(outcome.disposition)),
                title: Text(
                  '#${outcome.sourceIndex + 1} ${outcome.marker.markerId}',
                ),
                subtitle: Text(
                  '${outcome.marker.chancePercent}% · '
                  '${outcome.marker.placement} · ${outcome.code}',
                ),
              ),
            ),
        if (selected != null) _buildSelectedMarkerEvidence(selected),
      ],
    );
  }

  Widget _buildSelectedMarkerEvidence(ChunkV2MarkerPlacementOutcome outcome) {
    final marker = outcome.marker;
    final profile = outcome.profile;
    final result = outcome.result;
    return Column(
      key: const ValueKey<String>('chunk_selected_marker_evidence'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text('Selected marker', style: Theme.of(context).textTheme.titleSmall),
        SelectableText(outcome.selectionKey),
        Text(
          'source order ${outcome.sourceIndex + 1} · authored anchor '
          '(${marker.x}, ${marker.y}) px · chance ${marker.chancePercent}% · '
          'salt ${marker.salt}',
        ),
        Text(
          'intent ${marker.placement} · disposition '
          '${_markerDispositionLabel(outcome.disposition)}',
        ),
        Text(outcome.message),
        if (outcome.malformedCodes.isNotEmpty)
          Text('contract errors ${outcome.malformedCodes.join(', ')}'),
        Text(
          'intended edge '
          '${outcome.intendedSurface?.id.canonicalKey ?? '—'}',
        ),
        if (profile != null)
          Text(
            'profile ${profile.diagnosticKey} · capsule radius '
            '${TerrainPhysicsText.formatTicks(profile.capsule.radiusTicks)} px '
            '· half-spine '
            '${TerrainPhysicsText.formatTicks(profile.capsule.verticalHalfSegmentTicks)} px '
            '· offset '
            '(${TerrainPhysicsText.formatTicks(profile.capsule.resolvedOffsetXTicks)}, '
            '${TerrainPhysicsText.formatTicks(profile.capsule.offsetYTicks)}) px',
          ),
        if (result != null) ...<Widget>[
          Text(
            'Core ${result.validity.name} · requested body '
            '${_formatPhysicsPoint(result.requestedBodyCenter)} · accepted '
            'body ${_formatPhysicsPoint(result.bodyCenter)}',
          ),
          Text(
            'support ${result.supportEdgeId?.canonicalKey ?? '—'} · point '
            '${_formatPhysicsPoint(result.supportPoint)} · blocker '
            '${result.blockingEdgeId?.canonicalKey ?? '—'}',
          ),
          Text(
            'slope '
            '${result.absoluteSlopeAngleUnits == null ? '—' : '${TerrainPhysicsText.formatSlopeAngleUnits(result.absoluteSlopeAngleUnits!)}°'} '
            '· same-support clamp ${result.sameSupportClamped ? 'yes' : 'no'}',
          ),
          const SizedBox(height: 4),
          SelectableText(result.diagnostic),
        ],
      ],
    );
  }

  IconData _markerDispositionIcon(
    ChunkV2MarkerPlacementDisposition disposition,
  ) => switch (disposition) {
    ChunkV2MarkerPlacementDisposition.guaranteedAccepted =>
      Icons.check_circle_outline,
    ChunkV2MarkerPlacementDisposition.conditionalAccepted => Icons.help_outline,
    ChunkV2MarkerPlacementDisposition.guaranteedRejected =>
      Icons.cancel_outlined,
    ChunkV2MarkerPlacementDisposition.conditionalRejected =>
      Icons.warning_amber_outlined,
    ChunkV2MarkerPlacementDisposition.disabled => Icons.pause_circle_outline,
    ChunkV2MarkerPlacementDisposition.deferredGuaranteed ||
    ChunkV2MarkerPlacementDisposition.deferredConditional =>
      Icons.schedule_outlined,
    ChunkV2MarkerPlacementDisposition.malformed => Icons.error_outline,
  };

  String _markerDispositionLabel(
    ChunkV2MarkerPlacementDisposition disposition,
  ) => switch (disposition) {
    ChunkV2MarkerPlacementDisposition.guaranteedAccepted =>
      'guaranteed accepted',
    ChunkV2MarkerPlacementDisposition.conditionalAccepted =>
      'conditional accepted',
    ChunkV2MarkerPlacementDisposition.guaranteedRejected =>
      'required placement rejected',
    ChunkV2MarkerPlacementDisposition.conditionalRejected =>
      'conditional placement rejected',
    ChunkV2MarkerPlacementDisposition.disabled => 'disabled',
    ChunkV2MarkerPlacementDisposition.deferredGuaranteed =>
      'guaranteed deferred',
    ChunkV2MarkerPlacementDisposition.deferredConditional =>
      'conditional deferred',
    ChunkV2MarkerPlacementDisposition.malformed => 'malformed',
  };

  String _formatPhysicsPoint(TerrainPoint? point) => point == null
      ? '—'
      : '(${TerrainPhysicsText.formatTicks(point.xTicks)}, '
            '${TerrainPhysicsText.formatTicks(point.yTicks)}) px';

  Widget _buildMetadataInspector(
    ChunkPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    final controlsEnabled = !authoring.hasActiveOperation;
    final surfaceValue = shape.surfaceKind?.trim() ?? '';
    final materialValue = shape.materialKey?.trim() ?? '';
    final surfaceOptions = terrainMetadataSelectorOptions(
      current: surfaceValue,
      known: terrainSurfaceKindOptions,
    );
    final materialOptions = terrainMetadataSelectorOptions(
      current: materialValue,
      known:
          _materialCatalog?.materials.map((material) => material.key) ??
          const <String>[],
    );
    return Column(
      key: const ValueKey<String>('chunk_polygon_metadata_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Metadata', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildMetadataDropdown<TerrainSourceCollisionMode>(
          keyName: 'chunk_polygon_metadata_mode',
          label: 'Collision mode',
          value: shape.collisionMode,
          items: TerrainSourceCollisionMode.values
              .map(
                (mode) => DropdownMenuItem<TerrainSourceCollisionMode>(
                  value: mode,
                  child: Text(mode.name),
                ),
              )
              .toList(growable: false),
          onChanged: controlsEnabled
              ? (mode) {
                  if (mode == null || mode == shape.collisionMode) return;
                  authoring.editSelectedShapeMetadata(
                    collisionMode: mode,
                    surfaceKind: shape.surfaceKind,
                    materialKey: shape.materialKey,
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        _buildMetadataDropdown<String>(
          keyName: 'chunk_polygon_metadata_surface_selector',
          label: 'Surface kind',
          value: surfaceValue,
          items: surfaceOptions
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(terrainMetadataSelectorLabel(value)),
                ),
              )
              .toList(growable: false),
          onChanged: controlsEnabled
              ? (value) {
                  if (value == null || value == surfaceValue) return;
                  authoring.editSelectedShapeMetadata(
                    collisionMode: shape.collisionMode,
                    surfaceKind: nullableTerrainMetadataSelection(value),
                    materialKey: shape.materialKey,
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: _buildMetadataDropdown<String>(
                keyName: 'chunk_polygon_metadata_material_selector',
                label: 'Material key',
                value: materialValue,
                items: materialOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          terrainMaterialSelectorLabel(_materialCatalog, value),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: controlsEnabled
                    ? (value) {
                        if (value == null || value == materialValue) return;
                        authoring.editSelectedShapeMetadata(
                          collisionMode: shape.collisionMode,
                          surfaceKind: shape.surfaceKind,
                          materialKey: nullableTerrainMetadataSelection(value),
                        );
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const ValueKey<String>(
                'chunk_polygon_material_preview_button',
              ),
              onPressed: materialValue.isEmpty
                  ? null
                  : () => _showReadOnlyMaterialPreview(materialValue),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetadataDropdown<T>({
    required String keyName,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        key: ValueKey<String>(keyName),
        value: value,
        isDense: true,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  Future<void> _showReadOnlyMaterialPreview(String materialKey) async {
    final material = terrainMaterialPreviewForKey(
      _materialCatalog,
      materialKey,
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey<String>('chunk_polygon_read_only_material_dialog'),
        title: Text(
          material == null
              ? 'Material preview'
              : '${material.displayName} · ${material.key}',
        ),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: material == null
                ? Text('No preview assets are registered for $materialKey.')
                : TerrainMaterialPreview(
                    key: const ValueKey<String>(
                      'chunk_polygon_read_only_material_preview',
                    ),
                    workspaceRootPath: widget.controller.workspacePath,
                    material: material,
                    keyPrefix: 'chunk_polygon_read_only_material',
                  ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('chunk_polygon_material_preview_close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildVertexInspector(
    ChunkPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    final rectangle = TerrainAxisAlignedRectangle.tryFromShape(shape);
    final selection = authoring.state.selection;
    final selectedVertexIndex =
        selection?.shapeId == shape.shapeId &&
            selection?.kind == TerrainPolygonSelectionKind.vertex
        ? selection?.elementIndex
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (rectangle != null) ...<Widget>[
          TerrainPolygonRectangleEditor(
            key: ValueKey<String>(
              'chunk_polygon_rectangle_editor_${shape.shapeId}_'
              '${rectangle.xHalfPixels}_${rectangle.yHalfPixels}_'
              '${rectangle.widthHalfPixels}_${rectangle.heightHalfPixels}',
            ),
            keyPrefix: 'chunk_polygon',
            rectangle: rectangle,
            onApply:
                ({
                  required xHalfPixels,
                  required bottomYHalfPixels,
                  required widthHalfPixels,
                  required heightHalfPixels,
                }) {
                  authoring.editSelectedAxisAlignedRectangle(
                    xHalfPixels: xHalfPixels,
                    yHalfPixels: bottomYHalfPixels - heightHalfPixels,
                    widthHalfPixels: widthHalfPixels,
                    heightHalfPixels: heightHalfPixels,
                  );
                },
          ),
          const SizedBox(height: 12),
        ],
        Text('Vertices', style: Theme.of(context).textTheme.titleSmall),
        for (final entry in shape.vertices.asMap().entries)
          ListTile(
            key: ValueKey<String>(
              'chunk_polygon_vertex_${shape.shapeId}_${entry.key}',
            ),
            dense: true,
            selected: entry.key == selectedVertexIndex,
            onTap: () => authoring.select(
              TerrainPolygonSelection.vertex(shape.shapeId, entry.key),
            ),
            title: Text('v${entry.key}'),
            trailing: Text(
              '(${TerrainHalfPixelText.formatTicks(entry.value.xHalfPixels)}, '
              '${TerrainHalfPixelText.formatTicks(entry.value.yHalfPixels)})',
            ),
          ),
        if (selectedVertexIndex != null) ...<Widget>[
          const SizedBox(height: 8),
          TerrainPolygonVertexEditor(
            key: ValueKey<String>(
              'chunk_polygon_vertex_editor_${shape.shapeId}_'
              '${selectedVertexIndex}_'
              '${shape.vertices[selectedVertexIndex].xHalfPixels}_'
              '${shape.vertices[selectedVertexIndex].yHalfPixels}',
            ),
            keyPrefix: 'chunk_polygon',
            shapeId: shape.shapeId,
            vertexIndex: selectedVertexIndex,
            vertex: shape.vertices[selectedVertexIndex],
            onApply: (xHalfPixels, yHalfPixels) {
              authoring.editSelectedVertex(
                TerrainSourceVertexDef(
                  xHalfPixels: xHalfPixels,
                  yHalfPixels: yHalfPixels,
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _duplicateSelectedShape(
    ChunkPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    final chunk = authoring.chunk;
    final offset = findTerrainPolygonDuplicateOffset(
      selectedShape: shape,
      ownerShapes: authoring.state.shapes,
      snapStepHalfPixels: authoring.snapPolicy.stepHalfPixels,
      minXHalfPixels: 0,
      minYHalfPixels: 0,
      maxXHalfPixels: chunk.width * 2,
      maxYHalfPixels: chunk.height * 2,
    );
    if (offset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No non-overlapping duplicate fits this chunk.'),
        ),
      );
      return;
    }
    authoring.duplicateSelectedShape(
      deltaXHalfPixels: offset.deltaXHalfPixels,
      deltaYHalfPixels: offset.deltaYHalfPixels,
    );
  }

  List<ValidationIssue> _ownerIssues(
    ChunkPolygonAuthoringController authoring,
  ) {
    final sourcePath =
        _documentOrNull?.sourcePathByChunkKey[authoring.chunkKey];
    final combined = <ValidationIssue>[
      ...authoring.issues,
      ...widget.controller.issues.where(
        (issue) =>
            issue.sourcePath == sourcePath ||
            (sourcePath != null &&
                (issue.sourcePath?.startsWith('$sourcePath:') ?? false)),
      ),
    ];
    final seen = <String>{};
    final unique =
        combined
            .where(
              (issue) => seen.add(
                '${issue.code}|${issue.sourcePath}|${issue.shapeId}|'
                '${issue.elementIndex}|${issue.message}',
              ),
            )
            .toList(growable: false)
          ..sort((left, right) {
            var order = (left.shapeId ?? '').compareTo(right.shapeId ?? '');
            if (order != 0) return order;
            order = (left.elementIndex ?? -1).compareTo(
              right.elementIndex ?? -1,
            );
            if (order != 0) return order;
            return left.code.compareTo(right.code);
          });
    return unique;
  }

  void _focusIssue(
    ChunkPolygonAuthoringController authoring,
    ValidationIssue issue,
  ) {
    final shapeId = issue.shapeId;
    final shape = _findShape(authoring.state.visibleShapes, shapeId);
    if (shape == null || shapeId == null) return;
    final index = issue.elementIndex ?? 0;
    if (issue.code.contains('vertex') && index < shape.vertices.length) {
      authoring.select(TerrainPolygonSelection.vertex(shapeId, index));
    } else if (issue.code.contains('edge') && index < shape.vertices.length) {
      authoring.select(TerrainPolygonSelection.edge(shapeId, index));
    } else {
      authoring.select(TerrainPolygonSelection.shape(shapeId));
    }
  }

  Future<void> _createOwner(ChunkV2Document document) async {
    final id = await showChunkV2CreateDialog(context, document: document);
    if (id == null || !mounted) return;
    final beforeKeys = document.chunks.map((chunk) => chunk.chunkKey).toSet();
    final next = _dispatchLifecycle(document, ChunkV2CreateOperation(id: id));
    if (next == null) return;
    final createdKeys = next.chunks
        .map((chunk) => chunk.chunkKey)
        .where((key) => !beforeKeys.contains(key))
        .toList(growable: false);
    _syncOwnerAfterSessionMutation(preferredChunkKey: createdKeys.firstOrNull);
  }

  Future<void> _editOwner(
    ChunkV2Document document,
    ChunkV2FileData chunk,
  ) async {
    final edit = await showChunkV2OwnerDialog(
      context,
      document: document,
      chunk: chunk,
    );
    if (edit == null || !mounted) return;
    final before = ChunkV2MetadataSnapshot.fromChunk(chunk);
    final after = ChunkV2MetadataSnapshot(
      status: edit.status,
      levelId: edit.levelId,
      difficulty: edit.difficulty,
      assemblyGroupId: edit.assemblyGroupId,
      tags: edit.tags,
      groundBandZIndex: edit.groundBandZIndex,
    );
    if (before == after) return;
    final beforeDocument = widget.controller.document;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkMetadataCommandKind,
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'commit': ChunkV2MetadataCommit(before: before, after: after),
        },
      ),
    );
    if (identical(widget.controller.document, beforeDocument)) {
      _showOwnerMutationRejected();
      return;
    }
    _syncOwnerAfterSessionMutation(preferredChunkKey: chunk.chunkKey);
  }

  void _duplicateOwner(ChunkV2Document document, ChunkV2FileData chunk) {
    final beforeKeys = document.chunks.map((owner) => owner.chunkKey).toSet();
    final next = _dispatchLifecycle(
      document,
      ChunkV2DuplicateOperation(sourceChunkKey: chunk.chunkKey),
    );
    if (next == null) return;
    final duplicateKeys = next.chunks
        .map((owner) => owner.chunkKey)
        .where((key) => !beforeKeys.contains(key))
        .toList(growable: false);
    _syncOwnerAfterSessionMutation(
      preferredChunkKey: duplicateKeys.firstOrNull,
    );
  }

  Future<void> _renameOwner(
    ChunkV2Document document,
    ChunkV2FileData chunk,
  ) async {
    final nextId = await showChunkV2RenameDialog(
      context,
      document: document,
      chunk: chunk,
    );
    if (nextId == null || !mounted || nextId == chunk.id) return;
    final next = _dispatchLifecycle(
      document,
      ChunkV2RenameOperation(chunkKey: chunk.chunkKey, nextId: nextId),
    );
    if (next != null) {
      _syncOwnerAfterSessionMutation(preferredChunkKey: chunk.chunkKey);
    }
  }

  Future<void> _deleteOwner(
    ChunkV2Document document,
    ChunkV2Scene scene,
    ChunkV2FileData chunk,
  ) async {
    final removesDimensionAuthority = scene.chunks.length == 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${chunk.id}?'),
        content: Text(
          'This stages deletion of the chunk owner and all of its tile '
          'layers, prefab placements, enemy markers, and collision polygons.'
          '${removesDimensionAuthority ? '\n\nThis is the final owner in the active level. New owners cannot be created there until this deletion is undone because no locked dimension template will remain.' : ''}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('chunk_v2_owner_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete owner'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final next = _dispatchLifecycle(
      document,
      ChunkV2DeleteOperation(chunkKey: chunk.chunkKey),
    );
    if (next != null) _syncOwnerAfterSessionMutation();
  }

  ChunkV2Document? _dispatchLifecycle(
    ChunkV2Document document,
    ChunkV2LifecycleOperation operation,
  ) {
    final beforeDocument = widget.controller.document;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkLifecycleCommandKind,
        payload: <String, Object?>{
          'commit': ChunkV2LifecycleCommit(
            before: ChunkV2LifecycleSnapshot.fromDocument(document),
            operation: operation,
          ),
        },
      ),
    );
    final next = widget.controller.document;
    if (identical(next, beforeDocument) || next is! ChunkV2Document) {
      _showOwnerMutationRejected();
      return null;
    }
    return next;
  }

  void _showOwnerMutationRejected() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Chunk change was rejected. Review validation diagnostics and '
          'retry from the current owner state.',
        ),
      ),
    );
  }

  void _syncOwnerAfterSessionMutation({String? preferredChunkKey}) {
    if (!mounted) return;
    final scene = _sceneOrNull;
    if (scene == null) return;
    final chunks = List<ChunkV2FileData>.of(scene.chunks)..sort(_compareChunks);
    final keys = chunks.map((chunk) => chunk.chunkKey).toSet();
    String? nextKey;
    if (preferredChunkKey != null && keys.contains(preferredChunkKey)) {
      nextKey = preferredChunkKey;
    } else if (_selectedChunkKey != null && keys.contains(_selectedChunkKey)) {
      nextKey = _selectedChunkKey;
    } else {
      nextKey = chunks.firstOrNull?.chunkKey;
    }
    if (nextKey == null) {
      _disposeAuthoring();
      setState(() => _selectedChunkKey = null);
      return;
    }
    if (_authoring?.chunkKey == nextKey) {
      setState(() {});
      return;
    }
    setState(() {
      _bindOwner(nextKey!);
      _resetViewportValues();
    });
  }

  void _selectInitialOwner() {
    final scene = _sceneOrNull;
    if (scene == null || scene.chunks.isEmpty) return;
    final chunks = List<ChunkV2FileData>.of(scene.chunks)..sort(_compareChunks);
    _bindOwner(chunks.first.chunkKey);
  }

  void _reconcileReloadedOwner(ChunkV2Scene scene) {
    final selectedKey = _selectedChunkKey;
    if (selectedKey != null &&
        scene.chunks.any((chunk) => chunk.chunkKey == selectedKey)) {
      return;
    }
    _disposeAuthoring();
    _selectedChunkKey = null;
    final chunks = List<ChunkV2FileData>.of(scene.chunks)..sort(_compareChunks);
    final nextKey = chunks.firstOrNull?.chunkKey;
    if (nextKey != null) {
      _bindOwner(nextKey);
      _resetViewportValues();
    }
  }

  void _selectOwner(String chunkKey) {
    if (chunkKey == _selectedChunkKey) return;
    if (_hasActiveOperation) {
      _showOwnerSwitchBlocked();
      return;
    }
    setState(() {
      _bindOwner(chunkKey);
      _resetViewportValues();
    });
  }

  void _selectLevel(String? levelId) {
    if (levelId == null || levelId == _sceneOrNull?.activeLevelId) return;
    if (_hasActiveOperation) {
      _showOwnerSwitchBlocked();
      return;
    }
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'set_active_level',
        payload: <String, Object?>{'levelId': levelId},
      ),
    );
    _syncOwnerAfterSessionMutation();
  }

  void _showOwnerSwitchBlocked() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Finish or cancel the active authoring operation before switching '
          'owners or levels.',
        ),
      ),
    );
  }

  void _bindOwner(String chunkKey) {
    _disposeAuthoring();
    _prefabGesture.cancel();
    _markerGesture.cancel();
    _selectedChunkKey = chunkKey;
    _sceneCoordinator.bindOwner();
    _actorProjectionExpansion = null;
    _actorTerrainProjection = null;
    _markerPlacementProjection = null;
    _markerProjectionChunk = null;
    _markerProjectionTerrain = null;
    _markerProjectionGroundTopY = null;
    final materials = _materialCatalog?.materials;
    _authoring = ChunkPolygonAuthoringController(
      session: widget.controller,
      chunkKey: chunkKey,
      newShapeSurfaceKind: terrainSurfaceKindOptions.first,
      newShapeMaterialKey: materials == null || materials.isEmpty
          ? null
          : materials.first.key,
      snapPolicy: TerrainPolygonSnapPolicy.ownerGridPixels(1),
    )..addListener(_handleAuthoringChanged);
    _authoringUiFingerprint = _buildAuthoringUiFingerprint(_authoring!);
    if (_showActorTerrain || _showMarkerPlacements) {
      _refreshActorTerrainProjection();
    }
    if (_showMarkerPlacements) _refreshMarkerPlacementProjection();
  }

  void _disposeAuthoring() {
    final authoring = _authoring;
    if (authoring == null) return;
    authoring.removeListener(_handleAuthoringChanged);
    authoring.dispose();
    _authoring = null;
    _authoringUiFingerprint = null;
  }

  void _reloadMaterialCatalog() {
    _materialCatalog = loadTerrainMaterialPreviewCatalog(
      widget.controller.workspacePath,
    ).catalog;
  }

  void _setCompositionOperationActive(bool active) {
    if (!mounted || _compositionOperationActive == active) return;
    setState(() => _compositionOperationActive = active);
  }

  void _handleAuthoringChanged() {
    if (!mounted) return;
    final authoring = _authoring;
    if (authoring == null) return;
    final fingerprint = _buildAuthoringUiFingerprint(authoring);
    if (fingerprint == _authoringUiFingerprint) return;
    _authoringUiFingerprint = fingerprint;
    setState(() {
      _sceneCoordinator.reconcileComposition(authoring.chunk);
      _sceneCoordinator.selectTerrain(authoring.state.selection);
      if (_showActorTerrain || _showMarkerPlacements) {
        _refreshActorTerrainProjection();
      }
      if (_showMarkerPlacements ||
          _sceneCoordinator.sourceDomain == ChunkSceneDomain.markers) {
        _refreshMarkerPlacementProjection();
      }
    });
  }

  Object _buildAuthoringUiFingerprint(
    ChunkPolygonAuthoringController authoring,
  ) => (
    chunk: authoring.chunk,
    tool: authoring.state.tool,
    selection: authoring.state.selection,
    draft: authoring.state.draft,
    gestureActive: authoring.state.gesture != null,
    issues: authoring.issues,
    snapStep: authoring.snapPolicy.stepHalfPixels,
    canUndo: authoring.canUndo,
    canRedo: authoring.canRedo,
  );

  ChunkV2Document? get _documentOrNull {
    final document = widget.controller.document;
    return document is ChunkV2Document ? document : null;
  }

  ChunkV2Scene? get _sceneOrNull {
    final scene = widget.controller.scene;
    return scene is ChunkV2Scene ? scene : null;
  }

  ChunkV2CollisionExpansionResult? _expansionFor(String chunkKey) =>
      _sceneOrNull?.collisionExpansionByChunkKey[chunkKey];

  void _refreshActorTerrainProjection() {
    final chunkKey = _authoring?.chunkKey;
    final expansion = chunkKey == null
        ? null
        : _expansionFor(chunkKey)?.expansion;
    if (identical(expansion, _actorProjectionExpansion)) return;
    _actorProjectionExpansion = expansion;
    _actorTerrainProjection = expansion == null
        ? null
        : ChunkV2ActorTerrainProjection.build(expansion);
  }

  void _refreshMarkerPlacementProjection() {
    _refreshActorTerrainProjection();
    final authoring = _authoring;
    final projection = _actorTerrainProjection;
    final scene = _sceneOrNull;
    if (authoring == null || projection == null || scene == null) {
      _markerPlacementProjection = null;
      _markerProjectionChunk = null;
      _markerProjectionTerrain = null;
      _markerProjectionGroundTopY = null;
      return;
    }
    final groundTopY = scene.groundTopYByLevelId[authoring.chunk.levelId];
    if (identical(authoring.chunk, _markerProjectionChunk) &&
        identical(projection, _markerProjectionTerrain) &&
        groundTopY == _markerProjectionGroundTopY) {
      return;
    }
    _markerPlacementProjection = ChunkV2MarkerPlacementProjection.build(
      chunk: authoring.chunk,
      actorTerrain: projection,
      levelGroundTopY: groundTopY,
    );
    _markerProjectionChunk = authoring.chunk;
    _markerProjectionTerrain = projection;
    _markerProjectionGroundTopY = groundTopY;
    final selectedMarkerKey = _sceneCoordinator.selectedMarkerKey;
    if (selectedMarkerKey != null &&
        _markerPlacementProjection!.outcomeFor(selectedMarkerKey) == null) {
      _sceneCoordinator.clearSelection();
    }
  }

  void _selectSceneDomain(ChunkSceneDomain domain) {
    if (_hasActiveOperation) {
      _showOwnerSwitchBlocked();
      return;
    }
    setState(() {
      _inspectCompiledEdges = false;
      _sceneCoordinator.setSourceDomain(domain);
      if (domain == ChunkSceneDomain.terrain) {
        _sceneCoordinator.selectTerrain(_authoring?.state.selection);
      } else if (domain == ChunkSceneDomain.markers) {
        _refreshMarkerPlacementProjection();
      }
    });
  }

  void _selectSceneElement(
    ChunkSceneVisualProjection visualProjection,
    ChunkV2FileData chunk,
    Offset worldPoint,
  ) {
    switch (_sceneCoordinator.domain) {
      case ChunkSceneDomain.prefabs:
        final hit = visualProjection.hitTestPrefab(worldPoint);
        final selection = hit == null
            ? null
            : resolveChunkPrefabSelection(chunk.prefabs, hit.selectionKey);
        setState(() => _sceneCoordinator.selectPrefab(selection));
      case ChunkSceneDomain.markers:
        final hit = hitTestChunkMarkerSelection(
          markers: chunk.markers,
          worldX: worldPoint.dx,
          worldY: worldPoint.dy,
          radiusWorld: 8 / _zoom,
        );
        setState(() => _sceneCoordinator.selectMarker(hit));
      case ChunkSceneDomain.terrain || ChunkSceneDomain.compiledEdgeInspection:
        break;
    }
  }

  bool _beginDomainGesture({
    required ChunkV2Scene scene,
    required ChunkSceneVisualProjection visualProjection,
    required ChunkV2FileData chunk,
    required int pointer,
    required Offset worldPoint,
  }) {
    switch (_sceneCoordinator.domain) {
      case ChunkSceneDomain.prefabs:
        switch (_prefabGesture.tool) {
          case ChunkPrefabSceneTool.select:
            _selectSceneElement(visualProjection, chunk, worldPoint);
            return false;
          case ChunkPrefabSceneTool.place:
            final prefab = _selectedCatalogPrefab(scene);
            if (prefab == null) return false;
            var began = false;
            setState(() {
              began = _prefabGesture.beginPlace(
                pointer: pointer,
                worldPoint: worldPoint,
                chunk: chunk,
                prefab: prefab,
              );
              if (began) _sceneCoordinator.clearSelection();
            });
            return began;
          case ChunkPrefabSceneTool.move:
            final hit = visualProjection.hitTestPrefab(worldPoint);
            final selection = hit == null
                ? null
                : resolveChunkPrefabSelection(chunk.prefabs, hit.selectionKey);
            var began = false;
            setState(() {
              _sceneCoordinator.selectPrefab(selection);
              if (selection != null) {
                began = _prefabGesture.beginMove(
                  pointer: pointer,
                  worldPoint: worldPoint,
                  chunk: chunk,
                  selection: selection,
                );
              }
            });
            return began;
        }
      case ChunkSceneDomain.markers:
        switch (_markerGesture.tool) {
          case ChunkMarkerSceneTool.select:
            _selectSceneElement(visualProjection, chunk, worldPoint);
            return false;
          case ChunkMarkerSceneTool.place:
            var began = false;
            setState(() {
              began = _markerGesture.beginPlace(
                pointer: pointer,
                worldPoint: worldPoint,
                chunk: chunk,
                markerId: _selectedMarkerCatalogId ?? chunkMarkerEnemyIds.first,
              );
              if (began) _sceneCoordinator.clearSelection();
            });
            return began;
          case ChunkMarkerSceneTool.move:
            final selection = hitTestChunkMarkerSelection(
              markers: chunk.markers,
              worldX: worldPoint.dx,
              worldY: worldPoint.dy,
              radiusWorld: 8 / _zoom,
            );
            var began = false;
            setState(() {
              _sceneCoordinator.selectMarker(selection);
              if (selection != null) {
                began = _markerGesture.beginMove(
                  pointer: pointer,
                  worldPoint: worldPoint,
                  chunk: chunk,
                  selection: selection,
                );
              }
            });
            return began;
        }
      case ChunkSceneDomain.terrain || ChunkSceneDomain.compiledEdgeInspection:
        return false;
    }
  }

  void _updateDomainGesture(int pointer, Offset worldPoint) {
    if (_prefabGesture.hasActiveOperation) {
      setState(
        () => _prefabGesture.update(pointer: pointer, worldPoint: worldPoint),
      );
    } else if (_markerGesture.hasActiveOperation) {
      setState(
        () => _markerGesture.update(pointer: pointer, worldPoint: worldPoint),
      );
    }
  }

  void _endDomainGesture(int pointer, Offset worldPoint) {
    if (_prefabGesture.hasActiveOperation) {
      late final ChunkPrefabGestureResult? result;
      setState(() {
        result = _prefabGesture.finish(
          pointer: pointer,
          worldPoint: worldPoint,
        );
      });
      if (result != null) _dispatchPrefabGestureResult(result!);
    } else if (_markerGesture.hasActiveOperation) {
      late final ChunkMarkerGestureResult? result;
      setState(() {
        result = _markerGesture.finish(
          pointer: pointer,
          worldPoint: worldPoint,
        );
      });
      if (result != null) _dispatchMarkerGestureResult(result!);
    }
  }

  void _cancelDomainGesture(int pointer) {
    if (!_prefabGesture.hasActiveOperation &&
        !_markerGesture.hasActiveOperation) {
      return;
    }
    setState(() {
      _prefabGesture.cancel();
      _markerGesture.cancel();
    });
  }

  void _cancelGestureOrClearSelection() {
    setState(() {
      final cancelled = _prefabGesture.cancel() || _markerGesture.cancel();
      if (!cancelled) _sceneCoordinator.clearSelection();
    });
  }

  void _deleteSceneSelection() {
    if (_prefabGesture.hasActiveOperation ||
        _markerGesture.hasActiveOperation) {
      return;
    }
    final authoring = _authoring;
    if (authoring == null) return;
    switch (_sceneCoordinator.domain) {
      case ChunkSceneDomain.prefabs:
        final key = _sceneCoordinator.selectedPrefabKey;
        if (key == null) return;
        final selection = resolveChunkPrefabSelection(
          authoring.chunk.prefabs,
          key,
        );
        if (selection == null) return;
        final operation = ChunkV2CompositionOperation.delete(
          chunk: authoring.chunk,
          target: ChunkV2CompositionTarget.prefabs,
          sourceIndex: selection.sourceIndex,
          presentationKey: selection.selectionKey,
        );
        final commit = operation.buildPrefab();
        if (commit == null) return;
        _dispatchPrefabGestureResult(
          ChunkPrefabGestureResult(candidate: selection.prefab, commit: commit),
          deleted: true,
        );
      case ChunkSceneDomain.markers:
        final key = _sceneCoordinator.selectedMarkerKey;
        if (key == null) return;
        final selection = resolveChunkMarkerSelection(
          authoring.chunk.markers,
          key,
        );
        if (selection == null) return;
        final operation = ChunkV2CompositionOperation.delete(
          chunk: authoring.chunk,
          target: ChunkV2CompositionTarget.markers,
          sourceIndex: selection.sourceIndex,
          presentationKey: selection.selectionKey,
        );
        final commit = operation.buildMarker();
        if (commit == null) return;
        _dispatchMarkerGestureResult(
          ChunkMarkerGestureResult(candidate: selection.marker, commit: commit),
          deleted: true,
        );
      case ChunkSceneDomain.terrain || ChunkSceneDomain.compiledEdgeInspection:
        return;
    }
  }

  void _dispatchMarkerGestureResult(
    ChunkMarkerGestureResult result, {
    bool deleted = false,
  }) {
    final commit = result.commit;
    if (commit == null) return;
    final beforeDocument = widget.controller.document;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkCompositionCommandKind,
        payload: <String, Object?>{
          'chunkKey': commit.expectedChunkKey,
          'commit': commit,
        },
      ),
    );
    final accepted = !identical(widget.controller.document, beforeDocument);
    final authoring = _authoring;
    if (accepted && authoring != null) {
      setState(() {
        if (deleted) {
          _sceneCoordinator.clearSelection();
          return;
        }
        final key = uniqueChunkMarkerSelectionKey(
          authoring.chunk.markers,
          result.candidate,
        );
        _sceneCoordinator.selectMarker(
          key == null
              ? null
              : resolveChunkMarkerSelection(authoring.chunk.markers, key),
        );
        _refreshMarkerPlacementProjection();
      });
      return;
    }
    setState(_sceneCoordinator.clearSelection);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Marker scene change was rejected. Review validation diagnostics '
          'and retry from the current chunk state.',
        ),
      ),
    );
  }

  void _dispatchPrefabGestureResult(
    ChunkPrefabGestureResult result, {
    bool deleted = false,
  }) {
    final commit = result.commit;
    if (commit == null) return;
    final beforeDocument = widget.controller.document;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkCompositionCommandKind,
        payload: <String, Object?>{
          'chunkKey': commit.expectedChunkKey,
          'commit': commit,
        },
      ),
    );
    final accepted = !identical(widget.controller.document, beforeDocument);
    final authoring = _authoring;
    if (accepted && authoring != null) {
      setState(() {
        if (deleted) {
          _sceneCoordinator.clearSelection();
          return;
        }
        final key = uniqueChunkPrefabSelectionKey(
          authoring.chunk.prefabs,
          result.candidate,
        );
        _sceneCoordinator.selectPrefab(
          key == null
              ? null
              : resolveChunkPrefabSelection(authoring.chunk.prefabs, key),
        );
      });
      return;
    }
    setState(_sceneCoordinator.clearSelection);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Prefab scene change was rejected. Review validation diagnostics '
          'and retry from the current chunk state.',
        ),
      ),
    );
  }

  List<PrefabV3Def> _activePrefabCatalog(ChunkV2Scene scene) =>
      scene.prefabData.prefabs
          .where((prefab) => prefab.status == PrefabStatus.active)
          .toList(growable: false)
        ..sort((left, right) => left.id.compareTo(right.id));

  PrefabV3Def? _selectedCatalogPrefab(ChunkV2Scene scene) {
    final prefabs = _activePrefabCatalog(scene);
    if (prefabs.isEmpty) return null;
    return prefabs
            .where((prefab) => prefab.prefabKey == _selectedPrefabCatalogKey)
            .firstOrNull ??
        prefabs.first;
  }

  void _selectMarkerByKey({
    required ChunkV2FileData? authoringChunk,
    required String selectionKey,
  }) {
    if (authoringChunk == null) return;
    final selection = resolveChunkMarkerSelection(
      authoringChunk.markers,
      selectionKey,
    );
    setState(() => _sceneCoordinator.selectMarker(selection));
  }

  void _inspectCompiledEdge(
    ChunkPolygonAuthoringController authoring, {
    required Offset worldPoint,
  }) {
    final expansion = _expansionFor(authoring.chunkKey)?.expansion;
    if (expansion == null) return;
    final edgeId = hitTestChunkV2CompiledEdge(
      expansion: expansion,
      worldX: worldPoint.dx,
      worldY: worldPoint.dy,
      radiusWorld: 8 / _zoom,
    );
    setState(() => _sceneCoordinator.selectCompiledEdge(edgeId));
  }

  void _setZoom(double value) {
    final next = EditorSceneViewUtils.snapZoom(
      value: value,
      min: _minZoom,
      max: _maxZoom,
      step: _zoomStep,
    );
    if (EditorSceneViewUtils.zoomValuesEqual(next, _zoom)) return;
    setState(() => _zoom = next);
  }

  void _resetViewport() => setState(_resetViewportValues);

  void _resetViewportValues() {
    _zoom = _initialZoom;
    _pan = Offset.zero;
  }
}

/// Keeps the owner rail, scene, and inspector sidebar mounted while only their
/// bounds change.
class _ChunkWorkspaceLayout extends StatelessWidget {
  const _ChunkWorkspaceLayout({
    required this.minimumWideWidth,
    required this.gap,
    required this.ownerSidebar,
    required this.scene,
    required this.sidebar,
  });

  final double minimumWideWidth;
  final double gap;
  final Widget ownerSidebar;
  final Widget scene;
  final Widget sidebar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= minimumWideWidth;
      final sidebarWidth = math.min(
        460.0,
        math.max(360.0, constraints.maxWidth * 0.34),
      );
      final ownerSidebarWidth = math.min(
        360.0,
        math.max(280.0, constraints.maxWidth * 0.23),
      );
      final availableNarrowHeight = math.max(1.0, constraints.maxHeight - gap);
      final sceneHeight = math.min(
        math.max(540.0, availableNarrowHeight * 0.72),
        math.max(1.0, availableNarrowHeight - 140.0),
      );
      return Stack(
        key: const ValueKey<String>('chunk_workspace_layout'),
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox.shrink(
              key: ValueKey<String>(
                isWide ? 'chunk_workspace_wide' : 'chunk_workspace_narrow',
              ),
            ),
          ),
          Positioned(
            key: const ValueKey<String>('chunk_scene_slot'),
            left: isWide ? ownerSidebarWidth + gap : 0,
            top: 0,
            right: isWide ? sidebarWidth + gap : 0,
            bottom: isWide ? 0 : null,
            height: isWide ? null : sceneHeight,
            child: scene,
          ),
          Positioned(
            key: const ValueKey<String>('chunk_owner_sidebar_slot'),
            left: 0,
            top: isWide ? 0 : sceneHeight + gap,
            bottom: 0,
            width: ownerSidebarWidth,
            child: ownerSidebar,
          ),
          Positioned(
            key: const ValueKey<String>('chunk_sidebar_slot'),
            left: isWide ? null : ownerSidebarWidth + gap,
            top: isWide ? 0 : sceneHeight + gap,
            right: 0,
            bottom: 0,
            width: isWide ? sidebarWidth : null,
            child: sidebar,
          ),
        ],
      );
    },
  );
}

class _ChunkBoundsPainter extends CustomPainter {
  const _ChunkBoundsPainter({
    required this.chunk,
    required this.transform,
    this.paintFill = true,
  });

  final ChunkV2FileData chunk;
  final TerrainPolygonViewportTransform transform;
  final bool paintFill;

  @override
  void paint(Canvas canvas, Size size) {
    final topLeft = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
    );
    final bottomRight = transform.sourceVertexToCanvas(
      TerrainSourceVertexDef(
        xHalfPixels: chunk.width * 2,
        yHalfPixels: chunk.height * 2,
      ),
    );
    final bounds = Rect.fromPoints(topLeft, bottomRight);
    if (paintFill) {
      canvas.drawRect(bounds, Paint()..color = const Color(0xFF16232D));
    }
    canvas.drawRect(
      bounds,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF7DD3FC),
    );
  }

  @override
  bool shouldRepaint(covariant _ChunkBoundsPainter oldDelegate) =>
      !identical(chunk, oldDelegate.chunk) ||
      paintFill != oldDelegate.paintFill ||
      transform.origin != oldDelegate.transform.origin ||
      transform.zoom != oldDelegate.transform.zoom;
}

TerrainSourceShapeDef? _findShape(
  Iterable<TerrainSourceShapeDef> shapes,
  String? shapeId,
) {
  if (shapeId == null) return null;
  for (final shape in shapes) {
    if (shape.shapeId == shapeId) return shape;
  }
  return null;
}

int _compareChunks(ChunkV2FileData left, ChunkV2FileData right) {
  final idOrder = left.id.compareTo(right.id);
  return idOrder != 0 ? idOrder : left.chunkKey.compareTo(right.chunkKey);
}

String _toolLabel(TerrainPolygonTool tool) => switch (tool) {
  TerrainPolygonTool.select => 'Select shape',
  TerrainPolygonTool.createPolygon => 'Place vertex',
  TerrainPolygonTool.createRectangle => 'Rectangle',
  TerrainPolygonTool.moveVertex => 'Move vertex',
  TerrainPolygonTool.insertVertex => 'Insert vertex',
  TerrainPolygonTool.translateShape => 'Move shape',
};

String _prefabToolLabel(ChunkPrefabSceneTool tool) => switch (tool) {
  ChunkPrefabSceneTool.select => 'Select',
  ChunkPrefabSceneTool.place => 'Place',
  ChunkPrefabSceneTool.move => 'Move',
};

String _markerToolLabel(ChunkMarkerSceneTool tool) => switch (tool) {
  ChunkMarkerSceneTool.select => 'Select',
  ChunkMarkerSceneTool.place => 'Place',
  ChunkMarkerSceneTool.move => 'Move',
};

String _terrainActorLabel(ChunkV2TerrainActor actor) => switch (actor) {
  ChunkV2TerrainActor.eloise => 'Éloïse',
  ChunkV2TerrainActor.grojib => 'Grojib',
  ChunkV2TerrainActor.hashash => 'Hashash',
  ChunkV2TerrainActor.unoco => 'Unoco',
  ChunkV2TerrainActor.derf => 'Derf',
};
