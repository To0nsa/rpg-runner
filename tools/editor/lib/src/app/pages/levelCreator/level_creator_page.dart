import 'package:runner_core/collision/terrain/terrain_boundary_signature.dart';

import '../../../chunks/chunk_domain_plugin.dart';
import '../../../chunks/chunk_v2_models.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:runner_core/track/chunk_pattern_tier.dart';

import '../../../chunks/chunk_domain_models.dart';
import '../../../chunks/chunk_v2_file_data.dart';
import '../../../domain/authoring_identifiers.dart';
import '../../../domain/authoring_types.dart';
import '../../../levels/level_domain_models.dart';
import '../../../levels/level_domain_plugin.dart';
import '../../../parallax/parallax_domain_models.dart';
import '../../../playtest/authored_playtest_preparation.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_page_navigation_state.dart';
import '../shared/authored_playtest_session.dart';
import '../parallaxEditor/widgets/parallax_preview_view.dart';
import '../shared/editor_workspace_card.dart';
import '../chunkCreator/v2/chunk_composition_preview.dart';
import '../shared/editor_three_panel_layout.dart';
import '../shared/editor_panel_card.dart';
import 'level_appearance.dart';
import 'level_contents.dart';
import 'level_content_projection.dart';
import 'level_creation_form.dart';
import 'level_creator_navigation.dart';
import 'level_diagnostics.dart';
import 'level_flow.dart';
import 'level_inspector.dart';
import 'level_library.dart';
import 'level_sample_preview.dart';
import '../chunkCreator/v2/chunk_connections_panel.dart';
import 'level_view_preferences.dart';

class LevelCreatorPage extends StatefulWidget {
  const LevelCreatorPage({
    super.key,
    required this.controller,
    this.onOpenInParallax,
    this.onShellStateChanged,
    this.onOpenChunk,
    this.onRepairDependency,
    this.initialReturnContext,
    this.contentLoader = loadLevelContentProjection,
    this.playtestPlatformSupported,
    this.preparationRunner = preparePlaytestInBackground,
    this.playtestHostBuilder = buildDefaultAuthoredPlaytestHost,
    this.viewStore = const LevelCreatorViewStore.local(),
  });

  final EditorSessionController controller;
  final ValueChanged<ParallaxLevelTarget>? onOpenInParallax;
  final VoidCallback? onShellStateChanged;
  final Future<bool> Function(LevelCreatorChunkTarget target)? onOpenChunk;
  final Future<bool> Function(String pluginId)? onRepairDependency;
  final LevelCreatorReturnContext? initialReturnContext;
  final LevelContentProjectionLoader contentLoader;
  final bool? playtestPlatformSupported;
  final PlaytestPreparationRunner preparationRunner;
  final AuthoredPlaytestHostBuilder playtestHostBuilder;
  final LevelCreatorViewStore? viewStore;

  @override
  State<LevelCreatorPage> createState() => _LevelCreatorPageState();
}

class _LevelCreatorPageState extends State<LevelCreatorPage>
    implements
        EditorPageLocalDraftState,
        EditorPageSessionShortcutHandler,
        EditorPageSaveHandler,
        EditorPageReloadHandler,
        EditorPagePendingChangesSummary,
        EditorPagePlaytestHandler,
        EditorPageNavigationState {
  final TextEditingController _newLevelNameController = TextEditingController();
  final TextEditingController _newLevelIdController = TextEditingController();
  final TextEditingController _newVisualThemeIdController =
      TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _visualThemeIdController =
      TextEditingController();
  final TextEditingController _cameraCenterYController =
      TextEditingController();
  final TextEditingController _groundTopYController = TextEditingController();
  final TextEditingController _terrainHeightStepController =
      TextEditingController();
  final TextEditingController _earlyPatternChunksController =
      TextEditingController();
  final TextEditingController _easyPatternChunksController =
      TextEditingController();
  final TextEditingController _normalPatternChunksController =
      TextEditingController();
  final TextEditingController _noEnemyChunksController =
      TextEditingController();
  final TextEditingController _enumOrdinalController = TextEditingController();
  final TextEditingController _newChunkThemeGroupIdController =
      TextEditingController();
  final TextEditingController _segmentIdController = TextEditingController();
  final TextEditingController _segmentGroupIdController =
      TextEditingController();
  final TextEditingController _segmentMinChunkCountController =
      TextEditingController();
  final TextEditingController _segmentMaxChunkCountController =
      TextEditingController();

  final TextEditingController _librarySearch = TextEditingController();
  final TextEditingController _chunkSearch = TextEditingController();
  LevelCreatorTab _workspaceTab = LevelCreatorTab.contents;
  String? _selectedChunkKey;
  String? _groupFilter;
  bool _showLevelSettings = true;
  bool _creationDialogOpen = false;
  bool _restoredReturnContext = false;
  bool _restoredReturnSelection = false;
  LevelCreatorReturnContext? _initialViewContext;
  bool _restoringView = true;
  int _viewRequest = 0;
  String? _lastPersistedView;
  String? _viewRestoreNotice;
  int _previewSeed = 4401;
  final TextEditingController _previewSeedController = TextEditingController(
    text: '4401',
  );
  String? _previewSeedError;
  final AuthoredPlaytestSession _playtest = AuthoredPlaytestSession();
  final EditorThreePanelController _panelController =
      EditorThreePanelController();
  String? _diagnosticFieldKey;
  bool _showSample = false;
  bool _preparingSample = false;
  int _sampleGeneration = 0;
  LevelPlaytestScenario? _sampleScenario;
  Object? _sampleDocument;
  int _sampleContentRequest = -1;
  List<PlaytestPreparationIssue> _sampleIssues = const [];
  int _contentRequest = 0;
  int _seenSourceGeneration = -1;
  bool _loadingContent = false;
  LevelContentProjection? _content;
  ChunkV2Scene? _connectionScene;
  LevelDef? _connectionLevel;
  String? _contentError;

  String? _selectedLevelId;
  int _selectionRequestRevision = 0;
  bool _assemblyLoopSegments = true;
  List<String> _chunkThemeGroupsDraft = const <String>[
    defaultLevelChunkThemeGroupId,
  ];
  List<LevelAssemblySegmentDef> _assemblySegmentsDraft =
      const <LevelAssemblySegmentDef>[];
  int? _selectedAssemblySegmentIndex;
  bool _selectedSegmentRequireDistinct = true;
  NewLevelThemeMode _newLevelThemeMode = NewLevelThemeMode.copy;
  String? _copyLevelSourceId;
  bool _copySectionDesign = false;
  String? _selectedExistingThemeId;
  String? _createThemeDialogDraftId;
  bool _createThemeDialogOpen = false;
  List<String> _cleanupRequiredPaths = const <String>[];

  // The captured accepted value distinguishes user input from a newly arrived
  // undo/reload document. Comparing text against the live scene cannot do that.
  LevelDef? _inspectorBaseline;
  bool _syncingInput = false;
  bool _applyingInput = false;
  bool _resolvingTransition = false;
  bool _shellNotificationQueued = false;
  String? _lastShellStatus;
  final Map<String, String> _inputErrors = <String, String>{};
  final Map<String, FocusNode> _inputFocus = <String, FocusNode>{};

  Map<String, TextEditingController> get _levelInputs =>
      <String, TextEditingController>{
        'displayName': _displayNameController,
        'visualThemeId': _visualThemeIdController,
        'cameraCenterY': _cameraCenterYController,
        'groundTopY': _groundTopYController,
        'terrainHeightStepPx': _terrainHeightStepController,
        'earlyPatternChunks': _earlyPatternChunksController,
        'easyPatternChunks': _easyPatternChunksController,
        'normalPatternChunks': _normalPatternChunksController,
        'noEnemyChunks': _noEnemyChunksController,
        'enumOrdinal': _enumOrdinalController,
      };

  Map<String, TextEditingController> get _segmentInputs =>
      <String, TextEditingController>{
        'segmentId': _segmentIdController,
        'groupId': _segmentGroupIdController,
        'minChunkCount': _segmentMinChunkCountController,
        'maxChunkCount': _segmentMaxChunkCountController,
      };

  Iterable<TextEditingController> get _allInputControllers =>
      <TextEditingController>[
        ..._levelInputs.values,
        ..._segmentInputs.values,
        _newLevelNameController,
        _newLevelIdController,
        _newVisualThemeIdController,
        _newChunkThemeGroupIdController,
      ];

  bool get _hasCreateDraft =>
      _newLevelNameController.text.isNotEmpty ||
      _newLevelIdController.text.isNotEmpty ||
      _newVisualThemeIdController.text.isNotEmpty ||
      _createThemeDialogOpen ||
      _createThemeDialogDraftId != null;

  bool get _hasInspectorDraft {
    final baseline = _inspectorBaseline;
    if (baseline == null) {
      return _levelInputs.values.any((input) => input.text.isNotEmpty);
    }
    final expected = _levelText(baseline);
    return _levelInputs.entries.any(
          (entry) => entry.value.text != expected[entry.key],
        ) ||
        _newChunkThemeGroupIdController.text.isNotEmpty ||
        !_stringListEquals(_chunkThemeGroupsDraft, baseline.chunkThemeGroups) ||
        _assemblyDraftDiffersFromLevel(baseline) ||
        _segmentInputDiffers;
  }

  bool get _segmentInputDiffers {
    final segment = _selectedAssemblySegment;
    if (segment == null) {
      return _segmentInputs.values.any((input) => input.text.isNotEmpty);
    }
    return _segmentIdController.text != segment.segmentId ||
        _segmentGroupIdController.text != segment.groupId ||
        _segmentMinChunkCountController.text != '${segment.minChunkCount}' ||
        _segmentMaxChunkCountController.text != '${segment.maxChunkCount}';
  }

  @override
  bool get hasLocalDraftChanges => _hasCreateDraft || _hasInspectorDraft;

  @override
  List<String> get pendingChangeDescriptions {
    final document = widget.controller.document;
    if (document is! LevelDefsDocument) return const <String>[];
    final ids = <String>{...widget.controller.dirtyItemIds};
    if (_hasInspectorDraft && _inspectorBaseline != null) {
      ids.add('level:${_inspectorBaseline!.levelId}');
    }
    final descriptions = <String>[];
    for (final id in ids.toList()..sort()) {
      if (id.startsWith('level:')) {
        final levelId = id.substring('level:'.length);
        final level = findLevelDefById(document.levels, levelId);
        final name =
            levelId == _inspectorBaseline?.levelId &&
                _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : level?.displayName ?? levelId;
        descriptions.add('Level: $name');
      } else if (id.startsWith('parallaxTheme:')) {
        descriptions.add(
          'Background: ${id.substring('parallaxTheme:'.length)}',
        );
      }
    }
    if (_hasCreateDraft) {
      descriptions.add('New level: ${_newLevelNameController.text.trim()}');
    }
    return List<String>.unmodifiable(descriptions);
  }

  @override
  String get pendingChangesSummary {
    final descriptions = pendingChangeDescriptions;
    final levels = descriptions
        .where(
          (entry) =>
              entry.startsWith('Level:') || entry.startsWith('New level:'),
        )
        .length;
    final backgrounds = descriptions
        .where((entry) => entry.startsWith('Background:'))
        .length;
    final parts = <String>[
      if (levels > 0) '$levels level${levels == 1 ? '' : 's'}',
      if (backgrounds > 0)
        '$backgrounds background${backgrounds == 1 ? '' : 's'}',
    ];
    return parts.isEmpty
        ? 'No unsaved changes'
        : '${parts.join(' and ')} ${levels + backgrounds == 1 ? 'has' : 'have'} changes';
  }

  @override
  bool get canHandleUndoSessionShortcut =>
      !locksEditorShell && (widget.controller.canUndo || _hasInspectorDraft);

  @override
  bool get canHandleRedoSessionShortcut =>
      !locksEditorShell && widget.controller.canRedo;

  @override
  bool handleUndoSessionShortcut() {
    if (!canHandleUndoSessionShortcut || _resolvingTransition) return false;
    unawaited(_resolveHistory(redo: false));
    return true;
  }

  @override
  bool handleRedoSessionShortcut() {
    if (!canHandleRedoSessionShortcut || _resolvingTransition) return false;
    unawaited(_resolveHistory(redo: true));
    return true;
  }

  Future<void> _resolveHistory({required bool redo}) async {
    if (!await _resolveInspectorBeforeTransition() || !mounted) return;
    _invalidateHandoff();
    redo ? widget.controller.redo() : widget.controller.undo();
  }

  @override
  bool get canSaveEditorPage => !locksEditorShell && _canSaveSources;

  @override
  Future<EditorPageSaveResult> saveEditorPage() async {
    if (locksEditorShell ||
        widget.controller.isLoading ||
        widget.controller.isExporting ||
        widget.controller.requiresSavedRefresh ||
        widget.controller.requiresTransactionRecovery ||
        _cleanupRequiredPaths.isNotEmpty) {
      return EditorPageSaveResult.blocked;
    }
    if (!_flushInspectorEdits()) return EditorPageSaveResult.blocked;
    if (_hasCreateDraft) {
      if (_createThemeDialogOpen || _createThemeDialogDraftId != null) {
        _showSnackBar('Finish or cancel the background dialog before saving.');
        return EditorPageSaveResult.blocked;
      }
      _createLevel();
      if (_hasCreateDraft) return EditorPageSaveResult.blocked;
    }
    return _saveSources();
  }

  @override
  bool get canReloadEditorPage =>
      !locksEditorShell &&
      !widget.controller.isLoading &&
      !widget.controller.isExporting;

  @override
  Future<void> reloadEditorPage() async {
    if (!canReloadEditorPage) return;
    await widget.controller.loadWorkspace();
    if (!mounted || widget.controller.loadError != null) return;
    final scene = widget.controller.scene;
    if (scene is! LevelScene) return;
    _bindInspector(scene.activeLevel);
    _resetNewLevelForm(scene);
    setState(() {
      _createThemeDialogDraftId = null;
      _invalidateHandoff();
    });
    await _refreshContent();
    _notifyShellState();
  }

  @override
  bool get locksEditorShell => _playtest.locksEditor;

  String? get _playtestUnavailableReason {
    final supported =
        widget.playtestPlatformSupported ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);
    if (!supported) return 'Play is available in the Windows editor.';
    if (widget.controller.isLoading ||
        widget.controller.isExporting ||
        _loadingContent) {
      return 'Wait for the workspace operation to finish.';
    }
    if (widget.controller.requiresSavedRefresh ||
        widget.controller.requiresTransactionRecovery) {
      return 'Complete source recovery before starting Play.';
    }
    if (widget.controller.scene is! LevelScene ||
        (widget.controller.scene as LevelScene).activeLevel == null) {
      return 'Create or select a level first.';
    }
    return null;
  }

  bool _acceptPreviewSeed() {
    final seed = int.tryParse(_previewSeedController.text.trim());
    setState(
      () => _previewSeedError = seed == null || seed <= 0
          ? 'Enter a positive whole number.'
          : null,
    );
    if (seed == null || seed <= 0) return false;
    _previewSeed = seed;
    return true;
  }

  Future<void> _requestPlaytest() async {
    if (locksEditorShell) return;
    final reason = _playtestUnavailableReason;
    if (reason != null) {
      _showSnackBar(reason);
      return;
    }
    if (!_flushInspectorEdits() || !_acceptPreviewSeed()) return;
    final document = widget.controller.document;
    if (document is! LevelDefsDocument) return;
    final levelId = _selectedLevelId;
    if (levelId == null) return;
    final blocking = widget.controller.issues.where(
      (issue) =>
          issue.blocks(AuthoringOperation.play) &&
          (issue.ownerKey == null || issue.ownerKey == levelId),
    );
    if (blocking.isNotEmpty) {
      _showDiagnostics();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await _playtest.prepare(
      source: document,
      isSourceCurrent: () =>
          mounted &&
          !widget.controller.isLoading &&
          identical(widget.controller.document, document),
      capture: () => captureLevelPlaytestPreparationInput(
        document: document,
        levelId: levelId,
        workspaceRoot: widget.controller.workspacePath,
        contentDocument: _content?.document,
        seed: _previewSeed,
      ),
      runner: widget.preparationRunner,
    );
  }

  void _retryPlaytest() {
    _playtest.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_requestPlaytest());
    });
  }

  Future<void> _prepareSample() async {
    if (_preparingSample || !_flushInspectorEdits() || !_acceptPreviewSeed()) {
      return;
    }
    final document = widget.controller.document;
    final levelId = _selectedLevelId;
    if (document is! LevelDefsDocument || levelId == null || _content == null) {
      return;
    }
    final generation = ++_sampleGeneration;
    final content = _content;
    final seed = _previewSeed;
    final contentRequest = _contentRequest;
    setState(() {
      _showSample = true;
      _preparingSample = true;
      _sampleIssues = const [];
    });
    PlaytestPreparationResult result;
    try {
      final input = await captureLevelPlaytestPreparationInput(
        document: document,
        levelId: levelId,
        workspaceRoot: widget.controller.workspacePath,
        contentDocument: content?.document,
        seed: seed,
      );
      if (!mounted || generation != _sampleGeneration) return;
      result = await widget.preparationRunner(input);
    } on Object catch (error) {
      result = PlaytestPreparationResult.failure([
        PlaytestPreparationIssue(
          code: 'level_sample_preparation_failed',
          message: error.toString(),
        ),
      ]);
    }
    if (!mounted || generation != _sampleGeneration) return;
    setState(() {
      _preparingSample = false;
      _sampleDocument = document;
      _sampleContentRequest = contentRequest;
      _sampleScenario = result.scenario is LevelPlaytestScenario
          ? result.scenario as LevelPlaytestScenario
          : null;
      _sampleIssues = result.issues;
    });
  }

  Widget _buildSamplePreview() {
    if (_preparingSample) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!identical(_sampleDocument, widget.controller.document) ||
        _sampleContentRequest != _contentRequest ||
        _hasInspectorDraft ||
        (_sampleScenario != null &&
            _sampleScenario!.seed.toString() !=
                _previewSeedController.text.trim())) {
      return Center(
        child: FilledButton.tonal(
          onPressed: () => unawaited(_prepareSample()),
          child: const Text('Update sample from current edits'),
        ),
      );
    }
    final scenario = _sampleScenario;
    if (scenario == null) {
      return ListView(
        children: [
          const Text('This level cannot be sampled yet.'),
          for (final issue in _sampleIssues)
            ListTile(
              title: Text(issue.message),
              subtitle: Text(issue.sourcePath ?? issue.code),
              trailing:
                  levelDependencyPluginForPath(issue.sourcePath) != null &&
                      widget.onRepairDependency != null
                  ? TextButton(
                      onPressed: () => widget.onRepairDependency!(
                        levelDependencyPluginForPath(issue.sourcePath)!,
                      ),
                      child: const Text('Repair'),
                    )
                  : null,
            ),
        ],
      );
    }
    return LevelSamplePreview(
      scenario: scenario,
      joinedPreviewBuilder: (leftKey, rightKey) {
        final scene = _connectionScene;
        final left = scene?.chunks
            .where((chunk) => chunk.chunkKey == leftKey)
            .firstOrNull;
        final right = scene?.chunks
            .where((chunk) => chunk.chunkKey == rightKey)
            .firstOrNull;
        return scene == null || left == null || right == null
            ? const Icon(Icons.image_not_supported_outlined)
            : ChunkConnectionPreview(
                left: left,
                right: right,
                scene: scene,
                workspaceRootPath: widget.controller.workspacePath,
              );
      },
      sourceName: (key) =>
          _content?.document.chunks
              .where((chunk) => chunk.chunkKey == key)
              .firstOrNull
              ?.chunkKey ??
          key,
      previewBuilder: (key) {
        final chunk = _content?.document.chunks
            .where((chunk) => chunk.chunkKey == key)
            .firstOrNull;
        return chunk == null
            ? const Icon(Icons.image_not_supported_outlined)
            : _chunkPreview(chunk);
      },
      onSelected: (key) => unawaited(_selectChunk(key)),
    );
  }

  void _handlePlaytestChanged() {
    if (!mounted) return;
    setState(() {});
    _notifyShellState();
  }

  @override
  bool handlePlaytestShortcut(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.f5 && !locksEditorShell) {
      unawaited(_requestPlaytest());
      return locksEditorShell;
    }
    return _playtest.handleShortcut(key);
  }

  @override
  void handlePlaytestAppLifecycleState(AppLifecycleState state) =>
      _playtest.handleAppLifecycleState(state);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReturnContext;
    _initialViewContext = initial;
    if (initial != null) {
      _workspaceTab = initial.tab;
      _selectedChunkKey = initial.selectedChunkKey;
      _groupFilter = initial.groupFilter;
      _previewSeed = initial.previewSeed;
      _librarySearch.text = initial.librarySearch;
      _chunkSearch.text = initial.chunkSearch;
      _showLevelSettings = initial.showLevelSettings;
    }
    _previewSeedController.text = '$_previewSeed';
    _playtest.addListener(_handlePlaytestChanged);
    _librarySearch.addListener(_handlePresentationChanged);
    _chunkSearch.addListener(_handlePresentationChanged);
    widget.controller.addListener(_handleControllerChanged);
    for (final input in _allInputControllers) {
      input.addListener(_handleInputChanged);
    }
    for (final key in <String>[
      ..._levelInputs.keys,
      ..._segmentInputs.keys,
      'requireDistinctChunks',
      'difficulty',
    ]) {
      final node = FocusNode(debugLabel: 'Level $key');
      node.addListener(() {
        if (!node.hasFocus &&
            !_syncingInput &&
            !_resolvingTransition &&
            mounted) {
          _flushInspectorEdits(reportErrors: false);
        }
      });
      _inputFocus[key] = node;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final request = ++_viewRequest;
      final saved =
          widget.initialReturnContext ??
          await widget.viewStore?.read(widget.controller.workspacePath);
      if (!mounted || request != _viewRequest) return;
      _initialViewContext = saved;
      if (saved != null) {
        _workspaceTab = saved.tab;
        _selectedChunkKey = saved.selectedChunkKey;
        _groupFilter = saved.groupFilter;
        _previewSeed = saved.previewSeed;
        _previewSeedController.text = '$_previewSeed';
      }
      _restoringView = false;
      if (widget.controller.document is LevelDefsDocument) {
        _handleControllerChanged();
      } else {
        await widget.controller.loadWorkspace();
      }
    });
  }

  @override
  void didUpdateWidget(covariant LevelCreatorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _playtest.stop();
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      final scene = widget.controller.scene;
      _bindInspector(scene is LevelScene ? scene.activeLevel : null);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _playtest.removeListener(_handlePlaytestChanged);
    _playtest.dispose();
    _panelController.dispose();
    _previewSeedController.dispose();
    _contentRequest += 1;
    _sampleGeneration++;
    _viewRequest++;
    _librarySearch.dispose();
    _chunkSearch.dispose();
    for (final input in _allInputControllers) {
      input.removeListener(_handleInputChanged);
    }
    for (final node in _inputFocus.values) {
      node.dispose();
    }
    _newLevelIdController.dispose();
    _newLevelNameController.dispose();
    _newVisualThemeIdController.dispose();
    _displayNameController.dispose();
    _visualThemeIdController.dispose();
    _cameraCenterYController.dispose();
    _groundTopYController.dispose();
    _terrainHeightStepController.dispose();
    _earlyPatternChunksController.dispose();
    _easyPatternChunksController.dispose();
    _normalPatternChunksController.dispose();
    _noEnemyChunksController.dispose();
    _enumOrdinalController.dispose();
    _newChunkThemeGroupIdController.dispose();
    _segmentIdController.dispose();
    _segmentGroupIdController.dispose();
    _segmentMinChunkCountController.dispose();
    _segmentMaxChunkCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = !locksEditorShell;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !editing,
          child: TickerMode(
            enabled: editing,
            child: ExcludeFocus(
              excluding: !editing,
              child: _buildEditorWorkspace(),
            ),
          ),
        ),
        if (!editing)
          Positioned.fill(
            child: AuthoredPlaytestOverlay(
              session: _playtest,
              subject: 'Level',
              keyPrefix: 'level_playtest',
              onRetry: _retryPlaytest,
              hostBuilder: widget.playtestHostBuilder,
            ),
          ),
      ],
    );
  }

  Widget _buildEditorWorkspace() {
    if (_restoringView) return const Center(child: CircularProgressIndicator());
    final scene = widget.controller.scene;
    if (scene is! LevelScene) {
      return Center(
        child: widget.controller.isLoading
            ? const CircularProgressIndicator()
            : Text(
                widget.controller.loadError ?? 'Level source is not loaded.',
              ),
      );
    }
    final level = _viewRestoreNotice == null ? scene.activeLevel : null;
    return EditorWorkspaceCard(
      child: Column(
        children: [
          if (widget.controller.loadError != null)
            Text(widget.controller.loadError!),
          if (widget.controller.exportError != null)
            Text(widget.controller.exportError!),
          if (_viewRestoreNotice != null) Text(_viewRestoreNotice!),
          Expanded(
            child: EditorThreePanelLayout(
              controller: _panelController,
              key: const ValueKey<String>('level_workspace_layout'),
              firstLabel: 'Levels',
              secondLabel: 'Workspace',
              thirdLabel: 'Settings',
              firstFlex: 3,
              secondFlex: 8,
              thirdFlex: 4,
              minimumWideWidth: 1180,
              first: LevelLibrary(
                levels: scene.levels,
                selectedLevelId: _viewRestoreNotice == null
                    ? scene.activeLevelId
                    : null,
                dirtyItemIds: <String>{
                  ...widget.controller.dirtyItemIds,
                  if (_hasInspectorDraft && _selectedLevelId != null)
                    'level:$_selectedLevelId',
                },
                searchController: _librarySearch,
                onSelected: (id) => unawaited(_selectLevel(id)),
                onCreate: () => unawaited(_showCreateLevelDialog()),
                previewBuilder: _previewForLevel,
                countFor: (id) => _content?.activeCount(id),
              ),
              second: level == null
                  ? _emptyLevelWorkspace()
                  : _buildLevelWorkspace(scene, level),
              third: level == null
                  ? const Center(child: Text('Create or select a level.'))
                  : _buildSettings(level),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: const ValueKey<String>('level_diagnostics_button'),
                onPressed: () => _showDiagnostics(),
                icon: Icon(
                  widget.controller.errorCount == 0
                      ? Icons.fact_check_outlined
                      : Icons.error_outline,
                ),
                label: Text(
                  '${widget.controller.errorCount} issues · ${widget.controller.warningCount} suggestions',
                ),
              ),
              TextButton.icon(
                onPressed: _showChanges,
                icon: const Icon(Icons.difference_outlined),
                label: const Text('Review changes'),
              ),
              if (_cleanupRequiredPaths.isNotEmpty)
                const Text('Sources saved; transaction cleanup required'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyLevelWorkspace() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.landscape_outlined, size: 40),
        const SizedBox(height: 12),
        const Text('Create a level to start authoring its content and flow.'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => unawaited(_showCreateLevelDialog()),
          child: const Text('New level'),
        ),
      ],
    ),
  );

  Widget _buildLevelWorkspace(LevelScene scene, LevelDef level) {
    final chunks =
        _content?.chunksFor(level.levelId) ?? const <ChunkV2FileData>[];
    final selectedChunk = _previewChunk(level.levelId);
    final document = widget.controller.document as LevelDefsDocument;
    final themeId = _visualThemeIdController.text.trim();
    final themes =
        document.parallaxDocument?.themes ?? const <ParallaxThemeDef>[];
    final workspace = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                level.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Level settings',
              onPressed: () => unawaited(_showLevelInspector()),
              icon: const Icon(Icons.tune),
            ),
            PopupMenuButton<String>(
              tooltip: 'Level actions',
              onSelected: (action) {
                if (action == 'copy') {
                  unawaited(_showCreateLevelDialog(copySource: level));
                }
                if (action == 'status') {
                  level.status == levelStatusActive
                      ? _deprecateActiveLevel()
                      : _reactivateActiveLevel();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'copy',
                  child: Text('Copy level settings'),
                ),
                PopupMenuItem(
                  value: 'status',
                  child: Text(
                    level.status == levelStatusActive
                        ? 'Deprecate'
                        : 'Reactivate',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Tooltip(
              message: _playtestUnavailableReason ?? 'Play level — seeded run from current edits. F5 Play/Stop · F6 Restart · P Pause · Enter Start',
              child: FilledButton.icon(
                key: const ValueKey<String>('level_play_button'),
                onPressed: _playtestUnavailableReason == null
                    ? () => unawaited(_requestPlaytest())
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
            ),
            SizedBox(
              width: 140,
              child: TextField(
                key: const ValueKey<String>('level_preview_seed'),
                controller: _previewSeedController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Preview seed',
                  isDense: true,
                  errorText: _previewSeedError,
                ),
                onSubmitted: (_) => _acceptPreviewSeed(),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('level_sample_button'),
              onPressed: _preparingSample
                  ? null
                  : () => unawaited(_prepareSample()),
              icon: const Icon(Icons.view_carousel_outlined),
              label: const Text('Sample run'),
            ),
            if (_showSample)
              TextButton(
                onPressed: () => setState(() => _showSample = false),
                child: const Text('Show chunk'),
              ),
            TextButton(
              key: const ValueKey('level_new_variation'),
              onPressed: _preparingSample
                  ? null
                  : () {
                      _previewSeedController.text = '${_previewSeed + 1}';
                      unawaited(_prepareSample());
                    },
              child: const Text('New variation'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Flexible(
          flex: 4,
          child: EditorPanelCard(
            key: const ValueKey<String>('level_persistent_preview'),
            title: _showSample
                ? 'Sampled run'
                : selectedChunk == null
                ? 'Level preview'
                : 'Chunk preview · ${selectedChunk.chunkKey}',
            bodyMode: EditorPanelBodyMode.expanded,
            trailing: IconButton(
              tooltip: 'Refresh content',
              onPressed: _loadingContent
                  ? null
                  : () => unawaited(_refreshContent()),
              icon: const Icon(Icons.refresh),
            ),
            child: _showSample
                ? _buildSamplePreview()
                : _loadingContent && _content == null
                ? const Center(child: CircularProgressIndicator())
                : _contentError != null
                ? Center(
                    child: Text('Content preview unavailable. $_contentError'),
                  )
                : selectedChunk == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No chunks yet. Add a starter or create a chunk.',
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: widget.onOpenChunk == null
                              ? null
                              : () => unawaited(
                                  _openChunk(
                                    LevelCreatorChunkIntent.flatStarter,
                                  ),
                                ),
                          child: const Text('Add flat starter'),
                        ),
                      ],
                    ),
                  )
                : _chunkPreview(selectedChunk, themeId: themeId),
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<LevelCreatorTab>(
          key: const ValueKey<String>('level_workspace_tabs'),
          segments: const [
            ButtonSegment(
              value: LevelCreatorTab.contents,
              icon: Icon(Icons.grid_view),
              label: Text('Contents'),
            ),
            ButtonSegment(
              value: LevelCreatorTab.flow,
              icon: Icon(Icons.view_timeline_outlined),
              label: Text('Flow'),
            ),
            ButtonSegment(
              value: LevelCreatorTab.appearance,
              icon: Icon(Icons.layers_outlined),
              label: Text('Appearance'),
            ),
          ],
          selected: {_workspaceTab},
          showSelectedIcon: false,
          onSelectionChanged: (values) => unawaited(_selectTab(values.single)),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 5,
          child: IndexedStack(
            index: _workspaceTab.index,
            children: [
              LevelContents(
                chunks: chunks,
                groups: _chunkThemeGroupsDraft,
                groupFilter: _groupFilter,
                selectedChunkKey: _selectedChunkKey,
                firstChunkKey: level.firstChunkKey,
                searchController: _chunkSearch,
                onFilter: (group) {
                  setState(() => _groupFilter = group);
                  _persistView();
                },
                onSelected: (key) => unawaited(_selectChunk(key)),
                onAddGroup: () => unawaited(_showAddGroupDialog()),
                onRemoveGroup: (group) => unawaited(
                  _changeAssemblyStructure(
                    () => _removeChunkThemeGroup(scene, group),
                  ),
                ),
                onAddChunk: widget.onOpenChunk == null
                    ? null
                    : () =>
                          unawaited(_openChunk(LevelCreatorChunkIntent.create)),
                onEditChunk: widget.onOpenChunk == null
                    ? null
                    : (chunk) => unawaited(
                        _openChunk(LevelCreatorChunkIntent.edit, chunk: chunk),
                      ),
                onAssignChunk: widget.onOpenChunk == null
                    ? null
                    : (chunk) => unawaited(
                        _openChunk(
                          LevelCreatorChunkIntent.assignGroup,
                          chunk: chunk,
                        ),
                      ),
                previewBuilder: _chunkPreview,
              ),
              LevelFlow(
                connectionIssues: _connectionScene?.seamAnalysis.issues,
                onInspectConnection: (issue) =>
                    unawaited(_inspectConnection(issue)),
                onCreateConnection: (issue) =>
                    unawaited(_createConnectionForIssue(issue)),
                level: level,
                chunks: chunks,
                segments: _assemblySegmentsDraft,
                selectedSegmentId: _selectedAssemblySegment?.segmentId,
                loopSegments: _assemblyLoopSegments,
                onModeChanged: (ordered) =>
                    unawaited(_changeSelectionMode(ordered)),
                onSelected: (index) => unawaited(_selectAssemblySegment(index)),
                onAdd: () => unawaited(
                  _changeAssemblyStructure(() => _addAssemblySegment(scene)),
                ),
                onReorder: (oldIndex, newIndex) =>
                    unawaited(_reorderSections(oldIndex, newIndex)),
                onLoopChanged: (value) {
                  setState(() {
                    _assemblyLoopSegments = value;
                    _invalidateHandoff();
                  });
                  _flushInspectorEdits();
                },
                previewForGroup: (group) {
                  final chunk = chunks
                      .where((chunk) => chunk.assemblyGroupId == group)
                      .firstOrNull;
                  return chunk == null
                      ? const Icon(Icons.grid_view_outlined)
                      : _chunkPreview(chunk);
                },
              ),
              LevelAppearance(
                themeId: themeId,
                themes: themes,
                usedByNames: scene.levels
                    .where((candidate) => candidate.visualThemeId == themeId)
                    .map((candidate) => candidate.displayName)
                    .toList(growable: false),
                onThemeSelected: (id) {
                  _visualThemeIdController.text = id;
                  _flushInspectorEdits();
                },
                onCreateTheme: () => unawaited(
                  _showCreateAndAssignThemeDialog(
                    scene,
                    initialThemeId:
                        themes.any((theme) => theme.parallaxThemeId == themeId)
                        ? null
                        : themeId,
                  ),
                ),
                onEditTheme: widget.onOpenInParallax == null
                    ? null
                    : () => unawaited(_openBackground()),
                onCopyTheme:
                    themes.any((theme) => theme.parallaxThemeId == themeId)
                    ? _copyAssignedTheme
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumHeight = 680 * MediaQuery.textScalerOf(context).scale(1);
        return SingleChildScrollView(
          key: const PageStorageKey('level_workspace_scroll'),
          child: SizedBox(
            height: constraints.maxHeight < minimumHeight
                ? minimumHeight
                : constraints.maxHeight,
            child: workspace,
          ),
        );
      },
    );
  }

  Widget _buildSettings(LevelDef level) {
    final segment = !_showLevelSettings && _workspaceTab == LevelCreatorTab.flow
        ? _selectedAssemblySegment
        : null;
    final chunk =
        !_showLevelSettings && _workspaceTab == LevelCreatorTab.contents
        ? _previewChunk(level.levelId)
        : null;
    return LevelInspector(
      boundaryHeights: {
        for (final entry
            in _connectionScene
                    ?.seamAnalysis
                    .leftSignaturesByChunkKey
                    .entries ??
                const <MapEntry<String, TerrainBoundarySignature>>[])
          if (entry.value.coverageIntervals.length == 1)
            '${entry.key} entrance':
                entry.value.coverageIntervals.single.minYTicks / 1024,
        for (final entry
            in _connectionScene
                    ?.seamAnalysis
                    .rightSignaturesByChunkKey
                    .entries ??
                const <MapEntry<String, TerrainBoundarySignature>>[])
          if (entry.value.coverageIntervals.length == 1)
            '${entry.key} exit':
                entry.value.coverageIntervals.single.minYTicks / 1024,
      },
      level: level,
      segment: segment,
      chunk: chunk,
      inputs: {..._levelInputs, ..._segmentInputs},
      focusNodes: _inputFocus,
      errors: _inputErrors,
      revealedFieldKey: _diagnosticFieldKey,
      groups: _chunkThemeGroupsDraft,
      onCompleted: () => _flushInspectorEdits(),
      onShowLevel: () => unawaited(_showLevelInspector()),
      onIncludeInBuildChanged: (value) {
        if (!_flushInspectorEdits()) return;
        widget.controller.applyCommand(
          AuthoringCommand(
            kind: 'update_level',
            payload: {'levelId': level.levelId, 'includeInBuild': value},
          ),
        );
      },
      onSetFirstChunk: () {
        if (chunk != null) _setFirstChunk(chunk);
      },
      onClearFirstChunk: _clearFirstChunk,
      onGroupChanged: (group) {
        _segmentGroupIdController.text = group;
        _flushInspectorEdits();
      },
      onDifficultyChanged: (difficulty) {
        if (!_flushInspectorEdits()) return;
        if (_selectedAssemblySegment case final current?) {
          setState(
            () => _updateSelectedAssemblySegment(
              current.copyWith(
                difficulty: difficulty,
                clearDifficulty: difficulty == null,
              ),
            ),
          );
          _flushInspectorEdits();
        }
      },
      onDuplicateSection: () => unawaited(
        _changeAssemblyStructure(_duplicateSelectedAssemblySegment),
      ),
      onDistinctChanged: (value) {
        setState(() {
          _selectedSegmentRequireDistinct = value;
          if (_selectedAssemblySegment case final current?) {
            _updateSelectedAssemblySegment(
              current.copyWith(requireDistinctChunks: value),
            );
          }
        });
        _flushInspectorEdits();
      },
      onEarlier: (_selectedAssemblySegmentIndex ?? 0) == 0
          ? null
          : () => unawaited(
              _changeAssemblyStructure(_moveSelectedAssemblySegmentUp),
            ),
      onLater:
          _selectedAssemblySegmentIndex == null ||
              _selectedAssemblySegmentIndex == _assemblySegmentsDraft.length - 1
          ? null
          : () => unawaited(
              _changeAssemblyStructure(_moveSelectedAssemblySegmentDown),
            ),
      onRemoveSection: () =>
          unawaited(_changeAssemblyStructure(_removeSelectedAssemblySegment)),
      onEditChunk: chunk == null || widget.onOpenChunk == null
          ? null
          : () => unawaited(
              _openChunk(LevelCreatorChunkIntent.edit, chunk: chunk),
            ),
      onAssignChunk: chunk == null || widget.onOpenChunk == null
          ? null
          : () => unawaited(
              _openChunk(LevelCreatorChunkIntent.assignGroup, chunk: chunk),
            ),
    );
  }

  void _handlePresentationChanged() {
    if (mounted) setState(() {});
  }

  void _persistView() {
    if (_restoringView ||
        _selectedLevelId == null ||
        _viewRestoreNotice != null) {
      return;
    }
    final context = _returnContext;
    final key =
        '${widget.controller.workspacePath}/${context.levelId}/${context.tab}/${context.groupFilter}';
    if (key == _lastPersistedView) return;
    _lastPersistedView = key;
    unawaited(
      widget.viewStore?.write(widget.controller.workspacePath, context),
    );
  }

  Future<void> _refreshContent() async {
    final request = ++_contentRequest;
    _seenSourceGeneration = widget.controller.sourceGeneration;
    _sampleGeneration++;
    setState(() {
      _preparingSample = false;
      _sampleDocument = null;
      _loadingContent = true;
      _contentError = null;
    });
    try {
      final projection = await widget.contentLoader(
        widget.controller.workspacePath,
      );
      if (!mounted || request != _contentRequest) return;
      setState(() {
        _content = projection;
        _connectionLevel = null;
        _refreshConnectionScene(_inspectorBaseline);
        _loadingContent = false;
      });
    } catch (error) {
      if (!mounted || request != _contentRequest) return;
      setState(() {
        _contentError = '$error';
        _loadingContent = false;
      });
    }
  }

  ChunkV2FileData? _previewChunk(String levelId) {
    final chunks = _content?.chunksFor(levelId) ?? const <ChunkV2FileData>[];
    return chunks
            .where((chunk) => chunk.chunkKey == _selectedChunkKey)
            .firstOrNull ??
        chunks.firstOrNull;
  }

  Widget _previewForLevel(LevelDef level) {
    final chunk = _content?.chunksFor(level.levelId).firstOrNull;
    return chunk == null
        ? const Icon(Icons.landscape_outlined)
        : _chunkPreview(chunk, themeId: level.visualThemeId);
  }

  Widget _chunkPreview(ChunkV2FileData chunk, {String? themeId}) {
    final content = _content;
    final document = widget.controller.document;
    if (content == null || document is! LevelDefsDocument) {
      return const Icon(Icons.image_outlined);
    }
    final level = findLevelDefById(document.levels, chunk.levelId);
    return ChunkCompositionPreview(
      key: ValueKey<String>(
        'level_chunk_preview_${chunk.chunkKey}_$_contentRequest',
      ),
      workspaceRootPath: widget.controller.workspacePath,
      chunk: chunk,
      prefabData: content.document.prefabData,
      tileData: content.document.tileData,
      visualBoundsByPrefabKey: content.document.visualBoundsByPrefabKey,
      parallaxTheme: findParallaxThemeById(
        document.parallaxDocument?.themes ?? const <ParallaxThemeDef>[],
        themeId ?? level?.visualThemeId,
      ),
    );
  }

  Future<void> _selectTab(LevelCreatorTab tab) async {
    if (tab == _workspaceTab ||
        !await _resolveInspectorBeforeTransition() ||
        !mounted) {
      return;
    }
    setState(() => _workspaceTab = tab);
    _persistView();
  }

  Future<void> _selectChunk(String key) async {
    if (!await _resolveInspectorBeforeTransition() || !mounted) return;
    setState(() {
      _selectedChunkKey = key;
      _showLevelSettings = false;
    });
    _panelController.revealPanel(2);
  }

  void _setFirstChunk(ChunkV2FileData chunk) {
    if (!_flushInspectorEdits()) return;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'update_level',
        payload: <String, Object?>{
          'levelId': chunk.levelId,
          'firstChunkKey': chunk.chunkKey,
        },
      ),
    );
    _invalidateHandoff();
  }

  void _clearFirstChunk() {
    final level = _inspectorBaseline;
    if (level == null || !_flushInspectorEdits()) return;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'update_level',
        payload: <String, Object?>{
          'levelId': level.levelId,
          'firstChunkKey': null,
        },
      ),
    );
    _invalidateHandoff();
  }

  Future<void> _showLevelInspector() async {
    if (!await _resolveInspectorBeforeTransition() || !mounted) return;
    setState(() => _showLevelSettings = true);
    _panelController.revealPanel(2);
  }

  LevelCreatorReturnContext get _returnContext => LevelCreatorReturnContext(
    levelId: _selectedLevelId!,
    tab: _workspaceTab,
    selectedChunkKey: _selectedChunkKey,
    selectedSegmentId: _selectedAssemblySegment?.segmentId,
    groupFilter: _groupFilter,
    previewSeed: _previewSeed,
    librarySearch: _librarySearch.text,
    chunkSearch: _chunkSearch.text,
    showLevelSettings: _showLevelSettings,
  );

  @override
  LevelCreatorReturnContext? get navigationLocation =>
      _selectedLevelId == null ? null : _returnContext;

  Future<void> _openChunk(
    LevelCreatorChunkIntent intent, {
    ChunkV2FileData? chunk,
  }) async {
    final open = widget.onOpenChunk;
    if (open == null || _selectedLevelId == null || !_flushInspectorEdits()) {
      return;
    }
    await open(
      LevelCreatorChunkTarget(
        levelId: _selectedLevelId!,
        intent: intent,
        chunkKey: chunk?.chunkKey,
        difficulty: _workspaceTab == LevelCreatorTab.flow
            ? _selectedAssemblySegment?.difficulty?.name
            : null,
        groupId:
            _groupFilter ??
            chunk?.assemblyGroupId ??
            (_workspaceTab == LevelCreatorTab.flow
                ? _selectedAssemblySegment?.groupId
                : null) ??
            (intent == LevelCreatorChunkIntent.flatStarter
                ? null
                : defaultLevelChunkThemeGroupId),
        returnContext: _returnContext,
      ),
    );
  }

  Future<void> _createConnectionForIssue(ValidationIssue issue) async {
    final content = _content;
    if (content == null) return;
    final chunk = content.document.chunks
        .where(
          (chunk) =>
              content.document.sourcePathByChunkKey[chunk.chunkKey] ==
              issue.sourcePath,
        )
        .firstOrNull;
    if (chunk == null) return;
    final section = _inspectorBaseline?.assembly?.segments
        .where((section) => section.segmentId == issue.elementId)
        .firstOrNull;
    if (!_flushInspectorEdits() || _selectedLevelId == null) return;
    await widget.onOpenChunk?.call(
      LevelCreatorChunkTarget(
        levelId: _selectedLevelId!,
        intent: LevelCreatorChunkIntent.connecting,
        chunkKey: chunk.chunkKey,
        groupId: section?.groupId ?? chunk.assemblyGroupId,
        difficulty: section?.difficulty?.name,
        returnContext: _returnContext,
      ),
    );
  }

  Future<void> _inspectConnection(ValidationIssue issue) async {
    final document = _content?.document;
    final chunk = document?.chunks
        .where(
          (chunk) =>
              document.sourcePathByChunkKey[chunk.chunkKey] == issue.sourcePath,
        )
        .firstOrNull;
    if (chunk == null) {
      await _openIssue(issue);
      return;
    }
    await _openChunk(LevelCreatorChunkIntent.inspectConnection, chunk: chunk);
  }

  Future<void> _openBackground() async {
    if (!_flushInspectorEdits()) return;
    if (!mounted || _inspectorBaseline == null) {
      return;
    }
    final level = _inspectorBaseline!;
    widget.onOpenInParallax?.call(
      ParallaxLevelTarget(
        levelId: level.levelId,
        parallaxThemeId: level.visualThemeId,
      ),
    );
  }

  Future<void> _showCreateLevelDialog({LevelDef? copySource}) async {
    if (_creationDialogOpen ||
        !await _resolveInspectorBeforeTransition() ||
        !mounted) {
      return;
    }
    final currentScene = widget.controller.scene;
    if (currentScene is! LevelScene) return;
    _resetNewLevelForm(currentScene);
    _copyLevelSourceId = copySource?.levelId;
    _copySectionDesign = false;
    if (copySource != null) {
      _newLevelNameController.text = '${copySource.displayName} Copy';
    }
    _creationDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final scene = widget.controller.scene;
            if (scene is! LevelScene) {
              return const AlertDialog(
                content: Text('Level source is unavailable.'),
              );
            }
            return AlertDialog(
              key: const ValueKey<String>('level_creation_dialog'),
              title: Text(
                copySource == null ? 'New level' : 'Copy level settings',
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: LevelCreationForm(
                    scene: scene,
                    nameController: _newLevelNameController,
                    newLevelIdController: _newLevelIdController,
                    newVisualThemeIdController: _newVisualThemeIdController,
                    themeMode: _newLevelThemeMode,
                    selectedExistingThemeId: _selectedExistingThemeId,
                    formError: _newLevelFormError(scene),
                    isExporting: widget.controller.isExporting,
                    onChanged: () => updateDialog(() {}),
                    onThemeModeChanged: (mode) => updateDialog(() {
                      _newLevelThemeMode = mode;
                      _invalidateHandoff();
                    }),
                    copyingSettings: copySource != null,
                    copySectionDesign: _copySectionDesign,
                    onCopySectionDesignChanged: (value) =>
                        updateDialog(() => _copySectionDesign = value),
                    themePreview: (id) {
                      final document =
                          widget.controller.document as LevelDefsDocument;
                      return ParallaxPreviewView.thumbnail(
                        workspaceRootPath: widget.controller.workspacePath,
                        theme: findParallaxThemeById(
                          document.parallaxDocument?.themes ?? const [],
                          id,
                        ),
                      );
                    },
                    onExistingThemeChanged: (id) => updateDialog(() {
                      _selectedExistingThemeId = id;
                      _invalidateHandoff();
                    }),
                    onCreate: () {
                      if (_createLevel()) {
                        Navigator.of(dialogContext).pop();
                      } else {
                        updateDialog(() {});
                      }
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _resetNewLevelForm(scene);
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (mounted) setState(() => _creationDialogOpen = false);
  }

  Future<void> _showAddGroupDialog() async {
    if (!await _resolveInspectorBeforeTransition() || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Add group'),
          content: TextField(
            key: const ValueKey<String>('new_chunk_theme_group_id'),
            controller: _newChunkThemeGroupIdController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Group ID',
              errorText: _inputErrors['newGroup'],
              helperText: 'Lowercase letters, numbers and underscores.',
            ),
            onChanged: (_) => updateDialog(() {}),
            onSubmitted: (_) {
              _addChunkThemeGroup();
              if (_newChunkThemeGroupIdController.text.isEmpty) {
                Navigator.of(dialogContext).pop();
              } else {
                updateDialog(() {});
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _newChunkThemeGroupIdController.clear();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey<String>('add_chunk_theme_group_button'),
              onPressed: () {
                _addChunkThemeGroup();
                if (_newChunkThemeGroupIdController.text.isEmpty) {
                  Navigator.of(dialogContext).pop();
                } else {
                  updateDialog(() {});
                }
              },
              child: const Text('Add group'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeSelectionMode(bool ordered) async {
    if (!await _resolveInspectorBeforeTransition() || !mounted) return;
    final scene = widget.controller.scene;
    if (scene is! LevelScene) return;
    if (ordered) {
      await _changeAssemblyStructure(() => _addAssemblySegment(scene));
      return;
    }
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove ordered sections?'),
        content: const Text(
          'Automatic selection removes this section sequence. Undo restores it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Use Automatic'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    await _changeAssemblyStructure(() {
      _assemblySegmentsDraft = const <LevelAssemblySegmentDef>[];
      _selectedAssemblySegmentIndex = null;
      _syncSelectedAssemblySegmentControllers();
      _showLevelSettings = true;
    });
  }

  Future<void> _reorderSections(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _assemblySegmentsDraft.length) return;
    await _changeAssemblyStructure(() {
      final selectedId = _selectedAssemblySegment?.segmentId;
      final segments = List<LevelAssemblySegmentDef>.from(
        _assemblySegmentsDraft,
      );
      final segment = segments.removeAt(oldIndex);
      segments.insert(newIndex, segment);
      _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
        segments,
      );
      final selected = segments.indexWhere(
        (item) => item.segmentId == selectedId,
      );
      _selectedAssemblySegmentIndex = selected < 0 ? null : selected;
      _syncSelectedAssemblySegmentControllers();
    });
  }

  void _showDiagnostics() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Level diagnostics (${widget.controller.issues.length})'),
        content: SizedBox(
          width: 760,
          height: 540,
          child: widget.controller.issues.isEmpty
              ? const Center(
                  child: Text('No current source or readiness issues.'),
                )
              : LevelDiagnostics(
                  issues: widget.controller.issues,
                  onOpen: (issue) {
                    Navigator.of(dialogContext).pop();
                    unawaited(_openIssue(issue));
                  },
                  repairLabel: (issue) => widget.onRepairDependency == null
                      ? null
                      : _dependencyRepairLabel(issue.sourcePath),
                  onRepair: (issue) {
                    Navigator.of(dialogContext).pop();
                    final pluginId = levelDependencyPluginForPath(
                      issue.sourcePath,
                    );
                    if (pluginId != null) {
                      unawaited(widget.onRepairDependency!(pluginId));
                    }
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String? _dependencyRepairLabel(String? sourcePath) =>
      switch (levelDependencyPluginForPath(sourcePath)) {
        'parallax' => 'Repair background',
        'chunks' => 'Repair chunk',
        'prefabs' => 'Repair prefab',
        'terrain_materials' => 'Repair terrain material',
        _ => null,
      };

  Future<void> _openIssue(ValidationIssue issue) async {
    final scene = widget.controller.scene;
    if (scene is! LevelScene) return;
    final owner = issue.ownerKey;
    if (owner != null && scene.levels.any((level) => level.levelId == owner)) {
      await _selectLevel(owner);
      if (!mounted || _selectedLevelId != owner) return;
      final sectionId = issue.elementId;
      if (sectionId != null) {
        await _selectTab(LevelCreatorTab.flow);
        final index = _assemblySegmentsDraft.indexWhere(
          (section) => section.segmentId == sectionId,
        );
        if (index >= 0) await _selectAssemblySegment(index);
        _revealDiagnosticField(issue.fieldKey);
      } else if (const {
        'missing_theme_id',
        'invalid_theme_id',
        'missing_parallax_theme',
      }.contains(issue.code)) {
        await _selectTab(LevelCreatorTab.appearance);
        _panelController.revealPanel(1);
      } else if (const {
        'level_has_no_chunks',
        'missing_chunk_theme_groups',
        'invalid_chunk_theme_group_id',
        'duplicate_chunk_theme_group_id',
        'missing_default_chunk_theme_group',
      }.contains(issue.code)) {
        await _selectTab(LevelCreatorTab.contents);
        _panelController.revealPanel(1);
      } else {
        await _showLevelInspector();
        _revealDiagnosticField(
          issue.fieldKey ??
              switch (issue.code) {
                'missing_display_name' => 'displayName',
                'invalid_camera_center_y' ||
                'unusual_camera_center_y' => 'cameraCenterY',
                'invalid_ground_top_y' ||
                'unusual_ground_top_y' => 'groundTopY',
                'invalid_enum_ordinal' ||
                'duplicate_enum_ordinal' => 'enumOrdinal',
                _ => null,
              },
        );
      }
      return;
    }
    final chunk = _content?.document.chunks
        .where(
          (chunk) =>
              chunk.chunkKey == owner ||
              _content?.document.sourcePathByChunkKey[chunk.chunkKey] ==
                  issue.sourcePath,
        )
        .firstOrNull;
    if (chunk != null) {
      await _selectLevel(chunk.levelId);
      await _openChunk(LevelCreatorChunkIntent.edit, chunk: chunk);
    } else if (mounted) {
      await _showLevelInspector();
    }
  }

  void _revealDiagnosticField(String? fieldKey) {
    if (!mounted) return;
    setState(() => _diagnosticFieldKey = fieldKey);
    _panelController.revealPanel(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focus = _inputFocus[fieldKey];
      final target = focus?.context;
      if (target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 160),
          ),
        );
        focus?.requestFocus();
      }
    });
  }

  void _showChanges() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review source changes'),
        content: SizedBox(
          width: 760,
          height: 500,
          child: ListView(
            children: [
              Text(pendingChangesSummary),
              if (_hasInspectorDraft)
                const Text(
                  'The focused edit will be finalized by Save before source writes.',
                ),
              for (final description in pendingChangeDescriptions)
                Text(description),
              for (final diff in widget.controller.pendingChanges.fileDiffs)
                ExpansionTile(
                  title: Text(diff.relativePath),
                  children: [
                    SelectableText(
                      diff.unifiedDiff,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleControllerChanged() {
    if (!mounted || widget.controller.isLoading || _restoringView) return;
    _playtest.reconcileSource(widget.controller.document);
    final scene = widget.controller.scene;
    if (scene is LevelScene && !_applyingInput) {
      if (!_restoredReturnContext) {
        _restoredReturnContext = true;
        final target = _initialViewContext;
        if (target != null &&
            !scene.levels.any((level) => level.levelId == target.levelId)) {
          _viewRestoreNotice =
              'Previously selected level "${target.levelId}" is unavailable. Choose a current level.';
          _selectedChunkKey = null;
          _groupFilter = null;
        }
        if (target != null &&
            scene.activeLevelId != target.levelId &&
            scene.levels.any((level) => level.levelId == target.levelId)) {
          widget.controller.applyPresentationCommand(
            AuthoringCommand(
              kind: 'set_active_level',
              payload: {'levelId': target.levelId},
            ),
          );
          return;
        }
      }
      if (_seenSourceGeneration != widget.controller.sourceGeneration ||
          (_content == null && !_loadingContent && _contentError == null)) {
        unawaited(_refreshContent());
      }
      final level = scene.activeLevel;
      if (!_hasInspectorDraft || _inspectorBaseline == null) {
        _bindInspector(level);
      }
      _persistView();
    }
    setState(() {});
    _notifyShellState();
  }

  void _handleInputChanged() {
    if (_syncingInput || !mounted) return;
    setState(_invalidateHandoff);
    _notifyShellState();
  }

  void _notifyShellState() {
    if (_shellNotificationQueued || !mounted) return;
    _shellNotificationQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shellNotificationQueued = false;
      if (!mounted) return;
      final status =
          '$locksEditorShell/$hasLocalDraftChanges/$canSaveEditorPage/$canHandleUndoSessionShortcut/$canHandleRedoSessionShortcut/${pendingChangeDescriptions.join('|')}';
      if (_lastShellStatus == status) return;
      _lastShellStatus = status;
      widget.onShellStateChanged?.call();
    });
  }

  void _refreshConnectionScene(LevelDef? level) {
    if (level == null || _content == null) {
      _connectionScene = null;
      return;
    }
    if (_connectionLevel != null && levelDefEquals(level, _connectionLevel!)) {
      return;
    }
    _connectionLevel = level;
    _connectionScene = ChunkDomainPlugin().buildEditableScene(
      _content!.document.copyWith(
        activeLevelId: level.levelId,
        levels: [
          for (final current in _content!.document.levels)
            if (current.levelId != level.levelId) current,
          level,
        ],
      ),
    ) as ChunkV2Scene;
  }

  void _bindInspector(LevelDef? level) {
    _refreshConnectionScene(level);
    _syncingInput = true;
    try {
      _selectedLevelId = level?.levelId;
      _inspectorBaseline = level;
      level == null ? _clearInspector() : _syncInspector(level);
      if (!_restoredReturnSelection &&
          level?.levelId == _initialViewContext?.levelId) {
        _restoredReturnSelection = true;
        final selectedId = _initialViewContext?.selectedSegmentId;
        final index = _assemblySegmentsDraft.indexWhere(
          (segment) => segment.segmentId == selectedId,
        );
        if (index >= 0) {
          _selectedAssemblySegmentIndex = index;
          _showLevelSettings = false;
          _syncSelectedAssemblySegmentControllers();
        }
      }
      if (_groupFilter != null &&
          level?.chunkThemeGroups.contains(_groupFilter) != true) {
        _groupFilter = null;
      }
      _inputErrors.clear();
    } finally {
      _syncingInput = false;
    }
  }

  Future<void> _selectLevel(String levelId) async {
    if ((levelId == _selectedLevelId && _viewRestoreNotice == null) ||
        _resolvingTransition) {
      return;
    }
    if (!await _resolveInspectorBeforeTransition() || !mounted) {
      if (mounted) setState(() => _selectionRequestRevision += 1);
      return;
    }
    _selectedChunkKey = null;
    _groupFilter = null;
    _chunkSearch.clear();
    _showLevelSettings = true;
    setState(() => _viewRestoreNotice = null);
    widget.controller.applyPresentationCommand(
      AuthoringCommand(
        kind: 'set_active_level',
        payload: <String, Object?>{'levelId': levelId},
      ),
    );
    _persistView();
    _panelController.revealPanel(1);
  }

  Future<bool> _resolveInspectorBeforeTransition() async {
    if (_flushInspectorEdits()) return true;
    if (_resolvingTransition || _inputErrors.isEmpty) return false;
    _resolvingTransition = true;
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        key: const ValueKey<String>('level_invalid_input_dialog'),
        title: const Text('Finish this edit'),
        content: const Text(
          'This input cannot be accepted yet. Keep editing or discard the invalid input before continuing. Other valid changes are retained.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard this edit'),
          ),
        ],
      ),
    );
    _resolvingTransition = false;
    if (!mounted || discard != true) return false;
    _discardInvalidInput();
    return _flushInspectorEdits();
  }

  Map<String, String> _levelText(LevelDef level) => <String, String>{
    'displayName': level.displayName,
    'visualThemeId': level.visualThemeId,
    'cameraCenterY': formatCanonicalLevelNumber(level.cameraCenterY),
    'groundTopY': formatCanonicalLevelNumber(level.groundTopY),
    'terrainHeightStepPx': '${level.terrainHeightStepPx}',
    'earlyPatternChunks': '${level.earlyPatternChunks}',
    'easyPatternChunks': '${level.easyPatternChunks}',
    'normalPatternChunks': '${level.normalPatternChunks}',
    'noEnemyChunks': '${level.noEnemyChunks}',
    'enumOrdinal': '${level.enumOrdinal}',
  };

  /// Accepts one completed input transaction. Invalid strings never enter the
  /// domain's numeric conversion path or get replaced by their previous value.
  bool _flushInspectorEdits({bool reportErrors = true}) {
    if (_syncingInput || _applyingInput || !_hasInspectorDraft) return true;
    if (widget.controller.isLoading || widget.controller.isExporting) {
      return false;
    }
    final scene = widget.controller.scene;
    final baseline = _inspectorBaseline;
    if (scene is! LevelScene ||
        baseline == null ||
        scene.activeLevel?.levelId != baseline.levelId) {
      return false;
    }
    if (!levelDefEquals(scene.activeLevel!, baseline)) {
      if (reportErrors) {
        _showSnackBar(
          'The level changed while this input was unfinished. Keep the input or reload explicitly.',
        );
      }
      return false;
    }
    final errors = <String, String>{};
    final values = <String, int>{};
    for (final key in const <String>[
      'earlyPatternChunks',
      'easyPatternChunks',
      'normalPatternChunks',
      'noEnemyChunks',
      'terrainHeightStepPx',
      'enumOrdinal',
    ]) {
      final value = int.tryParse(_levelInputs[key]!.text.trim());
      if (value == null || value < 0) {
        errors[key] = 'Enter a whole number of zero or more.';
      } else {
        values[key] = value;
      }
    }
    if ((values['terrainHeightStepPx'] ?? 0) < 1 ||
        (values['terrainHeightStepPx'] ?? 0) > 32) {
      errors['terrainHeightStepPx'] = 'Enter a whole number from 1 to 32 px.';
    }
    if (_displayNameController.text.trim().isEmpty) {
      errors['displayName'] = 'Enter a display name.';
    }
    final ordinal = values['enumOrdinal'];
    if (ordinal != null &&
        scene.levels.any(
          (level) =>
              level.levelId != baseline.levelId && level.enumOrdinal == ordinal,
        )) {
      errors['enumOrdinal'] = 'This ordinal is already used by another level.';
    }
    final group = _newChunkThemeGroupIdController.text.trim();
    if (_newChunkThemeGroupIdController.text.isNotEmpty &&
        (!stableLevelIdentifierPattern.hasMatch(group) ||
            _chunkThemeGroupsDraft.contains(group))) {
      errors['newGroup'] = 'Enter a unique group ID using lowercase letters, numbers and underscores.';
    }
    final groups = group.isNotEmpty && !errors.containsKey('newGroup')
        ? normalizeLevelChunkThemeGroups(<String>[
            ..._chunkThemeGroupsDraft,
            group,
          ])
        : _chunkThemeGroupsDraft;
    final segments = List<LevelAssemblySegmentDef>.from(_assemblySegmentsDraft);
    final segment = _selectedAssemblySegment;
    if (segment != null) {
      final id = _segmentIdController.text.trim();
      final min = int.tryParse(_segmentMinChunkCountController.text.trim());
      final max = int.tryParse(_segmentMaxChunkCountController.text.trim());
      final groupId = _segmentGroupIdController.text.trim();
      if (!stableLevelIdentifierPattern.hasMatch(id) ||
          segments.indexed.any(
            (entry) =>
                entry.$1 != _selectedAssemblySegmentIndex &&
                entry.$2.segmentId == id,
          )) {
        errors['segmentId'] = 'Enter a unique section ID using lowercase letters, numbers and underscores.';
      }
      if (!groups.contains(groupId)) {
        errors['groupId'] = 'Choose a declared chunk group.';
      }
      if (min == null || min < 1) {
        errors['minChunkCount'] = 'Enter a whole number of one or more.';
      }
      if (max == null || max < 1) {
        errors['maxChunkCount'] = 'Enter a whole number of one or more.';
      }
      if (min != null && max != null && min > max) {
        errors['maxChunkCount'] = 'The maximum must be at least the minimum.';
      }
      if (errors.isEmpty) {
        segments[_selectedAssemblySegmentIndex!] = segment.copyWith(
          segmentId: id,
          groupId: groupId,
          minChunkCount: min,
          maxChunkCount: max,
          requireDistinctChunks: _selectedSegmentRequireDistinct,
        );
      }
    }
    if (errors.isNotEmpty) {
      if (reportErrors || _inputErrors.isNotEmpty) {
        setState(() {
          _inputErrors
            ..clear()
            ..addAll(errors);
        });
      }
      if (reportErrors) {
        _inputFocus[errors.keys.first]?.requestFocus();
        _showSnackBar(errors.values.first);
      }
      _notifyShellState();
      return false;
    }
    final assembly = segments.isEmpty
        ? null
        : LevelAssemblyDef(
            loopSegments: _assemblyLoopSegments,
            segments: segments,
          );
    final candidate = baseline.copyWith(
      displayName: _displayNameController.text.trim(),
      visualThemeId: _visualThemeIdController.text.trim(),
      chunkThemeGroups: groups,
      earlyPatternChunks: values['earlyPatternChunks'],
      easyPatternChunks: values['easyPatternChunks'],
      normalPatternChunks: values['normalPatternChunks'],
      noEnemyChunks: values['noEnemyChunks'],
      terrainHeightStepPx: values['terrainHeightStepPx'],
      enumOrdinal: values['enumOrdinal'],
      assembly: assembly,
      clearAssembly: assembly == null,
    );
    if (levelDefEquals(candidate, baseline, ignoreRevision: true)) {
      setState(() => _bindInspector(baseline));
      _notifyShellState();
      return true;
    }
    _applyingInput = true;
    try {
      widget.controller.applyCommand(
        AuthoringCommand(
          kind: 'update_level',
          payload: <String, Object?>{
            'levelId': baseline.levelId,
            'displayName': candidate.displayName,
            'visualThemeId': candidate.visualThemeId,
            'chunkThemeGroups': candidate.chunkThemeGroups,
            'earlyPatternChunks': candidate.earlyPatternChunks,
            'easyPatternChunks': candidate.easyPatternChunks,
            'normalPatternChunks': candidate.normalPatternChunks,
            'noEnemyChunks': candidate.noEnemyChunks,
            'terrainHeightStepPx': candidate.terrainHeightStepPx,
            'enumOrdinal': candidate.enumOrdinal,
            'assembly': candidate.assembly?.toJson(),
          },
        ),
      );
    } finally {
      _applyingInput = false;
    }
    final nextScene = widget.controller.scene;
    final accepted = nextScene is LevelScene
        ? findLevelDefById(nextScene.levels, baseline.levelId)
        : null;
    if (accepted == null ||
        !levelDefEquals(accepted, candidate, ignoreRevision: true)) {
      if (reportErrors) {
        _showSnackBar(
          'The edit was rejected. Your input is retained; review the source diagnostics.',
        );
      }
      return false;
    }
    // Resolve the selected section by its edited identity before canonical bind.
    _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
      segments,
    );
    setState(() {
      _bindInspector(accepted);
      _invalidateHandoff();
    });
    _notifyShellState();
    return true;
  }

  void _discardInvalidInput() {
    final baseline = _inspectorBaseline;
    if (baseline == null) return;
    final segment = _selectedAssemblySegment;
    final originals = <String, String>{
      ..._levelText(baseline),
      'newGroup': '',
      if (segment != null) ...<String, String>{
        'segmentId': segment.segmentId,
        'groupId': segment.groupId,
        'minChunkCount': '${segment.minChunkCount}',
        'maxChunkCount': '${segment.maxChunkCount}',
      },
    };
    final inputs = <String, TextEditingController>{
      ..._levelInputs,
      ..._segmentInputs,
      'newGroup': _newChunkThemeGroupIdController,
    };
    _syncingInput = true;
    try {
      for (final key in _inputErrors.keys) {
        inputs[key]?.text = originals[key] ?? '';
      }
      _inputErrors.clear();
    } finally {
      _syncingInput = false;
    }
    setState(() {});
  }

  Future<void> _changeAssemblyStructure(VoidCallback change) async {
    if (_resolvingTransition ||
        !await _resolveInspectorBeforeTransition() ||
        !mounted) {
      return;
    }
    _syncingInput = true;
    try {
      change();
    } finally {
      _syncingInput = false;
    }
    _flushInspectorEdits();
  }

  Future<void> _selectAssemblySegment(int index) async {
    if (_resolvingTransition) return;
    if (!await _resolveInspectorBeforeTransition() || !mounted) return;
    setState(() {
      _selectedAssemblySegmentIndex = index;
      _showLevelSettings = false;
      _syncingInput = true;
      try {
        _syncSelectedAssemblySegmentControllers();
      } finally {
        _syncingInput = false;
      }
    });
    _panelController.revealPanel(2);
  }

  void _syncInspector(LevelDef level) {
    final previousSegmentId = _selectedAssemblySegment?.segmentId;

    _displayNameController.text = level.displayName;
    _visualThemeIdController.text = level.visualThemeId;
    _cameraCenterYController.text = formatCanonicalLevelNumber(
      level.cameraCenterY,
    );
    _groundTopYController.text = formatCanonicalLevelNumber(level.groundTopY);
    _terrainHeightStepController.text = level.terrainHeightStepPx.toString();
    _earlyPatternChunksController.text = level.earlyPatternChunks.toString();
    _easyPatternChunksController.text = level.easyPatternChunks.toString();
    _normalPatternChunksController.text = level.normalPatternChunks.toString();
    _noEnemyChunksController.text = level.noEnemyChunks.toString();
    _enumOrdinalController.text = level.enumOrdinal.toString();
    _newChunkThemeGroupIdController.text = '';
    _chunkThemeGroupsDraft = List<String>.unmodifiable(level.chunkThemeGroups);
    _assemblyLoopSegments = level.assembly?.loopSegments ?? true;
    _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
      level.assembly?.segments ?? const <LevelAssemblySegmentDef>[],
    );
    final preservedIndex = _assemblySegmentsDraft.indexWhere(
      (segment) => segment.segmentId == previousSegmentId,
    );
    _selectedAssemblySegmentIndex = _assemblySegmentsDraft.isEmpty
        ? null
        : preservedIndex >= 0
        ? preservedIndex
        : 0;
    _syncSelectedAssemblySegmentControllers();
  }

  void _clearInspector() {
    _displayNameController.text = '';
    _visualThemeIdController.text = '';
    _cameraCenterYController.text = '';
    _groundTopYController.text = '';
    _terrainHeightStepController.text = '';
    _earlyPatternChunksController.text = '';
    _easyPatternChunksController.text = '';
    _normalPatternChunksController.text = '';
    _noEnemyChunksController.text = '';
    _enumOrdinalController.text = '';
    _newChunkThemeGroupIdController.text = '';
    _chunkThemeGroupsDraft = const <String>[defaultLevelChunkThemeGroupId];
    _assemblyLoopSegments = true;
    _assemblySegmentsDraft = const <LevelAssemblySegmentDef>[];
    _selectedAssemblySegmentIndex = null;
    _syncSelectedAssemblySegmentControllers();
  }

  bool _createLevel() {
    if (!_flushInspectorEdits()) return false;
    final before = widget.controller.scene;
    if (before is! LevelScene || _newLevelFormError(before) != null) {
      return false;
    }
    final targetId = _newLevelIdController.text.trim();
    final themeId = _newVisualThemeIdController.text.trim();
    final sourceId = _copyLevelSourceId;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: sourceId == null ? 'create_level' : 'duplicate_level',
        payload: {
          'levelId': ?sourceId,
          if (targetId.isNotEmpty)
            (sourceId == null ? 'levelId' : 'nextLevelId'): targetId,
          'displayName': _newLevelNameController.text.trim(),
          'themeMode': _newLevelThemeMode.name,
          if (_newLevelThemeMode == NewLevelThemeMode.existing)
            'visualThemeId': _selectedExistingThemeId,
          if (_newLevelThemeMode == NewLevelThemeMode.copy)
            'sourceVisualThemeId': _selectedExistingThemeId,
          if (_newLevelThemeMode != NewLevelThemeMode.existing &&
              themeId.isNotEmpty)
            'visualThemeId': themeId,
          if (sourceId != null) 'copySectionDesign': _copySectionDesign,
        },
      ),
    );
    final next = widget.controller.scene;
    if (next is! LevelScene || next.levels.length != before.levels.length + 1) {
      return false;
    }
    setState(() => _resetNewLevelForm(next));
    return true;
  }

  void _copyAssignedTheme() {
    if (!_flushInspectorEdits()) return;
    final scene = widget.controller.scene;
    if (scene is! LevelScene || scene.activeLevel == null) return;
    final level = scene.activeLevel!;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'copy_assign_theme',
        payload: {
          'levelId': level.levelId,
          'sourceVisualThemeId': level.visualThemeId,
        },
      ),
    );
  }

  void _deprecateActiveLevel() {
    if (!_flushInspectorEdits()) return;
    final scene = widget.controller.scene;
    if (scene is! LevelScene || scene.activeLevel == null) {
      return;
    }
    _invalidateHandoff();
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'deprecate_level',
        payload: <String, Object?>{'levelId': scene.activeLevel!.levelId},
      ),
    );
  }

  void _reactivateActiveLevel() {
    if (!_flushInspectorEdits()) return;
    final scene = widget.controller.scene;
    if (scene is! LevelScene || scene.activeLevel == null) {
      return;
    }
    _invalidateHandoff();
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'reactivate_level',
        payload: <String, Object?>{'levelId': scene.activeLevel!.levelId},
      ),
    );
  }

  Future<EditorPageSaveResult> _saveSources() async {
    if (widget.controller.saveBlockingErrorCount > 0 ||
        widget.controller.pendingChangesError != null) {
      _showSnackBar(
        'Resolve source validation or recovery issues before saving.',
      );
      return EditorPageSaveResult.blocked;
    }
    if (!widget.controller.pendingChanges.hasChanges) {
      return EditorPageSaveResult.noChanges;
    }
    await widget.controller.exportDirectWrite();
    if (!mounted) return EditorPageSaveResult.blocked;
    final outcome = EditorPageSaveResult.fromSession(widget.controller);
    final result = widget.controller.lastExportResult;
    setState(() {
      _cleanupRequiredPaths = result is LevelThemeExportResult
          ? result.cleanupRequiredPaths
          : const <String>[];
    });
    _notifyShellState();
    if (outcome == EditorPageSaveResult.saved) {
      _showSnackBar(
        'Authoring sources saved. Runtime generation is still required.',
      );
    } else if (outcome == EditorPageSaveResult.savedRefreshFailed) {
      _showSnackBar(
        'Sources saved. Refresh the saved content before continuing.',
      );
    } else if (outcome == EditorPageSaveResult.failed) {
      _showSnackBar(
        widget.controller.exportError ??
            'The save needs recovery. Your input is retained.',
      );
    }
    return outcome;
  }

  bool get _canSaveSources =>
      !widget.controller.isExporting &&
      !widget.controller.isLoading &&
      !widget.controller.requiresSavedRefresh &&
      !widget.controller.requiresTransactionRecovery &&
      _cleanupRequiredPaths.isEmpty &&
      (hasLocalDraftChanges || widget.controller.pendingChanges.hasChanges);

  String? _newLevelFormError(LevelScene scene) {
    if (widget.controller.saveBlockingErrorCount > 0) {
      return 'Resolve source issues before creating a level.';
    }
    if (_newLevelNameController.text.trim().isEmpty) {
      return 'Enter a level name.';
    }
    final levelId = _newLevelIdController.text.trim();
    if (levelId.isNotEmpty) {
      if (!stableLevelIdentifierPattern.hasMatch(levelId)) {
        return 'Use a valid stable Level ID or leave it automatic.';
      }
      if (scene.levels.any((level) => level.levelId == levelId)) {
        return 'Level "$levelId" already exists.';
      }
    }
    if (_newLevelThemeMode != NewLevelThemeMode.create &&
        !scene.availableParallaxVisualThemeIds.contains(
          _selectedExistingThemeId,
        )) {
      return 'Choose a source background.';
    }
    final themeId = _newVisualThemeIdController.text.trim();
    if (_newLevelThemeMode != NewLevelThemeMode.existing &&
        themeId.isNotEmpty) {
      return _newThemeIdError(scene, themeId);
    }
    return null;
  }

  String? _newThemeIdError(LevelScene scene, String themeId) {
    final document = widget.controller.document;
    if (document is! LevelDefsDocument ||
        !document.parallaxThemeSourceAvailable ||
        document.parallaxDocument == null) {
      return 'Parallax source is unavailable. Reload a valid workspace.';
    }
    if (themeId.isEmpty) return 'Enter a visual theme ID.';
    if (!stableAuthoringIdentifierPattern.hasMatch(themeId)) {
      return 'Theme ID must match ${stableAuthoringIdentifierPattern.pattern}.';
    }
    if (scene.availableParallaxVisualThemeIds.contains(themeId)) {
      return 'Visual theme "$themeId" already exists. Use existing theme instead.';
    }
    final symbol = generatedParallaxThemeSymbolSuffix(themeId);
    for (final existingId in scene.availableParallaxVisualThemeIds) {
      if (generatedParallaxThemeSymbolSuffix(existingId) == symbol) {
        return 'Theme ID "$themeId" generates the same Dart symbol as '
            '"$existingId".';
      }
    }
    return null;
  }

  Future<void> _showCreateAndAssignThemeDialog(
    LevelScene scene, {
    String? initialThemeId,
  }) async {
    final activeLevel = scene.activeLevel;
    if (activeLevel == null) return;
    final initialDraft =
        initialThemeId ??
        _createThemeDialogDraftId ??
        _suggestThemeId(scene, '${activeLevel.levelId}_theme');
    var draftText = initialDraft;
    setState(() {
      _createThemeDialogDraftId = initialDraft;
      _createThemeDialogOpen = true;
      _invalidateHandoff();
    });
    final acceptedThemeId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final draft = draftText.trim();
            final error = _newThemeIdError(scene, draft);
            return AlertDialog(
              title: const Text('Create and assign visual theme'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      key: const ValueKey<String>(
                        'create_assign_theme_id_field',
                      ),
                      initialValue: initialDraft,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'New visual theme ID',
                        border: const OutlineInputBorder(),
                        errorText: error,
                      ),
                      onChanged: (value) {
                        draftText = value;
                        _createThemeDialogDraftId = value;
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This stages an empty revision-1 theme and assigns it to '
                      'the level in one undo step. Add layers in Parallax after apply.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: error == null
                      ? () => Navigator.of(dialogContext).pop(draft)
                      : null,
                  child: const Text('Create and assign'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _createThemeDialogOpen = false;
      if (acceptedThemeId == null) _createThemeDialogDraftId = null;
    });
    if (acceptedThemeId == null) return;

    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'create_and_assign_theme',
        payload: <String, Object?>{
          'levelId': activeLevel.levelId,
          'visualThemeId': acceptedThemeId,
        },
      ),
    );
    final updatedScene = widget.controller.scene;
    final accepted =
        updatedScene is LevelScene &&
        updatedScene.activeLevel?.levelId == activeLevel.levelId &&
        updatedScene.activeLevel?.visualThemeId == acceptedThemeId &&
        updatedScene.availableParallaxVisualThemeIds.contains(acceptedThemeId);
    if (!accepted) {
      _showSnackBar(
        'The visual theme command was rejected. Review validation.',
      );
      return;
    }
    setState(() {
      _createThemeDialogDraftId = null;
      _visualThemeIdController.text = acceptedThemeId;
    });
  }

  void _resetNewLevelForm(LevelScene scene) {
    _newLevelNameController.clear();
    _newLevelIdController.clear();
    _newVisualThemeIdController.clear();
    _newLevelThemeMode = scene.availableParallaxVisualThemeIds.isEmpty
        ? NewLevelThemeMode.create
        : NewLevelThemeMode.copy;
    _selectedExistingThemeId =
        scene.availableParallaxVisualThemeIds.contains(
          scene.activeLevel?.visualThemeId,
        )
        ? scene.activeLevel!.visualThemeId
        : scene.availableParallaxVisualThemeIds.firstOrNull;
    _copyLevelSourceId = null;
    _copySectionDesign = false;
  }

  String _suggestThemeId(LevelScene scene, String base) {
    final ids = scene.availableParallaxVisualThemeIds.toSet();
    if (!ids.contains(base)) return base;
    var counter = 2;
    while (ids.contains('${base}_$counter')) {
      counter += 1;
    }
    return '${base}_$counter';
  }

  void _invalidateHandoff() {
    _notifyShellState();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _assemblyDraftDiffersFromLevel(LevelDef level) {
    final currentAssembly = _assemblySegmentsDraft.isEmpty
        ? null
        : LevelAssemblyDef(
            loopSegments: _assemblyLoopSegments,
            segments: _assemblySegmentsDraft,
          );
    return !levelAssemblyEquals(currentAssembly, level.assembly);
  }

  bool _stringListEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i += 1) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  LevelAssemblySegmentDef? get _selectedAssemblySegment {
    final index = _selectedAssemblySegmentIndex;
    if (index == null || index < 0 || index >= _assemblySegmentsDraft.length) {
      return null;
    }
    return _assemblySegmentsDraft[index];
  }

  void _syncSelectedAssemblySegmentControllers() {
    final segment = _selectedAssemblySegment;
    if (segment == null) {
      _segmentIdController.text = '';
      _segmentGroupIdController.text = '';
      _segmentMinChunkCountController.text = '';
      _segmentMaxChunkCountController.text = '';
      _selectedSegmentRequireDistinct = true;
      return;
    }
    _segmentIdController.text = segment.segmentId;
    _segmentGroupIdController.text = segment.groupId;
    _segmentMinChunkCountController.text = segment.minChunkCount.toString();
    _segmentMaxChunkCountController.text = segment.maxChunkCount.toString();
    _selectedSegmentRequireDistinct = segment.requireDistinctChunks;
  }

  void _updateSelectedAssemblySegment(LevelAssemblySegmentDef nextSegment) {
    final index = _selectedAssemblySegmentIndex;
    if (index == null || index < 0 || index >= _assemblySegmentsDraft.length) {
      return;
    }
    final nextSegments = List<LevelAssemblySegmentDef>.from(
      _assemblySegmentsDraft,
    );
    nextSegments[index] = nextSegment.normalized();
    _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
      nextSegments,
    );
    _invalidateHandoff();
  }

  void _addChunkThemeGroup() {
    if (_newChunkThemeGroupIdController.text.trim().isEmpty) {
      _showSnackBar('Enter a group ID before adding.');
      return;
    }
    _flushInspectorEdits();
  }

  void _removeChunkThemeGroup(LevelScene scene, String groupId) {
    if (groupId == defaultLevelChunkThemeGroupId) {
      _showSnackBar('"$defaultLevelChunkThemeGroupId" cannot be removed.');
      return;
    }
    if (_assemblySegmentsDraft.any((segment) => segment.groupId == groupId)) {
      _showSnackBar(
        'Reassign assembly segments using "$groupId" before removing it.',
      );
      return;
    }
    final activeLevelId = scene.activeLevelId;
    final authoredCount = activeLevelId == null
        ? 0
        : (scene.authoredChunkAssemblyGroupCountsByLevelId[activeLevelId]?[groupId] ??
              0);
    if (authoredCount > 0) {
      _showSnackBar(
        'Group "$groupId" is still used by $authoredCount chunk(s). '
        'Reassign chunks first.',
      );
      return;
    }
    setState(() {
      _chunkThemeGroupsDraft = normalizeLevelChunkThemeGroups(
        _chunkThemeGroupsDraft.where((entry) => entry != groupId),
      );
    });
  }

  void _addAssemblySegment(LevelScene scene) {
    final activeLevel = scene.activeLevel;
    if (activeLevel == null) {
      return;
    }
    final nextSegments = List<LevelAssemblySegmentDef>.from(
      _assemblySegmentsDraft,
    );
    final availableGroups = _chunkThemeGroupsDraft;
    final selectedSegment = _selectedAssemblySegment;
    final draftedGroupId = _segmentGroupIdController.text.trim();
    final preferredGroupId = draftedGroupId.isNotEmpty
        ? draftedGroupId
        : (selectedSegment?.groupId ?? defaultAssemblyGroupId);
    final nextSegment =
        buildSuggestedLevelAssemblySegment(
          existingSegments: nextSegments,
          availableGroupIds: availableGroups,
          preferredGroupId: preferredGroupId,
        ).copyWith(
          minChunkCount: 1,
          maxChunkCount: 1,
          difficulty:
              selectedSegment?.difficulty ??
              _content
                  ?.chunksFor(activeLevel.levelId, groupId: preferredGroupId)
                  .where((chunk) => chunk.status == chunkStatusActive)
                  .map(
                    (chunk) => ChunkPatternTier.values
                        .where((tier) => tier.name == chunk.difficulty)
                        .firstOrNull,
                  )
                  .whereType<ChunkPatternTier>()
                  .firstOrNull ??
              ChunkPatternTier.easy,
          requireDistinctChunks: true,
        );
    nextSegments.add(nextSegment);
    setState(() {
      _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
        nextSegments,
      );
      _selectedAssemblySegmentIndex = nextSegments.length - 1;
      _showLevelSettings = false;
      _syncSelectedAssemblySegmentControllers();
    });
  }

  void _duplicateSelectedAssemblySegment() {
    final segment = _selectedAssemblySegment;
    final index = _selectedAssemblySegmentIndex;
    if (segment == null || index == null) return;
    final segments = List<LevelAssemblySegmentDef>.from(_assemblySegmentsDraft);
    segments.insert(
      index + 1,
      segment.copyWith(
        segmentId: allocateUniqueAssemblySegmentId(segments, segment.segmentId),
      ),
    );
    setState(() {
      _assemblySegmentsDraft = List.unmodifiable(segments);
      _selectedAssemblySegmentIndex = index + 1;
      _syncSelectedAssemblySegmentControllers();
    });
  }

  void _moveSelectedAssemblySegmentUp() {
    final index = _selectedAssemblySegmentIndex;
    if (index == null || index <= 0) {
      return;
    }
    final nextSegments = List<LevelAssemblySegmentDef>.from(
      _assemblySegmentsDraft,
    );
    final current = nextSegments.removeAt(index);
    nextSegments.insert(index - 1, current);
    setState(() {
      _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
        nextSegments,
      );
      _selectedAssemblySegmentIndex = index - 1;
      _syncSelectedAssemblySegmentControllers();
    });
  }

  void _moveSelectedAssemblySegmentDown() {
    final index = _selectedAssemblySegmentIndex;
    if (index == null || index >= _assemblySegmentsDraft.length - 1) {
      return;
    }
    final nextSegments = List<LevelAssemblySegmentDef>.from(
      _assemblySegmentsDraft,
    );
    final current = nextSegments.removeAt(index);
    nextSegments.insert(index + 1, current);
    setState(() {
      _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
        nextSegments,
      );
      _selectedAssemblySegmentIndex = index + 1;
      _syncSelectedAssemblySegmentControllers();
    });
  }

  void _removeSelectedAssemblySegment() {
    final index = _selectedAssemblySegmentIndex;
    if (index == null || index < 0 || index >= _assemblySegmentsDraft.length) {
      return;
    }
    final nextSegments = List<LevelAssemblySegmentDef>.from(
      _assemblySegmentsDraft,
    )..removeAt(index);
    setState(() {
      _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
        nextSegments,
      );
      _selectedAssemblySegmentIndex = nextSegments.isEmpty
          ? null
          : (index >= nextSegments.length ? nextSegments.length - 1 : index);
      _syncSelectedAssemblySegmentControllers();
    });
  }
}
