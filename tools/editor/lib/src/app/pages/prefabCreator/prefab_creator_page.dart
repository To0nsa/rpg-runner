import 'package:flutter/material.dart';

import '../../../prefabs/domain/prefab_domain_models.dart';
import '../../../session/editor_session_controller.dart';
import '../../../terrain_authoring/polygon_authoring_migration_required.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_page_navigation_state.dart';
import '../shared/polygon_authoring_migration_required_workspace.dart';
import 'atlas_slicer/atlas_image_file_picker.dart';
import 'prefab_creator_navigation.dart';
import 'v3/prefab_polygon_workspace.dart';

/// Current prefab-v3 editor route.
///
/// Legacy or missing source is represented by the fail-closed migration
/// workspace. Rectangle-era editing is intentionally unavailable here; the
/// offline migration command is its only remaining reader.
class PrefabCreatorPage extends StatefulWidget {
  const PrefabCreatorPage({
    super.key,
    required this.controller,
    this.initialLocation,
    this.initialTarget,
    this.initialPrefabKey,
    this.onShellStateChanged,
    this.atlasImageFilePicker = pickAtlasImageFilePath,
  }) : assert(initialTarget == null || initialPrefabKey == null);

  final EditorSessionController controller;
  final PrefabCreatorLocation? initialLocation;
  final VoidCallback? onShellStateChanged;

  /// Stable owner and workflow requested by guarded cross-route navigation.
  final PrefabCreatorTarget? initialTarget;

  /// Backward-compatible owner-only request for embedded callers.
  final String? initialPrefabKey;

  /// Native atlas-source picker, replaceable for deterministic widget tests.
  final AtlasImageFilePicker atlasImageFilePicker;

  @override
  State<PrefabCreatorPage> createState() => _PrefabCreatorPageState();
}

class _PrefabCreatorPageState extends State<PrefabCreatorPage>
    implements
        EditorPageLocalDraftState,
        EditorPageNavigationState,
        EditorPageSessionShortcutHandler,
        EditorPageReloadHandler,
        EditorPageSaveHandler {
  final GlobalKey<PrefabPolygonWorkspaceState> _workspaceKey =
      GlobalKey<PrefabPolygonWorkspaceState>();

  @override
  PrefabCreatorLocation? get navigationLocation =>
      _workspaceKey.currentState?.navigationLocation;

  bool get _migrationRequired =>
      widget.controller.scene is PolygonAuthoringMigrationRequiredScene;

  @override
  bool get hasLocalDraftChanges => _migrationRequired
      ? false
      : _workspaceKey.currentState?.hasLocalDraftChanges ??
            widget.controller.pendingChanges.hasChanges;

  @override
  bool get canHandleUndoSessionShortcut =>
      !_migrationRequired &&
      (_workspaceKey.currentState?.canUndo ?? widget.controller.canUndo);

  @override
  bool get canHandleRedoSessionShortcut =>
      !_migrationRequired &&
      (_workspaceKey.currentState?.canRedo ?? widget.controller.canRedo);

  @override
  bool get canReloadEditorPage =>
      !widget.controller.isLoading && !widget.controller.isExporting;

  @override
  bool handleUndoSessionShortcut() =>
      !_migrationRequired &&
      (_workspaceKey.currentState?.handleUndoShortcut() ?? false);

  @override
  bool handleRedoSessionShortcut() =>
      !_migrationRequired &&
      (_workspaceKey.currentState?.handleRedoShortcut() ?? false);

  @override
  Future<void> reloadEditorPage() async {
    if (_migrationRequired) {
      await PolygonAuthoringMigrationRequiredWorkspace.recheckSource(
        widget.controller,
      );
      return;
    }
    await widget.controller.loadWorkspace();
  }

  @override
  bool get canSaveEditorPage =>
      !_migrationRequired &&
      (_workspaceKey.currentState?.canApplyToFiles ?? false);

  @override
  Future<EditorPageSaveResult> saveEditorPage() async {
    if (_migrationRequired) return EditorPageSaveResult.blocked;
    await _workspaceKey.currentState?.applyToFiles();
    if (hasLocalDraftChanges) return EditorPageSaveResult.blocked;
    return EditorPageSaveResult.fromSession(widget.controller);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.controller.isLoading ||
          widget.controller.scene is PrefabV3Scene ||
          widget.controller.scene is PolygonAuthoringMigrationRequiredScene) {
        return;
      }
      widget.controller.loadWorkspace();
    });
  }

  @override
  void didUpdateWidget(covariant PrefabCreatorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.controller.scene;
    if (scene is PolygonAuthoringMigrationRequiredScene) {
      return PolygonAuthoringMigrationRequiredWorkspace(
        controller: widget.controller,
      );
    }
    if (scene is PrefabV3Scene) {
      return PrefabPolygonWorkspace(
        initialLocation: widget.initialLocation,
        key: _workspaceKey,
        onDraftStateChanged: widget.onShellStateChanged,
        controller: widget.controller,
        initialTarget:
            widget.initialTarget ??
            (widget.initialPrefabKey == null
                ? null
                : PrefabCreatorTarget(
                    prefabKey: widget.initialPrefabKey!,
                    destination: PrefabCreatorDestination.prefab,
                  )),
        atlasImageFilePicker: widget.atlasImageFilePicker,
      );
    }
    if (widget.controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return const Center(child: Text('Current prefab source is unavailable.'));
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }
}
