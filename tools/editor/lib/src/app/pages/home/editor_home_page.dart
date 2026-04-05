import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../session/editor_session_controller.dart';
import '../chunkCreator/chunk_creator_page.dart';
import '../entities/entities_editor_page.dart';
import '../prefabCreator/prefab_creator_page.dart';
import '../shared/editor_page_local_draft_state.dart';
import 'home_routes.dart';

class EditorHomePage extends StatefulWidget {
  const EditorHomePage({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  final GlobalKey _entitiesPageKey = GlobalKey();
  final GlobalKey _prefabCreatorPageKey = GlobalKey();
  final GlobalKey _chunkCreatorPageKey = GlobalKey();
  late final TextEditingController _workspaceController;
  String _selectedRouteId = entitiesRouteId;

  @override
  void initState() {
    super.initState();
    _workspaceController = TextEditingController(
      text: widget.controller.workspacePath,
    );
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
    switch (_selectedRouteId) {
      case entitiesRouteId:
        return EntitiesEditorPage(
          key: _entitiesPageKey,
          controller: widget.controller,
        );
      case prefabCreatorRouteId:
        return PrefabCreatorPage(
          key: _prefabCreatorPageKey,
          controller: widget.controller,
        );
      case chunkCreatorRouteId:
        return ChunkCreatorPage(
          key: _chunkCreatorPageKey,
          controller: widget.controller,
        );
      default:
        return const Center(child: Text('Unknown editor page.'));
    }
  }

  void _syncPluginForRoute(String routeId) {
    final route = findHomeRouteById(routeId);
    if (route == null) {
      return;
    }
    final requiredPluginId = route.pluginId;
    if (requiredPluginId == null ||
        requiredPluginId == widget.controller.selectedPluginId) {
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
    final pageState = switch (_selectedRouteId) {
      entitiesRouteId => _entitiesPageKey.currentState,
      prefabCreatorRouteId => _prefabCreatorPageKey.currentState,
      chunkCreatorRouteId => _chunkCreatorPageKey.currentState,
      _ => null,
    };
    if (pageState is! EditorPageLocalDraftState) {
      return false;
    }
    final draftAwarePageState = pageState as EditorPageLocalDraftState;
    return draftAwarePageState.hasLocalDraftChanges;
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
    final pageState = switch (_selectedRouteId) {
      entitiesRouteId => _entitiesPageKey.currentState,
      prefabCreatorRouteId => _prefabCreatorPageKey.currentState,
      chunkCreatorRouteId => _chunkCreatorPageKey.currentState,
      _ => null,
    };
    if (pageState is! EditorPageSessionShortcutHandler) {
      return null;
    }
    return pageState as EditorPageSessionShortcutHandler;
  }

  BuildContext? _currentPageContext() {
    return switch (_selectedRouteId) {
      entitiesRouteId => _entitiesPageKey.currentContext,
      prefabCreatorRouteId => _prefabCreatorPageKey.currentContext,
      chunkCreatorRouteId => _chunkCreatorPageKey.currentContext,
      _ => null,
    };
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
