import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/platform_module_preview_tile.dart';
import 'widgets/platform_module_scene_view.dart';

/// Platform-module editing view.
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
    required this.workspaceRootPath,
    required this.onUpsertModule,
    required this.onStartNewEmptyModule,
    required this.onRenameSelectedModule,
    required this.onDuplicateSelectedModule,
    required this.onToggleDeprecateSelectedModule,
    required this.onSelectedModuleChanged,
    required this.onSelectedTileSliceChanged,
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
  final String workspaceRootPath;
  final VoidCallback onUpsertModule;
  final VoidCallback onStartNewEmptyModule;
  final VoidCallback onRenameSelectedModule;
  final VoidCallback onDuplicateSelectedModule;
  final VoidCallback onToggleDeprecateSelectedModule;
  final ValueChanged<String?> onSelectedModuleChanged;
  final ValueChanged<String> onSelectedTileSliceChanged;
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: _PlatformModuleInspectorPanel(
            moduleIdController: moduleIdController,
            moduleTileSizeController: moduleTileSizeController,
            modules: modules,
            selectedModule: selectedModule,
            tileSlices: tileSlices,
            selectedTileSliceId: selectedTileSliceId,
            isSelectedDeprecated: isSelectedDeprecated,
            onUpsertModule: onUpsertModule,
            onStartNewEmptyModule: onStartNewEmptyModule,
            onRenameSelectedModule: onRenameSelectedModule,
            onDuplicateSelectedModule: onDuplicateSelectedModule,
            onToggleDeprecateSelectedModule: onToggleDeprecateSelectedModule,
            onSelectedTileSliceChanged: onSelectedTileSliceChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Card(
            key: const ValueKey<String>('platform_module_scene_card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _PlatformModuleScenePanel(
                selectedModule: selectedModule,
                workspaceRootPath: workspaceRootPath,
                tileSlices: tileSlices,
                selectedModuleSceneTool: selectedModuleSceneTool,
                selectedTileSliceId: selectedTileSliceId,
                onModuleSceneToolChanged: onModuleSceneToolChanged,
                onPaintCell: onPaintCell,
                onEraseCell: onEraseCell,
                onMoveCell: onMoveCell,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: _PlatformModuleDisplayPanel(
            modules: modules,
            tileSlices: tileSlices,
            selectedModuleId: selectedModuleId,
            workspaceRootPath: workspaceRootPath,
            onSelectedModuleChanged: onSelectedModuleChanged,
            onDeleteModule: onDeleteModule,
            onDeleteModuleCell: onDeleteModuleCell,
          ),
        ),
      ],
    );
  }
}

class _PlatformModuleInspectorPanel extends StatelessWidget {
  const _PlatformModuleInspectorPanel({
    required this.moduleIdController,
    required this.moduleTileSizeController,
    required this.modules,
    required this.selectedModule,
    required this.tileSlices,
    required this.selectedTileSliceId,
    required this.isSelectedDeprecated,
    required this.onUpsertModule,
    required this.onStartNewEmptyModule,
    required this.onRenameSelectedModule,
    required this.onDuplicateSelectedModule,
    required this.onToggleDeprecateSelectedModule,
    required this.onSelectedTileSliceChanged,
  });

  final TextEditingController moduleIdController;
  final TextEditingController moduleTileSizeController;
  final List<TileModuleDef> modules;
  final TileModuleDef? selectedModule;
  final List<AtlasSliceDef> tileSlices;
  final String? selectedTileSliceId;
  final bool isSelectedDeprecated;
  final VoidCallback onUpsertModule;
  final VoidCallback onStartNewEmptyModule;
  final VoidCallback onRenameSelectedModule;
  final VoidCallback onDuplicateSelectedModule;
  final VoidCallback onToggleDeprecateSelectedModule;
  final ValueChanged<String> onSelectedTileSliceChanged;

  @override
  Widget build(BuildContext context) {
    TileModuleDef? draftTargetModule() {
      final draftId = moduleIdController.text.trim();
      if (draftId.isEmpty) {
        return null;
      }
      for (final module in modules) {
        if (module.id == draftId) {
          return module;
        }
      }
      return null;
    }

    return Card(
      key: const ValueKey<String>('platform_module_inspector_card'),
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
              ListenableBuilder(
                listenable: moduleIdController,
                builder: (context, _) {
                  final theme = Theme.of(context);
                  final editingModule = draftTargetModule();
                  final isEditingExistingModule = editingModule != null;
                  final modeBannerColor = isEditingExistingModule
                      ? const Color(0x1429C98E)
                      : const Color(0x143A8DFF);
                  final modeBannerTitle = isEditingExistingModule
                      ? 'Editing platform module "${editingModule.id}"'
                      : 'Creating new platform module';
                  final modeBannerDetails = isEditingExistingModule
                      ? 'rev=${editingModule.revision} '
                            'status=${editingModule.status.jsonValue} '
                            'tileSize=${editingModule.tileSize} '
                            'cells=${editingModule.cells.length}'
                      : 'Saving will create a new empty module for the current ID.';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        key: const ValueKey<String>(
                          'platform_module_mode_banner',
                        ),
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: modeBannerColor,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
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
                    ],
                  );
                },
              ),
              Container(
                key: const ValueKey<String>(
                  'platform_module_advanced_controls',
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Advanced Module Controls',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Create, rename, duplicate, deprecate, and select modules.',
                    ),
                    const SizedBox(height: 12),
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
                    ListenableBuilder(
                      listenable: moduleIdController,
                      builder: (context, _) {
                        final isEditingExistingModule =
                            draftTargetModule() != null;

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              key: const ValueKey<String>(
                                'platform_module_upsert_button',
                              ),
                              onPressed: onUpsertModule,
                              icon: Icon(
                                isEditingExistingModule
                                    ? Icons.save_outlined
                                    : Icons.add_box_outlined,
                              ),
                              label: Text(
                                isEditingExistingModule
                                    ? 'Update Module'
                                    : 'Create Module',
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const ValueKey<String>(
                                'platform_module_new_empty_button',
                              ),
                              onPressed: onStartNewEmptyModule,
                              icon: const Icon(Icons.post_add_outlined),
                              label: const Text('New Empty Module'),
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
                                isSelectedDeprecated
                                    ? 'Reactivate'
                                    : 'Deprecate',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      selectedModule == null
                          ? 'Select a module from the list to edit it.'
                          : 'Selected: key=${selectedModule!.id} '
                                'rev=${selectedModule!.revision} '
                                'status=${selectedModule!.status.jsonValue}',
                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformModuleScenePanel extends StatelessWidget {
  const _PlatformModuleScenePanel({
    required this.selectedModule,
    required this.workspaceRootPath,
    required this.tileSlices,
    required this.selectedModuleSceneTool,
    required this.selectedTileSliceId,
    required this.onModuleSceneToolChanged,
    required this.onPaintCell,
    required this.onEraseCell,
    required this.onMoveCell,
  });

  final TileModuleDef? selectedModule;
  final String workspaceRootPath;
  final List<AtlasSliceDef> tileSlices;
  final PlatformModuleSceneTool selectedModuleSceneTool;
  final String? selectedTileSliceId;
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

  @override
  Widget build(BuildContext context) {
    if (selectedModule == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Select or create a module to edit it.'),
        ),
      );
    }

    return PlatformModuleSceneView(
      workspaceRootPath: workspaceRootPath,
      module: selectedModule!,
      tileSlices: tileSlices,
      tool: selectedModuleSceneTool,
      selectedTileSliceId: selectedTileSliceId,
      onToolChanged: onModuleSceneToolChanged,
      onPaintCell: onPaintCell,
      onEraseCell: onEraseCell,
      onMoveCell: onMoveCell,
    );
  }
}

class _PlatformModuleDisplayPanel extends StatefulWidget {
  const _PlatformModuleDisplayPanel({
    required this.modules,
    required this.tileSlices,
    required this.selectedModuleId,
    required this.workspaceRootPath,
    required this.onSelectedModuleChanged,
    required this.onDeleteModule,
    required this.onDeleteModuleCell,
  });

  final List<TileModuleDef> modules;
  final List<AtlasSliceDef> tileSlices;
  final String? selectedModuleId;
  final String workspaceRootPath;
  final ValueChanged<String?> onSelectedModuleChanged;
  final ValueChanged<String> onDeleteModule;
  final void Function(String moduleId, int cellIndex) onDeleteModuleCell;

  @override
  State<_PlatformModuleDisplayPanel> createState() =>
      _PlatformModuleDisplayPanelState();
}

class _PlatformModuleDisplayPanelState
    extends State<_PlatformModuleDisplayPanel> {
  final EditorUiImageCache _previewImageCache = EditorUiImageCache();

  @override
  void dispose() {
    _previewImageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tileSlicesById = <String, AtlasSliceDef>{
      for (final slice in widget.tileSlices) slice.id: slice,
    };

    return Card(
      key: const ValueKey<String>('platform_module_display_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Modules',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Selected Module: ${widget.selectedModuleId ?? 'none'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.modules.isEmpty
                  ? const Center(child: Text('No platform modules yet.'))
                  : ListView.builder(
                      itemCount: widget.modules.length,
                      itemBuilder: (context, index) {
                        final module = widget.modules[index];
                        final isSelected = widget.selectedModuleId == module.id;
                        return Card(
                          key: ValueKey<String>(
                            'platform_module_row_${module.id}',
                          ),
                          clipBehavior: Clip.antiAlias,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () =>
                                widget.onSelectedModuleChanged(module.id),
                            child: Ink(
                              color: isSelected
                                  ? const Color(0x1829C98E)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                module.id,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight: isSelected
                                                          ? FontWeight.w700
                                                          : FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'status=${module.status.jsonValue} '
                                                'rev=${module.revision} '
                                                'tileSize=${module.tileSize} '
                                                'cells=${module.cells.length}',
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                module.cells.isEmpty
                                                    ? 'No components yet.'
                                                    : 'Tap to edit and expand components.',
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        PlatformModulePreviewTile(
                                          key: ValueKey<String>(
                                            'platform_module_preview_${module.id}',
                                          ),
                                          imageCache: _previewImageCache,
                                          workspaceRootPath:
                                              widget.workspaceRootPath,
                                          module: module,
                                          tileSlicesById: tileSlicesById,
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () =>
                                              widget.onDeleteModule(module.id),
                                        ),
                                      ],
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(height: 8),
                                      if (module.cells.isEmpty)
                                        const Text('No cells yet.')
                                      else
                                        for (
                                          var i = 0;
                                          i < module.cells.length;
                                          i += 1
                                        )
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            title: Text(
                                              module.cells[i].sliceId,
                                            ),
                                            subtitle: Text(
                                              'x=${module.cells[i].gridX} '
                                              'y=${module.cells[i].gridY}',
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              onPressed: () =>
                                                  widget.onDeleteModuleCell(
                                                    module.id,
                                                    i,
                                                  ),
                                            ),
                                          ),
                                    ],
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
