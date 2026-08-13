import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../domain/authoring_types.dart';
import '../../../parallax/parallax_domain_models.dart';
import '../../../session/editor_session_controller.dart';
import '../../../workspace/editor_workspace.dart';
import '../shared/editor_page_local_draft_state.dart';
import 'parallax_asset_file_picker.dart';
import 'widgets/parallax_preview_view.dart';

class ParallaxEditorPage extends StatefulWidget {
  const ParallaxEditorPage({
    super.key,
    required this.controller,
    this.previewBuilder,
    this.assetFilePicker = pickParallaxAssetFilePath,
  });

  final EditorSessionController controller;
  final Widget Function({
    required String workspaceRootPath,
    required ParallaxThemeDef? theme,
  })?
  previewBuilder;
  final ParallaxAssetFilePicker assetFilePicker;

  @override
  State<ParallaxEditorPage> createState() => _ParallaxEditorPageState();
}

class _ParallaxEditorPageState extends State<ParallaxEditorPage>
    implements EditorPageLocalDraftState {
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

  @override
  bool get hasLocalDraftChanges {
    final scene = widget.controller.scene;
    if (scene is! ParallaxScene) {
      return false;
    }
    final activeTheme = scene.activeTheme;
    if (activeTheme == null) return false;
    final layer = _selectedLayer(activeTheme);
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadWorkspace();
    });
  }

  @override
  void dispose() {
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
        _syncSelection(parallaxScene);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildControls(parallaxScene),
                const SizedBox(height: 12),
                if (widget.controller.loadError != null)
                  _buildErrorBanner(widget.controller.loadError!),
                if (widget.controller.exportError != null)
                  _buildErrorBanner(widget.controller.exportError!),
                if (parallaxScene == null)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Parallax scene is not loaded for this route.',
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildLayerPane(parallaxScene),
                        ),
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
          ),
        );
      },
    );
  }

  Widget _buildControls(ParallaxScene? scene) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: widget.controller.canUndo ? widget.controller.undo : null,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        OutlinedButton.icon(
          onPressed: widget.controller.canRedo ? widget.controller.redo : null,
          icon: const Icon(Icons.redo),
          label: const Text('Redo'),
        ),
        FilledButton.icon(
          onPressed: widget.controller.isExporting
              ? null
              : () {
                  unawaited(_confirmAndApplyToFiles());
                },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Apply To Files'),
        ),
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
                widget.controller.applyCommand(
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
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.24)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: InkWell(
          key: ValueKey<String>('parallax_layer_entry_${layer.layerKey}'),
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            setState(() {
              _selectedLayerKey = layer.layerKey;
              _syncLayerInspector(layer);
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ParallaxLayerAssetThumbnail(
                  workspaceRootPath: workspaceRootPath,
                  layer: layer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        layer.layerKey,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                ),
              ],
            ),
          ),
        ),
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
      _showSnackBar('Apply or discard the selected layer draft first.');
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
          TextField(
            controller: _layerKeyController,
            decoration: const InputDecoration(
              labelText: 'layerKey',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
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
                  },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _parallaxFactorController,
            decoration: const InputDecoration(
              labelText: 'parallaxFactor',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _zOrderController,
            decoration: const InputDecoration(
              labelText: 'zOrder',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _opacityController,
            decoration: const InputDecoration(
              labelText: 'opacity',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _yOffsetController,
            decoration: const InputDecoration(
              labelText: 'yOffset',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: selectedLayer == null
                ? null
                : _applySelectedLayerChanges,
            child: const Text('Apply Layer'),
          ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x22101820),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x334A6074)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(child: child),
          ],
        ),
      ),
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
    _layerKeyController.text = layer.layerKey;
    _assetPathController.text = layer.assetPath;
    _selectedGroup = layer.group;
    _parallaxFactorController.text = formatCanonicalParallaxNumber(
      layer.parallaxFactor,
    );
    _zOrderController.text = layer.zOrder.toString();
    _opacityController.text = formatCanonicalParallaxNumber(layer.opacity);
    _yOffsetController.text = formatCanonicalParallaxNumber(layer.yOffset);
  }

  void _clearLayerInspector() {
    _layerKeyController.text = '';
    _assetPathController.text = '';
    _selectedGroup = parallaxGroupBackground;
    _parallaxFactorController.text = '';
    _zOrderController.text = '';
    _opacityController.text = '';
    _yOffsetController.text = '';
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

  void _applySelectedLayerChanges() {
    final scene = widget.controller.scene;
    if (scene is! ParallaxScene ||
        scene.activeTheme == null ||
        _selectedLayerKey == null) {
      return;
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
          'parallaxFactor': _parallaxFactorController.text.trim(),
          'zOrder': _zOrderController.text.trim(),
          'opacity': _opacityController.text.trim(),
          'yOffset': _yOffsetController.text.trim(),
        },
      ),
    );
    final updatedScene = widget.controller.scene;
    if (updatedScene is! ParallaxScene || updatedScene.activeTheme == null) {
      return;
    }
    final targetLayerKey = nextLayerKey.isEmpty
        ? previousLayerKey
        : nextLayerKey;
    final updatedLayer = updatedScene.activeTheme!.layers
        .where((layer) => layer.layerKey == targetLayerKey)
        .cast<ParallaxLayerDef?>()
        .firstWhere((layer) => layer != null, orElse: () => null);
    if (updatedLayer != null) {
      setState(() {
        _selectedLayerKey = updatedLayer.layerKey;
        _syncLayerInspector(updatedLayer);
      });
    }
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

  Future<void> _confirmAndApplyToFiles() async {
    final pendingChanges = widget.controller.pendingChanges;
    if (!pendingChanges.hasChanges) {
      _showSnackBar('No pending changes to apply.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Apply Parallax Changes'),
          content: Text(
            'Write ${pendingChanges.changedItemIds.length} theme change(s) '
            'across ${pendingChanges.fileDiffs.length} file(s)?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await widget.controller.exportDirectWrite();
    if (!mounted) {
      return;
    }
    if (widget.controller.exportError != null) {
      _showSnackBar('Apply failed: ${widget.controller.exportError}');
      return;
    }
    _showSnackBar('Parallax changes applied.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Read-only, workspace-relative asset preview shown alongside each layer.
///
/// The thumbnail helps authors match a layer key to its art without making the
/// layer list another asset-management surface. Invalid or missing paths stay
/// selectable and are represented by the fallback icon.
class _ParallaxLayerAssetThumbnail extends StatelessWidget {
  const _ParallaxLayerAssetThumbnail({
    required this.workspaceRootPath,
    required this.layer,
  });

  static const double _width = 112;
  static const double _height = 64;

  final String workspaceRootPath;
  final ParallaxLayerDef layer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _width,
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Image.file(
            File(p.normalize(p.join(workspaceRootPath, layer.assetPath))),
            key: ValueKey<String>(
              'parallax_layer_asset_preview_${layer.layerKey}',
            ),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Icon(
                Icons.broken_image_outlined,
                key: ValueKey<String>(
                  'parallax_layer_asset_preview_missing_${layer.layerKey}',
                ),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
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
