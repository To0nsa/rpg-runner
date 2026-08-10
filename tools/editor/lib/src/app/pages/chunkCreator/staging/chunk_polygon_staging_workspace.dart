import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';

import '../../../../chunks/chunk_v2_actor_terrain_projection.dart';
import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_compiled_edge_inspection.dart';
import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_domain_plugin.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_lifecycle_commit.dart';
import '../../../../chunks/chunk_v2_marker_placement_projection.dart';
import '../../../../chunks/chunk_v2_metadata_commit.dart';
import '../../../../chunks/chunk_v2_seam_analysis.dart';
import '../../../../chunks/chunk_v2_staging_models.dart';
import '../../../../domain/authoring_types.dart';
import '../../../../session/editor_session_controller.dart';
import '../../../../terrain_authoring/terrain_half_pixel_text.dart';
import '../../../../terrain_authoring/terrain_polygon_duplicate_offset.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_physics_text.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/terrain_polygon_metadata_dialog.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import '../../shared/terrain_polygon_vertex_editor.dart';
import 'chunk_actor_terrain_overlay_painter.dart';
import 'chunk_compiled_edge_overlay_painter.dart';
import 'chunk_expanded_collision_overlay_painter.dart';
import 'chunk_marker_placement_overlay_painter.dart';
import 'chunk_polygon_authoring_controller.dart';
import 'chunk_polygon_scene_surface.dart';
import 'chunk_v2_composition_workspace.dart';
import 'chunk_v2_owner_dialog.dart';

/// Explicit chunk-v2 polygon workspace used before the schema cutover.
///
/// Normal Chunk Creator sessions still load and write chunk v1. This workspace
/// is selected only for an already-staged v2 scene and exposes no source-write
/// action while the coordinated migration gate remains closed.
class ChunkPolygonStagingWorkspace extends StatefulWidget {
  const ChunkPolygonStagingWorkspace({
    super.key,
    required this.controller,
    this.onOpenOwningPrefab,
  });

  final EditorSessionController controller;

  /// Opens a read-only expanded shape's stable owner outside this workspace.
  final ValueChanged<String>? onOpenOwningPrefab;

  @override
  State<ChunkPolygonStagingWorkspace> createState() =>
      ChunkPolygonStagingWorkspaceState();
}

class ChunkPolygonStagingWorkspaceState
    extends State<ChunkPolygonStagingWorkspace> {
  static const double _initialZoom = 1;
  static const double _minZoom = 0.25;
  static const double _maxZoom = 8;
  static const double _zoomStep = 0.25;
  static const double _gap = 12;

  ChunkPolygonAuthoringController? _authoring;
  String? _selectedChunkKey;
  _ChunkV2WorkspaceView _workspaceView = _ChunkV2WorkspaceView.terrain;
  double _zoom = _initialZoom;
  Offset _pan = Offset.zero;
  bool _showCompiledEdges = true;
  bool _inspectCompiledEdges = false;
  TerrainEdgeId? _selectedCompiledEdgeId;
  bool _showActorTerrain = false;
  ChunkV2TerrainActor _selectedTerrainActor = ChunkV2TerrainActor.eloise;
  ChunkV2CollisionExpansion? _actorProjectionExpansion;
  ChunkV2ActorTerrainProjection? _actorTerrainProjection;
  bool _showMarkerPlacements = false;
  String? _selectedMarkerKey;
  ChunkV2MarkerPlacementProjection? _markerPlacementProjection;

  bool get hasLocalDraftChanges =>
      (_authoring?.hasActiveOperation ?? false) ||
      widget.controller.pendingChanges.hasChanges;

  bool get canUndo =>
      (_authoring?.hasActiveOperation ?? false) || widget.controller.canUndo;

  bool get canRedo =>
      !(_authoring?.hasActiveOperation ?? false) && widget.controller.canRedo;

  bool handleUndoShortcut() {
    final authoring = _authoring;
    if (authoring?.hasActiveOperation ?? false) {
      authoring!.cancelActiveOperation();
      return true;
    }
    if (!widget.controller.canUndo) return false;
    widget.controller.undo();
    _syncOwnerAfterSessionMutation();
    return true;
  }

  bool handleRedoShortcut() {
    if ((_authoring?.hasActiveOperation ?? false) ||
        !widget.controller.canRedo) {
      return false;
    }
    widget.controller.redo();
    _syncOwnerAfterSessionMutation();
    return true;
  }

  @override
  void initState() {
    super.initState();
    _selectInitialOwner();
  }

  @override
  void didUpdateWidget(covariant ChunkPolygonStagingWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _disposeAuthoring();
    _selectedChunkKey = null;
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
    final authoring = _authoring;
    if (document == null || scene == null) {
      return const Center(
        child: Text('Chunk-v2 staging scene is no longer loaded.'),
      );
    }
    final issues = authoring == null
        ? const <ValidationIssue>[]
        : _ownerIssues(authoring);
    return Card(
      key: const ValueKey<String>('chunk_polygon_staging_workspace'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(document, scene),
            const SizedBox(height: _gap),
            Expanded(
              child: _workspaceView == _ChunkV2WorkspaceView.terrain
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          width: 260,
                          child: _buildOwnerPanel(
                            document,
                            scene,
                            authoring?.chunk,
                            controlsEnabled:
                                !(authoring?.hasActiveOperation ?? false),
                          ),
                        ),
                        const SizedBox(width: _gap),
                        Expanded(
                          child: authoring == null
                              ? _buildEmptyPanel(
                                  title: 'Terrain collision scene',
                                  message:
                                      'This level has no chunk owner. Undo '
                                      'the deletion, or switch to a level '
                                      'that still has a dimension template.',
                                )
                              : _buildScenePanel(authoring),
                        ),
                        const SizedBox(width: _gap),
                        SizedBox(
                          width: 310,
                          child: authoring == null
                              ? _buildEmptyPanel(
                                  title: 'Shapes and diagnostics',
                                  message:
                                      'Select or create a chunk owner first.',
                                )
                              : _buildShapePanel(authoring, issues),
                        ),
                      ],
                    )
                  : authoring == null
                  ? _buildEmptyPanel(
                      title: 'Chunk composition',
                      message: 'Select or create a chunk owner first.',
                    )
                  : ChunkV2CompositionWorkspace(
                      controller: widget.controller,
                      document: document,
                      chunk: authoring.chunk,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    ChunkV2StagingDocument document,
    ChunkV2StagingScene scene,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const Chip(
            avatar: Icon(Icons.science_outlined, size: 18),
            label: Text('Chunk v2 polygon staging'),
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
          FilledButton.icon(
            key: const ValueKey<String>('chunk_polygon_apply_locked'),
            onPressed: null,
            icon: Icon(Icons.lock_outline),
            label: Text('Apply source (cutover locked)'),
          ),
          OutlinedButton.icon(
            key: const ValueKey<String>('chunk_polygon_undo_button'),
            onPressed: canUndo ? handleUndoShortcut : null,
            icon: const Icon(Icons.undo),
            label: const Text('Undo'),
          ),
          OutlinedButton.icon(
            key: const ValueKey<String>('chunk_polygon_redo_button'),
            onPressed: canRedo ? handleRedoShortcut : null,
            icon: const Icon(Icons.redo),
            label: const Text('Redo'),
          ),
          Text(
            document.changedChunkKeys.isEmpty
                ? 'No staged chunk changes'
                : '${document.changedChunkKeys.length} staged chunk change(s)',
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Read-only migration workspace: session history and validation are '
        'active, but repository writes remain disabled until the coordinated '
        'prefab-v3/chunk-v2 cutover.',
        style: TextStyle(color: Color(0xFFFFD166)),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          ChoiceChip(
            key: const ValueKey<String>('chunk_v2_view_terrain'),
            label: const Text('Owners & terrain collision'),
            selected: _workspaceView == _ChunkV2WorkspaceView.terrain,
            onSelected: (_) =>
                _selectWorkspaceView(_ChunkV2WorkspaceView.terrain),
          ),
          ChoiceChip(
            key: const ValueKey<String>('chunk_v2_view_composition'),
            label: const Text('Layers, prefabs & markers'),
            selected: _workspaceView == _ChunkV2WorkspaceView.composition,
            onSelected: (_) =>
                _selectWorkspaceView(_ChunkV2WorkspaceView.composition),
          ),
        ],
      ),
    ],
  );

  void _selectWorkspaceView(_ChunkV2WorkspaceView view) {
    if (view == _workspaceView) return;
    if (_authoring?.hasActiveOperation ?? false) {
      _showOwnerSwitchBlocked();
      return;
    }
    setState(() => _workspaceView = view);
  }

  Widget _buildOwnerPanel(
    ChunkV2StagingDocument document,
    ChunkV2StagingScene scene,
    ChunkV2FileData? selectedChunk, {
    required bool controlsEnabled,
  }) {
    final chunks = List<ChunkV2FileData>.of(scene.chunks)..sort(_compareChunks);
    return _Panel(
      title: 'Chunk owners',
      child: ListView(
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
                return Card(
                  key: ValueKey<String>(
                    'chunk_polygon_owner_${chunk.chunkKey}',
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    selected: chunk.chunkKey == selectedChunk?.chunkKey,
                    onTap: () => _selectOwner(chunk.chunkKey),
                    title: Text(chunk.id),
                    subtitle: Text(
                      '${chunk.difficulty} · ${chunk.width}×${chunk.height} px · '
                      'rev ${chunk.revision}\n${chunk.status} · '
                      '${chunk.collisionShapes.length} direct · '
                      '${expansion?.expandedPrefabShapeCount ?? 0} expanded',
                    ),
                    isThreeLine: true,
                    trailing: document.changedChunkKeys.contains(chunk.chunkKey)
                        ? const Tooltip(
                            message: 'Staged geometry changed',
                            child: Icon(Icons.circle, size: 12),
                          )
                        : null,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOwnerActions(
    ChunkV2StagingDocument document,
    ChunkV2StagingScene scene, {
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

  Widget _buildEmptyPanel({required String title, required String message}) =>
      _Panel(
        title: title,
        child: Center(child: Text(message)),
      );

  Widget _buildScenePanel(ChunkPolygonAuthoringController authoring) => _Panel(
    title: 'Terrain collision scene',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
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
            FilterChip(
              key: const ValueKey<String>('chunk_compiled_edges_toggle'),
              label: const Text('Compiled edges'),
              selected: _showCompiledEdges,
              onSelected: (selected) {
                setState(() {
                  _showCompiledEdges = selected;
                  if (!selected) {
                    _inspectCompiledEdges = false;
                    _selectedCompiledEdgeId = null;
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
                  if (selected) {
                    _showCompiledEdges = true;
                  } else {
                    _selectedCompiledEdgeId = null;
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
                  } else {
                    _selectedMarkerKey = null;
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
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final tool in TerrainPolygonTool.values)
                ChoiceChip(
                  key: ValueKey<String>('chunk_polygon_tool_${tool.name}'),
                  label: Text(_toolLabel(tool)),
                  selected: authoring.state.tool == tool,
                  onSelected: _inspectCompiledEdges
                      ? null
                      : (_) => authoring.setTool(tool),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildExpansionSummary(authoring),
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
              : 'Primary input follows the selected tool. Ctrl+drag pans, '
                    'Ctrl+scroll zooms, Enter closes a draft, and Escape '
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
              final markerProjection = _showMarkerPlacements
                  ? _markerPlacementProjection
                  : null;
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
                child: ChunkPolygonSceneSurface(
                  controller: authoring,
                  transform: transform,
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CustomPaint(
                        painter: _ChunkBoundsPainter(
                          chunk: chunk,
                          transform: transform,
                        ),
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
                            selectedMarkerKey: _selectedMarkerKey,
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
                            selectedEdgeId: _selectedCompiledEdgeId,
                          ),
                        ),
                    ],
                  ),
                  onInspectWorldPoint: _inspectCompiledEdges
                      ? (point) =>
                            _inspectCompiledEdge(authoring, worldPoint: point)
                      : null,
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

  Widget _buildShapePanel(
    ChunkPolygonAuthoringController authoring,
    List<ValidationIssue> issues,
  ) {
    final shapes = List<TerrainSourceShapeDef>.of(authoring.state.visibleShapes)
      ..sort((left, right) => left.shapeId.compareTo(right.shapeId));
    final selection = authoring.state.selection;
    final selectedShape = _findShape(shapes, selection?.shapeId);
    final draft = authoring.state.draft;
    return _Panel(
      title: 'Shapes and diagnostics',
      child: ListView(
        key: const ValueKey<String>('chunk_shape_diagnostics_list'),
        children: <Widget>[
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
              OutlinedButton(
                key: const ValueKey<String>('chunk_polygon_close_draft'),
                onPressed: draft == null ? null : authoring.closePolygon,
                child: const Text('Close draft'),
              ),
              OutlinedButton(
                onPressed: authoring.hasActiveOperation
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
              Card(
                key: ValueKey<String>('chunk_polygon_shape_${shape.shapeId}'),
                child: ListTile(
                  selected: selection?.shapeId == shape.shapeId,
                  onTap: () => authoring.select(
                    TerrainPolygonSelection.shape(shape.shapeId),
                  ),
                  title: Text(shape.shapeId),
                  subtitle: Text(
                    '${shape.collisionMode.name} · '
                    '${shape.vertices.length} vertices',
                  ),
                ),
              ),
          if (selectedShape != null) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('chunk_polygon_duplicate_shape'),
                  onPressed: authoring.hasActiveOperation
                      ? null
                      : () => _duplicateSelectedShape(authoring, selectedShape),
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
                  key: const ValueKey<String>('chunk_polygon_edit_metadata'),
                  onPressed: () => _editMetadata(authoring, selectedShape),
                  icon: const Icon(Icons.tune),
                  label: const Text('Metadata'),
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
            _buildVertexInspector(authoring, selectedShape),
          ],
          _buildCompiledEdgeInspector(authoring),
          _buildExpandedPrefabShapes(authoring),
          _buildSeamInspector(authoring),
          if (_showMarkerPlacements) _buildMarkerPlacementInspector(),
          const Divider(height: 28),
          Text('Diagnostics', style: Theme.of(context).textTheme.titleSmall),
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
  }

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
        : inspectChunkV2CompiledEdge(expansion, _selectedCompiledEdgeId);
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
        const Divider(height: 28),
        Text(
          'Reachable chunk seams',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Read-only scheduler evidence from exact compiled boundaries. '
          'Material-key differences are retained for Phase 5 but do not block '
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
    final selected = projection.outcomeFor(_selectedMarkerKey);
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
          'Projectile terrain support remains later-phase work and is not '
          'previewed.',
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
                selected: outcome.selectionKey == _selectedMarkerKey,
                onTap: () =>
                    setState(() => _selectedMarkerKey = outcome.selectionKey),
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

  Widget _buildVertexInspector(
    ChunkPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    final selection = authoring.state.selection;
    final selectedVertexIndex =
        selection?.shapeId == shape.shapeId &&
            selection?.kind == TerrainPolygonSelectionKind.vertex
        ? selection?.elementIndex
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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

  Future<void> _editMetadata(
    ChunkPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) async {
    final edit = await showTerrainPolygonMetadataDialog(
      context,
      keyPrefix: 'chunk_polygon',
      shape: shape,
    );
    if (edit != null && mounted) {
      authoring.editSelectedShapeMetadata(
        collisionMode: edit.collisionMode,
        surfaceKind: edit.surfaceKind,
        materialKey: edit.materialKey,
      );
    }
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

  Future<void> _createOwner(ChunkV2StagingDocument document) async {
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
    ChunkV2StagingDocument document,
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

  void _duplicateOwner(ChunkV2StagingDocument document, ChunkV2FileData chunk) {
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
    ChunkV2StagingDocument document,
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
    ChunkV2StagingDocument document,
    ChunkV2StagingScene scene,
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

  ChunkV2StagingDocument? _dispatchLifecycle(
    ChunkV2StagingDocument document,
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
    if (identical(next, beforeDocument) || next is! ChunkV2StagingDocument) {
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

  void _selectOwner(String chunkKey) {
    if (chunkKey == _selectedChunkKey) return;
    if (_authoring?.hasActiveOperation ?? false) {
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
    if (_authoring?.hasActiveOperation ?? false) {
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
          'Finish or cancel the active polygon operation before switching '
          'owners or levels.',
        ),
      ),
    );
  }

  void _bindOwner(String chunkKey) {
    _disposeAuthoring();
    _selectedChunkKey = chunkKey;
    _selectedCompiledEdgeId = null;
    _selectedMarkerKey = null;
    _actorProjectionExpansion = null;
    _actorTerrainProjection = null;
    _markerPlacementProjection = null;
    _authoring = ChunkPolygonAuthoringController(
      session: widget.controller,
      chunkKey: chunkKey,
      snapPolicy: TerrainPolygonSnapPolicy.ownerGridPixels(1),
    )..addListener(_handleAuthoringChanged);
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
  }

  void _handleAuthoringChanged() {
    if (!mounted) return;
    setState(() {
      if (_showActorTerrain || _showMarkerPlacements) {
        _refreshActorTerrainProjection();
      }
      if (_showMarkerPlacements) _refreshMarkerPlacementProjection();
    });
  }

  ChunkV2StagingDocument? get _documentOrNull {
    final document = widget.controller.document;
    return document is ChunkV2StagingDocument ? document : null;
  }

  ChunkV2StagingScene? get _sceneOrNull {
    final scene = widget.controller.scene;
    return scene is ChunkV2StagingScene ? scene : null;
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
      _selectedMarkerKey = null;
      return;
    }
    _markerPlacementProjection = ChunkV2MarkerPlacementProjection.build(
      chunk: authoring.chunk,
      actorTerrain: projection,
      levelGroundTopY: scene.groundTopYByLevelId[authoring.chunk.levelId],
    );
    if (_markerPlacementProjection!.outcomeFor(_selectedMarkerKey) == null) {
      _selectedMarkerKey = null;
    }
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
    setState(() => _selectedCompiledEdgeId = edgeId);
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

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class _ChunkBoundsPainter extends CustomPainter {
  const _ChunkBoundsPainter({required this.chunk, required this.transform});

  final ChunkV2FileData chunk;
  final TerrainPolygonViewportTransform transform;

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
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF16232D));
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

enum _ChunkV2WorkspaceView { terrain, composition }

int _compareChunks(ChunkV2FileData left, ChunkV2FileData right) {
  final idOrder = left.id.compareTo(right.id);
  return idOrder != 0 ? idOrder : left.chunkKey.compareTo(right.chunkKey);
}

String _toolLabel(TerrainPolygonTool tool) => switch (tool) {
  TerrainPolygonTool.select => 'Select',
  TerrainPolygonTool.createPolygon => 'Create',
  TerrainPolygonTool.moveVertex => 'Move vertex',
  TerrainPolygonTool.insertVertex => 'Insert vertex',
  TerrainPolygonTool.translateShape => 'Move shape',
};

String _terrainActorLabel(ChunkV2TerrainActor actor) => switch (actor) {
  ChunkV2TerrainActor.eloise => 'Éloïse',
  ChunkV2TerrainActor.grojib => 'Grojib',
  ChunkV2TerrainActor.hashash => 'Hashash',
  ChunkV2TerrainActor.unoco => 'Unoco',
  ChunkV2TerrainActor.derf => 'Derf',
};
