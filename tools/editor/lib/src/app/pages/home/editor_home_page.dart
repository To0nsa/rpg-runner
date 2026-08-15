import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../parallax/parallax_domain_models.dart';
import '../../../parallax/parallax_domain_plugin.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';
import 'home_routes.dart';

/// Top-level editor shell that coordinates route selection around one shared
/// [EditorSessionController].
///
/// This page owns shell concerns only: selecting the active top-level route,
/// guarding destructive transitions, and routing shell-level undo/redo
/// shortcuts. Domain load/edit/export behavior still flows through the
/// selected plugin and page.
class EditorHomePage extends StatefulWidget {
  const EditorHomePage({super.key, required this.controller});

  /// Shared authoring session used by every top-level route.
  final EditorSessionController controller;

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  late final AppLifecycleListener _appLifecycleListener;
  // The shell owns stable page keys so it can query the active route for local
  // draft state, shortcut handling, and reload delegation without reintroducing
  // route-id switches elsewhere in the file.
  late final Map<String, _EditorHomeRouteBinding> _routeBindings;
  // Route/app-exit requests can all ask for discard confirmation;
  // keep them serialized so the shell never stacks competing dialogs.
  bool _isShowingDiscardDialog = false;
  bool _isApplyingCurrentPage = false;
  String _selectedRouteId = entitiesRouteId;
  String? _initialPrefabKey;

  @override
  void initState() {
    super.initState();
    _routeBindings = <String, _EditorHomeRouteBinding>{
      for (final route in homeRoutes)
        route.id: _EditorHomeRouteBinding(route: route, pageKey: GlobalKey()),
    };
    _appLifecycleListener = AppLifecycleListener(
      onExitRequested: _handleAppExitRequested,
    );
    // The shell handles cross-route undo/redo shortcuts globally, then routes
    // them back into the active page/session when appropriate.
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    // Route selection is shell-owned, but plugin selection still lives in the
    // shared session controller. Sync them once after the first frame so the
    // initial page and initial plugin contract start coherent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPluginForRoute(_selectedRouteId);
    });
  }

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EditorHomeShellControls(
                    selectedRouteId: _selectedRouteId,
                    canReloadCurrentPage: _canReloadCurrentPage,
                    canApplyCurrentPage: _canApplyCurrentPage,
                    canUndoCurrentPage: _canUndoCurrentPage,
                    canRedoCurrentPage: _canRedoCurrentPage,
                    isLoading: widget.controller.isLoading,
                    isExporting: widget.controller.isExporting,
                    hasPendingChanges:
                        widget.controller.pendingChanges.hasChanges,
                    pendingItemCount:
                        widget.controller.pendingChanges.changedItemIds.length,
                    pendingFileCount:
                        widget.controller.pendingChanges.fileDiffs.length,
                    pendingChangesError: widget.controller.pendingChangesError,
                    errorCount: widget.controller.errorCount,
                    warningCount: widget.controller.warningCount,
                    onReloadPressed: _handleReloadRequested,
                    onApplyPressed: _handleApplyRequested,
                    onUndoPressed: _handleUndoShortcut,
                    onRedoPressed: _handleRedoShortcut,
                    onRouteSelected: _handleRouteSelectionRequested,
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildSelectedRoutePage()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedRoutePage() {
    final routeBinding = _selectedRouteBinding;
    return routeBinding.buildPage(
      widget.controller,
      navigation: EditorHomeRouteNavigation(
        initialPrefabKey: _initialPrefabKey,
        onOpenOwningPrefab: (prefabKey) {
          unawaited(_handleOpenOwningPrefabRequested(prefabKey));
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
    final routeBinding = _requireRouteBinding(routeId);
    final requiredPluginId = routeBinding.route.pluginId;
    if (requiredPluginId == widget.controller.selectedPluginId) {
      return;
    }
    final hasPlugin = widget.controller.availablePlugins.any(
      (plugin) => plugin.id == requiredPluginId,
    );
    if (!hasPlugin) {
      throw StateError(
        'Editor home route "$routeId" requires plugin '
        '"$requiredPluginId", but it is not registered.',
      );
    }
    widget.controller.setSelectedPluginId(requiredPluginId);
  }

  Future<void> _handleRouteSelectionRequested(String routeId) async {
    final canLeave = await _confirmDiscardPendingChanges(
      promptLine: 'Leave this page without saving?',
      confirmLabel: 'Discard and leave',
    );
    if (!mounted || !canLeave) {
      return;
    }
    setState(() {
      _selectedRouteId = routeId;
      _initialPrefabKey = null;
    });
    _syncPluginForRoute(routeId);
  }

  Future<void> _handleOpenOwningPrefabRequested(String prefabKey) async {
    final targetPrefabKey = prefabKey.trim();
    if (targetPrefabKey.isEmpty || widget.controller.isLoading) {
      return;
    }
    final canLeave = await _confirmDiscardPendingChanges(
      promptLine: 'Open Prefab Creator without saving this chunk?',
      confirmLabel: 'Discard and open prefab',
    );
    if (!mounted || !canLeave) {
      return;
    }

    final loaded = await widget.controller.loadWorkspaceForPlugin(
      pluginId: PrefabDomainPlugin.pluginId,
      loadDocument: (plugin, workspace) async {
        if (plugin is! PrefabDomainPlugin) {
          throw StateError(
            'Owning-prefab navigation requires PrefabDomainPlugin, but '
            '${plugin.runtimeType} is registered.',
          );
        }
        final document = await plugin.loadV3FromRepo(workspace);
        final containsOwner = document.data.prefabs.any(
          (prefab) => prefab.prefabKey == targetPrefabKey,
        );
        if (!containsOwner) {
          throw StateError(
            'Prefab-v3 owner "$targetPrefabKey" no longer exists on disk.',
          );
        }
        return document;
      },
    );
    if (!mounted) {
      return;
    }
    if (!loaded) {
      final detail = widget.controller.loadError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail == null
                ? 'Prefab-v3 owner could not be opened.'
                : 'Prefab-v3 owner could not be opened: $detail',
          ),
        ),
      );
      return;
    }
    setState(() {
      _initialPrefabKey = targetPrefabKey;
      _selectedRouteId = prefabCreatorRouteId;
    });
  }

  Future<void> _handleOpenParallaxForLevelRequested(
    ParallaxLevelTarget target,
  ) async {
    if (target.levelId.trim().isEmpty ||
        target.parallaxThemeId.trim().isEmpty ||
        widget.controller.isLoading ||
        widget.controller.isExporting) {
      return;
    }
    final canLeave = await _confirmDiscardPendingChanges(
      promptLine: 'Open this saved level in Parallax?',
      confirmLabel: 'Open Parallax',
    );
    if (!mounted || !canLeave) return;

    final loaded = await widget.controller.loadWorkspaceForPlugin(
      pluginId: ParallaxDomainPlugin.pluginId,
      loadDocument: (plugin, workspace) {
        if (plugin is! ParallaxDomainPlugin) {
          throw StateError(
            'Level handoff requires ParallaxDomainPlugin, but '
            '${plugin.runtimeType} is registered.',
          );
        }
        return plugin.loadForLevel(workspace, target: target);
      },
    );
    if (!mounted) return;
    if (!loaded) {
      final detail = widget.controller.loadError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail == null
                ? 'The Level/theme target could not be opened in Parallax.'
                : 'The Level/theme target could not be opened: $detail',
          ),
        ),
      );
      return;
    }
    setState(() {
      _selectedRouteId = parallaxEditorRouteId;
      _initialPrefabKey = null;
    });
  }

  // The shell exposes one visible reload surface, but some pages need to
  // coordinate extra local state during reload. When the active page implements
  // [EditorPageReloadHandler], its availability becomes the source of truth.
  bool get _canReloadCurrentPage {
    if (_isShowingDiscardDialog || _isApplyingCurrentPage) {
      return false;
    }
    final pageReloadHandler = _currentPageReloadHandler();
    if (pageReloadHandler != null) {
      return pageReloadHandler.canReloadEditorPage;
    }
    return !widget.controller.isLoading && !widget.controller.isExporting;
  }

  bool get _canApplyCurrentPage {
    if (_isShowingDiscardDialog ||
        _isApplyingCurrentPage ||
        widget.controller.isLoading ||
        widget.controller.isExporting) {
      return false;
    }
    return _currentPageApplyHandler?.canApplyEditorPage ?? false;
  }

  bool get _canUndoCurrentPage {
    if (_isShowingDiscardDialog ||
        _isApplyingCurrentPage ||
        widget.controller.isLoading ||
        widget.controller.isExporting) {
      return false;
    }
    final pageShortcutHandler = _currentPageSessionShortcutHandler();
    return pageShortcutHandler?.canHandleUndoSessionShortcut ??
        widget.controller.canUndo;
  }

  bool get _canRedoCurrentPage {
    if (_isShowingDiscardDialog ||
        _isApplyingCurrentPage ||
        widget.controller.isLoading ||
        widget.controller.isExporting) {
      return false;
    }
    final pageShortcutHandler = _currentPageSessionShortcutHandler();
    return pageShortcutHandler?.canHandleRedoSessionShortcut ??
        widget.controller.canRedo;
  }

  Future<void> _handleReloadRequested() async {
    if (!_canReloadCurrentPage) {
      return;
    }
    // Reload is destructive to any unsaved session/page-local draft state, so
    // it goes through the same discard guard as route changes.
    final canLeave = await _confirmDiscardPendingChanges(
      promptLine: 'Reload from disk without saving?',
      confirmLabel: 'Discard and reload',
    );
    if (!mounted || !canLeave) {
      return;
    }
    await _reloadCurrentRoute();
  }

  Future<void> _handleApplyRequested() async {
    final pageApplyHandler = _currentPageApplyHandler;
    if (!_canApplyCurrentPage || pageApplyHandler == null) {
      return;
    }
    setState(() {
      _isApplyingCurrentPage = true;
    });
    try {
      await pageApplyHandler.applyEditorPage();
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingCurrentPage = false;
        });
      }
    }
  }

  Future<AppExitResponse> _handleAppExitRequested() async {
    if (!mounted) {
      return AppExitResponse.exit;
    }
    // App-close requests should respect the same unsaved-work guard as route
    // changes instead of bypassing the shell.
    final canExit = await _confirmDiscardPendingChanges(
      promptLine: 'Close the editor without saving?',
      confirmLabel: 'Discard and exit',
    );
    return canExit ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  Future<bool> _confirmDiscardPendingChanges({
    required String promptLine,
    required String confirmLabel,
  }) async {
    final pendingChanges = widget.controller.pendingChanges;
    final hasLocalDraftChanges = _currentPageHasLocalDraftChanges();
    if (!pendingChanges.hasChanges && !hasLocalDraftChanges) {
      return true;
    }
    if (_isShowingDiscardDialog) {
      return false;
    }

    final changedItems = pendingChanges.changedItemIds.length;
    final changedFiles = pendingChanges.fileDiffs.length;
    // The dialog summarizes both kinds of unsaved work the shell understands:
    // committed session changes from the controller and route-local draft state
    // that has not been promoted into the session yet.
    final contentLines = <String>[promptLine, ''];
    if (pendingChanges.hasChanges) {
      contentLines.add(
        'Pending session changes: $changedItems item(s), $changedFiles file(s).',
      );
    }
    if (hasLocalDraftChanges) {
      contentLines.add('This page also has unsaved draft form/input changes.');
    }
    _isShowingDiscardDialog = true;
    try {
      final decision = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Discard unsaved changes?'),
            content: Text(contentLines.join('\n')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
      return decision ?? false;
    } finally {
      _isShowingDiscardDialog = false;
    }
  }

  bool _currentPageHasLocalDraftChanges() {
    final pageState = _currentPageState;
    if (pageState is! EditorPageLocalDraftState) {
      return false;
    }
    return pageState.hasLocalDraftChanges;
  }

  bool _handleUndoShortcut() {
    final pageShortcutHandler = _currentPageSessionShortcutHandler();
    if (_focusedEditableTextConsumesShortcut(
          currentPageContext: _currentPageContext(),
          allowCurrentPageShortcutHandler: pageShortcutHandler != null,
        ) ||
        widget.controller.isLoading ||
        widget.controller.isExporting) {
      return false;
    }
    if (pageShortcutHandler?.handleUndoSessionShortcut() == true) {
      return true;
    }
    if (!widget.controller.canUndo) {
      return false;
    }
    widget.controller.undo();
    return true;
  }

  bool _handleRedoShortcut() {
    final pageShortcutHandler = _currentPageSessionShortcutHandler();
    if (_focusedEditableTextConsumesShortcut(
          currentPageContext: _currentPageContext(),
          allowCurrentPageShortcutHandler: pageShortcutHandler != null,
        ) ||
        widget.controller.isLoading ||
        widget.controller.isExporting) {
      return false;
    }
    if (pageShortcutHandler?.handleRedoSessionShortcut() == true) {
      return true;
    }
    if (!widget.controller.canRedo) {
      return false;
    }
    widget.controller.redo();
    return true;
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (!_shellRouteCanHandleGlobalShortcuts() ||
        event is! KeyDownEvent ||
        !HardwareKeyboard.instance.isControlPressed) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      return HardwareKeyboard.instance.isShiftPressed
          ? _handleRedoShortcut()
          : _handleUndoShortcut();
    }
    if (event.logicalKey == LogicalKeyboardKey.keyY) {
      return _handleRedoShortcut();
    }
    return false;
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

  EditorPageReloadHandler? _currentPageReloadHandler() {
    final pageState = _currentPageState;
    if (pageState is! EditorPageReloadHandler) {
      return null;
    }
    return pageState;
  }

  EditorPageApplyHandler? get _currentPageApplyHandler {
    final pageState = _currentPageState;
    if (pageState is! EditorPageApplyHandler) {
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
    await widget.controller.loadWorkspace();
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
    required this.canReloadCurrentPage,
    required this.canApplyCurrentPage,
    required this.canUndoCurrentPage,
    required this.canRedoCurrentPage,
    required this.isLoading,
    required this.isExporting,
    required this.hasPendingChanges,
    required this.pendingItemCount,
    required this.pendingFileCount,
    required this.pendingChangesError,
    required this.errorCount,
    required this.warningCount,
    required this.onReloadPressed,
    required this.onApplyPressed,
    required this.onUndoPressed,
    required this.onRedoPressed,
    required this.onRouteSelected,
  });

  final String selectedRouteId;
  final bool canReloadCurrentPage;
  final bool canApplyCurrentPage;
  final bool canUndoCurrentPage;
  final bool canRedoCurrentPage;
  final bool isLoading;
  final bool isExporting;
  final bool hasPendingChanges;
  final int pendingItemCount;
  final int pendingFileCount;
  final String? pendingChangesError;
  final int errorCount;
  final int warningCount;
  final Future<void> Function() onReloadPressed;
  final Future<void> Function() onApplyPressed;
  final bool Function() onUndoPressed;
  final bool Function() onRedoPressed;
  final Future<void> Function(String routeId) onRouteSelected;

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
    final applyButton = FilledButton.icon(
      key: const ValueKey<String>('apply_editor_page_button'),
      onPressed: canApplyCurrentPage
          ? () {
              unawaited(onApplyPressed());
            }
          : null,
      icon: const Icon(Icons.save_outlined),
      label: const Text('Apply To Files'),
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
            onChanged: (value) {
              if (value == null || value == selectedRouteId) {
                return;
              }
              onRouteSelected(value);
            },
          ),
        ),
      ),
    );

    final routeAndActions = <Widget>[
      SizedBox(width: 160, child: routeSelector),
      reloadButton,
      applyButton,
      undoButton,
      redoButton,
    ];
    final status = _EditorHomeShellStatus(
      isLoading: isLoading,
      isExporting: isExporting,
      hasPendingChanges: hasPendingChanges,
      pendingItemCount: pendingItemCount,
      pendingFileCount: pendingFileCount,
      pendingChangesError: pendingChangesError,
      errorCount: errorCount,
      warningCount: warningCount,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1040) {
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
    required this.pendingItemCount,
    required this.pendingFileCount,
    required this.pendingChangesError,
    required this.errorCount,
    required this.warningCount,
  });

  final bool isLoading;
  final bool isExporting;
  final bool hasPendingChanges;
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
      pendingLabel =
          '${_countLabel(pendingItemCount, 'pending item')} · '
          '${_countLabel(pendingFileCount, 'file')}';
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
          Text(isExporting ? 'Applying…' : 'Reloading…'),
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
