import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rpg_runner/playtest.dart';

import '../../../chunks/chunk_v2_models.dart';
import '../../../playtest/chunk_playtest_preparation.dart';
import '../../../session/editor_session_controller.dart';
import '../../../terrain_authoring/polygon_authoring_migration_required.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/polygon_authoring_migration_required_workspace.dart';
import 'v2/chunk_authoring_workspace.dart';

/// Builds the runtime host while keeping its implementation injectable in
/// editor widget tests.
typedef ChunkPlaytestHostBuilder =
    Widget Function({
      required ChunkPlaytestScenario scenario,
      required RunnerChunkPlaytestController controller,
      required AssetBundle assetBundle,
      required VoidCallback onStop,
    });

/// Resolves the read-only repository bundle for one captured workspace.
typedef ChunkPlaytestAssetBundleFactory =
    AssetBundle Function(String workspaceRoot);

enum _ChunkCreatorPlayMode { edit, preparing, playing, preparationFailed }

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
    this.preparationRunner = prepareChunkPlaytestInBackground,
    this.playtestHostBuilder = buildDefaultChunkPlaytestHost,
    this.assetBundleFactory = buildDefaultChunkPlaytestAssetBundle,
  });

  final EditorSessionController controller;

  /// Delegates placed-collision source navigation to the owning app shell.
  final ValueChanged<String>? onOpenOwningPrefab;

  /// Requests a shell-control rebuild after route-local lock state changes.
  final VoidCallback? onShellStateChanged;

  /// Optional platform override for tests; production defaults to Windows.
  final bool? playtestPlatformSupported;

  /// Pure preparation runner; production uses a background isolate.
  final ChunkPlaytestPreparationRunner preparationRunner;

  /// Runtime host factory; production mounts [RunnerChunkPlaytestHost].
  final ChunkPlaytestHostBuilder playtestHostBuilder;

  /// Read-only workspace bundle factory used after preparation succeeds.
  final ChunkPlaytestAssetBundleFactory assetBundleFactory;

  @override
  State<ChunkCreatorPage> createState() => _ChunkCreatorPageState();
}

class _ChunkCreatorPageState extends State<ChunkCreatorPage>
    implements
        EditorPageLocalDraftState,
        EditorPageSessionShortcutHandler,
        EditorPageReloadHandler,
        EditorPageApplyHandler,
        EditorPagePlaytestHandler {
  final GlobalKey<ChunkAuthoringWorkspaceState> _workspaceKey =
      GlobalKey<ChunkAuthoringWorkspaceState>();

  _ChunkCreatorPlayMode _playMode = _ChunkCreatorPlayMode.edit;
  int _preparationGeneration = 0;
  ChunkV2Document? _capturedDocument;
  ChunkPlaytestPreparationInput? _capturedInput;
  String? _capturedWorkspacePath;
  List<ChunkPlaytestPreparationIssue> _preparationIssues =
      const <ChunkPlaytestPreparationIssue>[];
  ChunkPlaytestScenario? _scenario;
  AssetBundle? _playtestAssetBundle;
  RunnerChunkPlaytestController? _playtestController;

  bool get _migrationRequired =>
      widget.controller.scene is PolygonAuthoringMigrationRequiredScene;

  bool get _platformSupportsPlaytest =>
      widget.playtestPlatformSupported ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

  @override
  bool get locksEditorShell => _playMode != _ChunkCreatorPlayMode.edit;

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
  bool get canApplyEditorPage =>
      !locksEditorShell &&
      !_migrationRequired &&
      (_workspaceKey.currentState?.canApplyToFiles ?? false);

  @override
  Future<void> applyEditorPage() async {
    if (locksEditorShell || _migrationRequired) return;
    await _workspaceKey.currentState?.applyToFiles();
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
    _cancelForContextChange();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _preparationGeneration += 1;
    final controller = _playtestController;
    _playtestController = null;
    if (controller != null) _retirePlaytestController(controller);
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
    final isEditing = _playMode == _ChunkCreatorPlayMode.edit;
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
                controller: widget.controller,
                onOpenOwningPrefab: widget.onOpenOwningPrefab,
                onPlayRequested: _requestPlay,
                playtestPlatformSupported: _platformSupportsPlaytest,
              ),
            ),
          ),
        ),
        if (!isEditing) Positioned.fill(child: _buildPlaytestBody()),
      ],
    );
  }

  Widget _buildPlaytestBody() => switch (_playMode) {
    _ChunkCreatorPlayMode.edit => const SizedBox.shrink(),
    _ChunkCreatorPlayMode.preparing => _ChunkPlaytestPreparationPanel(
      title: 'Preparing chunk playtest',
      detail:
          'Compiling the accepted in-memory document. No files are being '
          'written.',
      primaryLabel: null,
      onPrimary: null,
      onReturnToEdit: _stopPlaytest,
    ),
    _ChunkCreatorPlayMode.preparationFailed => _ChunkPlaytestPreparationPanel(
      title: 'Chunk playtest could not start',
      detail: _preparationIssues
          .map((issue) => '${issue.code}: ${issue.message}')
          .join('\n'),
      primaryLabel: 'Retry',
      onPrimary: _retryPreparation,
      onReturnToEdit: _stopPlaytest,
    ),
    _ChunkCreatorPlayMode.playing => _buildRuntimeHost(),
  };

  Widget _buildRuntimeHost() {
    final scenario = _scenario;
    final controller = _playtestController;
    final assetBundle = _playtestAssetBundle;
    if (scenario == null || controller == null || assetBundle == null) {
      return const _ChunkPlaytestPreparationPanel(
        title: 'Chunk playtest state is incomplete',
        detail: 'Return to Edit and prepare the scenario again.',
        primaryLabel: null,
        onPrimary: null,
        onReturnToEdit: null,
      );
    }
    final generation = _preparationGeneration;
    return widget.playtestHostBuilder(
      scenario: scenario,
      controller: controller,
      assetBundle: assetBundle,
      onStop: () => _handleRuntimeStopped(generation, controller),
    );
  }

  void _requestPlay() {
    if (_playMode != _ChunkCreatorPlayMode.edit) return;
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

    late final ChunkPlaytestPreparationInput input;
    try {
      input = captureChunkPlaytestPreparationInput(
        document: document,
        selectedChunkKey: selectedChunkKey,
      );
    } on ChunkPlaytestPreparationException catch (error) {
      _showPreparationFailure(
        document: document,
        issues: <ChunkPlaytestPreparationIssue>[
          ChunkPlaytestPreparationIssue(
            code: error.code,
            message: error.message,
          ),
        ],
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    _startPreparation(
      document: document,
      input: input,
      workspacePath: widget.controller.workspacePath,
    );
  }

  void _startPreparation({
    required ChunkV2Document document,
    required ChunkPlaytestPreparationInput input,
    required String workspacePath,
  }) {
    final generation = ++_preparationGeneration;
    _capturedDocument = document;
    _capturedInput = input;
    _capturedWorkspacePath = workspacePath;
    _preparationIssues = const <ChunkPlaytestPreparationIssue>[];
    _scenario = null;
    _playtestAssetBundle = null;
    _setPlayMode(_ChunkCreatorPlayMode.preparing);
    unawaited(
      _completePreparation(
        generation: generation,
        document: document,
        input: input,
        workspacePath: workspacePath,
      ),
    );
  }

  Future<void> _completePreparation({
    required int generation,
    required ChunkV2Document document,
    required ChunkPlaytestPreparationInput input,
    required String workspacePath,
  }) async {
    late final ChunkPlaytestPreparationResult result;
    try {
      result = await widget.preparationRunner(input);
    } on Object catch (error) {
      result = ChunkPlaytestPreparationResult.failure(
        <ChunkPlaytestPreparationIssue>[
          ChunkPlaytestPreparationIssue(
            code: 'chunk_playtest_preparation_failed',
            message: error.toString(),
          ),
        ],
      );
    }
    if (!_acceptsPreparationResult(generation, document)) return;
    final scenario = result.scenario;
    if (scenario == null) {
      _preparationIssues = result.issues;
      _setPlayMode(_ChunkCreatorPlayMode.preparationFailed);
      return;
    }

    late final AssetBundle assetBundle;
    try {
      assetBundle = widget.assetBundleFactory(workspacePath);
    } on Object catch (error) {
      final issue = error is RunnerWorkspaceAssetException
          ? ChunkPlaytestPreparationIssue(
              code: error.code,
              message: error.message,
            )
          : ChunkPlaytestPreparationIssue(
              code: 'chunk_playtest_asset_bundle_failed',
              message: error.toString(),
            );
      _preparationIssues = <ChunkPlaytestPreparationIssue>[issue];
      _setPlayMode(_ChunkCreatorPlayMode.preparationFailed);
      return;
    }
    if (!_acceptsPreparationResult(generation, document)) return;

    _scenario = scenario;
    _playtestAssetBundle = assetBundle;
    _playtestController = RunnerChunkPlaytestController();
    _setPlayMode(_ChunkCreatorPlayMode.playing);
  }

  bool _acceptsPreparationResult(int generation, ChunkV2Document document) =>
      mounted &&
      generation == _preparationGeneration &&
      _playMode == _ChunkCreatorPlayMode.preparing &&
      identical(_capturedDocument, document) &&
      identical(widget.controller.document, document);

  void _showPreparationFailure({
    required ChunkV2Document document,
    required List<ChunkPlaytestPreparationIssue> issues,
  }) {
    _preparationGeneration += 1;
    _capturedDocument = document;
    _capturedInput = null;
    _capturedWorkspacePath = widget.controller.workspacePath;
    _preparationIssues = issues;
    _setPlayMode(_ChunkCreatorPlayMode.preparationFailed);
  }

  void _retryPreparation() {
    final document = _capturedDocument;
    final input = _capturedInput;
    final workspacePath = _capturedWorkspacePath;
    if (document == null ||
        input == null ||
        workspacePath == null ||
        !identical(widget.controller.document, document)) {
      _returnToEdit();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestPlay();
      });
      return;
    }
    _startPreparation(
      document: document,
      input: input,
      workspacePath: workspacePath,
    );
  }

  bool _stopPlaytest() {
    switch (_playMode) {
      case _ChunkCreatorPlayMode.edit:
        return false;
      case _ChunkCreatorPlayMode.preparing ||
          _ChunkCreatorPlayMode.preparationFailed:
        _returnToEdit();
        return true;
      case _ChunkCreatorPlayMode.playing:
        final controller = _playtestController;
        if (controller == null) {
          _returnToEdit();
          return true;
        }
        controller.stop();
        return true;
    }
  }

  void _handleRuntimeStopped(
    int generation,
    RunnerChunkPlaytestController controller,
  ) {
    if (generation != _preparationGeneration ||
        !identical(controller, _playtestController)) {
      _retirePlaytestController(controller);
      return;
    }
    _playtestController = null;
    _returnToEdit();
    _retirePlaytestController(controller);
  }

  void _returnToEdit() {
    _preparationGeneration += 1;
    _capturedDocument = null;
    _capturedInput = null;
    _capturedWorkspacePath = null;
    _preparationIssues = const <ChunkPlaytestPreparationIssue>[];
    _scenario = null;
    _playtestAssetBundle = null;
    _setPlayMode(_ChunkCreatorPlayMode.edit);
  }

  void _cancelForContextChange() {
    if (_playMode == _ChunkCreatorPlayMode.edit) return;
    final controller = _playtestController;
    if (controller != null) {
      controller.stop();
    } else {
      _returnToEdit();
    }
  }

  void _setPlayMode(_ChunkCreatorPlayMode mode) {
    if (_playMode == mode) return;
    if (mounted) {
      setState(() => _playMode = mode);
    } else {
      _playMode = mode;
    }
    widget.onShellStateChanged?.call();
  }

  void _retirePlaytestController(RunnerChunkPlaytestController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  void _showPlaytestBlocked(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  bool handlePlaytestShortcut(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.f5) {
      if (_playMode == _ChunkCreatorPlayMode.edit) {
        _requestPlay();
        return _playMode != _ChunkCreatorPlayMode.edit;
      }
      return _stopPlaytest();
    }
    if (_playMode == _ChunkCreatorPlayMode.preparing ||
        _playMode == _ChunkCreatorPlayMode.preparationFailed) {
      return key == LogicalKeyboardKey.escape && _stopPlaytest();
    }
    if (_playMode != _ChunkCreatorPlayMode.playing) return false;
    final controller = _playtestController;
    if (controller == null) return false;
    if (key == LogicalKeyboardKey.escape) return _stopPlaytest();
    if (key == LogicalKeyboardKey.f6) return controller.restart();
    if (key == LogicalKeyboardKey.keyP) return controller.togglePause();
    if (key == LogicalKeyboardKey.enter) return controller.start();
    return false;
  }

  @override
  void handlePlaytestAppLifecycleState(AppLifecycleState state) {
    if (_playMode != _ChunkCreatorPlayMode.playing ||
        state == AppLifecycleState.resumed) {
      return;
    }
    _playtestController?.releaseFocus();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final capturedDocument = _capturedDocument;
    if (locksEditorShell &&
        capturedDocument != null &&
        !identical(widget.controller.document, capturedDocument)) {
      _cancelForContextChange();
      return;
    }
    setState(() {});
  }
}

/// Production host composition used by the Chunk Creator route.
Widget buildDefaultChunkPlaytestHost({
  required ChunkPlaytestScenario scenario,
  required RunnerChunkPlaytestController controller,
  required AssetBundle assetBundle,
  required VoidCallback onStop,
}) => RunnerChunkPlaytestHost(
  scenario: scenario,
  controller: controller,
  assetBundle: assetBundle,
  onStop: onStop,
);

/// Production read-only asset bundle composition for the captured workspace.
AssetBundle buildDefaultChunkPlaytestAssetBundle(String workspaceRoot) =>
    RunnerWorkspaceAssetBundle(workspaceRoot: workspaceRoot);

class _ChunkPlaytestPreparationPanel extends StatelessWidget {
  const _ChunkPlaytestPreparationPanel({
    required this.title,
    required this.detail,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onReturnToEdit,
  });

  final String title;
  final String detail;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onReturnToEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B1118),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    key: const ValueKey<String>('chunk_playtest_state_title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail,
                    key: const ValueKey<String>('chunk_playtest_state_detail'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      if (primaryLabel != null)
                        FilledButton(
                          key: const ValueKey<String>(
                            'chunk_playtest_retry_button',
                          ),
                          onPressed: onPrimary,
                          child: Text(primaryLabel!),
                        ),
                      if (onReturnToEdit != null)
                        OutlinedButton(
                          key: const ValueKey<String>(
                            'chunk_playtest_return_button',
                          ),
                          onPressed: onReturnToEdit,
                          child: const Text('Return to Edit'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
