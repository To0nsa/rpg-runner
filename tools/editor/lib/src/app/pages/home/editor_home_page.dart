import 'package:flutter/material.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPluginForRoute(_selectedRouteId);
    });
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final workspacePath = widget.controller.workspacePath;
        if (_workspaceController.text != workspacePath) {
          _workspaceController.value = _workspaceController.value.copyWith(
            text: workspacePath,
            selection: TextSelection.collapsed(offset: workspacePath.length),
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
}
