import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../chunks/chunk_v2_models.dart';
import '../../../playtest/authored_playtest_preparation.dart';
import '../../../session/editor_session_controller.dart';
import '../../../terrain_authoring/polygon_authoring_migration_required.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/authored_playtest_session.dart';
import '../shared/polygon_authoring_migration_required_workspace.dart';
import 'v2/chunk_authoring_workspace.dart';

/// Current chunk-v2 editor route with an isolated Windows Play mode.
///
/// Legacy or missing source remains fail closed. The normal authoring subtree
/// stays mounted while a scenario prepares or runs, so Play/Stop cannot replace
/// plugin/session state or page-local selection and viewport state.
class ChunkCreatorPage extends StatefulWidget {
  const ChunkCreatorPage({
    super.key,
    required this.controller,
    this.onOpenOwningPrefab,
    this.onShellStateChanged,
    this.playtestPlatformSupported,
    this.preparationRunner = preparePlaytestInBackground,
    this.playtestHostBuilder = buildDefaultAuthoredPlaytestHost,
  });

  final EditorSessionController controller;

  /// Delegates placed-collision source navigation to the owning app shell.
  final ValueChanged<String>? onOpenOwningPrefab;

  /// Requests a shell-control rebuild after route-local lock state changes.
  final VoidCallback? onShellStateChanged;

  /// Optional platform override for tests; production defaults to Windows.
  final bool? playtestPlatformSupported;

  /// Pure preparation runner; production uses a background isolate.
  final PlaytestPreparationRunner preparationRunner;

  /// Runtime host factory shared with authored Level Play.
  final AuthoredPlaytestHostBuilder playtestHostBuilder;

  @override
  State<ChunkCreatorPage> createState() => _ChunkCreatorPageState();
}

class _ChunkCreatorPageState extends State<ChunkCreatorPage>
    implements
        EditorPageLocalDraftState,
        EditorPageSessionShortcutHandler,
        EditorPageReloadHandler,
        EditorPageSaveHandler,
        EditorPagePlaytestHandler {
  final GlobalKey<ChunkAuthoringWorkspaceState> _workspaceKey =
      GlobalKey<ChunkAuthoringWorkspaceState>();

  final AuthoredPlaytestSession _playtest = AuthoredPlaytestSession();
  bool _finalizingForPlay = false;

  bool get _migrationRequired =>
      widget.controller.scene is PolygonAuthoringMigrationRequiredScene;

  bool get _platformSupportsPlaytest =>
      widget.playtestPlatformSupported ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

  @override
  bool get locksEditorShell => _playtest.locksEditor || _finalizingForPlay;

  @override
  bool get hasLocalDraftChanges => _migrationRequired
      ? false
      : _workspaceKey.currentState?.hasLocalDraftChanges ??
            widget.controller.pendingChanges.hasChanges;

  @override
  bool get canHandleUndoSessionShortcut =>
      !locksEditorShell &&
      !_migrationRequired &&
      (_workspaceKey.currentState?.canUndo ?? widget.controller.canUndo);

  @override
  bool get canHandleRedoSessionShortcut =>
      !locksEditorShell &&
      !_migrationRequired &&
      (_workspaceKey.currentState?.canRedo ?? widget.controller.canRedo);

  @override
  bool get canReloadEditorPage =>
      !locksEditorShell &&
      !(_workspaceKey.currentState?.hasActiveOperation ?? false) &&
      !widget.controller.isLoading &&
      !widget.controller.isExporting;

  @override
  bool handleUndoSessionShortcut() =>
      !locksEditorShell &&
      !_migrationRequired &&
      (_workspaceKey.currentState?.handleUndoShortcut() ?? false);

  @override
  bool handleRedoSessionShortcut() =>
      !locksEditorShell &&
      !_migrationRequired &&
      (_workspaceKey.currentState?.handleRedoShortcut() ?? false);

  @override
  Future<void> reloadEditorPage() async {
    if (locksEditorShell) return;
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
      !locksEditorShell &&
      !_migrationRequired &&
      (_workspaceKey.currentState?.canApplyToFiles ?? false);

  @override
  Future<EditorPageSaveResult> saveEditorPage() async {
    if (locksEditorShell || _migrationRequired) {
      return EditorPageSaveResult.blocked;
    }
    await _workspaceKey.currentState?.applyToFiles();
    return EditorPageSaveResult.fromSession(widget.controller);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _playtest.addListener(_handlePlaytestChanged);
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
    _playtest.stop();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _playtest.removeListener(_handlePlaytestChanged);
    _playtest.dispose();
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
    if (scene is ChunkV2Scene) return _buildCurrentSchemaWorkspace();
    if (widget.controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return const Center(child: Text('Current chunk source is unavailable.'));
  }

  Widget _buildCurrentSchemaWorkspace() {
    final isEditing = !_playtest.locksEditor;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Offstage(
          offstage: !isEditing,
          child: TickerMode(
            enabled: isEditing,
            child: IgnorePointer(
              ignoring: !isEditing,
              child: ChunkAuthoringWorkspace(
                key: _workspaceKey,
                onDraftStateChanged: widget.onShellStateChanged,
                controller: widget.controller,
                onOpenOwningPrefab: widget.onOpenOwningPrefab,
                onPlayRequested: _requestPlay,
                playtestPlatformSupported: _platformSupportsPlaytest,
              ),
            ),
          ),
        ),
        if (!isEditing)
          Positioned.fill(
            child: AuthoredPlaytestOverlay(
              session: _playtest,
              subject: 'Chunk',
              keyPrefix: 'chunk_playtest',
              hostBuilder: widget.playtestHostBuilder,
              onRetry: _retryPreparation,
            ),
          ),
      ],
    );
  }

  Future<void> _requestPlay() async {
    if (locksEditorShell || _finalizingForPlay) return;
    if (!_platformSupportsPlaytest ||
        (_workspaceKey.currentState?.hasActiveOperation ?? true)) {
      _showPlaytestBlocked(
        _workspaceKey.currentState?.playtestReadiness.message ??
            'The Chunk workspace is not ready for Play.',
      );
      return;
    }
    _finalizingForPlay = true;
    _handlePlaytestChanged();
    final requestedController = widget.controller;
    final requestedWorkspace = widget.controller.workspacePath;
    var accepted = false;
    try {
      accepted =
          await _workspaceKey.currentState?.finalizeLocalEdits() ?? false;
    } finally {
      _finalizingForPlay = false;
      _handlePlaytestChanged();
    }
    if (!mounted || !accepted) return;
    if (!identical(requestedController, widget.controller) ||
        requestedWorkspace != widget.controller.workspacePath) {
      return;
    }
    final readiness = _workspaceKey.currentState?.playtestReadiness;
    if (readiness == null || !readiness.isReady) {
      _showPlaytestBlocked(
        readiness?.message ?? 'The Chunk workspace is not ready for Play.',
      );
      return;
    }
    final document = widget.controller.document;
    final selectedChunkKey = readiness.selectedChunkKey;
    if (document is! ChunkV2Document || selectedChunkKey == null) {
      _showPlaytestBlocked('The accepted Chunk-v2 document is unavailable.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await _playtest.prepare(
      source: document,
      isSourceCurrent: () =>
          mounted && identical(widget.controller.document, document),
      capture: () => captureChunkPlaytestPreparationInput(
        document: document,
        selectedChunkKey: selectedChunkKey,
        workspaceRoot: widget.controller.workspacePath,
      ),
      runner: widget.preparationRunner,
    );
  }

  void _retryPreparation() {
    _playtest.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_requestPlay());
    });
  }

  void _handlePlaytestChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onShellStateChanged?.call();
  }

  void _showPlaytestBlocked(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  bool handlePlaytestShortcut(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.f5 && !locksEditorShell) {
      unawaited(_requestPlay());
      return locksEditorShell;
    }
    return _playtest.handleShortcut(key);
  }

  @override
  void handlePlaytestAppLifecycleState(AppLifecycleState state) =>
      _playtest.handleAppLifecycleState(state);

  void _handleControllerChanged() {
    if (!mounted) return;
    _playtest.reconcileSource(widget.controller.document);
    setState(() {});
  }
}
