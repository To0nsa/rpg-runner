import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../../shared/atlas_slice_preview_tile.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../shared/ui/prefab_editor_action_row.dart';
import '../shared/ui/prefab_editor_delete_button.dart';
import '../shared/ui/prefab_editor_empty_state.dart';
import '../shared/ui/prefab_editor_mode_banner.dart';
import '../shared/ui/prefab_editor_panel_card.dart';
import '../shared/ui/prefab_editor_placement_fields.dart';
import '../shared/ui/prefab_editor_panel_summary.dart';
import '../shared/ui/prefab_editor_row_metadata.dart';
import '../shared/ui/prefab_editor_scene_header.dart';
import '../shared/ui/prefab_editor_section_card.dart';
import '../shared/ui/prefab_editor_selectable_row_card.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';
import '../shared/ui/prefab_editor_ui_tokens.dart';
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
    return PrefabEditorThreePanelLayout(
      inspector: _ObstaclePrefabInspectorPanel(
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
      scene: _buildSceneCard(
        workspaceRootPath: workspaceRootPath,
        selectedSlice: selectedSlice,
        sceneValues: sceneValues,
        onSceneValuesChanged: onSceneValuesChanged,
      ),
      display: _ObstaclePrefabDisplayPanel(
        prefabSlices: prefabSlices,
        obstaclePrefabs: obstaclePrefabs,
        editingObstaclePrefab: editingObstaclePrefab,
        workspaceRootPath: workspaceRootPath,
        onLoadPrefab: onLoadPrefab,
        onDeletePrefab: onDeletePrefab,
      ),
    );
  }

  Widget _buildSceneCard({
    required String workspaceRootPath,
    required AtlasSliceDef? selectedSlice,
    required PrefabSceneValues? sceneValues,
    required ValueChanged<PrefabSceneValues> onSceneValuesChanged,
  }) {
    final sceneHeaderTitle = selectedSlice == null
        ? 'No prefab slice selected'
        : 'Slice: ${selectedSlice.id}';
    final sceneHeaderSubtitle = selectedSlice == null
        ? 'Select a prefab slice to edit anchor/collider visually.'
        : sceneValues == null
        ? 'Anchor/collider values are invalid. Fix them to enable scene editing.'
        : '${selectedSlice.width}x${selectedSlice.height} px '
              'sprite with editable anchor and collider overlays.';

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('obstacle_prefab_scene_card'),
      title: 'Scene View',
      expandBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorSceneHeader(
            title: sceneHeaderTitle,
            subtitle: sceneHeaderSubtitle,
          ),
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          Expanded(
            child: _ObstaclePrefabScenePanel(
              workspaceRootPath: workspaceRootPath,
              selectedSlice: selectedSlice,
              sceneValues: sceneValues,
              onSceneValuesChanged: onSceneValuesChanged,
            ),
          ),
        ],
      ),
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
    final modeBannerTitle = isEditingObstaclePrefab
        ? 'Editing obstacle prefab "${editingObstaclePrefab!.id}"'
        : 'Creating new obstacle prefab';
    final modeBannerDetails = isEditingObstaclePrefab
        ? 'key=${editingObstaclePrefab!.prefabKey} '
              'rev=${editingObstaclePrefab!.revision} '
              'status=${editingObstaclePrefab!.status.jsonValue}'
        : 'Saving will create a new prefab from the current values.';

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('obstacle_prefab_inspector_card'),
      title: 'Inspector',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorModeBanner(
            bannerKey: const ValueKey<String>('obstacle_prefab_mode_banner'),
            title: modeBannerTitle,
            details: modeBannerDetails,
            tone: isEditingObstaclePrefab
                ? PrefabEditorModeTone.edit
                : PrefabEditorModeTone.create,
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          if (!hasObstacleSources)
            const Padding(
              padding: EdgeInsets.only(bottom: PrefabEditorUiTokens.controlGap),
              child: Text(
                'No prefab slices yet. Obstacle prefabs require atlas slices.',
              ),
            ),
          if (editingObstaclePrefab != null)
            Padding(
              padding: const EdgeInsets.only(
                bottom: PrefabEditorUiTokens.controlGap,
              ),
              child: Text(
                'Editing key=${editingObstaclePrefab!.prefabKey} '
                'rev=${editingObstaclePrefab!.revision} '
                'status=${editingObstaclePrefab!.status.jsonValue}',
              ),
            ),
          PrefabEditorSectionCard(
            title: 'Actions',
            child: PrefabEditorActionRow(
              children: [
                FilledButton.icon(
                  key: const ValueKey<String>('obstacle_prefab_upsert_button'),
                  onPressed: onUpsertPrefab,
                  icon: Icon(
                    isEditingObstaclePrefab
                        ? Icons.save_outlined
                        : Icons.add_box_outlined,
                  ),
                  label: Text(
                    isEditingObstaclePrefab ? 'Update Prefab' : 'Create Prefab',
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
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          PrefabEditorSectionCard(
            title: 'Prefab Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: form.prefabIdController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Prefab ID',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
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
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
                TextField(
                  controller: form.tagsController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Tags (comma separated)',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          PrefabEditorSectionCard(
            title: 'Placement & Collider',
            child: PrefabEditorPlacementFields(
              form: form,
              onSnapToGridChanged: onSnapToGridChanged,
              colliderOffsetXLabel: 'Offset X',
              colliderOffsetYLabel: 'Offset Y',
              colliderWidthLabel: 'Width',
              colliderHeightLabel: 'Height',
            ),
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
        ],
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
    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('obstacle_prefab_display_card'),
      title: 'Obstacle Prefabs',
      expandBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorPanelSummary(
            secondaryText:
                'Editing Prefab: ${widget.editingObstaclePrefab?.id ?? 'none'}',
          ),
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          Expanded(
            child: widget.obstaclePrefabs.isEmpty
                ? const PrefabEditorEmptyState(
                    message: 'No obstacle prefabs yet.',
                  )
                : ListView.builder(
                    itemCount: widget.obstaclePrefabs.length,
                    itemBuilder: (context, index) {
                      final prefab = widget.obstaclePrefabs[index];
                      final slice = slicesById[prefab.sliceId];
                      final isEditing =
                          widget.editingObstaclePrefab?.prefabKey ==
                          prefab.prefabKey;
                      return PrefabEditorSelectableRowCard(
                        key: ValueKey<String>(
                          'obstacle_prefab_row_${prefab.id}',
                        ),
                        isSelected: isEditing,
                        onTap: () => widget.onLoadPrefab(prefab),
                        preview: AtlasSlicePreviewTile(
                          key: ValueKey<String>(
                            'obstacle_prefab_preview_${prefab.id}',
                          ),
                          imageCache: _previewImageCache,
                          workspaceRootPath: widget.workspaceRootPath,
                          slice: slice,
                        ),
                        trailing: PrefabEditorDeleteButton(
                          onPressed: () => widget.onDeletePrefab(prefab.id),
                        ),
                        child: PrefabEditorRowMetadata(
                          title: prefab.id,
                          isSelected: isEditing,
                          metadataLines: [
                            'key=${prefab.prefabKey} '
                                'rev=${prefab.revision} '
                                'status=${prefab.status.jsonValue}',
                            'source=atlas_slice:${prefab.sliceId}',
                            'anchor=(${prefab.anchorXPx},${prefab.anchorYPx}) '
                                'colliders=${prefab.colliders.length} '
                                'z=${prefab.zIndex} '
                                'snap=${prefab.snapToGrid}',
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
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
      return const PrefabEditorEmptyState(
        message:
            'Anchor/collider fields contain invalid values. Fix them to enable scene editing.',
      );
    }

    if (selectedSlice == null) {
      return const PrefabEditorEmptyState(
        message: 'Select a prefab slice to edit anchor/collider visually.',
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
