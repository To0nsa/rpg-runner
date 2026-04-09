import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../platform_modules/widgets/platform_module_scene_view.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/platform_module_preview_tile.dart';
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: _PlatformPrefabInspectorPanel(
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
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Card(
            key: const ValueKey<String>('platform_prefab_scene_card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _PlatformPrefabScenePanel(
                workspaceRootPath: workspaceRootPath,
                selectedModule: selectedModule,
                tileSlices: tileSlices,
                sceneValues: sceneValues,
                onSceneValuesChanged: onSceneValuesChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: _PlatformPrefabDisplayPanel(
            modules: modules,
            tileSlices: tileSlices,
            platformPrefabs: platformPrefabs,
            editingPlatformPrefab: editingPlatformPrefab,
            workspaceRootPath: workspaceRootPath,
            onLoadPrefab: onLoadPrefab,
            onDeletePrefab: onDeletePrefab,
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    final modeBannerColor = isEditingPlatformPrefab
        ? const Color(0x1429C98E)
        : const Color(0x143A8DFF);
    final modeBannerTitle = isEditingPlatformPrefab
        ? 'Editing platform prefab "${editingPlatformPrefab!.id}"'
        : 'Creating new platform prefab';
    final modeBannerDetails = isEditingPlatformPrefab
        ? 'key=${editingPlatformPrefab!.prefabKey} '
              'rev=${editingPlatformPrefab!.revision} '
              'status=${editingPlatformPrefab!.status.jsonValue}'
        : 'Saving will create a new prefab from the current values.';

    return Card(
      key: const ValueKey<String>('platform_prefab_inspector_card'),
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
                key: const ValueKey<String>('platform_prefab_mode_banner'),
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
                    Text(modeBannerTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(modeBannerDetails),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (!hasModules)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No platform modules yet. Create one in Platform Modules first.',
                  ),
                ),
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
                const SizedBox(height: 8),
                Text(
                  'Selected module: ${selectedModule!.id} '
                  '(tileSize=${selectedModule!.tileSize} '
                  'cells=${selectedModule!.cells.length} '
                  'status=${selectedModule!.status.jsonValue})',
                ),
              ],
              const SizedBox(height: 12),
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
        ),
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

    return Card(
      key: const ValueKey<String>('platform_prefab_display_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Prefab List',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Editing Prefab: ${widget.editingPlatformPrefab?.id ?? 'none'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.platformPrefabs.isEmpty
                  ? const Center(child: Text('No platform prefabs yet.'))
                  : ListView.builder(
                      itemCount: widget.platformPrefabs.length,
                      itemBuilder: (context, index) {
                        final prefab = widget.platformPrefabs[index];
                        final module = modulesById[prefab.moduleId];
                        final isEditing =
                            widget.editingPlatformPrefab?.prefabKey ==
                            prefab.prefabKey;
                        return Card(
                          key: ValueKey<String>(
                            'platform_prefab_row_${prefab.id}',
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
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
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
                                            'source=platform_module:${prefab.moduleId} '
                                            'moduleCells=${module?.cells.length ?? 0} '
                                            'tileSize=${module?.tileSize ?? '-'}',
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
                                    PlatformModulePreviewTile(
                                      key: ValueKey<String>(
                                        'platform_prefab_preview_${prefab.id}',
                                      ),
                                      imageCache: _previewImageCache,
                                      workspaceRootPath:
                                          widget.workspaceRootPath,
                                      module: module,
                                      tileSlicesById: tileSlicesById,
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Select a platform module to preview and edit prefab anchor/collider values.',
          ),
        ),
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
