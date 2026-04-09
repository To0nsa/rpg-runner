import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../../shared/atlas_slice_preview_tile.dart';
import '../../shared/editor_scene_view_utils.dart';
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
    required this.onStartNewFromCurrentValues,
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
  final VoidCallback onStartNewFromCurrentValues;
  final VoidCallback onClearForm;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
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
            onStartNewFromCurrentValues: onStartNewFromCurrentValues,
            onClearForm: onClearForm,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Card(
            key: const ValueKey<String>('obstacle_prefab_scene_card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _ObstaclePrefabScenePanel(
                workspaceRootPath: workspaceRootPath,
                selectedSlice: selectedSlice,
                sceneValues: sceneValues,
                onSceneValuesChanged: onSceneValuesChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: _ObstaclePrefabDisplayPanel(
            prefabSlices: prefabSlices,
            obstaclePrefabs: obstaclePrefabs,
            editingObstaclePrefab: editingObstaclePrefab,
            workspaceRootPath: workspaceRootPath,
            onLoadPrefab: onLoadPrefab,
            onDeletePrefab: onDeletePrefab,
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
    required this.onStartNewFromCurrentValues,
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
  final VoidCallback onStartNewFromCurrentValues;
  final VoidCallback onClearForm;

  @override
  Widget build(BuildContext context) {
    final hasObstacleSources = prefabSlices.isNotEmpty;
    final isEditingObstaclePrefab = editingObstaclePrefab != null;
    final theme = Theme.of(context);
    final modeBannerColor = isEditingObstaclePrefab
        ? const Color(0x1429C98E)
        : const Color(0x143A8DFF);
    final modeBannerTitle = isEditingObstaclePrefab
        ? 'Editing obstacle prefab "${editingObstaclePrefab!.id}"'
        : 'Creating new obstacle prefab';
    final modeBannerDetails = isEditingObstaclePrefab
        ? 'key=${editingObstaclePrefab!.prefabKey} '
              'rev=${editingObstaclePrefab!.revision} '
              'status=${editingObstaclePrefab!.status.jsonValue}'
        : 'Saving will create a new prefab from the current values.';

    return Card(
      key: const ValueKey<String>('obstacle_prefab_inspector_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selector / Inspector',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                key: const ValueKey<String>('obstacle_prefab_mode_banner'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: modeBannerColor,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modeBannerTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(modeBannerDetails),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
                    key: const ValueKey<String>(
                      'obstacle_prefab_upsert_button',
                    ),
                    onPressed: onUpsertPrefab,
                    icon: Icon(
                      isEditingObstaclePrefab
                          ? Icons.save_outlined
                          : Icons.add_box_outlined,
                    ),
                    label: Text(
                      isEditingObstaclePrefab
                          ? 'Update Prefab'
                          : 'Create Prefab',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey<String>(
                      'obstacle_prefab_new_from_current_values_button',
                    ),
                    onPressed: isEditingObstaclePrefab
                        ? onStartNewFromCurrentValues
                        : null,
                    icon: const Icon(Icons.post_add_outlined),
                    label: const Text('New From Current Values'),
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
      ),
    );
  }
}

class _ObstaclePrefabDisplayPanel extends StatefulWidget {
  const _ObstaclePrefabDisplayPanel({
    required this.prefabSlices,
    required this.obstaclePrefabs,
    required this.editingObstaclePrefab,
    required this.workspaceRootPath,
    required this.onLoadPrefab,
    required this.onDeletePrefab,
  });

  final List<AtlasSliceDef> prefabSlices;
  final List<PrefabDef> obstaclePrefabs;
  final PrefabDef? editingObstaclePrefab;
  final String workspaceRootPath;
  final ValueChanged<PrefabDef> onLoadPrefab;
  final ValueChanged<String> onDeletePrefab;

  @override
  State<_ObstaclePrefabDisplayPanel> createState() =>
      _ObstaclePrefabDisplayPanelState();
}

class _ObstaclePrefabDisplayPanelState
    extends State<_ObstaclePrefabDisplayPanel> {
  final EditorUiImageCache _previewImageCache = EditorUiImageCache();

  @override
  void dispose() {
    _previewImageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slicesById = <String, AtlasSliceDef>{
      for (final slice in widget.prefabSlices) slice.id: slice,
    };
    return Card(
      key: const ValueKey<String>('obstacle_prefab_display_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Obstacle Prefab List',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Editing Prefab: ${widget.editingObstaclePrefab?.id ?? 'none'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.obstaclePrefabs.isEmpty
                  ? const Center(child: Text('No obstacle prefabs yet.'))
                  : ListView.builder(
                      itemCount: widget.obstaclePrefabs.length,
                      itemBuilder: (context, index) {
                        final prefab = widget.obstaclePrefabs[index];
                        final slice = slicesById[prefab.sliceId];
                        final isEditing =
                            widget.editingObstaclePrefab?.prefabKey ==
                            prefab.prefabKey;
                        return Card(
                          key: ValueKey<String>(
                            'obstacle_prefab_row_${prefab.id}',
                          ),
                          clipBehavior: Clip.antiAlias,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => widget.onLoadPrefab(prefab),
                            child: Ink(
                              color: isEditing ? const Color(0x1829C98E) : null,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            prefab.id,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall?.copyWith(
                                              fontWeight: isEditing
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'key=${prefab.prefabKey} '
                                            'rev=${prefab.revision} '
                                            'status=${prefab.status.jsonValue}',
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'source=atlas_slice:${prefab.sliceId}',
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'anchor=(${prefab.anchorXPx},${prefab.anchorYPx}) '
                                            'colliders=${prefab.colliders.length} '
                                            'z=${prefab.zIndex} '
                                            'snap=${prefab.snapToGrid}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    AtlasSlicePreviewTile(
                                      key: ValueKey<String>(
                                        'obstacle_prefab_preview_${prefab.id}',
                                      ),
                                      imageCache: _previewImageCache,
                                      workspaceRootPath:
                                          widget.workspaceRootPath,
                                      slice: slice,
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          widget.onDeletePrefab(prefab.id),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Anchor/collider fields contain invalid values. '
            'Fix them to enable scene editing.',
          ),
        ),
      );
    }

    if (selectedSlice == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Select a prefab slice to edit anchor/collider visually.',
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: PrefabSceneView(
        workspaceRootPath: workspaceRootPath,
        slice: selectedSlice!,
        values: sceneValues!,
        onChanged: onSceneValuesChanged,
        showCardFrame: false,
      ),
    );
  }
}
