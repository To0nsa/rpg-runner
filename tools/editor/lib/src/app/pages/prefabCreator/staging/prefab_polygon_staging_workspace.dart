import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/validation/prefab_validation.dart';
import '../../../../session/editor_session_controller.dart';
import '../../../../terrain_authoring/terrain_half_pixel_text.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import '../shared/prefab_polygon_authoring_controller.dart';
import '../shared/prefab_polygon_scene_surface.dart';
import '../shared/prefab_polygon_visual_source.dart';
import '../shared/ui/prefab_editor_panel_card.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';
import '../shared/ui/prefab_editor_ui_tokens.dart';

/// Explicit prefab-v3 polygon workspace used before the schema cutover.
///
/// The normal Prefab Creator still loads and writes v2 rectangles. This page is
/// selected only when the session already contains [PrefabV3StagingScene], and
/// deliberately exposes no source-write action while staging export is locked.
class PrefabPolygonStagingWorkspace extends StatefulWidget {
  const PrefabPolygonStagingWorkspace({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<PrefabPolygonStagingWorkspace> createState() =>
      PrefabPolygonStagingWorkspaceState();
}

/// Shortcut and local-draft contract exposed to the containing editor route.
class PrefabPolygonStagingWorkspaceState
    extends State<PrefabPolygonStagingWorkspace> {
  static const double _initialZoom = 4;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 12;
  static const double _zoomStep = 0.5;

  PrefabPolygonAuthoringController? _authoring;
  String? _selectedPrefabKey;
  double _zoom = _initialZoom;
  Offset _pan = Offset.zero;

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
  void didUpdateWidget(covariant PrefabPolygonStagingWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _disposeAuthoring();
    _selectedPrefabKey = null;
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
    final authoring = _authoring;
    if (document == null || authoring == null) {
      return const Center(
        child: Text('Prefab-v3 staging scene is no longer loaded.'),
      );
    }
    final prefab = authoring.prefab;
    final issues = _ownerIssues(document, prefab, authoring.issues);

    return Card(
      key: const ValueKey<String>('prefab_polygon_staging_workspace'),
      child: Padding(
        padding: PrefabEditorUiTokens.panelInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(document, authoring),
            const SizedBox(height: PrefabEditorUiTokens.sectionGap),
            Expanded(
              child: PrefabEditorThreePanelLayout(
                inspector: _buildOwnerPanel(document, prefab),
                scene: _buildScenePanel(document, prefab, authoring),
                display: _buildShapePanel(authoring, issues),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    PrefabV3StagingDocument document,
    PrefabPolygonAuthoringController authoring,
  ) {
    final changedCount = document.changedPrefabKeys.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: PrefabEditorUiTokens.controlGap,
          runSpacing: PrefabEditorUiTokens.controlGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const Chip(
              avatar: Icon(Icons.science_outlined, size: 18),
              label: Text('Prefab v3 polygon staging'),
            ),
            FilledButton.icon(
              key: const ValueKey<String>('prefab_polygon_apply_locked'),
              onPressed: null,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Apply source (cutover locked)'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('prefab_polygon_undo_button'),
              onPressed:
                  authoring.hasActiveOperation || widget.controller.canUndo
                  ? authoring.undo
                  : null,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('prefab_polygon_redo_button'),
              onPressed:
                  authoring.hasActiveOperation || !widget.controller.canRedo
                  ? null
                  : authoring.redo,
              icon: const Icon(Icons.redo),
              label: const Text('Redo'),
            ),
            Text(
              changedCount == 0
                  ? 'No staged geometry changes'
                  : '$changedCount staged prefab change(s)',
            ),
          ],
        ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        const Text(
          'Read-only migration workspace: edits participate in session history '
          'and validation, but repository writes remain disabled until the '
          'coordinated prefab-v3/chunk-v2 cutover.',
          style: TextStyle(color: Color(0xFFFFD166)),
        ),
      ],
    );
  }

  Widget _buildOwnerPanel(
    PrefabV3StagingDocument document,
    PrefabV3Def selectedPrefab,
  ) {
    final prefabs = List<PrefabV3Def>.of(document.data.prefabs)
      ..sort(_comparePrefabs);
    return PrefabEditorPanelCard(
      title: 'Prefab owners',
      scrollable: true,
      child: Column(
        children: <Widget>[
          for (final prefab in prefabs)
            Card(
              key: ValueKey<String>('prefab_polygon_owner_${prefab.prefabKey}'),
              margin: const EdgeInsets.only(
                bottom: PrefabEditorUiTokens.controlGap,
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                selected: prefab.prefabKey == selectedPrefab.prefabKey,
                onTap: () => _selectOwner(prefab.prefabKey),
                title: Text(prefab.id),
                subtitle: Text(
                  '${prefab.kind.jsonValue} · rev ${prefab.revision} · '
                  '${prefab.visualSource.type.jsonValue}:'
                  '${prefab.sourceRefId}\n${prefab.status.jsonValue}'
                  '${prefab.tags.isEmpty ? '' : ' · ${prefab.tags.join(', ')}'}',
                ),
                isThreeLine: true,
                trailing: document.changedPrefabKeys.contains(prefab.prefabKey)
                    ? const Tooltip(
                        message: 'Staged geometry changed',
                        child: Icon(Icons.circle, size: 12),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScenePanel(
    PrefabV3StagingDocument document,
    PrefabV3Def prefab,
    PrefabPolygonAuthoringController authoring,
  ) {
    final canEditCollision = prefab.kind != PrefabKind.decoration;
    final projection = PrefabPolygonVisualProjection.fromDocument(
      document: document,
      prefab: prefab,
    );
    return PrefabEditorPanelCard(
      title: 'Collision scene',
      expandBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: PrefabEditorUiTokens.controlGap,
            runSpacing: PrefabEditorUiTokens.controlGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              EditorZoomControls(
                value: _zoom,
                min: _minZoom,
                max: _maxZoom,
                step: _zoomStep,
                sliderWidth: 150,
                onChanged: _setZoom,
              ),
              OutlinedButton.icon(
                onPressed: _resetViewport,
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Reset view'),
              ),
              SegmentedButton<int>(
                key: const ValueKey<String>('prefab_polygon_snap_selector'),
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 2, label: Text('1 px grid')),
                  ButtonSegment<int>(value: 1, label: Text('0.5 px')),
                ],
                selected: <int>{authoring.snapPolicy.stepHalfPixels},
                onSelectionChanged: (selection) {
                  final step = selection.single;
                  authoring.setSnapPolicy(
                    step == 1
                        ? const TerrainPolygonSnapPolicy.halfPixel()
                        : TerrainPolygonSnapPolicy.ownerGridPixels(1),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: PrefabEditorUiTokens.controlGap,
              children: <Widget>[
                for (final tool in TerrainPolygonTool.values)
                  ChoiceChip(
                    key: ValueKey<String>('prefab_polygon_tool_${tool.name}'),
                    label: Text(_toolLabel(tool)),
                    selected: authoring.state.tool == tool,
                    onSelected:
                        !canEditCollision && tool != TerrainPolygonTool.select
                        ? null
                        : (_) => authoring.setTool(tool),
                  ),
              ],
            ),
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          if (!canEditCollision)
            const Text(
              'Decoration prefabs remain collider-free; their visual source '
              'can be inspected but collision tools are disabled.',
            )
          else
            const Text(
              'Primary input follows the selected tool. Ctrl+drag pans, '
              'Ctrl+scroll zooms, Enter closes a draft, and Escape cancels.',
            ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportSize = Size(
                  math.max(1, constraints.maxWidth),
                  math.max(1, constraints.maxHeight),
                );
                final transform = TerrainPolygonViewportTransform(
                  origin:
                      Offset(
                        viewportSize.width * 0.5,
                        viewportSize.height * 0.5,
                      ) +
                      _pan,
                  zoom: _zoom,
                );
                return EditorSceneViewportFrame(
                  child: PrefabPolygonSceneSurface(
                    controller: authoring,
                    transform: transform,
                    visualSource: PrefabPolygonVisualSource(
                      workspaceRootPath: widget.controller.workspacePath,
                      projection: projection,
                      transform: transform,
                    ),
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
  }

  Widget _buildShapePanel(
    PrefabPolygonAuthoringController authoring,
    List<PrefabValidationIssue> issues,
  ) {
    final shapes = List<TerrainSourceShapeDef>.of(authoring.state.visibleShapes)
      ..sort((left, right) => left.shapeId.compareTo(right.shapeId));
    final selectedShapeId = authoring.state.selection?.shapeId;
    final selectedShape = _findShape(shapes, selectedShapeId);
    final draft = authoring.state.draft;
    return PrefabEditorPanelCard(
      title: 'Shapes and diagnostics',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: PrefabEditorUiTokens.controlGap,
            runSpacing: PrefabEditorUiTokens.controlGap,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('prefab_polygon_new_shape'),
                onPressed:
                    authoring.prefab.kind == PrefabKind.decoration ||
                        draft != null
                    ? null
                    : () {
                        authoring.setTool(TerrainPolygonTool.createPolygon);
                        authoring.beginCreatePolygon();
                      },
                icon: const Icon(Icons.add),
                label: const Text('New polygon'),
              ),
              OutlinedButton(
                key: const ValueKey<String>('prefab_polygon_close_draft'),
                onPressed: draft == null ? null : authoring.closePolygon,
                child: const Text('Close draft'),
              ),
              OutlinedButton(
                onPressed: !authoring.hasActiveOperation
                    ? null
                    : authoring.cancelActiveOperation,
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          if (shapes.isEmpty)
            const Text('No committed collision shapes.')
          else
            for (final shape in shapes)
              Card(
                key: ValueKey<String>('prefab_polygon_shape_${shape.shapeId}'),
                margin: const EdgeInsets.only(
                  bottom: PrefabEditorUiTokens.controlGap,
                ),
                child: ListTile(
                  selected: selectedShapeId == shape.shapeId,
                  onTap: () => authoring.select(
                    TerrainPolygonSelection.shape(shape.shapeId),
                  ),
                  title: Text(shape.shapeId),
                  subtitle: Text(
                    '${shape.collisionMode.name} · '
                    '${shape.vertices.length} vertices\n${_shapeExtent(shape)}',
                  ),
                  isThreeLine: true,
                ),
              ),
          if (selectedShape != null) ...<Widget>[
            const SizedBox(height: PrefabEditorUiTokens.controlGap),
            Wrap(
              spacing: PrefabEditorUiTokens.controlGap,
              runSpacing: PrefabEditorUiTokens.controlGap,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => authoring.duplicateSelectedShape(
                    deltaXHalfPixels: 4,
                    deltaYHalfPixels: 4,
                  ),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Duplicate'),
                ),
                OutlinedButton.icon(
                  onPressed: authoring.normalizeSelectedShape,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Normalize'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editMetadata(authoring, selectedShape),
                  icon: const Icon(Icons.tune),
                  label: const Text('Metadata'),
                ),
                OutlinedButton.icon(
                  onPressed: authoring.deleteSelection,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
            const SizedBox(height: PrefabEditorUiTokens.controlGap),
            _buildVertexInspector(authoring, selectedShape),
          ],
          const Divider(height: 32),
          Text('Diagnostics', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          if (issues.isEmpty)
            const Text('No issues for this owner.')
          else
            for (final issue in issues)
              ListTile(
                key: ValueKey<String>(
                  'prefab_polygon_issue_${issue.code}_${issue.shapeId}_${issue.elementIndex}',
                ),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  issue.severity == PrefabValidationSeverity.error
                      ? Icons.error_outline
                      : Icons.warning_amber_outlined,
                  color: issue.severity == PrefabValidationSeverity.error
                      ? const Color(0xFFFF7F7F)
                      : const Color(0xFFFFD166),
                ),
                title: Text(issue.code),
                subtitle: Text(issue.message),
                onTap: issue.shapeId.isEmpty
                    ? null
                    : () => _focusIssue(authoring, issue),
              ),
        ],
      ),
    );
  }

  Widget _buildVertexInspector(
    PrefabPolygonAuthoringController authoring,
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
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        for (final entry in shape.vertices.asMap().entries)
          ListTile(
            key: ValueKey<String>(
              'prefab_polygon_vertex_${shape.shapeId}_${entry.key}',
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            selected: entry.key == selectedVertexIndex,
            onTap: () => authoring.select(
              TerrainPolygonSelection.vertex(shape.shapeId, entry.key),
            ),
            title: Text('v${entry.key}'),
            trailing: Text(
              '(${_formatHalfPixels(entry.value.xHalfPixels)}, '
              '${_formatHalfPixels(entry.value.yHalfPixels)})',
            ),
          ),
        if (selectedVertexIndex != null) ...<Widget>[
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          _VertexCoordinateEditor(
            key: ValueKey<String>(
              'prefab_polygon_vertex_editor_${shape.shapeId}_'
              '${selectedVertexIndex}_'
              '${shape.vertices[selectedVertexIndex].xHalfPixels}_'
              '${shape.vertices[selectedVertexIndex].yHalfPixels}',
            ),
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
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) async {
    var collisionMode = shape.collisionMode;
    final surfaceController = TextEditingController(
      text: shape.surfaceKind ?? '',
    );
    final materialController = TextEditingController(
      text: shape.materialKey ?? '',
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${shape.shapeId} metadata'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<TerrainSourceCollisionMode>(
                initialValue: collisionMode,
                decoration: const InputDecoration(labelText: 'Collision mode'),
                items: TerrainSourceCollisionMode.values
                    .map(
                      (mode) => DropdownMenuItem<TerrainSourceCollisionMode>(
                        value: mode,
                        child: Text(mode.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => collisionMode = value);
                  }
                },
              ),
              TextField(
                controller: surfaceController,
                decoration: const InputDecoration(labelText: 'Surface kind'),
              ),
              TextField(
                controller: materialController,
                decoration: const InputDecoration(labelText: 'Material key'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      authoring.editSelectedShapeMetadata(
        collisionMode: collisionMode,
        surfaceKind: _nullableText(surfaceController.text),
        materialKey: _nullableText(materialController.text),
      );
    }
    surfaceController.dispose();
    materialController.dispose();
  }

  void _focusIssue(
    PrefabPolygonAuthoringController authoring,
    PrefabValidationIssue issue,
  ) {
    final shape = _findShape(authoring.state.visibleShapes, issue.shapeId);
    if (shape == null) return;
    final index = issue.elementIndex;
    if (issue.code.contains('vertex') && index < shape.vertices.length) {
      authoring.select(TerrainPolygonSelection.vertex(shape.shapeId, index));
    } else if (issue.code.contains('edge') && index < shape.vertices.length) {
      authoring.select(TerrainPolygonSelection.edge(shape.shapeId, index));
    } else {
      authoring.select(TerrainPolygonSelection.shape(shape.shapeId));
    }
    final minX = shape.vertices
        .map((vertex) => vertex.xHalfPixels)
        .reduce(math.min);
    final maxX = shape.vertices
        .map((vertex) => vertex.xHalfPixels)
        .reduce(math.max);
    final minY = shape.vertices
        .map((vertex) => vertex.yHalfPixels)
        .reduce(math.min);
    final maxY = shape.vertices
        .map((vertex) => vertex.yHalfPixels)
        .reduce(math.max);
    setState(() {
      _pan = Offset(
        -((minX + maxX) * 0.25 * _zoom),
        -((minY + maxY) * 0.25 * _zoom),
      );
    });
  }

  List<PrefabValidationIssue> _ownerIssues(
    PrefabV3StagingDocument document,
    PrefabV3Def prefab,
    Iterable<PrefabValidationIssue> localIssues,
  ) {
    final bounds = document.visualBoundsByPrefabKey[prefab.prefabKey];
    final combined = <PrefabValidationIssue>[
      ...localIssues,
      ...validatePrefabCollisionShapes(
        prefabId: prefab.id,
        prefabKey: prefab.prefabKey,
        kind: prefab.kind,
        anchorXPx: prefab.anchorXPx,
        anchorYPx: prefab.anchorYPx,
        collisionShapes: prefab.collisionShapes,
        sourceWidthPx: bounds?.widthPx,
        sourceHeightPx: bounds?.heightPx,
        sourcePath:
            'assets/authoring/level/prefab_defs.json:${prefab.prefabKey}',
      ),
    ];
    final seen = <String>{};
    final unique =
        combined
            .where((issue) {
              return seen.add(
                '${issue.code}|${issue.sourcePath}|${issue.shapeId}|'
                '${issue.elementIndex}|${issue.message}',
              );
            })
            .toList(growable: false)
          ..sort((left, right) {
            var order = left.sourcePath.compareTo(right.sourcePath);
            if (order != 0) return order;
            order = left.shapeId.compareTo(right.shapeId);
            if (order != 0) return order;
            order = left.elementIndex.compareTo(right.elementIndex);
            if (order != 0) return order;
            return left.code.compareTo(right.code);
          });
    return unique;
  }

  void _selectInitialOwner() {
    final document = _documentOrNull;
    if (document == null || document.data.prefabs.isEmpty) return;
    final prefabs = List<PrefabV3Def>.of(document.data.prefabs)
      ..sort(_comparePrefabs);
    final preferred = prefabs.where(
      (prefab) => prefab.kind != PrefabKind.decoration,
    );
    _bindOwner(
      preferred.isNotEmpty
          ? preferred.first.prefabKey
          : prefabs.first.prefabKey,
    );
  }

  void _selectOwner(String prefabKey) {
    if (prefabKey == _selectedPrefabKey) return;
    setState(() {
      _bindOwner(prefabKey);
      _resetViewportValues();
    });
  }

  void _bindOwner(String prefabKey) {
    _disposeAuthoring();
    _selectedPrefabKey = prefabKey;
    _authoring = PrefabPolygonAuthoringController(
      session: widget.controller,
      prefabKey: prefabKey,
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

  PrefabV3StagingDocument? get _documentOrNull {
    final document = widget.controller.document;
    return document is PrefabV3StagingDocument ? document : null;
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

class _VertexCoordinateEditor extends StatefulWidget {
  const _VertexCoordinateEditor({
    super.key,
    required this.shapeId,
    required this.vertexIndex,
    required this.vertex,
    required this.onApply,
  });

  final String shapeId;
  final int vertexIndex;
  final TerrainSourceVertexDef vertex;
  final void Function(int xHalfPixels, int yHalfPixels) onApply;

  @override
  State<_VertexCoordinateEditor> createState() =>
      _VertexCoordinateEditorState();
}

class _VertexCoordinateEditorState extends State<_VertexCoordinateEditor> {
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  String? _xError;
  String? _yError;

  @override
  void initState() {
    super.initState();
    _xController = TextEditingController(
      text: TerrainHalfPixelText.formatTicks(widget.vertex.xHalfPixels),
    );
    _yController = TextEditingController(
      text: TerrainHalfPixelText.formatTicks(widget.vertex.yHalfPixels),
    );
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Edit ${widget.shapeId} v${widget.vertexIndex}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const ValueKey<String>('prefab_polygon_vertex_x_field'),
                controller: _xController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'X (px)',
                  errorText: _xError,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _apply(),
              ),
            ),
            const SizedBox(width: PrefabEditorUiTokens.controlGap),
            Expanded(
              child: TextField(
                key: const ValueKey<String>('prefab_polygon_vertex_y_field'),
                controller: _yController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Y (px)',
                  errorText: _yError,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _apply(),
              ),
            ),
          ],
        ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        FilledButton.icon(
          key: const ValueKey<String>('prefab_polygon_apply_vertex'),
          onPressed: _apply,
          icon: const Icon(Icons.check),
          label: const Text('Apply exact vertex'),
        ),
      ],
    );
  }

  void _apply() {
    final xHalfPixels = TerrainHalfPixelText.tryParseTicks(_xController.text);
    final yHalfPixels = TerrainHalfPixelText.tryParseTicks(_yController.text);
    setState(() {
      _xError = xHalfPixels == null ? 'Use an integer or .5 value.' : null;
      _yError = yHalfPixels == null ? 'Use an integer or .5 value.' : null;
    });
    if (xHalfPixels == null || yHalfPixels == null) return;
    widget.onApply(xHalfPixels, yHalfPixels);
  }
}

int _comparePrefabs(PrefabV3Def left, PrefabV3Def right) {
  final kindOrder = _kindOrder(left.kind).compareTo(_kindOrder(right.kind));
  if (kindOrder != 0) return kindOrder;
  final idOrder = left.id.compareTo(right.id);
  return idOrder != 0 ? idOrder : left.prefabKey.compareTo(right.prefabKey);
}

int _kindOrder(PrefabKind kind) => switch (kind) {
  PrefabKind.obstacle => 0,
  PrefabKind.platform => 1,
  PrefabKind.decoration => 2,
  PrefabKind.unknown => 3,
};

String _toolLabel(TerrainPolygonTool tool) => switch (tool) {
  TerrainPolygonTool.select => 'Select',
  TerrainPolygonTool.createPolygon => 'Create',
  TerrainPolygonTool.moveVertex => 'Move vertex',
  TerrainPolygonTool.translateShape => 'Move shape',
  TerrainPolygonTool.insertVertex => 'Insert vertex',
};

String _shapeExtent(TerrainSourceShapeDef shape) {
  final xs = shape.vertices.map((vertex) => vertex.xHalfPixels);
  final ys = shape.vertices.map((vertex) => vertex.yHalfPixels);
  return 'x ${_formatHalfPixels(xs.reduce(math.min))}..'
      '${_formatHalfPixels(xs.reduce(math.max))}, y '
      '${_formatHalfPixels(ys.reduce(math.min))}..'
      '${_formatHalfPixels(ys.reduce(math.max))}';
}

String _formatHalfPixels(int ticks) {
  final magnitude = ticks.abs();
  final value = magnitude.isEven ? '${magnitude ~/ 2}' : '${magnitude ~/ 2}.5';
  return '${ticks < 0 ? '-' : ''}$value px';
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

String? _nullableText(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
