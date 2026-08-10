import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../../prefabs/domain/prefab_v3_lifecycle_commit.dart';
import '../../../../prefabs/domain/prefab_v3_metadata_commit.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/validation/prefab_validation.dart';
import '../../../../session/editor_session_controller.dart';
import '../../../../terrain_authoring/terrain_polygon_duplicate_offset.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/terrain_polygon_metadata_dialog.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import '../../shared/terrain_polygon_vertex_editor.dart';
import '../shared/prefab_polygon_authoring_controller.dart';
import '../shared/prefab_polygon_scene_surface.dart';
import '../shared/prefab_polygon_visual_source.dart';
import '../shared/ui/prefab_editor_panel_card.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';
import '../shared/ui/prefab_editor_ui_tokens.dart';
import 'prefab_v3_atlas_catalog_workspace.dart';
import 'prefab_v3_module_catalog_workspace.dart';
import 'prefab_v3_owner_dialog.dart';

/// Explicit prefab-v3 polygon workspace used before the schema cutover.
///
/// Legacy source still loads the v2 rectangle workflow. Current v3 source and
/// explicit owner navigation select this page through [PrefabV3StagingScene].
/// Source apply is available only for already-current files and cannot migrate
/// legacy source.
class PrefabPolygonStagingWorkspace extends StatefulWidget {
  const PrefabPolygonStagingWorkspace({
    super.key,
    required this.controller,
    this.initialPrefabKey,
  });

  final EditorSessionController controller;

  /// Stable owner to prefer over the workspace's deterministic default.
  final String? initialPrefabKey;

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
  final GlobalKey<PrefabV3AtlasCatalogWorkspaceState> _atlasWorkspaceKey =
      GlobalKey<PrefabV3AtlasCatalogWorkspaceState>();
  final GlobalKey<PrefabV3ModuleCatalogWorkspaceState> _moduleWorkspaceKey =
      GlobalKey<PrefabV3ModuleCatalogWorkspaceState>();
  String? _selectedPrefabKey;
  _PrefabV3WorkspaceView _workspaceView = _PrefabV3WorkspaceView.owners;
  double _zoom = _initialZoom;
  Offset _pan = Offset.zero;

  bool get hasLocalDraftChanges =>
      (_authoring?.hasActiveOperation ?? false) ||
      (_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) ||
      (_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) ||
      widget.controller.pendingChanges.hasChanges;

  bool get canUndo =>
      (_authoring?.hasActiveOperation ?? false) ||
      (_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) ||
      (_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) ||
      widget.controller.canUndo;

  bool get canRedo =>
      !(_authoring?.hasActiveOperation ?? false) &&
      !(_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) &&
      !(_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) &&
      widget.controller.canRedo;

  bool handleUndoShortcut() {
    if (_workspaceView == _PrefabV3WorkspaceView.atlasSlices &&
        (_atlasWorkspaceKey.currentState?.cancelLocalDraft() ?? false)) {
      return true;
    }
    if (_workspaceView == _PrefabV3WorkspaceView.platformModules &&
        (_moduleWorkspaceKey.currentState?.cancelLocalDraft() ?? false)) {
      return true;
    }
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
        (_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) ||
        (_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false)) {
      return false;
    }
    if (!widget.controller.canRedo) return false;
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
  void didUpdateWidget(covariant PrefabPolygonStagingWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _disposeAuthoring();
      _selectedPrefabKey = null;
      _selectInitialOwner();
      return;
    }
    if (oldWidget.initialPrefabKey != widget.initialPrefabKey) {
      final targetKey = _requestedOwnerKey(_documentOrNull);
      if (targetKey != null && targetKey != _selectedPrefabKey) {
        _bindOwner(targetKey);
        _resetViewportValues();
      }
    }
  }

  @override
  void dispose() {
    _disposeAuthoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = _documentOrNull;
    if (document == null) {
      return const Center(
        child: Text('Prefab-v3 staging scene is no longer loaded.'),
      );
    }
    _reconcileReloadedOwner(document);
    final authoring = _authoring;
    final prefab = authoring?.prefab;
    final issues = prefab == null
        ? const <PrefabValidationIssue>[]
        : _ownerIssues(document, prefab, authoring!.issues);
    final ownerWorkspace = prefab == null || authoring == null
        ? _buildEmptyOwnerState(document)
        : PrefabEditorThreePanelLayout(
            inspector: _buildOwnerPanel(document, prefab, authoring),
            scene: _buildScenePanel(document, prefab, authoring),
            display: _buildShapePanel(authoring, issues),
          );

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
              child: IndexedStack(
                index: _workspaceView.index,
                children: <Widget>[
                  ownerWorkspace,
                  PrefabV3AtlasCatalogWorkspace(
                    key: _atlasWorkspaceKey,
                    controller: widget.controller,
                    document: document,
                  ),
                  PrefabV3ModuleCatalogWorkspace(
                    key: _moduleWorkspaceKey,
                    controller: widget.controller,
                    document: document,
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
    PrefabV3StagingDocument document,
    PrefabPolygonAuthoringController? authoring,
  ) {
    final changedCount = document.changedPrefabKeys.length;
    final changedKeys = document.changedPrefabKeys.toSet();
    final affectedImpacts = document.downstreamImpacts
        .where((impact) => changedKeys.contains(impact.prefabKey))
        .toList(growable: false);
    final affectedPlacementCount = affectedImpacts.fold<int>(
      0,
      (total, impact) => total + impact.placementCount,
    );
    final affectedChunkCount = affectedImpacts
        .expand((impact) => impact.referencingChunkKeys)
        .toSet()
        .length;
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
              key: const ValueKey<String>('prefab_polygon_apply_source'),
              onPressed:
                  widget.controller.pendingChanges.hasChanges &&
                      !(authoring?.hasActiveOperation ?? false) &&
                      !(_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ??
                          false) &&
                      !(_moduleWorkspaceKey
                              .currentState
                              ?.hasLocalDraftChanges ??
                          false) &&
                      !widget.controller.isLoading &&
                      !widget.controller.isExporting
                  ? _confirmAndApplyToFiles
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Apply current source'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('prefab_polygon_undo_button'),
              onPressed:
                  (authoring?.hasActiveOperation ?? false) ||
                      widget.controller.canUndo
                  ? handleUndoShortcut
                  : null,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('prefab_polygon_redo_button'),
              onPressed:
                  (authoring?.hasActiveOperation ?? false) ||
                      !widget.controller.canRedo
                  ? null
                  : handleRedoShortcut,
              icon: const Icon(Icons.redo),
              label: const Text('Redo'),
            ),
            Text(
              changedCount == 0
                  ? 'No staged prefab changes'
                  : '$changedCount staged prefab change(s)',
            ),
            if (changedCount > 0)
              Text(
                key: const ValueKey<String>('prefab_polygon_downstream_impact'),
                '$affectedPlacementCount placement(s) in '
                '$affectedChunkCount chunk(s) affected; chunk revisions stay '
                'unchanged.',
              ),
          ],
        ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        const Text(
          'Current-schema workspace: apply rechecks both source baselines and '
          'commits the prefab/tile pair atomically. Legacy migration and '
          'runtime terrain activation remain separate cutover steps.',
          style: TextStyle(color: Color(0xFFFFD166)),
        ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        Wrap(
          spacing: PrefabEditorUiTokens.controlGap,
          runSpacing: PrefabEditorUiTokens.controlGap,
          children: <Widget>[
            ChoiceChip(
              key: const ValueKey<String>('prefab_v3_view_owners'),
              label: const Text('Prefab owners & collision'),
              selected: _workspaceView == _PrefabV3WorkspaceView.owners,
              onSelected: (_) =>
                  _selectWorkspaceView(_PrefabV3WorkspaceView.owners),
            ),
            ChoiceChip(
              key: const ValueKey<String>('prefab_v3_view_atlas_slices'),
              label: const Text('Atlas & tile slices'),
              selected: _workspaceView == _PrefabV3WorkspaceView.atlasSlices,
              onSelected: (_) =>
                  _selectWorkspaceView(_PrefabV3WorkspaceView.atlasSlices),
            ),
            ChoiceChip(
              key: const ValueKey<String>('prefab_v3_view_platform_modules'),
              label: const Text('Platform modules'),
              selected:
                  _workspaceView == _PrefabV3WorkspaceView.platformModules,
              onSelected: (_) =>
                  _selectWorkspaceView(_PrefabV3WorkspaceView.platformModules),
            ),
          ],
        ),
      ],
    );
  }

  void _selectWorkspaceView(_PrefabV3WorkspaceView view) {
    if (view == _workspaceView) return;
    if (_authoring?.hasActiveOperation ?? false) {
      _showWorkspaceSwitchBlocked(
        'Finish or cancel the active polygon operation before switching.',
      );
      return;
    }
    if (_workspaceView == _PrefabV3WorkspaceView.atlasSlices &&
        (_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false)) {
      _showWorkspaceSwitchBlocked(
        'Apply the slice form or undo its local draft before switching.',
      );
      return;
    }
    if (_workspaceView == _PrefabV3WorkspaceView.platformModules &&
        (_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false)) {
      _showWorkspaceSwitchBlocked(
        'Apply the module form or undo its local draft before switching.',
      );
      return;
    }
    setState(() => _workspaceView = view);
  }

  void _showWorkspaceSwitchBlocked(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmAndApplyToFiles() async {
    final pendingChanges = widget.controller.pendingChanges;
    if (!pendingChanges.hasChanges) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply Prefab-v3 Changes'),
        content: Text(
          'Write ${pendingChanges.changedItemIds.length} prefab change(s) '
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
              ? 'Prefab-v3 changes applied.'
              : 'Prefab-v3 apply failed: $error',
        ),
      ),
    );
  }

  Widget _buildOwnerPanel(
    PrefabV3StagingDocument document,
    PrefabV3Def selectedPrefab,
    PrefabPolygonAuthoringController authoring,
  ) {
    final prefabs = List<PrefabV3Def>.of(document.data.prefabs)
      ..sort(_comparePrefabs);
    return PrefabEditorPanelCard(
      title: 'Prefab owners',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildOwnerActions(
            document,
            selectedPrefab: selectedPrefab,
            controlsEnabled: !authoring.hasActiveOperation,
          ),
          const Divider(height: 28),
          for (final prefab in prefabs)
            Builder(
              builder: (context) {
                final impact = document.downstreamImpacts
                    .where((entry) => entry.prefabKey == prefab.prefabKey)
                    .firstOrNull;
                return Card(
                  key: ValueKey<String>(
                    'prefab_polygon_owner_${prefab.prefabKey}',
                  ),
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
                      '${prefab.tags.isEmpty ? '' : ' · ${prefab.tags.join(', ')}'}'
                      '\n${impact?.placementCount ?? 0} downstream '
                      'placement(s) in '
                      '${impact?.referencingChunkKeys.length ?? 0} chunk(s)',
                    ),
                    isThreeLine: true,
                    trailing:
                        document.changedPrefabKeys.contains(prefab.prefabKey)
                        ? const Tooltip(
                            message: 'Staged prefab changed',
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

  Widget _buildEmptyOwnerState(PrefabV3StagingDocument document) {
    return PrefabEditorPanelCard(
      title: 'Prefab owners',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildOwnerActions(
            document,
            selectedPrefab: null,
            controlsEnabled: true,
          ),
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          const Text(
            'No prefab owners remain. Create one from a retained atlas slice '
            'or platform module.',
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerActions(
    PrefabV3StagingDocument document, {
    required PrefabV3Def? selectedPrefab,
    required bool controlsEnabled,
  }) {
    final canCreate =
        document.data.slices.isNotEmpty ||
        document.tileData.platformModules.isNotEmpty;
    return Wrap(
      spacing: PrefabEditorUiTokens.controlGap,
      runSpacing: PrefabEditorUiTokens.controlGap,
      children: <Widget>[
        FilledButton.icon(
          key: const ValueKey<String>('prefab_v3_owner_create'),
          onPressed: controlsEnabled && canCreate
              ? () => _createOwner(document)
              : null,
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('prefab_v3_owner_edit'),
          onPressed: controlsEnabled && selectedPrefab != null
              ? () => _editOwner(document, selectedPrefab)
              : null,
          icon: const Icon(Icons.tune),
          label: const Text('Edit'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('prefab_v3_owner_duplicate'),
          onPressed: controlsEnabled && selectedPrefab != null
              ? () => _duplicateOwner(document, selectedPrefab)
              : null,
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Duplicate'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('prefab_v3_owner_rename'),
          onPressed: controlsEnabled && selectedPrefab != null
              ? () => _renameOwner(document, selectedPrefab)
              : null,
          icon: const Icon(Icons.drive_file_rename_outline),
          label: const Text('Rename'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('prefab_v3_owner_delete'),
          onPressed: controlsEnabled && selectedPrefab != null
              ? () => _deleteOwner(document, selectedPrefab)
              : null,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
      ],
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
                  onPressed: authoring.hasActiveOperation
                      ? null
                      : () => _duplicateSelectedShape(authoring, selectedShape),
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
          TerrainPolygonVertexEditor(
            key: ValueKey<String>(
              'prefab_polygon_vertex_editor_${shape.shapeId}_'
              '${selectedVertexIndex}_'
              '${shape.vertices[selectedVertexIndex].xHalfPixels}_'
              '${shape.vertices[selectedVertexIndex].yHalfPixels}',
            ),
            keyPrefix: 'prefab_polygon',
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
            controlGap: PrefabEditorUiTokens.controlGap,
          ),
        ],
      ],
    );
  }

  Future<void> _editMetadata(
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) async {
    final edit = await showTerrainPolygonMetadataDialog(
      context,
      keyPrefix: 'prefab_polygon',
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
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    final offset = findTerrainPolygonDuplicateOffset(
      selectedShape: shape,
      ownerShapes: authoring.state.shapes,
      snapStepHalfPixels: authoring.snapPolicy.stepHalfPixels,
    );
    if (offset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No free duplicate position found.')),
      );
      return;
    }
    authoring.duplicateSelectedShape(
      deltaXHalfPixels: offset.deltaXHalfPixels,
      deltaYHalfPixels: offset.deltaYHalfPixels,
    );
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

  Future<void> _createOwner(PrefabV3StagingDocument document) async {
    final edit = await showPrefabV3OwnerDialog(context, document: document);
    if (edit == null || !mounted) return;
    final beforeKeys = document.data.prefabs
        .map((prefab) => prefab.prefabKey)
        .toSet();
    final next = _dispatchLifecycle(
      document,
      PrefabV3CreateOperation(
        id: edit.id!,
        kind: edit.kind,
        visualSource: edit.visualSource,
        anchorXPx: edit.anchorXPx,
        anchorYPx: edit.anchorYPx,
        tags: edit.tags,
      ),
    );
    if (next == null) return;
    final createdKeys = next.data.prefabs
        .map((prefab) => prefab.prefabKey)
        .where((key) => !beforeKeys.contains(key))
        .toList(growable: false);
    _syncOwnerAfterSessionMutation(preferredPrefabKey: createdKeys.firstOrNull);
  }

  Future<void> _editOwner(
    PrefabV3StagingDocument document,
    PrefabV3Def prefab,
  ) async {
    final edit = await showPrefabV3OwnerDialog(
      context,
      document: document,
      prefab: prefab,
    );
    if (edit == null || !mounted) return;
    final before = PrefabV3MetadataSnapshot.fromPrefab(prefab);
    final after = PrefabV3MetadataSnapshot(
      status: edit.status,
      kind: edit.kind,
      visualSource: edit.visualSource,
      anchorXPx: edit.anchorXPx,
      anchorYPx: edit.anchorYPx,
      tags: edit.tags,
    );
    if (before == after) return;
    final beforeDocument = widget.controller.document;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3MetadataCommandKind,
        payload: <String, Object?>{
          'prefabKey': prefab.prefabKey,
          'commit': PrefabV3MetadataCommit(before: before, after: after),
        },
      ),
    );
    if (identical(widget.controller.document, beforeDocument)) {
      _showOwnerMutationRejected();
      return;
    }
    _syncOwnerAfterSessionMutation(preferredPrefabKey: prefab.prefabKey);
  }

  void _duplicateOwner(PrefabV3StagingDocument document, PrefabV3Def prefab) {
    final beforeKeys = document.data.prefabs
        .map((owner) => owner.prefabKey)
        .toSet();
    final next = _dispatchLifecycle(
      document,
      PrefabV3DuplicateOperation(sourcePrefabKey: prefab.prefabKey),
    );
    if (next == null) return;
    final duplicateKeys = next.data.prefabs
        .map((owner) => owner.prefabKey)
        .where((key) => !beforeKeys.contains(key))
        .toList(growable: false);
    _syncOwnerAfterSessionMutation(
      preferredPrefabKey: duplicateKeys.firstOrNull,
    );
  }

  Future<void> _renameOwner(
    PrefabV3StagingDocument document,
    PrefabV3Def prefab,
  ) async {
    final nextId = await showPrefabV3RenameDialog(
      context,
      document: document,
      prefab: prefab,
    );
    if (nextId == null || !mounted || nextId == prefab.id) return;
    final next = _dispatchLifecycle(
      document,
      PrefabV3RenameOperation(prefabKey: prefab.prefabKey, nextId: nextId),
    );
    if (next != null) {
      _syncOwnerAfterSessionMutation(preferredPrefabKey: prefab.prefabKey);
    }
  }

  Future<void> _deleteOwner(
    PrefabV3StagingDocument document,
    PrefabV3Def prefab,
  ) async {
    final impact = document.downstreamImpacts
        .where((entry) => entry.prefabKey == prefab.prefabKey)
        .firstOrNull;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${prefab.id}?'),
        content: Text(
          'This removes the prefab owner and its polygon source. '
          '${impact?.placementCount ?? 0} placement(s) in '
          '${impact?.referencingChunkKeys.length ?? 0} chunk(s) currently '
          'reference this stable key; those chunks are not mutated.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('prefab_v3_owner_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete owner'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final next = _dispatchLifecycle(
      document,
      PrefabV3DeleteOperation(prefabKey: prefab.prefabKey),
    );
    if (next != null) _syncOwnerAfterSessionMutation();
  }

  PrefabV3StagingDocument? _dispatchLifecycle(
    PrefabV3StagingDocument document,
    PrefabV3LifecycleOperation operation,
  ) {
    final beforeDocument = widget.controller.document;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3LifecycleCommandKind,
        payload: <String, Object?>{
          'commit': PrefabV3LifecycleCommit(
            before: PrefabV3LifecycleSnapshot.fromDocument(document),
            operation: operation,
          ),
        },
      ),
    );
    final next = widget.controller.document;
    if (identical(next, beforeDocument) || next is! PrefabV3StagingDocument) {
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
          'Prefab change was rejected. Review validation diagnostics and '
          'retry from the current owner state.',
        ),
      ),
    );
  }

  void _syncOwnerAfterSessionMutation({String? preferredPrefabKey}) {
    if (!mounted) return;
    final document = _documentOrNull;
    if (document == null) return;
    final keys = document.data.prefabs
        .map((prefab) => prefab.prefabKey)
        .toSet();
    String? nextKey;
    if (preferredPrefabKey != null && keys.contains(preferredPrefabKey)) {
      nextKey = preferredPrefabKey;
    } else if (_selectedPrefabKey != null &&
        keys.contains(_selectedPrefabKey)) {
      nextKey = _selectedPrefabKey;
    } else {
      nextKey = _preferredOwnerKey(document);
    }
    if (nextKey == null) {
      _disposeAuthoring();
      setState(() => _selectedPrefabKey = null);
      return;
    }
    if (_authoring?.prefabKey == nextKey) {
      setState(() {});
      return;
    }
    setState(() {
      _bindOwner(nextKey!);
      _resetViewportValues();
    });
  }

  void _selectInitialOwner() {
    final document = _documentOrNull;
    if (document == null) return;
    final prefabKey = _preferredOwnerKey(document);
    if (prefabKey != null) _bindOwner(prefabKey);
  }

  void _reconcileReloadedOwner(PrefabV3StagingDocument document) {
    final selectedKey = _selectedPrefabKey;
    if (selectedKey != null &&
        document.data.prefabs.any(
          (prefab) => prefab.prefabKey == selectedKey,
        )) {
      return;
    }
    _disposeAuthoring();
    _selectedPrefabKey = null;
    final nextKey = _preferredOwnerKey(document);
    if (nextKey != null) {
      _bindOwner(nextKey);
      _resetViewportValues();
    }
  }

  String? _preferredOwnerKey(PrefabV3StagingDocument document) {
    final requestedKey = _requestedOwnerKey(document);
    if (requestedKey != null) return requestedKey;
    if (document.data.prefabs.isEmpty) return null;
    final prefabs = List<PrefabV3Def>.of(document.data.prefabs)
      ..sort(_comparePrefabs);
    return prefabs
            .where((prefab) => prefab.kind != PrefabKind.decoration)
            .firstOrNull
            ?.prefabKey ??
        prefabs.first.prefabKey;
  }

  String? _requestedOwnerKey(PrefabV3StagingDocument? document) {
    if (document == null) return null;
    final requestedKey = widget.initialPrefabKey?.trim();
    if (requestedKey == null || requestedKey.isEmpty) return null;
    return document.data.prefabs.any(
          (prefab) => prefab.prefabKey == requestedKey,
        )
        ? requestedKey
        : null;
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

enum _PrefabV3WorkspaceView { owners, atlasSlices, platformModules }

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
