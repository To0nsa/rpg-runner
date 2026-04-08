import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../platform_prefabs/platform_prefab_output_panel.dart';
import '../shared/prefab_form_state.dart';
import '../shared/prefab_scene_values.dart';
import 'widgets/platform_module_scene_view.dart';

/// Platform-module editing view and platform-prefab output controls.
class PlatformModulesTab extends StatelessWidget {
  const PlatformModulesTab({
    super.key,
    required this.moduleIdController,
    required this.moduleTileSizeController,
    required this.modules,
    required this.selectedModuleId,
    required this.selectedModule,
    required this.tileSlices,
    required this.selectedTileSliceId,
    required this.selectedModuleSceneTool,
    required this.sceneValues,
    required this.workspaceRootPath,
    required this.platformPrefabForm,
    required this.onUpsertModule,
    required this.onRenameSelectedModule,
    required this.onDuplicateSelectedModule,
    required this.onToggleDeprecateSelectedModule,
    required this.onSelectedModuleChanged,
    required this.onSelectedTileSliceChanged,
    required this.onPlatformPrefabSnapToGridChanged,
    required this.onPlatformPrefabLoad,
    required this.onPlatformPrefabUpsert,
    required this.onPlatformPrefabSceneValuesChanged,
    required this.onModuleSceneToolChanged,
    required this.onPaintCell,
    required this.onEraseCell,
    required this.onMoveCell,
    required this.onDeleteModule,
    required this.onDeleteModuleCell,
  });

  final TextEditingController moduleIdController;
  final TextEditingController moduleTileSizeController;
  final List<TileModuleDef> modules;
  final String? selectedModuleId;
  final TileModuleDef? selectedModule;
  final List<AtlasSliceDef> tileSlices;
  final String? selectedTileSliceId;
  final PlatformModuleSceneTool selectedModuleSceneTool;
  final PrefabSceneValues? sceneValues;
  final String workspaceRootPath;
  final PrefabFormState platformPrefabForm;
  final VoidCallback onUpsertModule;
  final VoidCallback onRenameSelectedModule;
  final VoidCallback onDuplicateSelectedModule;
  final VoidCallback onToggleDeprecateSelectedModule;
  final ValueChanged<String?> onSelectedModuleChanged;
  final ValueChanged<String> onSelectedTileSliceChanged;
  final ValueChanged<bool> onPlatformPrefabSnapToGridChanged;
  final VoidCallback onPlatformPrefabLoad;
  final VoidCallback onPlatformPrefabUpsert;
  final ValueChanged<PrefabSceneValues> onPlatformPrefabSceneValuesChanged;
  final ValueChanged<PlatformModuleSceneTool> onModuleSceneToolChanged;
  final void Function(int gridX, int gridY, String sliceId) onPaintCell;
  final void Function(int gridX, int gridY) onEraseCell;
  final void Function(
    int sourceGridX,
    int sourceGridY,
    int targetGridX,
    int targetGridY,
  )
  onMoveCell;
  final ValueChanged<String> onDeleteModule;
  final void Function(String moduleId, int cellIndex) onDeleteModuleCell;

  @override
  Widget build(BuildContext context) {
    final isSelectedDeprecated =
        selectedModule?.status == TileModuleStatus.deprecated;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: ExpansionTile(
                    key: const ValueKey<String>(
                      'platform_module_advanced_controls',
                    ),
                    initiallyExpanded: false,
                    title: const Text('Advanced Module Controls'),
                    subtitle: const Text(
                      'Create, rename, duplicate, deprecate, and select modules.',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      TextField(
                        controller: moduleIdController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Platform Module ID',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: moduleTileSizeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Tile Size (px)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: onUpsertModule,
                            icon: const Icon(Icons.add_box_outlined),
                            label: const Text('Add/Update Module'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onRenameSelectedModule,
                            icon: const Icon(Icons.drive_file_rename_outline),
                            label: const Text('Rename'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onDuplicateSelectedModule,
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('Duplicate'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onToggleDeprecateSelectedModule,
                            icon: Icon(
                              isSelectedDeprecated
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                            ),
                            label: Text(
                              isSelectedDeprecated ? 'Reactivate' : 'Deprecate',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String?>(
                          'module_${selectedModuleId ?? 'none'}',
                        ),
                        initialValue: selectedModuleId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Edit Module',
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
                        onChanged: onSelectedModuleChanged,
                      ),
                      if (selectedModule != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Selected: key=${selectedModule!.id} '
                          'rev=${selectedModule!.revision} '
                          'status=${selectedModule!.status.jsonValue}',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tile Slice Palette',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (tileSlices.isEmpty)
                  const Text(
                    'No tile slices yet. Create tile slices in Atlas Slicer first.',
                  )
                else
                  _TileSlicePalette(
                    tileSlices: tileSlices,
                    selectedTileSliceId: selectedTileSliceId,
                    onSelectedTileSliceChanged: onSelectedTileSliceChanged,
                  ),
                const SizedBox(height: 16),
                PlatformPrefabOutputPanel(
                  form: platformPrefabForm,
                  isEnabled: selectedModule != null,
                  sceneValues: sceneValues,
                  onLoadPrefabForModule: onPlatformPrefabLoad,
                  onUpsertPrefabForModule: onPlatformPrefabUpsert,
                  onSnapToGridChanged: onPlatformPrefabSnapToGridChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: selectedModule == null
                    ? const Card(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Select or create a module to edit it.',
                            ),
                          ),
                        ),
                      )
                    : PlatformModuleSceneView(
                        workspaceRootPath: workspaceRootPath,
                        module: selectedModule!,
                        tileSlices: tileSlices,
                        tool: selectedModuleSceneTool,
                        selectedTileSliceId: selectedTileSliceId,
                        overlayValues: sceneValues,
                        onOverlayValuesChanged:
                            onPlatformPrefabSceneValuesChanged,
                        onToolChanged: onModuleSceneToolChanged,
                        onPaintCell: onPaintCell,
                        onEraseCell: onEraseCell,
                        onMoveCell: onMoveCell,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                'Platform Modules',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 2,
                child: modules.isEmpty
                    ? const Text('No platform modules yet.')
                    : ListView.builder(
                        itemCount: modules.length,
                        itemBuilder: (context, index) {
                          final module = modules[index];
                          return Card(
                            child: ExpansionTile(
                              title: Text(module.id),
                              subtitle: Text(
                                'status=${module.status.jsonValue} '
                                'rev=${module.revision} '
                                'tileSize=${module.tileSize} '
                                'cells=${module.cells.length}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => onDeleteModule(module.id),
                              ),
                              children: [
                                if (module.cells.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('No cells yet.'),
                                    ),
                                  ),
                                for (var i = 0; i < module.cells.length; i += 1)
                                  ListTile(
                                    dense: true,
                                    title: Text(module.cells[i].sliceId),
                                    subtitle: Text(
                                      'x=${module.cells[i].gridX} y=${module.cells[i].gridY}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          onDeleteModuleCell(module.id, i),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TileSlicePalette extends StatelessWidget {
  const _TileSlicePalette({
    required this.tileSlices,
    required this.selectedTileSliceId,
    required this.onSelectedTileSliceChanged,
  });

  final List<AtlasSliceDef> tileSlices;
  final String? selectedTileSliceId;
  final ValueChanged<String> onSelectedTileSliceChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final slice in tileSlices)
          ChoiceChip(
            label: Text('${slice.id} (${slice.width}x${slice.height})'),
            selected: selectedTileSliceId == slice.id,
            onSelected: (selected) {
              if (!selected) {
                return;
              }
              onSelectedTileSliceChanged(slice.id);
            },
          ),
      ],
    );
  }
}
