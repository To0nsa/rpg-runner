import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../collider/collider_domain_models.dart';
import '../domain/authoring_types.dart';
import '../session/editor_session_controller.dart';
import 'inspector/editor_inspector_panel.dart';

part 'scene/scene_zoom.dart';
part 'scene/scene_grid.dart';
part 'scene/scene_view.dart';

class EditorHomePage extends StatefulWidget {
  const EditorHomePage({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  late final TextEditingController _workspaceController;
  late final TextEditingController _halfXController;
  late final TextEditingController _halfYController;
  late final TextEditingController _offsetXController;
  late final TextEditingController _offsetYController;
  late final TextEditingController _anchorXPxController;
  late final TextEditingController _anchorYPxController;
  late final TextEditingController _frameWidthController;
  late final TextEditingController _frameHeightController;
  late final TextEditingController _renderScaleController;
  late final TextEditingController _searchController;
  late final TextEditingController _sceneZoomController;

  String? _selectedEntryId;
  String? _selectedDiffPath;
  String? _selectedArtifactTitle;
  String _searchQuery = '';
  ColliderEntityType? _entityTypeFilter;
  bool _showDirtyOnly = false;
  double _sceneZoom = 1.0;
  final Map<String, ui.Image> _referenceImageCache = <String, ui.Image>{};
  final Set<String> _referenceImageLoading = <String>{};
  final Set<String> _referenceImageFailed = <String>{};

  @override
  void initState() {
    super.initState();
    _workspaceController = TextEditingController(
      text: widget.controller.workspacePath,
    );
    _halfXController = TextEditingController();
    _halfYController = TextEditingController();
    _offsetXController = TextEditingController();
    _offsetYController = TextEditingController();
    _anchorXPxController = TextEditingController();
    _anchorYPxController = TextEditingController();
    _frameWidthController = TextEditingController();
    _frameHeightController = TextEditingController();
    _renderScaleController = TextEditingController();
    _searchController = TextEditingController();
    _sceneZoomController = TextEditingController();
    _syncSceneZoomText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadWorkspace();
    });
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    _halfXController.dispose();
    _halfYController.dispose();
    _offsetXController.dispose();
    _offsetYController.dispose();
    _anchorXPxController.dispose();
    _anchorYPxController.dispose();
    _frameWidthController.dispose();
    _frameHeightController.dispose();
    _renderScaleController.dispose();
    _searchController.dispose();
    _sceneZoomController.dispose();
    for (final image in _referenceImageCache.values) {
      image.dispose();
    }
    _referenceImageCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final colliderScene = widget.controller.colliderScene;
        final visibleEntries = colliderScene == null
            ? const <ColliderEntry>[]
            : _filteredEntries(colliderScene.entries);
        _ensureSelection(colliderScene, visibleEntries);
        _ensureDiffSelection(widget.controller.pendingChanges);
        _ensureArtifactSelection(widget.controller.lastExportResult);
        return Scaffold(
          appBar: AppBar(title: const Text('RPG Runner Editor')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildControls(),
                const SizedBox(height: 16),
                _buildStatusRow(),
                const SizedBox(height: 16),
                Expanded(child: _buildSceneBody(colliderScene, visibleEntries)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 580,
          child: TextField(
            controller: _workspaceController,
            decoration: const InputDecoration(
              labelText: 'Workspace Path',
              hintText: r'C:\dev\rpg_runner',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.controller.setWorkspacePath,
          ),
        ),
        DropdownButton<String>(
          value: widget.controller.selectedPluginId,
          items: [
            for (final plugin in widget.controller.availablePlugins)
              DropdownMenuItem<String>(
                value: plugin.id,
                child: Text(plugin.displayName),
              ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            widget.controller.setSelectedPluginId(value);
          },
        ),
        FilledButton.icon(
          onPressed:
              widget.controller.isLoading || widget.controller.isExporting
              ? null
              : () {
                  widget.controller.setWorkspacePath(_workspaceController.text);
                  widget.controller.loadWorkspace();
                },
          icon: const Icon(Icons.sync),
          label: const Text('Load Workspace'),
        ),
        OutlinedButton.icon(
          onPressed:
              widget.controller.isLoading ||
                  widget.controller.isExporting ||
                  !widget.controller.canUndo
              ? null
              : widget.controller.undo,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        OutlinedButton.icon(
          onPressed:
              widget.controller.isLoading ||
                  widget.controller.isExporting ||
                  !widget.controller.canRedo
              ? null
              : widget.controller.redo,
          icon: const Icon(Icons.redo),
          label: const Text('Redo'),
        ),
        OutlinedButton.icon(
          onPressed:
              widget.controller.scene == null ||
                  widget.controller.isLoading ||
                  widget.controller.isExporting
              ? null
              : widget.controller.exportPreview,
          icon: const Icon(Icons.file_present_outlined),
          label: const Text('Export Preview'),
        ),
        FilledButton.icon(
          onPressed:
              widget.controller.scene == null ||
                  widget.controller.isLoading ||
                  widget.controller.isExporting
              ? null
              : () {
                  unawaited(_confirmAndApplyToFiles());
                },
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text('Apply To Files'),
        ),
      ],
    );
  }

  Future<void> _confirmAndApplyToFiles() async {
    final pendingChanges = widget.controller.pendingChanges;
    if (!pendingChanges.hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending changes to apply.')),
      );
      return;
    }

    final changedEntries = pendingChanges.changedEntryIds.length;
    final changedFiles = pendingChanges.fileDiffs.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Apply Changes To Files'),
          content: Text(
            'This will write $changedEntries edited collider entries across '
            '$changedFiles file(s).\n\n'
            'A .bak backup file will be written for each modified source file '
            'before applying changes.',
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

    final exportError = widget.controller.exportError;
    if (exportError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Apply failed: $exportError')));
      return;
    }

    final exportResult = widget.controller.lastExportResult;
    if (exportResult == null || !exportResult.applied) {
      return;
    }
    final backupCount = _backupCount(exportResult);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          backupCount > 0
              ? 'Applied changes. Wrote $backupCount backup file(s).'
              : 'Applied changes.',
        ),
      ),
    );
  }

  int _backupCount(ExportResult exportResult) {
    for (final artifact in exportResult.artifacts) {
      if (artifact.title != 'collider_backups.md') {
        continue;
      }
      final lines = artifact.content
          .split('\n')
          .where((line) => line.startsWith('- '))
          .length;
      return lines;
    }
    return 0;
  }

  Widget _buildStatusRow() {
    final statusText = widget.controller.isLoading
        ? 'Loading...'
        : widget.controller.isExporting
        ? 'Exporting...'
        : widget.controller.loadError == null
        ? 'Ready'
        : 'Load error';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text(statusText)),
        Chip(label: Text('Errors: ${widget.controller.errorCount}')),
        Chip(label: Text('Warnings: ${widget.controller.warningCount}')),
        Chip(
          label: Text('Dirty entries: ${widget.controller.dirtyEntryCount}'),
        ),
        Chip(label: Text('Dirty files: ${widget.controller.dirtyFileCount}')),
        if (widget.controller.exportError != null)
          const Chip(label: Text('Export error')),
        if (widget.controller.pendingChangesError != null)
          const Chip(label: Text('Diff error')),
        if (widget.controller.lastExportResult != null)
          Chip(
            label: Text(
              widget.controller.lastExportResult!.applied
                  ? 'Last export: applied'
                  : 'Last export: preview',
            ),
          ),
      ],
    );
  }

  Widget _buildSceneBody(
    ColliderScene? colliderScene,
    List<ColliderEntry> visibleEntries,
  ) {
    final error = widget.controller.loadError;
    if (error != null) {
      return _ErrorPanel(message: error);
    }
    if (widget.controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (colliderScene == null) {
      return const Center(child: Text('No scene loaded.'));
    }

    final selectedEntry = _selectedEntry(colliderScene);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _buildEntryListPanel(
            scene: colliderScene,
            visibleEntries: visibleEntries,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildViewportPanel(selectedEntry),
                ),
                const SizedBox(height: 12),
                _buildInspector(selectedEntry),
                const SizedBox(height: 12),
                SizedBox(height: 180, child: _buildValidationPanel()),
                const SizedBox(height: 12),
                SizedBox(height: 300, child: _buildPendingDiffPanel()),
                const SizedBox(height: 12),
                SizedBox(height: 230, child: _buildExportPanel()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryListPanel({
    required ColliderScene scene,
    required List<ColliderEntry> visibleEntries,
  }) {
    final dirtyVisibleCount = visibleEntries
        .where((entry) => widget.controller.dirtyEntryIds.contains(entry.id))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 340,
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search Entries',
                              hintText: 'id, label, source path',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.trim().toLowerCase();
                              });
                            },
                          ),
                        ),
                        Text(
                          'Visible: ${visibleEntries.length} / ${scene.entries.length}',
                        ),
                        Text('Dirty visible: $dirtyVisibleCount'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _typeFilterChip(label: 'All', type: null),
                        _typeFilterChip(
                          label: 'Players',
                          type: ColliderEntityType.player,
                        ),
                        _typeFilterChip(
                          label: 'Enemies',
                          type: ColliderEntityType.enemy,
                        ),
                        _typeFilterChip(
                          label: 'Projectiles',
                          type: ColliderEntityType.projectile,
                        ),
                        FilterChip(
                          selected: _showDirtyOnly,
                          label: const Text('Dirty only'),
                          onSelected: (selected) {
                            setState(() {
                              _showDirtyOnly = selected;
                            });
                          },
                        ),
                        OutlinedButton.icon(
                          onPressed: dirtyVisibleCount == 0
                              ? null
                              : () => _selectAdjacentDirty(
                                  scene,
                                  visibleEntries,
                                  reverse: true,
                                ),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Prev Dirty'),
                        ),
                        OutlinedButton.icon(
                          onPressed: dirtyVisibleCount == 0
                              ? null
                              : () => _selectAdjacentDirty(
                                  scene,
                                  visibleEntries,
                                  reverse: false,
                                ),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Next Dirty'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _ColliderTable(
            entries: visibleEntries,
            selectedId: _selectedEntryId,
            dirtyEntryIds: widget.controller.dirtyEntryIds,
            onSelect: (id) {
              _selectEntryById(scene, id);
            },
          ),
        ),
      ],
    );
  }

  ChoiceChip _typeFilterChip({
    required String label,
    required ColliderEntityType? type,
  }) {
    return ChoiceChip(
      selected: _entityTypeFilter == type,
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _entityTypeFilter = type;
        });
      },
    );
  }

  Widget _buildInspector(ColliderEntry? selectedEntry) {
    return EditorInspectorPanel(
      selectedEntry: selectedEntry,
      isDirty:
          selectedEntry != null &&
          widget.controller.dirtyEntryIds.contains(selectedEntry.id),
      halfXController: _halfXController,
      halfYController: _halfYController,
      offsetXController: _offsetXController,
      offsetYController: _offsetYController,
      anchorXPxController: _anchorXPxController,
      anchorYPxController: _anchorYPxController,
      frameWidthController: _frameWidthController,
      frameHeightController: _frameHeightController,
      renderScaleController: _renderScaleController,
      onApply: selectedEntry == null
          ? null
          : () => _applyInspectorEdits(selectedEntry),
    );
  }

  Widget _buildValidationPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Validation', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: widget.controller.issues.isEmpty
                  ? const Text('No validation issues.')
                  : ListView.builder(
                      itemCount: widget.controller.issues.length,
                      itemBuilder: (context, index) {
                        final issue = widget.controller.issues[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            _iconForSeverity(issue.severity),
                            color: _colorForSeverity(issue.severity),
                          ),
                          title: Text(issue.message),
                          subtitle: issue.sourcePath == null
                              ? null
                              : Text(issue.sourcePath!),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDiffPanel() {
    final pendingChanges = widget.controller.pendingChanges;
    final diffError = widget.controller.pendingChangesError;
    final selectedDiff = _selectedDiff(pendingChanges);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending File Diff',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'entries: ${pendingChanges.changedEntryIds.length} '
              'files: ${pendingChanges.fileDiffs.length}',
            ),
            if (pendingChanges.fileDiffs.length > 1) ...[
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedDiff?.relativePath,
                items: [
                  for (final fileDiff in pendingChanges.fileDiffs)
                    DropdownMenuItem<String>(
                      value: fileDiff.relativePath,
                      child: Text(
                        '${fileDiff.relativePath} (${fileDiff.editCount})',
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedDiffPath = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: diffError != null
                  ? SelectableText(diffError)
                  : selectedDiff == null
                  ? const Text('No pending file changes.')
                  : SingleChildScrollView(
                      child: SelectableText(
                        selectedDiff.unifiedDiff,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportPanel() {
    final exportResult = widget.controller.lastExportResult;
    final exportError = widget.controller.exportError;
    final artifact = _selectedArtifact(exportResult);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (exportError != null) ...[
              SelectableText(
                exportError,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
            ],
            if (exportResult != null) ...[
              Text('mode: ${exportResult.mode.name}'),
              Text('applied: ${exportResult.applied}'),
              if (exportResult.artifacts.length > 1) ...[
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: artifact?.title,
                  items: [
                    for (final item in exportResult.artifacts)
                      DropdownMenuItem<String>(
                        value: item.title,
                        child: Text(item.title),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedArtifactTitle = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
            Expanded(
              child: artifact == null
                  ? const Text('No export preview generated yet.')
                  : SingleChildScrollView(
                      child: SelectableText(artifact.content),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<ColliderEntry> _filteredEntries(List<ColliderEntry> entries) {
    final query = _searchQuery;
    return entries
        .where((entry) {
          if (_entityTypeFilter != null &&
              entry.entityType != _entityTypeFilter) {
            return false;
          }
          if (_showDirtyOnly &&
              !widget.controller.dirtyEntryIds.contains(entry.id)) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          final haystack = '${entry.id} ${entry.label} ${entry.sourcePath}'
              .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _selectAdjacentDirty(
    ColliderScene scene,
    List<ColliderEntry> visibleEntries, {
    required bool reverse,
  }) {
    final dirtyEntries = visibleEntries
        .where((entry) => widget.controller.dirtyEntryIds.contains(entry.id))
        .toList(growable: false);
    if (dirtyEntries.isEmpty) {
      return;
    }

    final currentIndex = dirtyEntries.indexWhere(
      (entry) => entry.id == _selectedEntryId,
    );
    final targetEntry = currentIndex == -1
        ? (reverse ? dirtyEntries.last : dirtyEntries.first)
        : dirtyEntries[reverse
              ? (currentIndex - 1 + dirtyEntries.length) % dirtyEntries.length
              : (currentIndex + 1) % dirtyEntries.length];
    _selectEntryById(scene, targetEntry.id);
  }

  void _selectEntryById(ColliderScene scene, String entryId) {
    ColliderEntry? entry;
    for (final candidate in scene.entries) {
      if (candidate.id == entryId) {
        entry = candidate;
        break;
      }
    }
    if (entry == null) {
      return;
    }
    final selectedEntry = entry;

    setState(() {
      _resetViewportSelectionState();
      _selectedEntryId = selectedEntry.id;
      _syncInspectorFromEntry(selectedEntry);
    });
  }

  void _resetViewportSelectionState() {
    // No interactive viewport state to reset in simplified scene view.
  }

  void _ensureSelection(
    ColliderScene? scene,
    List<ColliderEntry> visibleEntries,
  ) {
    if (scene == null || visibleEntries.isEmpty) {
      _resetViewportSelectionState();
      _selectedEntryId = null;
      _syncInspectorFromEntry(null);
      return;
    }

    final selectedStillValid = visibleEntries.any(
      (entry) => entry.id == _selectedEntryId,
    );
    if (selectedStillValid) {
      return;
    }

    _resetViewportSelectionState();
    _selectedEntryId = visibleEntries.first.id;
    _syncInspectorFromEntry(visibleEntries.first);
  }

  void _ensureDiffSelection(PendingChanges pendingChanges) {
    if (pendingChanges.fileDiffs.isEmpty) {
      _selectedDiffPath = null;
      return;
    }

    final selectedStillValid = pendingChanges.fileDiffs.any(
      (diff) => diff.relativePath == _selectedDiffPath,
    );
    if (selectedStillValid) {
      return;
    }
    _selectedDiffPath = pendingChanges.fileDiffs.first.relativePath;
  }

  PendingFileDiff? _selectedDiff(PendingChanges pendingChanges) {
    final selectedPath = _selectedDiffPath;
    if (selectedPath == null) {
      return pendingChanges.fileDiffs.isEmpty
          ? null
          : pendingChanges.fileDiffs.first;
    }
    for (final diff in pendingChanges.fileDiffs) {
      if (diff.relativePath == selectedPath) {
        return diff;
      }
    }
    return pendingChanges.fileDiffs.isEmpty
        ? null
        : pendingChanges.fileDiffs.first;
  }

  void _ensureArtifactSelection(ExportResult? exportResult) {
    final artifacts = exportResult?.artifacts;
    if (artifacts == null || artifacts.isEmpty) {
      _selectedArtifactTitle = null;
      return;
    }

    final selectedStillValid = artifacts.any(
      (artifact) => artifact.title == _selectedArtifactTitle,
    );
    if (selectedStillValid) {
      return;
    }
    _selectedArtifactTitle = artifacts.first.title;
  }

  ExportArtifact? _selectedArtifact(ExportResult? exportResult) {
    final artifacts = exportResult?.artifacts;
    if (artifacts == null || artifacts.isEmpty) {
      return null;
    }
    final selectedTitle = _selectedArtifactTitle;
    if (selectedTitle == null) {
      return artifacts.first;
    }
    for (final artifact in artifacts) {
      if (artifact.title == selectedTitle) {
        return artifact;
      }
    }
    return artifacts.first;
  }

  ColliderEntry? _selectedEntry(ColliderScene scene) {
    final selectedId = _selectedEntryId;
    if (selectedId == null) {
      return null;
    }
    for (final entry in scene.entries) {
      if (entry.id == selectedId) {
        return entry;
      }
    }
    return null;
  }

  void _syncInspectorFromEntry(ColliderEntry? entry) {
    if (entry == null) {
      _halfXController.text = '';
      _halfYController.text = '';
      _offsetXController.text = '';
      _offsetYController.text = '';
      _renderScaleController.text = '';
      _anchorXPxController.text = '';
      _anchorYPxController.text = '';
      _frameWidthController.text = '';
      _frameHeightController.text = '';
      return;
    }

    _syncInspectorFromValues(
      halfX: entry.halfX,
      halfY: entry.halfY,
      offsetX: entry.offsetX,
      offsetY: entry.offsetY,
    );
    final reference = entry.referenceVisual;
    _renderScaleController.text =
        reference?.renderScale?.toStringAsFixed(3) ?? '';
    _anchorXPxController.text = reference?.anchorXPx?.toStringAsFixed(3) ?? '';
    _anchorYPxController.text = reference?.anchorYPx?.toStringAsFixed(3) ?? '';
    _frameWidthController.text =
        reference?.frameWidth?.toStringAsFixed(3) ?? '';
    _frameHeightController.text =
        reference?.frameHeight?.toStringAsFixed(3) ?? '';
  }

  void _applyInspectorEdits(ColliderEntry selectedEntry) {
    final halfX = double.tryParse(_halfXController.text.trim());
    final halfY = double.tryParse(_halfYController.text.trim());
    final offsetX = double.tryParse(_offsetXController.text.trim());
    final offsetY = double.tryParse(_offsetYController.text.trim());

    if (halfX == null || halfY == null || offsetX == null || offsetY == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All collider fields must be valid numbers.'),
        ),
      );
      return;
    }

    final reference = selectedEntry.referenceVisual;
    double? renderScale;
    double? anchorXPx;
    double? anchorYPx;
    if (reference != null) {
      if (reference.renderScaleBinding != null) {
        renderScale = double.tryParse(_renderScaleController.text.trim());
        if (renderScale == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('renderScale must be a valid number.'),
            ),
          );
          return;
        }
      }
      if (reference.anchorBinding != null) {
        anchorXPx = double.tryParse(_anchorXPxController.text.trim());
        anchorYPx = double.tryParse(_anchorYPxController.text.trim());
        if (anchorXPx == null || anchorYPx == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('anchorPoint.x/y must be valid numbers.'),
            ),
          );
          return;
        }
      }
    }

    _applyEntryValues(
      selectedEntry.id,
      halfX: halfX,
      halfY: halfY,
      offsetX: offsetX,
      offsetY: offsetY,
      renderScale: renderScale,
      anchorXPx: anchorXPx,
      anchorYPx: anchorYPx,
    );
  }

  void _applyEntryValues(
    String entryId, {
    required double halfX,
    required double halfY,
    required double offsetX,
    required double offsetY,
    double? renderScale,
    double? anchorXPx,
    double? anchorYPx,
  }) {
    final payload = <String, Object?>{
      'id': entryId,
      'halfX': halfX,
      'halfY': halfY,
      'offsetX': offsetX,
      'offsetY': offsetY,
    };
    if (renderScale != null) {
      payload['renderScale'] = renderScale;
    }
    if (anchorXPx != null) {
      payload['anchorXPx'] = anchorXPx;
    }
    if (anchorYPx != null) {
      payload['anchorYPx'] = anchorYPx;
    }
    widget.controller.applyCommand(
      AuthoringCommand(kind: 'update_entry', payload: payload),
    );
  }

  void _updateState(VoidCallback callback) {
    setState(callback);
  }

  IconData _iconForSeverity(ValidationSeverity severity) {
    switch (severity) {
      case ValidationSeverity.info:
        return Icons.info_outline;
      case ValidationSeverity.warning:
        return Icons.warning_amber_rounded;
      case ValidationSeverity.error:
        return Icons.error_outline;
    }
  }

  Color _colorForSeverity(ValidationSeverity severity) {
    switch (severity) {
      case ValidationSeverity.info:
        return Colors.lightBlueAccent;
      case ValidationSeverity.warning:
        return Colors.amberAccent;
      case ValidationSeverity.error:
        return Colors.redAccent;
    }
  }
}

class _ColliderTable extends StatelessWidget {
  const _ColliderTable({
    required this.entries,
    required this.selectedId,
    required this.dirtyEntryIds,
    required this.onSelect,
  });

  final List<ColliderEntry> entries;
  final String? selectedId;
  final Set<String> dirtyEntryIds;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [DataColumn(label: Text('ID'))],
          rows: entries
              .map((entry) {
                final isDirty = dirtyEntryIds.contains(entry.id);
                return DataRow(
                  selected: entry.id == selectedId,
                  onSelectChanged: (_) => onSelect(entry.id),
                  cells: [DataCell(Text(isDirty ? '* ${entry.id}' : entry.id))],
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF3F1F1F),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workspace Load Failed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}
