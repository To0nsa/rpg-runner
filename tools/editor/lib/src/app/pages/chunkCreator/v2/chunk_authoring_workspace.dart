import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../../../../chunks/chunk_v2_actor_terrain_projection.dart';
import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_composition_operation.dart';
import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../../../chunks/chunk_domain_plugin.dart';
import '../../../../chunks/chunk_prefab_surface_snap.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_lifecycle_commit.dart';
import '../../../../chunks/chunk_v2_marker_placement_projection.dart';
import '../../../../chunks/chunk_v2_metadata_commit.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_determinism.dart';
import '../../../../session/editor_session_controller.dart';
import '../../../../terrain_authoring/terrain_axis_aligned_rectangle.dart';
import '../../../../terrain_authoring/terrain_half_pixel_text.dart';
import '../../../../terrain_authoring/terrain_polygon_duplicate_offset.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_panel_card.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_workspace_card.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_viewport_grid_painter.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/terrain_material_preview.dart';
import '../../shared/terrain_polygon_rectangle_editor.dart';
import '../../shared/terrain_polygon_exact_edit_controller.dart';
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

enum _PendingShapeEditAction { save, discard, cancel }

/// Snapshot readiness exposed to the Chunk Creator Play/Edit orchestrator.
///
/// Accepted session changes are intentionally absent from the blockers. Only
/// state that is not yet represented by the immutable plugin document, or a
/// blocking document/session condition, prevents scenario capture.
@immutable
final class ChunkPlaytestWorkspaceReadiness {
  const ChunkPlaytestWorkspaceReadiness({
    required this.code,
    required this.message,
    required this.selectedChunkKey,
  });

  /// Stable readiness code used by tests and editor presentation.
  final String code;

  /// Concise author-facing explanation or ready-state description.
  final String message;

  /// Selected accepted owner, absent when owner/level context is incomplete.
  final String? selectedChunkKey;

  bool get isReady => code == 'ready';
}

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
    this.onPlayRequested,
    this.playtestPlatformSupported = false,
  });

  final EditorSessionController controller;

  /// Opens a read-only expanded shape's stable owner outside this workspace.
  final ValueChanged<String>? onOpenOwningPrefab;

  /// Requests a snapshot playtest after [ChunkPlaytestWorkspaceReadiness]
  /// reports ready; lifecycle ownership remains with the route page.
  final VoidCallback? onPlayRequested;

  /// Whether this host supports the Windows-only Phase 5 Play surface.
  final bool playtestPlatformSupported;

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
  bool _showGrid = false;
  bool _showShapeEdges = false;
  bool _visualPreview = false;
  bool _showActorTerrain = false;
  ChunkV2TerrainActor _selectedTerrainActor = ChunkV2TerrainActor.eloise;
  bool _showMarkerPlacements = false;
  bool _terrainCreationSnapToGrid = false;
  bool _terrainEditSnapToGrid = false;
  bool _prefabSurfaceSnapEnabled = true;
  ChunkV2CollisionExpansion? _actorTerrainExpansion;
  ChunkV2ActorTerrainProjection? _actorTerrainProjection;
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
  final Map<String, String> _shapeNameDrafts = <String, String>{};
  final TerrainPolygonExactEditController _exactEditController =
      TerrainPolygonExactEditController();

  bool get _hasActiveOperation =>
      (_authoring?.hasActiveOperation ?? false) ||
      _compositionOperationActive ||
      _prefabGesture.hasActiveOperation ||
      _markerGesture.hasActiveOperation;

  bool get hasActiveOperation => _hasActiveOperation;

  /// Stable selected owner used when the route captures a playtest snapshot.
  String? get selectedChunkKey => _selectedChunkKey;

  /// Current fail-closed readiness for Play button and F5 entry.
  ChunkPlaytestWorkspaceReadiness get playtestReadiness {
    if (!widget.playtestPlatformSupported) {
      return const ChunkPlaytestWorkspaceReadiness(
        code: 'unsupportedPlatformOrSourceGeneration',
        message: 'Play mode is available only in the Windows Chunk-v2 editor.',
        selectedChunkKey: null,
      );
    }
    if (widget.controller.isLoading || widget.controller.isExporting) {
      return ChunkPlaytestWorkspaceReadiness(
        code: 'activeLocalOperationOrDraft',
        message: widget.controller.isLoading
            ? 'Wait for the workspace to finish loading.'
            : 'Wait for Apply To Files to finish.',
        selectedChunkKey: _selectedChunkKey,
      );
    }
    final selectedChunkKey = _selectedChunkKey;
    final scene = _sceneOrNull;
    if (selectedChunkKey == null ||
        scene == null ||
        scene.activeLevelId == null ||
        !scene.chunks.any((chunk) => chunk.chunkKey == selectedChunkKey)) {
      return const ChunkPlaytestWorkspaceReadiness(
        code: 'missingOwnerOrLevelContext',
        message: 'Select a current chunk owner and level before Play.',
        selectedChunkKey: null,
      );
    }
    if (_hasActiveOperation || _hasPendingSelectedShapeEdit) {
      return ChunkPlaytestWorkspaceReadiness(
        code: 'activeLocalOperationOrDraft',
        message:
            'Finish, save, or cancel the active gesture or inspector draft '
            'before Play.',
        selectedChunkKey: selectedChunkKey,
      );
    }
    if (widget.controller.issues.any(
      (issue) => issue.severity == ValidationSeverity.error,
    )) {
      return ChunkPlaytestWorkspaceReadiness(
        code: 'blockingValidationIssue',
        message: 'Resolve the blocking Chunk diagnostics before Play.',
        selectedChunkKey: selectedChunkKey,
      );
    }
    return ChunkPlaytestWorkspaceReadiness(
      code: 'ready',
      message: 'Play the accepted in-memory chunk snapshot.',
      selectedChunkKey: selectedChunkKey,
    );
  }

  bool get hasLocalDraftChanges =>
      _hasActiveOperation ||
      _hasPendingSelectedShapeEdit ||
      widget.controller.pendingChanges.hasChanges;

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
      !_hasPendingSelectedShapeEdit &&
      !widget.controller.isLoading &&
      !widget.controller.isExporting;

  bool get _hasPendingSelectedShapeEdit {
    final authoring = _authoring;
    final selection = authoring?.state.selection;
    if (authoring == null || selection == null) return false;
    final shape = _findShape(authoring.state.shapes, selection.shapeId);
    return shape != null &&
        (_hasPendingShapeName(shape) || _exactEditController.hasChanges);
  }

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
    _exactEditController.addListener(_handleExactEditChanged);
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
    _exactEditController
      ..removeListener(_handleExactEditChanged)
      ..dispose();
    super.dispose();
  }

  void _handleExactEditChanged() {
    if (mounted) setState(() {});
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
              sidebar: _buildChunkSidebar(document, authoring),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ChunkV2Document document, ChunkV2Scene scene) {
    final readiness = playtestReadiness;
    return Column(
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
                  scene.chunks.any(
                    (chunk) => chunk.chunkKey == _selectedChunkKey,
                  )
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
            Tooltip(
              message: readiness.message,
              child: FilledButton.icon(
                key: const ValueKey<String>('chunk_playtest_button'),
                onPressed: readiness.isReady ? widget.onPlayRequested : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play (F5)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          readiness.isReady
              ? 'Play ready: ${readiness.message}'
              : 'Play unavailable: ${readiness.message}',
          key: const ValueKey<String>('chunk_playtest_readiness'),
          style: TextStyle(
            color: readiness.isReady
                ? const Color(0xFF7DD3FC)
                : const Color(0xFFFFD166),
          ),
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
  }

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
                  preview: _ChunkOwnerPreview(
                    key: ValueKey<String>(
                      'chunk_owner_preview_${chunk.chunkKey}',
                    ),
                    workspaceRootPath: widget.controller.workspacePath,
                    chunk: chunk,
                    scene: scene,
                  ),
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
    ChunkPolygonAuthoringController? authoring,
  ) {
    final controlsEnabled = !_hasActiveOperation && !_visualPreview;
    final activePanel = switch (_sceneCoordinator.sourceDomain) {
      ChunkSceneDomain.terrain ||
      ChunkSceneDomain.compiledEdgeInspection => EditorPanelCard(
        key: const ValueKey<String>('chunk_terrain_card'),
        title: 'Terrain',
        description: _visualPreview
            ? 'Exit Visual preview to edit direct terrain shapes.'
            : controlsEnabled
            ? 'Create and edit direct terrain shapes.'
            : 'Finish or cancel the active terrain edit before changing tabs.',
        collapsible: true,
        expansionKey: const ValueKey<String>('chunk_terrain_card_toggle'),
        child: authoring == null
            ? _buildEmptySidebarPanel(
                key: const ValueKey<String>('chunk_polygon_shapes_panel'),
                expansionKey: const ValueKey<String>(
                  'chunk_polygon_shapes_panel_toggle',
                ),
                title: 'Terrain shapes',
                message: 'Select or create a chunk owner first.',
              )
            : _buildShapePanel(authoring),
      ),
      ChunkSceneDomain.prefabs => _buildCompositionSidebarCard(
        document,
        authoring,
        section: ChunkCompositionSection.prefabs,
      ),
      ChunkSceneDomain.markers => _buildCompositionSidebarCard(
        document,
        authoring,
        section: ChunkCompositionSection.markers,
      ),
      ChunkSceneDomain.layers => _buildCompositionSidebarCard(
        document,
        authoring,
        section: ChunkCompositionSection.layers,
      ),
    };
    final sidebar = SingleChildScrollView(
      key: const ValueKey<String>('chunk_authoring_sidebar'),
      primary: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          activePanel,
          const SizedBox(height: _gap),
          _buildDiagnosticsCard(),
        ],
      ),
    );
    return IgnorePointer(
      ignoring: _visualPreview,
      child: Opacity(opacity: _visualPreview ? 0.45 : 1, child: sidebar),
    );
  }

  Widget _buildDiagnosticsCard() {
    final issues = widget.controller.issues;
    final errorCount = issues
        .where((issue) => issue.severity == ValidationSeverity.error)
        .length;
    final warningCount = issues
        .where((issue) => issue.severity == ValidationSeverity.warning)
        .length;
    final infoCount = issues.length - errorCount - warningCount;
    final description = issues.isEmpty
        ? 'No issues in the current chunk document.'
        : '${issues.length} total · $errorCount error(s) · '
              '$warningCount warning(s) · $infoCount info';
    return EditorPanelCard(
      key: const ValueKey<String>('chunk_diagnostics_card'),
      title: 'Diagnostics',
      description: description,
      collapsible: true,
      expansionKey: const ValueKey<String>('chunk_diagnostics_card_toggle'),
      child: Column(
        key: const ValueKey<String>('chunk_diagnostics_list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (issues.isEmpty)
            const Text('No validation issues.')
          else
            for (final (index, issue) in issues.indexed)
              ListTile(
                key: ValueKey<String>(
                  'chunk_diagnostic_${index}_${issue.code}',
                ),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _diagnosticIcon(issue.severity),
                  color: _diagnosticColor(issue.severity),
                ),
                title: Text(issue.code),
                subtitle: Text(
                  [issue.message, ?_diagnosticContext(issue)].join('\n'),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildCompositionSidebarCard(
    ChunkV2Document document,
    ChunkPolygonAuthoringController? authoring, {
    required ChunkCompositionSection section,
  }) {
    if (authoring == null) {
      final (cardKey, expansionKey, title) = switch (section) {
        ChunkCompositionSection.prefabs => (
          'chunk_prefabs_card',
          'chunk_prefabs_card_toggle',
          'Prefabs',
        ),
        ChunkCompositionSection.markers => (
          'chunk_markers_card',
          'chunk_markers_card_toggle',
          'Markers',
        ),
        ChunkCompositionSection.layers => (
          'chunk_layers_card',
          'chunk_layers_card_toggle',
          'Layers',
        ),
      };
      return EditorPanelCard(
        key: ValueKey<String>(cardKey),
        title: title,
        collapsible: true,
        expansionKey: ValueKey<String>(expansionKey),
        child: const Text('Select or create a chunk owner first.'),
      );
    }
    return ChunkCompositionCard(
      section: section,
      controller: widget.controller,
      document: document,
      chunk: authoring.chunk,
      controlsEnabled: !_hasActiveOperation && !_visualPreview,
      onOperationChanged: _setCompositionOperationActive,
      selectedPrefabKey: _sceneCoordinator.selectedPrefabKey,
      selectedMarkerKey: _sceneCoordinator.selectedMarkerKey,
      selectedCatalogPrefabKey: _selectedPrefabCatalogKey,
      onOpenOwningPrefab: widget.onOpenOwningPrefab,
      onCatalogPrefabSelected: (prefab) =>
          setState(() => _selectedPrefabCatalogKey = prefab.prefabKey),
      onPrefabSelected: (selection) => setState(() {
        _prefabGesture.setTool(ChunkPrefabSceneTool.select);
        _sceneCoordinator.selectPrefab(selection);
      }),
      onMarkerSelected: (selection) => setState(() {
        _markerGesture.setTool(ChunkMarkerSceneTool.select);
        _sceneCoordinator.selectMarker(selection);
        _refreshMarkerPlacementProjection();
      }),
    );
  }

  Widget _buildChunkOwnerSidebar(
    ChunkV2Document document,
    ChunkV2Scene scene,
    ChunkV2FileData? selectedChunk,
  ) => IgnorePointer(
    ignoring: _visualPreview,
    child: Opacity(
      opacity: _visualPreview ? 0.45 : 1,
      child: SingleChildScrollView(
        key: const ValueKey<String>('chunk_owner_sidebar'),
        primary: false,
        child: _buildOwnerPanel(
          document,
          scene,
          selectedChunk,
          controlsEnabled: !_hasActiveOperation && !_visualPreview,
        ),
      ),
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
          key: const ValueKey<String>('chunk_scene_global_controls'),
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FilterChip(
              key: const ValueKey<String>('chunk_visual_preview_toggle'),
              label: const Text('Visual preview'),
              selected: _visualPreview,
              onSelected: _hasActiveOperation
                  ? null
                  : (selected) {
                      setState(() => _visualPreview = selected);
                    },
            ),
            FilterChip(
              key: const ValueKey<String>('chunk_show_grid_toggle'),
              label: const Text('Show grid'),
              selected: _showGrid,
              onSelected: _visualPreview
                  ? null
                  : (selected) {
                      setState(() => _showGrid = selected);
                    },
            ),
            FilterChip(
              key: const ValueKey<String>('chunk_shape_edges_toggle'),
              label: const Text('Shape edges'),
              selected: _showShapeEdges,
              onSelected: _visualPreview
                  ? null
                  : (selected) {
                      setState(() => _showShapeEdges = selected);
                    },
            ),
            FilterChip(
              key: const ValueKey<String>('chunk_actor_terrain_toggle'),
              label: const Text('Actor terrain'),
              selected: _showActorTerrain,
              onSelected: _visualPreview
                  ? null
                  : (selected) {
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
              onSelected: _visualPreview
                  ? null
                  : (selected) {
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
              onChanged: _visualPreview || !_showActorTerrain
                  ? null
                  : (actor) {
                      if (actor == null) return;
                      setState(() => _selectedTerrainActor = actor);
                    },
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
          ],
        ),
        if (!_visualPreview && _showActorTerrain) ...<Widget>[
          const SizedBox(height: 4),
          _buildActorTerrainSummary(),
        ],
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ChunkSceneDomain>(
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
              ButtonSegment<ChunkSceneDomain>(
                value: ChunkSceneDomain.layers,
                label: Text('Layers'),
              ),
            ],
            selected: <ChunkSceneDomain>{_sceneCoordinator.sourceDomain},
            onSelectionChanged: _hasActiveOperation || _visualPreview
                ? null
                : (selection) => _selectSceneDomain(selection.single),
          ),
        ),
        const SizedBox(height: 4),
        IgnorePointer(
          ignoring: _visualPreview,
          child: Opacity(
            opacity: _visualPreview ? 0.45 : 1,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (_sceneCoordinator.sourceDomain == ChunkSceneDomain.terrain)
                  for (final tool in terrainPolygonSceneToolbarTools.where(
                    (tool) => tool != TerrainPolygonTool.createPolygon,
                  ))
                    ChoiceChip(
                      key: ValueKey<String>('chunk_polygon_tool_${tool.name}'),
                      label: Text(_toolLabel(tool)),
                      selected: authoring.state.tool == tool,
                      onSelected:
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
                          _hasActiveOperation ||
                              (tool == ChunkPrefabSceneTool.place &&
                                  _selectedCatalogPrefab(scene) == null)
                          ? null
                          : (_) => setState(() => _prefabGesture.setTool(tool)),
                    ),
                  Tooltip(
                    message:
                        _prefabGesture.surfaceSnapMessage ??
                        'Snap a compatible collider support edge to exposed '
                            'terrain without occupied-area overlap.',
                    child: FilterChip(
                      key: const ValueKey<String>(
                        'chunk_prefab_surface_snap_toggle',
                      ),
                      avatar: Icon(
                        _prefabGesture.isSurfaceSnapped
                            ? Icons.check_circle_outline
                            : Icons.vertical_align_bottom,
                        size: 18,
                      ),
                      label: const Text('Surface snap'),
                      selected: _prefabSurfaceSnapEnabled,
                      onSelected: _hasActiveOperation
                          ? null
                          : (value) => setState(
                              () => _prefabSurfaceSnapEnabled = value,
                            ),
                    ),
                  ),
                  if (_selectedCatalogPrefab(scene) case final prefab?)
                    Chip(
                      key: const ValueKey<String>(
                        'chunk_prefab_catalog_selection',
                      ),
                      avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: Text('Selected: ${prefab.id}'),
                    )
                  else
                    const Chip(
                      key: ValueKey<String>(
                        'chunk_prefab_catalog_selection_empty',
                      ),
                      avatar: Icon(Icons.inventory_2_outlined, size: 18),
                      label: Text('No active prefab'),
                    ),
                ] else if (_sceneCoordinator.sourceDomain ==
                    ChunkSceneDomain.markers) ...<Widget>[
                  for (final tool in ChunkMarkerSceneTool.values)
                    ChoiceChip(
                      key: ValueKey<String>('chunk_marker_tool_${tool.name}'),
                      label: Text(_markerToolLabel(tool)),
                      selected: _markerGesture.tool == tool,
                      onSelected: _hasActiveOperation
                          ? null
                          : (_) => setState(() => _markerGesture.setTool(tool)),
                    ),
                  DropdownButton<String>(
                    key: const ValueKey<String>(
                      'chunk_marker_catalog_selector',
                    ),
                    value:
                        _selectedMarkerCatalogId ?? chunkMarkerEnemyIds.first,
                    items: chunkMarkerEnemyIds
                        .map(
                          (markerId) => DropdownMenuItem<String>(
                            value: markerId,
                            child: Text(markerId),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _hasActiveOperation
                        ? null
                        : (markerId) => setState(
                            () => _selectedMarkerCatalogId = markerId,
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _visualPreview
              ? 'Visual preview shows runtime-facing chunk art only. Exit it '
                    'to resume authoring; Ctrl+drag still pans and Ctrl+scroll '
                    'zooms.'
              : _sceneCoordinator.sourceDomain == ChunkSceneDomain.prefabs
              ? 'Place and Move keep whole-pixel origins. Surface snap can '
                    'refine Y to exact non-overlapping terrain-edge contact. '
                    'Ctrl+drag pans and Ctrl+scroll zooms.'
              : _sceneCoordinator.sourceDomain == ChunkSceneDomain.markers
              ? 'Primary input selects the topmost authored marker anchor. '
                    'Ctrl+drag pans and Ctrl+scroll zooms.'
              : _sceneCoordinator.sourceDomain == ChunkSceneDomain.layers
              ? 'Layer metadata is edited in the sidebar. Scene authoring '
                    'input is paused; Ctrl+drag still pans and Ctrl+scroll '
                    'zooms.'
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
              final actorProjection = (!_visualPreview && _showActorTerrain)
                  ? _actorTerrainProjection
                  : null;
              final markerProjection =
                  (!_visualPreview &&
                      (_showMarkerPlacements ||
                          _sceneCoordinator.sourceDomain ==
                              ChunkSceneDomain.markers))
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
                showBorder: !_visualPreview,
                child: ChunkSceneSurface(
                  controller: authoring,
                  transform: transform,
                  activeDomain: _sceneCoordinator.domain,
                  semanticLabel: _visualPreview
                      ? 'Chunk visual preview'
                      : 'Chunk authoring scene',
                  showAuthoringOverlay: !_visualPreview,
                  interactionEnabled: !_visualPreview,
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
                      if (!_visualPreview)
                        CustomPaint(
                          key: const ValueKey<String>('chunk_bounds_overlay'),
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
                      if (!_visualPreview)
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
                                hiddenPlacementKey:
                                    _prefabGesture.previewCollisionLoops.isEmpty
                                    ? null
                                    : _prefabGesture.hiddenPlacementKey,
                                previewCollisionLoops:
                                    _prefabGesture.previewCollisionLoops,
                                previewTouchesTerrain:
                                    _prefabGesture.isSurfaceSnapped,
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
                      if (!_visualPreview && _showGrid)
                        IgnorePointer(
                          child: CustomPaint(
                            key: const ValueKey<String>(
                              'chunk_tile_grid_overlay',
                            ),
                            painter: _ChunkTileGridPainter(
                              chunk: chunk,
                              transform: transform,
                            ),
                          ),
                        ),
                      if (!_visualPreview &&
                          _sceneCoordinator.selectedPrefabKey != null &&
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
                      if (!_visualPreview && prefabCandidateVisual != null)
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
                      if (!_visualPreview)
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
                      if (!_visualPreview &&
                          _showShapeEdges &&
                          expansion != null)
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
                  onInspectWorldPoint: null,
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
    final creationMaterialValue = authoring.newShapeMaterialKey?.trim() ?? '';
    final creationMaterialOptions = terrainMetadataSelectorOptions(
      current: creationMaterialValue,
      known:
          _materialCatalog?.materials.map((material) => material.key) ??
          const <String>[],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildShapeCreationPanel(
          authoring,
          creationMaterialValue: creationMaterialValue,
          creationMaterialOptions: creationMaterialOptions,
        ),
        const SizedBox(height: _gap),
        EditorSectionCard(
          key: const ValueKey<String>('chunk_polygon_shapes_panel'),
          expansionKey: const ValueKey<String>(
            'chunk_polygon_shapes_panel_toggle',
          ),
          title: 'Existing terrain shapes',
          description: shapes.isEmpty
              ? 'Saved direct collision shapes will appear here.'
              : 'Select a shape to edit its metadata, geometry, or lifecycle.',
          trailing: Text('${shapes.length} total'),
          collapsible: true,
          child: Column(
            key: const ValueKey<String>('chunk_shape_list'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (shapes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No existing terrain shapes. Use the creation card above '
                    'to draw the first one.',
                  ),
                )
              else
                for (final shape in shapes) ...<Widget>[
                  _buildExistingShapeCard(
                    authoring,
                    shape,
                    selected: selection?.shapeId == shape.shapeId,
                  ),
                  if (selectedShape?.shapeId == shape.shapeId)
                    Padding(
                      key: const ValueKey<String>(
                        'chunk_polygon_selected_shape_editor',
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Edit ${shape.shapeId}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _buildTerrainSnapSwitch(
                            authoring,
                            keyName: 'chunk_polygon_edit_snap_to_grid',
                            forCreation: false,
                          ),
                          const SizedBox(height: 8),
                          _buildSelectedShapeHeader(authoring, shape),
                          const SizedBox(height: 8),
                          _buildVertexInspector(authoring, shape),
                        ],
                      ),
                    ),
                ],
            ],
          ),
        ),
      ],
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
        '${projection.groundedView(ChunkV2TerrainActor.eloise)!.eligibleSurfaces.length} '
            'Éloïse-walkable surfaces · cyan edges are traversable',
      ChunkV2TerrainActor.grojib || ChunkV2TerrainActor.hashash =>
        '${projection.groundedView(_selectedTerrainActor)!.eligibleSurfaces.length} '
            '${_terrainActorLabel(_selectedTerrainActor)}-walkable surfaces',
      ChunkV2TerrainActor.unoco =>
        '${projection.unocoSolidBlockerIds.length} solid blockers · '
            '${projection.unocoLocalHoverCandidateIds.length} local-hover '
            'surface candidates',
      ChunkV2TerrainActor.derf =>
        '${projection.derfPerches.where((item) => item.perchEligible).length} '
            'perch-eligible surfaces · 32 px minimum horizontal support span',
    };
    return Text(
      text,
      key: const ValueKey<String>('chunk_actor_terrain_summary'),
    );
  }

  Widget _buildShapeCreationPanel(
    ChunkPolygonAuthoringController authoring, {
    required String creationMaterialValue,
    required List<String> creationMaterialOptions,
  }) {
    final draft = authoring.state.draft;
    final gesture = authoring.state.gesture;
    final rectangleGesture =
        gesture?.kind == TerrainPolygonGestureKind.createRectangle;
    final rectangleReady =
        draft == null &&
        gesture == null &&
        authoring.state.tool == TerrainPolygonTool.createRectangle;
    final polygonDraftActive = draft != null && !draft.isClosed;
    return EditorSectionCard(
      key: const ValueKey<String>('chunk_polygon_creation_panel'),
      expansionKey: const ValueKey<String>(
        'chunk_polygon_creation_panel_toggle',
      ),
      title: 'Create terrain shape',
      description: 'Choose collision and material first, then draw in the terrain scene.',
      collapsible: true,
      child: Column(
        key: const ValueKey<String>('chunk_polygon_creation_section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            key: ValueKey<String>(
              'chunk_polygon_creation_name_${authoring.newShapeNameGeneration}',
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
          const SizedBox(height: 8),
          _buildMetadataDropdown<TerrainSourceCollisionMode>(
            keyName: 'chunk_polygon_creation_mode_selector',
            label: 'Collision',
            value: authoring.newShapeCollisionMode,
            items: TerrainSourceCollisionMode.values
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
                    if (mode == null) return;
                    authoring.setNewShapeCollisionMode(mode);
                  },
          ),
          const SizedBox(height: 8),
          _buildMaterialDropdown(
            keyName: 'chunk_polygon_creation_material_selector',
            label: 'Material',
            previewKeyPrefix: 'chunk_polygon_creation_material_preview',
            value: creationMaterialValue,
            options: creationMaterialOptions,
            enabled: !authoring.hasActiveOperation,
            onChanged: (next) {
              authoring.setNewShapeMaterialKey(
                nullableTerrainMetadataSelection(next),
              );
            },
          ),
          const SizedBox(height: 4),
          _buildTerrainSnapSwitch(
            authoring,
            keyName: 'chunk_polygon_creation_snap_to_grid',
            forCreation: true,
          ),
          if (draft != null || rectangleGesture || rectangleReady) ...<Widget>[
            const SizedBox(height: 10),
            _buildCreationStatus(
              authoring,
              draft: draft,
              rectangleGesture: rectangleGesture,
              rectangleReady: rectangleReady,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('chunk_polygon_new_shape'),
                onPressed: polygonDraftActive
                    ? authoring.state.tool == TerrainPolygonTool.createPolygon
                          ? null
                          : () => authoring.setTool(
                              TerrainPolygonTool.createPolygon,
                            )
                    : authoring.hasActiveOperation ||
                          !authoring.canBeginNewShape
                    ? null
                    : () {
                        authoring.setTool(TerrainPolygonTool.createPolygon);
                        authoring.beginCreatePolygon();
                      },
                icon: const Icon(Icons.polyline),
                label: Text(
                  polygonDraftActive ? 'Continue drawing' : 'Draw polygon',
                ),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey<String>('chunk_polygon_new_rectangle'),
                onPressed:
                    authoring.hasActiveOperation || !authoring.canBeginNewShape
                    ? null
                    : () =>
                          authoring.setTool(TerrainPolygonTool.createRectangle),
                icon: const Icon(Icons.crop_square),
                label: const Text('Draw rectangle'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('chunk_polygon_save_draft'),
                onPressed: draft == null || draft.vertices.length < 3
                    ? null
                    : authoring.saveDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save shape'),
              ),
              TextButton(
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
        ],
      ),
    );
  }

  Widget _buildTerrainSnapSwitch(
    ChunkPolygonAuthoringController authoring, {
    required String keyName,
    required bool forCreation,
  }) {
    final enabled = !authoring.hasActiveOperation && !_visualPreview;
    return SwitchListTile(
      key: ValueKey<String>(keyName),
      contentPadding: EdgeInsets.zero,
      title: const Text('Snap to grid'),
      subtitle: Text(
        'Snap vertices to the nearest ${authoring.chunk.tileSize} px tile '
        'intersection.',
      ),
      value: forCreation
          ? authoring.creationSnapToGrid
          : authoring.editSnapToGrid,
      onChanged: enabled
          ? (selected) {
              if (forCreation) {
                _terrainCreationSnapToGrid = selected;
                authoring.setCreationSnapToGrid(selected);
              } else {
                _terrainEditSnapToGrid = selected;
                authoring.setEditSnapToGrid(selected);
              }
            }
          : null,
    );
  }

  Widget _buildMaterialDropdown({
    required String keyName,
    required String label,
    required String previewKeyPrefix,
    required String value,
    required List<String> options,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey<String>(keyName),
          value: value,
          isDense: true,
          isExpanded: true,
          selectedItemBuilder: (context) => options
              .map(
                (option) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    terrainMaterialSelectorLabel(_materialCatalog, option),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          terrainMaterialSelectorLabel(
                            _materialCatalog,
                            option,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (option.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 8),
                        IconButton(
                          key: ValueKey<String>('${previewKeyPrefix}_$option'),
                          tooltip: 'Preview $option',
                          visualDensity: VisualDensity.compact,
                          onPressed: !enabled
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  _showReadOnlyMaterialPreview(option);
                                },
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                      ],
                    ],
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: enabled && options.length > 1
              ? (next) {
                  if (next == null || next == value) return;
                  onChanged(next);
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildCreationStatus(
    ChunkPolygonAuthoringController authoring, {
    required TerrainPolygonDraft? draft,
    required bool rectangleGesture,
    required bool rectangleReady,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final (title, message) = switch ((
      draft,
      rectangleGesture,
      rectangleReady,
    )) {
      (_, true, _) => (
        'Drawing rectangle',
        '${_collisionModeLabel(authoring.newShapeCollisionMode)} · '
            '${_creationMaterialLabel(authoring.newShapeMaterialKey)}. '
            'Release when the preview reaches the intended corner.',
      ),
      (final draft?, _, _) => (
        draft.isClosed ? 'Rectangle draft ready' : 'Polygon draft in progress',
        '${_collisionModeLabel(draft.collisionMode)} · '
            '${_creationMaterialLabel(draft.materialKey)} · '
            '${draft.vertices.length} vertices. '
            '${draft.vertices.length < 3 ? 'Add at least 3 vertices.' : 'Ready to save or keep editing.'}',
      ),
      _ => (
        'Rectangle tool ready',
        'Drag between opposite corners in the terrain scene.',
      ),
    };
    return Container(
      key: const ValueKey<String>('chunk_polygon_creation_status'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.edit_outlined, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingShapeCard(
    ChunkPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape, {
    required bool selected,
  }) {
    final rectangle = TerrainAxisAlignedRectangle.tryFromShape(shape);
    return EditorListCard(
      key: ValueKey<String>('chunk_polygon_shape_${shape.shapeId}'),
      isSelected: selected,
      onTap: () => _selectOrCloseShape(authoring, shape),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        selected: selected,
        leading: Icon(switch (shape.collisionMode) {
          TerrainSourceCollisionMode.solid => Icons.square_outlined,
          TerrainSourceCollisionMode.oneWay => Icons.horizontal_rule,
          TerrainSourceCollisionMode.none => Icons.layers_clear_outlined,
        }),
        title: Text(shape.shapeId),
        subtitle: Text(
          '${_collisionModeLabel(shape.collisionMode)}'
          '${rectangle == null ? '' : ' · Rectangle'}'
          '${shape.materialKey == null ? '' : ' · ${shape.materialKey}'}',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text('${shape.vertices.length} vertices'),
      ),
    );
  }

  String _creationMaterialLabel(String? materialKey) {
    final value = materialKey?.trim() ?? '';
    return value.isEmpty
        ? 'No material'
        : terrainMaterialSelectorLabel(_materialCatalog, value);
  }

  String _collisionModeLabel(TerrainSourceCollisionMode collisionMode) =>
      switch (collisionMode) {
        TerrainSourceCollisionMode.solid => 'Solid',
        TerrainSourceCollisionMode.oneWay => 'One-way',
        TerrainSourceCollisionMode.none => 'No collision (visual only)',
      };

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
    final shapeNameInput = _shapeNameDrafts[shape.shapeId] ?? shape.shapeId;
    final shapeNameError = authoring.validateShapeName(
      shapeNameInput,
      excludingShapeId: shape.shapeId,
    );
    return Column(
      key: const ValueKey<String>('chunk_polygon_metadata_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Metadata', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey<String>('chunk_polygon_shape_name_${shape.shapeId}'),
          initialValue: shapeNameInput,
          enabled: controlsEnabled,
          decoration: InputDecoration(
            labelText: 'Shape name',
            helperText:
                'Lowercase letters, numbers, and underscores; unique in '
                'this chunk.',
            errorText: shapeNameError,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() => _shapeNameDrafts[shape.shapeId] = value);
          },
        ),
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
        _buildMaterialDropdown(
          keyName: 'chunk_polygon_metadata_material_selector',
          label: 'Material key',
          previewKeyPrefix: 'chunk_polygon_metadata_material_preview',
          value: materialValue,
          options: materialOptions,
          enabled: controlsEnabled,
          onChanged: (value) {
            authoring.editSelectedShapeMetadata(
              collisionMode: shape.collisionMode,
              surfaceKind: shape.surfaceKind,
              materialKey: nullableTerrainMetadataSelection(value),
            );
          },
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
    final shapeNameError = authoring.validateShapeName(
      _pendingShapeName(shape),
      excludingShapeId: shape.shapeId,
    );
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
            applyButtonKey: const ValueKey<String>('chunk_polygon_save_edit'),
            applyLabel: 'Save edit',
            applyEnabled: shapeNameError == null,
            coordinateStepHalfPixels: 2,
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
              if (saved) _shapeNameDrafts.remove(shape.shapeId);
              return saved;
            },
          ),
        ] else if (rectangle != null) ...<Widget>[
          const SizedBox(height: 8),
          TerrainPolygonRectangleEditor(
            key: ValueKey<String>(
              'chunk_polygon_rectangle_editor_${shape.shapeId}_'
              '${rectangle.xHalfPixels}_${rectangle.yHalfPixels}_'
              '${rectangle.widthHalfPixels}_${rectangle.heightHalfPixels}',
            ),
            keyPrefix: 'chunk_polygon',
            rectangle: rectangle,
            applyButtonKey: const ValueKey<String>('chunk_polygon_save_edit'),
            applyLabel: 'Save edit',
            applyEnabled: shapeNameError == null,
            coordinateStepHalfPixels: 2,
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
                  if (saved) _shapeNameDrafts.remove(shape.shapeId);
                  return saved;
                },
          ),
        ] else ...<Widget>[
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey<String>('chunk_polygon_save_edit'),
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
    ChunkPolygonAuthoringController authoring,
    TerrainSourceShapeDef shape,
  ) =>
      authoring.validateShapeName(
        _pendingShapeName(shape),
        excludingShapeId: shape.shapeId,
      ) ==
      null;

  bool _saveShapeName(
    ChunkPolygonAuthoringController authoring,
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

  Future<void> _selectOrCloseShape(
    ChunkPolygonAuthoringController authoring,
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
    ChunkPolygonAuthoringController authoring,
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
        key: const ValueKey<String>('chunk_polygon_unsaved_edit_dialog'),
        title: const Text('Save terrain shape changes?'),
        content: Text(
          'Save the pending changes to ${shape.shapeId} before closing its '
          'editor?',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('chunk_polygon_unsaved_edit_cancel'),
            onPressed: () =>
                Navigator.of(context).pop(_PendingShapeEditAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey<String>('chunk_polygon_unsaved_edit_discard'),
            onPressed: () =>
                Navigator.of(context).pop(_PendingShapeEditAction.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            key: const ValueKey<String>('chunk_polygon_unsaved_edit_save'),
            onPressed: () =>
                Navigator.of(context).pop(_PendingShapeEditAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || !identical(authoring, _authoring)) return false;
    switch (action) {
      case _PendingShapeEditAction.save:
        return _exactEditController.hasEditor
            ? _exactEditController.save()
            : _saveShapeName(authoring, shape);
      case _PendingShapeEditAction.discard:
        _exactEditController.discard();
        setState(() => _shapeNameDrafts.remove(shape.shapeId));
        return true;
      case _PendingShapeEditAction.cancel:
      case null:
        return false;
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
      snapStepHalfPixels: authoring.editSnapPolicy.stepHalfPixels,
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
    _shapeNameDrafts.clear();
    _prefabGesture.cancel();
    _markerGesture.cancel();
    _selectedChunkKey = chunkKey;
    _sceneCoordinator.bindOwner();
    _actorTerrainExpansion = null;
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
      creationSnapToGrid: _terrainCreationSnapToGrid,
      editSnapToGrid: _terrainEditSnapToGrid,
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
    newShapeCollisionMode: authoring.newShapeCollisionMode,
    newShapeMaterialKey: authoring.newShapeMaterialKey,
    newShapeNameInput: authoring.newShapeNameInput,
    newShapeNameGeneration: authoring.newShapeNameGeneration,
    creationSnapToGrid: authoring.creationSnapToGrid,
    creationSnapStep: authoring.creationSnapPolicy.stepHalfPixels,
    editSnapToGrid: authoring.editSnapToGrid,
    editSnapStep: authoring.editSnapPolicy.stepHalfPixels,
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
    if (identical(expansion, _actorTerrainExpansion)) return;
    _actorTerrainExpansion = expansion;
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
      case ChunkSceneDomain.terrain ||
          ChunkSceneDomain.layers ||
          ChunkSceneDomain.compiledEdgeInspection:
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
    if (_hasActiveOperation) return false;
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
                surfaceSnapContext: _prefabSurfaceSnapContext(chunk),
                surfaceSnapRadiusWorld: chunkPrefabSurfaceSnapRadiusPx / _zoom,
                surfaceSnapEnabled: _prefabSurfaceSnapEnabled,
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
                final prefab = _resolvePlacedPrefab(
                  scene.prefabData.prefabs,
                  selection.prefab,
                );
                began = _prefabGesture.beginMove(
                  pointer: pointer,
                  worldPoint: worldPoint,
                  chunk: chunk,
                  selection: selection,
                  prefab: prefab,
                  surfaceSnapContext: _prefabSurfaceSnapContext(
                    chunk,
                    excludedPlacementKey: selection.selectionKey,
                  ),
                  surfaceSnapRadiusWorld:
                      chunkPrefabSurfaceSnapRadiusPx / _zoom,
                  surfaceSnapEnabled: _prefabSurfaceSnapEnabled,
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
      case ChunkSceneDomain.terrain ||
          ChunkSceneDomain.layers ||
          ChunkSceneDomain.compiledEdgeInspection:
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
    if (_hasActiveOperation) return;
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
      case ChunkSceneDomain.terrain ||
          ChunkSceneDomain.layers ||
          ChunkSceneDomain.compiledEdgeInspection:
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
      PrefabDeterminism.sortPrefabV3ByIdThenKey(
        scene.prefabData.prefabs.where(
          (prefab) => prefab.status == PrefabStatus.active,
        ),
      );

  PrefabV3Def? _selectedCatalogPrefab(ChunkV2Scene scene) {
    final prefabs = _activePrefabCatalog(scene);
    if (prefabs.isEmpty) return null;
    return prefabs
            .where((prefab) => prefab.prefabKey == _selectedPrefabCatalogKey)
            .firstOrNull ??
        prefabs.first;
  }

  ChunkPrefabSurfaceSnapContext? _prefabSurfaceSnapContext(
    ChunkV2FileData chunk, {
    String? excludedPlacementKey,
  }) {
    final expansion = _expansionFor(chunk.chunkKey)?.expansion;
    if (expansion == null) return null;
    return ChunkPrefabSurfaceSnapContext.fromGeometry(
      geometry: expansion.geometry,
      excludedPlacementKey: excludedPlacementKey,
    );
  }

  PrefabV3Def? _resolvePlacedPrefab(
    Iterable<PrefabV3Def> prefabs,
    PlacedPrefabDef placement,
  ) {
    if (placement.prefabKey.isNotEmpty) {
      final keyMatch = prefabs
          .where((prefab) => prefab.prefabKey == placement.prefabKey)
          .firstOrNull;
      if (keyMatch != null) return keyMatch;
    }
    if (placement.prefabId.isEmpty) return null;
    return prefabs
        .where((prefab) => prefab.id == placement.prefabId)
        .firstOrNull;
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

/// Compact, read-only composition preview for one owner-row card.
class _ChunkOwnerPreview extends StatelessWidget {
  const _ChunkOwnerPreview({
    super.key,
    required this.workspaceRootPath,
    required this.chunk,
    required this.scene,
  });

  final String workspaceRootPath;
  final ChunkV2FileData chunk;
  final ChunkV2Scene scene;

  @override
  Widget build(BuildContext context) {
    final visualProjection = ChunkSceneVisualProjection.fromChunk(
      chunk: chunk,
      prefabData: scene.prefabData,
      tileData: scene.tileData,
      visualBoundsByPrefabKey: scene.visualBoundsByPrefabKey,
    );
    final belowTerrain = visualProjection
        .belowTerrain(chunk.groundBandZIndex)
        .toList(growable: false);
    final atOrAboveTerrain = visualProjection
        .atOrAboveTerrain(chunk.groundBandZIndex)
        .toList(growable: false);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: 'Preview of ${chunk.id}',
      child: RepaintBoundary(
        child: Container(
          width: 104,
          height: 68,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chunkWidth = math.max(1, chunk.width).toDouble();
                final chunkHeight = math.max(1, chunk.height).toDouble();
                final zoom = math.min(
                  constraints.maxWidth / chunkWidth,
                  constraints.maxHeight / chunkHeight,
                );
                final transform = TerrainPolygonViewportTransform(
                  origin: Offset(
                    (constraints.maxWidth - chunkWidth * zoom) * 0.5,
                    (constraints.maxHeight - chunkHeight * zoom) * 0.5,
                  ),
                  zoom: zoom,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ChunkPolygonLevelVisualSource(
                      workspaceRootPath: workspaceRootPath,
                      chunk: chunk,
                      parallaxTheme: scene.activeParallaxTheme,
                      transform: transform,
                      layer: ChunkPolygonLevelVisualLayer.background,
                    ),
                    if (belowTerrain.isNotEmpty)
                      ChunkSceneVisualSource(
                        workspaceRootPath: workspaceRootPath,
                        placements: belowTerrain,
                        transform: transform,
                      ),
                    ChunkPolygonLevelVisualSource(
                      workspaceRootPath: workspaceRootPath,
                      chunk: chunk,
                      parallaxTheme: scene.activeParallaxTheme,
                      transform: transform,
                      layer: ChunkPolygonLevelVisualLayer.terrain,
                    ),
                    ChunkPolygonLevelVisualSource(
                      workspaceRootPath: workspaceRootPath,
                      chunk: chunk,
                      parallaxTheme: scene.activeParallaxTheme,
                      transform: transform,
                      layer: ChunkPolygonLevelVisualLayer.foreground,
                    ),
                    if (atOrAboveTerrain.isNotEmpty)
                      ChunkSceneVisualSource(
                        workspaceRootPath: workspaceRootPath,
                        placements: atOrAboveTerrain,
                        transform: transform,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ChunkTileGridPainter extends CustomPainter {
  const _ChunkTileGridPainter({required this.chunk, required this.transform});

  final ChunkV2FileData chunk;
  final TerrainPolygonViewportTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(
      transform.origin.dx,
      transform.origin.dy,
      chunk.width * transform.zoom,
      chunk.height * transform.zoom,
    );
    canvas.save();
    canvas.clipRect(bounds);
    EditorViewportGridPainter.world(
      zoom: transform.zoom,
      worldRect: Rect.fromLTWH(
        0,
        0,
        chunk.width.toDouble(),
        chunk.height.toDouble(),
      ),
      worldOrigin: transform.origin,
      worldSpacingPx: chunk.tileSize.toDouble(),
      majorWorldSpacingPx: chunk.tileSize * 4.0,
    ).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChunkTileGridPainter oldDelegate) =>
      oldDelegate.chunk.width != chunk.width ||
      oldDelegate.chunk.height != chunk.height ||
      oldDelegate.chunk.tileSize != chunk.tileSize ||
      oldDelegate.transform.origin != transform.origin ||
      oldDelegate.transform.zoom != transform.zoom;
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

IconData _diagnosticIcon(ValidationSeverity severity) => switch (severity) {
  ValidationSeverity.error => Icons.error_outline,
  ValidationSeverity.warning => Icons.warning_amber_outlined,
  ValidationSeverity.info => Icons.info_outline,
};

Color _diagnosticColor(ValidationSeverity severity) => switch (severity) {
  ValidationSeverity.error => const Color(0xFFFF7F7F),
  ValidationSeverity.warning => const Color(0xFFFFD166),
  ValidationSeverity.info => const Color(0xFF7DD3FC),
};

String? _diagnosticContext(ValidationIssue issue) {
  final sourcePath = issue.sourcePath?.trim();
  final ownerKey = issue.ownerKey?.trim();
  final placementKey = issue.placementKey?.trim();
  final shapeId = issue.shapeId?.trim();
  final parts = <String>[
    if (sourcePath != null && sourcePath.isNotEmpty) sourcePath,
    if (ownerKey != null && ownerKey.isNotEmpty) 'owner $ownerKey',
    if (placementKey != null && placementKey.isNotEmpty)
      'placement $placementKey',
    if (shapeId != null && shapeId.isNotEmpty) 'shape $shapeId',
    if (issue.elementIndex case final elementIndex?) 'element $elementIndex',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
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
