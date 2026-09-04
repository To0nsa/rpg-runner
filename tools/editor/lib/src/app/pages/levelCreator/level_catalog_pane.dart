import 'package:flutter/material.dart';

import '../../../levels/level_domain_models.dart';
import 'level_presentation.dart';

/// Whether a new Level creates a Parallax theme or reuses an authored one.
enum NewLevelThemeMode { create, existing }

/// Level catalog, lifecycle actions, and local new-Level form presentation.
///
/// Controllers and callbacks remain owned by `LevelCreatorPage`; this widget
/// cannot dispatch session commands or persist source files directly.
class LevelCatalogPane extends StatelessWidget {
  const LevelCatalogPane({
    super.key,
    required this.scene,
    required this.dirtyItemIds,
    required this.newLevelIdController,
    required this.newVisualThemeIdController,
    required this.themeMode,
    required this.selectedExistingThemeId,
    required this.formError,
    required this.isExporting,
    required this.onNewLevelIdChanged,
    required this.onThemeModeChanged,
    required this.onNewThemeIdChanged,
    required this.onExistingThemeChanged,
    required this.onCreate,
    required this.onDuplicate,
    required this.onDeprecate,
    required this.onReactivate,
    required this.onLevelSelected,
  });

  final LevelScene scene;
  final Set<String> dirtyItemIds;
  final TextEditingController newLevelIdController;
  final TextEditingController newVisualThemeIdController;
  final NewLevelThemeMode themeMode;
  final String? selectedExistingThemeId;
  final String? formError;
  final bool isExporting;
  final ValueChanged<String> onNewLevelIdChanged;
  final ValueChanged<NewLevelThemeMode> onThemeModeChanged;
  final ValueChanged<String> onNewThemeIdChanged;
  final ValueChanged<String?> onExistingThemeChanged;
  final VoidCallback onCreate;
  final VoidCallback onDuplicate;
  final VoidCallback onDeprecate;
  final VoidCallback onReactivate;
  final ValueChanged<String> onLevelSelected;

  @override
  Widget build(BuildContext context) => LevelPane(
    title: 'Levels',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NewLevelForm(
          scene: scene,
          newLevelIdController: newLevelIdController,
          newVisualThemeIdController: newVisualThemeIdController,
          themeMode: themeMode,
          selectedExistingThemeId: selectedExistingThemeId,
          formError: formError,
          isExporting: isExporting,
          onNewLevelIdChanged: onNewLevelIdChanged,
          onThemeModeChanged: onThemeModeChanged,
          onNewThemeIdChanged: onNewThemeIdChanged,
          onExistingThemeChanged: onExistingThemeChanged,
          onCreate: onCreate,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: scene.activeLevel == null ? null : onDuplicate,
              child: const Text('Duplicate'),
            ),
            OutlinedButton(
              onPressed:
                  scene.activeLevel == null ||
                      scene.activeLevel!.status == levelStatusDeprecated
                  ? null
                  : onDeprecate,
              child: const Text('Deprecate'),
            ),
            OutlinedButton(
              onPressed:
                  scene.activeLevel == null ||
                      scene.activeLevel!.status == levelStatusActive
                  ? null
                  : onReactivate,
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
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == scene.levels.length - 1 ? 0 : 8,
                      ),
                      child: _LevelEntry(
                        level: level,
                        isSelected: level.levelId == scene.activeLevelId,
                        isDirty: dirtyItemIds.contains(
                          'level:${level.levelId}',
                        ),
                        chunkCount:
                            scene.authoredChunkCountsByLevelId[level.levelId] ??
                            0,
                        onSelected: () => onLevelSelected(level.levelId),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _NewLevelForm extends StatelessWidget {
  const _NewLevelForm({
    required this.scene,
    required this.newLevelIdController,
    required this.newVisualThemeIdController,
    required this.themeMode,
    required this.selectedExistingThemeId,
    required this.formError,
    required this.isExporting,
    required this.onNewLevelIdChanged,
    required this.onThemeModeChanged,
    required this.onNewThemeIdChanged,
    required this.onExistingThemeChanged,
    required this.onCreate,
  });

  final LevelScene scene;
  final TextEditingController newLevelIdController;
  final TextEditingController newVisualThemeIdController;
  final NewLevelThemeMode themeMode;
  final String? selectedExistingThemeId;
  final String? formError;
  final bool isExporting;
  final ValueChanged<String> onNewLevelIdChanged;
  final ValueChanged<NewLevelThemeMode> onThemeModeChanged;
  final ValueChanged<String> onNewThemeIdChanged;
  final ValueChanged<String?> onExistingThemeChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
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
              controller: newLevelIdController,
              decoration: const InputDecoration(
                labelText: 'New levelId',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onNewLevelIdChanged,
            ),
            const SizedBox(height: 8),
            SegmentedButton<NewLevelThemeMode>(
              key: const ValueKey<String>('new_level_theme_mode'),
              segments: const <ButtonSegment<NewLevelThemeMode>>[
                ButtonSegment<NewLevelThemeMode>(
                  value: NewLevelThemeMode.create,
                  icon: Icon(Icons.add_photo_alternate_outlined),
                  label: Text('Create new theme'),
                ),
                ButtonSegment<NewLevelThemeMode>(
                  value: NewLevelThemeMode.existing,
                  icon: Icon(Icons.collections_outlined),
                  label: Text('Use existing theme'),
                ),
              ],
              selected: <NewLevelThemeMode>{themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  onThemeModeChanged(selection.single),
            ),
            const SizedBox(height: 8),
            if (themeMode == NewLevelThemeMode.create)
              TextField(
                key: const ValueKey<String>('new_visual_theme_id_field'),
                controller: newVisualThemeIdController,
                decoration: const InputDecoration(
                  labelText: 'New visual theme ID',
                  helperText: 'Creates an empty theme. Add its layers in Parallax after apply.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: onNewThemeIdChanged,
              )
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: const ValueKey<String>('new_level_existing_theme'),
                initialValue: themeIds.contains(selectedExistingThemeId)
                    ? selectedExistingThemeId
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
                onChanged: themeIds.isEmpty ? null : onExistingThemeChanged,
              ),
            if (formError != null) ...[
              const SizedBox(height: 6),
              Text(
                formError!,
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
              onPressed: formError == null && !isExporting ? onCreate : null,
              icon: const Icon(Icons.add),
              label: const Text('Create Level'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelEntry extends StatelessWidget {
  const _LevelEntry({
    required this.level,
    required this.isSelected,
    required this.isDirty,
    required this.chunkCount,
    required this.onSelected,
  });

  final LevelDef level;
  final bool isSelected;
  final bool isDirty;
  final int chunkCount;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
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
          key: ValueKey<String>('level_entry_${level.levelId}'),
          borderRadius: BorderRadius.circular(6),
          onTap: onSelected,
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
}
