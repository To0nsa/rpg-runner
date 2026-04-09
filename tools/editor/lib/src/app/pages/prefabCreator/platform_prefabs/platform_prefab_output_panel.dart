import 'package:flutter/material.dart';

import '../shared/prefab_editor_action_row.dart';
import '../shared/prefab_editor_placement_fields.dart';
import '../shared/prefab_form_state.dart';
import '../shared/prefab_scene_values.dart';
import '../shared/prefab_editor_section_card.dart';
import '../shared/prefab_editor_ui_tokens.dart';

/// Form panel for exporting a platform prefab from the selected module.
class PlatformPrefabOutputPanel extends StatelessWidget {
  const PlatformPrefabOutputPanel({
    super.key,
    required this.form,
    required this.isEnabled,
    required this.isEditingPrefab,
    required this.sceneValues,
    required this.onLoadPrefabForModule,
    required this.onUpsertPrefabForModule,
    required this.onStartNewFromCurrentValues,
    required this.onSnapToGridChanged,
  });

  final PrefabFormState form;
  final bool isEnabled;
  final bool isEditingPrefab;
  final PrefabSceneValues? sceneValues;
  final VoidCallback onLoadPrefabForModule;
  final VoidCallback onUpsertPrefabForModule;
  final VoidCallback onStartNewFromCurrentValues;
  final ValueChanged<bool> onSnapToGridChanged;

  @override
  Widget build(BuildContext context) {
    return PrefabEditorSectionCard(
      title: 'Platform Prefab Output',
      description:
          'Set anchor/collider here and save a platform prefab directly from this module.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorActionRow(
            children: [
              OutlinedButton.icon(
                onPressed: isEnabled ? onLoadPrefabForModule : null,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Load Prefab For Module'),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('platform_prefab_upsert_button'),
                onPressed: isEnabled ? onUpsertPrefabForModule : null,
                icon: Icon(
                  isEditingPrefab
                      ? Icons.save_outlined
                      : Icons.add_box_outlined,
                ),
                label: Text(
                  isEditingPrefab
                      ? 'Update Platform Prefab'
                      : 'Create Platform Prefab',
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>(
                  'platform_prefab_new_from_current_values_button',
                ),
                onPressed: isEnabled && isEditingPrefab
                    ? onStartNewFromCurrentValues
                    : null,
                icon: const Icon(Icons.post_add_outlined),
                label: const Text('New From Current Values'),
              ),
            ],
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          TextField(
            controller: form.prefabIdController,
            enabled: isEnabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Platform Prefab ID',
            ),
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          PrefabEditorPlacementFields(
            form: form,
            isEnabled: isEnabled,
            onSnapToGridChanged: onSnapToGridChanged,
            colliderOffsetXLabel: 'Collider Offset X',
            colliderOffsetYLabel: 'Collider Offset Y',
            colliderWidthLabel: 'Collider Width',
            colliderHeightLabel: 'Collider Height',
            invalidValuesMessage: sceneValues == null
                ? 'Anchor/collider fields contain invalid values. '
                      'Fix them before saving the prefab.'
                : null,
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          TextField(
            controller: form.tagsController,
            enabled: isEnabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Tags (comma separated)',
            ),
          ),
        ],
      ),
    );
  }
}
