import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';
import 'home_routes.dart';
import 'workspace_directory_picker.dart';

/// Top-level editor shell that coordinates route selection around one shared
/// [EditorSessionController].
///
/// This page owns shell concerns only: selecting the active top-level route,
/// applying workspace changes, guarding destructive transitions, and routing
/// shell-level undo/redo shortcuts. Domain load/edit/export behavior still
/// flows through the selected plugin and page.
class EditorHomePage extends StatefulWidget {
  const EditorHomePage({
    super.key,
    required this.controller,
    this.workspaceDirectoryPicker = pickWorkspaceDirectoryPath,
  });

  /// Shared authoring session used by every top-level route.
  final EditorSessionController controller;

  /// Platform directory picker used by the shell's `Browse...` action.
  ///
  /// Kept injectable so widget tests can drive workspace selection without
  /// opening native dialogs.
  final Future<String?> Function() workspaceDirectoryPicker;

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  late final AppLifecycleListener _appLifecycleListener;
  late final TextEditingController _workspaceController;
  // The shell owns stable page keys so it can query the active route for local
  // draft state and shortcut handling without reintroducing route-id switches.
  late final Map<String, _EditorHomeRouteBinding> _routeBindings;
  late String _lastSyncedWorkspacePath;
  // Route/workspace/app-exit requests can all ask for discard confirmation;
  // keep them serialized so the shell never stacks competing dialogs.
  bool _isShowingDiscardDialog = false;
  String _selectedRouteId = entitiesRouteId;

  @override
  void initState() {
    super.initState();
    _workspaceController = TextEditingController(
      text: widget.controller.workspacePath,
    );
    _routeBindings = <String, _EditorHomeRouteBinding>{
      for (final route in homeRoutes)
        route.id: _EditorHomeRouteBinding(
          route: route,
          pageKey: GlobalKey(),
        ),
    };
    _lastSyncedWorkspacePath = widget.controller.workspacePath;
    _appLifecycleListener = AppLifecycleListener(
      onExitRequested: _handleAppExitRequested,
    );
    widget.controller.addListener(_syncWorkspaceDraftFromController);
    // The shell handles cross-route undo/redo shortcuts globally, then routes
    // them back into the active page/session when appropriate.
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPluginForRoute(_selectedRouteId);
    });
  }

  @override
  void didUpdateWidget(EditorHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) {
      return;
    }
    oldWidget.controller.removeListener(_syncWorkspaceDraftFromController);
    _lastSyncedWorkspacePath = widget.controller.workspacePath;
    _setWorkspaceDraftText(_lastSyncedWorkspacePath);
    widget.controller.addListener(_syncWorkspaceDraftFromController);
  }

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    widget.controller.removeListener(_syncWorkspaceDraftFromController);
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _workspaceController.dispose();
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
                    workspaceController: _workspaceController,
                    canApplyWorkspacePathDraft: _canApplyWorkspacePathDraft,
                    canBrowseWorkspace: _canBrowseWorkspace,
                    onWorkspaceDraftChanged: () {
                      setState(() {});
                    },
                    onWorkspaceSubmitted: _handleWorkspacePathApplyRequested,
                    onApplyWorkspacePressed: _handleWorkspacePathApplyRequested,
                    onBrowseWorkspacePressed: _handleBrowseWorkspaceRequested,
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
    return routeBinding.buildPage(widget.controller);
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
    });
    _syncPluginForRoute(routeId);
  }

  bool get _canApplyWorkspacePathDraft {
    return _workspaceController.text != widget.controller.workspacePath &&
        !widget.controller.isLoading &&
        !widget.controller.isExporting;
  }

  bool get _canBrowseWorkspace {
    return !widget.controller.isLoading &&
        !widget.controller.isExporting &&
        !_isShowingDiscardDialog;
  }

  Future<void> _handleBrowseWorkspaceRequested() async {
    if (!_canBrowseWorkspace) {
      return;
    }
    final selectedWorkspacePath = await widget.workspaceDirectoryPicker();
    if (!mounted || selectedWorkspacePath == null) {
      return;
    }
    if (_workspaceController.text != selectedWorkspacePath) {
      setState(() {
        _setWorkspaceDraftText(selectedWorkspacePath);
      });
    }
    await _handleWorkspacePathApplyRequested();
  }

  // Workspace changes invalidate the loaded session snapshot, so typing stays
  // local until the user explicitly applies the draft and confirms discard.
  Future<void> _handleWorkspacePathApplyRequested() async {
    final currentWorkspacePath = widget.controller.workspacePath;
    final nextWorkspacePath = _workspaceController.text.trim();
    if (nextWorkspacePath == currentWorkspacePath) {
      if (_workspaceController.text != currentWorkspacePath) {
        setState(() {
          _setWorkspaceDraftText(currentWorkspacePath);
        });
      }
      return;
    }

    final canLeave = await _confirmDiscardPendingChanges(
      promptLine: 'Change workspace without saving?',
      confirmLabel: 'Discard and switch',
    );
    if (!mounted || !canLeave) {
      return;
    }
    widget.controller.setWorkspacePath(nextWorkspacePath);
  }

  Future<AppExitResponse> _handleAppExitRequested() async {
    if (!mounted) {
      return AppExitResponse.exit;
    }
    // App-close requests should respect the same unsaved-work guard as route
    // and workspace changes instead of bypassing the shell.
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
      return _handleUndoShortcut();
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

  void _syncWorkspaceDraftFromController() {
    final workspacePath = widget.controller.workspacePath;
    if (workspacePath == _lastSyncedWorkspacePath) {
      return;
    }
    // Only committed controller changes should rewrite the field; local typing
    // remains intact until the user applies or resets it.
    _lastSyncedWorkspacePath = workspacePath;
    _setWorkspaceDraftText(workspacePath);
  }

  void _setWorkspaceDraftText(String workspacePath) {
    _workspaceController.value = _workspaceController.value.copyWith(
      text: workspacePath,
      selection: TextSelection.collapsed(offset: workspacePath.length),
      composing: TextRange.empty,
    );
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

  Widget buildPage(EditorSessionController controller) {
    return route.buildPage(key: pageKey, controller: controller);
  }
}

/// Presentation-only controls row for the editor shell.
///
/// This widget renders the route selector and workspace draft controls, while
/// [EditorHomePage] keeps the actual coordination logic for route switching,
/// discard guards, and session updates.
class _EditorHomeShellControls extends StatelessWidget {
  const _EditorHomeShellControls({
    required this.selectedRouteId,
    required this.workspaceController,
    required this.canApplyWorkspacePathDraft,
    required this.canBrowseWorkspace,
    required this.onWorkspaceDraftChanged,
    required this.onWorkspaceSubmitted,
    required this.onApplyWorkspacePressed,
    required this.onBrowseWorkspacePressed,
    required this.onRouteSelected,
  });

  final String selectedRouteId;
  final TextEditingController workspaceController;
  final bool canApplyWorkspacePathDraft;
  final bool canBrowseWorkspace;
  final VoidCallback onWorkspaceDraftChanged;
  final Future<void> Function() onWorkspaceSubmitted;
  final Future<void> Function() onApplyWorkspacePressed;
  final Future<void> Function() onBrowseWorkspacePressed;
  final Future<void> Function(String routeId) onRouteSelected;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'RPG Runner Editor - Pages ->',
      style: Theme.of(context).textTheme.headlineSmall,
    );
    final workspaceField = TextField(
      controller: workspaceController,
      decoration: const InputDecoration(
        labelText: 'Workspace Path',
        hintText: r'C:\dev\rpg_runner',
        border: OutlineInputBorder(),
      ),
      onChanged: (_) {
        onWorkspaceDraftChanged();
      },
      onSubmitted: (_) {
        onWorkspaceSubmitted();
      },
    );
    final applyWorkspaceButton = FilledButton(
      key: const ValueKey<String>('apply_workspace_path_button'),
      onPressed: canApplyWorkspacePathDraft
          ? () {
              onApplyWorkspacePressed();
            }
          : null,
      child: const Text('Apply'),
    );
    final browseWorkspaceButton = OutlinedButton(
      key: const ValueKey<String>('browse_workspace_path_button'),
      onPressed: canBrowseWorkspace
          ? () {
              onBrowseWorkspacePressed();
            }
          : null,
      child: const Text('Browse...'),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DefaultTextStyle.merge(
              overflow: TextOverflow.ellipsis,
              child: title,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: SizedBox(width: 160, child: routeSelector),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Row(
            children: [
              Expanded(child: workspaceField),
              const SizedBox(width: 12),
              browseWorkspaceButton,
              const SizedBox(width: 12),
              applyWorkspaceButton,
            ],
          ),
        ),
      ],
    );
  }
}
