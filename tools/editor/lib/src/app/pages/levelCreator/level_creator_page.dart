import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/authoring_identifiers.dart';
import '../../../domain/authoring_types.dart';
import '../../../levels/level_domain_models.dart';
import '../../../levels/level_domain_plugin.dart';
import '../../../parallax/parallax_domain_models.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_workspace_card.dart';

class LevelCreatorPage extends StatefulWidget {
  const LevelCreatorPage({
    super.key,
    required this.controller,
    this.onOpenInParallax,
  });

  final EditorSessionController controller;
  final ValueChanged<ParallaxLevelTarget>? onOpenInParallax;

  @override
  State<LevelCreatorPage> createState() => _LevelCreatorPageState();
}

class _LevelCreatorPageState extends State<LevelCreatorPage>
    implements
        EditorPageLocalDraftState,
        EditorPageSessionShortcutHandler,
        EditorPageApplyHandler {
  static const String _defaultNewLevelId = 'new_level';

  final TextEditingController _newLevelIdController = TextEditingController(
    text: _defaultNewLevelId,
  );
  final TextEditingController _newVisualThemeIdController =
      TextEditingController(text: _defaultNewLevelId);
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _visualThemeIdController =
      TextEditingController();
  final TextEditingController _cameraCenterYController =
      TextEditingController();
  final TextEditingController _groundTopYController = TextEditingController();
  final TextEditingController _earlyPatternChunksController =
      TextEditingController();
  final TextEditingController _easyPatternChunksController =
      TextEditingController();
  final TextEditingController _normalPatternChunksController =
      TextEditingController();
  final TextEditingController _noEnemyChunksController =
      TextEditingController();
  final TextEditingController _enumOrdinalController = TextEditingController();
  final TextEditingController _newChunkThemeGroupIdController =
      TextEditingController();
  final TextEditingController _segmentIdController = TextEditingController();
  final TextEditingController _segmentGroupIdController =
      TextEditingController();
  final TextEditingController _segmentMinChunkCountController =
      TextEditingController();
  final TextEditingController _segmentMaxChunkCountController =
      TextEditingController();

  String? _selectedLevelId;
  bool _assemblyLoopSegments = true;
  List<String> _chunkThemeGroupsDraft = const <String>[
    defaultLevelChunkThemeGroupId,
  ];
  List<LevelAssemblySegmentDef> _assemblySegmentsDraft =
      const <LevelAssemblySegmentDef>[];
  int? _selectedAssemblySegmentIndex;
  bool _selectedSegmentRequireDistinct = true;
  _NewLevelThemeMode _newLevelThemeMode = _NewLevelThemeMode.create;
  String _newLevelFormBaselineId = _defaultNewLevelId;
  String? _selectedExistingThemeId;
  bool _newThemeIdWasManuallyEdited = false;
  String? _createThemeDialogDraftId;
  bool _createThemeDialogOpen = false;
  ParallaxLevelTarget? _parallaxHandoffTarget;
  List<String> _cleanupRequiredPaths = const <String>[];

  @override
  bool get hasLocalDraftChanges {
    final scene = widget.controller.scene;
    final levelScene = scene is LevelScene ? scene : null;
    final activeLevel = levelScene?.activeLevel;
    if (_newLevelIdController.text.trim() != _newLevelFormBaselineId ||
        _newLevelThemeMode != _NewLevelThemeMode.create ||
        _newVisualThemeIdController.text.trim() != _newLevelFormBaselineId ||
        _createThemeDialogOpen ||
        _createThemeDialogDraftId != null) {
      return true;
    }
    if (activeLevel == null) {
      return _displayNameController.text.trim().isNotEmpty ||
          _visualThemeIdController.text.trim().isNotEmpty ||
          _cameraCenterYController.text.trim().isNotEmpty ||
          _groundTopYController.text.trim().isNotEmpty ||
          _earlyPatternChunksController.text.trim().isNotEmpty ||
          _easyPatternChunksController.text.trim().isNotEmpty ||
          _normalPatternChunksController.text.trim().isNotEmpty ||
          _noEnemyChunksController.text.trim().isNotEmpty ||
          _enumOrdinalController.text.trim().isNotEmpty ||
          _newChunkThemeGroupIdController.text.trim().isNotEmpty ||
          !_stringListEquals(_chunkThemeGroupsDraft, const <String>[
            defaultLevelChunkThemeGroupId,
          ]) ||
          _assemblySegmentsDraft.isNotEmpty;
    }
    return _displayNameController.text.trim() != activeLevel.displayName ||
        _visualThemeIdController.text.trim() != activeLevel.visualThemeId ||
        _cameraCenterYController.text.trim() !=
            formatCanonicalLevelNumber(activeLevel.cameraCenterY) ||
        _groundTopYController.text.trim() !=
            formatCanonicalLevelNumber(activeLevel.groundTopY) ||
        _earlyPatternChunksController.text.trim() !=
            activeLevel.earlyPatternChunks.toString() ||
        _easyPatternChunksController.text.trim() !=
            activeLevel.easyPatternChunks.toString() ||
        _normalPatternChunksController.text.trim() !=
            activeLevel.normalPatternChunks.toString() ||
        _noEnemyChunksController.text.trim() !=
            activeLevel.noEnemyChunks.toString() ||
        _enumOrdinalController.text.trim() !=
            activeLevel.enumOrdinal.toString() ||
        !_stringListEquals(
          _chunkThemeGroupsDraft,
          activeLevel.chunkThemeGroups,
        ) ||
        _assemblyDraftDiffersFromLevel(activeLevel);
  }

  @override
  bool get canHandleUndoSessionShortcut => widget.controller.canUndo;

  @override
  bool get canHandleRedoSessionShortcut => widget.controller.canRedo;

  @override
  bool handleUndoSessionShortcut() {
    if (!widget.controller.canUndo) return false;
    _invalidateHandoff();
    widget.controller.undo();
    return true;
  }

  @override
  bool handleRedoSessionShortcut() {
    if (!widget.controller.canRedo) return false;
    _invalidateHandoff();
    widget.controller.redo();
    return true;
  }

  @override
  bool get canApplyEditorPage => _canApplyToFiles;

  @override
  Future<void> applyEditorPage() async {
    if (!canApplyEditorPage) return;
    await _confirmAndApplyToFiles();
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
    _newLevelIdController.dispose();
    _newVisualThemeIdController.dispose();
    _displayNameController.dispose();
    _visualThemeIdController.dispose();
    _cameraCenterYController.dispose();
    _groundTopYController.dispose();
    _earlyPatternChunksController.dispose();
    _easyPatternChunksController.dispose();
    _normalPatternChunksController.dispose();
    _noEnemyChunksController.dispose();
    _enumOrdinalController.dispose();
    _newChunkThemeGroupIdController.dispose();
    _segmentIdController.dispose();
    _segmentGroupIdController.dispose();
    _segmentMinChunkCountController.dispose();
    _segmentMaxChunkCountController.dispose();
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
        final levelScene = scene is LevelScene ? scene : null;
        _syncSelection(levelScene);

        return EditorWorkspaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRouteControls(levelScene),
              const SizedBox(height: 12),
              if (widget.controller.loadError != null)
                _buildErrorBanner(widget.controller.loadError!),
              if (widget.controller.exportError != null)
                _buildErrorBanner(widget.controller.exportError!),
              if (levelScene == null)
                const Expanded(
                  child: Center(
                    child: Text('Level scene is not loaded for this route.'),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 980) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildLevelListPane(levelScene),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildInspectorPane(levelScene),
                            ),
                          ],
                        );
                      }
                      return ListView(
                        key: const ValueKey<String>(
                          'level_creator_narrow_layout',
                        ),
                        children: [
                          SizedBox(
                            height: 560,
                            child: _buildLevelListPane(levelScene),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 1200,
                            child: _buildInspectorPane(levelScene),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteControls(LevelScene? scene) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (scene != null)
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey<String?>('level-active-${scene.activeLevelId}'),
              initialValue: scene.activeLevelId,
              decoration: const InputDecoration(
                labelText: 'Active Level',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final level in scene.levels)
                  DropdownMenuItem<String>(
                    value: level.levelId,
                    child: Text(level.levelId),
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
        if (scene != null && scene.activeLevel != null)
          Chip(
            avatar: const Icon(Icons.numbers, size: 16),
            label: Text('enumOrdinal: ${scene.activeLevel!.enumOrdinal}'),
          ),
        if (scene != null && scene.activeLevel != null)
          Chip(
            avatar: const Icon(Icons.extension, size: 16),
            label: Text(
              'chunks: ${scene.authoredChunkCountsByLevelId[scene.activeLevel!.levelId] ?? 0}',
            ),
          ),
      ],
    );
  }

  Widget _buildLevelListPane(LevelScene scene) {
    return _buildPane(
      title: 'Levels',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNewLevelForm(scene),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: scene.activeLevel == null
                    ? null
                    : _duplicateActiveLevel,
                child: const Text('Duplicate'),
              ),
              OutlinedButton(
                onPressed:
                    scene.activeLevel == null ||
                        scene.activeLevel!.status == levelStatusDeprecated
                    ? null
                    : _deprecateActiveLevel,
                child: const Text('Deprecate'),
              ),
              OutlinedButton(
                onPressed:
                    scene.activeLevel == null ||
                        scene.activeLevel!.status == levelStatusActive
                    ? null
                    : _reactivateActiveLevel,
                child: const Text('Reactivate'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: scene.levels.isEmpty
                ? const Center(child: Text('No authored levels.'))
                : ListView.builder(
                    itemCount: scene.levels.length,
                    itemBuilder: (context, index) {
                      final level = scene.levels[index];
                      final isSelected = level.levelId == scene.activeLevelId;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == scene.levels.length - 1 ? 0 : 8,
                        ),
                        child: _buildLevelEntry(
                          level,
                          isSelected: isSelected,
                          chunkCount:
                              scene.authoredChunkCountsByLevelId[level
                                  .levelId] ??
                              0,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewLevelForm(LevelScene scene) {
    final formError = _newLevelFormError(scene);
    final themeIds = scene.availableParallaxVisualThemeIds;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x334A6074)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Level', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('new_level_id_field'),
              controller: _newLevelIdController,
              decoration: const InputDecoration(
                labelText: 'New levelId',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                if (!_newThemeIdWasManuallyEdited) {
                  _newVisualThemeIdController
                      .value = _newVisualThemeIdController.value.copyWith(
                    text: value,
                    selection: TextSelection.collapsed(offset: value.length),
                    composing: TextRange.empty,
                  );
                }
                setState(_invalidateHandoff);
              },
            ),
            const SizedBox(height: 8),
            SegmentedButton<_NewLevelThemeMode>(
              key: const ValueKey<String>('new_level_theme_mode'),
              segments: const <ButtonSegment<_NewLevelThemeMode>>[
                ButtonSegment<_NewLevelThemeMode>(
                  value: _NewLevelThemeMode.create,
                  icon: Icon(Icons.add_photo_alternate_outlined),
                  label: Text('Create new theme'),
                ),
                ButtonSegment<_NewLevelThemeMode>(
                  value: _NewLevelThemeMode.existing,
                  icon: Icon(Icons.collections_outlined),
                  label: Text('Use existing theme'),
                ),
              ],
              selected: <_NewLevelThemeMode>{_newLevelThemeMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() {
                  _newLevelThemeMode = selection.single;
                  _invalidateHandoff();
                });
              },
            ),
            const SizedBox(height: 8),
            if (_newLevelThemeMode == _NewLevelThemeMode.create)
              TextField(
                key: const ValueKey<String>('new_visual_theme_id_field'),
                controller: _newVisualThemeIdController,
                decoration: const InputDecoration(
                  labelText: 'New visual theme ID',
                  helperText: 'Creates an empty theme. Add its layers in Parallax after apply.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) {
                  setState(() {
                    _newThemeIdWasManuallyEdited = true;
                    _invalidateHandoff();
                  });
                },
              )
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: const ValueKey<String>('new_level_existing_theme'),
                initialValue: themeIds.contains(_selectedExistingThemeId)
                    ? _selectedExistingThemeId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Existing visual theme',
                  hintText: 'Choose an authored theme',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final themeId in themeIds)
                    DropdownMenuItem<String>(
                      value: themeId,
                      child: Text(themeId),
                    ),
                ],
                onChanged: themeIds.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _selectedExistingThemeId = value;
                          _invalidateHandoff();
                        });
                      },
              ),
            if (formError != null) ...[
              const SizedBox(height: 6),
              Text(
                formError,
                key: const ValueKey<String>('new_level_form_error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey<String>('create_level_button'),
              onPressed: formError == null && !widget.controller.isExporting
                  ? _createLevel
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Create Level'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelEntry(
    LevelDef level, {
    required bool isSelected,
    required int chunkCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDirty = widget.controller.dirtyItemIds.contains(
      'level:${level.levelId}',
    );
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
          key: ValueKey<String>('level_entry_${level.levelId}'),
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            widget.controller.applyCommand(
              AuthoringCommand(
                kind: 'set_active_level',
                payload: <String, Object?>{'levelId': level.levelId},
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        level.levelId,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isDirty)
                      const Icon(Icons.circle, size: 10, color: Colors.orange),
                  ],
                ),
                const SizedBox(height: 4),
                Text(level.displayName),
                const SizedBox(height: 4),
                Text(
                  'visualTheme=${level.visualThemeId}  status=${level.status}  chunks=$chunkCount',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'ordinal=${level.enumOrdinal}  ground=${formatCanonicalLevelNumber(level.groundTopY)}  camera=${formatCanonicalLevelNumber(level.cameraCenterY)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'assembly=${level.assembly?.segments.length ?? 0} segment(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInspectorPane(LevelScene scene) {
    final activeLevel = scene.activeLevel;
    final pendingChanges = widget.controller.pendingChanges;
    final issues = widget.controller.issues;
    final selectedVisualThemeId = _visualThemeIdController.text.trim();
    final availableVisualThemeIds = scene.availableParallaxVisualThemeIds;
    final hasSelectedVisualThemeId = selectedVisualThemeId.isNotEmpty;
    final selectedThemeIsAuthored = availableVisualThemeIds.contains(
      selectedVisualThemeId,
    );
    final showMissingSelectedTheme =
        hasSelectedVisualThemeId && !selectedThemeIsAuthored;
    final visualThemeDropdownValue = selectedThemeIsAuthored
        ? selectedVisualThemeId
        : null;
    final visualThemeItems = <DropdownMenuItem<String>>[
      for (final visualThemeId in availableVisualThemeIds)
        DropdownMenuItem<String>(
          value: visualThemeId,
          child: Text(visualThemeId),
        ),
    ];
    final canSelectVisualTheme =
        activeLevel != null && availableVisualThemeIds.isNotEmpty;
    final postApplyPanel = _buildPostApplyPanel(scene);

    return _buildPane(
      title: 'Inspector',
      child: ListView(
        key: const ValueKey<String>('level_inspector_scroll'),
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'levelId',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: SelectableText(activeLevel?.levelId ?? ''),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'displayName',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey<String>(
              'level-visual-theme-${scene.activeLevelId ?? 'none'}-$selectedVisualThemeId',
            ),
            initialValue: visualThemeDropdownValue,
            decoration: const InputDecoration(
              labelText: 'Visual theme (Parallax)',
              hintText: 'Select an authored visual theme',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: visualThemeItems,
            onChanged: !canSelectVisualTheme
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _visualThemeIdController.text = value;
                      _invalidateHandoff();
                    });
                  },
          ),
          if (showMissingSelectedTheme) ...[
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Theme.of(context).colorScheme.error),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Missing visual theme "$selectedVisualThemeId".',
                      key: const ValueKey<String>(
                        'missing_visual_theme_repair',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create the missing empty theme, or select an authored theme above.',
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      key: const ValueKey<String>(
                        'create_missing_visual_theme_button',
                      ),
                      onPressed: activeLevel == null
                          ? null
                          : () => unawaited(
                              _showCreateAndAssignThemeDialog(
                                scene,
                                initialThemeId: selectedVisualThemeId,
                              ),
                            ),
                      child: const Text('Create missing theme'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey<String>('create_assign_visual_theme_button'),
            onPressed: activeLevel == null
                ? null
                : () => unawaited(_showCreateAndAssignThemeDialog(scene)),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Create and assign new theme'),
          ),
          const SizedBox(height: 4),
          const Text(
            'Parallax owns theme layers. Terrain materials remain authored separately.',
          ),
          const SizedBox(height: 8),
          _buildRuntimeMetricsRow(),
          const SizedBox(height: 8),
          TextField(
            controller: _enumOrdinalController,
            decoration: const InputDecoration(
              labelText: 'enumOrdinal',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildChunkThemeGroupsSection(scene),
          const SizedBox(height: 16),
          _buildAssemblySection(scene),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey<String>('apply_level_button'),
            onPressed: activeLevel == null ? null : _applySelectedLevelChanges,
            child: const Text('Apply Level'),
          ),
          if (postApplyPanel != null) ...[
            const SizedBox(height: 12),
            postApplyPanel,
          ],
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
            for (final diff in pendingChanges.fileDiffs) ...[
              SelectableText(
                diff.unifiedDiff,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRuntimeMetricsRow() {
    final lockedFillColor = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.32);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildRuntimeMetricField(
            controller: _cameraCenterYController,
            label: 'cameraCenterY',
            fillColor: lockedFillColor,
            readOnly: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(width: 8),
          _buildRuntimeMetricField(
            controller: _groundTopYController,
            label: 'groundTopY',
            fillColor: lockedFillColor,
            readOnly: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(width: 8),
          _buildRuntimeMetricField(
            controller: _earlyPatternChunksController,
            label: 'earlyPatternChunks',
            fillColor: lockedFillColor,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(width: 8),
          _buildRuntimeMetricField(
            controller: _easyPatternChunksController,
            label: 'easyPatternChunks',
            fillColor: lockedFillColor,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(width: 8),
          _buildRuntimeMetricField(
            controller: _normalPatternChunksController,
            label: 'normalPatternChunks',
            fillColor: lockedFillColor,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(width: 8),
          _buildRuntimeMetricField(
            controller: _noEnemyChunksController,
            label: 'noEnemyChunks',
            fillColor: lockedFillColor,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeMetricField({
    required TextEditingController controller,
    required String label,
    required Color fillColor,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      width: 190,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        style: readOnly
            ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          filled: readOnly,
          fillColor: readOnly ? fillColor : null,
          suffixIcon: readOnly ? const Icon(Icons.lock_outline) : null,
        ),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget? _buildPostApplyPanel(LevelScene scene) {
    final target = _parallaxHandoffTarget;
    if (target == null && _cleanupRequiredPaths.isEmpty) return null;
    final targetStillResolves =
        target != null &&
        scene.levels.any(
          (level) =>
              level.levelId == target.levelId &&
              level.visualThemeId == target.parallaxThemeId,
        );
    final canOpen =
        targetStillResolves &&
        widget.onOpenInParallax != null &&
        !widget.controller.pendingChanges.hasChanges &&
        !hasLocalDraftChanges &&
        !widget.controller.isLoading &&
        !widget.controller.isExporting &&
        _cleanupRequiredPaths.isEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer
            .withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _cleanupRequiredPaths.isEmpty
                  ? 'Authoring sources saved'
                  : 'Sources committed; cleanup required',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Runtime Dart is not generated yet. After finishing Level and Parallax authoring, run:',
            ),
            const SizedBox(height: 6),
            const SelectableText(
              'dart run tool/generate_chunk_runtime_data.dart\n'
              'dart run tool/generate_chunk_runtime_data.dart --dry-run',
              style: TextStyle(fontFamily: 'monospace'),
            ),
            if (_cleanupRequiredPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Do not apply again until these transaction files are inspected and removed:',
              ),
              for (final path in _cleanupRequiredPaths)
                SelectableText(
                  path,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
            ],
            if (target != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey<String>('open_level_in_parallax_button'),
                onPressed: canOpen
                    ? () => widget.onOpenInParallax!(target)
                    : null,
                icon: const Icon(Icons.layers_outlined),
                label: Text('Open ${target.parallaxThemeId} in Parallax'),
              ),
            ],
          ],
        ),
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

  void _syncSelection(LevelScene? scene) {
    final activeLevel = scene?.activeLevel;
    final nextLevelId = activeLevel?.levelId;
    if (_selectedLevelId != nextLevelId) {
      _selectedLevelId = nextLevelId;
      if (activeLevel == null) {
        _clearInspector();
      } else {
        _syncInspector(activeLevel);
      }
      return;
    }

    if (activeLevel == null) {
      _clearInspector();
      return;
    }

    if (!hasLocalDraftChanges) {
      _syncInspector(activeLevel);
    }
  }

  Widget _buildChunkThemeGroupsSection(LevelScene scene) {
    final activeLevel = scene.activeLevel;
    final authoredCounts = activeLevel == null
        ? const <String, int>{}
        : scene.authoredChunkAssemblyGroupCountsByLevelId[activeLevel
                  .levelId] ??
              const <String, int>{};
    final canEdit = activeLevel != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x22101820),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x334A6074)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chunk Theme Groups',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'Define allowed chunk groups for this level. "default" is always required.',
            ),
            const SizedBox(height: 8),
            if (!canEdit)
              const Text('Select a level to edit chunk theme groups.')
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final groupId in _chunkThemeGroupsDraft)
                    InputChip(
                      key: ValueKey<String>('chunk_theme_group_$groupId'),
                      label: Text(
                        authoredCounts.containsKey(groupId)
                            ? '$groupId (${authoredCounts[groupId]})'
                            : groupId,
                      ),
                      onDeleted: groupId == defaultLevelChunkThemeGroupId
                          ? null
                          : () => _removeChunkThemeGroup(scene, groupId),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey<String>('new_chunk_theme_group_id'),
                      controller: _newChunkThemeGroupIdController,
                      decoration: const InputDecoration(
                        labelText: 'new groupId',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addChunkThemeGroup(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    key: const ValueKey<String>('add_chunk_theme_group_button'),
                    onPressed: _addChunkThemeGroup,
                    child: const Text('Add Group'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssemblySection(LevelScene scene) {
    final activeLevel = scene.activeLevel;
    final authoredGroupCounts = activeLevel == null
        ? const <String, int>{}
        : scene.authoredChunkAssemblyGroupCountsByLevelId[activeLevel
                  .levelId] ??
              const <String, int>{};
    final availableGroupIds = _chunkThemeGroupsDraft.isEmpty
        ? const <String>[defaultLevelChunkThemeGroupId]
        : _chunkThemeGroupsDraft;
    final selectedSegment = _selectedAssemblySegment;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x22101820),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x334A6074)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assembly Segments',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _assemblyLoopSegments,
                title: const Text('Loop Segments'),
                subtitle: const Text(
                  'When disabled, runtime holds on the final authored segment after the ordered run list completes.',
                ),
                onChanged: activeLevel == null
                    ? null
                    : (value) {
                        setState(() {
                          _assemblyLoopSegments = value;
                        });
                      },
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: activeLevel == null
                      ? null
                      : () => _addAssemblySegment(scene),
                  child: const Text('Add Segment'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_assemblySegmentsDraft.isEmpty)
              const Text(
                'No assembly segments. Runtime falls back to the current level-based chunk selection path.',
              )
            else
              Column(
                children: [
                  for (var i = 0; i < _assemblySegmentsDraft.length; i += 1)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == _assemblySegmentsDraft.length - 1 ? 0 : 8,
                      ),
                      child: _buildAssemblySegmentTile(
                        _assemblySegmentsDraft[i],
                        index: i,
                        isSelected: i == _selectedAssemblySegmentIndex,
                      ),
                    ),
                ],
              ),
            if (activeLevel != null) ...[
              const SizedBox(height: 12),
              Text(
                'Allowed Chunk Groups',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final groupId in availableGroupIds)
                    ActionChip(
                      label: Text(
                        authoredGroupCounts.containsKey(groupId)
                            ? '$groupId (${authoredGroupCounts[groupId]})'
                            : groupId,
                      ),
                      onPressed: selectedSegment == null
                          ? null
                          : () {
                              setState(() {
                                _segmentGroupIdController.text = groupId;
                                _updateSelectedAssemblySegment(
                                  selectedSegment.copyWith(groupId: groupId),
                                );
                              });
                            },
                    ),
                ],
              ),
            ],
            if (selectedSegment != null) ...[
              const SizedBox(height: 12),
              Text(
                'Selected Segment',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _segmentIdController,
                decoration: const InputDecoration(
                  labelText: 'segmentId',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _updateSelectedAssemblySegment(
                      selectedSegment.copyWith(segmentId: value.trim()),
                    );
                  });
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'assembly-segment-group-${_selectedAssemblySegmentIndex ?? 'none'}',
                ),
                initialValue: selectedSegment.groupId,
                decoration: const InputDecoration(
                  labelText: 'groupId',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  if (!availableGroupIds.contains(selectedSegment.groupId))
                    DropdownMenuItem<String>(
                      value: selectedSegment.groupId,
                      child: Text('${selectedSegment.groupId} (missing)'),
                    ),
                  for (final groupId in availableGroupIds)
                    DropdownMenuItem<String>(
                      value: groupId,
                      child: Text(groupId),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _segmentGroupIdController.text = value;
                    _updateSelectedAssemblySegment(
                      selectedSegment.copyWith(groupId: value),
                    );
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _segmentMinChunkCountController,
                      decoration: const InputDecoration(
                        labelText: 'minChunkCount',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim());
                        if (parsed == null) {
                          return;
                        }
                        setState(() {
                          _updateSelectedAssemblySegment(
                            selectedSegment.copyWith(minChunkCount: parsed),
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _segmentMaxChunkCountController,
                      decoration: const InputDecoration(
                        labelText: 'maxChunkCount',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim());
                        if (parsed == null) {
                          return;
                        }
                        setState(() {
                          _updateSelectedAssemblySegment(
                            selectedSegment.copyWith(maxChunkCount: parsed),
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selectedSegmentRequireDistinct,
                  title: const Text('Require Distinct Chunks'),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedSegmentRequireDistinct = value;
                      _updateSelectedAssemblySegment(
                        selectedSegment.copyWith(requireDistinctChunks: value),
                      );
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed:
                        _selectedAssemblySegmentIndex == null ||
                            _selectedAssemblySegmentIndex == 0
                        ? null
                        : _moveSelectedAssemblySegmentUp,
                    child: const Text('Move Up'),
                  ),
                  OutlinedButton(
                    onPressed:
                        _selectedAssemblySegmentIndex == null ||
                            _selectedAssemblySegmentIndex ==
                                _assemblySegmentsDraft.length - 1
                        ? null
                        : _moveSelectedAssemblySegmentDown,
                    child: const Text('Move Down'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedAssemblySegmentIndex == null
                        ? null
                        : _removeSelectedAssemblySegment,
                    child: const Text('Remove Segment'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssemblySegmentTile(
    LevelAssemblySegmentDef segment, {
    required int index,
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
          onTap: () {
            setState(() {
              _selectedAssemblySegmentIndex = index;
              _syncSelectedAssemblySegmentControllers();
            });
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.segmentId,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'group=${segment.groupId}  range=${segment.minChunkCount}..${segment.maxChunkCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'distinct=${segment.requireDistinctChunks}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncInspector(LevelDef level) {
    _displayNameController.text = level.displayName;
    _visualThemeIdController.text = level.visualThemeId;
    _cameraCenterYController.text = formatCanonicalLevelNumber(
      level.cameraCenterY,
    );
    _groundTopYController.text = formatCanonicalLevelNumber(level.groundTopY);
    _earlyPatternChunksController.text = level.earlyPatternChunks.toString();
    _easyPatternChunksController.text = level.easyPatternChunks.toString();
    _normalPatternChunksController.text = level.normalPatternChunks.toString();
    _noEnemyChunksController.text = level.noEnemyChunks.toString();
    _enumOrdinalController.text = level.enumOrdinal.toString();
    _newChunkThemeGroupIdController.text = '';
    _chunkThemeGroupsDraft = List<String>.unmodifiable(level.chunkThemeGroups);
    _assemblyLoopSegments = level.assembly?.loopSegments ?? true;
    _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
      level.assembly?.segments ?? const <LevelAssemblySegmentDef>[],
    );
    _selectedAssemblySegmentIndex = _assemblySegmentsDraft.isEmpty ? null : 0;
    _syncSelectedAssemblySegmentControllers();
  }

  void _clearInspector() {
    _displayNameController.text = '';
    _visualThemeIdController.text = '';
    _cameraCenterYController.text = '';
    _groundTopYController.text = '';
    _earlyPatternChunksController.text = '';
    _easyPatternChunksController.text = '';
    _normalPatternChunksController.text = '';
    _noEnemyChunksController.text = '';
    _enumOrdinalController.text = '';
    _newChunkThemeGroupIdController.text = '';
    _chunkThemeGroupsDraft = const <String>[defaultLevelChunkThemeGroupId];
    _assemblyLoopSegments = true;
    _assemblySegmentsDraft = const <LevelAssemblySegmentDef>[];
    _selectedAssemblySegmentIndex = null;
    _syncSelectedAssemblySegmentControllers();
  }

  void _createLevel() {
    final requestedLevelId = _newLevelIdController.text.trim();
    final requestedThemeId = _newLevelThemeMode == _NewLevelThemeMode.create
        ? _newVisualThemeIdController.text.trim()
        : (_selectedExistingThemeId ?? '');
    _invalidateHandoff();
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'create_level',
        payload: <String, Object?>{
          'levelId': requestedLevelId,
          'themeMode': _newLevelThemeMode == _NewLevelThemeMode.create
              ? levelThemeModeCreate
              : levelThemeModeExisting,
          'visualThemeId': requestedThemeId,
        },
      ),
    );
    final updatedScene = widget.controller.scene;
    if (updatedScene is! LevelScene ||
        updatedScene.activeLevelId != requestedLevelId) {
      return;
    }
    setState(() {
      _resetNewLevelForm(updatedScene);
    });
  }

  void _duplicateActiveLevel() {
    final scene = widget.controller.scene;
    if (scene is! LevelScene || scene.activeLevel == null) {
      return;
    }
    _invalidateHandoff();
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'duplicate_level',
        payload: <String, Object?>{'levelId': scene.activeLevel!.levelId},
      ),
    );
  }

  void _deprecateActiveLevel() {
    final scene = widget.controller.scene;
    if (scene is! LevelScene || scene.activeLevel == null) {
      return;
    }
    _invalidateHandoff();
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'deprecate_level',
        payload: <String, Object?>{'levelId': scene.activeLevel!.levelId},
      ),
    );
  }

  void _reactivateActiveLevel() {
    final scene = widget.controller.scene;
    if (scene is! LevelScene || scene.activeLevel == null) {
      return;
    }
    _invalidateHandoff();
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'reactivate_level',
        payload: <String, Object?>{'levelId': scene.activeLevel!.levelId},
      ),
    );
  }

  void _applySelectedLevelChanges() {
    final scene = widget.controller.scene;
    if (scene is! LevelScene || scene.activeLevel == null) {
      return;
    }
    final assemblyPayload = _assemblySegmentsDraft.isEmpty
        ? null
        : LevelAssemblyDef(
            loopSegments: _assemblyLoopSegments,
            segments: _assemblySegmentsDraft,
          ).toJson();
    _invalidateHandoff();
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'update_level',
        payload: <String, Object?>{
          'levelId': scene.activeLevel!.levelId,
          'displayName': _displayNameController.text.trim(),
          'visualThemeId': _visualThemeIdController.text.trim(),
          'chunkThemeGroups': _chunkThemeGroupsDraft,
          'cameraCenterY': _cameraCenterYController.text.trim(),
          'groundTopY': _groundTopYController.text.trim(),
          'earlyPatternChunks': _earlyPatternChunksController.text.trim(),
          'easyPatternChunks': _easyPatternChunksController.text.trim(),
          'normalPatternChunks': _normalPatternChunksController.text.trim(),
          'noEnemyChunks': _noEnemyChunksController.text.trim(),
          'enumOrdinal': _enumOrdinalController.text.trim(),
          'assembly': assemblyPayload,
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
    if (widget.controller.errorCount > 0 ||
        widget.controller.pendingChangesError != null ||
        _cleanupRequiredPaths.isNotEmpty) {
      _showSnackBar('Resolve blocking validation or recovery issues first.');
      return;
    }
    final sceneBeforeApply = widget.controller.scene;
    final activeLevelBeforeApply = sceneBeforeApply is LevelScene
        ? sceneBeforeApply.activeLevel
        : null;
    final handoffTarget = activeLevelBeforeApply == null
        ? null
        : ParallaxLevelTarget(
            levelId: activeLevelBeforeApply.levelId,
            parallaxThemeId: activeLevelBeforeApply.visualThemeId,
          );
    final changedPaths = pendingChanges.fileDiffs
        .map((diff) => diff.relativePath)
        .join('\n');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Apply Level Changes'),
          content: Text(
            'Write ${pendingChanges.changedItemIds.length} Level/theme '
            'change(s) across ${pendingChanges.fileDiffs.length} file(s)?\n\n'
            '$changedPaths',
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
      setState(_invalidateHandoff);
      _showSnackBar('Apply failed: ${widget.controller.exportError}');
      return;
    }
    final result = widget.controller.lastExportResult;
    final reloadedScene = widget.controller.scene;
    final targetResolved =
        result?.applied == true &&
        handoffTarget != null &&
        reloadedScene is LevelScene &&
        reloadedScene.levels.any(
          (level) =>
              level.levelId == handoffTarget.levelId &&
              level.visualThemeId == handoffTarget.parallaxThemeId,
        ) &&
        !widget.controller.pendingChanges.hasChanges;
    setState(() {
      _parallaxHandoffTarget = targetResolved ? handoffTarget : null;
      _cleanupRequiredPaths = result is LevelThemeExportResult
          ? result.cleanupRequiredPaths
          : const <String>[];
    });
    if (result?.applied != true) {
      _showSnackBar('No source files changed.');
      return;
    }
    _showSnackBar(
      _cleanupRequiredPaths.isEmpty
          ? 'Authoring sources saved. Runtime generation is still required.'
          : 'Sources committed, but transaction cleanup is required.',
    );
  }

  bool get _canApplyToFiles {
    return !widget.controller.isExporting &&
        !widget.controller.isLoading &&
        widget.controller.pendingChanges.hasChanges &&
        widget.controller.pendingChangesError == null &&
        widget.controller.errorCount == 0 &&
        _cleanupRequiredPaths.isEmpty;
  }

  String? _newLevelFormError(LevelScene scene) {
    if (widget.controller.errorCount > 0) {
      return 'Resolve blocking document issues before creating another Level.';
    }
    final levelId = _newLevelIdController.text.trim();
    if (levelId.isEmpty) return 'Enter a level ID.';
    if (!stableLevelIdentifierPattern.hasMatch(levelId)) {
      return 'levelId must match ${stableLevelIdentifierPattern.pattern}.';
    }
    if (scene.levels.any((level) => level.levelId == levelId)) {
      return 'Level "$levelId" already exists.';
    }
    if (_newLevelThemeMode == _NewLevelThemeMode.existing) {
      if (scene.availableParallaxVisualThemeIds.isEmpty) {
        return 'No authored visual themes are available.';
      }
      final existingId = _selectedExistingThemeId;
      if (existingId == null ||
          !scene.availableParallaxVisualThemeIds.contains(existingId)) {
        return 'Choose an existing visual theme explicitly.';
      }
      return null;
    }
    return _newThemeIdError(scene, _newVisualThemeIdController.text.trim());
  }

  String? _newThemeIdError(LevelScene scene, String themeId) {
    final document = widget.controller.document;
    if (document is! LevelDefsDocument ||
        !document.parallaxThemeSourceAvailable ||
        document.parallaxDocument == null) {
      return 'Parallax source is unavailable. Reload a valid workspace.';
    }
    if (themeId.isEmpty) return 'Enter a visual theme ID.';
    if (!stableAuthoringIdentifierPattern.hasMatch(themeId)) {
      return 'Theme ID must match ${stableAuthoringIdentifierPattern.pattern}.';
    }
    if (scene.availableParallaxVisualThemeIds.contains(themeId)) {
      return 'Visual theme "$themeId" already exists. Use existing theme instead.';
    }
    final symbol = generatedParallaxThemeSymbolSuffix(themeId);
    for (final existingId in scene.availableParallaxVisualThemeIds) {
      if (generatedParallaxThemeSymbolSuffix(existingId) == symbol) {
        return 'Theme ID "$themeId" generates the same Dart symbol as '
            '"$existingId".';
      }
    }
    return null;
  }

  Future<void> _showCreateAndAssignThemeDialog(
    LevelScene scene, {
    String? initialThemeId,
  }) async {
    final activeLevel = scene.activeLevel;
    if (activeLevel == null) return;
    final initialDraft =
        initialThemeId ??
        _createThemeDialogDraftId ??
        _suggestThemeId(scene, '${activeLevel.levelId}_theme');
    var draftText = initialDraft;
    setState(() {
      _createThemeDialogDraftId = initialDraft;
      _createThemeDialogOpen = true;
      _invalidateHandoff();
    });
    final acceptedThemeId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final draft = draftText.trim();
            final error = _newThemeIdError(scene, draft);
            return AlertDialog(
              title: const Text('Create and assign visual theme'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      key: const ValueKey<String>(
                        'create_assign_theme_id_field',
                      ),
                      initialValue: initialDraft,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'New visual theme ID',
                        border: const OutlineInputBorder(),
                        errorText: error,
                      ),
                      onChanged: (value) {
                        draftText = value;
                        _createThemeDialogDraftId = value;
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This stages an empty revision-1 theme and assigns it to '
                      'the level in one undo step. Add layers in Parallax after apply.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: error == null
                      ? () => Navigator.of(dialogContext).pop(draft)
                      : null,
                  child: const Text('Create and assign'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _createThemeDialogOpen = false;
      if (acceptedThemeId == null) _createThemeDialogDraftId = null;
    });
    if (acceptedThemeId == null) return;

    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'create_and_assign_theme',
        payload: <String, Object?>{
          'levelId': activeLevel.levelId,
          'visualThemeId': acceptedThemeId,
        },
      ),
    );
    final updatedScene = widget.controller.scene;
    final accepted =
        updatedScene is LevelScene &&
        updatedScene.activeLevel?.levelId == activeLevel.levelId &&
        updatedScene.activeLevel?.visualThemeId == acceptedThemeId &&
        updatedScene.availableParallaxVisualThemeIds.contains(acceptedThemeId);
    if (!accepted) {
      _showSnackBar(
        'The visual theme command was rejected. Review validation.',
      );
      return;
    }
    setState(() {
      _createThemeDialogDraftId = null;
      _visualThemeIdController.text = acceptedThemeId;
    });
  }

  void _resetNewLevelForm(LevelScene scene) {
    final suggestion = _suggestNewLevelId(scene);
    _newLevelFormBaselineId = suggestion;
    _newLevelIdController.text = suggestion;
    _newVisualThemeIdController.text = suggestion;
    _newLevelThemeMode = _NewLevelThemeMode.create;
    _selectedExistingThemeId = null;
    _newThemeIdWasManuallyEdited = false;
  }

  String _suggestThemeId(LevelScene scene, String base) {
    final ids = scene.availableParallaxVisualThemeIds.toSet();
    if (!ids.contains(base)) return base;
    var counter = 2;
    while (ids.contains('${base}_$counter')) {
      counter += 1;
    }
    return '${base}_$counter';
  }

  void _invalidateHandoff() {
    _parallaxHandoffTarget = null;
  }

  String _suggestNewLevelId(LevelScene scene) {
    final existingIds = scene.levels.map((level) => level.levelId).toSet();
    if (!existingIds.contains(_defaultNewLevelId)) {
      return _defaultNewLevelId;
    }
    var counter = 2;
    while (true) {
      final candidate = '${_defaultNewLevelId}_$counter';
      if (!existingIds.contains(candidate)) {
        return candidate;
      }
      counter += 1;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _assemblyDraftDiffersFromLevel(LevelDef level) {
    final currentAssembly = _assemblySegmentsDraft.isEmpty
        ? null
        : LevelAssemblyDef(
            loopSegments: _assemblyLoopSegments,
            segments: _assemblySegmentsDraft,
          );
    return !levelAssemblyEquals(currentAssembly, level.assembly);
  }

  bool _stringListEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i += 1) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  LevelAssemblySegmentDef? get _selectedAssemblySegment {
    final index = _selectedAssemblySegmentIndex;
    if (index == null || index < 0 || index >= _assemblySegmentsDraft.length) {
      return null;
    }
    return _assemblySegmentsDraft[index];
  }

  void _syncSelectedAssemblySegmentControllers() {
    final segment = _selectedAssemblySegment;
    if (segment == null) {
      _segmentIdController.text = '';
      _segmentGroupIdController.text = '';
      _segmentMinChunkCountController.text = '';
      _segmentMaxChunkCountController.text = '';
      _selectedSegmentRequireDistinct = true;
      return;
    }
    _segmentIdController.text = segment.segmentId;
    _segmentGroupIdController.text = segment.groupId;
    _segmentMinChunkCountController.text = segment.minChunkCount.toString();
    _segmentMaxChunkCountController.text = segment.maxChunkCount.toString();
    _selectedSegmentRequireDistinct = segment.requireDistinctChunks;
  }

  void _updateSelectedAssemblySegment(LevelAssemblySegmentDef nextSegment) {
    final index = _selectedAssemblySegmentIndex;
    if (index == null || index < 0 || index >= _assemblySegmentsDraft.length) {
      return;
    }
    final nextSegments = List<LevelAssemblySegmentDef>.from(
      _assemblySegmentsDraft,
    );
    nextSegments[index] = nextSegment.normalized();
    _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
      nextSegments,
    );
  }

  void _addChunkThemeGroup() {
    final candidate = _newChunkThemeGroupIdController.text.trim();
    if (candidate.isEmpty) {
      _showSnackBar('Enter a valid groupId before adding.');
      return;
    }
    if (!stableLevelIdentifierPattern.hasMatch(candidate)) {
      _showSnackBar(
        'groupId must match ${stableLevelIdentifierPattern.pattern}.',
      );
      return;
    }
    if (_chunkThemeGroupsDraft.contains(candidate)) {
      _showSnackBar('Group "$candidate" already exists for this level.');
      return;
    }
    setState(() {
      _chunkThemeGroupsDraft = normalizeLevelChunkThemeGroups(<String>[
        ..._chunkThemeGroupsDraft,
        candidate,
      ]);
      _newChunkThemeGroupIdController.text = '';
    });
  }

  void _removeChunkThemeGroup(LevelScene scene, String groupId) {
    if (groupId == defaultLevelChunkThemeGroupId) {
      _showSnackBar('"$defaultLevelChunkThemeGroupId" cannot be removed.');
      return;
    }
    if (_assemblySegmentsDraft.any((segment) => segment.groupId == groupId)) {
      _showSnackBar(
        'Reassign assembly segments using "$groupId" before removing it.',
      );
      return;
    }
    final activeLevelId = scene.activeLevelId;
    final authoredCount = activeLevelId == null
        ? 0
        : (scene.authoredChunkAssemblyGroupCountsByLevelId[activeLevelId]?[groupId] ??
              0);
    if (authoredCount > 0) {
      _showSnackBar(
        'Group "$groupId" is still used by $authoredCount chunk(s). '
        'Reassign chunks first.',
      );
      return;
    }
    setState(() {
      _chunkThemeGroupsDraft = normalizeLevelChunkThemeGroups(
        _chunkThemeGroupsDraft.where((entry) => entry != groupId),
      );
    });
  }

  void _addAssemblySegment(LevelScene scene) {
    final activeLevel = scene.activeLevel;
    if (activeLevel == null) {
      return;
    }
    final nextSegments = List<LevelAssemblySegmentDef>.from(
      _assemblySegmentsDraft,
    );
    final availableGroups = _chunkThemeGroupsDraft;
    final selectedSegment = _selectedAssemblySegment;
    final draftedGroupId = _segmentGroupIdController.text.trim();
    final preferredGroupId = draftedGroupId.isNotEmpty
        ? draftedGroupId
        : (selectedSegment?.groupId ?? defaultAssemblyGroupId);
    final nextSegment = buildSuggestedLevelAssemblySegment(
      existingSegments: nextSegments,
      availableGroupIds: availableGroups,
      preferredGroupId: preferredGroupId,
    );
    nextSegments.add(nextSegment);
    setState(() {
      _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
        nextSegments,
      );
      _selectedAssemblySegmentIndex = nextSegments.length - 1;
      _syncSelectedAssemblySegmentControllers();
    });
  }

  void _moveSelectedAssemblySegmentUp() {
    final index = _selectedAssemblySegmentIndex;
    if (index == null || index <= 0) {
      return;
    }
    final nextSegments = List<LevelAssemblySegmentDef>.from(
      _assemblySegmentsDraft,
    );
    final current = nextSegments.removeAt(index);
    nextSegments.insert(index - 1, current);
    setState(() {
      _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
        nextSegments,
      );
      _selectedAssemblySegmentIndex = index - 1;
      _syncSelectedAssemblySegmentControllers();
    });
  }

  void _moveSelectedAssemblySegmentDown() {
    final index = _selectedAssemblySegmentIndex;
    if (index == null || index >= _assemblySegmentsDraft.length - 1) {
      return;
    }
    final nextSegments = List<LevelAssemblySegmentDef>.from(
      _assemblySegmentsDraft,
    );
    final current = nextSegments.removeAt(index);
    nextSegments.insert(index + 1, current);
    setState(() {
      _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
        nextSegments,
      );
      _selectedAssemblySegmentIndex = index + 1;
      _syncSelectedAssemblySegmentControllers();
    });
  }

  void _removeSelectedAssemblySegment() {
    final index = _selectedAssemblySegmentIndex;
    if (index == null || index < 0 || index >= _assemblySegmentsDraft.length) {
      return;
    }
    final nextSegments = List<LevelAssemblySegmentDef>.from(
      _assemblySegmentsDraft,
    )..removeAt(index);
    setState(() {
      _assemblySegmentsDraft = List<LevelAssemblySegmentDef>.unmodifiable(
        nextSegments,
      );
      _selectedAssemblySegmentIndex = nextSegments.isEmpty
          ? null
          : (index >= nextSegments.length ? nextSegments.length - 1 : index);
      _syncSelectedAssemblySegmentControllers();
    });
  }
}

enum _NewLevelThemeMode { create, existing }
