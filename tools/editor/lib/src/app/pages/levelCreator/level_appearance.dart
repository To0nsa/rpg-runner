import 'package:flutter/material.dart';

import '../../../parallax/parallax_domain_models.dart';

/// Level theme assignment and shared usage. Layer editing stays in Parallax.
class LevelAppearance extends StatelessWidget {
  const LevelAppearance({
    super.key,
    required this.themeId,
    required this.themes,
    required this.usedByNames,
    required this.onThemeSelected,
    required this.onCreateTheme,
    required this.onEditTheme,
    this.onCopyTheme,
  });

  final String themeId;
  final List<ParallaxThemeDef> themes;
  final List<String> usedByNames;
  final ValueChanged<String> onThemeSelected;
  final VoidCallback onCreateTheme;
  final VoidCallback? onEditTheme;
  final VoidCallback? onCopyTheme;

  @override
  Widget build(BuildContext context) {
    final theme = findParallaxThemeById(themes, themeId);
    final foregroundCount =
        theme?.layers
            .where((layer) => layer.group == parallaxGroupForeground)
            .length ??
        0;
    return ListView(
      key: const PageStorageKey<String>('level_appearance_scroll'),
      padding: const EdgeInsets.all(12),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey<String>('level_background_$themeId'),
          initialValue: theme == null ? null : themeId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Background',
            hintText: 'Choose an authored background',
          ),
          items: [
            for (final item in themes)
              DropdownMenuItem(
                value: item.parallaxThemeId,
                child: Text(item.parallaxThemeId),
              ),
          ],
          onChanged: (value) {
            if (value != null) onThemeSelected(value);
          },
        ),
        const SizedBox(height: 12),
        Text(
          theme == null
              ? 'The assigned background is missing. Choose an existing background or create it.'
              : theme.layers.isEmpty
              ? 'This background has no layers. Empty backgrounds are valid.'
              : '${theme.layers.where((layer) => layer.group == parallaxGroupBackground).length} background layers',
        ),
        const SizedBox(height: 8),
        Text(
          'Used by ${usedByNames.length} level${usedByNames.length == 1 ? '' : 's'}: ${usedByNames.join(', ')}',
        ),
        if (usedByNames.length > 1)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Editing this background changes every listed level. Make an independent copy when only this level should change.',
            ),
          ),
        if (foregroundCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$foregroundCount foreground layer${foregroundCount == 1 ? ' is' : 's are'} authored but unsupported by gameplay rendering. Edit the background to resolve this limitation.',
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: theme == null ? null : onEditTheme,
              icon: const Icon(Icons.layers_outlined),
              label: Text(
                theme?.layers.isEmpty == true
                    ? 'Add background layers'
                    : 'Edit background',
              ),
            ),
            if (onCopyTheme != null)
              OutlinedButton.icon(
                onPressed: onCopyTheme,
                icon: const Icon(Icons.copy),
                label: const Text('Make a copy'),
              ),
            OutlinedButton.icon(
              onPressed: onCreateTheme,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                theme == null
                    ? 'Create missing background'
                    : 'Create empty background',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Terrain appearance comes from the materials and objects authored in each chunk. The background applies to the whole level.',
        ),
      ],
    );
  }
}
