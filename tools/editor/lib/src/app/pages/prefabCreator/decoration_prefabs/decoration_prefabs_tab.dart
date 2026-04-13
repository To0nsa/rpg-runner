import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../../shared/atlas_slice_preview_tile.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../obstacle_prefabs/widgets/prefab_scene_view.dart';
import '../shared/prefab_form_state.dart';
import '../shared/prefab_scene_values.dart';
import '../shared/ui/prefab_editor_action_row.dart';
import '../shared/ui/prefab_editor_atlas_slice_selector.dart';
import '../shared/ui/prefab_editor_delete_button.dart';
import '../shared/ui/prefab_editor_empty_state.dart';
import '../shared/ui/prefab_editor_mode_banner.dart';
import '../shared/ui/prefab_editor_panel_card.dart';
import '../shared/ui/prefab_editor_panel_summary.dart';
import '../shared/ui/prefab_editor_row_metadata.dart';
import '../shared/ui/prefab_editor_scene_header.dart';
import '../shared/ui/prefab_editor_section_card.dart';
import '../shared/ui/prefab_editor_selectable_row_card.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';
import '../shared/ui/prefab_editor_ui_tokens.dart';

/// Decoration-prefab authoring view for atlas-slice-backed prefabs.
///
/// Decoration prefabs keep anchor/tags/source authoring but intentionally do
/// not define colliders.
class DecorationPrefabsTab extends StatelessWidget {
  const DecorationPrefabsTab({
    super.key,
    required this.form,
    required this.prefabSlices,
    required this.selectablePrefabSlices,
    required this.decorationPrefabs,
    required this.selectedSliceId,
    required this.selectedSlice,
    required this.editingDecorationPrefab,
    required this.sceneValues,
    required this.workspaceRootPath,
    required this.onSelectedSliceChanged,
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
  final List<AtlasSliceDef> selectablePrefabSlices;
  final List<PrefabDef> decorationPrefabs;
  final String? selectedSliceId;
  final AtlasSliceDef? selectedSlice;
  final PrefabDef? editingDecorationPrefab;
  final PrefabSceneValues? sceneValues;
  final String workspaceRootPath;
  final ValueChanged<String?> onSelectedSliceChanged;
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
      inspector: _DecorationPrefabInspectorPanel(
        form: form,
        prefabSlices: prefabSlices,
        selectablePrefabSlices: selectablePrefabSlices,
        selectedSliceId: selectedSliceId,
        editingDecorationPrefab: editingDecorationPrefab,
        workspaceRootPath: workspaceRootPath,
        onSelectedSliceChanged: onSelectedSliceChanged,
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
      display: _DecorationPrefabDisplayPanel(
        prefabSlices: prefabSlices,
        decorationPrefabs: decorationPrefabs,
        editingDecorationPrefab: editingDecorationPrefab,
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
        ? 'No decoration slice selected'
        : 'Slice: ${selectedSlice.id}';
    final sceneHeaderSubtitle = selectedSlice == null
        ? 'Select a prefab slice to edit anchor visually.'
        : sceneValues == null
        ? 'Anchor values are invalid. Fix them to enable scene editing.'
        : '${selectedSlice.width}x${selectedSlice.height} px '
              'sprite with editable anchor overlay.';

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('decoration_prefab_scene_card'),
      title: 'Decoration Prefabs View',
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
            child: _DecorationPrefabScenePanel(
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

class _DecorationPrefabInspectorPanel extends StatelessWidget {
  const _DecorationPrefabInspectorPanel({
    required this.form,
    required this.prefabSlices,
    required this.selectablePrefabSlices,
    required this.selectedSliceId,
    required this.editingDecorationPrefab,
    required this.workspaceRootPath,
    required this.onSelectedSliceChanged,
    required this.onUpsertPrefab,
    required this.onDuplicatePrefab,
    required this.onDeprecatePrefab,
    required this.onStartNewFromCurrentValues,
    required this.onClearForm,
  });

  final PrefabFormState form;
  final List<AtlasSliceDef> prefabSlices;
  final List<AtlasSliceDef> selectablePrefabSlices;
  final String? selectedSliceId;
  final PrefabDef? editingDecorationPrefab;
  final String workspaceRootPath;
  final ValueChanged<String?> onSelectedSliceChanged;
  final VoidCallback onUpsertPrefab;
  final VoidCallback onDuplicatePrefab;
  final VoidCallback onDeprecatePrefab;
  final VoidCallback onStartNewFromCurrentValues;
  final VoidCallback onClearForm;

  @override
  Widget build(BuildContext context) {
    final hasDecorationSources = prefabSlices.isNotEmpty;
    final isEditingDecorationPrefab = editingDecorationPrefab != null;
    final modeBannerTitle = isEditingDecorationPrefab
        ? 'Editing decoration prefab "${editingDecorationPrefab!.id}"'
        : 'Creating new decoration prefab';
    final modeBannerDetails = isEditingDecorationPrefab
        ? 'key=${editingDecorationPrefab!.prefabKey} '
              'rev=${editingDecorationPrefab!.revision} '
              'status=${editingDecorationPrefab!.status.jsonValue}'
        : 'Saving will create a new decoration prefab from the current values.';

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('decoration_prefab_inspector_card'),
      title: 'Decoration Prefab Controls',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorModeBanner(
            bannerKey: const ValueKey<String>('decoration_prefab_mode_banner'),
            title: modeBannerTitle,
            details: modeBannerDetails,
            tone: isEditingDecorationPrefab
                ? PrefabEditorModeTone.edit
                : PrefabEditorModeTone.create,
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          if (!hasDecorationSources)
            const Padding(
              padding: EdgeInsets.only(bottom: PrefabEditorUiTokens.controlGap),
              child: Text(
                'No prefab slices yet. Decoration prefabs require atlas slices.',
              ),
            ),
          if (editingDecorationPrefab != null)
            Padding(
              padding: const EdgeInsets.only(
                bottom: PrefabEditorUiTokens.controlGap,
              ),
              child: Text(
                'Editing key=${editingDecorationPrefab!.prefabKey} '
                'rev=${editingDecorationPrefab!.revision} '
                'status=${editingDecorationPrefab!.status.jsonValue}',
              ),
            ),
          PrefabEditorSectionCard(
            title: 'Actions',
            child: PrefabEditorActionRow(
              children: [
                FilledButton.icon(
                  key: const ValueKey<String>(
                    'decoration_prefab_upsert_button',
                  ),
                  onPressed: onUpsertPrefab,
                  icon: Icon(
                    isEditingDecorationPrefab
                        ? Icons.save_outlined
                        : Icons.add_box_outlined,
                  ),
                  label: Text(
                    isEditingDecorationPrefab
                        ? 'Update Prefab'
                        : 'Create Prefab',
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>(
                    'decoration_prefab_new_from_current_values_button',
                  ),
                  onPressed: isEditingDecorationPrefab
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
                  key: const ValueKey<String>(
                    'decoration_prefab_clear_form_button',
                  ),
                  onPressed: onClearForm,
                  icon: const Icon(Icons.clear_outlined),
                  label: const Text('Clear Form'),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          PrefabEditorSectionCard(
            title: 'Prefab ID, Source & Tags',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: form.prefabIdController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Prefab ID',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'use same name as slice',
                  ),
                ),
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
                hasDecorationSources
                    ? PrefabEditorAtlasSliceSelector(
                        fieldKey: const ValueKey<String>(
                          'decoration_prefab_slice_selector',
                        ),
                        optionKeyPrefix: 'decoration_prefab_slice_option',
                        optionPreviewKeyPrefix:
                            'decoration_prefab_slice_option_preview',
                        selectedPreviewKey: const ValueKey<String>(
                          'decoration_prefab_slice_selected_preview',
                        ),
                        slices: selectablePrefabSlices,
                        selectedSliceId: selectedSliceId,
                        onSelectedSliceChanged: onSelectedSliceChanged,
                        workspaceRootPath: workspaceRootPath,
                        labelText: 'Atlas Slice',
                        hintText: 'Search decoration slices by id or tag',
                        emptyStateMessage:
                            'All atlas slices are already used by decoration prefabs.',
                        defaultScopeTags: const <String>['decoration'],
                      )
                    : const Text('Create prefab atlas slices first.'),
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
                TextField(
                  controller: form.tagsController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Tags (comma separated)',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'tags from the name and more',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          PrefabEditorSectionCard(
            title: 'Placement',
            description: 'Decoration prefabs do not define colliders.',
            child: _DecorationAnchorFields(form: form),
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
        ],
      ),
    );
  }
}

class _DecorationAnchorFields extends StatelessWidget {
  const _DecorationAnchorFields({required this.form});

  final PrefabFormState form;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        const SizedBox(width: PrefabEditorUiTokens.controlGap),
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
    );
  }
}

class _DecorationPrefabDisplayPanel extends StatefulWidget {
  const _DecorationPrefabDisplayPanel({
    required this.prefabSlices,
    required this.decorationPrefabs,
    required this.editingDecorationPrefab,
    required this.workspaceRootPath,
    required this.onLoadPrefab,
    required this.onDeletePrefab,
  });

  final List<AtlasSliceDef> prefabSlices;
  final List<PrefabDef> decorationPrefabs;
  final PrefabDef? editingDecorationPrefab;
  final String workspaceRootPath;
  final ValueChanged<PrefabDef> onLoadPrefab;
  final ValueChanged<String> onDeletePrefab;

  @override
  State<_DecorationPrefabDisplayPanel> createState() =>
      _DecorationPrefabDisplayPanelState();
}

class _DecorationPrefabDisplayPanelState
    extends State<_DecorationPrefabDisplayPanel> {
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
      cardKey: const ValueKey<String>('decoration_prefab_display_card'),
      title: 'Decoration Prefabs',
      expandBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorPanelSummary(
            secondaryText:
                'Editing Prefab: ${widget.editingDecorationPrefab?.id ?? 'none'}',
          ),
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          Expanded(
            child: widget.decorationPrefabs.isEmpty
                ? const PrefabEditorEmptyState(
                    message: 'No decoration prefabs yet.',
                  )
                : ListView.builder(
                    itemCount: widget.decorationPrefabs.length,
                    itemBuilder: (context, index) {
                      final prefab = widget.decorationPrefabs[index];
                      final slice = slicesById[prefab.sliceId];
                      final isEditing =
                          widget.editingDecorationPrefab?.prefabKey ==
                          prefab.prefabKey;
                      return PrefabEditorSelectableRowCard(
                        key: ValueKey<String>(
                          'decoration_prefab_row_${prefab.id}',
                        ),
                        isSelected: isEditing,
                        onTap: () => widget.onLoadPrefab(prefab),
                        preview: AtlasSlicePreviewTile(
                          key: ValueKey<String>(
                            'decoration_prefab_preview_${prefab.id}',
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
                                'colliders=${prefab.colliders.length}',
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

class _DecorationPrefabScenePanel extends StatelessWidget {
  const _DecorationPrefabScenePanel({
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
            'Anchor fields contain invalid values. Fix them to enable scene editing.',
      );
    }

    if (selectedSlice == null) {
      return const PrefabEditorEmptyState(
        message: 'Select a prefab slice to edit anchor visually.',
      );
    }

    return SizedBox.expand(
      child: PrefabSceneView(
        workspaceRootPath: workspaceRootPath,
        slice: selectedSlice!,
        values: sceneValues!,
        onChanged: onSceneValuesChanged,
        showCardFrame: false,
        showColliderOverlay: false,
      ),
    );
  }
}
