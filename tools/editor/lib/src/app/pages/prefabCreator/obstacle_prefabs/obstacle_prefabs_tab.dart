import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../shared/prefab_form_state.dart';
import '../shared/prefab_scene_values.dart';
import 'widgets/prefab_scene_view.dart';

/// Obstacle-prefab authoring view for atlas-slice-backed prefabs.
class ObstaclePrefabsTab extends StatelessWidget {
  const ObstaclePrefabsTab({
    super.key,
    required this.form,
    required this.prefabSlices,
    required this.obstaclePrefabs,
    required this.selectedSliceId,
    required this.selectedSlice,
    required this.editingObstaclePrefab,
    required this.sceneValues,
    required this.workspaceRootPath,
    required this.onSelectedSliceChanged,
    required this.onSnapToGridChanged,
    required this.onSceneValuesChanged,
    required this.onLoadPrefab,
    required this.onDeletePrefab,
    required this.onUpsertPrefab,
    required this.onDuplicatePrefab,
    required this.onDeprecatePrefab,
    required this.onClearForm,
  });

  final PrefabFormState form;
  final List<AtlasSliceDef> prefabSlices;
  final List<PrefabDef> obstaclePrefabs;
  final String? selectedSliceId;
  final AtlasSliceDef? selectedSlice;
  final PrefabDef? editingObstaclePrefab;
  final PrefabSceneValues? sceneValues;
  final String workspaceRootPath;
  final ValueChanged<String?> onSelectedSliceChanged;
  final ValueChanged<bool> onSnapToGridChanged;
  final ValueChanged<PrefabSceneValues> onSceneValuesChanged;
  final ValueChanged<PrefabDef> onLoadPrefab;
  final ValueChanged<String> onDeletePrefab;
  final VoidCallback onUpsertPrefab;
  final VoidCallback onDuplicatePrefab;
  final VoidCallback onDeprecatePrefab;
  final VoidCallback onClearForm;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _ObstaclePrefabScenePanel(
                  workspaceRootPath: workspaceRootPath,
                  selectedSlice: selectedSlice,
                  sceneValues: sceneValues,
                  onSceneValuesChanged: onSceneValuesChanged,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Obstacle Prefabs',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 1,
                child: obstaclePrefabs.isEmpty
                    ? const Text('No obstacle prefabs yet.')
                    : ListView.builder(
                        itemCount: obstaclePrefabs.length,
                        itemBuilder: (context, index) {
                          final prefab = obstaclePrefabs[index];
                          return Card(
                            child: ListTile(
                              title: Text(prefab.id),
                              subtitle: Text(
                                'key=${prefab.prefabKey} '
                                'rev=${prefab.revision} '
                                'status=${prefab.status.jsonValue} '
                                'source=atlas_slice:${prefab.sliceId} '
                                'anchor=(${prefab.anchorXPx},${prefab.anchorYPx}) '
                                'colliders=${prefab.colliders.length} '
                                'z=${prefab.zIndex} '
                                'snap=${prefab.snapToGrid}',
                              ),
                              onTap: () => onLoadPrefab(prefab),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => onDeletePrefab(prefab.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 420,
          child: _ObstaclePrefabInspectorPanel(
            form: form,
            prefabSlices: prefabSlices,
            selectedSliceId: selectedSliceId,
            editingObstaclePrefab: editingObstaclePrefab,
            onSelectedSliceChanged: onSelectedSliceChanged,
            onSnapToGridChanged: onSnapToGridChanged,
            onUpsertPrefab: onUpsertPrefab,
            onDuplicatePrefab: onDuplicatePrefab,
            onDeprecatePrefab: onDeprecatePrefab,
            onClearForm: onClearForm,
          ),
        ),
      ],
    );
  }
}

class _ObstaclePrefabInspectorPanel extends StatelessWidget {
  const _ObstaclePrefabInspectorPanel({
    required this.form,
    required this.prefabSlices,
    required this.selectedSliceId,
    required this.editingObstaclePrefab,
    required this.onSelectedSliceChanged,
    required this.onSnapToGridChanged,
    required this.onUpsertPrefab,
    required this.onDuplicatePrefab,
    required this.onDeprecatePrefab,
    required this.onClearForm,
  });

  final PrefabFormState form;
  final List<AtlasSliceDef> prefabSlices;
  final String? selectedSliceId;
  final PrefabDef? editingObstaclePrefab;
  final ValueChanged<String?> onSelectedSliceChanged;
  final ValueChanged<bool> onSnapToGridChanged;
  final VoidCallback onUpsertPrefab;
  final VoidCallback onDuplicatePrefab;
  final VoidCallback onDeprecatePrefab;
  final VoidCallback onClearForm;

  @override
  Widget build(BuildContext context) {
    final hasObstacleSources = prefabSlices.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasObstacleSources)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'No prefab slices yet. Obstacle prefabs require atlas slices.',
                ),
              ),
            if (editingObstaclePrefab != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Editing key=${editingObstaclePrefab!.prefabKey} '
                  'rev=${editingObstaclePrefab!.revision} '
                  'status=${editingObstaclePrefab!.status.jsonValue}',
                ),
              ),
            TextField(
              controller: form.prefabIdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Prefab ID',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Visual Source',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            hasObstacleSources
                ? DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      'prefab_slice_${selectedSliceId ?? 'none'}',
                    ),
                    initialValue: selectedSliceId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Atlas Slice',
                    ),
                    items: [
                      for (final slice in prefabSlices)
                        DropdownMenuItem<String>(
                          value: slice.id,
                          child: Text(slice.id),
                        ),
                    ],
                    onChanged: onSelectedSliceChanged,
                  )
                : const Text('Create prefab atlas slices first.'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: form.anchorXController,
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
            Text(
              'Default Collider',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: form.colliderOffsetXController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Offset X',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: form.colliderOffsetYController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Offset Y',
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
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Width',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: form.colliderHeightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Height',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: form.zIndexController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Z Index',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: form.snapToGrid,
              onChanged: (value) {
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Tags (comma separated)',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey<String>('obstacle_prefab_upsert_button'),
                  onPressed: onUpsertPrefab,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Add/Update Prefab'),
                ),
                OutlinedButton.icon(
                  onPressed: onDuplicatePrefab,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Duplicate'),
                ),
                OutlinedButton.icon(
                  onPressed: onDeprecatePrefab,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Deprecate'),
                ),
                OutlinedButton.icon(
                  onPressed: onClearForm,
                  icon: const Icon(Icons.clear_outlined),
                  label: const Text('Clear Form'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ObstaclePrefabScenePanel extends StatelessWidget {
  const _ObstaclePrefabScenePanel({
    required this.workspaceRootPath,
    required this.selectedSlice,
    required this.sceneValues,
    required this.onSceneValuesChanged,
  });

  final String workspaceRootPath;
  final AtlasSliceDef? selectedSlice;
  final PrefabSceneValues? sceneValues;
  final ValueChanged<PrefabSceneValues> onSceneValuesChanged;

  @override
  Widget build(BuildContext context) {
    if (sceneValues == null) {
      return const Card(
        child: SizedBox(
          height: 210,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Anchor/collider fields contain invalid values. '
                'Fix them to enable scene editing.',
              ),
            ),
          ),
        ),
      );
    }

    if (selectedSlice == null) {
      return const Card(
        child: SizedBox(
          height: 210,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select a prefab slice to edit anchor/collider visually.',
              ),
            ),
          ),
        ),
      );
    }

    return PrefabSceneView(
      workspaceRootPath: workspaceRootPath,
      slice: selectedSlice!,
      values: sceneValues!,
      onChanged: onSceneValuesChanged,
    );
  }
}
