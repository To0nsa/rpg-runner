import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../platform_modules/widgets/platform_module_scene_view.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/platform_module_preview_tile.dart';
import '../shared/ui/prefab_editor_empty_state.dart';
import '../shared/ui/prefab_editor_delete_button.dart';
import '../shared/ui/prefab_editor_mode_banner.dart';
import '../shared/ui/prefab_editor_panel_card.dart';
import '../shared/ui/prefab_editor_panel_summary.dart';
import '../shared/ui/prefab_editor_row_metadata.dart';
import '../shared/ui/prefab_editor_scene_header.dart';
import '../shared/ui/prefab_editor_selectable_row_card.dart';
import '../shared/ui/prefab_editor_section_card.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';
import '../shared/ui/prefab_editor_ui_tokens.dart';
import '../shared/prefab_form_state.dart';
import '../shared/prefab_scene_values.dart';
import 'platform_prefab_output_panel.dart';

/// Platform-prefab authoring view separated from platform-module editing.
class PlatformPrefabsTab extends StatelessWidget {
  const PlatformPrefabsTab({
    super.key,
    required this.form,
    required this.modules,
    required this.selectedModuleId,
    required this.selectedModule,
    required this.tileSlices,
    required this.platformPrefabs,
    required this.editingPlatformPrefab,
    required this.sceneValues,
    required this.workspaceRootPath,
    required this.onSelectedModuleChanged,
    required this.onSnapToGridChanged,
    required this.onLoadPrefabForModule,
    required this.onUpsertPrefabForModule,
    required this.onStartNewFromCurrentValues,
    required this.onSceneValuesChanged,
    required this.onLoadPrefab,
    required this.onDeletePrefab,
  });

  final PrefabFormState form;
  final List<TileModuleDef> modules;
  final String? selectedModuleId;
  final TileModuleDef? selectedModule;
  final List<AtlasSliceDef> tileSlices;
  final List<PrefabDef> platformPrefabs;
  final PrefabDef? editingPlatformPrefab;
  final PrefabSceneValues? sceneValues;
  final String workspaceRootPath;
  final ValueChanged<String?> onSelectedModuleChanged;
  final ValueChanged<bool> onSnapToGridChanged;
  final VoidCallback onLoadPrefabForModule;
  final VoidCallback onUpsertPrefabForModule;
  final VoidCallback onStartNewFromCurrentValues;
  final ValueChanged<PrefabSceneValues> onSceneValuesChanged;
  final ValueChanged<PrefabDef> onLoadPrefab;
  final ValueChanged<String> onDeletePrefab;

  @override
  Widget build(BuildContext context) {
    return PrefabEditorThreePanelLayout(
      inspector: _PlatformPrefabInspectorPanel(
        form: form,
        modules: modules,
        selectedModuleId: selectedModuleId,
        selectedModule: selectedModule,
        editingPlatformPrefab: editingPlatformPrefab,
        sceneValues: sceneValues,
        onSelectedModuleChanged: onSelectedModuleChanged,
        onSnapToGridChanged: onSnapToGridChanged,
        onLoadPrefabForModule: onLoadPrefabForModule,
        onUpsertPrefabForModule: onUpsertPrefabForModule,
        onStartNewFromCurrentValues: onStartNewFromCurrentValues,
      ),
      scene: _buildSceneCard(
        workspaceRootPath: workspaceRootPath,
        selectedModule: selectedModule,
        tileSlices: tileSlices,
        sceneValues: sceneValues,
        onSceneValuesChanged: onSceneValuesChanged,
      ),
      display: _PlatformPrefabDisplayPanel(
        modules: modules,
        tileSlices: tileSlices,
        platformPrefabs: platformPrefabs,
        editingPlatformPrefab: editingPlatformPrefab,
        workspaceRootPath: workspaceRootPath,
        onLoadPrefab: onLoadPrefab,
        onDeletePrefab: onDeletePrefab,
      ),
    );
  }

  Widget _buildSceneCard({
    required String workspaceRootPath,
    required TileModuleDef? selectedModule,
    required List<AtlasSliceDef> tileSlices,
    required PrefabSceneValues? sceneValues,
    required ValueChanged<PrefabSceneValues> onSceneValuesChanged,
  }) {
    final sceneHeaderTitle = selectedModule == null
        ? 'No backing module selected'
        : 'Module: ${selectedModule.id}';
    final sceneHeaderSubtitle = selectedModule == null
        ? 'Select a platform module to preview prefab anchor/collider values.'
        : sceneValues == null
        ? 'Anchor/collider values are invalid. Fix them to enable overlay editing.'
        : 'cells=${selectedModule.cells.length} '
              'tileSize=${selectedModule.tileSize} '
              'prefab overlay preview';

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('platform_prefab_scene_card'),
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
            child: _PlatformPrefabScenePanel(
              workspaceRootPath: workspaceRootPath,
              selectedModule: selectedModule,
              tileSlices: tileSlices,
              sceneValues: sceneValues,
              onSceneValuesChanged: onSceneValuesChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformPrefabInspectorPanel extends StatelessWidget {
  const _PlatformPrefabInspectorPanel({
    required this.form,
    required this.modules,
    required this.selectedModuleId,
    required this.selectedModule,
    required this.editingPlatformPrefab,
    required this.sceneValues,
    required this.onSelectedModuleChanged,
    required this.onSnapToGridChanged,
    required this.onLoadPrefabForModule,
    required this.onUpsertPrefabForModule,
    required this.onStartNewFromCurrentValues,
  });

  final PrefabFormState form;
  final List<TileModuleDef> modules;
  final String? selectedModuleId;
  final TileModuleDef? selectedModule;
  final PrefabDef? editingPlatformPrefab;
  final PrefabSceneValues? sceneValues;
  final ValueChanged<String?> onSelectedModuleChanged;
  final ValueChanged<bool> onSnapToGridChanged;
  final VoidCallback onLoadPrefabForModule;
  final VoidCallback onUpsertPrefabForModule;
  final VoidCallback onStartNewFromCurrentValues;

  @override
  Widget build(BuildContext context) {
    final hasModules = modules.isNotEmpty;
    final isEditingPlatformPrefab = editingPlatformPrefab != null;
    final modeBannerTitle = isEditingPlatformPrefab
        ? 'Editing platform prefab "${editingPlatformPrefab!.id}"'
        : 'Creating new platform prefab';
    final modeBannerDetails = isEditingPlatformPrefab
        ? 'key=${editingPlatformPrefab!.prefabKey} '
              'rev=${editingPlatformPrefab!.revision} '
              'status=${editingPlatformPrefab!.status.jsonValue}'
        : 'Saving will create a new prefab from the current values.';

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('platform_prefab_inspector_card'),
      title: 'Inspector',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorModeBanner(
            bannerKey: const ValueKey<String>('platform_prefab_mode_banner'),
            title: modeBannerTitle,
            details: modeBannerDetails,
            tone: isEditingPlatformPrefab
                ? PrefabEditorModeTone.edit
                : PrefabEditorModeTone.create,
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          if (!hasModules)
            const Padding(
              padding: EdgeInsets.only(bottom: PrefabEditorUiTokens.controlGap),
              child: Text(
                'No platform modules yet. Create one in Platform Modules first.',
              ),
            ),
          PrefabEditorSectionCard(
            title: 'Backing Module',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>(
                    'platform_prefab_module_${selectedModuleId ?? 'none'}',
                  ),
                  initialValue: selectedModuleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Backing Module',
                  ),
                  items: [
                    for (final module in modules)
                      DropdownMenuItem<String>(
                        value: module.id,
                        child: Text(
                          module.status == TileModuleStatus.deprecated
                              ? '${module.id} (deprecated)'
                              : module.id,
                        ),
                      ),
                  ],
                  onChanged: hasModules ? onSelectedModuleChanged : null,
                ),
                if (selectedModule != null) ...[
                  const SizedBox(height: PrefabEditorUiTokens.controlGap),
                  Text(
                    'Selected module: ${selectedModule!.id} '
                    '(tileSize=${selectedModule!.tileSize} '
                    'cells=${selectedModule!.cells.length} '
                    'status=${selectedModule!.status.jsonValue})',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          PlatformPrefabOutputPanel(
            form: form,
            isEnabled: selectedModule != null,
            isEditingPrefab: isEditingPlatformPrefab,
            sceneValues: sceneValues,
            onLoadPrefabForModule: onLoadPrefabForModule,
            onUpsertPrefabForModule: onUpsertPrefabForModule,
            onStartNewFromCurrentValues: onStartNewFromCurrentValues,
            onSnapToGridChanged: onSnapToGridChanged,
          ),
        ],
      ),
    );
  }
}

class _PlatformPrefabDisplayPanel extends StatefulWidget {
  const _PlatformPrefabDisplayPanel({
    required this.modules,
    required this.tileSlices,
    required this.platformPrefabs,
    required this.editingPlatformPrefab,
    required this.workspaceRootPath,
    required this.onLoadPrefab,
    required this.onDeletePrefab,
  });

  final List<TileModuleDef> modules;
  final List<AtlasSliceDef> tileSlices;
  final List<PrefabDef> platformPrefabs;
  final PrefabDef? editingPlatformPrefab;
  final String workspaceRootPath;
  final ValueChanged<PrefabDef> onLoadPrefab;
  final ValueChanged<String> onDeletePrefab;

  @override
  State<_PlatformPrefabDisplayPanel> createState() =>
      _PlatformPrefabDisplayPanelState();
}

class _PlatformPrefabDisplayPanelState
    extends State<_PlatformPrefabDisplayPanel> {
  final EditorUiImageCache _previewImageCache = EditorUiImageCache();

  @override
  void dispose() {
    _previewImageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modulesById = <String, TileModuleDef>{
      for (final module in widget.modules) module.id: module,
    };
    final tileSlicesById = <String, AtlasSliceDef>{
      for (final slice in widget.tileSlices) slice.id: slice,
    };

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('platform_prefab_display_card'),
      title: 'Platform Prefabs',
      expandBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorPanelSummary(
            secondaryText:
                'Editing Prefab: ${widget.editingPlatformPrefab?.id ?? 'none'}',
          ),
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          Expanded(
            child: widget.platformPrefabs.isEmpty
                ? const PrefabEditorEmptyState(
                    message: 'No platform prefabs yet.',
                  )
                : ListView.builder(
                    itemCount: widget.platformPrefabs.length,
                    itemBuilder: (context, index) {
                      final prefab = widget.platformPrefabs[index];
                      final module = modulesById[prefab.moduleId];
                      final isEditing =
                          widget.editingPlatformPrefab?.prefabKey ==
                          prefab.prefabKey;
                      return PrefabEditorSelectableRowCard(
                        key: ValueKey<String>(
                          'platform_prefab_row_${prefab.id}',
                        ),
                        isSelected: isEditing,
                        onTap: () => widget.onLoadPrefab(prefab),
                        preview: PlatformModulePreviewTile(
                          key: ValueKey<String>(
                            'platform_prefab_preview_${prefab.id}',
                          ),
                          imageCache: _previewImageCache,
                          workspaceRootPath: widget.workspaceRootPath,
                          module: module,
                          tileSlicesById: tileSlicesById,
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
                            'source=platform_module:${prefab.moduleId} '
                                'moduleCells=${module?.cells.length ?? 0} '
                                'tileSize=${module?.tileSize ?? '-'}',
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

class _PlatformPrefabScenePanel extends StatelessWidget {
  const _PlatformPrefabScenePanel({
    required this.workspaceRootPath,
    required this.selectedModule,
    required this.tileSlices,
    required this.sceneValues,
    required this.onSceneValuesChanged,
  });

  final String workspaceRootPath;
  final TileModuleDef? selectedModule;
  final List<AtlasSliceDef> tileSlices;
  final PrefabSceneValues? sceneValues;
  final ValueChanged<PrefabSceneValues> onSceneValuesChanged;

  @override
  Widget build(BuildContext context) {
    if (selectedModule == null) {
      return const PrefabEditorEmptyState(
        message:
            'Select a platform module to preview and edit prefab anchor/collider values.',
      );
    }

    return SizedBox.expand(
      child: PlatformModuleSceneView(
        workspaceRootPath: workspaceRootPath,
        module: selectedModule!,
        tileSlices: tileSlices,
        tool: PlatformModuleSceneTool.paint,
        selectedTileSliceId: null,
        allowModuleEditing: false,
        overlayValues: sceneValues,
        onOverlayValuesChanged: onSceneValuesChanged,
        onToolChanged: (_) {},
        onPaintCell: (_, _, _) {},
        onEraseCell: (_, _) {},
        onMoveCell: (_, _, _, _) {},
      ),
    );
  }
}
