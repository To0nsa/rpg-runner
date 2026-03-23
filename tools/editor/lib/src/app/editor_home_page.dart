import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../collider/collider_domain_models.dart';
import '../domain/authoring_types.dart';
import '../session/editor_session_controller.dart';

class EditorHomePage extends StatefulWidget {
  const EditorHomePage({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  static const double _viewportMinHalfExtent = 0.1;
  static const double _viewportMinZoom = 0.2;
  static const double _viewportMaxZoom = 6.0;
  static const double _valueEpsilon = 0.000001;
  static const double _fallbackRuntimeGridCellSize = 32.0;

  late final TextEditingController _workspaceController;
  late final TextEditingController _halfXController;
  late final TextEditingController _halfYController;
  late final TextEditingController _offsetXController;
  late final TextEditingController _offsetYController;
  late final TextEditingController _anchorXPxController;
  late final TextEditingController _anchorYPxController;
  late final TextEditingController _renderScaleController;
  late final TextEditingController _searchController;
  late final FocusNode _viewportFocusNode;

  String? _selectedEntryId;
  String? _selectedDiffPath;
  String? _selectedArtifactTitle;
  _ViewportDragSession? _dragSession;
  _ViewportPanSession? _panSession;
  String? _draftEntryId;
  double? _draftHalfX;
  double? _draftHalfY;
  double? _draftOffsetX;
  double? _draftOffsetY;
  double _viewportZoom = 1.0;
  Offset _viewportPanPixels = Offset.zero;
  String _searchQuery = '';
  ColliderEntityType? _entityTypeFilter;
  bool _showDirtyOnly = false;
  double? _snapFactor = 0.25;
  bool _showReferenceLayer = true;
  bool _showReferencePoints = true;
  double _referenceOpacity = 0.8;
  String? _referenceAnimKeyOverride;
  int? _referenceRowOverride;
  int? _referenceFrameOverride;
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
    _renderScaleController = TextEditingController();
    _searchController = TextEditingController();
    _viewportFocusNode = FocusNode(debugLabel: 'colliderViewport');
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
    _renderScaleController.dispose();
    _searchController.dispose();
    _viewportFocusNode.dispose();
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
                SizedBox(
                  height: 280,
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

  Widget _buildViewportPanel(ColliderEntry? selectedEntry) {
    if (selectedEntry == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No collider entry selected.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final scene = widget.controller.colliderScene;
            final runtimeGridCellSize = _runtimeGridCellSize(scene);
            final previewEntry = _previewEntry(selectedEntry);
            final scale =
                _computeViewportScale(viewportSize, previewEntry) *
                _viewportZoom;
            final activeHandle = _dragSession?.entryId == selectedEntry.id
                ? _dragSession!.handle
                : null;
            final zoomLabel = _viewportZoom.toStringAsFixed(2);
            final resolvedReference = _showReferenceLayer
                ? _resolveReferenceVisual(previewEntry)
                : null;
            final referenceAnimKey = resolvedReference == null
                ? null
                : _effectiveReferenceAnimKey(resolvedReference);
            final referenceAnimView = resolvedReference == null
                ? null
                : _effectiveReferenceAnimView(resolvedReference);
            if (referenceAnimView != null) {
              unawaited(
                _ensureReferenceImageLoaded(referenceAnimView.absolutePath),
              );
            }
            final resolvedImage = referenceAnimView == null
                ? null
                : _referenceImageCache[referenceAnimView.absolutePath];
            final referenceAssetPath = previewEntry.referenceVisual?.assetPath;
            final referenceRow = referenceAnimView == null
                ? 0
                : _effectiveReferenceRow(referenceAnimView);
            final referenceFrame = referenceAnimView == null
                ? 0
                : _effectiveReferenceFrame(referenceAnimView);
            final referenceStatusText = referenceAssetPath == null
                ? 'No reference visual metadata'
                : resolvedReference == null
                ? 'Missing reference: assets/images/$referenceAssetPath'
                : referenceAnimView == null
                ? 'Reference metadata has no valid anim key source'
                : _referenceImageFailed.contains(referenceAnimView.absolutePath)
                ? 'Failed loading reference: ${referenceAnimView.displayPath}'
                : resolvedImage == null
                ? 'Loading reference: ${referenceAnimView.displayPath}'
                : 'Reference: ${referenceAnimView.displayPath} '
                      '(key ${referenceAnimKey ?? '-'}, row $referenceRow, '
                      'frame $referenceFrame)';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Scene View',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _applyZoomDelta(0.12),
                        icon: const Icon(Icons.zoom_in, size: 18),
                        label: const Text('Zoom In'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => _applyZoomDelta(-0.12),
                        icon: const Icon(Icons.zoom_out, size: 18),
                        label: const Text('Zoom Out'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: _resetViewportTransform,
                        icon: const Icon(Icons.center_focus_strong, size: 18),
                        label: Text('Reset View ($zoomLabel x)'),
                      ),
                      const SizedBox(width: 6),
                      Center(
                        child: DropdownButton<String>(
                          value: _snapMenuValue,
                          isDense: true,
                          items: [
                            DropdownMenuItem(
                              value: 'off',
                              child: Text('Snap: Off'),
                            ),
                            DropdownMenuItem(
                              value: '1x',
                              child: Text(
                                'Snap: 1x (${runtimeGridCellSize.toStringAsFixed(2)})',
                              ),
                            ),
                            DropdownMenuItem(
                              value: '1/2x',
                              child: Text(
                                'Snap: 1/2x (${(runtimeGridCellSize * 0.5).toStringAsFixed(2)})',
                              ),
                            ),
                            DropdownMenuItem(
                              value: '1/4x',
                              child: Text(
                                'Snap: 1/4x (${(runtimeGridCellSize * 0.25).toStringAsFixed(2)})',
                              ),
                            ),
                            DropdownMenuItem(
                              value: '1/8x',
                              child: Text(
                                'Snap: 1/8x (${(runtimeGridCellSize * 0.125).toStringAsFixed(2)})',
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _snapFactor = switch (value) {
                                'off' => null,
                                '1x' => 1.0,
                                '1/2x' => 0.5,
                                '1/4x' => 0.25,
                                '1/8x' => 0.125,
                                _ => _snapFactor,
                              };
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Center(
                        child: Chip(
                          label: Text(
                            'Grid ${runtimeGridCellSize.toStringAsFixed(2)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Center(
                        child: FilterChip(
                          selected: _showReferenceLayer,
                          label: const Text('Reference'),
                          onSelected: (selected) {
                            setState(() {
                              _showReferenceLayer = selected;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Center(
                        child: FilterChip(
                          selected: _showReferencePoints,
                          label: const Text('Ref Points'),
                          onSelected: (selected) {
                            setState(() {
                              _showReferencePoints = selected;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Center(
                        child: DropdownButton<double>(
                          value: _referenceOpacity,
                          isDense: true,
                          items: const [
                            DropdownMenuItem<double>(
                              value: 1.0,
                              child: Text('Ref Opacity: 100%'),
                            ),
                            DropdownMenuItem<double>(
                              value: 0.2,
                              child: Text('Ref Opacity: 20%'),
                            ),
                            DropdownMenuItem<double>(
                              value: 0.35,
                              child: Text('Ref Opacity: 35%'),
                            ),
                            DropdownMenuItem<double>(
                              value: 0.45,
                              child: Text('Ref Opacity: 45%'),
                            ),
                            DropdownMenuItem<double>(
                              value: 0.6,
                              child: Text('Ref Opacity: 60%'),
                            ),
                            DropdownMenuItem<double>(
                              value: 0.8,
                              child: Text('Ref Opacity: 80%'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _referenceOpacity = value;
                            });
                          },
                        ),
                      ),
                      if (resolvedReference != null) ...[
                        if (referenceAnimKey != null &&
                            resolvedReference.animKeys.length > 1) ...[
                          const SizedBox(width: 6),
                          Center(
                            child: DropdownButton<String>(
                              value: referenceAnimKey,
                              isDense: true,
                              items: [
                                for (final key in resolvedReference.animKeys)
                                  DropdownMenuItem<String>(
                                    value: key,
                                    child: Text('Anim: $key'),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                _selectReferenceAnimKey(
                                  resolvedReference,
                                  value,
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                      if (referenceAnimView != null) ...[
                        const SizedBox(width: 6),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _adjustReferenceRow(referenceAnimView, -1);
                            },
                            icon: const Icon(Icons.remove, size: 16),
                            label: Text('Row $referenceRow'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _adjustReferenceRow(referenceAnimView, 1);
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Row +'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _adjustReferenceFrame(referenceAnimView, -1);
                            },
                            icon: const Icon(Icons.remove, size: 16),
                            label: Text('Frame $referenceFrame'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _adjustReferenceFrame(referenceAnimView, 1);
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Frame +'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _resetReferenceFrameSelection();
                            },
                            icon: const Icon(Icons.restart_alt, size: 16),
                            label: const Text('Ref Reset'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '$referenceStatusText | drag handles edit | drag empty area '
                  'pans | wheel zoom | arrows nudge offsets | Alt+arrows '
                  'nudge extents',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        if (event.scrollDelta.dy < 0) {
                          _applyZoomDelta(0.08);
                        } else if (event.scrollDelta.dy > 0) {
                          _applyZoomDelta(-0.08);
                        }
                      }
                    },
                    child: Focus(
                      focusNode: _viewportFocusNode,
                      onFocusChange: (_) {
                        setState(() {});
                      },
                      onKeyEvent: (node, event) {
                        return _handleViewportKeyEvent(event, selectedEntry);
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _viewportFocusNode.requestFocus();
                        },
                        onPanStart: (details) {
                          _viewportFocusNode.requestFocus();
                          _startViewportInteraction(
                            selectedEntry,
                            previewEntry,
                            viewportSize,
                            scale,
                            details.localPosition,
                          );
                        },
                        onPanUpdate: (details) {
                          _updateViewportInteraction(details.localPosition);
                        },
                        onPanEnd: (_) {
                          _finishViewportInteraction();
                        },
                        onPanCancel: _cancelViewportInteraction,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _viewportFocusNode.hasFocus
                                  ? const Color(0xFF7CE5FF)
                                  : const Color(0xFF1B2A36),
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const Positioned.fill(
                                child: ColoredBox(color: Color(0xFF111A22)),
                              ),
                              CustomPaint(
                                painter: _ColliderViewportPainter(
                                  entry: previewEntry,
                                  scale: scale,
                                  gridCellSize: runtimeGridCellSize,
                                  panPixels: _viewportPanPixels,
                                  activeHandle: null,
                                  drawGridAndAxes: true,
                                  drawColliderFill: true,
                                  drawColliderOutline: false,
                                  drawHandles: false,
                                  fillColor:
                                      resolvedReference != null &&
                                          _showReferenceLayer
                                      ? const Color(0x1F22D3EE)
                                      : const Color(0x5522D3EE),
                                ),
                              ),
                              if (resolvedReference != null &&
                                  referenceAnimView != null &&
                                  resolvedImage != null)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: _referenceOpacity,
                                      child: CustomPaint(
                                        painter: _ReferenceFramePainter(
                                          image: resolvedImage,
                                          row: referenceRow,
                                          frame: referenceFrame,
                                          destinationRect: _referenceRect(
                                            scale: scale,
                                            viewportSize: viewportSize,
                                            reference: resolvedReference,
                                          ),
                                          anchorX: resolvedReference.anchorX,
                                          anchorY: resolvedReference.anchorY,
                                          showReferencePoints:
                                              _showReferencePoints,
                                          frameWidth:
                                              resolvedReference.frameWidth,
                                          frameHeight:
                                              resolvedReference.frameHeight,
                                          gridColumns: referenceAnimView
                                              .defaultGridColumns,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              CustomPaint(
                                painter: _ColliderViewportPainter(
                                  entry: previewEntry,
                                  scale: scale,
                                  gridCellSize: runtimeGridCellSize,
                                  panPixels: _viewportPanPixels,
                                  activeHandle: activeHandle,
                                  drawGridAndAxes: false,
                                  drawColliderFill: false,
                                  drawColliderOutline: true,
                                  drawHandles: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInspector(ColliderEntry? selectedEntry) {
    if (selectedEntry == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No collider entry selected.'),
        ),
      );
    }

    final isDirty = widget.controller.dirtyEntryIds.contains(selectedEntry.id);
    final reference = selectedEntry.referenceVisual;
    final canEditRenderScale = reference?.renderScaleBinding != null;
    final canEditAnchor = reference?.anchorBinding != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedEntry.id,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(label: Text(isDirty ? 'Dirty' : 'Clean')),
              ],
            ),
            const SizedBox(height: 4),
            Text(selectedEntry.sourcePath),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _halfXController,
                    decoration: const InputDecoration(
                      labelText: 'halfX',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _halfYController,
                    decoration: const InputDecoration(
                      labelText: 'halfY',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _offsetXController,
                    decoration: const InputDecoration(
                      labelText: 'offsetX',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _offsetYController,
                    decoration: const InputDecoration(
                      labelText: 'offsetY',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _renderScaleController,
                    readOnly: !canEditRenderScale,
                    decoration: InputDecoration(
                      labelText: 'renderScale',
                      border: const OutlineInputBorder(),
                      helperText: canEditRenderScale
                          ? null
                          : (reference == null
                                ? 'No render metadata'
                                : 'Read-only (source binding unavailable)'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _anchorXPxController,
                    readOnly: !canEditAnchor,
                    decoration: InputDecoration(
                      labelText: 'anchorInFramePx.x',
                      border: const OutlineInputBorder(),
                      helperText: canEditAnchor
                          ? null
                          : (reference == null
                                ? 'No render metadata'
                                : 'Read-only (source binding unavailable)'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _anchorYPxController,
                    readOnly: !canEditAnchor,
                    decoration: const InputDecoration(
                      labelText: 'anchorInFramePx.y',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => _applyInspectorEdits(selectedEntry),
                child: const Text('Apply Values'),
              ),
            ),
          ],
        ),
      ),
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

  ColliderEntry _previewEntry(ColliderEntry selectedEntry) {
    if (_draftEntryId != selectedEntry.id) {
      return selectedEntry;
    }
    return selectedEntry.copyWith(
      halfX: _draftHalfX,
      halfY: _draftHalfY,
      offsetX: _draftOffsetX,
      offsetY: _draftOffsetY,
    );
  }

  double _computeViewportScale(Size size, ColliderEntry entry) {
    final minSide = math.max(1.0, math.min(size.width, size.height));
    const viewportPadding = 28.0;
    final usableSide = math.max(1.0, minSide - viewportPadding * 2);
    final maxWorldSpan = math.max(
      24.0,
      math.max(
        entry.halfX + entry.offsetX.abs(),
        entry.halfY + entry.offsetY.abs(),
      ),
    );
    return usableSide / (maxWorldSpan * 2.0);
  }

  double _runtimeGridCellSize(ColliderScene? scene) {
    final raw = scene?.runtimeGridCellSize;
    if (raw == null || !raw.isFinite || raw <= 0) {
      return _fallbackRuntimeGridCellSize;
    }
    return raw;
  }

  String get _snapMenuValue {
    final factor = _snapFactor;
    if (factor == null) {
      return 'off';
    }
    return switch (factor) {
      1.0 => '1x',
      0.5 => '1/2x',
      0.25 => '1/4x',
      0.125 => '1/8x',
      _ => '1/4x',
    };
  }

  double _snapValue(double value) {
    final step = _resolvedSnapStep();
    if (step == null || step <= 0) {
      return value;
    }
    return (value / step).roundToDouble() * step;
  }

  double _snapHalfExtent(double value) =>
      math.max(_viewportMinHalfExtent, _snapValue(value));

  double? _resolvedSnapStep() {
    final factor = _snapFactor;
    if (factor == null || factor <= 0) {
      return null;
    }
    return _runtimeGridCellSize(widget.controller.colliderScene) * factor;
  }

  _ResolvedReferenceVisual? _resolveReferenceVisual(ColliderEntry entry) {
    final reference = entry.referenceVisual;
    final workspace = widget.controller.workspace;
    if (reference == null || workspace == null) {
      return null;
    }

    final frameWidth = reference.frameWidth;
    final frameHeight = reference.frameHeight;
    final resolvedFrameWidth = frameWidth != null && frameWidth > 0
        ? frameWidth
        : math.max(1.0, entry.halfX * 2.0);
    final resolvedFrameHeight = frameHeight != null && frameHeight > 0
        ? frameHeight
        : math.max(1.0, entry.halfY * 2.0);
    final resolvedRenderScale =
        reference.renderScale != null && reference.renderScale! > 0
        ? reference.renderScale!
        : 1.0;
    final resolvedAnchorX = _normalizeReferenceAnchor(
      reference.anchorXPx,
      resolvedFrameWidth,
    );
    final resolvedAnchorY = _normalizeReferenceAnchor(
      reference.anchorYPx,
      resolvedFrameHeight,
    );

    _ResolvedReferenceAnimView? resolveAnimView({
      required String key,
      required String assetPath,
      required int row,
      required int frameStart,
      required int? frameCount,
      required int? gridColumns,
    }) {
      final normalizedAssetPath = assetPath.replaceAll('\\', '/');
      final relativeImagePath = 'assets/images/$normalizedAssetPath';
      final absoluteImagePath = workspace.resolve(relativeImagePath);
      final file = File(absoluteImagePath);
      if (!file.existsSync()) {
        return null;
      }
      return _ResolvedReferenceAnimView(
        key: key,
        absolutePath: absoluteImagePath,
        displayPath: relativeImagePath.replaceAll('\\', '/'),
        defaultRow: row,
        defaultFrameStart: frameStart,
        defaultFrameCount: frameCount,
        defaultGridColumns: gridColumns,
      );
    }

    final animViewsByKey = <String, _ResolvedReferenceAnimView>{};
    if (reference.animViewsByKey.isNotEmpty) {
      for (final animView in reference.animViewsByKey.values) {
        final resolvedView = resolveAnimView(
          key: animView.key,
          assetPath: animView.assetPath,
          row: animView.row,
          frameStart: animView.frameStart,
          frameCount: animView.frameCount,
          gridColumns: animView.gridColumns,
        );
        if (resolvedView != null) {
          animViewsByKey[animView.key] = resolvedView;
        }
      }
    } else {
      final fallbackKey = reference.defaultAnimKey ?? 'idle';
      final fallbackView = resolveAnimView(
        key: fallbackKey,
        assetPath: reference.assetPath,
        row: reference.defaultRow,
        frameStart: reference.defaultFrameStart,
        frameCount: reference.defaultFrameCount,
        gridColumns: reference.defaultGridColumns,
      );
      if (fallbackView != null) {
        animViewsByKey[fallbackKey] = fallbackView;
      }
    }
    if (animViewsByKey.isEmpty) {
      return null;
    }

    return _ResolvedReferenceVisual(
      frameWidth: resolvedFrameWidth,
      frameHeight: resolvedFrameHeight,
      renderScale: resolvedRenderScale,
      anchorX: resolvedAnchorX,
      anchorY: resolvedAnchorY,
      defaultAnimKey: reference.defaultAnimKey,
      animViewsByKey: animViewsByKey,
    );
  }

  double _normalizeReferenceAnchor(double? anchorPx, double frameSize) {
    if (anchorPx == null || !anchorPx.isFinite || frameSize <= 0) {
      return 0.5;
    }
    return (anchorPx / frameSize).clamp(0.0, 1.0);
  }

  String? _effectiveReferenceAnimKey(_ResolvedReferenceVisual reference) {
    return reference.resolveAnimKey(_referenceAnimKeyOverride);
  }

  _ResolvedReferenceAnimView? _effectiveReferenceAnimView(
    _ResolvedReferenceVisual reference,
  ) {
    final key = _effectiveReferenceAnimKey(reference);
    if (key == null) {
      return null;
    }
    return reference.animViewsByKey[key];
  }

  int _effectiveReferenceRow(_ResolvedReferenceAnimView reference) {
    final row = _referenceRowOverride ?? reference.defaultRow;
    return row < 0 ? 0 : row;
  }

  int _effectiveReferenceFrame(_ResolvedReferenceAnimView reference) {
    final fallback = reference.defaultFrameStart;
    final value = _referenceFrameOverride ?? fallback;
    final minFrame = reference.defaultFrameStart;
    final maxFrame = reference.maxFrameIndex ?? 9999;
    return value.clamp(minFrame, maxFrame);
  }

  void _selectReferenceAnimKey(_ResolvedReferenceVisual reference, String key) {
    final resolvedKey = reference.resolveAnimKey(key);
    if (resolvedKey == null) {
      return;
    }
    setState(() {
      _referenceAnimKeyOverride = resolvedKey;
      _referenceRowOverride = null;
      _referenceFrameOverride = null;
    });
  }

  void _adjustReferenceRow(_ResolvedReferenceAnimView reference, int delta) {
    final next = math.max(0, _effectiveReferenceRow(reference) + delta);
    setState(() {
      _referenceRowOverride = next;
    });
  }

  void _adjustReferenceFrame(_ResolvedReferenceAnimView reference, int delta) {
    final minFrame = reference.defaultFrameStart;
    final maxFrame = reference.maxFrameIndex ?? 9999;
    final next = (_effectiveReferenceFrame(reference) + delta).clamp(
      minFrame,
      maxFrame,
    );
    setState(() {
      _referenceFrameOverride = next;
    });
  }

  void _resetReferenceFrameSelection() {
    setState(() {
      _referenceRowOverride = null;
      _referenceFrameOverride = null;
    });
  }

  Future<void> _ensureReferenceImageLoaded(String absolutePath) async {
    if (_referenceImageCache.containsKey(absolutePath) ||
        _referenceImageLoading.contains(absolutePath) ||
        _referenceImageFailed.contains(absolutePath)) {
      return;
    }
    _referenceImageLoading.add(absolutePath);
    try {
      final bytes = await File(absolutePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _referenceImageCache[absolutePath] = frame.image;
        _referenceImageLoading.remove(absolutePath);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _referenceImageLoading.remove(absolutePath);
        _referenceImageFailed.add(absolutePath);
      });
    }
  }

  Rect _referenceRect({
    required double scale,
    required Size viewportSize,
    required _ResolvedReferenceVisual reference,
  }) {
    final origin = _ViewportGeometry.canvasCenter(
      viewportSize,
      _viewportPanPixels,
    );
    final width = math.max(
      1.0,
      reference.frameWidth * reference.renderScale * scale,
    );
    final height = math.max(
      1.0,
      reference.frameHeight * reference.renderScale * scale,
    );
    final left = origin.dx - (reference.anchorX * width);
    final top = origin.dy - (reference.anchorY * height);
    return Rect.fromLTWH(left, top, width, height);
  }

  void _applyZoomDelta(double delta) {
    final nextZoom = (_viewportZoom + delta).clamp(
      _viewportMinZoom,
      _viewportMaxZoom,
    );
    if ((nextZoom - _viewportZoom).abs() <= _valueEpsilon) {
      return;
    }
    setState(() {
      _viewportZoom = nextZoom;
    });
  }

  void _resetViewportTransform() {
    setState(() {
      _viewportZoom = 1.0;
      _viewportPanPixels = Offset.zero;
      _panSession = null;
    });
  }

  KeyEventResult _handleViewportKeyEvent(
    KeyEvent event,
    ColliderEntry selectedEntry,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_dragSession != null || _panSession != null) {
      return KeyEventResult.handled;
    }

    final key = event.logicalKey;
    final shiftPressed =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );
    final altPressed =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.altLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.altRight,
        );
    final baseStep = _resolvedSnapStep() ?? 0.25;
    final step = shiftPressed ? baseStep * 4.0 : baseStep;

    var axisX = 0.0;
    var offsetAxisY = 0.0;
    var extentAxisY = 0.0;
    if (key == LogicalKeyboardKey.arrowLeft) {
      axisX = -1.0;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      axisX = 1.0;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      // Runtime world uses Y-down: move up means negative offsetY.
      offsetAxisY = -1.0;
      // For extent editing, keep "up increases height".
      extentAxisY = 1.0;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      // Runtime world uses Y-down: move down means positive offsetY.
      offsetAxisY = 1.0;
      // For extent editing, keep "down decreases height".
      extentAxisY = -1.0;
    } else {
      return KeyEventResult.ignored;
    }

    var halfX = selectedEntry.halfX;
    var halfY = selectedEntry.halfY;
    var offsetX = selectedEntry.offsetX;
    var offsetY = selectedEntry.offsetY;

    if (altPressed) {
      if (axisX != 0) {
        halfX = _snapHalfExtent(halfX + axisX * step);
      }
      if (extentAxisY != 0) {
        halfY = _snapHalfExtent(halfY + extentAxisY * step);
      }
    } else {
      if (axisX != 0) {
        offsetX = _snapValue(offsetX + axisX * step);
      }
      if (offsetAxisY != 0) {
        offsetY = _snapValue(offsetY + offsetAxisY * step);
      }
    }

    _dragSession = null;
    _panSession = null;
    _clearDraft();
    _applyEntryValues(
      selectedEntry.id,
      halfX: halfX,
      halfY: halfY,
      offsetX: offsetX,
      offsetY: offsetY,
    );
    return KeyEventResult.handled;
  }

  void _startViewportInteraction(
    ColliderEntry selectedEntry,
    ColliderEntry previewEntry,
    Size viewportSize,
    double scale,
    Offset localPosition,
  ) {
    final handle = _hitTestViewportHandle(
      localPosition: localPosition,
      size: viewportSize,
      entry: previewEntry,
      scale: scale,
      panPixels: _viewportPanPixels,
    );
    if (handle != null) {
      _setDraftFromEntry(previewEntry);
      setState(() {
        _panSession = null;
        _dragSession = _ViewportDragSession(
          entryId: selectedEntry.id,
          handle: handle,
          startPointer: localPosition,
          scale: scale,
          size: viewportSize,
          panPixels: _viewportPanPixels,
          startHalfX: previewEntry.halfX,
          startHalfY: previewEntry.halfY,
          startOffsetX: previewEntry.offsetX,
          startOffsetY: previewEntry.offsetY,
        );
      });
      return;
    }

    setState(() {
      _dragSession = null;
      _panSession = _ViewportPanSession(
        startPointer: localPosition,
        startPanPixels: _viewportPanPixels,
      );
      _clearDraft();
    });
  }

  void _updateViewportInteraction(Offset localPosition) {
    final panSession = _panSession;
    if (panSession != null) {
      setState(() {
        _viewportPanPixels =
            panSession.startPanPixels +
            (localPosition - panSession.startPointer);
      });
      return;
    }

    final session = _dragSession;
    if (session == null) {
      return;
    }

    final currentHalfX = _draftHalfX ?? session.startHalfX;
    final currentHalfY = _draftHalfY ?? session.startHalfY;
    final currentOffsetX = _draftOffsetX ?? session.startOffsetX;
    final currentOffsetY = _draftOffsetY ?? session.startOffsetY;

    var nextHalfX = currentHalfX;
    var nextHalfY = currentHalfY;
    var nextOffsetX = currentOffsetX;
    var nextOffsetY = currentOffsetY;

    final center = _ViewportGeometry.colliderCenter(
      session.size,
      currentOffsetX,
      currentOffsetY,
      session.scale,
      session.panPixels,
    );

    switch (session.handle) {
      case _ViewportDragHandle.center:
        final dx = (localPosition.dx - session.startPointer.dx) / session.scale;
        final dy = (localPosition.dy - session.startPointer.dy) / session.scale;
        nextOffsetX = _snapValue(session.startOffsetX + dx);
        nextOffsetY = _snapValue(session.startOffsetY + dy);
        break;
      case _ViewportDragHandle.rightEdge:
        final candidate = (localPosition.dx - center.dx) / session.scale;
        nextHalfX = _snapHalfExtent(candidate);
        break;
      case _ViewportDragHandle.topEdge:
        final candidate = (center.dy - localPosition.dy) / session.scale;
        nextHalfY = _snapHalfExtent(candidate);
        break;
    }

    setState(() {
      _draftHalfX = nextHalfX;
      _draftHalfY = nextHalfY;
      _draftOffsetX = nextOffsetX;
      _draftOffsetY = nextOffsetY;
      _syncInspectorFromValues(
        halfX: nextHalfX,
        halfY: nextHalfY,
        offsetX: nextOffsetX,
        offsetY: nextOffsetY,
      );
    });
  }

  void _finishViewportInteraction() {
    if (_panSession != null) {
      setState(() {
        _panSession = null;
      });
      return;
    }

    final session = _dragSession;
    setState(() {
      _dragSession = null;
    });
    if (session == null) {
      return;
    }

    final scene = widget.controller.colliderScene;
    if (scene == null) {
      _clearDraft();
      return;
    }
    final selectedEntry = _selectedEntry(scene);
    if (selectedEntry == null) {
      _clearDraft();
      return;
    }
    if (selectedEntry.id != session.entryId) {
      _clearDraft();
      return;
    }

    _commitDraftToController(selectedEntry);
    _clearDraft();
  }

  void _cancelViewportInteraction() {
    setState(() {
      _dragSession = null;
      _panSession = null;
    });
    final scene = widget.controller.colliderScene;
    final selectedEntry = scene == null ? null : _selectedEntry(scene);
    _clearDraft();
    if (selectedEntry != null) {
      _syncInspectorFromEntry(selectedEntry);
    }
  }

  _ViewportDragHandle? _hitTestViewportHandle({
    required Offset localPosition,
    required Size size,
    required ColliderEntry entry,
    required double scale,
    required Offset panPixels,
  }) {
    const hitRadius = 16.0;
    final center = _ViewportGeometry.colliderCenter(
      size,
      entry.offsetX,
      entry.offsetY,
      scale,
      panPixels,
    );
    final right = _ViewportGeometry.rightHandle(center, entry.halfX, scale);
    final top = _ViewportGeometry.topHandle(center, entry.halfY, scale);

    final candidates = <(_ViewportDragHandle, Offset)>[
      (_ViewportDragHandle.center, center),
      (_ViewportDragHandle.rightEdge, right),
      (_ViewportDragHandle.topEdge, top),
    ];
    for (final candidate in candidates) {
      final distance = (candidate.$2 - localPosition).distance;
      if (distance <= hitRadius) {
        return candidate.$1;
      }
    }
    return null;
  }

  void _setDraftFromEntry(ColliderEntry entry) {
    _draftEntryId = entry.id;
    _draftHalfX = entry.halfX;
    _draftHalfY = entry.halfY;
    _draftOffsetX = entry.offsetX;
    _draftOffsetY = entry.offsetY;
  }

  void _clearDraft() {
    _draftEntryId = null;
    _draftHalfX = null;
    _draftHalfY = null;
    _draftOffsetX = null;
    _draftOffsetY = null;
  }

  void _commitDraftToController(ColliderEntry baseline) {
    if (_draftEntryId != baseline.id) {
      return;
    }
    final halfX = _draftHalfX ?? baseline.halfX;
    final halfY = _draftHalfY ?? baseline.halfY;
    final offsetX = _draftOffsetX ?? baseline.offsetX;
    final offsetY = _draftOffsetY ?? baseline.offsetY;

    if ((halfX - baseline.halfX).abs() <= _valueEpsilon &&
        (halfY - baseline.halfY).abs() <= _valueEpsilon &&
        (offsetX - baseline.offsetX).abs() <= _valueEpsilon &&
        (offsetY - baseline.offsetY).abs() <= _valueEpsilon) {
      return;
    }

    _applyEntryValues(
      baseline.id,
      halfX: halfX,
      halfY: halfY,
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }

  void _syncInspectorFromValues({
    required double halfX,
    required double halfY,
    required double offsetX,
    required double offsetY,
  }) {
    _halfXController.text = halfX.toStringAsFixed(2);
    _halfYController.text = halfY.toStringAsFixed(2);
    _offsetXController.text = offsetX.toStringAsFixed(2);
    _offsetYController.text = offsetY.toStringAsFixed(2);
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
    _dragSession = null;
    _panSession = null;
    _clearDraft();
    _viewportZoom = 1.0;
    _viewportPanPixels = Offset.zero;
    _referenceAnimKeyOverride = null;
    _referenceRowOverride = null;
    _referenceFrameOverride = null;
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
              content: Text('anchorInFramePx.x/y must be valid numbers.'),
            ),
          );
          return;
        }
      }
    }

    _dragSession = null;
    _panSession = null;
    _clearDraft();
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
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('halfX')),
            DataColumn(label: Text('halfY')),
            DataColumn(label: Text('offsetX')),
            DataColumn(label: Text('offsetY')),
          ],
          rows: entries
              .map((entry) {
                final isDirty = dirtyEntryIds.contains(entry.id);
                return DataRow(
                  selected: entry.id == selectedId,
                  onSelectChanged: (_) => onSelect(entry.id),
                  cells: [
                    DataCell(Text(isDirty ? '* ${entry.id}' : entry.id)),
                    DataCell(Text(_typeLabel(entry.entityType))),
                    DataCell(Text(entry.halfX.toStringAsFixed(2))),
                    DataCell(Text(entry.halfY.toStringAsFixed(2))),
                    DataCell(Text(entry.offsetX.toStringAsFixed(2))),
                    DataCell(Text(entry.offsetY.toStringAsFixed(2))),
                  ],
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  String _typeLabel(ColliderEntityType entityType) {
    switch (entityType) {
      case ColliderEntityType.player:
        return 'player';
      case ColliderEntityType.enemy:
        return 'enemy';
      case ColliderEntityType.projectile:
        return 'projectile';
    }
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

class _ResolvedReferenceVisual {
  const _ResolvedReferenceVisual({
    required this.frameWidth,
    required this.frameHeight,
    required this.renderScale,
    required this.anchorX,
    required this.anchorY,
    required this.defaultAnimKey,
    required this.animViewsByKey,
  });

  final double frameWidth;
  final double frameHeight;
  final double renderScale;
  final double anchorX;
  final double anchorY;
  final String? defaultAnimKey;
  final Map<String, _ResolvedReferenceAnimView> animViewsByKey;

  List<String> get animKeys => List<String>.unmodifiable(animViewsByKey.keys);

  String? resolveAnimKey(String? preferredKey) {
    if (preferredKey != null && animViewsByKey.containsKey(preferredKey)) {
      return preferredKey;
    }
    final fallbackKey = defaultAnimKey;
    if (fallbackKey != null && animViewsByKey.containsKey(fallbackKey)) {
      return fallbackKey;
    }
    if (animViewsByKey.isEmpty) {
      return null;
    }
    return animViewsByKey.keys.first;
  }
}

class _ResolvedReferenceAnimView {
  const _ResolvedReferenceAnimView({
    required this.key,
    required this.absolutePath,
    required this.displayPath,
    required this.defaultRow,
    required this.defaultFrameStart,
    required this.defaultFrameCount,
    required this.defaultGridColumns,
  });

  final String key;
  final String absolutePath;
  final String displayPath;
  final int defaultRow;
  final int defaultFrameStart;
  final int? defaultFrameCount;
  final int? defaultGridColumns;

  int? get maxFrameIndex {
    final count = defaultFrameCount;
    if (count == null || count <= 0) {
      return null;
    }
    return defaultFrameStart + count - 1;
  }
}

enum _ViewportDragHandle { center, rightEdge, topEdge }

class _ViewportDragSession {
  const _ViewportDragSession({
    required this.entryId,
    required this.handle,
    required this.startPointer,
    required this.scale,
    required this.size,
    required this.panPixels,
    required this.startHalfX,
    required this.startHalfY,
    required this.startOffsetX,
    required this.startOffsetY,
  });

  final String entryId;
  final _ViewportDragHandle handle;
  final Offset startPointer;
  final double scale;
  final Size size;
  final Offset panPixels;
  final double startHalfX;
  final double startHalfY;
  final double startOffsetX;
  final double startOffsetY;
}

class _ViewportPanSession {
  const _ViewportPanSession({
    required this.startPointer,
    required this.startPanPixels,
  });

  final Offset startPointer;
  final Offset startPanPixels;
}

class _ReferenceFramePainter extends CustomPainter {
  const _ReferenceFramePainter({
    required this.image,
    required this.row,
    required this.frame,
    required this.destinationRect,
    required this.anchorX,
    required this.anchorY,
    required this.showReferencePoints,
    required this.frameWidth,
    required this.frameHeight,
    required this.gridColumns,
  });

  final ui.Image image;
  final int row;
  final int frame;
  final Rect destinationRect;
  final double anchorX;
  final double anchorY;
  final bool showReferencePoints;
  final double frameWidth;
  final double frameHeight;
  final int? gridColumns;

  @override
  void paint(Canvas canvas, Size size) {
    final safeFrameWidth = math.max(1.0, frameWidth);
    final safeFrameHeight = math.max(1.0, frameHeight);

    final maxColumns = math.max(1, (image.width / safeFrameWidth).floor());
    final maxRows = math.max(1, (image.height / safeFrameHeight).floor());
    final requestedFrame = frame < 0 ? 0 : frame;
    final requestedRow = row < 0 ? 0 : row;

    final columns = gridColumns != null && gridColumns! > 0
        ? gridColumns!
        : maxColumns;
    final rowOffset = requestedFrame ~/ columns;
    final columnIndex = requestedFrame % columns;
    final sourceRow = (requestedRow + rowOffset).clamp(0, maxRows - 1);
    final sourceColumn = columnIndex.clamp(0, maxColumns - 1);
    final sourceRect = Rect.fromLTWH(
      sourceColumn * safeFrameWidth,
      sourceRow * safeFrameHeight,
      safeFrameWidth,
      safeFrameHeight,
    );
    if (destinationRect.width <= 0 || destinationRect.height <= 0) {
      return;
    }
    canvas.drawImageRect(
      image,
      sourceRect,
      destinationRect,
      Paint()
        // Use filtered minification in editor preview so zoomed-out frames keep
        // a stable visual centroid instead of "pixel-drop" apparent drift.
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true,
    );

    if (!showReferencePoints) {
      return;
    }

    final clampedAnchorX = anchorX.clamp(0.0, 1.0);
    final clampedAnchorY = anchorY.clamp(0.0, 1.0);
    final anchorPoint = Offset(
      destinationRect.left + destinationRect.width * clampedAnchorX,
      destinationRect.top + destinationRect.height * clampedAnchorY,
    );
    final frameCenter = destinationRect.center;

    final guidePaint = Paint()
      ..color = const Color(0xCCFFD85A)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(frameCenter, anchorPoint, guidePaint);

    final centerFill = Paint()..color = const Color(0xCC9AD9FF);
    final centerStroke = Paint()
      ..color = const Color(0xFF0B141C)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(frameCenter, 3.8, centerFill);
    canvas.drawCircle(frameCenter, 3.8, centerStroke);

    final anchorStroke = Paint()
      ..color = const Color(0xFFFFE07D)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const arm = 5.0;
    canvas.drawLine(
      Offset(anchorPoint.dx - arm, anchorPoint.dy),
      Offset(anchorPoint.dx + arm, anchorPoint.dy),
      anchorStroke,
    );
    canvas.drawLine(
      Offset(anchorPoint.dx, anchorPoint.dy - arm),
      Offset(anchorPoint.dx, anchorPoint.dy + arm),
      anchorStroke,
    );
    canvas.drawCircle(anchorPoint, 4.8, anchorStroke);
  }

  @override
  bool shouldRepaint(covariant _ReferenceFramePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.row != row ||
        oldDelegate.frame != frame ||
        oldDelegate.destinationRect != destinationRect ||
        oldDelegate.anchorX != anchorX ||
        oldDelegate.anchorY != anchorY ||
        oldDelegate.showReferencePoints != showReferencePoints ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.gridColumns != gridColumns;
  }
}

class _ColliderViewportPainter extends CustomPainter {
  const _ColliderViewportPainter({
    required this.entry,
    required this.scale,
    required this.gridCellSize,
    required this.panPixels,
    required this.activeHandle,
    this.drawGridAndAxes = true,
    this.drawColliderFill = true,
    this.drawColliderOutline = true,
    this.drawHandles = true,
    this.fillColor = const Color(0x5522D3EE),
  });

  final ColliderEntry entry;
  final double scale;
  final double gridCellSize;
  final Offset panPixels;
  final _ViewportDragHandle? activeHandle;
  final bool drawGridAndAxes;
  final bool drawColliderFill;
  final bool drawColliderOutline;
  final bool drawHandles;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final canvasCenter = _ViewportGeometry.canvasCenter(size, panPixels);
    if (drawGridAndAxes) {
      final gridPaint = Paint()
        ..color = const Color(0xFF233444)
        ..strokeWidth = 1;
      final axisPaint = Paint()
        ..color = const Color(0xFF3A566E)
        ..strokeWidth = 1.2;
      _paintWorldGrid(
        canvas,
        size,
        canvasCenter: canvasCenter,
        gridPaint: gridPaint,
      );
      canvas.drawLine(
        Offset(0, canvasCenter.dy),
        Offset(size.width, canvasCenter.dy),
        axisPaint,
      );
      canvas.drawLine(
        Offset(canvasCenter.dx, 0),
        Offset(canvasCenter.dx, size.height),
        axisPaint,
      );
    }

    final colliderCenter = _ViewportGeometry.colliderCenter(
      size,
      entry.offsetX,
      entry.offsetY,
      scale,
      panPixels,
    );
    final colliderRect = _ViewportGeometry.colliderRect(
      center: colliderCenter,
      halfX: entry.halfX,
      halfY: entry.halfY,
      scale: scale,
    );
    if (drawColliderFill) {
      final fillPaint = Paint()..color = fillColor;
      canvas.drawRect(colliderRect, fillPaint);
    }
    if (drawColliderOutline) {
      final strokePaint = Paint()
        ..color = const Color(0xFF7CE5FF)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawRect(colliderRect, strokePaint);
    }

    if (drawHandles) {
      final centerHandle = colliderCenter;
      final rightHandle = _ViewportGeometry.rightHandle(
        colliderCenter,
        entry.halfX,
        scale,
      );
      final topHandle = _ViewportGeometry.topHandle(
        colliderCenter,
        entry.halfY,
        scale,
      );
      _paintHandle(
        canvas,
        centerHandle,
        kind: _ViewportDragHandle.center,
        activeKind: activeHandle,
        color: const Color(0xFFE9B949),
      );
      _paintHandle(
        canvas,
        rightHandle,
        kind: _ViewportDragHandle.rightEdge,
        activeKind: activeHandle,
        color: const Color(0xFF9BDEAC),
      );
      _paintHandle(
        canvas,
        topHandle,
        kind: _ViewportDragHandle.topEdge,
        activeKind: activeHandle,
        color: const Color(0xFFBCA6FF),
      );
    }
  }

  void _paintHandle(
    Canvas canvas,
    Offset center, {
    required _ViewportDragHandle kind,
    required _ViewportDragHandle? activeKind,
    required Color color,
  }) {
    final isActive = kind == activeKind;
    final fill = Paint()
      ..color = isActive ? color : color.withValues(alpha: 0.8);
    final stroke = Paint()
      ..color = const Color(0xFF0B141C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final radius = isActive ? 8.0 : 6.5;
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);
  }

  void _paintWorldGrid(
    Canvas canvas,
    Size size, {
    required Offset canvasCenter,
    required Paint gridPaint,
  }) {
    if (!gridCellSize.isFinite || gridCellSize <= 0 || !scale.isFinite) {
      return;
    }
    final baseSpacingPx = gridCellSize * scale;
    if (!baseSpacingPx.isFinite || baseSpacingPx <= 0) {
      return;
    }

    // Keep line count bounded at low zoom while staying aligned to world cells.
    var cellStride = 1;
    if (baseSpacingPx < 12.0) {
      cellStride = (12.0 / baseSpacingPx).ceil();
    }
    final spacingPx = baseSpacingPx * cellStride;

    final minKX = ((0 - canvasCenter.dx) / spacingPx).floor() - 1;
    final maxKX = ((size.width - canvasCenter.dx) / spacingPx).ceil() + 1;
    for (var k = minKX; k <= maxKX; k += 1) {
      final x = canvasCenter.dx + (k * spacingPx);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final minKY = ((0 - canvasCenter.dy) / spacingPx).floor() - 1;
    final maxKY = ((size.height - canvasCenter.dy) / spacingPx).ceil() + 1;
    for (var k = minKY; k <= maxKY; k += 1) {
      final y = canvasCenter.dy + (k * spacingPx);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ColliderViewportPainter oldDelegate) {
    return oldDelegate.entry.halfX != entry.halfX ||
        oldDelegate.entry.halfY != entry.halfY ||
        oldDelegate.entry.offsetX != entry.offsetX ||
        oldDelegate.entry.offsetY != entry.offsetY ||
        oldDelegate.scale != scale ||
        oldDelegate.gridCellSize != gridCellSize ||
        oldDelegate.panPixels != panPixels ||
        oldDelegate.activeHandle != activeHandle ||
        oldDelegate.drawGridAndAxes != drawGridAndAxes ||
        oldDelegate.drawColliderFill != drawColliderFill ||
        oldDelegate.drawColliderOutline != drawColliderOutline ||
        oldDelegate.drawHandles != drawHandles ||
        oldDelegate.fillColor != fillColor;
  }
}

class _ViewportGeometry {
  static Offset canvasCenter(Size size, Offset panPixels) =>
      Offset(size.width * 0.5, size.height * 0.5) + panPixels;

  static Offset colliderCenter(
    Size size,
    double offsetX,
    double offsetY,
    double scale,
    Offset panPixels,
  ) {
    final canvasMid = canvasCenter(size, panPixels);
    return Offset(
      canvasMid.dx + offsetX * scale,
      // Match runtime convention (Core + Flame): Y increases downward.
      canvasMid.dy + offsetY * scale,
    );
  }

  static Rect colliderRect({
    required Offset center,
    required double halfX,
    required double halfY,
    required double scale,
  }) {
    final halfWidth = halfX * scale;
    final halfHeight = halfY * scale;
    return Rect.fromLTRB(
      center.dx - halfWidth,
      center.dy - halfHeight,
      center.dx + halfWidth,
      center.dy + halfHeight,
    );
  }

  static Offset rightHandle(Offset center, double halfX, double scale) =>
      Offset(center.dx + halfX * scale, center.dy);

  static Offset topHandle(Offset center, double halfY, double scale) =>
      Offset(center.dx, center.dy - halfY * scale);
}
