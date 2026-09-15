import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../build/content_build_service.dart';
import '../shared/content_build_dialog.dart';
import '../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../chunks/chunk_domain_plugin.dart';
import '../../../chunks/chunk_connection_creation.dart';
import '../../../chunks/chunk_v2_models.dart';
import '../chunkCreator/v2/chunk_connection_creation_dialog.dart';
import '../chunkCreator/chunk_creator_location.dart';
import '../../../chunks/chunk_level_target.dart';
import '../../../domain/authoring_types.dart';
import '../../../domain/authoring_dependency_repair.dart';
import '../../../levels/level_domain_models.dart';
import '../levelCreator/level_creator_navigation.dart';
import '../prefabCreator/prefab_creator_navigation.dart';
import '../shared/authoring_conflict_dialog.dart';
import '../../../parallax/parallax_domain_models.dart';
import '../../../parallax/parallax_domain_plugin.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_pending_changes_dialog.dart';
import 'home_routes.dart';
import 'editor_navigation_history.dart';
import '../shared/editor_page_navigation_state.dart';
import '../../../workspace/editor_workspace.dart';

/// Top-level editor shell that coordinates route selection around one shared
/// [EditorSessionController].
///
/// This page owns shell concerns only: selecting the active top-level route,
/// guarding destructive transitions, and routing shell-level undo/redo
/// shortcuts. Domain load/edit/export behavior still flows through the
/// selected plugin and page.
class EditorHomePage extends StatefulWidget {
  const EditorHomePage({
    super.key,
    required this.controller,
    this.buildService,
  });

  /// Shared authoring session used by every top-level route.
  final EditorSessionController controller;

  /// Optional process adapter for an embedded editor or test harness.
  final ContentBuildService? buildService;

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  late final AppLifecycleListener _appLifecycleListener;
  late final ContentBuildService _buildService;
  bool _isShowingBuild = false;
  late String _buildWorkspacePath;
  bool _isPreparingBuild = false;
  // The shell owns stable page keys so it can query the active route for local
  // draft state, shortcut handling, and reload delegation without reintroducing
  // route-id switches elsewhere in the file.
  late final Map<String, _EditorHomeRouteBinding> _routeBindings;
  // Route/app-exit requests can all ask for discard confirmation;
  // keep them serialized so the shell never stacks competing dialogs.
  bool _isShowingDiscardDialog = false;
  bool _isSavingCurrentPage = false;
  String _selectedRouteId = entitiesRouteId;
  EditorPageLocation? _initialLocation;
  late final EditorNavigationHistory _navigationHistory;
  bool _isNavigating = false;
  LevelCreatorReturnContext? _levelReturnContext;
  ChunkFlatStarterIntent? _pendingStarterIntent;
  EditorSessionController? _repairController;
  String? _repairOriginRouteId;
  EditorPageLocation? _repairOriginLocation;
  bool _repairTransition = false;

  EditorSessionController get _controller =>
      _repairController ?? widget.controller;

  @override
  void initState() {
    super.initState();
    _buildService = widget.buildService ?? ContentBuildService();
    _buildWorkspacePath = widget.controller.workspacePath;
    _buildService.addListener(_handleBuildChanged);
    widget.controller.addListener(_updateBuildDirty);
    _selectedRouteId =
        homeRoutes
            .where(
              (route) => route.pluginId == widget.controller.selectedPluginId,
            )
            .firstOrNull
            ?.id ??
        entitiesRouteId;
    _navigationHistory = EditorNavigationHistory(
      EditorNavigationLocation(routeId: _selectedRouteId),
    );
    _routeBindings = <String, _EditorHomeRouteBinding>{
      for (final route in homeRoutes)
        route.id: _EditorHomeRouteBinding(route: route, pageKey: GlobalKey()),
    };
    _appLifecycleListener = AppLifecycleListener(
      onExitRequested: _handleAppExitRequested,
      onStateChange: _handleAppLifecycleState,
    );
    // The shell handles cross-route undo/redo shortcuts globally, then routes
    // them back into the active page/session when appropriate.
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    // Route selection is shell-owned, but plugin selection still lives in the
    // shared session controller. Sync them once after the first frame so the
    // initial page and initial plugin contract start coherent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPluginForRoute(_selectedRouteId);
      _updateBuildDirty();
    });
  }

  @override
  void didUpdateWidget(covariant EditorHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_updateBuildDirty);
    widget.controller.addListener(_updateBuildDirty);
    _repairController?.dispose();
    _repairController = null;
    _repairOriginRouteId = null;
    _repairOriginLocation = null;
    _initialLocation = null;
    _levelReturnContext = null;
    _pendingStarterIntent = null;
    _selectedRouteId = homeRoutes
        .firstWhere(
          (route) => route.pluginId == widget.controller.selectedPluginId,
        )
        .id;
    _navigationHistory.reset(
      EditorNavigationLocation(routeId: _selectedRouteId),
    );
    for (final route in homeRoutes) {
      _routeBindings[route.id] = _EditorHomeRouteBinding(
        route: route,
        pageKey: GlobalKey(),
      );
    }
    _updateBuildDirty();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateBuildDirty);
    _buildService.removeListener(_handleBuildChanged);
    if (widget.buildService == null) _buildService.dispose();
    _repairController?.dispose();
    _appLifecycleListener.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EditorHomeShellControls(
                    selectedRouteId: _selectedRouteId,
                    shellLocked: !_canNavigate,
                    onBack: _canNavigate && _navigationHistory.canGoBack
                        ? () => _handleHistoryNavigation(forward: false)
                        : null,
                    onForward: _canNavigate && _navigationHistory.canGoForward
                        ? () => _handleHistoryNavigation(forward: true)
                        : null,
                    backLabel: _navigationHistory.back == null
                        ? null
                        : _requireRouteBinding(_navigationHistory.back!.routeId)
                              .route
                              .label,
                    forwardLabel: _navigationHistory.forward == null
                        ? null
                        : _requireRouteBinding(
                            _navigationHistory.forward!.routeId,
                          ).route.label,
                    canReloadCurrentPage: _canReloadCurrentPage,
                    canSaveCurrentPage: _canSaveCurrentPage,
                    canUndoCurrentPage: _canUndoCurrentPage,
                    canRedoCurrentPage: _canRedoCurrentPage,
                    isLoading: _controller.isLoading,
                    isExporting: _controller.isExporting,
                    hasPendingChanges:
                        _controller.pendingChanges.hasChanges ||
                        _currentPageHasLocalDraftChanges(),
                    pendingSummary: _pendingChangesSummary,
                    pendingItemCount:
                        _controller.pendingChanges.changedItemIds.length,
                    pendingFileCount:
                        _controller.pendingChanges.fileDiffs.length,
                    pendingChangesError: _controller.pendingChangesError,
                    errorCount: _controller.errorCount,
                    warningCount: _controller.warningCount,
                    onReloadPressed: _handleReloadRequested,
                    onSavePressed: _handleSaveRequested,
                    onUndoPressed: _handleUndoShortcut,
                    onRedoPressed: _handleRedoShortcut,
                    onRouteSelected: _handleRouteSelectionRequested,
                    onBuildPressed: _canOpenBuild ? _showBuildReport : null,
                    buildStatus: _buildStatusLabel,
                  ),
                  if (_levelReturnContext != null &&
                      _repairController == null &&
                      _selectedRouteId != levelCreatorRouteId)
                    MaterialBanner(
                      content: Text(
                        'Editing content for ${_levelReturnContext!.levelId}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: !_canNavigate
                              ? null
                              : () => _returnToLevel(save: false),
                          child: const Text('Return to level'),
                        ),
                        FilledButton(
                          onPressed: !_canNavigate
                              ? null
                              : () => _returnToLevel(save: true),
                          child: const Text('Save and return to level'),
                        ),
                      ],
                    ),
                  if (_repairController != null)
                    MaterialBanner(
                      content: const Text(
                        'Dependency repair — your originating edits are retained.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: _repairTransition
                              ? null
                              : () => _returnFromRepair(save: false),
                          child: const Text('Cancel repair and return'),
                        ),
                        FilledButton(
                          onPressed: _repairTransition
                              ? null
                              : () => _returnFromRepair(save: true),
                          child: const Text('Save repair and return'),
                        ),
                      ],
                    ),
                  if (_controller.requiresSourceReconciliation ||
                      _controller.recoveryCopy != null)
                    MaterialBanner(
                      content: Text(
                        _controller.recoveryError ?? 'Saved sources changed. Your edits are retained for review.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: _handleReloadRequested,
                          child: const Text('Reload and discard all'),
                        ),
                        if (_controller.canReapplyIntent)
                          FilledButton(
                            onPressed: _controller.isLoading
                                ? null
                                : _handleReapplyIntent,
                            child: const Text('Review and reapply'),
                          ),
                      ],
                    ),
                  if (_controller.requiresSavedRefresh)
                    MaterialBanner(
                      content: Text(
                        'Saved; refresh failed. ${_controller.refreshError ?? ''}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: _controller.isLoading
                              ? null
                              : () => _controller.retrySavedRefresh(),
                          child: const Text('Retry refresh'),
                        ),
                      ],
                    ),
                  if (_controller.requiresTransactionRecovery)
                    MaterialBanner(
                      content: Text(
                        _controller.recoveryError ??
                            _controller.lastExportResult?.message ??
                            'Source transaction recovery requires review.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: _showTransactionRecovery,
                          child: const Text('Review recovery'),
                        ),
                        if (_controller.lastExportResult?.recovery != null)
                          FilledButton(
                            onPressed: _controller.isExporting
                                ? null
                                : () => _controller.retryTransactionRecovery(),
                            child: const Text('Retry transaction recovery'),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: IgnorePointer(
                      ignoring: _buildService.isRunning,
                      child: ExcludeFocus(
                        excluding: _buildService.isRunning,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Offstage(
                                offstage: _repairController != null,
                                child: TickerMode(
                                  enabled: _repairController == null,
                                  child: ExcludeFocus(
                                    excluding: _repairController != null,
                                    child: _buildRoutePage(
                                      _repairOriginRouteId ?? _selectedRouteId,
                                      widget.controller,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_repairController != null)
                              Positioned.fill(
                                child: _buildRoutePage(
                                  _selectedRouteId,
                                  _repairController!,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoutePage(String routeId, EditorSessionController controller) {
    final routeBinding = _requireRouteBinding(routeId);
    return routeBinding.buildPage(
      controller,
      navigation: EditorHomeRouteNavigation(
        initialLocation: routeId == _selectedRouteId
            ? _initialLocation
            : _repairOriginLocation,
        onOpenChunkForLevel: _handleOpenChunkForLevel,
        onRepairDependency: _beginDependencyRepair,
        onShellStateChanged: () {
          if (mounted) {
            _updateBuildDirty();
            setState(() {});
          }
        },
        onOpenPrefabTarget: (target) {
          unawaited(_handleOpenPrefabTargetRequested(target));
        },
        onOpenParallaxForLevel: (target) {
          unawaited(_handleOpenParallaxForLevelRequested(target));
        },
      ),
    );
  }

  // `homeRoutes` is authoritative, so route/plugin drift is a configuration
  // bug. Fail fast instead of leaving the shell on one page and the session on
  // another plugin contract.
  void _syncPluginForRoute(String routeId) {
    final requiredPluginId = _requireRoutePlugin(routeId);
    if (requiredPluginId == _controller.selectedPluginId) {
      return;
    }
    _controller.setSelectedPluginId(requiredPluginId);
  }

  String _requireRoutePlugin(String routeId) {
    final requiredPluginId = _requireRouteBinding(routeId).route.pluginId;
    final hasPlugin = _controller.availablePlugins.any(
      (plugin) => plugin.id == requiredPluginId,
    );
    if (!hasPlugin) {
      throw StateError(
        'Editor home route "$routeId" requires plugin '
        '"$requiredPluginId", but it is not registered.',
      );
    }
    return requiredPluginId;
  }

  void _handleBuildChanged() {
    if (mounted) setState(() {});
  }

  void _updateBuildDirty() {
    if (!mounted) return;
    if (_buildWorkspacePath != widget.controller.workspacePath) {
      _buildWorkspacePath = widget.controller.workspacePath;
      _buildService.resetForWorkspaceChange();
    }
    _buildService.setAuthoringDirty(
      widget.controller.pendingChanges.hasChanges ||
          _controller.pendingChanges.hasChanges ||
          _currentPageHasLocalDraftChanges(),
    );
  }

  bool get _canOpenBuild =>
      !_isPreparingBuild &&
      _repairController == null &&
      (!_isCurrentPageShellLocked || _buildService.isRunning) &&
      !_controller.isLoading &&
      !_controller.isExporting;

  String get _buildStatusLabel => switch (_buildService.status) {
    GeneratedContentStatus.notChecked => 'Not checked',
    GeneratedContentStatus.buildNeeded => 'Needed',
    GeneratedContentStatus.checking => 'Checking',
    GeneratedContentStatus.building => 'Running',
    GeneratedContentStatus.builtAndVerified => 'Verified',
    GeneratedContentStatus.failed => 'Failed',
    GeneratedContentStatus.cancelled => 'Cancelled',
  };

  Future<void> _showBuildReport() async {
    if (_isShowingBuild || !mounted) return;
    _updateBuildDirty();
    _isShowingBuild = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          void navigate(Future<void> Function() action) {
            Navigator.of(dialogContext).pop();
            unawaited(action());
          }

          return ContentBuildDialog(
            controller: _buildService,
            onClose: () => Navigator.of(dialogContext).pop(),
            onBuild: () => navigate(() => _runContentBuild(dryRun: false)),
            onCheck: () => navigate(() => _runContentBuild(dryRun: true)),
            onOpenIssue: (issue) => navigate(() => _openBuildIssue(issue)),
            onOpenLevel: (level) => navigate(() async {
              await _openBuildLevel(level.levelId);
            }),
            onAddContent: (level) => navigate(() async {
              if (await _openBuildLevel(level.levelId) && mounted) {
                await _handleOpenChunkForLevel(
                  LevelCreatorChunkTarget(
                    levelId: level.levelId,
                    intent: LevelCreatorChunkIntent.create,
                    returnContext: LevelCreatorReturnContext(
                      levelId: level.levelId,
                    ),
                  ),
                );
              }
            }),
            onExcludeLevel: (level) =>
                navigate(() => _setBuildLevelIncluded(level, false)),
            onRestoreLevel: (level) =>
                navigate(() => _setBuildLevelIncluded(level, true)),
          );
        },
      );
    } finally {
      _isShowingBuild = false;
    }
  }

  Future<void> _runContentBuild({required bool dryRun}) async {
    // Let the report route finish closing before showing a Save decision.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || !_canOpenBuild || _buildService.isRunning) return;
    _isPreparingBuild = true;
    try {
      if (!dryRun) {
        if (!await _resolvePendingDeparture(
              promptLine: 'Build game content from saved sources?',
            ) ||
            !mounted) {
          return;
        }
        // Discard resolved a departure decision. Build stays on this route, so
        // explicitly discard its buffers before acquiring the source-write lock.
        if (_controller.pendingChanges.hasChanges ||
            _currentPageHasLocalDraftChanges()) {
          await _reloadCurrentRoute();
        }
        if (!mounted ||
            _controller.loadError != null ||
            _controller.pendingChanges.hasChanges ||
            _currentPageHasLocalDraftChanges()) {
          return;
        }
      }
      _updateBuildDirty();
      final job = dryRun
          ? _buildService.checkFreshness(
              workspaceRoot: _controller.workspacePath,
            )
          : _buildService.build(workspaceRoot: _controller.workspacePath);
      _isPreparingBuild = false;
      unawaited(_showBuildReport());
      await job;
    } finally {
      _isPreparingBuild = false;
      if (mounted) setState(() {});
    }
  }

  Future<bool> _openBuildLevel(String levelId) => _navigate(
    EditorNavigationLocation(
      routeId: levelCreatorRouteId,
      page: LevelCreatorReturnContext(levelId: levelId),
    ),
    prompt: 'Open the Level from this Build report?',
    loadDocument: (plugin, workspace) =>
        _loadExistingLevel(plugin, workspace, levelId),
  );

  Future<AuthoringDocument> _loadExistingLevel(
    AuthoringDomainPlugin plugin,
    EditorWorkspace workspace,
    String levelId,
  ) async {
    final document = await plugin.loadFromRepo(workspace);
    if (document is! LevelDefsDocument ||
        findLevelDefById(document.levels, levelId) == null) {
      throw StateError(
        'The Level "$levelId" no longer exists in saved sources.',
      );
    }
    return document;
  }

  Future<void> _setBuildLevelIncluded(
    ContentBuildLevel level,
    bool included,
  ) async {
    if (await _openBuildLevel(level.levelId) && mounted) {
      _controller.applyCommand(
        AuthoringCommand(
          kind: 'update_level',
          payload: {'levelId': level.levelId, 'includeInBuild': included},
        ),
      );
    }
  }

  Future<void> _openBuildIssue(ContentBuildIssue issue) async {
    final pluginId = levelDependencyPluginForPath(issue.path);
    if (pluginId != null) {
      final route = homeRoutes
          .where((route) => route.pluginId == pluginId)
          .firstOrNull;
      if (route != null) await _handleRouteSelectionRequested(route.id);
    } else if (issue.levelId != null) {
      await _openBuildLevel(issue.levelId!);
    } else if (issue.path?.replaceAll('\\', '/').endsWith('level_defs.json') ??
        false) {
      await _handleRouteSelectionRequested(levelCreatorRouteId);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review ${issue.path ?? issue.code}: ${issue.message}'),
        ),
      );
    }
  }

  bool get _canNavigate =>
      !_isNavigating &&
      !_isShowingDiscardDialog &&
      !_repairTransition &&
      _repairController == null &&
      !_isCurrentPageShellLocked;

  EditorNavigationLocation _captureLocation() {
    final page = _currentPageState;
    return EditorNavigationLocation(
      routeId: _selectedRouteId,
      page: page is EditorPageNavigationState
          ? page.navigationLocation
          : _initialLocation,
      levelReturnContext: _levelReturnContext,
    );
  }

  /// One transaction for selector, history, source links, and Level returns.
  /// The old page and history survive cancellation or a failed destination load.
  Future<bool> _navigate(
    EditorNavigationLocation destination, {
    String prompt = 'Leave this editor?',
    bool save = false,
    int? historyIndex,
    Future<AuthoringDocument> Function(
      AuthoringDomainPlugin plugin,
      EditorWorkspace workspace,
    )?
    loadDocument,
    VoidCallback? onLoaded,
    SnackBarAction? Function(Object? error)? actionForLoadFailure,
  }) async {
    if (!_canNavigate) return false;
    final pluginId = _requireRoutePlugin(destination.routeId);
    setState(() => _isNavigating = true);
    final controller = _controller;
    try {
      if (save &&
          (controller.pendingChanges.hasChanges ||
              _currentPageHasLocalDraftChanges())) {
        final outcome = await _handleSaveRequested();
        if (!mounted ||
            !outcome.permitsDeparture ||
            _currentPageHasLocalDraftChanges()) {
          return false;
        }
      } else if (!await _resolvePendingDeparture(promptLine: prompt)) {
        return false;
      }
      if (!mounted || !identical(controller, _controller)) return false;
      // Capture after Save can rename an owner, but before loading another
      // plugin notifies the departing page with a different scene type.
      final origin = _captureLocation();
      final route = _requireRouteBinding(destination.routeId).route;
      Object? targetError;
      final loaded = await controller.loadWorkspaceForPlugin(
        pluginId: pluginId,
        loadDocument: (plugin, workspace) async {
          try {
            final document = await (loadDocument == null
                ? plugin.loadFromRepo(workspace)
                : loadDocument(plugin, workspace));
            return destination.page?.restoreDocumentSelection(
                  plugin,
                  document,
                ) ??
                document;
          } catch (error) {
            targetError = error;
            rethrow;
          }
        },
      );
      if (!mounted || !identical(controller, _controller)) return false;
      if (!loaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open ${route.label}: ${controller.loadError}',
            ),
            action: actionForLoadFailure?.call(targetError),
          ),
        );
        return false;
      }
      onLoaded?.call();
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _navigationHistory.commit(
          origin: origin,
          destination: destination,
          historyIndex: historyIndex,
        );
        _selectedRouteId = destination.routeId;
        _initialLocation = destination.page;
        _levelReturnContext = destination.levelReturnContext;
        // A same-tool targeted visit also needs a new view, while repair keeps
        // its originating key mounted until the dependency flow finishes.
        _routeBindings[destination.routeId] = _EditorHomeRouteBinding(
          route: route,
          pageKey: GlobalKey(),
        );
        if (_levelReturnContext == null) _pendingStarterIntent = null;
      });
      // Keep rapid requests serialized until the destination owns its page key.
      await WidgetsBinding.instance.endOfFrame;
      return true;
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  Future<void> _handleHistoryNavigation({required bool forward}) async {
    final target = forward
        ? _navigationHistory.forward
        : _navigationHistory.back;
    if (target == null) return;
    await _navigate(
      target,
      historyIndex: _navigationHistory.index + (forward ? 1 : -1),
    );
  }

  Future<void> _handleRouteSelectionRequested(String routeId) async {
    if (routeId == _selectedRouteId) return;
    if (routeId == levelCreatorRouteId && _levelReturnContext != null) {
      await _returnToLevel(save: false);
    } else {
      await _navigate(_navigationHistory.forRoute(routeId));
    }
  }

  Future<void> _handleOpenPrefabTargetRequested(
    PrefabCreatorTarget target,
  ) async {
    final key = target.prefabKey.trim();
    if (key.isEmpty) return;
    final normalized = PrefabCreatorTarget(
      prefabKey: key,
      destination: target.destination,
    );
    await _navigate(
      EditorNavigationLocation(
        routeId: prefabCreatorRouteId,
        page: PrefabCreatorLocation.forTarget(normalized),
        levelReturnContext: _levelReturnContext,
      ),
      prompt: 'Open Prefab Creator?',
      loadDocument: (plugin, workspace) async {
        if (plugin is! PrefabDomainPlugin) {
          throw StateError(
            'Owning-prefab navigation requires PrefabDomainPlugin.',
          );
        }
        final document = await plugin.loadV3FromRepo(workspace);
        if (!document.data.prefabs.any((prefab) => prefab.prefabKey == key)) {
          throw StateError('Prefab-v3 owner "$key" no longer exists on disk.');
        }
        return document;
      },
    );
  }

  Future<void> _handleOpenParallaxForLevelRequested(
    ParallaxLevelTarget target,
  ) async {
    if (target.levelId.trim().isEmpty ||
        target.parallaxThemeId.trim().isEmpty) {
      return;
    }
    final page = _captureLocation().page;
    await _navigate(
      EditorNavigationLocation(
        routeId: parallaxEditorRouteId,
        levelReturnContext: page is LevelCreatorReturnContext ? page : null,
      ),
      prompt: 'Open this saved level in Parallax?',
      loadDocument: (plugin, workspace) {
        if (plugin is! ParallaxDomainPlugin) {
          throw StateError('Level handoff requires ParallaxDomainPlugin.');
        }
        return plugin.loadForLevel(workspace, target: target);
      },
    );
  }

  Future<bool> _handleOpenChunkForLevel(LevelCreatorChunkTarget target) async {
    AuthoringCommand? starterCommand;
    return _navigate(
      EditorNavigationLocation(
        routeId: chunkCreatorRouteId,
        page: target.intent == LevelCreatorChunkIntent.inspectConnection
            ? ChunkCreatorLocation(
                levelId: target.levelId,
                chunkKey: target.chunkKey,
                connectionsExpanded: true,
                showElevationGuides: true,
              )
            : null,
        levelReturnContext: target.returnContext,
      ),
      actionForLoadFailure: (error) =>
          error is ChunkTargetException &&
              error.code == 'flat_starter_material_unavailable'
          ? SnackBarAction(
              label: 'Repair material',
              onPressed: () => _beginDependencyRepair('terrain_materials'),
            )
          : null,
      prompt: target.intent == LevelCreatorChunkIntent.flatStarter
          ? 'Save the Level and background before adding its starter chunk?'
          : 'Open this content in Chunk Creator?',
      loadDocument: (plugin, workspace) async {
        if (plugin is! ChunkDomainPlugin) {
          throw StateError('Chunk target requires the Chunk plugin.');
        }
        final document = await plugin.loadForLevel(
          workspace,
          target: ChunkLevelTarget(
            target.levelId,
            chunkKey: target.intent == LevelCreatorChunkIntent.flatStarter
                ? null
                : target.chunkKey,
            groupId: target.groupId,
          ),
        );
        if (target.intent != LevelCreatorChunkIntent.flatStarter) {
          return document;
        }
        final prior = _pendingStarterIntent;
        final intent =
            prior != null &&
                prior.levelId == target.levelId &&
                (target.groupId == null || prior.groupId == target.groupId)
            ? prior
            : plugin.flatStarterIntentForLevel(
                document,
                levelId: target.levelId,
                groupId: target.groupId,
              );
        _pendingStarterIntent = intent;
        starterCommand = AuthoringCommand(
          kind: 'create_flat_starter',
          payload: {'intent': intent},
        );
        plugin.applyEdit(document, starterCommand!);
        return document;
      },
      onLoaded: () {
        if (starterCommand != null) _controller.applyCommand(starterCommand!);
        if (target.intent == LevelCreatorChunkIntent.connecting) {
          unawaited(_createConnectingChunk(target));
        }
      },
    );
  }

  Future<void> _createConnectingChunk(LevelCreatorChunkTarget target) async {
    final document = _controller.document;
    final scene = _controller.scene;
    if (document is! ChunkV2Document ||
        scene is! ChunkV2Scene ||
        target.chunkKey == null) {
      return;
    }
    try {
      final template = inspectChunkConnectionTemplate(
        document,
        target.chunkKey!,
      );
      final intent = await showDialog<ChunkConnectionCreation>(
        context: context,
        builder: (_) => ChunkConnectionCreationDialog(
          document: document,
          scene: scene,
          template: template,
          workspaceRootPath: _controller.workspacePath,
          initialGroup: target.groupId,
          initialDifficulty: target.difficulty,
        ),
      );
      if (!mounted || intent == null) return;
      _controller.applyCommand(
        AuthoringCommand(
          kind: ChunkDomainPlugin.createConnectingChunkCommandKind,
          payload: {'intent': intent},
        ),
      );
    } on ChunkTargetException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _returnToLevel({required bool save}) async {
    final target = _levelReturnContext;
    if (target == null) return;
    await _navigate(
      EditorNavigationLocation(routeId: levelCreatorRouteId, page: target),
      save: save,
      historyIndex: _navigationHistory.previousIndexWhere(
        (location) =>
            location.routeId == levelCreatorRouteId &&
            location.page is LevelCreatorReturnContext &&
            (location.page! as LevelCreatorReturnContext).levelId ==
                target.levelId,
      ),
      prompt: 'Return to the Level workspace?',
      loadDocument: (plugin, workspace) =>
          _loadExistingLevel(plugin, workspace, target.levelId),
    );
  }

  Future<bool> _beginDependencyRepair(String pluginId) async {
    if (!_canNavigate || _controller.isLoading || _controller.isExporting) {
      return false;
    }
    final target = homeRoutes
        .where((route) => route.pluginId == pluginId)
        .firstOrNull;
    if (target == null ||
        target.id == _selectedRouteId ||
        !_controller.canReapplyIntent) {
      return false;
    }
    setState(() => _repairTransition = true);
    final originController = _controller;
    final originLocation = _captureLocation().page;
    final dependency = _controller.createDependencySession(pluginId);
    // Preflight without touching the originating controller or widget subtree.
    final loaded = await dependency.loadWorkspaceForPlugin(
      pluginId: pluginId,
      loadDocument: (plugin, workspace) => plugin.loadFromRepo(workspace),
    );
    _repairTransition = false;
    if (!mounted || !identical(originController, _controller)) {
      dependency.dispose();
      return false;
    }
    setState(() {});
    if (!mounted ||
        !loaded ||
        !isDependencyRepairSourceReadable(dependency.document)) {
      dependency.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The dependency source could not be opened. Your originating edits are intact.',
            ),
          ),
        );
      }
      return false;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _repairOriginRouteId = _selectedRouteId;
      _repairOriginLocation = originLocation;
      _initialLocation = null;
      _repairController = dependency;
      _selectedRouteId = target.id;
    });
    return true;
  }

  Future<void> _returnFromRepair({required bool save}) async {
    final dependency = _repairController;
    final originRouteId = _repairOriginRouteId;
    if (dependency == null || originRouteId == null || _repairTransition) {
      return;
    }
    if (save &&
        (_currentPageHasLocalDraftChanges() ||
            dependency.pendingChanges.hasChanges)) {
      final outcome = await _handleSaveRequested();
      if (!mounted ||
          !outcome.permitsDeparture ||
          _currentPageHasLocalDraftChanges()) {
        return;
      }
    } else if (!save &&
        !await _resolvePendingDeparture(
          promptLine: 'Return from dependency repair?',
        )) {
      return;
    }
    if (!mounted) return;
    if (dependency.requiresSavedRefresh ||
        dependency.requiresTransactionRecovery) {
      return;
    }
    setState(() {
      _selectedRouteId = originRouteId;
      _initialLocation = _repairOriginLocation;
      _repairOriginLocation = null;
      _repairOriginRouteId = null;
      _repairController = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => dependency.dispose());
    if (save || dependency.sourceWriteCount > 0) await _handleReapplyIntent();
  }

  Future<void> _handleReapplyIntent() async {
    final controller = _controller;
    var plan = await controller.reapplyIntent(reviewOnly: true);
    while (plan != null && identical(controller, _controller)) {
      if (!mounted) return;
      final choices = await showAuthoringConflictDialog(context, plan);
      if (!mounted || choices == null) return;
      plan = await controller.reapplyIntent(resolutions: choices);
      if (controller.recoveryCopy == null) return;
      if (!mounted) return;
      if (controller.recoveryError != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(controller.recoveryError!)));
        return;
      }
    }
  }

  // The shell exposes one visible reload surface, but some pages need to
  // coordinate extra local state during reload. When the active page implements
  // [EditorPageReloadHandler], its availability becomes the source of truth.
  bool get _canReloadCurrentPage {
    if (_isShowingDiscardDialog ||
        _isSavingCurrentPage ||
        _isCurrentPageShellLocked) {
      return false;
    }
    final pageReloadHandler = _currentPageReloadHandler();
    if (pageReloadHandler != null) {
      return pageReloadHandler.canReloadEditorPage;
    }
    return !_controller.isLoading && !_controller.isExporting;
  }

  bool get _canSaveCurrentPage {
    if (_isShowingDiscardDialog ||
        _isSavingCurrentPage ||
        _isCurrentPageShellLocked ||
        _controller.requiresSourceReconciliation ||
        _controller.isLoading ||
        _controller.isExporting) {
      return false;
    }
    return _currentPageSaveHandler?.canSaveEditorPage ?? false;
  }

  bool get _canUndoCurrentPage {
    if (_isShowingDiscardDialog ||
        _isSavingCurrentPage ||
        _isCurrentPageShellLocked ||
        _controller.isLoading ||
        _controller.isExporting) {
      return false;
    }
    final pageShortcutHandler = _currentPageSessionShortcutHandler();
    return pageShortcutHandler?.canHandleUndoSessionShortcut ??
        _controller.canUndo;
  }

  bool get _canRedoCurrentPage {
    if (_isShowingDiscardDialog ||
        _isSavingCurrentPage ||
        _isCurrentPageShellLocked ||
        _controller.isLoading ||
        _controller.isExporting) {
      return false;
    }
    final pageShortcutHandler = _currentPageSessionShortcutHandler();
    return pageShortcutHandler?.canHandleRedoSessionShortcut ??
        _controller.canRedo;
  }

  Future<void> _handleReloadRequested() async {
    if (!_canReloadCurrentPage) {
      return;
    }
    // Reload is destructive to any unsaved session/page-local draft state, so
    // it goes through the same discard guard as route changes.
    final canLeave = await _resolvePendingDeparture(
      promptLine: 'Reload saved sources?',
    );
    if (!mounted || !canLeave) {
      return;
    }
    await _reloadCurrentRoute();
  }

  Future<EditorPageSaveResult> _handleSaveRequested() async {
    final pageSaveHandler = _currentPageSaveHandler;
    if (!_canSaveCurrentPage || pageSaveHandler == null) {
      return EditorPageSaveResult.blocked;
    }
    setState(() {
      _isSavingCurrentPage = true;
    });
    try {
      return await pageSaveHandler.saveEditorPage();
    } finally {
      if (mounted) {
        setState(() {
          _isSavingCurrentPage = false;
        });
      }
    }
  }

  Future<AppExitResponse> _handleAppExitRequested() async {
    if (!mounted) {
      return AppExitResponse.exit;
    }
    if (_buildService.isRunning || _isPreparingBuild) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wait for Build to finish, or cancel it from the Build report before closing.',
          ),
        ),
      );
      return AppExitResponse.cancel;
    }
    if (_repairController != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Return from dependency repair before closing to resolve your retained edits.',
          ),
        ),
      );
      return AppExitResponse.cancel;
    }
    if (_controller.requiresSavedRefresh &&
        !_currentPageHasLocalDraftChanges()) {
      if (_isShowingDiscardDialog) return AppExitResponse.cancel;
      _isShowingDiscardDialog = true;
      try {
        final close = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Changes are saved'),
            content: const Text(
              'The files were saved, but the editor could not refresh them. Reopening will load the saved sources.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay and retry refresh'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Close with saved files'),
              ),
            ],
          ),
        );
        return close == true ? AppExitResponse.exit : AppExitResponse.cancel;
      } finally {
        _isShowingDiscardDialog = false;
      }
    }
    // App-close requests should respect the same unsaved-work guard as route
    // changes instead of bypassing the shell.
    final canExit = await _resolvePendingDeparture(
      promptLine: 'Close the editor?',
    );
    return canExit ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  Future<bool> _resolvePendingDeparture({required String promptLine}) async {
    if (_isCurrentPageShellLocked) return false;
    final pendingChanges = _controller.pendingChanges;
    final hasLocalDraftChanges = _currentPageHasLocalDraftChanges();
    if (!pendingChanges.hasChanges && !hasLocalDraftChanges) {
      return true;
    }
    if (_isShowingDiscardDialog) {
      return false;
    }

    final contentLines = <String>[
      promptLine,
      _pendingChangesSummary,
      ..._pendingChangeDescriptions,
      '',
      'Save or discard all changes in this editor before continuing.',
    ];
    _isShowingDiscardDialog = true;
    try {
      final decision = await showDialog<EditorPendingChangesAction>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Unsaved changes'),
            content: Text(contentLines.join('\n')),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext)
                        .pop(EditorPendingChangesAction.cancel),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext)
                        .pop(EditorPendingChangesAction.discard),
                child: const Text('Discard all changes'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext)
                        .pop(EditorPendingChangesAction.save),
                child: const Text('Save all changes'),
              ),
            ],
          );
        },
      );
      if (decision == EditorPendingChangesAction.discard) return true;
      if (decision != EditorPendingChangesAction.save || !mounted) return false;
      // The modal has closed; save failures keep the current editing context.
      _isShowingDiscardDialog = false;
      final outcome = await _handleSaveRequested();
      return outcome.permitsDeparture && !_currentPageHasLocalDraftChanges();
    } finally {
      _isShowingDiscardDialog = false;
    }
  }

  String get _pendingChangesSummary {
    final page = _currentPageState;
    if (page is EditorPagePendingChangesSummary) {
      return page.pendingChangesSummary;
    }
    final count = _controller.pendingChanges.changedItemIds.length;
    if (count == 0 && !_currentPageHasLocalDraftChanges()) return 'Saved';
    return count == 0 ? 'Unsaved input changes' : '$count items have changes';
  }

  List<String> get _pendingChangeDescriptions {
    final page = _currentPageState;
    if (page is EditorPagePendingChangesSummary) {
      return page.pendingChangeDescriptions;
    }
    return _controller.pendingChanges.changedItemIds;
  }

  Future<void> _showTransactionRecovery() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Source transaction recovery'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: SelectableText(
            [
              _controller.lastExportResult?.message ??
                  'Review the transaction outcome before another write.',
              for (final artifact
                  in _controller.lastExportResult?.artifacts ?? [])
                '${artifact.title}\n${artifact.content}',
            ].join('\n\n'),
          ),
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

  bool _currentPageHasLocalDraftChanges() {
    final pageState = _currentPageState;
    if (pageState is! EditorPageLocalDraftState) {
      return false;
    }
    return pageState.hasLocalDraftChanges;
  }

  bool _handleUndoShortcut() {
    if (_isCurrentPageShellLocked || _isShowingDiscardDialog) return false;
    final pageShortcutHandler = _currentPageSessionShortcutHandler();
    if (_focusedEditableTextConsumesShortcut(
          currentPageContext: _currentPageContext(),
          allowCurrentPageShortcutHandler: pageShortcutHandler != null,
        ) ||
        _controller.isLoading ||
        _controller.isExporting) {
      return false;
    }
    if (pageShortcutHandler?.handleUndoSessionShortcut() == true) {
      return true;
    }
    if (!_controller.canUndo) {
      return false;
    }
    _controller.undo();
    return true;
  }

  bool _handleRedoShortcut() {
    if (_isCurrentPageShellLocked || _isShowingDiscardDialog) return false;
    final pageShortcutHandler = _currentPageSessionShortcutHandler();
    if (_focusedEditableTextConsumesShortcut(
          currentPageContext: _currentPageContext(),
          allowCurrentPageShortcutHandler: pageShortcutHandler != null,
        ) ||
        _controller.isLoading ||
        _controller.isExporting) {
      return false;
    }
    if (pageShortcutHandler?.handleRedoSessionShortcut() == true) {
      return true;
    }
    if (!_controller.canRedo) {
      return false;
    }
    _controller.redo();
    return true;
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (!_shellRouteCanHandleGlobalShortcuts() || event is! KeyDownEvent) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isShiftPressed &&
        !_focusedEditableTextOwnsInput() &&
        (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight)) {
      if (!_canNavigate) return false;
      final forward = event.logicalKey == LogicalKeyboardKey.arrowRight;
      if (forward
          ? !_navigationHistory.canGoForward
          : !_navigationHistory.canGoBack) {
        return false;
      }
      unawaited(_handleHistoryNavigation(forward: forward));
      return true;
    }
    final playtestHandler = _currentPagePlaytestHandler();
    if (playtestHandler != null &&
        !_isModifiedShortcut() &&
        !_focusedEditableTextOwnsInput() &&
        playtestHandler.handlePlaytestShortcut(event.logicalKey)) {
      return true;
    }
    if (!HardwareKeyboard.instance.isControlPressed) return false;
    if (event.logicalKey == LogicalKeyboardKey.keyS &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      unawaited(_handleSaveRequested());
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (_focusedEditableTextOwnsInput()) return false;
      return HardwareKeyboard.instance.isShiftPressed
          ? _handleRedoShortcut()
          : _handleUndoShortcut();
    }
    if (event.logicalKey == LogicalKeyboardKey.keyY) {
      if (_focusedEditableTextOwnsInput()) return false;
      return _handleRedoShortcut();
    }
    return false;
  }

  void _handleAppLifecycleState(AppLifecycleState state) {
    _currentPagePlaytestHandler()?.handlePlaytestAppLifecycleState(state);
  }

  bool _isModifiedShortcut() {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed;
  }

  bool _focusedEditableTextOwnsInput() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext != null &&
        _focusedEditableTextContext(focusContext) != null;
  }

  bool _shellRouteCanHandleGlobalShortcuts() {
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  // Keep shell undo/redo out of focused text fields so normal text editing
  // shortcuts win. The active page can still opt into handling the shortcut if
  // the focused field belongs to that page's local draft workflow.
  bool _focusedEditableTextConsumesShortcut({
    required BuildContext? currentPageContext,
    required bool allowCurrentPageShortcutHandler,
  }) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    final editableContext = _focusedEditableTextContext(focusContext);
    if (editableContext == null) {
      return false;
    }
    if (!allowCurrentPageShortcutHandler || currentPageContext == null) {
      return true;
    }
    return !_isDescendantContext(
      descendant: editableContext,
      ancestor: currentPageContext,
    );
  }

  EditorPageSessionShortcutHandler? _currentPageSessionShortcutHandler() {
    final pageState = _currentPageState;
    if (pageState is! EditorPageSessionShortcutHandler) {
      return null;
    }
    return pageState;
  }

  EditorPagePlaytestHandler? _currentPagePlaytestHandler() {
    final pageState = _currentPageState;
    return pageState is EditorPagePlaytestHandler ? pageState : null;
  }

  bool get _isCurrentPageShellLocked =>
      _buildService.isRunning ||
      _controller.isLoading ||
      _controller.isExporting ||
      _isSavingCurrentPage ||
      _controller.requiresSavedRefresh ||
      _controller.requiresTransactionRecovery ||
      (_currentPagePlaytestHandler()?.locksEditorShell ?? false);

  EditorPageReloadHandler? _currentPageReloadHandler() {
    final pageState = _currentPageState;
    if (pageState is! EditorPageReloadHandler) {
      return null;
    }
    return pageState;
  }

  EditorPageSaveHandler? get _currentPageSaveHandler {
    final pageState = _currentPageState;
    if (pageState is! EditorPageSaveHandler) {
      return null;
    }
    return pageState;
  }

  BuildContext? _currentPageContext() {
    return _selectedRouteBinding.currentContext;
  }

  _EditorHomeRouteBinding get _selectedRouteBinding =>
      _requireRouteBinding(_selectedRouteId);

  Object? get _currentPageState => _selectedRouteBinding.currentState;

  _EditorHomeRouteBinding _requireRouteBinding(String routeId) {
    final routeBinding = _routeBindings[routeId];
    if (routeBinding == null) {
      throw StateError('Unknown editor home route id: $routeId');
    }
    return routeBinding;
  }

  // Most routes reload by asking the shared session to reread the current
  // plugin/workspace. Pages with extra local projections, such as prefab
  // authoring, can override that through [EditorPageReloadHandler].
  Future<void> _reloadCurrentRoute() async {
    final pageReloadHandler = _currentPageReloadHandler();
    if (pageReloadHandler != null) {
      await pageReloadHandler.reloadEditorPage();
      return;
    }
    await _controller.loadWorkspace();
  }

  BuildContext? _focusedEditableTextContext(BuildContext focusContext) {
    if (focusContext.widget is EditableText) {
      return focusContext;
    }
    BuildContext? editableContext;
    focusContext.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        editableContext = element;
        return false;
      }
      return true;
    });
    return editableContext;
  }

  bool _isDescendantContext({
    required BuildContext descendant,
    required BuildContext ancestor,
  }) {
    if (identical(descendant, ancestor)) {
      return true;
    }
    var isDescendant = false;
    descendant.visitAncestorElements((element) {
      if (identical(element, ancestor)) {
        isDescendant = true;
        return false;
      }
      return true;
    });
    return isDescendant;
  }
}

/// Stable shell-owned binding for one top-level route entry.
///
/// Keeps the route definition together with the page key the shell uses to
/// inspect route-local draft/shortcut state.
class _EditorHomeRouteBinding {
  const _EditorHomeRouteBinding({required this.route, required this.pageKey});

  final EditorHomeRoute route;
  final GlobalKey pageKey;

  Object? get currentState => pageKey.currentState;

  BuildContext? get currentContext => pageKey.currentContext;

  Widget buildPage(
    EditorSessionController controller, {
    required EditorHomeRouteNavigation navigation,
  }) {
    return route.buildPage(
      key: pageKey,
      controller: controller,
      navigation: navigation,
    );
  }
}

/// Presentation-only controls row for the editor shell.
///
/// This widget renders the actions shared by every top-level editor route.
///
/// [EditorHomePage] keeps route switching, discard guards, and page-action
/// delegation centralized so route widgets only own domain-specific behavior.
class _EditorHomeShellControls extends StatelessWidget {
  const _EditorHomeShellControls({
    required this.selectedRouteId,
    required this.shellLocked,
    required this.onBack,
    required this.onForward,
    required this.backLabel,
    required this.forwardLabel,
    required this.canReloadCurrentPage,
    required this.canSaveCurrentPage,
    required this.canUndoCurrentPage,
    required this.canRedoCurrentPage,
    required this.isLoading,
    required this.isExporting,
    required this.hasPendingChanges,
    required this.pendingSummary,
    required this.pendingItemCount,
    required this.pendingFileCount,
    required this.pendingChangesError,
    required this.errorCount,
    required this.warningCount,
    required this.onReloadPressed,
    required this.onSavePressed,
    required this.onUndoPressed,
    required this.onRedoPressed,
    required this.onRouteSelected,
    required this.onBuildPressed,
    required this.buildStatus,
  });

  final String selectedRouteId;
  final bool shellLocked;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final String? backLabel;
  final String? forwardLabel;
  final bool canReloadCurrentPage;
  final bool canSaveCurrentPage;
  final bool canUndoCurrentPage;
  final bool canRedoCurrentPage;
  final bool isLoading;
  final bool isExporting;
  final bool hasPendingChanges;
  final String pendingSummary;
  final int pendingItemCount;
  final int pendingFileCount;
  final String? pendingChangesError;
  final int errorCount;
  final int warningCount;
  final Future<void> Function() onReloadPressed;
  final Future<void> Function() onSavePressed;
  final bool Function() onUndoPressed;
  final bool Function() onRedoPressed;
  final Future<void> Function(String routeId) onRouteSelected;
  final VoidCallback? onBuildPressed;
  final String buildStatus;

  @override
  Widget build(BuildContext context) {
    final reloadButton = FilledButton.icon(
      key: const ValueKey<String>('reload_editor_page_button'),
      onPressed: canReloadCurrentPage
          ? () {
              onReloadPressed();
            }
          : null,
      icon: const Icon(Icons.sync),
      label: const Text('Reload'),
    );
    final saveButton = FilledButton.icon(
      key: const ValueKey<String>('apply_editor_page_button'),
      onPressed: canSaveCurrentPage
          ? () {
              unawaited(onSavePressed());
            }
          : null,
      icon: const Icon(Icons.save_outlined),
      label: const Text('Save'),
    );
    final undoButton = OutlinedButton.icon(
      key: const ValueKey<String>('undo_editor_page_button'),
      onPressed: canUndoCurrentPage ? onUndoPressed : null,
      icon: const Icon(Icons.undo),
      label: const Text('Undo'),
    );
    final redoButton = OutlinedButton.icon(
      key: const ValueKey<String>('redo_editor_page_button'),
      onPressed: canRedoCurrentPage ? onRedoPressed : null,
      icon: const Icon(Icons.redo),
      label: const Text('Redo'),
    );
    final routeSelector = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF4A6074)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedRouteId,
            items: [
              for (final route in homeRoutes)
                DropdownMenuItem<String>(
                  value: route.id,
                  child: Text(
                    route.label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: shellLocked
                ? null
                : (value) {
                    if (value == null || value == selectedRouteId) return;
                    onRouteSelected(value);
                  },
          ),
        ),
      ),
    );

    final routeAndActions = <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            key: const ValueKey('editor_navigation_back'),
            tooltip: backLabel == null
                ? 'Back (Alt+Left)'
                : 'Back to $backLabel (Alt+Left)',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
          IconButton.outlined(
            key: const ValueKey('editor_navigation_forward'),
            tooltip: forwardLabel == null
                ? 'Forward (Alt+Right)'
                : 'Forward to $forwardLabel (Alt+Right)',
            onPressed: onForward,
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
      SizedBox(
        width: 200 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.2),
        child: routeSelector,
      ),
      reloadButton,
      saveButton,
      undoButton,
      redoButton,
      Tooltip(
        message: 'Generated content: $buildStatus',
        child: OutlinedButton.icon(
          key: const ValueKey('build_game_content_button'),
          onPressed: onBuildPressed,
          icon: const Icon(Icons.build_outlined),
          label: Text('Build · $buildStatus'),
        ),
      ),
    ];
    final status = _EditorHomeShellStatus(
      isLoading: isLoading,
      isExporting: isExporting,
      hasPendingChanges: hasPendingChanges,
      pendingSummary: pendingSummary,
      pendingItemCount: pendingItemCount,
      pendingFileCount: pendingFileCount,
      pendingChangesError: pendingChangesError,
      errorCount: errorCount,
      warningCount: warningCount,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1360 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: routeAndActions,
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: status),
            ],
          );
        }

        return Row(
          children: <Widget>[
            ...routeAndActions.expand(
              (action) => <Widget>[action, const SizedBox(width: 12)],
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: status,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact session status rendered at the trailing edge of the shared toolbar.
class _EditorHomeShellStatus extends StatelessWidget {
  const _EditorHomeShellStatus({
    required this.isLoading,
    required this.isExporting,
    required this.hasPendingChanges,
    required this.pendingSummary,
    required this.pendingItemCount,
    required this.pendingFileCount,
    required this.pendingChangesError,
    required this.errorCount,
    required this.warningCount,
  });

  final bool isLoading;
  final bool isExporting;
  final bool hasPendingChanges;
  final String pendingSummary;
  final int pendingItemCount;
  final int pendingFileCount;
  final String? pendingChangesError;
  final int errorCount;
  final int warningCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pendingError = pendingChangesError;
    late final String pendingLabel;
    late final IconData pendingIcon;
    late final Color pendingBackgroundColor;
    if (pendingError != null) {
      pendingLabel = 'Pending status unavailable';
      pendingIcon = Icons.error_outline;
      pendingBackgroundColor = colorScheme.errorContainer;
    } else if (hasPendingChanges) {
      pendingLabel = pendingSummary;
      pendingIcon = Icons.pending_actions_outlined;
      pendingBackgroundColor = colorScheme.secondaryContainer;
    } else {
      pendingLabel = 'Saved';
      pendingIcon = Icons.check_circle_outline;
      pendingBackgroundColor = colorScheme.primaryContainer;
    }

    late final IconData validationIcon;
    late final Color validationBackgroundColor;
    if (errorCount > 0) {
      validationIcon = Icons.error_outline;
      validationBackgroundColor = colorScheme.errorContainer;
    } else if (warningCount > 0) {
      validationIcon = Icons.warning_amber_outlined;
      validationBackgroundColor = colorScheme.tertiaryContainer;
    } else {
      validationIcon = Icons.verified_outlined;
      validationBackgroundColor = colorScheme.surfaceContainerHighest;
    }

    final pendingStatus = Chip(
      key: const ValueKey<String>('editor_toolbar_pending_status'),
      avatar: Icon(pendingIcon, size: 18),
      label: Text(pendingLabel),
      backgroundColor: pendingBackgroundColor,
      visualDensity: VisualDensity.compact,
    );
    final validationStatus = Chip(
      key: const ValueKey<String>('editor_toolbar_validation_status'),
      avatar: Icon(validationIcon, size: 18),
      label: Text(
        '${_countLabel(errorCount, 'error')} · '
        '${_countLabel(warningCount, 'warning')}',
      ),
      backgroundColor: validationBackgroundColor,
      visualDensity: VisualDensity.compact,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isLoading || isExporting) ...<Widget>[
          const SizedBox.square(
            key: ValueKey<String>('editor_toolbar_progress'),
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(isExporting ? 'Saving…' : 'Reloading…'),
          const SizedBox(width: 12),
        ],
        if (pendingError == null)
          pendingStatus
        else
          Tooltip(message: pendingError, child: pendingStatus),
        const SizedBox(width: 8),
        validationStatus,
      ],
    );
  }
}

String _countLabel(int count, String singular) {
  return '$count ${count == 1 ? singular : '${singular}s'}';
}
