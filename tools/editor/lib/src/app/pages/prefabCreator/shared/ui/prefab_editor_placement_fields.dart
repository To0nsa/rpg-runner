import 'package:flutter/material.dart';

import '../../../../../prefabs/models/models.dart';
import '../prefab_form_state.dart';
import 'prefab_editor_action_row.dart';
import 'prefab_editor_ui_tokens.dart';

/// Shared placement/collider fields used by obstacle and platform prefab flows.
class PrefabEditorPlacementFields extends StatelessWidget {
  const PrefabEditorPlacementFields({
    super.key,
    required this.form,
    this.isEnabled = true,
    this.colliderOffsetXLabel = 'Offset X',
    this.colliderOffsetYLabel = 'Offset Y',
    this.colliderWidthLabel = 'Width',
    this.colliderHeightLabel = 'Height',
    this.colliders = const <PrefabColliderDef>[],
    this.selectedColliderIndex,
    this.onSelectedColliderChanged,
    this.onAddCollider,
    this.onDuplicateCollider,
    this.onDeleteCollider,
    this.colliderKeyPrefix = 'prefab_collider',
    this.invalidValuesMessage,
  });

  final PrefabFormState form;
  final bool isEnabled;
  final String colliderOffsetXLabel;
  final String colliderOffsetYLabel;
  final String colliderWidthLabel;
  final String colliderHeightLabel;
  final List<PrefabColliderDef> colliders;
  final int? selectedColliderIndex;
  final ValueChanged<int>? onSelectedColliderChanged;
  final VoidCallback? onAddCollider;
  final VoidCallback? onDuplicateCollider;
  final VoidCallback? onDeleteCollider;
  final String colliderKeyPrefix;
  final String? invalidValuesMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            const SizedBox(width: PrefabEditorUiTokens.controlGap),
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
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        Text('Collider List', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        if (colliders.isEmpty)
          const Text('No colliders configured.')
        else
          Wrap(
            spacing: PrefabEditorUiTokens.controlGap,
            runSpacing: PrefabEditorUiTokens.controlGap,
            children: [
              for (var i = 0; i < colliders.length; i += 1)
                ChoiceChip(
                  key: ValueKey<String>('${colliderKeyPrefix}_chip_$i'),
                  label: Text(_colliderLabel(i, colliders[i])),
                  selected: selectedColliderIndex == i,
                  onSelected: !isEnabled || onSelectedColliderChanged == null
                      ? null
                      : (_) => onSelectedColliderChanged!(i),
                ),
            ],
          ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        PrefabEditorActionRow(
          children: [
            OutlinedButton.icon(
              key: ValueKey<String>('${colliderKeyPrefix}_add_button'),
              onPressed: isEnabled ? onAddCollider : null,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Add Collider'),
            ),
            OutlinedButton.icon(
              key: ValueKey<String>('${colliderKeyPrefix}_duplicate_button'),
              onPressed: isEnabled ? onDuplicateCollider : null,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate Collider'),
            ),
            OutlinedButton.icon(
              key: ValueKey<String>('${colliderKeyPrefix}_delete_button'),
              onPressed: isEnabled ? onDeleteCollider : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Collider'),
            ),
          ],
        ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: form.colliderOffsetXController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: colliderOffsetXLabel,
                ),
              ),
            ),
            const SizedBox(width: PrefabEditorUiTokens.controlGap),
            Expanded(
              child: TextField(
                controller: form.colliderOffsetYController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: colliderOffsetYLabel,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: form.colliderWidthController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: colliderWidthLabel,
                ),
              ),
            ),
            const SizedBox(width: PrefabEditorUiTokens.controlGap),
            Expanded(
              child: TextField(
                controller: form.colliderHeightController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: colliderHeightLabel,
                ),
              ),
            ),
          ],
        ),
        if (invalidValuesMessage != null) ...[
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          Text(invalidValuesMessage!),
        ],
      ],
    );
  }

  String _colliderLabel(int index, PrefabColliderDef collider) {
    return '#${index + 1} '
        '${collider.width}x${collider.height} '
        '@ ${collider.offsetX},${collider.offsetY}';
  }
}
