import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/authoring_types.dart';
import '../../../levels/level_domain_models.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';

class LevelCreatorPage extends StatefulWidget {
  const LevelCreatorPage({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<LevelCreatorPage> createState() => _LevelCreatorPageState();
}

class _LevelCreatorPageState extends State<LevelCreatorPage>
    implements EditorPageLocalDraftState {
  static const String _defaultNewLevelId = 'new_level';

  final TextEditingController _newLevelIdController = TextEditingController(
    text: _defaultNewLevelId,
  );
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _themeIdController = TextEditingController();
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

  String? _selectedLevelId;

  @override
  bool get hasLocalDraftChanges {
    final scene = widget.controller.scene;
    final levelScene = scene is LevelScene ? scene : null;
    final activeLevel = levelScene?.activeLevel;
    if (_newLevelIdController.text.trim() != _defaultNewLevelId) {
      return true;
    }
    if (activeLevel == null) {
      return _displayNameController.text.trim().isNotEmpty ||
          _themeIdController.text.trim().isNotEmpty ||
          _cameraCenterYController.text.trim().isNotEmpty ||
          _groundTopYController.text.trim().isNotEmpty ||
          _earlyPatternChunksController.text.trim().isNotEmpty ||
          _easyPatternChunksController.text.trim().isNotEmpty ||
          _normalPatternChunksController.text.trim().isNotEmpty ||
          _noEnemyChunksController.text.trim().isNotEmpty ||
          _enumOrdinalController.text.trim().isNotEmpty;
    }
    return _displayNameController.text.trim() != activeLevel.displayName ||
        _themeIdController.text.trim() != activeLevel.themeId ||
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
            activeLevel.enumOrdinal.toString();
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
    _displayNameController.dispose();
    _themeIdController.dispose();
    _cameraCenterYController.dispose();
    _groundTopYController.dispose();
    _earlyPatternChunksController.dispose();
    _easyPatternChunksController.dispose();
    _normalPatternChunksController.dispose();
    _noEnemyChunksController.dispose();
    _enumOrdinalController.dispose();
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

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildControls(levelScene),
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
                    child: Row(
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
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(LevelScene? scene) {
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
          TextField(
            controller: _newLevelIdController,
            decoration: const InputDecoration(
              labelText: 'New levelId',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _createLevel,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
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

  Widget _buildLevelEntry(
    LevelDef level, {
    required bool isSelected,
    required int chunkCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDirty = widget.controller.dirtyItemIds.contains(level.levelId);
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                  'theme=${level.themeId}  status=${level.status}  chunks=$chunkCount',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'ordinal=${level.enumOrdinal}  ground=${formatCanonicalLevelNumber(level.groundTopY)}  camera=${formatCanonicalLevelNumber(level.cameraCenterY)}',
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

    return _buildPane(
      title: 'Inspector',
      child: ListView(
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
          TextField(
            controller: _themeIdController,
            decoration: const InputDecoration(
              labelText: 'themeId',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (scene.availableParallaxThemeIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final themeId in scene.availableParallaxThemeIds)
                  ActionChip(
                    label: Text(themeId),
                    onPressed: () {
                      setState(() {
                        _themeIdController.text = themeId;
                      });
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _cameraCenterYController,
            decoration: const InputDecoration(
              labelText: 'cameraCenterY',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _groundTopYController,
            decoration: const InputDecoration(
              labelText: 'groundTopY',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _earlyPatternChunksController,
            decoration: const InputDecoration(
              labelText: 'earlyPatternChunks',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _easyPatternChunksController,
            decoration: const InputDecoration(
              labelText: 'easyPatternChunks',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _normalPatternChunksController,
            decoration: const InputDecoration(
              labelText: 'normalPatternChunks',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noEnemyChunksController,
            decoration: const InputDecoration(
              labelText: 'noEnemyChunks',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
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
          const SizedBox(height: 8),
          FilledButton(
            onPressed: activeLevel == null ? null : _applySelectedLevelChanges,
            child: const Text('Apply Level'),
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

  void _syncInspector(LevelDef level) {
    _displayNameController.text = level.displayName;
    _themeIdController.text = level.themeId;
    _cameraCenterYController.text = formatCanonicalLevelNumber(
      level.cameraCenterY,
    );
    _groundTopYController.text = formatCanonicalLevelNumber(level.groundTopY);
    _earlyPatternChunksController.text = level.earlyPatternChunks.toString();
    _easyPatternChunksController.text = level.easyPatternChunks.toString();
    _normalPatternChunksController.text = level.normalPatternChunks.toString();
    _noEnemyChunksController.text = level.noEnemyChunks.toString();
    _enumOrdinalController.text = level.enumOrdinal.toString();
  }

  void _clearInspector() {
    _displayNameController.text = '';
    _themeIdController.text = '';
    _cameraCenterYController.text = '';
    _groundTopYController.text = '';
    _earlyPatternChunksController.text = '';
    _easyPatternChunksController.text = '';
    _normalPatternChunksController.text = '';
    _noEnemyChunksController.text = '';
    _enumOrdinalController.text = '';
  }

  void _createLevel() {
    final requestedLevelId = _newLevelIdController.text.trim();
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'create_level',
        payload: <String, Object?>{'levelId': requestedLevelId},
      ),
    );
    final updatedScene = widget.controller.scene;
    if (updatedScene is! LevelScene ||
        updatedScene.activeLevelId != requestedLevelId) {
      return;
    }
    setState(() {
      _newLevelIdController.text = _suggestNewLevelId(updatedScene);
    });
  }

  void _duplicateActiveLevel() {
    final scene = widget.controller.scene;
    if (scene is! LevelScene || scene.activeLevel == null) {
      return;
    }
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
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'update_level',
        payload: <String, Object?>{
          'levelId': scene.activeLevel!.levelId,
          'displayName': _displayNameController.text.trim(),
          'themeId': _themeIdController.text.trim(),
          'cameraCenterY': _cameraCenterYController.text.trim(),
          'groundTopY': _groundTopYController.text.trim(),
          'earlyPatternChunks': _earlyPatternChunksController.text.trim(),
          'easyPatternChunks': _easyPatternChunksController.text.trim(),
          'normalPatternChunks': _normalPatternChunksController.text.trim(),
          'noEnemyChunks': _noEnemyChunksController.text.trim(),
          'enumOrdinal': _enumOrdinalController.text.trim(),
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
          title: const Text('Apply Level Changes'),
          content: Text(
            'Write ${pendingChanges.changedItemIds.length} level change(s) '
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
    _showSnackBar('Level changes applied.');
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
