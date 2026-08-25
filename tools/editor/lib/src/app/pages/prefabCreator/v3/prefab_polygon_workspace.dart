import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:terrain_materials/terrain_materials.dart';

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
import '../../../../terrain_authoring/terrain_axis_aligned_rectangle.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_inline_id_form.dart';
import '../../shared/editor_panel_card.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_ui_tokens.dart';
import '../../shared/editor_workspace_card.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/terrain_material_preview_catalog.dart';
import '../../shared/terrain_polygon_exact_edit_controller.dart';
import '../../shared/terrain_polygon_rectangle_editor.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import '../../shared/terrain_polygon_vertex_editor.dart';
import '../shared/prefab_polygon_authoring_controller.dart';
import '../shared/prefab_polygon_scene_surface.dart';
import '../shared/prefab_polygon_visual_source.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';
import 'prefab_v3_atlas_catalog_workspace.dart';
import 'prefab_v3_module_catalog_workspace.dart';
import 'prefab_v3_owner_form.dart';
import 'prefab_owner_catalog_browser.dart';

/// Normal prefab-v3 polygon authoring workspace.
///
/// Current v3 source and explicit owner navigation select this page through
/// [PrefabV3Scene]. Legacy or missing source opens the fail-closed migration
/// workspace; source apply cannot perform migration.
class PrefabPolygonWorkspace extends StatefulWidget {
  const PrefabPolygonWorkspace({
    super.key,
    required this.controller,
    this.initialPrefabKey,
  });

  final EditorSessionController controller;

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
  String? _selectedPrefabKey;
  PrefabV3Def? _ownerEditSource;
  bool _ownerEditDirty = false;
  bool _ownerRenameActive = false;
  bool _ownerCreateExpanded = false;
  bool _ownerCreateDirty = false;
  PrefabV3Document? _ownerCreateSource;
  _PrefabV3WorkspaceView _workspaceView = _PrefabV3WorkspaceView.owners;
  double _zoom = _initialZoom;
  Offset _pan = Offset.zero;
  TerrainMaterialCatalog? _materialCatalog;

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
    if (_workspaceView == _PrefabV3WorkspaceView.atlasSlices &&
        (_atlasWorkspaceKey.currentState?.cancelLocalDraft() ?? false)) {
      return true;
    }
    if (_workspaceView == _PrefabV3WorkspaceView.platformModules &&
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
    _exactEditController.addListener(_handleExactEditChanged);
    _reloadMaterialCatalog();
    _selectInitialOwner();
  }

  @override
  void didUpdateWidget(covariant PrefabPolygonWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _disposeAuthoring();
      _clearOwnerEditorState();
      _clearOwnerCreateState();
      _selectedPrefabKey = null;
      _reloadMaterialCatalog();
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

  void _reloadMaterialCatalog() {
    _materialCatalog = loadTerrainMaterialPreviewCatalog(
      widget.controller.workspacePath,
    ).catalog;
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
    final ownerWorkspace = prefab == null || authoring == null
        ? _buildEmptyOwnerState(document)
        : PrefabEditorThreePanelLayout(
            inspector: _buildOwnerPanel(document, prefab, authoring),
            scene: _buildScenePanel(document, prefab, authoring),
            display: _buildShapePanel(document, authoring, issues),
          );

    return EditorWorkspaceCard(
      key: const ValueKey<String>('prefab_polygon_workspace'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(document),
          const SizedBox(height: EditorUiTokens.sectionGap),
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
    );
  }

  Widget _buildHeader(PrefabV3Document document) {
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
    final prefabs = List<PrefabV3Def>.of(document.data.prefabs)
      ..sort(_comparePrefabs);
    final selectedPrefab = prefabs
        .where((prefab) => prefab.prefabKey == _selectedPrefabKey)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: EditorUiTokens.controlGap,
          runSpacing: EditorUiTokens.controlGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const Chip(
              avatar: Icon(Icons.science_outlined, size: 18),
              label: Text('Prefab v3 polygon authoring'),
            ),
            Text(
              changedCount == 0
                  ? 'No pending prefab changes'
                  : '$changedCount pending prefab change(s)',
            ),
            if (changedCount > 0)
              Text(
                key: const ValueKey<String>('prefab_polygon_downstream_impact'),
                '$affectedPlacementCount placement(s) in '
                '$affectedChunkCount chunk(s) affected; chunk revisions stay '
                'unchanged.',
              ),
            if (selectedPrefab != null)
              DropdownButton<String>(
                key: const ValueKey<String>('prefab_v3_owner_selector'),
                value: selectedPrefab.prefabKey,
                hint: const Text('Select prefab owner'),
                onChanged: (prefabKey) {
                  if (prefabKey != null) {
                    unawaited(_selectOwnerFromHeader(prefabKey));
                  }
                },
                items: <DropdownMenuItem<String>>[
                  for (final prefab in prefabs)
                    DropdownMenuItem<String>(
                      value: prefab.prefabKey,
                      child: Text(prefab.id),
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        const Text(
          'Current-schema workspace: apply rechecks both source baselines and '
          'commits the prefab/tile pair atomically. Legacy migration stays '
          'read-only; runtime terrain updates after generated outputs refresh.',
          style: TextStyle(color: Color(0xFFFFD166)),
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        Wrap(
          spacing: EditorUiTokens.controlGap,
          runSpacing: EditorUiTokens.controlGap,
          children: <Widget>[
            ChoiceChip(
              key: const ValueKey<String>('prefab_v3_view_owners'),
              label: const Text('Prefab owners & collision'),
              selected: _workspaceView == _PrefabV3WorkspaceView.owners,
              onSelected: (_) => unawaited(
                _selectWorkspaceView(_PrefabV3WorkspaceView.owners),
              ),
            ),
            ChoiceChip(
              key: const ValueKey<String>('prefab_v3_view_atlas_slices'),
              label: const Text('Atlas & tile slices'),
              selected: _workspaceView == _PrefabV3WorkspaceView.atlasSlices,
              onSelected: (_) => unawaited(
                _selectWorkspaceView(_PrefabV3WorkspaceView.atlasSlices),
              ),
            ),
            ChoiceChip(
              key: const ValueKey<String>('prefab_v3_view_platform_modules'),
              label: const Text('Platform modules'),
              selected:
                  _workspaceView == _PrefabV3WorkspaceView.platformModules,
              onSelected: (_) => unawaited(
                _selectWorkspaceView(_PrefabV3WorkspaceView.platformModules),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectWorkspaceView(_PrefabV3WorkspaceView view) async {
    if (view == _workspaceView) return;
    if (_ownerEditDirty || _ownerCreateDirty) {
      _showWorkspaceSwitchBlocked(
        'Apply or cancel the prefab owner draft before switching views.',
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

  Widget _buildOwnerPanel(
    PrefabV3Document document,
    PrefabV3Def selectedPrefab,
    PrefabPolygonAuthoringController authoring,
  ) {
    final ownerEditorOpen = _ownerEditSource != null;
    return SingleChildScrollView(
      key: const ValueKey<String>('prefab_owner_sidebar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildOwnerCreateSection(
            document,
            controlsEnabled: !authoring.hasActiveOperation,
          ),
          const SizedBox(height: EditorUiTokens.sectionGap),
          EditorSectionCard(
            key: const ValueKey<String>('prefab_owner_library_section'),
            expansionKey: const ValueKey<String>(
              'prefab_owner_library_section_toggle',
            ),
            title: 'Prefab owner library',
            description: 'Search, filter, select, and edit prefab owners.',
            trailing: Text('${document.data.prefabs.length} total'),
            collapsible: !ownerEditorOpen,
            initiallyExpanded: false,
            expanded: ownerEditorOpen ? true : null,
            child: PrefabOwnerCatalogBrowser(
              prefabs: document.data.prefabs,
              prefabData: document.data,
              tileData: document.tileData,
              visualBoundsByPrefabKey: document.visualBoundsByPrefabKey,
              workspaceRootPath: widget.controller.workspacePath,
              selectedPrefabKey: selectedPrefab.prefabKey,
              expandedPrefabKey: _ownerEditSource?.prefabKey,
              changedPrefabKeys: document.changedPrefabKeys,
              downstreamImpacts: document.downstreamImpacts,
              enabled: true,
              onSelected: (prefab) => unawaited(_selectOrOpenOwner(prefab)),
              selectedDetailsBuilder: (context, prefab) => Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: _buildOwnerEditDetails(document, prefab),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOwnerState(PrefabV3Document document) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildOwnerCreateSection(document, controlsEnabled: true),
          const SizedBox(height: EditorUiTokens.sectionGap),
          const EditorSectionCard(
            title: 'Prefab owner library',
            description: '0 total',
            collapsible: true,
            initiallyExpanded: false,
            child: Text(
              'No prefab owners remain. Create one from a retained atlas '
              'slice or platform module.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCreateSection(
    PrefabV3Document document, {
    required bool controlsEnabled,
  }) {
    final canCreate =
        document.data.slices.isNotEmpty ||
        document.tileData.platformModules.isNotEmpty;
    final source = _ownerCreateSource ?? document;
    return EditorSectionCard(
      key: const ValueKey<String>('prefab_v3_owner_create_section'),
      title: 'Create prefab owner',
      description: canCreate
          ? 'Create from an authored atlas slice or platform module.'
          : 'Create an atlas slice or platform module first.',
      collapsible: !_ownerCreateDirty,
      initiallyExpanded: false,
      expanded: _ownerCreateExpanded || _ownerCreateDirty,
      expansionKey: const ValueKey<String>(
        'prefab_v3_owner_create_section_toggle',
      ),
      onExpansionChanged: (expanded) => unawaited(
        _setOwnerCreateExpanded(
          expanded,
          document: document,
          controlsEnabled: controlsEnabled && canCreate,
        ),
      ),
      child: canCreate
          ? PrefabV3OwnerForm(
              key: _ownerCreateFormKey,
              document: source,
              autofocusId: true,
              submitLabel: 'Create owner',
              submitKey: const ValueKey<String>(
                'prefab_v3_owner_inline_create_apply',
              ),
              cancelKey: const ValueKey<String>(
                'prefab_v3_owner_inline_create_cancel',
              ),
              onDirtyChanged: _setOwnerCreateDirty,
              onCancel: _closeOwnerCreateSection,
              onSubmit: _createOwner,
            )
          : const Text(
              'No visual source is currently available for a prefab owner.',
            ),
    );
  }

  Widget _buildOwnerEditDetails(
    PrefabV3Document document,
    PrefabV3Def currentPrefab,
  ) {
    final source = _ownerEditSource!;
    final impact = document.downstreamImpacts
        .where((entry) => entry.prefabKey == source.prefabKey)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Edit ${currentPrefab.id}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        Text(
          'prefabKey: ${source.prefabKey} · revision ${source.revision}\n'
          '${source.visualSource.type.jsonValue}:${source.sourceRefId} · '
          '${source.collisionShapes.length} collision shape(s) · '
          '${impact?.placementCount ?? 0} downstream placement(s)',
        ),
        const SizedBox(height: EditorUiTokens.sectionGap),
        Wrap(
          spacing: EditorUiTokens.controlGap,
          runSpacing: EditorUiTokens.controlGap,
          children: <Widget>[
            Tooltip(
              message: 'Rename ${source.id} while preserving its prefab key.',
              child: OutlinedButton.icon(
                key: const ValueKey<String>('prefab_v3_owner_rename'),
                onPressed: !_ownerEditDirty && !_ownerRenameActive
                    ? _beginOwnerRename
                    : null,
                icon: const Icon(Icons.drive_file_rename_outline),
                label: const Text('Rename'),
              ),
            ),
            Tooltip(
              message: 'Duplicate ${source.id} with a new stable prefab key.',
              child: OutlinedButton.icon(
                key: const ValueKey<String>('prefab_v3_owner_duplicate'),
                onPressed: !_ownerEditDirty && !_ownerRenameActive
                    ? () => _duplicateOwner(document, source)
                    : null,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Duplicate'),
              ),
            ),
            Tooltip(
              message: 'Delete ${source.id} after reviewing its references.',
              child: OutlinedButton.icon(
                key: const ValueKey<String>('prefab_v3_owner_delete'),
                onPressed: !_ownerEditDirty && !_ownerRenameActive
                    ? () => _deleteOwner(document, source)
                    : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ),
          ],
        ),
        const SizedBox(height: EditorUiTokens.sectionGap),
        if (_ownerRenameActive)
          EditorInlineIdForm(
            key: _ownerRenameFormKey,
            initialValue: source.id,
            fieldKey: const ValueKey<String>('prefab_v3_inline_rename_id'),
            submitKey: const ValueKey<String>('prefab_v3_inline_rename_apply'),
            cancelKey: const ValueKey<String>('prefab_v3_inline_rename_cancel'),
            submitLabel: 'Rename owner',
            helperText: 'The stable prefab key is preserved.',
            validator: (value) => validatePrefabV3OwnerId(
              value,
              document: document,
              exceptPrefabKey: source.prefabKey,
            ),
            onDirtyChanged: _setOwnerEditDirty,
            onCancel: _cancelOwnerRename,
            onSubmit: _renameOwner,
          )
        else
          PrefabV3OwnerForm(
            key: _ownerEditFormKey,
            document: document,
            prefab: source,
            submitLabel: 'Apply changes',
            submitKey: ValueKey<String>(
              'prefab_v3_owner_inline_apply_${source.prefabKey}',
            ),
            cancelKey: ValueKey<String>(
              'prefab_v3_owner_inline_cancel_${source.prefabKey}',
            ),
            onDirtyChanged: _setOwnerEditDirty,
            onCancel: _closeOwnerEditor,
            onSubmit: _applyOwnerEdit,
          ),
      ],
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
                          '${_shapeExtent(shape)}',
                        ),
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
    final materialValue = authoring.newShapeMaterialKey?.trim() ?? '';
    final surfaceValue = authoring.newShapeSurfaceKind?.trim() ?? '';
    final materialOptions = terrainMetadataSelectorOptions(
      current: materialValue,
      known:
          _materialCatalog?.materials.map((material) => material.key) ??
          const <String>[],
    );
    final surfaceOptions = terrainMetadataSelectorOptions(
      current: surfaceValue,
      known: terrainSurfaceKindOptions,
    );
    return EditorSectionCard(
      key: const ValueKey<String>('prefab_polygon_creation_panel'),
      expansionKey: const ValueKey<String>(
        'prefab_polygon_creation_panel_toggle',
      ),
      title: 'Create collision shape',
      description: authoring.prefab.kind == PrefabKind.decoration
          ? 'Decoration owners remain collider-free.'
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
          _buildMetadataDropdown<TerrainSourceCollisionMode>(
            keyName: 'prefab_polygon_creation_mode_selector',
            label: 'Collision',
            value: authoring.newShapeCollisionMode,
            items:
                const <TerrainSourceCollisionMode>[
                      TerrainSourceCollisionMode.solid,
                      TerrainSourceCollisionMode.oneWay,
                    ]
                    .map(
                      (mode) => DropdownMenuItem<TerrainSourceCollisionMode>(
                        value: mode,
                        child: Text(_collisionModeLabel(mode)),
                      ),
                    )
                    .toList(growable: false),
            onChanged: authoring.hasActiveOperation
                ? null
                : (mode) {
                    if (mode != null) authoring.setNewShapeCollisionMode(mode);
                  },
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          _buildMetadataDropdown<String>(
            keyName: 'prefab_polygon_creation_surface_selector',
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
            onChanged: authoring.hasActiveOperation
                ? null
                : (value) {
                    if (value != null) {
                      authoring.setNewShapeSurfaceKind(
                        nullableTerrainMetadataSelection(value),
                      );
                    }
                  },
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          _buildMetadataDropdown<String>(
            keyName: 'prefab_polygon_creation_material_selector',
            label: 'Material key',
            value: materialValue,
            items: materialOptions
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      terrainMaterialSelectorLabel(_materialCatalog, value),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: authoring.hasActiveOperation
                ? null
                : (value) {
                    if (value != null) {
                      authoring.setNewShapeMaterialKey(
                        nullableTerrainMetadataSelection(value),
                      );
                    }
                  },
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          _buildPrefabSnapSelector(
            authoring,
            keyName: 'prefab_polygon_creation_snap_selector',
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
          const SizedBox(height: EditorUiTokens.controlGap),
          Wrap(
            spacing: EditorUiTokens.controlGap,
            runSpacing: EditorUiTokens.controlGap,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('prefab_polygon_new_shape'),
                onPressed:
                    authoring.prefab.kind == PrefabKind.decoration ||
                        authoring.hasActiveOperation ||
                        !authoring.canBeginNewShape
                    ? null
                    : () {
                        authoring.setTool(TerrainPolygonTool.createPolygon);
                        authoring.beginCreatePolygon();
                      },
                icon: const Icon(Icons.polyline),
                label: const Text('Draw polygon'),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey<String>('prefab_polygon_new_rectangle'),
                onPressed:
                    authoring.prefab.kind == PrefabKind.decoration ||
                        authoring.hasActiveOperation ||
                        !authoring.canBeginNewShape
                    ? null
                    : () =>
                          authoring.setTool(TerrainPolygonTool.createRectangle),
                icon: const Icon(Icons.crop_square),
                label: const Text('Draw rectangle'),
              ),
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
                    authoring.hasActiveOperation ||
                        authoring.state.tool ==
                            TerrainPolygonTool.createRectangle
                    ? authoring.cancelActiveOperation
                    : null,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedShapeEditor(
    PrefabPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) {
    final hasPendingExactEdit =
        _hasPendingShapeName(shape) || _exactEditController.hasChanges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Edit ${shape.shapeId}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        _buildPrefabSnapSelector(
          authoring,
          keyName: 'prefab_polygon_edit_snap_selector',
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        Wrap(
          spacing: EditorUiTokens.controlGap,
          runSpacing: EditorUiTokens.controlGap,
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('prefab_polygon_duplicate_shape'),
              onPressed: authoring.hasActiveOperation || hasPendingExactEdit
                  ? null
                  : () => _duplicateSelectedShape(authoring, shape),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('prefab_polygon_normalize_shape'),
              onPressed: authoring.hasActiveOperation || hasPendingExactEdit
                  ? null
                  : authoring.normalizeSelectedShape,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Normalize'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('prefab_polygon_delete_shape'),
              onPressed: authoring.hasActiveOperation || hasPendingExactEdit
                  ? null
                  : authoring.deleteSelection,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
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
    final controlsEnabled =
        !authoring.hasActiveOperation &&
        !_hasPendingShapeName(shape) &&
        !_exactEditController.hasChanges;
    return Column(
      key: const ValueKey<String>('prefab_polygon_metadata_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: ValueKey<String>('prefab_polygon_shape_name_${shape.shapeId}'),
          initialValue: shapeNameInput,
          enabled: !authoring.hasActiveOperation,
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
        _buildMetadataDropdown<TerrainSourceCollisionMode>(
          keyName: 'prefab_polygon_metadata_mode',
          label: 'Collision mode',
          value: shape.collisionMode,
          items: TerrainSourceCollisionMode.values
              .where(
                (mode) =>
                    mode != TerrainSourceCollisionMode.none ||
                    mode == shape.collisionMode,
              )
              .map(
                (mode) => DropdownMenuItem<TerrainSourceCollisionMode>(
                  value: mode,
                  child: Text(_collisionModeLabel(mode)),
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
        const SizedBox(height: EditorUiTokens.controlGap),
        _buildMetadataDropdown<String>(
          keyName: 'prefab_polygon_metadata_surface_selector',
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
        const SizedBox(height: EditorUiTokens.controlGap),
        _buildMetadataDropdown<String>(
          keyName: 'prefab_polygon_metadata_material_selector',
          label: 'Material key',
          value: materialValue,
          items: materialOptions
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    terrainMaterialSelectorLabel(_materialCatalog, value),
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

  Widget _buildPrefabSnapSelector(
    PrefabPolygonAuthoringController authoring, {
    required String keyName,
  }) => SegmentedButton<int>(
    key: ValueKey<String>(keyName),
    segments: const <ButtonSegment<int>>[
      ButtonSegment<int>(value: 2, label: Text('1 px grid')),
      ButtonSegment<int>(value: 1, label: Text('0.5 px')),
    ],
    selected: <int>{authoring.snapPolicy.stepHalfPixels},
    onSelectionChanged: authoring.hasActiveOperation
        ? null
        : (selection) {
            final step = selection.single;
            authoring.setSnapPolicy(
              step == 1
                  ? const TerrainPolygonSnapPolicy.halfPixel()
                  : TerrainPolygonSnapPolicy.ownerGridPixels(1),
            );
          },
  );

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
            coordinateStepHalfPixels: authoring.snapPolicy.stepHalfPixels,
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
            coordinateStepHalfPixels: authoring.snapPolicy.stepHalfPixels,
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
    if (authoring.hasActiveOperation) return;
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
    final action = await showDialog<_PendingShapeEditAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        key: const ValueKey<String>('prefab_polygon_unsaved_edit_dialog'),
        title: const Text('Save collision shape changes?'),
        content: Text(
          'Save the pending changes to ${shape.shapeId} before closing its '
          'editor?',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('prefab_polygon_unsaved_edit_cancel'),
            onPressed: () =>
                Navigator.of(context).pop(_PendingShapeEditAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey<String>('prefab_polygon_unsaved_edit_discard'),
            onPressed: () =>
                Navigator.of(context).pop(_PendingShapeEditAction.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            key: const ValueKey<String>('prefab_polygon_unsaved_edit_save'),
            onPressed: () =>
                Navigator.of(context).pop(_PendingShapeEditAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || !identical(authoring, _authoring)) return false;
    return switch (action) {
      _PendingShapeEditAction.save =>
        _exactEditController.hasEditor
            ? _exactEditController.save()
            : _saveShapeName(authoring, shape),
      _PendingShapeEditAction.discard => () {
        _exactEditController.discard();
        setState(() => _shapeNameDrafts.remove(shape.shapeId));
        return true;
      }(),
      _PendingShapeEditAction.cancel || null => false,
    };
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
    if (next != null) {
      _clearOwnerEditorState();
      _syncOwnerAfterSessionMutation();
    }
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
      ..sort(_comparePrefabs);
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
        'prefab owners.',
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
        'prefab owners.',
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
    _ownerEditSource = prefab;
    _ownerEditDirty = false;
    _ownerRenameActive = false;
  }

  void _beginOwnerRename() {
    if (_ownerEditSource == null || _ownerEditDirty) return;
    setState(() => _ownerRenameActive = true);
  }

  void _cancelOwnerRename() {
    if (!_ownerRenameActive) return;
    setState(() {
      _ownerRenameActive = false;
      _ownerEditDirty = false;
    });
  }

  void _setOwnerEditDirty(bool dirty) {
    if (!mounted || dirty == _ownerEditDirty) return;
    setState(() => _ownerEditDirty = dirty);
  }

  void _closeOwnerEditor() {
    if (_ownerEditSource == null) return;
    setState(_clearOwnerEditorState);
  }

  void _clearOwnerEditorState() {
    _ownerEditSource = null;
    _ownerEditDirty = false;
    _ownerRenameActive = false;
  }

  Future<bool> _resolveOwnerEditor() async {
    if (_ownerEditSource == null) return true;
    if (!_ownerEditDirty) {
      _closeOwnerEditor();
      return true;
    }
    final action = await showDialog<_PendingOwnerEditAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        key: const ValueKey<String>('prefab_v3_owner_unsaved_edit_dialog'),
        title: const Text('Save prefab metadata changes?'),
        content: Text(
          'Save the pending changes to ${_ownerEditSource!.id} before closing '
          'its editor?',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('prefab_v3_owner_unsaved_edit_cancel'),
            onPressed: () =>
                Navigator.of(context).pop(_PendingOwnerEditAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey<String>('prefab_v3_owner_unsaved_edit_discard'),
            onPressed: () =>
                Navigator.of(context).pop(_PendingOwnerEditAction.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            key: const ValueKey<String>('prefab_v3_owner_unsaved_edit_save'),
            onPressed: () =>
                Navigator.of(context).pop(_PendingOwnerEditAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    return switch (action) {
      _PendingOwnerEditAction.save =>
        await ((_ownerRenameActive
                ? _ownerRenameFormKey.currentState?.submit()
                : _ownerEditFormKey.currentState?.submit()) ??
            Future<bool>.value(false)),
      _PendingOwnerEditAction.discard => () {
        _closeOwnerEditor();
        return true;
      }(),
      _PendingOwnerEditAction.cancel || null => false,
    };
  }

  Future<void> _setOwnerCreateExpanded(
    bool expanded, {
    required PrefabV3Document document,
    required bool controlsEnabled,
  }) async {
    if (!expanded) {
      if (_ownerCreateDirty) return;
      _closeOwnerCreateSection();
      return;
    }
    if (!controlsEnabled) {
      _showWorkspaceSwitchBlocked(
        'Finish the active owner or polygon operation before creating a prefab.',
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
      _ownerCreateExpanded = true;
      _ownerCreateSource = document;
    });
  }

  void _setOwnerCreateDirty(bool dirty) {
    if (!mounted || dirty == _ownerCreateDirty) return;
    setState(() => _ownerCreateDirty = dirty);
  }

  void _closeOwnerCreateSection() {
    if (!_ownerCreateExpanded && _ownerCreateSource == null) return;
    setState(_clearOwnerCreateState);
  }

  void _clearOwnerCreateState() {
    _ownerCreateExpanded = false;
    _ownerCreateDirty = false;
    _ownerCreateSource = null;
  }

  Future<bool> _resolveOwnerCreateDraft() async {
    if (!_ownerCreateExpanded) return true;
    if (!_ownerCreateDirty) {
      _closeOwnerCreateSection();
      return true;
    }
    final action = await showDialog<_PendingOwnerEditAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        key: const ValueKey<String>('prefab_v3_owner_unsaved_create_dialog'),
        title: const Text('Create this prefab owner?'),
        content: const Text(
          'Save the pending prefab owner before leaving the creation form?',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>(
              'prefab_v3_owner_unsaved_create_cancel',
            ),
            onPressed: () =>
                Navigator.of(context).pop(_PendingOwnerEditAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey<String>(
              'prefab_v3_owner_unsaved_create_discard',
            ),
            onPressed: () =>
                Navigator.of(context).pop(_PendingOwnerEditAction.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            key: const ValueKey<String>('prefab_v3_owner_unsaved_create_save'),
            onPressed: () =>
                Navigator.of(context).pop(_PendingOwnerEditAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    return switch (action) {
      _PendingOwnerEditAction.save =>
        await (_ownerCreateFormKey.currentState?.submit() ??
            Future<bool>.value(false)),
      _PendingOwnerEditAction.discard => () {
        _closeOwnerCreateSection();
        return true;
      }(),
      _PendingOwnerEditAction.cancel || null => false,
    };
  }

  void _bindOwner(String prefabKey) {
    _disposeAuthoring();
    _exactEditController.discard();
    _shapeNameDrafts.clear();
    _selectedPrefabKey = prefabKey;
    _authoring = PrefabPolygonAuthoringController(
      session: widget.controller,
      prefabKey: prefabKey,
      newShapeSurfaceKind: terrainSurfaceKindOptions.first,
      newShapeMaterialKey: _materialCatalog?.materials.firstOrNull?.key,
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

enum _PrefabV3WorkspaceView { owners, atlasSlices, platformModules }

enum _PendingOwnerEditAction { save, discard, cancel }

enum _PendingShapeEditAction { save, discard, cancel }

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
