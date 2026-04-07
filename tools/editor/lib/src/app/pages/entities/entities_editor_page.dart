import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../entities/entity_domain_models.dart';
import '../../../domain/authoring_types.dart';
import '../../../session/editor_session_controller.dart';
import 'inspector/entity_inspector_panel.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_scene_viewport_frame.dart';
import '../shared/editor_scene_view_utils.dart';
import '../shared/editor_viewport_grid_painter.dart';
import '../shared/scene_input_utils.dart';
import '../shared/editor_zoom_controls.dart';

// Entities page library root.
//
// Keep this file as the composition/ownership hub (state fields, lifecycle,
// and cross-part wiring). Behavior-heavy concerns are split into `scene/**`,
// `state/**`, and `panels/**` part files.
part 'entities_page.dart';
part 'scene/entity_scene_zoom.dart';
part 'scene/entity_scene_models.dart';
part 'scene/entity_scene_painters.dart';
part 'scene/entity_scene_reference.dart';
part 'scene/entity_scene_interaction.dart';
part 'scene/widgets/scene_anim_controls.dart';
part 'scene/entity_scene_view.dart';
part 'state/entities_editor_selection.dart';
part 'state/entities_editor_apply.dart';
part 'panels/entities_editor_status_panels.dart';

class EntitiesEditorPage extends StatefulWidget {
  const EntitiesEditorPage({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<EntitiesEditorPage> createState() => _EntitiesEditorPageState();
}

class _EntitiesEditorPageState extends State<EntitiesEditorPage>
    implements EditorPageLocalDraftState {
  // Controllers are page-owned draft state. We only persist through
  // plugin/controller command paths, never directly from widget fields.
  late final TextEditingController _halfXController;
  late final TextEditingController _halfYController;
  late final TextEditingController _offsetXController;
  late final TextEditingController _offsetYController;
  late final TextEditingController _anchorXPxController;
  late final TextEditingController _anchorYPxController;
  late final TextEditingController _frameWidthController;
  late final TextEditingController _frameHeightController;
  late final TextEditingController _renderScaleController;
  late final TextEditingController _castOriginOffsetController;
  late final TextEditingController _searchController;
  late final ScrollController _sceneHorizontalScrollController;
  late final ScrollController _sceneVerticalScrollController;

  String? _selectedEntryId;
  String? _selectedDiffPath;
  String? _selectedArtifactTitle;
  String _searchQuery = '';
  EntityType? _entityTypeFilter;
  bool _showDirtyOnly = false;
  double _sceneZoom = 1.0;
  String? _sceneAnimKey;
  int _sceneAnimFrameIndex = 0;
  bool _sceneCtrlPanActive = false;
  _SceneHandleDrag? _sceneHandleDrag;
  final EditorUiImageCache _referenceImageCache = EditorUiImageCache();

  @override
  // Used by route/session orchestration to guard unsaved draft prompts.
  // This compares local draft text against the currently selected entry model.
  bool get hasLocalDraftChanges {
    final scene = widget.controller.scene;
    if (scene is! EntityScene) {
      return false;
    }
    final selectedEntry = _selectedEntry(scene);
    if (selectedEntry == null) {
      return false;
    }
    final reference = selectedEntry.referenceVisual;
    return _halfXController.text.trim() !=
            selectedEntry.halfX.toStringAsFixed(2) ||
        _halfYController.text.trim() !=
            selectedEntry.halfY.toStringAsFixed(2) ||
        _offsetXController.text.trim() !=
            selectedEntry.offsetX.toStringAsFixed(2) ||
        _offsetYController.text.trim() !=
            selectedEntry.offsetY.toStringAsFixed(2) ||
        _renderScaleController.text.trim() !=
            _formatOptionalDouble(reference?.renderScale) ||
        _anchorXPxController.text.trim() !=
            _formatOptionalDouble(reference?.anchorXPx) ||
        _anchorYPxController.text.trim() !=
            _formatOptionalDouble(reference?.anchorYPx) ||
        _frameWidthController.text.trim() !=
            _formatOptionalDouble(reference?.frameWidth) ||
        _frameHeightController.text.trim() !=
            _formatOptionalDouble(reference?.frameHeight) ||
        _castOriginOffsetController.text.trim() !=
            _formatOptionalDouble(selectedEntry.castOriginOffset);
  }

  @override
  void initState() {
    super.initState();
    _halfXController = TextEditingController();
    _halfYController = TextEditingController();
    _offsetXController = TextEditingController();
    _offsetYController = TextEditingController();
    _anchorXPxController = TextEditingController();
    _anchorYPxController = TextEditingController();
    _frameWidthController = TextEditingController();
    _frameHeightController = TextEditingController();
    _renderScaleController = TextEditingController();
    _castOriginOffsetController = TextEditingController();
    _searchController = TextEditingController();
    _sceneHorizontalScrollController = ScrollController();
    _sceneVerticalScrollController = ScrollController();
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadWorkspace();
    });
  }

  @override
  void didUpdateWidget(covariant EntitiesEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _reconcileSelectionsFromCurrentState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _halfXController.dispose();
    _halfYController.dispose();
    _offsetXController.dispose();
    _offsetYController.dispose();
    _anchorXPxController.dispose();
    _anchorYPxController.dispose();
    _frameWidthController.dispose();
    _frameHeightController.dispose();
    _renderScaleController.dispose();
    _castOriginOffsetController.dispose();
    _searchController.dispose();
    _sceneHorizontalScrollController.dispose();
    _sceneVerticalScrollController.dispose();
    _referenceImageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final scene = widget.controller.scene;
        final entityScene = scene is EntityScene ? scene : null;
        final visibleEntries = entityScene == null
            ? const <EntityEntry>[]
            : _filteredEntries(entityScene.entries);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildControls(),
            const SizedBox(height: 16),
            Expanded(child: _buildEntitiesPage(entityScene, visibleEntries)),
          ],
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
        FilledButton.icon(
          onPressed:
              widget.controller.scene == null ||
                  widget.controller.isLoading ||
                  widget.controller.isExporting ||
                  widget.controller.errorCount > 0
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
    // Export remains plugin/controller-authoritative. The page only confirms
    // intent, blocks obvious invalid states, and reports user-facing outcome.
    if (widget.controller.errorCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resolve validation errors before applying changes.'),
        ),
      );
      return;
    }

    final pendingChanges = widget.controller.pendingChanges;
    if (!pendingChanges.hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending changes to apply.')),
      );
      return;
    }

    final changedEntries = pendingChanges.changedItemIds.length;
    final changedFiles = pendingChanges.fileDiffs.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Apply Changes To Files'),
          content: Text(
            'This will write $changedEntries edited entity entries across '
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
      if (artifact.title != 'entity_backups.md') {
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

  Widget _buildEntryListPanel({
    required EntityScene scene,
    required List<EntityEntry> visibleEntries,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
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
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.trim().toLowerCase();
                            _reconcileSelectionsFromCurrentState();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _typeFilterChip(label: 'All', type: null),
                    _typeFilterChip(label: 'Players', type: EntityType.player),
                    _typeFilterChip(label: 'Enemies', type: EntityType.enemy),
                    _typeFilterChip(
                      label: 'Projectiles',
                      type: EntityType.projectile,
                    ),
                    FilterChip(
                      selected: _showDirtyOnly,
                      label: const Text('Dirty only'),
                      onSelected: (selected) {
                        setState(() {
                          _showDirtyOnly = selected;
                          _reconcileSelectionsFromCurrentState();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _EntityTable(
            entries: visibleEntries,
            selectedId: _selectedEntryId,
            dirtyItemIds: widget.controller.dirtyItemIds,
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
    required EntityType? type,
  }) {
    return ChoiceChip(
      selected: _entityTypeFilter == type,
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _entityTypeFilter = type;
          _reconcileSelectionsFromCurrentState();
        });
      },
    );
  }

  Widget _buildInspector(EntityEntry? selectedEntry) {
    return EntityInspectorPanel(
      selectedEntry: selectedEntry,
      isDirty:
          selectedEntry != null &&
          widget.controller.dirtyItemIds.contains(selectedEntry.id),
      halfXController: _halfXController,
      halfYController: _halfYController,
      offsetXController: _offsetXController,
      offsetYController: _offsetYController,
      anchorXPxController: _anchorXPxController,
      anchorYPxController: _anchorYPxController,
      frameWidthController: _frameWidthController,
      frameHeightController: _frameHeightController,
      renderScaleController: _renderScaleController,
      castOriginOffsetController: _castOriginOffsetController,
      onApply: selectedEntry == null
          ? null
          : () => _applyInspectorEdits(selectedEntry),
    );
  }

  void _updateState(VoidCallback callback) {
    // Extension part files call this helper so state mutation stays scoped to
    // this owning `State` class instead of calling `setState` directly.
    setState(callback);
  }
}

class _EntityTable extends StatelessWidget {
  const _EntityTable({
    required this.entries,
    required this.selectedId,
    required this.dirtyItemIds,
    required this.onSelect,
  });

  final List<EntityEntry> entries;
  final String? selectedId;
  final Set<String> dirtyItemIds;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 0,
          columns: const [DataColumn(label: SizedBox.shrink())],
          rows: entries
              .map((entry) {
                final isDirty = dirtyItemIds.contains(entry.id);
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
