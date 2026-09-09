import 'package:flutter/material.dart';

import '../../../levels/level_domain_models.dart';

enum NewLevelThemeMode { copy, existing, create }

/// Friendly creation intent. Optional IDs are advanced overrides; allocation,
/// collision checks, background copying, and source writes remain domain owned.
class LevelCreationForm extends StatelessWidget {
  const LevelCreationForm({
    super.key,
    required this.scene,
    required this.nameController,
    required this.newLevelIdController,
    required this.newVisualThemeIdController,
    required this.themeMode,
    required this.selectedExistingThemeId,
    required this.formError,
    required this.isExporting,
    required this.onChanged,
    required this.onThemeModeChanged,
    required this.onExistingThemeChanged,
    required this.onCreate,
    required this.themePreview,
    this.copyingSettings = false,
    this.copySectionDesign = false,
    this.onCopySectionDesignChanged,
  });

  final LevelScene scene;
  final TextEditingController nameController;
  final TextEditingController newLevelIdController;
  final TextEditingController newVisualThemeIdController;
  final NewLevelThemeMode themeMode;
  final String? selectedExistingThemeId;
  final String? formError;
  final bool isExporting;
  final VoidCallback onChanged;
  final ValueChanged<NewLevelThemeMode> onThemeModeChanged;
  final ValueChanged<String?> onExistingThemeChanged;
  final VoidCallback onCreate;
  final Widget Function(String) themePreview;
  final bool copyingSettings;
  final bool copySectionDesign;
  final ValueChanged<bool>? onCopySectionDesignChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('new_level_name'),
        controller: nameController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Level name',
          hintText: 'Crystal Depths',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => onChanged(),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<NewLevelThemeMode>(
        key: ValueKey(themeMode),
        initialValue: themeMode,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Background'),
        items: const [
          DropdownMenuItem(
            value: NewLevelThemeMode.copy,
            child: Text('Make an independent copy'),
          ),
          DropdownMenuItem(
            value: NewLevelThemeMode.existing,
            child: Text('Share an existing background'),
          ),
          DropdownMenuItem(
            value: NewLevelThemeMode.create,
            child: Text('Start with an empty background'),
          ),
        ],
        onChanged: (value) {
          if (value != null) onThemeModeChanged(value);
        },
      ),
      if (themeMode != NewLevelThemeMode.create) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'new_level_background_source_${themeMode.name}_$selectedExistingThemeId',
          ),
          initialValue:
              scene.availableParallaxVisualThemeIds.contains(
                selectedExistingThemeId,
              )
              ? selectedExistingThemeId
              : null,
          isExpanded: true,
          itemHeight: 72,
          decoration: const InputDecoration(labelText: 'Source background'),
          items: [
            for (final id in scene.availableParallaxVisualThemeIds)
              DropdownMenuItem(
                value: id,
                child: Row(
                  children: [
                    SizedBox(width: 84, height: 52, child: themePreview(id)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(id, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
          ],
          onChanged: onExistingThemeChanged,
        ),
        const SizedBox(height: 8),
        Text(
          themeMode == NewLevelThemeMode.copy
              ? 'The copy starts with these layers and can be edited independently.'
              : 'Background edits will affect every level that shares it.',
        ),
      ] else ...[
        const SizedBox(height: 8),
        const Text(
          'Creates a valid empty background. Add its layers in Appearance.',
        ),
      ],
      if (copyingSettings) ...[
        const SizedBox(height: 12),
        CheckboxListTile(
          key: const ValueKey('copy_level_section_design'),
          contentPadding: EdgeInsets.zero,
          value: copySectionDesign,
          title: const Text('Copy section design too'),
          subtitle: const Text(
            'Copies group and section rules. Chunk files are not copied; populate the new content pool separately.',
          ),
          onChanged: (value) {
            if (value != null) onCopySectionDesignChanged?.call(value);
          },
        ),
        const Text(
          'Without section design, the copy starts in Automatic mode.',
        ),
      ],
      const SizedBox(height: 12),
      const Text(
        'New levels start outside the Build. Add content, try Play, then enable Include in Build when ready.',
      ),
      ExpansionTile(
        title: const Text('Advanced IDs'),
        children: [
          TextField(
            key: const ValueKey('new_level_id_field'),
            controller: newLevelIdController,
            decoration: const InputDecoration(
              labelText: 'Level ID override',
              hintText: 'Automatic from the name',
            ),
            onChanged: (_) => onChanged(),
          ),
          if (themeMode != NewLevelThemeMode.existing)
            TextField(
              key: const ValueKey('new_visual_theme_id_field'),
              controller: newVisualThemeIdController,
              decoration: const InputDecoration(
                labelText: 'Background ID override',
                hintText: 'Automatic independent ID',
              ),
              onChanged: (_) => onChanged(),
            ),
        ],
      ),
      if (formError != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            formError!,
            key: const ValueKey('new_level_form_error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      FilledButton.icon(
        key: const ValueKey('create_level_button'),
        onPressed: formError == null && !isExporting ? onCreate : null,
        icon: Icon(copyingSettings ? Icons.copy : Icons.add),
        label: Text(copyingSettings ? 'Create copy' : 'Create level'),
      ),
    ],
  );
}
