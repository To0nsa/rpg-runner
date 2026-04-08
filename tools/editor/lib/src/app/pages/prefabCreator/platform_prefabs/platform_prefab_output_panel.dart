import 'package:flutter/material.dart';

import '../shared/prefab_form_state.dart';
import '../shared/prefab_scene_values.dart';

/// Form panel for exporting a platform prefab from the selected module.
class PlatformPrefabOutputPanel extends StatelessWidget {
  const PlatformPrefabOutputPanel({
    super.key,
    required this.form,
    required this.isEnabled,
    required this.sceneValues,
    required this.onLoadPrefabForModule,
    required this.onUpsertPrefabForModule,
    required this.onSnapToGridChanged,
  });

  final PrefabFormState form;
  final bool isEnabled;
  final PrefabSceneValues? sceneValues;
  final VoidCallback onLoadPrefabForModule;
  final VoidCallback onUpsertPrefabForModule;
  final ValueChanged<bool> onSnapToGridChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Prefab Output',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Set anchor/collider here and save a platform prefab directly from this module.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: isEnabled ? onLoadPrefabForModule : null,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Load Prefab For Module'),
            ),
            FilledButton.icon(
              onPressed: isEnabled ? onUpsertPrefabForModule : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Create/Update Platform Prefab'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: form.prefabIdController,
          enabled: isEnabled,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Platform Prefab ID',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: form.anchorXController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Anchor X (px)',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: form.anchorYController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Anchor Y (px)',
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
                controller: form.colliderOffsetXController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Collider Offset X',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: form.colliderOffsetYController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Collider Offset Y',
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
                controller: form.colliderWidthController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Collider Width',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: form.colliderHeightController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Collider Height',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: form.zIndexController,
          enabled: isEnabled,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Z Index',
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: form.snapToGrid,
          onChanged: !isEnabled
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }
                  onSnapToGridChanged(value);
                },
          title: const Text('Snap To Grid'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: form.tagsController,
          enabled: isEnabled,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Tags (comma separated)',
          ),
        ),
        if (sceneValues == null) ...[
          const SizedBox(height: 8),
          const Text(
            'Anchor/collider fields contain invalid values. '
            'Fix them before saving the prefab.',
          ),
        ],
      ],
    );
  }
}
