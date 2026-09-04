import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/collision_fitting/prefab_collision_fitting.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../../prefabs/domain/prefab_platform_pairing.dart';
import '../../../../prefabs/domain/prefab_v3_catalog_commit.dart';
import '../../../../prefabs/domain/prefab_v3_lifecycle_commit.dart';
import '../../../../prefabs/domain/prefab_v3_metadata_commit.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/validation/prefab_validation.dart';
import '../../../../session/editor_session_controller.dart';
import '../../../../terrain_authoring/terrain_polygon_duplicate_offset.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_axis_aligned_rectangle.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_inline_id_form.dart';
import '../../shared/editor_owner_draft_state.dart';
import '../../shared/editor_panel_card.dart';
import '../../shared/editor_pending_changes_dialog.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_ui_tokens.dart';
import '../../shared/editor_workspace_card.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/terrain_polygon_exact_edit_controller.dart';
import '../../shared/terrain_polygon_rectangle_editor.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import '../../shared/terrain_polygon_vertex_editor.dart';
import '../atlas_slicer/atlas_image_file_picker.dart';
import '../shared/prefab_polygon_authoring_controller.dart';
import '../shared/prefab_polygon_scene_surface.dart';
import '../shared/prefab_polygon_visual_source.dart';
import '../shared/prefab_visual_alpha_mask_loader.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';
import 'prefab_v3_atlas_catalog_workspace.dart';
import 'prefab_collision_owner_panel.dart';
import 'prefab_collision_catalog.dart';
import 'prefab_fit_draft_editor.dart';
import 'prefab_library_panel.dart';
import 'prefab_owner_order.dart';
import 'prefab_owner_panels.dart';
import 'prefab_v3_module_catalog_workspace.dart';
import 'prefab_v3_owner_form.dart';
import 'prefab_visual_preview_panel.dart';
import 'prefab_workspace_view_selector.dart';

/// Normal prefab-v3 polygon authoring workspace.
///
/// Current v3 source and explicit owner navigation select this page through
/// [PrefabV3Scene]. Legacy or missing source opens the fail-closed migration
/// workspace; source apply cannot perform migration.
class PrefabPolygonWorkspace extends StatefulWidget {
  const PrefabPolygonWorkspace({
    super.key,
    required this.controller,
    required this.atlasImageFilePicker,
    this.initialPrefabKey,
  });

  final EditorSessionController controller;
  final AtlasImageFilePicker atlasImageFilePicker;

  /// Stable owner to prefer over the workspace's deterministic default.
  final String? initialPrefabKey;

  @override
  State<PrefabPolygonWorkspace> createState() => PrefabPolygonWorkspaceState();
}

/// Shortcut and local-draft contract exposed to the containing editor route.
class PrefabPolygonWorkspaceState extends State<PrefabPolygonWorkspace> {
  static const double _initialZoom = 4;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 12;
  static const double _zoomStep = 0.5;

  PrefabPolygonAuthoringController? _authoring;
  final GlobalKey<PrefabV3AtlasCatalogWorkspaceState> _atlasWorkspaceKey =
      GlobalKey<PrefabV3AtlasCatalogWorkspaceState>();
  final GlobalKey<PrefabV3ModuleCatalogWorkspaceState> _moduleWorkspaceKey =
      GlobalKey<PrefabV3ModuleCatalogWorkspaceState>();
  final GlobalKey<PrefabV3OwnerFormState> _ownerEditFormKey =
      GlobalKey<PrefabV3OwnerFormState>();
  final GlobalKey<PrefabV3OwnerFormState> _ownerCreateFormKey =
      GlobalKey<PrefabV3OwnerFormState>();
  final GlobalKey<EditorInlineIdFormState> _ownerRenameFormKey =
      GlobalKey<EditorInlineIdFormState>();
  final Map<String, String> _shapeNameDrafts = <String, String>{};
  final TerrainPolygonExactEditController _exactEditController =
      TerrainPolygonExactEditController();
  final EditorOwnerDraftState<PrefabV3Def, PrefabV3Document> _ownerDraft =
      EditorOwnerDraftState<PrefabV3Def, PrefabV3Document>();
  String? _selectedPrefabKey;
  PrefabWorkspaceView _workspaceView = PrefabWorkspaceView.prefabs;
  double _zoom = _initialZoom;
  Offset _pan = Offset.zero;
  late EditorUiImageCache _prefabImageCache;
  late PrefabVisualAlphaMaskCache _prefabMaskCache;
  PrefabCollisionCreationMethod _creationMethod =
      PrefabCollisionCreationMethod.traceVisibleOutline;
  PrefabCollisionFitSettings _fitSettings = const PrefabCollisionFitSettings();
  String? _pendingRefitShapeId;
  bool _fitAdvancedExpanded = false;
  bool _observedFitDraft = false;

  PrefabV3Def? get _ownerEditSource => _ownerDraft.editSource;
  bool get _ownerEditDirty => _ownerDraft.editDirty;
  bool get _ownerRenameActive => _ownerDraft.renameActive;
  bool get _ownerCreateExpanded => _ownerDraft.createExpanded;
  bool get _ownerCreateDirty => _ownerDraft.createDirty;
  PrefabV3Document? get _ownerCreateSource => _ownerDraft.createSource;

  bool get hasLocalDraftChanges =>
      (_authoring?.hasActiveOperation ?? false) ||
      _hasPendingSelectedShapeEdit ||
      _ownerEditDirty ||
      _ownerCreateDirty ||
      (_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) ||
      (_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) ||
      widget.controller.pendingChanges.hasChanges;

  bool get canUndo =>
      _hasPendingSelectedShapeEdit ||
      _ownerEditDirty ||
      _ownerCreateDirty ||
      (_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) ||
      (_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) ||
      (_authoring?.canUndo ?? widget.controller.canUndo);

  bool get canRedo =>
      !_hasPendingSelectedShapeEdit &&
      !_ownerEditDirty &&
      !_ownerCreateDirty &&
      !(_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) &&
      !(_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) &&
      (_authoring?.canRedo ?? widget.controller.canRedo);

  /// True when the shell may apply the current prefab source atomically.
  bool get canApplyToFiles =>
      widget.controller.pendingChanges.hasChanges &&
      !(_authoring?.hasActiveOperation ?? false) &&
      !_hasPendingSelectedShapeEdit &&
      !_ownerEditDirty &&
      !_ownerCreateDirty &&
      !(_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) &&
      !(_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) &&
      !widget.controller.isLoading &&
      !widget.controller.isExporting;

  bool handleUndoShortcut() {
    if (_ownerCreateDirty) {
      _closeOwnerCreateSection();
      return true;
    }
    if (_ownerEditDirty) {
      _closeOwnerEditor();
      return true;
    }
    if (_ownerEditSource != null) _closeOwnerEditor();
    if (_hasPendingSelectedShapeEdit) {
      _discardSelectedShapeEdit();
      return true;
    }
    if (_workspaceView == PrefabWorkspaceView.atlasSlices &&
        (_atlasWorkspaceKey.currentState?.cancelLocalDraft() ?? false)) {
      return true;
    }
    if (_workspaceView == PrefabWorkspaceView.platformModules &&
        (_moduleWorkspaceKey.currentState?.cancelLocalDraft() ?? false)) {
      return true;
    }
    final authoring = _authoring;
    if (authoring != null) return authoring.undo();
    if (!widget.controller.canUndo) return false;
    widget.controller.undo();
    return true;
  }

  bool handleRedoShortcut() {
    if (_ownerEditDirty ||
        _ownerCreateDirty ||
        (_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false) ||
        (_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false)) {
      return false;
    }
    if (_ownerEditSource != null) _closeOwnerEditor();
    final authoring = _authoring;
    if (authoring != null) return authoring.redo();
    if (!widget.controller.canRedo) return false;
    widget.controller.redo();
    return true;
  }

  @override
  void initState() {
    super.initState();
    _prefabImageCache = EditorUiImageCache();
    _prefabMaskCache = PrefabVisualAlphaMaskCache();
    _exactEditController.addListener(_handleExactEditChanged);
    _selectInitialOwner();
  }

  @override
  void didUpdateWidget(covariant PrefabPolygonWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _prefabImageCache.dispose();
      _prefabImageCache = EditorUiImageCache();
      _prefabMaskCache = PrefabVisualAlphaMaskCache();
      _disposeAuthoring();
      _clearOwnerEditorState();
      _clearOwnerCreateState();
      _selectedPrefabKey = null;
      _workspaceView = PrefabWorkspaceView.prefabs;
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
    _prefabImageCache.dispose();
    _exactEditController
      ..removeListener(_handleExactEditChanged)
      ..dispose();
    super.dispose();
  }

  bool get _hasPendingSelectedShapeEdit {
    final authoring = _authoring;
    final selection = authoring?.state.selection;
    if (authoring == null || selection == null) return false;
    final shape = _findShape(authoring.state.shapes, selection.shapeId);
    return shape != null &&
        (_hasPendingShapeName(shape) || _exactEditController.hasChanges);
  }

  void _handleExactEditChanged() {
    if (mounted) setState(() {});
  }

  void _discardSelectedShapeEdit() {
    final authoring = _authoring;
    final selection = authoring?.state.selection;
    _exactEditController.discard();
    if (selection != null) _shapeNameDrafts.remove(selection.shapeId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final document = _documentOrNull;
    if (document == null) {
      return const Center(
        child: Text('Prefab-v3 current scene is no longer loaded.'),
      );
    }
    _reconcileReloadedOwner(document);
    final authoring = _authoring;
    final prefab = authoring?.prefab;
    final issues = authoring == null
        ? widget.controller.issues
        : _sessionIssues(authoring);
    final prefabWorkspace = _buildPrefabWorkspace(document, prefab, authoring);
    final collisionWorkspace = _buildCollisionWorkspace(
      document,
      prefab,
      authoring,
      issues,
    );

    return EditorWorkspaceCard(
      key: const ValueKey<String>('prefab_polygon_workspace'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PrefabWorkspaceViewSelector(
            selectedView: _workspaceView,
            onSelected: (view) => unawaited(_selectWorkspaceView(view)),
          ),
          const SizedBox(height: EditorUiTokens.sectionGap),
          Expanded(
            child: IndexedStack(
              index: _workspaceView.index,
              children: <Widget>[
                prefabWorkspace,
                collisionWorkspace,
                PrefabV3AtlasCatalogWorkspace(
                  key: _atlasWorkspaceKey,
                  controller: widget.controller,
                  document: document,
                  atlasImageFilePicker: widget.atlasImageFilePicker,
                  onPrefabCreated: _handleAtlasPrefabCreated,
                ),
                PrefabV3ModuleCatalogWorkspace(
                  key: _moduleWorkspaceKey,
                  controller: widget.controller,
                  document: document,
                  onEditCollision: (moduleId) =>
                      unawaited(_editPlatformCollision(moduleId)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectWorkspaceView(PrefabWorkspaceView view) async {
    if (view == _workspaceView) return;
    if (_ownerEditDirty || _ownerCreateDirty) {
      _showWorkspaceSwitchBlocked(
        'Apply or cancel the prefab draft before switching views.',
      );
      return;
    }
    if (_authoring?.hasActiveOperation ?? false) {
      _showWorkspaceSwitchBlocked(
        'Finish or cancel the active polygon operation before switching.',
      );
      return;
    }
    final authoring = _authoring;
    if (authoring != null &&
        (!await _resolvePendingShapeEdit(authoring) || !mounted)) {
      return;
    }
    if (_workspaceView == PrefabWorkspaceView.atlasSlices &&
        (_atlasWorkspaceKey.currentState?.hasLocalDraftChanges ?? false)) {
      _showWorkspaceSwitchBlocked(
        'Apply the slice form or undo its local draft before switching.',
      );
      return;
    }
    if (_workspaceView == PrefabWorkspaceView.platformModules &&
        (_moduleWorkspaceKey.currentState?.hasLocalDraftChanges ?? false)) {
      _showWorkspaceSwitchBlocked(
        'Apply the module form or undo its local draft before switching.',
      );
      return;
    }
    if (view == PrefabWorkspaceView.collision) {
      final document = _documentOrNull;
      if (document != null) {
        final selected = document.data.prefabs
            .where((prefab) => prefab.prefabKey == _selectedPrefabKey)
            .firstOrNull;
        if (selected == null || !canAuthorPrefabCollision(selected)) {
          final collisionPrefab = PrefabCollisionCatalog.fromDocument(document)
              .prefabs
              .firstOrNull;
          if (collisionPrefab != null) {
            _bindOwner(collisionPrefab.prefabKey);
            _resetViewportValues();
          }
        }
      }
    }
    setState(() => _workspaceView = view);
  }

  void _showWorkspaceSwitchBlocked(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Confirms and applies the current source through the shared session.
  Future<void> applyToFiles() async {
    if (!canApplyToFiles) return;
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

  Widget _buildPrefabWorkspace(
    PrefabV3Document document,
    PrefabV3Def? selectedPrefab,
    PrefabPolygonAuthoringController? authoring,
  ) => PrefabEditorThreePanelLayout(
    inspector: _buildPrefabAuthoringPanel(document, authoring),
    scene: PrefabVisualPreviewPanel(
      document: document,
      prefab: selectedPrefab,
      imageCache: _prefabImageCache,
      workspaceRootPath: widget.controller.workspacePath,
    ),
    display: _buildPrefabLibraryPanel(document, selectedPrefab),
  );

  Widget _buildPrefabAuthoringPanel(
    PrefabV3Document document,
    PrefabPolygonAuthoringController? authoring,
  ) => SingleChildScrollView(
    key: const ValueKey<String>('prefab_authoring_sidebar'),
    child: _buildOwnerCreateSection(
      document,
      controlsEnabled: !(authoring?.hasActiveOperation ?? false),
    ),
  );

  Widget _buildPrefabLibraryPanel(
    PrefabV3Document document,
    PrefabV3Def? selectedPrefab,
  ) => PrefabLibraryPanel(
    document: document,
    selectedPrefab: selectedPrefab,
    expandedPrefab: _ownerEditSource,
    workspaceRootPath: widget.controller.workspacePath,
    onSelected: (prefab) => unawaited(_selectOrOpenOwner(prefab)),
    selectedDetailsBuilder: (context, prefab) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: _buildOwnerEditDetails(document, prefab),
    ),
  );

  Widget _buildCollisionWorkspace(
    PrefabV3Document document,
    PrefabV3Def? prefab,
    PrefabPolygonAuthoringController? authoring,
    List<ValidationIssue> issues,
  ) {
    final canAuthor =
        prefab != null && authoring != null && canAuthorPrefabCollision(prefab);
    return PrefabEditorThreePanelLayout(
      inspector: _buildCollisionOwnerPanel(document, prefab),
      scene: canAuthor
          ? _buildScenePanel(document, prefab, authoring)
          : const PrefabCollisionEmptyScene(),
      display: canAuthor
          ? _buildShapePanel(document, authoring, issues)
          : const PrefabCollisionEmptyInspector(),
    );
  }

  Widget _buildCollisionOwnerPanel(
    PrefabV3Document document,
    PrefabV3Def? selectedPrefab,
  ) => PrefabCollisionOwnerPanel(
    document: document,
    selectedPrefab: selectedPrefab,
    catalog: PrefabCollisionCatalog.fromDocument(document),
    imageCache: _prefabImageCache,
    workspaceRootPath: widget.controller.workspacePath,
    onPrefabSelected: (prefab) =>
        unawaited(_selectOwnerFromHeader(prefab.prefabKey)),
    onEditPrefabCollision: (prefabKey) =>
        unawaited(_editPrefabCollision(prefabKey)),
    onEditPlatformCollision: (moduleId) =>
        unawaited(_editPlatformCollision(moduleId)),
  );

  Widget _buildOwnerCreateSection(
    PrefabV3Document document, {
    required bool controlsEnabled,
  }) {
    final canCreate =
        document.data.slices.isNotEmpty ||
        document.tileData.platformModules.isNotEmpty;
    final source = _ownerCreateSource ?? document;
    return PrefabOwnerCreateSection(
      formDocument: source,
      workspaceRootPath: widget.controller.workspacePath,
      formKey: _ownerCreateFormKey,
      canCreate: canCreate,
      isExpanded: _ownerCreateExpanded,
      isDirty: _ownerCreateDirty,
      onExpansionChanged: (expanded) => unawaited(
        _setOwnerCreateExpanded(
          expanded,
          document: document,
          controlsEnabled: controlsEnabled,
          canCreate: canCreate,
        ),
      ),
      onDirtyChanged: _setOwnerCreateDirty,
      onCancel: _closeOwnerCreateSection,
      onSubmit: _createOwner,
    );
  }

  Widget _buildOwnerEditDetails(
    PrefabV3Document document,
    PrefabV3Def currentPrefab,
  ) {
    final source = _ownerEditSource!;
    return PrefabOwnerEditDetails(
      document: document,
      currentPrefab: currentPrefab,
      source: source,
      workspaceRootPath: widget.controller.workspacePath,
      editFormKey: _ownerEditFormKey,
      renameFormKey: _ownerRenameFormKey,
      isDirty: _ownerEditDirty,
      renameActive: _ownerRenameActive,
      renameValidator: (value) => validatePrefabV3OwnerId(
        value,
        document: document,
        exceptPrefabKey: source.prefabKey,
      ),
      onEditCollision: () => unawaited(_editPrefabCollision(source.prefabKey)),
      onBeginRename: _beginOwnerRename,
      onDuplicate: () => _duplicateOwner(document, source),
      onDelete: () => _deleteOwner(document, source),
      onDirtyChanged: _setOwnerEditDirty,
      onCancelRename: _cancelOwnerRename,
      onRename: _renameOwner,
      onCancelEdit: _closeOwnerEditor,
      onApplyEdit: _applyOwnerEdit,
    );
  }

  Widget _buildScenePanel(
    PrefabV3Document document,
    PrefabV3Def prefab,
    PrefabPolygonAuthoringController authoring,
  ) {
    final canEditCollision = prefab.kind != PrefabKind.decoration;
    final hasCommittedCollisionShapes = authoring.state.shapes.isNotEmpty;
    final projection = PrefabPolygonVisualProjection.fromDocument(
      document: document,
      prefab: prefab,
    );
    return EditorPanelCard(
      title: 'Collision scene',
      bodyMode: EditorPanelBodyMode.expanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: EditorUiTokens.controlGap,
            runSpacing: EditorUiTokens.controlGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Chip(
                key: const ValueKey<String>('prefab_scene_owner_context'),
                avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                label: Text('${prefab.id} · ${prefab.kind.jsonValue}'),
              ),
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
            ],
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: EditorUiTokens.controlGap,
              children: <Widget>[
                for (final tool in terrainPolygonSceneToolbarTools)
                  ChoiceChip(
                    key: ValueKey<String>('prefab_polygon_tool_${tool.name}'),
                    label: Text(_toolLabel(tool)),
                    selected: authoring.state.tool == tool,
                    onSelected:
                        (!canEditCollision &&
                                tool != TerrainPolygonTool.select) ||
                            (authoring.state.draft == null &&
                                tool == TerrainPolygonTool.createPolygon) ||
                            (authoring.state.draft == null &&
                                !hasCommittedCollisionShapes &&
                                (tool == TerrainPolygonTool.moveVertex ||
                                    tool == TerrainPolygonTool.translateShape ||
                                    tool == TerrainPolygonTool.insertVertex)) ||
                            (authoring.state.draft != null &&
                                tool != TerrainPolygonTool.createPolygon &&
                                tool != TerrainPolygonTool.moveVertex &&
                                tool != TerrainPolygonTool.insertVertex)
                        ? null
                        : (_) => authoring.setTool(tool),
                  ),
              ],
            ),
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          if (!canEditCollision)
            const Text(
              'Decoration prefabs remain collider-free; their visual source '
              'can be inspected but collision tools are disabled.',
            )
          else
            Text(
              authoring.state.tool == TerrainPolygonTool.createRectangle
                  ? 'Drag across opposite corners to draw a rectangle draft. '
                        'Enter saves it and Escape cancels.'
                  : 'Primary input follows the selected tool. Ctrl+drag pans, '
                        'Ctrl+scroll zooms, Enter saves a draft, and Escape '
                        'cancels.',
            ),
          const SizedBox(height: EditorUiTokens.controlGap),
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
                      imageCache: _prefabImageCache,
                      fitMask: authoring.fitMask,
                      fitMaskOriginPx: authoring.fitMask == null
                          ? null
                          : projection.visualBoundsPx.topLeft,
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
    PrefabV3Document document,
    PrefabPolygonAuthoringController authoring,
    List<ValidationIssue> issues,
  ) {
    final shapes = List<TerrainSourceShapeDef>.of(authoring.state.visibleShapes)
      ..sort((left, right) => left.shapeId.compareTo(right.shapeId));
    final selectedShapeId = authoring.state.selection?.shapeId;
    return SingleChildScrollView(
      key: const ValueKey<String>('prefab_collision_sidebar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildShapeCreationSection(authoring),
          const SizedBox(height: EditorUiTokens.sectionGap),
          EditorSectionCard(
            key: const ValueKey<String>('prefab_polygon_shapes_panel'),
            expansionKey: const ValueKey<String>(
              'prefab_polygon_shapes_panel_toggle',
            ),
            title: 'Existing collision shapes',
            description: shapes.isEmpty
                ? 'Saved collision shapes will appear here.'
                : 'Select a row to edit metadata, geometry, or lifecycle.',
            trailing: Text('${shapes.length} total'),
            collapsible: selectedShapeId == null,
            initiallyExpanded: false,
            expanded: selectedShapeId == null ? null : true,
            child: Column(
              key: const ValueKey<String>('prefab_shape_list'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (shapes.isEmpty)
                  const Text(
                    'No committed collision shapes. Use the creation section '
                    'above to draw the first one.',
                  )
                else
                  for (final shape in shapes)
                    EditorListCard(
                      key: ValueKey<String>(
                        'prefab_polygon_shape_${shape.shapeId}',
                      ),
                      isSelected: selectedShapeId == shape.shapeId,
                      onTap: () =>
                          unawaited(_selectOrCloseShape(authoring, shape)),
                      details: selectedShapeId == shape.shapeId
                          ? Padding(
                              key: ValueKey<String>(
                                'prefab_polygon_selected_shape_editor_'
                                '${shape.shapeId}',
                              ),
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                              child: _buildSelectedShapeEditor(
                                authoring,
                                shape,
                              ),
                            )
                          : null,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        selected: selectedShapeId == shape.shapeId,
                        leading: Icon(
                          shape.collisionMode ==
                                  TerrainSourceCollisionMode.oneWay
                              ? Icons.horizontal_rule
                              : Icons.square_outlined,
                        ),
                        title: Text(shape.shapeId),
                        subtitle: Text(
                          '${_collisionModeLabel(shape.collisionMode)} · '
                          '${shape.vertices.length} vertices · '
                          '${_shapeExtent(shape)}'
                          '${authoring.isFitCandidate(shape.shapeId) ? ' · Fit draft' : ''}',
                        ),
                        trailing: authoring.isFitCandidate(shape.shapeId)
                            ? Checkbox(
                                key: ValueKey<String>(
                                  'prefab_fit_include_${shape.shapeId}',
                                ),
                                value: authoring.isFitCandidateIncluded(
                                  shape.shapeId,
                                ),
                                onChanged: authoring.isFitLoading
                                    ? null
                                    : (included) =>
                                          authoring.setFitCandidateIncluded(
                                            shape.shapeId,
                                            included ?? false,
                                          ),
                              )
                            : null,
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: EditorUiTokens.sectionGap),
          _buildDiagnosticsSection(document, issues),
        ],
      ),
    );
  }

  Widget _buildShapeCreationSection(
    PrefabPolygonAuthoringController authoring,
  ) {
    final draft = authoring.state.draft;
    final gesture = authoring.state.gesture;
    return EditorSectionCard(
      key: const ValueKey<String>('prefab_polygon_creation_panel'),
      expansionKey: const ValueKey<String>(
        'prefab_polygon_creation_panel_toggle',
      ),
      title: 'Create collision shape',
      description: authoring.prefab.kind == PrefabKind.decoration
          ? 'Decoration prefabs remain collider-free.'
          : 'Choose identity and metadata, then draw in the scene.',
      collapsible: !authoring.hasActiveOperation,
      initiallyExpanded: false,
      expanded: authoring.hasActiveOperation ? true : null,
      child: Column(
        key: const ValueKey<String>('prefab_polygon_creation_section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            key: ValueKey<String>(
              'prefab_polygon_creation_name_'
              '${authoring.newShapeNameGeneration}',
            ),
            initialValue: authoring.newShapeNameInput,
            enabled: !authoring.hasActiveOperation,
            decoration: InputDecoration(
              labelText: 'Shape name (optional)',
              hintText: 'Automatic: ${authoring.resolvedNewShapeName}',
              helperText:
                  'Lowercase letters, numbers, and underscores. Blank uses '
                  'the automatic name.',
              errorText: authoring.newShapeNameError,
              border: const OutlineInputBorder(),
            ),
            onChanged: authoring.setNewShapeNameInput,
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          InputDecorator(
            key: const ValueKey<String>(
              'prefab_polygon_creation_mode_selector',
            ),
            decoration: const InputDecoration(labelText: 'Collision'),
            child: Text(
              '${_collisionModeLabel(authoring.newShapeCollisionMode)} '
              '(from ${authoring.prefab.kind.jsonValue})',
            ),
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          Text('Method', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: EditorUiTokens.controlGap),
          if (authoring.prefab.kind == PrefabKind.decoration)
            const Text('Decoration Prefabs do not author collision.')
          else
            Wrap(
              key: const ValueKey<String>('prefab_collision_creation_methods'),
              spacing: EditorUiTokens.controlGap,
              runSpacing: EditorUiTokens.controlGap,
              children: <Widget>[
                FilledButton.tonalIcon(
                  key: const ValueKey<String>('prefab_polygon_new_rectangle'),
                  label: const Text('Rectangle'),
                  icon: const Icon(Icons.crop_square, size: 18),
                  style: _manualMethodStyle(
                    PrefabCollisionCreationMethod.rectangle,
                  ),
                  onPressed: _creationMethodEnabled(authoring)
                      ? () => _selectManualCreationMethod(
                          authoring,
                          PrefabCollisionCreationMethod.rectangle,
                        )
                      : null,
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey<String>('prefab_polygon_new_shape'),
                  label: const Text('Polygon'),
                  icon: const Icon(Icons.polyline, size: 18),
                  style: _manualMethodStyle(
                    PrefabCollisionCreationMethod.polygon,
                  ),
                  onPressed: _creationMethodEnabled(authoring)
                      ? () => _selectManualCreationMethod(
                          authoring,
                          PrefabCollisionCreationMethod.polygon,
                        )
                      : null,
                ),
                _buildFitMethodChip(
                  authoring,
                  PrefabCollisionCreationMethod.fitVisibleBounds,
                ),
                _buildFitMethodChip(
                  authoring,
                  PrefabCollisionCreationMethod.traceVisibleOutline,
                ),
                if (authoring.prefab.kind == PrefabKind.platform)
                  _buildFitMethodChip(
                    authoring,
                    PrefabCollisionCreationMethod.detectPlatformSurface,
                  ),
              ],
            ),
          if (draft != null || gesture != null) ...<Widget>[
            const SizedBox(height: EditorUiTokens.controlGap),
            Text(
              draft == null
                  ? 'Drawing rectangle · release to keep the local preview.'
                  : '${draft.isClosed ? 'Rectangle' : 'Polygon'} draft · '
                        '${draft.vertices.length} vertices · '
                        '${draft.vertices.length < 3 ? 'add at least 3 vertices' : 'ready to save'}',
              key: const ValueKey<String>('prefab_polygon_creation_status'),
            ),
          ],
          if (authoring.hasFitDraft) ...<Widget>[
            const SizedBox(height: EditorUiTokens.controlGap),
            _buildFitDraftEditor(authoring),
          ] else ...<Widget>[
            const SizedBox(height: EditorUiTokens.controlGap),
            Wrap(
              spacing: EditorUiTokens.controlGap,
              runSpacing: EditorUiTokens.controlGap,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('prefab_polygon_save_draft'),
                  onPressed: draft == null || draft.vertices.length < 3
                      ? null
                      : authoring.saveDraft,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save shape'),
                ),
                TextButton(
                  key: const ValueKey<String>('prefab_polygon_cancel_draft'),
                  onPressed:
                      draft != null ||
                          authoring.state.tool ==
                              TerrainPolygonTool.createRectangle
                      ? authoring.cancelActiveOperation
                      : null,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _creationMethodEnabled(PrefabPolygonAuthoringController authoring) =>
      authoring.prefab.kind != PrefabKind.decoration &&
      !authoring.hasActiveOperation &&
      authoring.canBeginNewShape;

  ButtonStyle? _manualMethodStyle(PrefabCollisionCreationMethod method) {
    if (_creationMethod != method) return null;
    return FilledButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
      side: BorderSide(color: Theme.of(context).colorScheme.secondary),
    );
  }

  Widget _buildFitMethodChip(
    PrefabPolygonAuthoringController authoring,
    PrefabCollisionCreationMethod method,
  ) => ChoiceChip(
    key: ValueKey<String>('prefab_fit_method_${method.name}'),
    label: Text(prefabFitMethodLabel(method)),
    avatar: Icon(prefabFitMethodIcon(method), size: 18),
    selected: _creationMethod == method,
    onSelected: _creationMethodEnabled(authoring)
        ? (_) => unawaited(_generateFit(authoring, method: method))
        : null,
  );

  void _selectManualCreationMethod(
    PrefabPolygonAuthoringController authoring,
    PrefabCollisionCreationMethod method,
  ) {
    setState(() => _creationMethod = method);
    if (method == PrefabCollisionCreationMethod.polygon) {
      authoring.setTool(TerrainPolygonTool.createPolygon);
      authoring.beginCreatePolygon();
    } else {
      authoring.setTool(TerrainPolygonTool.createRectangle);
    }
  }

  Widget _buildFitDraftEditor(PrefabPolygonAuthoringController authoring) {
    final candidateIds = authoring.fitCandidateShapeIds;
    final vertexCountsByShapeId = <String, int>{
      for (final id in candidateIds)
        id: _findShape(authoring.state.shapes, id)?.vertices.length ?? 0,
    };
    return PrefabFitDraftEditor(
      method: authoring.fitMethod!,
      refitShapeId: authoring.fitRefitShapeId,
      evidence: authoring.fitEvidence,
      candidateIds: candidateIds,
      vertexCountsByShapeId: vertexCountsByShapeId,
      includedCandidateIds: candidateIds
          .where(authoring.isFitCandidateIncluded)
          .toSet(),
      messages: authoring.fitMessages,
      isLoading: authoring.isFitLoading,
      canSave: authoring.canSaveFitDraft,
      settings: _fitSettings,
      settingsChanged: authoring.fitSettings != _fitSettings,
      advancedExpanded: _fitAdvancedExpanded,
      onCandidateChanged: authoring.setFitCandidateIncluded,
      onSettingsChanged: (settings) => setState(() => _fitSettings = settings),
      onAdvancedExpansionChanged: (expanded) =>
          setState(() => _fitAdvancedExpanded = expanded),
      onRegenerate: () => unawaited(_regenerateFit(authoring)),
      onSave: () => unawaited(_saveFitDraft(authoring)),
      onCancel: _cancelFitDraft,
    );
  }

  Future<void> _generateFit(
    PrefabPolygonAuthoringController authoring, {
    required PrefabCollisionCreationMethod method,
    String? refitShapeId,
  }) async {
    final document = _documentOrNull;
    if (document == null || !identical(authoring, _authoring)) return;
    final token = authoring.startFitGeneration(
      method: method,
      settings: _fitSettings,
      refitShapeId: refitShapeId,
    );
    if (token == 0) return;
    setState(() {
      _creationMethod = method;
      _pendingRefitShapeId = null;
    });
    final projection = PrefabPolygonVisualProjection.fromDocument(
      document: document,
      prefab: authoring.prefab,
    );
    final loaded = await PrefabVisualAlphaMaskLoader.load(
      workspaceRootPath: widget.controller.workspacePath,
      projection: projection,
      imageCache: _prefabImageCache,
      maskCache: _prefabMaskCache,
    );
    if (!mounted || !identical(authoring, _authoring)) return;
    if (!loaded.accepted) {
      authoring.rejectFitGeneration(
        token: token,
        message: loaded.diagnostics.join(' '),
      );
      return;
    }
    final result = PrefabCollisionFitter.generate(
      mask: loaded.mask!,
      method: method,
      settings: _fitSettings,
    );
    authoring.completeFitGeneration(
      token: token,
      sourceMask: loaded.mask!,
      sourceIdentity: loaded.sourceIdentity!,
      result: result,
      visualOriginXPx: projection.visualBoundsPx.left.toInt(),
      visualOriginYPx: projection.visualBoundsPx.top.toInt(),
    );
  }

  Future<void> _regenerateFit(
    PrefabPolygonAuthoringController authoring,
  ) async {
    if (authoring.fitHasLocalEdits) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace fit adjustments?'),
          content: const Text(
            'Regenerating replaces candidate edits and component choices with '
            'a fresh result from the current settings.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Regenerate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final method = authoring.fitMethod;
    if (method == null) return;
    await _generateFit(
      authoring,
      method: method,
      refitShapeId: authoring.fitRefitShapeId,
    );
  }

  Future<void> _saveFitDraft(PrefabPolygonAuthoringController authoring) async {
    final document = _documentOrNull;
    if (document == null || !identical(authoring, _authoring)) return;
    final projection = PrefabPolygonVisualProjection.fromDocument(
      document: document,
      prefab: authoring.prefab,
    );
    final current = await PrefabVisualAlphaMaskLoader.load(
      workspaceRootPath: widget.controller.workspacePath,
      projection: projection,
      imageCache: _prefabImageCache,
      maskCache: _prefabMaskCache,
    );
    if (!mounted || !identical(authoring, _authoring)) return;
    if (!current.accepted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(current.diagnostics.join(' '))));
      return;
    }
    final saved = authoring.saveFitDraft(
      currentSourceIdentity: current.sourceIdentity!,
    );
    if (saved) {
      setState(() {
        _pendingRefitShapeId = null;
        _fitSettings = const PrefabCollisionFitSettings();
        _fitAdvancedExpanded = false;
      });
    }
  }

  void _cancelFitDraft() {
    final authoring = _authoring;
    if (authoring == null || !authoring.cancelFitDraft()) return;
    setState(() {
      _pendingRefitShapeId = null;
      _fitSettings = const PrefabCollisionFitSettings();
      _fitAdvancedExpanded = false;
      _creationMethod = _defaultCreationMethod(authoring.prefab.kind);
    });
  }

  Widget _buildSelectedShapeEditor(
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    final hasPendingExactEdit =
        _hasPendingShapeName(shape) || _exactEditController.hasChanges;
    final canEditShape = authoring.canEditShape(shape.shapeId);
    final isFitCandidate = authoring.isFitCandidate(shape.shapeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Edit ${shape.shapeId}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Wrap(
          spacing: EditorUiTokens.controlGap,
          runSpacing: EditorUiTokens.controlGap,
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('prefab_polygon_duplicate_shape'),
              onPressed: !canEditShape || isFitCandidate || hasPendingExactEdit
                  ? null
                  : () => _duplicateSelectedShape(authoring, shape),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('prefab_polygon_normalize_shape'),
              onPressed: !canEditShape || hasPendingExactEdit
                  ? null
                  : authoring.normalizeSelectedShape,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Normalize'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('prefab_polygon_delete_shape'),
              onPressed: !canEditShape || isFitCandidate || hasPendingExactEdit
                  ? null
                  : authoring.deleteSelection,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
            if (!isFitCandidate &&
                authoring.prefab.kind != PrefabKind.decoration)
              OutlinedButton.icon(
                key: const ValueKey<String>('prefab_polygon_refit_shape'),
                onPressed: authoring.hasActiveOperation || hasPendingExactEdit
                    ? null
                    : () => setState(() {
                        _pendingRefitShapeId =
                            _pendingRefitShapeId == shape.shapeId
                            ? null
                            : shape.shapeId;
                      }),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Refit from pixels'),
              ),
          ],
        ),
        if (_pendingRefitShapeId == shape.shapeId) ...<Widget>[
          const SizedBox(height: EditorUiTokens.controlGap),
          Text(
            'Choose how visible pixels should replace this shape:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          Wrap(
            key: const ValueKey<String>('prefab_refit_methods'),
            spacing: EditorUiTokens.controlGap,
            runSpacing: EditorUiTokens.controlGap,
            children: <Widget>[
              for (final method in <PrefabCollisionCreationMethod>[
                PrefabCollisionCreationMethod.fitVisibleBounds,
                PrefabCollisionCreationMethod.traceVisibleOutline,
                if (authoring.prefab.kind == PrefabKind.platform)
                  PrefabCollisionCreationMethod.detectPlatformSurface,
              ])
                ActionChip(
                  key: ValueKey<String>('prefab_refit_method_${method.name}'),
                  avatar: Icon(prefabFitMethodIcon(method), size: 18),
                  label: Text(prefabFitMethodLabel(method)),
                  onPressed: () => unawaited(
                    _generateFit(
                      authoring,
                      method: method,
                      refitShapeId: shape.shapeId,
                    ),
                  ),
                ),
              ActionChip(
                label: const Text('Cancel'),
                onPressed: () => setState(() => _pendingRefitShapeId = null),
              ),
            ],
          ),
        ],
        const SizedBox(height: EditorUiTokens.controlGap),
        _buildShapeMetadataInspector(authoring, shape),
        const SizedBox(height: EditorUiTokens.controlGap),
        _buildVertexInspector(authoring, shape),
      ],
    );
  }

  Widget _buildShapeMetadataInspector(
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    final shapeNameInput = _shapeNameDrafts[shape.shapeId] ?? shape.shapeId;
    final shapeNameError = authoring.validateShapeName(
      shapeNameInput,
      excludingShapeId: shape.shapeId,
    );
    return Column(
      key: const ValueKey<String>('prefab_polygon_metadata_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: ValueKey<String>('prefab_polygon_shape_name_${shape.shapeId}'),
          initialValue: shapeNameInput,
          enabled:
              authoring.canEditShape(shape.shapeId) &&
              !authoring.isFitCandidate(shape.shapeId),
          decoration: InputDecoration(
            labelText: 'Shape name',
            helperText:
                'Lowercase letters, numbers, and underscores; unique in '
                'this prefab.',
            errorText: shapeNameError,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() => _shapeNameDrafts[shape.shapeId] = value);
          },
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        InputDecorator(
          key: const ValueKey<String>('prefab_polygon_metadata_mode'),
          decoration: const InputDecoration(labelText: 'Collision mode'),
          child: Text(
            '${_collisionModeLabel(shape.collisionMode)} '
            '(from ${authoring.prefab.kind.jsonValue})',
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsSection(
    PrefabV3Document document,
    List<ValidationIssue> issues,
  ) {
    final errors = issues
        .where((issue) => issue.severity == ValidationSeverity.error)
        .length;
    final warnings = issues
        .where((issue) => issue.severity == ValidationSeverity.warning)
        .length;
    final infos = issues.length - errors - warnings;
    return EditorSectionCard(
      key: const ValueKey<String>('prefab_polygon_diagnostics_panel'),
      expansionKey: const ValueKey<String>(
        'prefab_polygon_diagnostics_panel_toggle',
      ),
      title: 'Diagnostics',
      description: issues.isEmpty
          ? 'No issues in the current Prefab session.'
          : '$errors error(s) · $warnings warning(s) · $infos info',
      trailing: Text('${issues.length} total'),
      collapsible: true,
      initiallyExpanded: false,
      child: issues.isEmpty
          ? const Text('No issues in the current Prefab session.')
          : Column(
              children: <Widget>[
                for (final entry in issues.indexed)
                  ListTile(
                    key: ValueKey<String>(
                      'prefab_polygon_issue_${entry.$2.code}_'
                      '${entry.$2.ownerKey}_${entry.$2.shapeId}_'
                      '${entry.$2.elementIndex}_${entry.$1}',
                    ),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      switch (entry.$2.severity) {
                        ValidationSeverity.error => Icons.error_outline,
                        ValidationSeverity.warning =>
                          Icons.warning_amber_outlined,
                        ValidationSeverity.info => Icons.info_outline,
                      },
                      color: switch (entry.$2.severity) {
                        ValidationSeverity.error => const Color(0xFFFF7F7F),
                        ValidationSeverity.warning => const Color(0xFFFFD166),
                        ValidationSeverity.info => null,
                      },
                    ),
                    title: Text(entry.$2.code),
                    subtitle: Text(_diagnosticSubtitle(document, entry.$2)),
                    onTap: _diagnosticOwnerKey(document, entry.$2) == null
                        ? null
                        : () => unawaited(_focusIssue(document, entry.$2)),
                  ),
              ],
            ),
    );
  }

  Widget _buildVertexInspector(
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    final rectangle = TerrainAxisAlignedRectangle.tryFromShape(shape);
    final selection = authoring.state.selection;
    final selectedVertexIndex =
        selection?.shapeId == shape.shapeId &&
            selection?.kind == TerrainPolygonSelectionKind.vertex
        ? selection?.elementIndex
        : null;
    final shapeNameError = authoring.validateShapeName(
      _pendingShapeName(shape),
      excludingShapeId: shape.shapeId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Vertices', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: EditorUiTokens.controlGap),
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
          const SizedBox(height: EditorUiTokens.controlGap),
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
            applyButtonKey: const ValueKey<String>('prefab_polygon_save_edit'),
            applyLabel: 'Save edit',
            applyEnabled: shapeNameError == null,
            coordinateStepHalfPixels: authoring.coordinateStepHalfPixels,
            editController: _exactEditController,
            onBeforeApply: () => _pendingShapeNameIsValid(authoring, shape),
            onApply: (xHalfPixels, yHalfPixels) {
              final saved = authoring.editSelectedVertex(
                TerrainSourceVertexDef(
                  xHalfPixels: xHalfPixels,
                  yHalfPixels: yHalfPixels,
                ),
                shapeId: _pendingShapeName(shape),
              );
              if (saved) {
                _shapeNameDrafts.remove(shape.shapeId);
                _scheduleShapeEditorRefresh();
              }
              return saved;
            },
            controlGap: EditorUiTokens.controlGap,
          ),
        ] else if (rectangle != null) ...<Widget>[
          const SizedBox(height: EditorUiTokens.controlGap),
          TerrainPolygonRectangleEditor(
            key: ValueKey<String>(
              'prefab_polygon_rectangle_editor_${shape.shapeId}_'
              '${rectangle.xHalfPixels}_${rectangle.yHalfPixels}_'
              '${rectangle.widthHalfPixels}_${rectangle.heightHalfPixels}',
            ),
            keyPrefix: 'prefab_polygon',
            rectangle: rectangle,
            applyButtonKey: const ValueKey<String>('prefab_polygon_save_edit'),
            applyLabel: 'Save edit',
            applyEnabled: shapeNameError == null,
            coordinateStepHalfPixels: authoring.coordinateStepHalfPixels,
            editController: _exactEditController,
            onBeforeApply: () => _pendingShapeNameIsValid(authoring, shape),
            onApply:
                ({
                  required xHalfPixels,
                  required bottomYHalfPixels,
                  required widthHalfPixels,
                  required heightHalfPixels,
                }) {
                  final saved = authoring.editSelectedAxisAlignedRectangle(
                    xHalfPixels: xHalfPixels,
                    yHalfPixels: bottomYHalfPixels - heightHalfPixels,
                    widthHalfPixels: widthHalfPixels,
                    heightHalfPixels: heightHalfPixels,
                    shapeId: _pendingShapeName(shape),
                  );
                  if (saved) {
                    _shapeNameDrafts.remove(shape.shapeId);
                    _scheduleShapeEditorRefresh();
                  }
                  return saved;
                },
            controlGap: EditorUiTokens.controlGap,
          ),
        ] else ...<Widget>[
          const SizedBox(height: EditorUiTokens.controlGap),
          FilledButton.icon(
            key: const ValueKey<String>('prefab_polygon_save_edit'),
            onPressed: shapeNameError == null && _hasPendingShapeName(shape)
                ? () => _saveShapeName(authoring, shape)
                : null,
            icon: const Icon(Icons.check),
            label: const Text('Save edit'),
          ),
        ],
      ],
    );
  }

  String _pendingShapeName(TerrainSourceShapeDef shape) =>
      (_shapeNameDrafts[shape.shapeId] ?? shape.shapeId).trim();

  bool _hasPendingShapeName(TerrainSourceShapeDef shape) =>
      _pendingShapeName(shape) != shape.shapeId;

  bool _pendingShapeNameIsValid(
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) =>
      authoring.validateShapeName(
        _pendingShapeName(shape),
        excludingShapeId: shape.shapeId,
      ) ==
      null;

  bool _saveShapeName(
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    if (!_pendingShapeNameIsValid(authoring, shape)) {
      setState(() {});
      return false;
    }
    if (!_hasPendingShapeName(shape)) return true;
    final saved = authoring.renameSelectedShape(_pendingShapeName(shape));
    if (saved) _shapeNameDrafts.remove(shape.shapeId);
    return saved;
  }

  void _scheduleShapeEditorRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _selectOrCloseShape(
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef target,
  ) async {
    if (authoring.hasActiveOperation &&
        !(authoring.hasFitDraft && authoring.isFitCandidate(target.shapeId))) {
      return;
    }
    final currentSelection = authoring.state.selection;
    final closingCurrent = currentSelection?.shapeId == target.shapeId;
    if (currentSelection != null) {
      final canLeave = await _resolvePendingShapeEdit(authoring);
      if (!canLeave || !mounted || !identical(authoring, _authoring)) return;
    }
    authoring.select(
      closingCurrent ? null : TerrainPolygonSelection.shape(target.shapeId),
    );
  }

  Future<bool> _resolvePendingShapeEdit(
    PrefabPolygonAuthoringController authoring,
  ) async {
    final selection = authoring.state.selection;
    if (selection == null) return true;
    final shape = _findShape(authoring.state.shapes, selection.shapeId);
    if (shape == null) return true;
    if (!_hasPendingShapeName(shape) && !_exactEditController.hasChanges) {
      _shapeNameDrafts.remove(shape.shapeId);
      return true;
    }
    final action = await showEditorPendingChangesDialog(
      context: context,
      dialogKey: const ValueKey<String>('prefab_polygon_unsaved_edit_dialog'),
      title: 'Save collision shape changes?',
      content: Text(
        'Save the pending changes to ${shape.shapeId} before closing its '
        'editor?',
      ),
      cancelKey: const ValueKey<String>('prefab_polygon_unsaved_edit_cancel'),
      discardKey: const ValueKey<String>('prefab_polygon_unsaved_edit_discard'),
      saveKey: const ValueKey<String>('prefab_polygon_unsaved_edit_save'),
    );
    if (!mounted || !identical(authoring, _authoring)) return false;
    return switch (action) {
      EditorPendingChangesAction.save =>
        _exactEditController.hasEditor
            ? _exactEditController.save()
            : _saveShapeName(authoring, shape),
      EditorPendingChangesAction.discard => () {
        _exactEditController.discard();
        setState(() => _shapeNameDrafts.remove(shape.shapeId));
        return true;
      }(),
      EditorPendingChangesAction.cancel || null => false,
    };
  }

  void _duplicateSelectedShape(
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    final offset = findTerrainPolygonDuplicateOffset(
      selectedShape: shape,
      ownerShapes: authoring.state.shapes,
      snapStepHalfPixels: authoring.coordinateStepHalfPixels,
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

  Future<void> _focusIssue(
    PrefabV3Document document,
    ValidationIssue issue,
  ) async {
    final ownerKey = _diagnosticOwnerKey(document, issue);
    if (ownerKey == null) return;
    if (ownerKey != _selectedPrefabKey) {
      await _selectOwnerFromHeader(ownerKey);
      if (!mounted || _selectedPrefabKey != ownerKey) return;
    }

    final shapeId = issue.shapeId;
    if (shapeId == null) {
      if (_ownerEditSource?.prefabKey == ownerKey) return;
      final owner = _documentOrNull?.data.prefabs
          .where((prefab) => prefab.prefabKey == ownerKey)
          .firstOrNull;
      if (owner != null) await _selectOrOpenOwner(owner);
      return;
    }

    final currentAuthoring = _authoring;
    if (currentAuthoring == null || currentAuthoring.prefabKey != ownerKey) {
      return;
    }
    final shape = _findShape(currentAuthoring.state.visibleShapes, shapeId);
    if (shape == null) return;
    final index = issue.elementIndex ?? 0;
    if (issue.code.contains('vertex') && index < shape.vertices.length) {
      currentAuthoring.select(
        TerrainPolygonSelection.vertex(shape.shapeId, index),
      );
    } else if (issue.code.contains('edge') && index < shape.vertices.length) {
      currentAuthoring.select(
        TerrainPolygonSelection.edge(shape.shapeId, index),
      );
    } else {
      currentAuthoring.select(TerrainPolygonSelection.shape(shape.shapeId));
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

  List<ValidationIssue> _sessionIssues(
    PrefabPolygonAuthoringController authoring,
  ) {
    final combined = <ValidationIssue>[
      ...widget.controller.issues,
      for (final issue in authoring.issues)
        ValidationIssue(
          severity: switch (issue.severity) {
            PrefabValidationSeverity.warning => ValidationSeverity.warning,
            PrefabValidationSeverity.error => ValidationSeverity.error,
          },
          code: issue.code,
          message: issue.message,
          sourcePath: issue.sourcePath,
          ownerKey: issue.ownerKey ?? authoring.prefabKey,
          shapeId: issue.shapeId.isEmpty ? null : issue.shapeId,
          elementIndex: issue.shapeId.isEmpty ? null : issue.elementIndex,
        ),
    ];
    final seen = <String>{};
    return List<ValidationIssue>.unmodifiable(
      combined.where(
        (issue) => seen.add(
          '${issue.severity}|${issue.code}|${issue.sourcePath}|'
          '${issue.ownerKey}|${issue.shapeId}|${issue.elementIndex}|'
          '${issue.message}',
        ),
      ),
    );
  }

  String _diagnosticSubtitle(PrefabV3Document document, ValidationIssue issue) {
    final ownerKey = _diagnosticOwnerKey(document, issue);
    if (ownerKey == null) return issue.message;
    final owner = document.data.prefabs
        .where((prefab) => prefab.prefabKey == ownerKey)
        .firstOrNull;
    final ownerLabel = owner?.id ?? ownerKey;
    return '$ownerLabel · ${issue.message}';
  }

  String? _diagnosticOwnerKey(
    PrefabV3Document document,
    ValidationIssue issue,
  ) {
    final direct = issue.ownerKey;
    if (direct != null &&
        document.data.prefabs.any((prefab) => prefab.prefabKey == direct)) {
      return direct;
    }
    final sourcePath = issue.sourcePath;
    if (sourcePath == null) return null;
    return document.data.prefabs
        .where((prefab) => sourcePath.endsWith(':${prefab.prefabKey}'))
        .firstOrNull
        ?.prefabKey;
  }

  bool _createOwner(PrefabV3OwnerFormValue edit) {
    final document = _ownerCreateSource;
    if (document == null || edit.id == null) return false;
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
    if (next == null) return false;
    final createdKeys = next.data.prefabs
        .map((prefab) => prefab.prefabKey)
        .where((key) => !beforeKeys.contains(key))
        .toList(growable: false);
    _clearOwnerCreateState();
    _syncOwnerAfterSessionMutation(preferredPrefabKey: createdKeys.firstOrNull);
    return true;
  }

  bool _applyOwnerEdit(PrefabV3OwnerFormValue edit) {
    final prefab = _ownerEditSource;
    if (prefab == null) return false;
    final before = PrefabV3MetadataSnapshot.fromPrefab(prefab);
    final after = PrefabV3MetadataSnapshot(
      status: edit.status,
      kind: edit.kind,
      visualSource: edit.visualSource,
      anchorXPx: edit.anchorXPx,
      anchorYPx: edit.anchorYPx,
      tags: edit.tags,
    );
    if (before == after) {
      _closeOwnerEditor();
      return true;
    }
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
      return false;
    }
    _clearOwnerEditorState();
    _syncOwnerAfterSessionMutation(preferredPrefabKey: prefab.prefabKey);
    return true;
  }

  void _duplicateOwner(PrefabV3Document document, PrefabV3Def prefab) {
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
    _clearOwnerEditorState();
    _syncOwnerAfterSessionMutation(
      preferredPrefabKey: duplicateKeys.firstOrNull,
    );
  }

  bool _renameOwner(String nextId) {
    final document = _documentOrNull;
    final prefab = _ownerEditSource;
    if (document == null || prefab == null) return false;
    if (nextId == prefab.id) {
      _closeOwnerEditor();
      return true;
    }
    final next = _dispatchLifecycle(
      document,
      PrefabV3RenameOperation(prefabKey: prefab.prefabKey, nextId: nextId),
    );
    if (next == null) return false;
    _clearOwnerEditorState();
    _syncOwnerAfterSessionMutation(preferredPrefabKey: prefab.prefabKey);
    return true;
  }

  Future<void> _deleteOwner(
    PrefabV3Document document,
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
          'This removes the prefab and its collision shapes. '
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
            child: const Text('Delete prefab'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final next = _dispatchLifecycle(
      document,
      PrefabV3DeleteOperation(prefabKey: prefab.prefabKey),
    );
    if (next != null) {
      _clearOwnerEditorState();
      _syncOwnerAfterSessionMutation();
    }
  }

  Future<void> _editPlatformCollision(String moduleId) async {
    if (_workspaceView != PrefabWorkspaceView.collision) {
      await _selectWorkspaceView(PrefabWorkspaceView.collision);
      if (!mounted || _workspaceView != PrefabWorkspaceView.collision) {
        return;
      }
    }
    if (_authoring?.hasActiveOperation ?? false) {
      _showWorkspaceSwitchBlocked(
        'Finish or cancel the active polygon operation before switching '
        'platforms.',
      );
      return;
    }
    final authoring = _authoring;
    if (authoring != null &&
        (!await _resolvePendingShapeEdit(authoring) || !mounted)) {
      return;
    }
    if (!await _resolveOwnerCreateDraft() || !mounted) return;
    if (!await _resolveOwnerEditor() || !mounted) return;

    var document = _documentOrNull;
    if (document == null ||
        !document.tileData.platformModules.any(
          (module) => module.id == moduleId,
        )) {
      return;
    }
    var owners = PrefabPlatformPairing.ownersForModule(document.data, moduleId);
    if (owners.isEmpty) {
      final next = _dispatchCatalog(
        document,
        PrefabV3EnsurePlatformPrefabOperation(moduleId: moduleId),
      );
      if (next == null) return;
      document = next;
      owners = PrefabPlatformPairing.ownersForModule(document.data, moduleId);
    }
    final target =
        PrefabPlatformPairing.pairedOwner(document.data, moduleId) ??
        owners.firstOrNull;
    if (target == null) {
      _showWorkspaceSwitchBlocked(
        'Add at least one visual tile before setting up collision.',
      );
      return;
    }
    setState(() {
      if (_selectedPrefabKey != target.prefabKey) {
        _bindOwner(target.prefabKey);
        _resetViewportValues();
      }
    });
    if (owners.length > 1 &&
        PrefabPlatformPairing.pairedOwner(document.data, moduleId) == null) {
      _showWorkspaceSwitchBlocked(
        'This platform has multiple custom prefab variants; opened '
        '${target.id}.',
      );
    }
  }

  Future<void> _editPrefabCollision(String prefabKey) async {
    if (_workspaceView != PrefabWorkspaceView.collision) {
      await _selectWorkspaceView(PrefabWorkspaceView.collision);
      if (!mounted || _workspaceView != PrefabWorkspaceView.collision) {
        return;
      }
    }
    if (_selectedPrefabKey == prefabKey) return;
    await _selectOwnerFromHeader(prefabKey);
  }

  void _handleAtlasPrefabCreated(PrefabV3Def prefab) {
    if (!mounted || prefab.kind != PrefabKind.obstacle) return;
    final document = _documentOrNull;
    if (document == null ||
        !document.data.prefabs.any(
          (candidate) => candidate.prefabKey == prefab.prefabKey,
        )) {
      return;
    }
    setState(() {
      _bindOwner(prefab.prefabKey);
      _resetViewportValues();
      _workspaceView = PrefabWorkspaceView.collision;
    });
  }

  PrefabV3Document? _dispatchCatalog(
    PrefabV3Document document,
    PrefabV3CatalogOperation operation,
  ) {
    final beforeDocument = widget.controller.document;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
        payload: <String, Object?>{
          'commit': PrefabV3CatalogCommit(
            before: PrefabV3CatalogSnapshot.fromDocument(document),
            operation: operation,
          ),
        },
      ),
    );
    final next = widget.controller.document;
    if (identical(next, beforeDocument) || next is! PrefabV3Document) {
      _showWorkspaceSwitchBlocked(
        'Platform collision setup was rejected. Review validation '
        'diagnostics and retry.',
      );
      return null;
    }
    return next;
  }

  PrefabV3Document? _dispatchLifecycle(
    PrefabV3Document document,
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
    if (identical(next, beforeDocument) || next is! PrefabV3Document) {
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
          'retry from the current prefab state.',
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

  void _reconcileReloadedOwner(PrefabV3Document document) {
    final selectedKey = _selectedPrefabKey;
    if (selectedKey != null &&
        document.data.prefabs.any(
          (prefab) => prefab.prefabKey == selectedKey,
        )) {
      return;
    }
    _disposeAuthoring();
    _clearOwnerEditorState();
    _selectedPrefabKey = null;
    final nextKey = _preferredOwnerKey(document);
    if (nextKey != null) {
      _bindOwner(nextKey);
      _resetViewportValues();
    }
  }

  String? _preferredOwnerKey(PrefabV3Document document) {
    final requestedKey = _requestedOwnerKey(document);
    if (requestedKey != null) return requestedKey;
    if (document.data.prefabs.isEmpty) return null;
    final prefabs = List<PrefabV3Def>.of(document.data.prefabs)
      ..sort(comparePrefabOwners);
    return prefabs
            .where((prefab) => prefab.kind != PrefabKind.decoration)
            .firstOrNull
            ?.prefabKey ??
        prefabs.first.prefabKey;
  }

  String? _requestedOwnerKey(PrefabV3Document? document) {
    if (document == null) return null;
    final requestedKey = widget.initialPrefabKey?.trim();
    if (requestedKey == null || requestedKey.isEmpty) return null;
    return document.data.prefabs.any(
          (prefab) => prefab.prefabKey == requestedKey,
        )
        ? requestedKey
        : null;
  }

  Future<void> _selectOrOpenOwner(PrefabV3Def target) async {
    if (_authoring?.hasActiveOperation ?? false) {
      _showWorkspaceSwitchBlocked(
        'Finish or cancel the active polygon operation before switching '
        'prefabs.',
      );
      return;
    }
    final authoring = _authoring;
    if (authoring != null &&
        (!await _resolvePendingShapeEdit(authoring) || !mounted)) {
      return;
    }
    if (!await _resolveOwnerCreateDraft() || !mounted) return;
    if (_ownerEditSource?.prefabKey == target.prefabKey) {
      await _resolveOwnerEditor();
      return;
    }
    if (!await _resolveOwnerEditor() || !mounted) return;
    final document = _documentOrNull;
    final current = document?.data.prefabs
        .where((prefab) => prefab.prefabKey == target.prefabKey)
        .firstOrNull;
    if (current == null) return;
    setState(() {
      if (current.prefabKey != _selectedPrefabKey) {
        _bindOwner(current.prefabKey);
        _resetViewportValues();
      }
      _beginOwnerEditor(current);
    });
  }

  Future<void> _selectOwnerFromHeader(String prefabKey) async {
    if (prefabKey == _selectedPrefabKey) return;
    if (_authoring?.hasActiveOperation ?? false) {
      _showWorkspaceSwitchBlocked(
        'Finish or cancel the active polygon operation before switching '
        'prefabs.',
      );
      return;
    }
    final authoring = _authoring;
    if (authoring != null &&
        (!await _resolvePendingShapeEdit(authoring) || !mounted)) {
      return;
    }
    if (!await _resolveOwnerCreateDraft() || !mounted) return;
    if (!await _resolveOwnerEditor() || !mounted) return;
    final document = _documentOrNull;
    final target = document?.data.prefabs
        .where((prefab) => prefab.prefabKey == prefabKey)
        .firstOrNull;
    if (target == null) return;
    setState(() {
      _bindOwner(target.prefabKey);
      _resetViewportValues();
    });
  }

  void _beginOwnerEditor(PrefabV3Def prefab) {
    _ownerDraft.beginEdit(prefab);
  }

  void _beginOwnerRename() {
    if (!_ownerDraft.beginRename()) return;
    setState(() {});
  }

  void _cancelOwnerRename() {
    if (!_ownerDraft.cancelRename()) return;
    setState(() {});
  }

  void _setOwnerEditDirty(bool dirty) {
    if (!mounted || !_ownerDraft.setEditDirty(dirty)) return;
    setState(() {});
  }

  void _closeOwnerEditor() {
    if (_ownerEditSource == null) return;
    setState(_clearOwnerEditorState);
  }

  void _clearOwnerEditorState() {
    _ownerDraft.clearEdit();
  }

  Future<bool> _resolveOwnerEditor() async {
    if (_ownerEditSource == null) return true;
    if (!_ownerEditDirty) {
      _closeOwnerEditor();
      return true;
    }
    final action = await showEditorPendingChangesDialog(
      context: context,
      dialogKey: const ValueKey<String>('prefab_v3_owner_unsaved_edit_dialog'),
      title: 'Save prefab metadata changes?',
      content: Text(
        'Save the pending changes to ${_ownerEditSource!.id} before closing '
        'its editor?',
      ),
      cancelKey: const ValueKey<String>('prefab_v3_owner_unsaved_edit_cancel'),
      discardKey: const ValueKey<String>(
        'prefab_v3_owner_unsaved_edit_discard',
      ),
      saveKey: const ValueKey<String>('prefab_v3_owner_unsaved_edit_save'),
    );
    if (!mounted) return false;
    return switch (action) {
      EditorPendingChangesAction.save =>
        await ((_ownerRenameActive
                ? _ownerRenameFormKey.currentState?.submit()
                : _ownerEditFormKey.currentState?.submit()) ??
            Future<bool>.value(false)),
      EditorPendingChangesAction.discard => () {
        _closeOwnerEditor();
        return true;
      }(),
      EditorPendingChangesAction.cancel || null => false,
    };
  }

  Future<void> _setOwnerCreateExpanded(
    bool expanded, {
    required PrefabV3Document document,
    required bool controlsEnabled,
    required bool canCreate,
  }) async {
    if (!expanded) {
      if (_ownerCreateDirty) return;
      _closeOwnerCreateSection();
      return;
    }
    if (!canCreate) {
      setState(_ownerDraft.expandCreate);
      return;
    }
    if (!controlsEnabled) {
      _showWorkspaceSwitchBlocked(
        'Finish the active prefab edit or polygon operation before creating a '
        'prefab.',
      );
      return;
    }
    final authoring = _authoring;
    if (authoring != null &&
        (!await _resolvePendingShapeEdit(authoring) || !mounted)) {
      return;
    }
    if (!await _resolveOwnerEditor() || !mounted) return;
    setState(() {
      _ownerDraft.expandCreate(document);
    });
  }

  void _setOwnerCreateDirty(bool dirty) {
    if (!mounted || !_ownerDraft.setCreateDirty(dirty)) return;
    setState(() {});
  }

  void _closeOwnerCreateSection() {
    if (!_ownerCreateExpanded && _ownerCreateSource == null) return;
    setState(_clearOwnerCreateState);
  }

  void _clearOwnerCreateState() {
    _ownerDraft.clearCreate();
  }

  Future<bool> _resolveOwnerCreateDraft() async {
    if (!_ownerCreateExpanded) return true;
    if (!_ownerCreateDirty) {
      _closeOwnerCreateSection();
      return true;
    }
    final action = await showEditorPendingChangesDialog(
      context: context,
      dialogKey: const ValueKey<String>(
        'prefab_v3_owner_unsaved_create_dialog',
      ),
      title: 'Create this prefab?',
      content: const Text(
        'Save the pending prefab before leaving the creation form?',
      ),
      cancelKey: const ValueKey<String>(
        'prefab_v3_owner_unsaved_create_cancel',
      ),
      discardKey: const ValueKey<String>(
        'prefab_v3_owner_unsaved_create_discard',
      ),
      saveKey: const ValueKey<String>('prefab_v3_owner_unsaved_create_save'),
    );
    if (!mounted) return false;
    return switch (action) {
      EditorPendingChangesAction.save =>
        await (_ownerCreateFormKey.currentState?.submit() ??
            Future<bool>.value(false)),
      EditorPendingChangesAction.discard => () {
        _closeOwnerCreateSection();
        return true;
      }(),
      EditorPendingChangesAction.cancel || null => false,
    };
  }

  void _bindOwner(String prefabKey) {
    _disposeAuthoring();
    _exactEditController.discard();
    _shapeNameDrafts.clear();
    _pendingRefitShapeId = null;
    _fitSettings = const PrefabCollisionFitSettings();
    _fitAdvancedExpanded = false;
    _observedFitDraft = false;
    _selectedPrefabKey = prefabKey;
    _authoring = PrefabPolygonAuthoringController(
      session: widget.controller,
      prefabKey: prefabKey,
    )..addListener(_handleAuthoringChanged);
    _creationMethod = _defaultCreationMethod(_authoring!.prefab.kind);
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
    final authoring = _authoring;
    final hasFitDraft = authoring?.hasFitDraft ?? false;
    setState(() {
      if (_observedFitDraft && !hasFitDraft && authoring != null) {
        _pendingRefitShapeId = null;
        _fitSettings = const PrefabCollisionFitSettings();
        _fitAdvancedExpanded = false;
        _creationMethod = _defaultCreationMethod(authoring.prefab.kind);
      }
      _observedFitDraft = hasFitDraft;
    });
  }

  PrefabV3Document? get _documentOrNull {
    final document = widget.controller.document;
    return document is PrefabV3Document ? document : null;
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

String _toolLabel(TerrainPolygonTool tool) => switch (tool) {
  TerrainPolygonTool.select => 'Select shape',
  TerrainPolygonTool.createPolygon => 'Place vertex',
  TerrainPolygonTool.createRectangle => 'Rectangle',
  TerrainPolygonTool.moveVertex => 'Move vertex',
  TerrainPolygonTool.translateShape => 'Move shape',
  TerrainPolygonTool.insertVertex => 'Insert vertex',
};

String _collisionModeLabel(TerrainSourceCollisionMode mode) => switch (mode) {
  TerrainSourceCollisionMode.solid => 'Solid',
  TerrainSourceCollisionMode.oneWay => 'One-way',
  TerrainSourceCollisionMode.none => 'No collision (visual only)',
};

PrefabCollisionCreationMethod _defaultCreationMethod(PrefabKind kind) =>
    switch (kind) {
      PrefabKind.platform =>
        PrefabCollisionCreationMethod.detectPlatformSurface,
      PrefabKind.obstacle ||
      PrefabKind.unknown => PrefabCollisionCreationMethod.traceVisibleOutline,
      PrefabKind.decoration => PrefabCollisionCreationMethod.rectangle,
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
