import 'package:flutter/material.dart';

import '../../../chunks/chunk_v2_models.dart';
import '../../../session/editor_session_controller.dart';
import '../../../terrain_authoring/polygon_authoring_migration_required.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/polygon_authoring_migration_required_workspace.dart';
import 'v2/chunk_polygon_workspace.dart';

/// Current chunk-v2 editor route.
///
/// Legacy or missing source is represented by the fail-closed migration
/// workspace. Chunk-v1 rectangle authoring is intentionally unavailable here;
/// the offline migration command is its only remaining reader.
class ChunkCreatorPage extends StatefulWidget {
  const ChunkCreatorPage({
    super.key,
    required this.controller,
    this.onOpenOwningPrefab,
  });

  final EditorSessionController controller;

  /// Delegates placed-collision source navigation to the owning app shell.
  final ValueChanged<String>? onOpenOwningPrefab;

  @override
  State<ChunkCreatorPage> createState() => _ChunkCreatorPageState();
}

class _ChunkCreatorPageState extends State<ChunkCreatorPage>
    implements
        EditorPageLocalDraftState,
        EditorPageSessionShortcutHandler,
        EditorPageReloadHandler {
  final GlobalKey<ChunkPolygonWorkspaceState> _workspaceKey =
      GlobalKey<ChunkPolygonWorkspaceState>();

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
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.controller.isLoading ||
          widget.controller.scene is ChunkV2Scene ||
          widget.controller.scene is PolygonAuthoringMigrationRequiredScene) {
        return;
      }
      widget.controller.loadWorkspace();
    });
  }

  @override
  void didUpdateWidget(covariant ChunkCreatorPage oldWidget) {
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
    if (scene is ChunkV2Scene) {
      return ChunkPolygonWorkspace(
        key: _workspaceKey,
        controller: widget.controller,
        onOpenOwningPrefab: widget.onOpenOwningPrefab,
      );
    }
    if (widget.controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return const Center(child: Text('Current chunk source is unavailable.'));
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }
}
