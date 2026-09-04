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

/// Platform visual-composition view with direct collision-owner navigation.
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
    required this.prefabCountByModuleId,
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
    required this.onEditCollision,
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
  final Map<String, int> prefabCountByModuleId;
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
  final ValueChanged<String> onEditCollision;
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
        collisionOwnerCount: selectedModule == null
            ? 0
            : prefabCountByModuleId[selectedModule!.id] ?? 0,
        onEditCollision: selectedModule == null || selectedModule!.cells.isEmpty
            ? null
            : () => onEditCollision(selectedModule!.id),
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
        prefabCountByModuleId: prefabCountByModuleId,
        onEditCollision: onEditCollision,
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
        ? 'No platform selected'
        : 'Platform: ${selectedModule.id}';
    final sceneHeaderSubtitle = selectedModule == null
        ? 'Select or create a platform to edit it.'
        : 'cells=${selectedModule.cells.length} '
              'tileSize=${selectedModule.tileSize} '
              'tool=${selectedModuleSceneTool.label} '
              'slice=${selectedTileSliceId ?? 'none'}';

    return EditorPanelCard(
      key: const ValueKey<String>('platform_module_scene_card'),
      title: 'Platform Visual',
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
    required this.collisionOwnerCount,
    required this.onEditCollision,
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
  final int collisionOwnerCount;
  final VoidCallback? onEditCollision;
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
                ? 'Creating new platform'
                : 'Editing platform "${selectedModule!.id}"',
            details: selectedModule == null
                ? 'Saving creates an empty visual composition. Add tiles and '
                      'its collision owner is created automatically.'
                : 'rev=${selectedModule!.revision} '
                      'status=${selectedModule!.status.jsonValue} '
                      'tileSize=${selectedModule!.tileSize} '
                      'cells=${selectedModule!.cells.length} '
                      'collision=${_collisionOwnerLabel(collisionOwnerCount)}',
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
                ? 'Create platform'
                : 'Edit selected platform',
            description: selectedModule == null
                ? 'Create a new platform visual with a unique ID and tile size.'
                : 'Update its visual, lifecycle, or collision.',
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
                    labelText: 'Platform ID',
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
                            ? 'Update Platform'
                            : 'Create Platform',
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
                      label: const Text('New Platform'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'platform_module_edit_collision_button',
                      ),
                      onPressed: onEditCollision,
                      icon: const Icon(Icons.border_style_outlined),
                      label: Text(
                        collisionOwnerCount == 0
                            ? 'Set Up Collision'
                            : collisionOwnerCount == 1
                            ? 'Edit Collision'
                            : 'Choose Collision Prefab',
                      ),
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
                      ? 'Select a platform from the list to edit it.'
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
        message: 'Select or create a platform to edit it.',
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
    required this.prefabCountByModuleId,
    required this.onEditCollision,
  });

  final List<TileModuleDef> modules;
  final List<AtlasSliceDef> tileSlices;
  final String? selectedModuleId;
  final String workspaceRootPath;
  final ValueChanged<String?> onSelectedModuleChanged;
  final ValueChanged<String> onDeleteModule;
  final void Function(String moduleId, int cellIndex) onDeleteModuleCell;
  final Map<String, int> prefabCountByModuleId;
  final ValueChanged<String> onEditCollision;

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
        title: 'Existing platforms',
        description: 'Select a platform to edit its visual or collision.',
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
              const PrefabEditorEmptyState(message: 'No platforms yet.')
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
                  trailing: Wrap(
                    spacing: EditorUiTokens.controlGap,
                    children: <Widget>[
                      IconButton(
                        key: ValueKey<String>(
                          'platform_module_collision_${module.id}',
                        ),
                        tooltip: module.cells.isEmpty
                            ? 'Add visual tiles before editing collision'
                            : (widget.prefabCountByModuleId[module.id] ?? 0) ==
                                  0
                            ? 'Set up collision'
                            : 'Edit collision',
                        onPressed: module.cells.isEmpty
                            ? null
                            : () => widget.onEditCollision(module.id),
                        icon: const Icon(Icons.border_style_outlined),
                      ),
                      PrefabEditorDeleteButton(
                        onPressed: () => widget.onDeleteModule(module.id),
                      ),
                    ],
                  ),
                  details: widget.selectedModuleId != module.id
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected for editing in Edit selected '
                              'platform and the visual scene.',
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
                      'collision=${_collisionOwnerLabel(widget.prefabCountByModuleId[module.id] ?? 0)}',
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

String _collisionOwnerLabel(int count) => switch (count) {
  0 => 'not configured',
  1 => 'configured',
  _ => '$count prefab variants',
};
