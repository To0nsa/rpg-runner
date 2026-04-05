import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';
import 'home_routes.dart';

class EditorHomePage extends StatefulWidget {
  const EditorHomePage({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  late final TextEditingController _workspaceController;
  late final Map<String, _EditorHomeRouteBinding> _routeBindings;
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
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPluginForRoute(_selectedRouteId);
    });
  }

  @override
  void dispose() {
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
          final workspacePath = widget.controller.workspacePath;
          if (_workspaceController.text != workspacePath) {
            _workspaceController.value = _workspaceController.value.copyWith(
              text: workspacePath,
              selection: TextSelection.collapsed(
                offset: workspacePath.length,
              ),
              composing: TextRange.empty,
            );
          }
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShellControls(),
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

  Widget _buildShellControls() {
    final title = Text(
      'RPG Runner Editor - Pages ->',
      style: Theme.of(context).textTheme.headlineSmall,
    );
    final workspaceField = TextField(
      controller: _workspaceController,
      decoration: const InputDecoration(
        labelText: 'Workspace Path',
        hintText: r'C:\dev\rpg_runner',
        border: OutlineInputBorder(),
      ),
      onChanged: widget.controller.setWorkspacePath,
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
            value: _selectedRouteId,
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
              if (value == null || value == _selectedRouteId) {
                return;
              }
              _handleRouteSelectionRequested(value);
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
        Expanded(flex: 5, child: workspaceField),
      ],
    );
  }

  Widget _buildSelectedRoutePage() {
    final routeBinding = _selectedRouteBinding;
    if (routeBinding == null) {
      return const Center(child: Text('Unknown editor page.'));
    }
    return routeBinding.buildPage(widget.controller);
  }

  void _syncPluginForRoute(String routeId) {
    final routeBinding = _routeBindings[routeId];
    if (routeBinding == null) {
      return;
    }
    final requiredPluginId = routeBinding.route.pluginId;
    if (requiredPluginId == widget.controller.selectedPluginId) {
      return;
    }
    final hasPlugin = widget.controller.availablePlugins.any(
      (plugin) => plugin.id == requiredPluginId,
    );
    if (!hasPlugin) {
      return;
    }
    widget.controller.setSelectedPluginId(requiredPluginId);
  }

  Future<void> _handleRouteSelectionRequested(String routeId) async {
    final canLeave = await _confirmDiscardPendingChanges();
    if (!mounted || !canLeave) {
      return;
    }
    setState(() {
      _selectedRouteId = routeId;
    });
    _syncPluginForRoute(routeId);
  }

  Future<bool> _confirmDiscardPendingChanges() async {
    final pendingChanges = widget.controller.pendingChanges;
    final hasLocalDraftChanges = _currentPageHasLocalDraftChanges();
    if (!pendingChanges.hasChanges && !hasLocalDraftChanges) {
      return true;
    }

    final changedItems = pendingChanges.changedItemIds.length;
    final changedFiles = pendingChanges.fileDiffs.length;
    final contentLines = <String>['Leave this page without saving?', ''];
    if (pendingChanges.hasChanges) {
      contentLines.add(
        'Pending session changes: $changedItems item(s), $changedFiles file(s).',
      );
    }
    if (hasLocalDraftChanges) {
      contentLines.add('This page also has unsaved draft form/input changes.');
    }
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
              child: const Text('Discard and leave'),
            ),
          ],
        );
      },
    );
    return decision ?? false;
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
    if (event is! KeyDownEvent ||
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
    return _selectedRouteBinding?.currentContext;
  }

  _EditorHomeRouteBinding? get _selectedRouteBinding =>
      _routeBindings[_selectedRouteId];

  Object? get _currentPageState => _selectedRouteBinding?.currentState;

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
