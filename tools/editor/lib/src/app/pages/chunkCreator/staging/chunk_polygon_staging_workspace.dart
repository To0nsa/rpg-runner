import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';

import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_compiled_edge_inspection.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
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
import 'chunk_compiled_edge_overlay_painter.dart';
import 'chunk_expanded_collision_overlay_painter.dart';
import 'chunk_polygon_authoring_controller.dart';
import 'chunk_polygon_scene_surface.dart';

/// Explicit chunk-v2 polygon workspace used before the schema cutover.
///
/// Normal Chunk Creator sessions still load and write chunk v1. This workspace
/// is selected only for an already-staged v2 scene and exposes no source-write
/// action while the coordinated migration gate remains closed.
class ChunkPolygonStagingWorkspace extends StatefulWidget {
  const ChunkPolygonStagingWorkspace({super.key, required this.controller});

  final EditorSessionController controller;

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
  double _zoom = _initialZoom;
  Offset _pan = Offset.zero;
  bool _showCompiledEdges = true;
  bool _inspectCompiledEdges = false;
  TerrainEdgeId? _selectedCompiledEdgeId;

  bool get hasLocalDraftChanges =>
      (_authoring?.hasActiveOperation ?? false) ||
      widget.controller.pendingChanges.hasChanges;

  bool get canUndo =>
      (_authoring?.hasActiveOperation ?? false) || widget.controller.canUndo;

  bool get canRedo =>
      !(_authoring?.hasActiveOperation ?? false) && widget.controller.canRedo;

  bool handleUndoShortcut() => _authoring?.undo() ?? false;

  bool handleRedoShortcut() => _authoring?.redo() ?? false;

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
    if (document == null || scene == null || authoring == null) {
      return const Center(
        child: Text('Chunk-v2 staging scene is no longer loaded.'),
      );
    }
    final issues = _ownerIssues(authoring);
    return Card(
      key: const ValueKey<String>('chunk_polygon_staging_workspace'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(document, scene, authoring),
            const SizedBox(height: _gap),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 260,
                    child: _buildOwnerPanel(document, scene, authoring.chunk),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(child: _buildScenePanel(authoring)),
                  const SizedBox(width: _gap),
                  SizedBox(
                    width: 310,
                    child: _buildShapePanel(authoring, issues),
                  ),
                ],
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
    ChunkPolygonAuthoringController authoring,
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
          FilledButton.icon(
            key: const ValueKey<String>('chunk_polygon_apply_locked'),
            onPressed: null,
            icon: Icon(Icons.lock_outline),
            label: Text('Apply source (cutover locked)'),
          ),
          OutlinedButton.icon(
            key: const ValueKey<String>('chunk_polygon_undo_button'),
            onPressed: canUndo ? authoring.undo : null,
            icon: const Icon(Icons.undo),
            label: const Text('Undo'),
          ),
          OutlinedButton.icon(
            key: const ValueKey<String>('chunk_polygon_redo_button'),
            onPressed: canRedo ? authoring.redo : null,
            icon: const Icon(Icons.redo),
            label: const Text('Redo'),
          ),
          Text(
            document.changedChunkKeys.isEmpty
                ? 'No staged geometry changes'
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
    ],
  );

  Widget _buildOwnerPanel(
    ChunkV2StagingDocument document,
    ChunkV2StagingScene scene,
    ChunkV2FileData selectedChunk,
  ) {
    final chunks = List<ChunkV2FileData>.of(scene.chunks)..sort(_compareChunks);
    return _Panel(
      title: 'Chunk owners',
      child: ListView(
        children: <Widget>[
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
                    selected: chunk.chunkKey == selectedChunk.chunkKey,
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
                  foreground: _showCompiledEdges && expansion != null
                      ? CustomPaint(
                          key: const ValueKey<String>(
                            'chunk_compiled_edge_overlay',
                          ),
                          painter: ChunkCompiledEdgeOverlayPainter(
                            expansion: expansion,
                            transform: transform,
                            selectedEdgeId: _selectedCompiledEdgeId,
                          ),
                        )
                      : const SizedBox.shrink(),
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
        if (relatedIssues.isEmpty)
          const Text('diagnostics none')
        else
          for (final issue in relatedIssues)
            Text('diagnostic ${issue.code}: ${issue.message}'),
      ],
    );
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
          ),
      ],
    );
  }

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

  void _selectInitialOwner() {
    final scene = _sceneOrNull;
    if (scene == null || scene.chunks.isEmpty) return;
    final chunks = List<ChunkV2FileData>.of(scene.chunks)..sort(_compareChunks);
    _bindOwner(chunks.first.chunkKey);
  }

  void _selectOwner(String chunkKey) {
    if (chunkKey == _selectedChunkKey) return;
    setState(() {
      _bindOwner(chunkKey);
      _resetViewportValues();
    });
  }

  void _selectLevel(String? levelId) {
    if (levelId == null || levelId == _sceneOrNull?.activeLevelId) return;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'set_active_level',
        payload: <String, Object?>{'levelId': levelId},
      ),
    );
    final scene = _sceneOrNull;
    if (scene == null || scene.chunks.isEmpty) return;
    final chunks = List<ChunkV2FileData>.of(scene.chunks)..sort(_compareChunks);
    setState(() {
      _bindOwner(chunks.first.chunkKey);
      _resetViewportValues();
    });
  }

  void _bindOwner(String chunkKey) {
    _disposeAuthoring();
    _selectedChunkKey = chunkKey;
    _selectedCompiledEdgeId = null;
    _authoring = ChunkPolygonAuthoringController(
      session: widget.controller,
      chunkKey: chunkKey,
      snapPolicy: TerrainPolygonSnapPolicy.ownerGridPixels(1),
    )..addListener(_handleAuthoringChanged);
  }

  void _disposeAuthoring() {
    final authoring = _authoring;
    if (authoring == null) return;
    authoring.removeListener(_handleAuthoringChanged);
    authoring.dispose();
    _authoring = null;
  }

  void _handleAuthoringChanged() {
    if (mounted) setState(() {});
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
