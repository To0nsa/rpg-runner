import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../domain/authoring_types.dart';
import '../../../parallax/parallax_domain_models.dart';
import '../../../session/editor_session_controller.dart';
import '../../../workspace/editor_workspace.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_page_navigation_state.dart';
import '../shared/editor_scene_view_utils.dart';
import '../shared/editor_panel_card.dart';
import '../shared/editor_list_card.dart';
import '../shared/editor_workspace_card.dart';
import 'parallax_asset_file_picker.dart';
import 'widgets/parallax_preview_view.dart';

/// Level/theme/layer selection without retaining editable layer values.
class ParallaxEditorLocation extends EditorPageLocation {
  const ParallaxEditorLocation({this.levelId, this.themeId, this.layerKey});
  final String? levelId;
  final String? themeId;
  final String? layerKey;

  @override
  AuthoringDocument restoreDocumentSelection(
    AuthoringDomainPlugin plugin,
    AuthoringDocument document,
  ) {
    if (document is! ParallaxDefsDocument ||
        !document.availableLevelIds.contains(levelId)) {
      return document;
    }
    return plugin.applyEdit(
      document,
      AuthoringCommand(kind: 'set_active_level', payload: {'levelId': levelId}),
    );
  }
}

class ParallaxEditorPage extends StatefulWidget {
  const ParallaxEditorPage({
    super.key,
    required this.controller,
    this.initialLocation,
    this.previewBuilder,
    this.assetFilePicker = pickParallaxAssetFilePath,
    this.onShellStateChanged,
  });

  final EditorSessionController controller;
  final ParallaxEditorLocation? initialLocation;
  final Widget Function({
    required String workspaceRootPath,
    required ParallaxThemeDef? theme,
  })?
  previewBuilder;
  final ParallaxAssetFilePicker assetFilePicker;
  final VoidCallback? onShellStateChanged;

  @override
  State<ParallaxEditorPage> createState() => _ParallaxEditorPageState();
}

class _ParallaxEditorPageState extends State<ParallaxEditorPage>
    implements
        EditorPageLocalDraftState,
        EditorPageNavigationState,
        EditorPageSaveHandler,
        EditorPageSessionShortcutHandler,
        EditorPageReloadHandler {
  final TextEditingController _layerKeyController = TextEditingController();
  final TextEditingController _assetPathController = TextEditingController();
  final TextEditingController _parallaxFactorController =
      TextEditingController();
  final TextEditingController _zOrderController = TextEditingController();
  final TextEditingController _opacityController = TextEditingController();
  final TextEditingController _yOffsetController = TextEditingController();

  String? _selectedLayerKey;
  String? _selectedParallaxThemeId;
  String _selectedGroup = parallaxGroupBackground;
  ParallaxLayerDef? _boundLayer;
  AuthoringDocument? _boundDocument;
  bool _syncingInspector = false;
  bool _shellNotificationPending = false;
  String? _inputError;

  @override
  ParallaxEditorLocation get navigationLocation => ParallaxEditorLocation(
    levelId: switch (widget.controller.document) {
      ParallaxDefsDocument(:final activeLevelId) => activeLevelId,
      _ => null,
    },
    themeId: _selectedParallaxThemeId,
    layerKey: _selectedLayerKey,
  );

  List<TextEditingController> get _draftControllers => [
    _layerKeyController,
    _assetPathController,
    _parallaxFactorController,
    _zOrderController,
    _opacityController,
    _yOffsetController,
  ];

  @override
  bool get hasLocalDraftChanges {
    final layer = _boundLayer;
    if (layer == null) {
      return false;
    }
    return _layerKeyController.text.trim() != layer.layerKey ||
        _assetPathController.text.trim() != layer.assetPath ||
        _selectedGroup != layer.group ||
        _parallaxFactorController.text.trim() !=
            formatCanonicalParallaxNumber(layer.parallaxFactor) ||
        _zOrderController.text.trim() != layer.zOrder.toString() ||
        _opacityController.text.trim() !=
            formatCanonicalParallaxNumber(layer.opacity) ||
        _yOffsetController.text.trim() !=
            formatCanonicalParallaxNumber(layer.yOffset);
  }

  @override
  bool get canSaveEditorPage =>
      !widget.controller.isLoading &&
      !widget.controller.isExporting &&
      !widget.controller.requiresSavedRefresh &&
      (widget.controller.pendingChanges.hasChanges || hasLocalDraftChanges);

  @override
  Future<EditorPageSaveResult> saveEditorPage() async {
    if (!canSaveEditorPage) return EditorPageSaveResult.blocked;
    if (hasLocalDraftChanges && !_applySelectedLayerChanges()) {
      return EditorPageSaveResult.blocked;
    }
    if (widget.controller.saveBlockingErrorCount > 0) {
      return EditorPageSaveResult.blocked;
    }
    await _saveToFiles();
    return EditorPageSaveResult.fromSession(widget.controller);
  }

  @override
  bool get canHandleUndoSessionShortcut =>
      hasLocalDraftChanges || widget.controller.canUndo;
  @override
  bool get canHandleRedoSessionShortcut =>
      !hasLocalDraftChanges && widget.controller.canRedo;
  @override
  bool handleUndoSessionShortcut() {
    if (hasLocalDraftChanges && !_applySelectedLayerChanges()) return true;
    if (!widget.controller.canUndo) return false;
    widget.controller.undo();
    return true;
  }

  @override
  bool handleRedoSessionShortcut() {
    if (hasLocalDraftChanges) return true;
    if (!widget.controller.canRedo) return false;
    widget.controller.redo();
    return true;
  }

  @override
  void initState() {
    super.initState();
    _selectedParallaxThemeId = widget.initialLocation?.themeId;
    _selectedLayerKey = widget.initialLocation?.layerKey;
    for (final controller in _draftControllers) {
      controller.addListener(_handleDraftChanged);
    }
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.controller.scene is ParallaxScene) {
        _handleControllerChanged();
      } else {
        widget.controller.loadWorkspace();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ParallaxEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _boundDocument = null;
    _boundLayer = null;
    _handleControllerChanged();
  }

  void _handleDraftChanged() {
    if (!mounted || _syncingInspector) return;
    setState(() => _inputError = null);
    _notifyShell();
  }

  void _notifyShell() {
    if (_shellNotificationPending) return;
    _shellNotificationPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shellNotificationPending = false;
      if (mounted) widget.onShellStateChanged?.call();
    });
  }

  void _handleControllerChanged() {
    if (!mounted ||
        widget.controller.isLoading ||
        identical(_boundDocument, widget.controller.document)) {
      return;
    }
    final hadDraft = hasLocalDraftChanges;
    _boundDocument = widget.controller.document;
    if (!hadDraft) {
      final scene = widget.controller.scene;
      _syncSelection(scene is ParallaxScene ? scene : null);
      final theme = scene is ParallaxScene ? scene.activeTheme : null;
      final layer = theme == null ? null : _selectedLayer(theme);
      if (layer != null) _syncLayerInspector(layer);
    }
    setState(() {});
    _notifyShell();
  }

  @override
  bool get canReloadEditorPage =>
      !widget.controller.isLoading && !widget.controller.isExporting;

  @override
  Future<void> reloadEditorPage() async {
    await widget.controller.loadWorkspace();
    if (!mounted || widget.controller.loadError != null) return;
    _boundLayer = null;
    _boundDocument = null;
    _handleControllerChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _layerKeyController.dispose();
    _assetPathController.dispose();
    _parallaxFactorController.dispose();
    _zOrderController.dispose();
    _opacityController.dispose();
    _yOffsetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final scene = widget.controller.scene;
        final parallaxScene = scene is ParallaxScene ? scene : null;

        return EditorWorkspaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRouteControls(parallaxScene),
              const SizedBox(height: 12),
              if (widget.controller.loadError != null)
                _buildErrorBanner(widget.controller.loadError!),
              if (widget.controller.exportError != null)
                _buildErrorBanner(widget.controller.exportError!),
              if (parallaxScene == null)
                const Expanded(
                  child: Center(
                    child: Text('Parallax scene is not loaded for this route.'),
                  ),
                )
              else
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: _buildLayerPane(parallaxScene)),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildPreviewPane(parallaxScene),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildInspectorPane(parallaxScene),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteControls(ParallaxScene? scene) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (scene != null)
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              key: ValueKey<String?>('parallax-active-${scene.activeLevelId}'),
              initialValue: scene.activeLevelId,
              decoration: InputDecoration(
                labelText: 'Active Level (${scene.levelOptionSource})',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final levelId in scene.availableLevelIds)
                  DropdownMenuItem<String>(
                    value: levelId,
                    child: Text(levelId),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                if (hasLocalDraftChanges && !_applySelectedLayerChanges()) {
                  return;
                }
                widget.controller.applyPresentationCommand(
                  AuthoringCommand(
                    kind: 'set_active_level',
                    payload: <String, Object?>{'levelId': value},
                  ),
                );
              },
            ),
          ),
        if (scene != null)
          Chip(
            avatar: const Icon(Icons.palette_outlined, size: 16),
            label: Text(
              'parallaxThemeId: ${scene.activeParallaxThemeId ?? 'unresolved'}',
            ),
          ),
        if (scene != null && scene.activeThemeUsageLevelIds.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.link, size: 16),
            label: Text('Used by ${scene.activeThemeUsageLevelIds.join(', ')}'),
          ),
      ],
    );
  }

  Widget _buildLayerPane(ParallaxScene scene) {
    final activeTheme = scene.activeTheme;
    if (activeTheme == null) {
      return _buildPane(
        title: 'Layers',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scene.activeParallaxThemeId == null
                  ? 'This level does not resolve to a parallaxThemeId in level_registry.dart.'
                  : 'Theme "${scene.activeParallaxThemeId}" is not authored yet.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: scene.activeParallaxThemeId == null
                  ? null
                  : () {
                      widget.controller.applyCommand(
                        AuthoringCommand(kind: 'ensure_active_theme'),
                      );
                    },
              icon: const Icon(Icons.add),
              label: const Text('Create Theme'),
            ),
          ],
        ),
      );
    }

    return _buildPane(
      title: 'Layers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {
                  _createLayer(scene);
                },
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
              OutlinedButton(
                onPressed: _selectedLayerKey == null
                    ? null
                    : () {
                        _duplicateLayer(scene);
                      },
                child: const Text('Duplicate'),
              ),
              OutlinedButton(
                onPressed: _selectedLayerKey == null
                    ? null
                    : () {
                        widget.controller.applyCommand(
                          AuthoringCommand(
                            kind: 'remove_layer',
                            payload: <String, Object?>{
                              'layerKey': _selectedLayerKey!,
                            },
                          ),
                        );
                      },
                child: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _selectedLayerKey == null
                    ? null
                    : () => _reorderSelectedLayer(-1),
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: const Text('Move Up'),
              ),
              OutlinedButton.icon(
                onPressed: _selectedLayerKey == null
                    ? null
                    : () => _reorderSelectedLayer(1),
                icon: const Icon(Icons.arrow_downward, size: 18),
                label: const Text('Move Down'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: activeTheme.layers.isEmpty
                ? const Center(
                    child: Text('No layers authored for this theme.'),
                  )
                : ListView.builder(
                    itemCount: activeTheme.layers.length,
                    itemBuilder: (context, index) {
                      final layer = activeTheme.layers[index];
                      final isSelected = layer.layerKey == _selectedLayerKey;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == activeTheme.layers.length - 1
                              ? 0
                              : 8,
                        ),
                        child: _buildLayerEntry(
                          layer,
                          workspaceRootPath: scene.workspaceRootPath,
                          isSelected: isSelected,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerEntry(
    ParallaxLayerDef layer, {
    required String workspaceRootPath,
    required bool isSelected,
  }) {
    return EditorListCard(
      key: ValueKey<String>('parallax_layer_entry_${layer.layerKey}'),
      isSelected: isSelected,
      onTap: () {
        if (layer.layerKey == _selectedLayerKey) return;
        if (hasLocalDraftChanges && !_applySelectedLayerChanges()) return;
        setState(() {
          _selectedLayerKey = layer.layerKey;
          _syncLayerInspector(layer);
        });
      },
      leading: _ParallaxLayerAssetThumbnail(
        workspaceRootPath: workspaceRootPath,
        layer: layer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            layer.layerKey,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${layer.group}  z=${layer.zOrder}  factor=${formatCanonicalParallaxNumber(layer.parallaxFactor)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            layer.assetPath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPane(ParallaxScene scene) {
    return _buildPane(
      title: 'Preview',
      child:
          widget.previewBuilder?.call(
            workspaceRootPath: scene.workspaceRootPath,
            theme: scene.activeTheme,
          ) ??
          ParallaxPreviewView(
            workspaceRootPath: scene.workspaceRootPath,
            theme: scene.activeTheme,
            onSetAllLayerYOffsets: _setAllLayerYOffsets,
          ),
    );
  }

  bool _setAllLayerYOffsets(double yOffset) {
    final scene = widget.controller.scene;
    final activeTheme = scene is ParallaxScene ? scene.activeTheme : null;
    if (activeTheme == null || activeTheme.layers.isEmpty) {
      return false;
    }
    if (hasLocalDraftChanges) {
      _showSnackBar('Finish or discard the selected layer edit first.');
      return false;
    }

    final previousRevision = activeTheme.revision;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'set_active_theme_y_offsets',
        payload: <String, Object?>{'yOffset': yOffset},
      ),
    );
    final updatedScene = widget.controller.scene;
    final updatedTheme = updatedScene is ParallaxScene
        ? updatedScene.activeTheme
        : null;
    if (updatedTheme == null || updatedTheme.revision != previousRevision + 1) {
      return false;
    }
    final selectedLayer = _selectedLayer(updatedTheme);
    if (selectedLayer != null) {
      setState(() {
        _syncLayerInspector(selectedLayer);
      });
    }
    return true;
  }

  Widget _layerTextField({
    required TextEditingController controller,
    required InputDecoration decoration,
    TextInputType? keyboardType,
  }) => Focus(
    onFocusChange: (focused) {
      if (!focused && mounted && !_syncingInspector && hasLocalDraftChanges) {
        _applySelectedLayerChanges();
      }
    },
    child: TextField(
      controller: controller,
      decoration: decoration,
      keyboardType: keyboardType,
      onSubmitted: (_) => _applySelectedLayerChanges(),
    ),
  );

  Widget _buildInspectorPane(ParallaxScene scene) {
    final activeTheme = scene.activeTheme;
    final selectedLayer = activeTheme == null
        ? null
        : _selectedLayer(activeTheme);
    final pendingChanges = widget.controller.pendingChanges;
    final issues = widget.controller.issues;

    return _buildPane(
      title: 'Inspector',
      child: ListView(
        children: [
          Text(
            selectedLayer == null
                ? 'Layer'
                : 'Layer: ${selectedLayer.layerKey}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _layerTextField(
            controller: _layerKeyController,
            decoration: const InputDecoration(
              labelText: 'layerKey',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          _layerTextField(
            controller: _assetPathController,
            decoration: InputDecoration(
              labelText: 'assetPath',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                key: const ValueKey<String>('parallax_asset_path_picker'),
                tooltip: 'Select parallax image',
                onPressed: selectedLayer == null
                    ? null
                    : () {
                        unawaited(_pickAssetPath(scene));
                      },
                icon: const Icon(Icons.add),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('parallax_group_$_selectedGroup'),
            initialValue: _selectedGroup,
            decoration: const InputDecoration(
              labelText: 'group',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: parallaxGroupBackground,
                child: Text(parallaxGroupBackground),
              ),
              DropdownMenuItem(
                value: parallaxGroupForeground,
                child: Text(parallaxGroupForeground),
              ),
            ],
            onChanged: selectedLayer == null
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedGroup = value;
                    });
                    _notifyShell();
                  },
          ),
          const SizedBox(height: 8),
          _layerTextField(
            controller: _parallaxFactorController,
            decoration: const InputDecoration(
              labelText: 'parallaxFactor',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          _layerTextField(
            controller: _zOrderController,
            decoration: const InputDecoration(
              labelText: 'zOrder',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          _layerTextField(
            controller: _opacityController,
            decoration: const InputDecoration(
              labelText: 'opacity',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          _layerTextField(
            controller: _yOffsetController,
            decoration: const InputDecoration(
              labelText: 'yOffset',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          if (_inputError != null) _buildErrorBanner(_inputError!),
          const SizedBox(height: 16),
          Text(
            'Validation (${widget.controller.errorCount} errors, '
            '${widget.controller.warningCount} warnings)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (issues.isEmpty)
            const Text('No validation issues.')
          else
            ...issues.take(12).map(_buildIssueRow),
          if (issues.length > 12)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('... ${issues.length - 12} more issue(s)'),
            ),
          const SizedBox(height: 16),
          Text(
            'Pending Changes (${pendingChanges.fileDiffs.length} file)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (!pendingChanges.hasChanges)
            const Text('No pending file writes.')
          else ...[
            for (final diff in pendingChanges.fileDiffs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(diff.relativePath),
              ),
            SelectableText(
              pendingChanges.fileDiffs.first.unifiedDiff,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIssueRow(ValidationIssue issue) {
    final color = switch (issue.severity) {
      ValidationSeverity.error => Colors.red.shade300,
      ValidationSeverity.warning => Colors.orange.shade300,
      ValidationSeverity.info => Colors.blue.shade300,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '[${issue.code}] ${issue.message}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }

  Widget _buildPane({required String title, required Widget child}) {
    return EditorPanelCard(
      title: title,
      bodyMode: EditorPanelBodyMode.expanded,
      child: child,
    );
  }

  Widget _buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MaterialBanner(
        content: Text(message),
        actions: const [SizedBox.shrink()],
      ),
    );
  }

  void _syncSelection(ParallaxScene? scene) {
    final activeTheme = scene?.activeTheme;
    final nextParallaxThemeId = activeTheme?.parallaxThemeId;
    if (_selectedParallaxThemeId != nextParallaxThemeId) {
      _selectedParallaxThemeId = nextParallaxThemeId;
      _selectedLayerKey = activeTheme?.layers.isEmpty ?? true
          ? null
          : activeTheme!.layers.first.layerKey;
      final selectedLayer = activeTheme == null
          ? null
          : _selectedLayer(activeTheme);
      if (selectedLayer != null) {
        _syncLayerInspector(selectedLayer);
      } else {
        _clearLayerInspector();
      }
      return;
    }

    if (activeTheme == null) {
      _clearLayerInspector();
      _selectedLayerKey = null;
      return;
    }

    if (_selectedLayerKey == null ||
        activeTheme.layers.every(
          (layer) => layer.layerKey != _selectedLayerKey,
        )) {
      _selectedLayerKey = activeTheme.layers.isEmpty
          ? null
          : activeTheme.layers.first.layerKey;
      final selectedLayer = _selectedLayer(activeTheme);
      if (selectedLayer != null) {
        _syncLayerInspector(selectedLayer);
      } else {
        _clearLayerInspector();
      }
    }
  }

  void _syncLayerInspector(ParallaxLayerDef layer) {
    _syncingInspector = true;
    _boundLayer = layer;
    _layerKeyController.text = layer.layerKey;
    _assetPathController.text = layer.assetPath;
    _selectedGroup = layer.group;
    _parallaxFactorController.text = formatCanonicalParallaxNumber(
      layer.parallaxFactor,
    );
    _zOrderController.text = layer.zOrder.toString();
    _opacityController.text = formatCanonicalParallaxNumber(layer.opacity);
    _yOffsetController.text = formatCanonicalParallaxNumber(layer.yOffset);
    _syncingInspector = false;
    _inputError = null;
  }

  void _clearLayerInspector() {
    _syncingInspector = true;
    _boundLayer = null;
    _layerKeyController.text = '';
    _assetPathController.text = '';
    _selectedGroup = parallaxGroupBackground;
    _parallaxFactorController.text = '';
    _zOrderController.text = '';
    _opacityController.text = '';
    _yOffsetController.text = '';
    _syncingInspector = false;
  }

  Future<void> _pickAssetPath(ParallaxScene scene) async {
    String? selectedPath;
    try {
      selectedPath = await widget.assetFilePicker(
        initialDirectory: _assetPickerInitialDirectory(scene),
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar('Could not open the parallax asset selector.');
      }
      return;
    }
    if (!mounted || selectedPath == null) {
      return;
    }

    final relativePath = _workspaceRelativePath(
      workspaceRootPath: scene.workspaceRootPath,
      selectedPath: selectedPath,
    );
    if (relativePath == null) {
      _showSnackBar('Choose an image inside the current workspace.');
      return;
    }

    setState(() {
      _assetPathController.text = relativePath;
    });
  }

  String _assetPickerInitialDirectory(ParallaxScene scene) {
    final workspace = EditorWorkspace(rootPath: scene.workspaceRootPath);
    final authoredPath = _assetPathController.text.trim();
    if (authoredPath.isNotEmpty) {
      try {
        final authoredParent = File(workspace.resolve(authoredPath)).parent;
        if (authoredParent.existsSync()) {
          return authoredParent.path;
        }
      } on ArgumentError {
        // The inspector may contain an invalid draft; use the normal fallback.
      }
    }

    final parallaxDirectory = Directory(
      workspace.resolve('assets/images/parallax'),
    );
    return parallaxDirectory.existsSync()
        ? parallaxDirectory.path
        : workspace.rootPath;
  }

  ParallaxLayerDef? _selectedLayer(ParallaxThemeDef theme) {
    final selectedLayerKey = _selectedLayerKey;
    if (selectedLayerKey == null || selectedLayerKey.isEmpty) {
      return null;
    }
    for (final layer in theme.layers) {
      if (layer.layerKey == selectedLayerKey) {
        return layer;
      }
    }
    return null;
  }

  bool _applySelectedLayerChanges() {
    final scene = widget.controller.scene;
    if (scene is! ParallaxScene ||
        scene.activeTheme == null ||
        _selectedLayerKey == null) {
      return false;
    }
    if (!hasLocalDraftChanges) return true;
    final factor = double.tryParse(_parallaxFactorController.text.trim());
    final opacity = double.tryParse(_opacityController.text.trim());
    final offset = double.tryParse(_yOffsetController.text.trim());
    final order = int.tryParse(_zOrderController.text.trim());
    final error = factor == null || !factor.isFinite
        ? 'Parallax factor must be a finite number.'
        : opacity == null || !opacity.isFinite
        ? 'Opacity must be a finite number.'
        : offset == null || !offset.isFinite
        ? 'Y offset must be a finite number.'
        : order == null
        ? 'Z order must be a whole number.'
        : _layerKeyController.text.trim().isEmpty
        ? 'Enter a layer key.'
        : null;
    if (error != null) {
      setState(() => _inputError = error);
      _showSnackBar(error);
      return false;
    }
    final previousLayerKey = _selectedLayerKey!;
    final nextLayerKey = _layerKeyController.text.trim();
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'update_layer',
        payload: <String, Object?>{
          'layerKey': previousLayerKey,
          'nextLayerKey': nextLayerKey,
          'assetPath': _assetPathController.text.trim(),
          'group': _selectedGroup,
          'parallaxFactor': factor,
          'zOrder': order,
          'opacity': opacity,
          'yOffset': offset,
        },
      ),
    );
    final updatedScene = widget.controller.scene;
    if (updatedScene is! ParallaxScene || updatedScene.activeTheme == null) {
      return false;
    }
    final targetLayerKey = nextLayerKey.isEmpty
        ? previousLayerKey
        : nextLayerKey;
    final updatedLayer = updatedScene.activeTheme!.layers
        .where((layer) => layer.layerKey == targetLayerKey)
        .cast<ParallaxLayerDef?>()
        .firstWhere((layer) => layer != null, orElse: () => null);
    final accepted =
        updatedLayer != null &&
        updatedLayer.assetPath == _assetPathController.text.trim() &&
        updatedLayer.group == _selectedGroup &&
        updatedLayer.parallaxFactor == factor &&
        updatedLayer.zOrder == order &&
        updatedLayer.opacity == opacity &&
        updatedLayer.yOffset == offset;
    if (!accepted) {
      setState(
        () => _inputError =
            'This layer edit was rejected. Review its validation issues.',
      );
      return false;
    }
    setState(() {
      _selectedLayerKey = updatedLayer.layerKey;
      _syncLayerInspector(updatedLayer);
    });
    _notifyShell();
    return true;
  }

  void _createLayer(ParallaxScene scene) {
    final activeTheme = scene.activeTheme;
    final beforeKeys =
        activeTheme?.layers.map((layer) => layer.layerKey).toSet() ??
        const <String>{};
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'create_layer',
        payload: <String, Object?>{
          'group':
              (activeTheme == null ? null : _selectedLayer(activeTheme))
                  ?.group ??
              parallaxGroupBackground,
        },
      ),
    );
    final updatedScene = widget.controller.scene;
    if (updatedScene is! ParallaxScene || updatedScene.activeTheme == null) {
      return;
    }
    for (final layer in updatedScene.activeTheme!.layers) {
      if (!beforeKeys.contains(layer.layerKey)) {
        setState(() {
          _selectedLayerKey = layer.layerKey;
          _syncLayerInspector(layer);
        });
        return;
      }
    }
  }

  void _duplicateLayer(ParallaxScene scene) {
    final activeTheme = scene.activeTheme;
    final selectedLayerKey = _selectedLayerKey;
    if (activeTheme == null || selectedLayerKey == null) {
      return;
    }
    final beforeKeys = activeTheme.layers
        .map((layer) => layer.layerKey)
        .toSet();
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'duplicate_layer',
        payload: <String, Object?>{'layerKey': selectedLayerKey},
      ),
    );
    final updatedScene = widget.controller.scene;
    if (updatedScene is! ParallaxScene || updatedScene.activeTheme == null) {
      return;
    }
    for (final layer in updatedScene.activeTheme!.layers) {
      if (!beforeKeys.contains(layer.layerKey)) {
        setState(() {
          _selectedLayerKey = layer.layerKey;
          _syncLayerInspector(layer);
        });
        return;
      }
    }
  }

  void _reorderSelectedLayer(int direction) {
    final selectedLayerKey = _selectedLayerKey;
    if (selectedLayerKey == null) {
      return;
    }
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'reorder_layer',
        payload: <String, Object?>{
          'layerKey': selectedLayerKey,
          'direction': direction,
        },
      ),
    );
  }

  Future<void> _saveToFiles() async {
    final pendingChanges = widget.controller.pendingChanges;
    if (!pendingChanges.hasChanges) {
      _showSnackBar('No pending changes to save.');
      return;
    }

    await widget.controller.exportDirectWrite();
    if (!mounted) {
      return;
    }
    final error =
        widget.controller.refreshError ?? widget.controller.exportError;
    if (error != null) {
      _showSnackBar(
        widget.controller.requiresSavedRefresh
            ? 'Saved; refresh failed: $error'
            : 'Save failed: $error',
      );
      return;
    }
    _showSnackBar('Parallax changes saved.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Read-only, workspace-relative asset preview shown alongside each layer.
///
/// The thumbnail helps authors match a layer key to its art without making the
/// layer list another asset-management surface. Invalid or missing paths stay
/// selectable and are represented by the fallback icon.
class _ParallaxLayerAssetThumbnail extends StatefulWidget {
  const _ParallaxLayerAssetThumbnail({
    required this.workspaceRootPath,
    required this.layer,
  });
  final String workspaceRootPath;
  final ParallaxLayerDef layer;

  @override
  State<_ParallaxLayerAssetThumbnail> createState() =>
      _ParallaxLayerAssetThumbnailState();
}

class _ParallaxLayerAssetThumbnailState
    extends State<_ParallaxLayerAssetThumbnail> {
  final EditorUiImageCache _images = EditorUiImageCache();
  String _path = '';

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant _ParallaxLayerAssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        !identical(oldWidget.layer, widget.layer)) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final path = p.normalize(
      p.join(widget.workspaceRootPath, widget.layer.assetPath),
    );
    _path = path;
    // Decode from copied bytes so a visible thumbnail cannot keep the source
    // PNG memory-mapped and prevent an artist from replacing it on Windows.
    await _images.ensureRasterLoaded(path, refresh: true);
    if (mounted && path == _path) setState(() {});
  }

  @override
  void dispose() {
    _images.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final image = _images.imageFor(_path);
    return SizedBox(
      key: ValueKey<String>(
        'parallax_layer_asset_preview_${widget.layer.layerKey}',
      ),
      width: 112,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: image == null
              ? Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    key: ValueKey<String>(
                      'parallax_layer_asset_preview_missing_${widget.layer.layerKey}',
                    ),
                    color: colors.onSurfaceVariant,
                  ),
                )
              : RawImage(
                  image: image,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
        ),
      ),
    );
  }
}

String? _workspaceRelativePath({
  required String workspaceRootPath,
  required String selectedPath,
}) {
  final workspace = EditorWorkspace(rootPath: workspaceRootPath);
  final absoluteSelection = p.normalize(p.absolute(selectedPath));
  if (!File(absoluteSelection).existsSync()) {
    return null;
  }

  final relativeSelection = p.normalize(
    p.relative(absoluteSelection, from: workspace.rootPath),
  );
  try {
    final resolvedSelection = workspace.resolve(relativeSelection);
    if (!p.equals(resolvedSelection, absoluteSelection)) {
      return null;
    }
  } on ArgumentError {
    return null;
  }
  return relativeSelection.replaceAll('\\', '/');
}
