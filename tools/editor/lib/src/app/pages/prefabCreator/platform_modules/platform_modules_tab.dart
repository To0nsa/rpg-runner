import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/platform_module_preview_tile.dart';
import '../shared/ui/prefab_editor_action_row.dart';
import '../shared/ui/prefab_editor_choice_chip_group.dart';
import '../shared/ui/prefab_editor_delete_button.dart';
import '../shared/ui/prefab_editor_empty_state.dart';
import '../shared/ui/prefab_editor_mode_banner.dart';
import '../shared/ui/prefab_editor_panel_card.dart';
import '../shared/ui/prefab_editor_panel_summary.dart';
import '../shared/ui/prefab_editor_row_metadata.dart';
import '../shared/ui/prefab_editor_scene_header.dart';
import '../shared/ui/prefab_editor_selectable_row_card.dart';
import '../shared/ui/prefab_editor_section_card.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';
import '../shared/ui/prefab_editor_ui_tokens.dart';
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

    return PrefabEditorThreePanelLayout(
      inspector: _PlatformModuleInspectorPanel(
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
      scene: _buildSceneCard(
        selectedModule: selectedModule,
        selectedTileSliceId: selectedTileSliceId,
        selectedModuleSceneTool: selectedModuleSceneTool,
        workspaceRootPath: workspaceRootPath,
        tileSlices: tileSlices,
        onModuleSceneToolChanged: onModuleSceneToolChanged,
        onPaintCell: onPaintCell,
        onEraseCell: onEraseCell,
        onMoveCell: onMoveCell,
      ),
      display: _PlatformModuleDisplayPanel(
        modules: modules,
        tileSlices: tileSlices,
        selectedModuleId: selectedModuleId,
        workspaceRootPath: workspaceRootPath,
        onSelectedModuleChanged: onSelectedModuleChanged,
        onDeleteModule: onDeleteModule,
        onDeleteModuleCell: onDeleteModuleCell,
      ),
    );
  }

  Widget _buildSceneCard({
    required TileModuleDef? selectedModule,
    required String? selectedTileSliceId,
    required PlatformModuleSceneTool selectedModuleSceneTool,
    required String workspaceRootPath,
    required List<AtlasSliceDef> tileSlices,
    required ValueChanged<PlatformModuleSceneTool> onModuleSceneToolChanged,
    required void Function(int gridX, int gridY, String sliceId) onPaintCell,
    required void Function(int gridX, int gridY) onEraseCell,
    required void Function(
      int sourceGridX,
      int sourceGridY,
      int targetGridX,
      int targetGridY,
    )
    onMoveCell,
  }) {
    final sceneHeaderTitle = selectedModule == null
        ? 'No module selected'
        : 'Module: ${selectedModule.id}';
    final sceneHeaderSubtitle = selectedModule == null
        ? 'Select or create a module to edit it.'
        : 'cells=${selectedModule.cells.length} '
              'tileSize=${selectedModule.tileSize} '
              'tool=${selectedModuleSceneTool.label} '
              'slice=${selectedTileSliceId ?? 'none'}';

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('platform_module_scene_card'),
      title: 'Platform Module View',
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
        ],
      ),
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

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('platform_module_inspector_card'),
      title: 'Platform Module Controls',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListenableBuilder(
            listenable: moduleIdController,
            builder: (context, _) {
              final editingModule = draftTargetModule();
              final isEditingExistingModule = editingModule != null;
              final modeBannerTitle = isEditingExistingModule
                  ? 'Editing platform module "${editingModule.id}"'
                  : 'Creating new platform module';
              final modeBannerDetails = isEditingExistingModule
                  ? 'rev=${editingModule.revision} '
                        'status=${editingModule.status.jsonValue} '
                        'tileSize=${editingModule.tileSize} '
                        'cells=${editingModule.cells.length}'
                  : 'Saving will create a new empty module for the current ID.';

              return PrefabEditorModeBanner(
                bannerKey: const ValueKey<String>(
                  'platform_module_mode_banner',
                ),
                title: modeBannerTitle,
                details: modeBannerDetails,
                tone: isEditingExistingModule
                    ? PrefabEditorModeTone.edit
                    : PrefabEditorModeTone.create,
              );
            },
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          PrefabEditorSectionCard(
            sectionKey: const ValueKey<String>(
              'platform_module_advanced_controls',
            ),
            title: 'ID, Tile Size & Actions',
            description:
                'Create, rename, duplicate, deprecate, and select modules.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: moduleIdController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Platform Module ID',
                  ),
                ),
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
                TextField(
                  controller: moduleTileSizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Tile Size (px)',
                  ),
                ),
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
                ListenableBuilder(
                  listenable: moduleIdController,
                  builder: (context, _) {
                    final isEditingExistingModule = draftTargetModule() != null;

                    return PrefabEditorActionRow(
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
                            isSelectedDeprecated ? 'Reactivate' : 'Deprecate',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: PrefabEditorUiTokens.sectionGap),
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
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          PrefabEditorSectionCard(
            title: 'Tile Slice Palette',
            child: tileSlices.isEmpty
                ? const Text(
                    'No tile slices yet. Create tile slices in Atlas Slicer first.',
                  )
                : _TileSlicePalette(
                    tileSlices: tileSlices,
                    selectedTileSliceId: selectedTileSliceId,
                    onSelectedTileSliceChanged: onSelectedTileSliceChanged,
                  ),
          ),
        ],
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
      return const PrefabEditorEmptyState(
        message: 'Select or create a module to edit it.',
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

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('platform_module_display_card'),
      title: 'Platform Modules List',
      expandBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorPanelSummary(
            secondaryText:
                'Selected Module: ${widget.selectedModuleId ?? 'none'}',
          ),
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          Expanded(
            child: widget.modules.isEmpty
                ? const PrefabEditorEmptyState(
                    message: 'No platform modules yet.',
                  )
                : ListView.builder(
                    itemCount: widget.modules.length,
                    itemBuilder: (context, index) {
                      final module = widget.modules[index];
                      final isSelected = widget.selectedModuleId == module.id;
                      return PrefabEditorSelectableRowCard(
                        key: ValueKey<String>(
                          'platform_module_row_${module.id}',
                        ),
                        isSelected: isSelected,
                        onTap: () => widget.onSelectedModuleChanged(module.id),
                        preview: PlatformModulePreviewTile(
                          key: ValueKey<String>(
                            'platform_module_preview_${module.id}',
                          ),
                          imageCache: _previewImageCache,
                          workspaceRootPath: widget.workspaceRootPath,
                          module: module,
                          tileSlicesById: tileSlicesById,
                        ),
                        trailing: PrefabEditorDeleteButton(
                          onPressed: () => widget.onDeleteModule(module.id),
                        ),
                        details: !isSelected
                            ? null
                            : module.cells.isEmpty
                            ? const Text('No cells yet.')
                            : Column(
                                children: [
                                  for (
                                    var i = 0;
                                    i < module.cells.length;
                                    i += 1
                                  )
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: Text(module.cells[i].sliceId),
                                      subtitle: Text(
                                        'x=${module.cells[i].gridX} '
                                        'y=${module.cells[i].gridY}',
                                      ),
                                      trailing: PrefabEditorDeleteButton(
                                        onPressed: () => widget
                                            .onDeleteModuleCell(module.id, i),
                                      ),
                                    ),
                                ],
                              ),
                        child: PrefabEditorRowMetadata(
                          title: module.id,
                          isSelected: isSelected,
                          metadataLines: [
                            'status=${module.status.jsonValue} '
                                'rev=${module.revision} '
                                'tileSize=${module.tileSize} '
                                'cells=${module.cells.length}',
                            module.cells.isEmpty
                                ? 'No components yet.'
                                : 'Tap to edit and expand components.',
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
    AtlasSliceDef? selectedSlice;
    final selectedId = selectedTileSliceId;
    if (selectedId != null) {
      for (final slice in tileSlices) {
        if (slice.id == selectedId) {
          selectedSlice = slice;
          break;
        }
      }
    }

    return PrefabEditorChoiceChipGroup<AtlasSliceDef>(
      items: tileSlices,
      selectedValue: selectedSlice,
      labelBuilder: (slice) => '${slice.id} (${slice.width}x${slice.height})',
      onSelected: (slice) => onSelectedTileSliceChanged(slice.id),
    );
  }
}
