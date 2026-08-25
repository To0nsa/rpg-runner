import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../../shared/editor_panel_card.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_ui_tokens.dart';
import '../../shared/platform_module_preview_tile.dart';
import '../shared/ui/prefab_editor_action_row.dart';
import '../shared/ui/prefab_editor_atlas_slice_selector.dart';
import '../shared/ui/prefab_editor_delete_button.dart';
import '../shared/ui/prefab_editor_empty_state.dart';
import '../shared/ui/prefab_editor_mode_banner.dart';
import '../shared/ui/prefab_editor_panel_summary.dart';
import '../shared/ui/prefab_editor_row_metadata.dart';
import '../shared/ui/prefab_editor_scene_header.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';
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
    required this.hasLocalDraftChanges,
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
  final ValueChanged<String?> onSelectedTileSliceChanged;
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
  final bool hasLocalDraftChanges;

  @override
  Widget build(BuildContext context) {
    final isSelectedDeprecated =
        selectedModule?.status == TileModuleStatus.deprecated;

    return PrefabEditorThreePanelLayout(
      inspector: _PlatformModuleInspectorPanel(
        moduleIdController: moduleIdController,
        moduleTileSizeController: moduleTileSizeController,
        selectedModule: selectedModule,
        tileSlices: tileSlices,
        selectedTileSliceId: selectedTileSliceId,
        workspaceRootPath: workspaceRootPath,
        isSelectedDeprecated: isSelectedDeprecated,
        hasLocalDraftChanges: hasLocalDraftChanges,
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

    return EditorPanelCard(
      key: const ValueKey<String>('platform_module_scene_card'),
      title: 'Platform Module View',
      bodyMode: EditorPanelBodyMode.expanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorSceneHeader(
            title: sceneHeaderTitle,
            subtitle: sceneHeaderSubtitle,
          ),
          const SizedBox(height: EditorUiTokens.sectionGap),
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
    required this.selectedModule,
    required this.tileSlices,
    required this.selectedTileSliceId,
    required this.workspaceRootPath,
    required this.isSelectedDeprecated,
    required this.hasLocalDraftChanges,
    required this.onUpsertModule,
    required this.onStartNewEmptyModule,
    required this.onRenameSelectedModule,
    required this.onDuplicateSelectedModule,
    required this.onToggleDeprecateSelectedModule,
    required this.onSelectedTileSliceChanged,
  });

  final TextEditingController moduleIdController;
  final TextEditingController moduleTileSizeController;
  final TileModuleDef? selectedModule;
  final List<AtlasSliceDef> tileSlices;
  final String? selectedTileSliceId;
  final String workspaceRootPath;
  final bool isSelectedDeprecated;
  final bool hasLocalDraftChanges;
  final VoidCallback onUpsertModule;
  final VoidCallback onStartNewEmptyModule;
  final VoidCallback onRenameSelectedModule;
  final VoidCallback onDuplicateSelectedModule;
  final VoidCallback onToggleDeprecateSelectedModule;
  final ValueChanged<String?> onSelectedTileSliceChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey<String>('platform_module_authoring_sidebar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrefabEditorModeBanner(
            bannerKey: const ValueKey<String>('platform_module_mode_banner'),
            title: selectedModule == null
                ? 'Creating new platform module'
                : 'Editing platform module "${selectedModule!.id}"',
            details: selectedModule == null
                ? 'Saving will create a new empty module for the current ID.'
                : 'rev=${selectedModule!.revision} '
                      'status=${selectedModule!.status.jsonValue} '
                      'tileSize=${selectedModule!.tileSize} '
                      'cells=${selectedModule!.cells.length}',
            tone: selectedModule == null
                ? PrefabEditorModeTone.create
                : PrefabEditorModeTone.edit,
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          EditorSectionCard(
            key: const ValueKey<String>('platform_module_advanced_controls'),
            expansionKey: const ValueKey<String>(
              'platform_module_advanced_controls_toggle',
            ),
            title: selectedModule == null
                ? 'Create platform module'
                : 'Edit selected module',
            description: selectedModule == null
                ? 'Create a new empty module with a unique ID and tile size.'
                : 'Update metadata or use contextual lifecycle actions.',
            collapsible: !hasLocalDraftChanges,
            initiallyExpanded: false,
            expanded: hasLocalDraftChanges ? true : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey<String>('platform_module_id_field'),
                  controller: moduleIdController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Platform Module ID',
                  ),
                ),
                const SizedBox(height: EditorUiTokens.controlGap),
                TextField(
                  key: const ValueKey<String>(
                    'platform_module_tile_size_field',
                  ),
                  controller: moduleTileSizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Tile Size (px)',
                  ),
                ),
                const SizedBox(height: EditorUiTokens.controlGap),
                PrefabEditorActionRow(
                  children: [
                    FilledButton.icon(
                      key: const ValueKey<String>(
                        'platform_module_upsert_button',
                      ),
                      onPressed: onUpsertModule,
                      icon: Icon(
                        selectedModule != null
                            ? Icons.save_outlined
                            : Icons.add_box_outlined,
                      ),
                      label: Text(
                        selectedModule != null
                            ? 'Update Module'
                            : 'Create Module',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'platform_module_new_empty_button',
                      ),
                      onPressed: selectedModule == null
                          ? null
                          : onStartNewEmptyModule,
                      icon: const Icon(Icons.post_add_outlined),
                      label: const Text('New Empty Module'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'platform_module_rename_button',
                      ),
                      onPressed: selectedModule == null
                          ? null
                          : onRenameSelectedModule,
                      icon: const Icon(Icons.drive_file_rename_outline),
                      label: const Text('Rename'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'platform_module_duplicate_button',
                      ),
                      onPressed: selectedModule == null
                          ? null
                          : onDuplicateSelectedModule,
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Duplicate'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'platform_module_status_button',
                      ),
                      onPressed: selectedModule == null
                          ? null
                          : onToggleDeprecateSelectedModule,
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
                const SizedBox(height: EditorUiTokens.sectionGap),
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
          const SizedBox(height: EditorUiTokens.sectionGap),
          EditorSectionCard(
            key: const ValueKey<String>('platform_module_palette_section'),
            expansionKey: const ValueKey<String>(
              'platform_module_palette_section_toggle',
            ),
            title: 'Tile Slice Palette',
            description: 'Choose the tile painted by the scene tool.',
            collapsible: true,
            initiallyExpanded: false,
            child: tileSlices.isEmpty
                ? const Text(
                    'No tile slices yet. Create tile slices in Atlas Slicer first.',
                  )
                : PrefabEditorAtlasSliceSelector(
                    fieldKey: const ValueKey<String>(
                      'platform_module_tile_slice_selector',
                    ),
                    optionKeyPrefix: 'platform_module_tile_slice_option',
                    optionPreviewKeyPrefix:
                        'platform_module_tile_slice_option_preview',
                    selectedPreviewKey: const ValueKey<String>(
                      'platform_module_tile_slice_selected_preview',
                    ),
                    slices: tileSlices,
                    selectedSliceId: selectedTileSliceId,
                    onSelectedSliceChanged: onSelectedTileSliceChanged,
                    workspaceRootPath: workspaceRootPath,
                    labelText: 'Tile Slice',
                    hintText: 'Search tile slices by id or tag',
                    emptyStateMessage: 'No tile slices yet. Create tile slices in Atlas Slicer first.',
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

    return SingleChildScrollView(
      key: const ValueKey<String>('platform_module_display_sidebar'),
      child: EditorSectionCard(
        key: const ValueKey<String>('platform_module_library_section'),
        expansionKey: const ValueKey<String>(
          'platform_module_library_section_toggle',
        ),
        title: 'Existing platform modules',
        description: 'Select a visual row to synchronize its inline editor.',
        trailing: Text('${widget.modules.length} total'),
        collapsible: true,
        initiallyExpanded: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrefabEditorPanelSummary(
              secondaryText:
                  'Selected Module: ${widget.selectedModuleId ?? 'none'}',
            ),
            const SizedBox(height: EditorUiTokens.sectionGap),
            if (widget.modules.isEmpty)
              const PrefabEditorEmptyState(message: 'No platform modules yet.')
            else
              for (final module in widget.modules)
                EditorListCard(
                  key: ValueKey<String>('platform_module_row_${module.id}'),
                  isSelected: widget.selectedModuleId == module.id,
                  onTap: () => widget.onSelectedModuleChanged(module.id),
                  semanticLabel:
                      '${module.id}, ${module.status.jsonValue}, '
                      '${module.cells.length} cells, '
                      '${module.tileSize} pixel tiles',
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
                  details: widget.selectedModuleId != module.id
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected for editing in Edit selected '
                              'module and the scene.',
                            ),
                            if (module.cells.isEmpty)
                              const Text('No cells yet.'),
                            for (var i = 0; i < module.cells.length; i += 1)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(module.cells[i].sliceId),
                                subtitle: Text(
                                  'x=${module.cells[i].gridX} '
                                  'y=${module.cells[i].gridY}',
                                ),
                                trailing: PrefabEditorDeleteButton(
                                  onPressed: () =>
                                      widget.onDeleteModuleCell(module.id, i),
                                ),
                              ),
                          ],
                        ),
                  child: PrefabEditorRowMetadata(
                    title: module.id,
                    isSelected: widget.selectedModuleId == module.id,
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
                ),
          ],
        ),
      ),
    );
  }
}
