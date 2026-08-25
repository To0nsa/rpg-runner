import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../atlas/atlas_grid.dart';
import '../../../../atlas/atlas_pixel_rect.dart';
import '../../../../prefabs/models/models.dart';
import '../../shared/atlas_grid_controls.dart';
import '../../shared/atlas_image_viewport.dart';
import '../../shared/atlas_region_fields.dart';
import '../../shared/atlas_region_preview_tile.dart';
import '../../shared/atlas_selection_painter.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_panel_card.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_ui_tokens.dart';
import '../../shared/editor_zoom_controls.dart';
import '../shared/ui/prefab_editor_action_row.dart';
import '../shared/ui/prefab_editor_delete_button.dart';
import '../shared/ui/prefab_editor_empty_state.dart';
import '../shared/ui/prefab_editor_mode_banner.dart';
import '../shared/ui/prefab_editor_panel_summary.dart';
import '../shared/ui/prefab_editor_row_metadata.dart';
import '../shared/ui/prefab_editor_scene_header.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';

/// Atlas slicing view for prefab and tile source rectangles.
class AtlasSlicerTab extends StatefulWidget {
  const AtlasSlicerTab({
    super.key,
    required this.atlasImagePaths,
    required this.selectedAtlasPath,
    required this.selectedSliceKind,
    required this.sliceIdController,
    required this.sliceTagsController,
    required this.atlasZoom,
    required this.zoomMin,
    required this.zoomMax,
    required this.zoomStep,
    required this.selectionLabel,
    required this.selectionXController,
    required this.selectionYController,
    required this.selectionWController,
    required this.selectionHController,
    required this.atlasSize,
    required this.slices,
    required this.existingSliceIds,
    required this.selectedSliceId,
    required this.selectedSlice,
    required this.workspaceRootPath,
    required this.selectionRectInImagePixels,
    required this.autoSliceEnabled,
    required this.gridSettings,
    required this.horizontalScrollController,
    required this.verticalScrollController,
    required this.onSelectedAtlasChanged,
    required this.onSelectedSliceKindChanged,
    required this.onSelectedSliceChanged,
    required this.onAtlasZoomChanged,
    required this.onSelectionInputsChanged,
    required this.onAutoSliceEnabledChanged,
    required this.onGridSettingsChanged,
    required this.onSaveSlice,
    required this.onDeleteSlice,
    required this.onSelectionChanged,
    required this.hasLocalDraftChanges,
  });

  final List<String> atlasImagePaths;
  final String? selectedAtlasPath;
  final AtlasSliceKind selectedSliceKind;
  final TextEditingController sliceIdController;
  final TextEditingController sliceTagsController;
  final double atlasZoom;
  final double zoomMin;
  final double zoomMax;
  final double zoomStep;
  final String selectionLabel;
  final TextEditingController selectionXController;
  final TextEditingController selectionYController;
  final TextEditingController selectionWController;
  final TextEditingController selectionHController;
  final Size? atlasSize;
  final List<AtlasSliceDef> slices;
  final Set<String> existingSliceIds;
  final String? selectedSliceId;
  final AtlasSliceDef? selectedSlice;
  final String workspaceRootPath;
  final AtlasPixelRect? selectionRectInImagePixels;
  final bool autoSliceEnabled;
  final AtlasGridSettings gridSettings;
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;
  final ValueChanged<String?> onSelectedAtlasChanged;
  final ValueChanged<AtlasSliceKind> onSelectedSliceKindChanged;
  final ValueChanged<String> onSelectedSliceChanged;
  final ValueChanged<double> onAtlasZoomChanged;
  final VoidCallback onSelectionInputsChanged;
  final ValueChanged<bool> onAutoSliceEnabledChanged;
  final ValueChanged<AtlasGridSettings> onGridSettingsChanged;
  final VoidCallback onSaveSlice;
  final ValueChanged<String> onDeleteSlice;
  final ValueChanged<AtlasPixelRect> onSelectionChanged;
  final bool hasLocalDraftChanges;

  @override
  State<AtlasSlicerTab> createState() => _AtlasSlicerTabState();
}

class _AtlasSlicerTabState extends State<AtlasSlicerTab> {
  final EditorUiImageCache _previewImageCache = EditorUiImageCache();

  @override
  void dispose() {
    _previewImageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrefabEditorThreePanelLayout(
      inspector: _buildInspectorCard(context),
      scene: _buildScenePanel(context),
      display: _buildSliceDisplayCard(context),
    );
  }

  Widget _buildInspectorCard(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey<String>('atlas_slice_authoring_sidebar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.sliceIdController,
            builder: (context, value, _) {
              final id = value.text.trim();
              final editing = widget.existingSliceIds.contains(id);
              return PrefabEditorModeBanner(
                bannerKey: const ValueKey<String>('atlas_slice_mode_banner'),
                title: editing
                    ? 'Editing ${_sliceKindDisplayName.toLowerCase()} slice '
                          '"$id"'
                    : 'Creating a new '
                          '${_sliceKindDisplayName.toLowerCase()} slice',
                details: editing
                    ? 'The visual row, atlas overlay, and fields share this '
                          'slice selection.'
                    : 'Choose a unique ID and source rectangle before saving.',
                tone: editing
                    ? PrefabEditorModeTone.edit
                    : PrefabEditorModeTone.create,
              );
            },
          ),
          const SizedBox(height: EditorUiTokens.sectionGap),
          EditorSectionCard(
            key: const ValueKey<String>('atlas_slice_setup_section'),
            expansionKey: const ValueKey<String>(
              'atlas_slice_setup_section_toggle',
            ),
            title: 'Source & Slice Setup',
            description: 'Choose the atlas image, slice kind, target slice id, and tags.',
            collapsible: !widget.hasLocalDraftChanges,
            initiallyExpanded: false,
            expanded: widget.hasLocalDraftChanges ? true : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>(
                    'atlas_${widget.selectedAtlasPath ?? 'none'}',
                  ),
                  initialValue: widget.selectedAtlasPath,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Atlas/Tileset Source',
                  ),
                  items: [
                    for (final path in widget.atlasImagePaths)
                      DropdownMenuItem<String>(value: path, child: Text(path)),
                  ],
                  onChanged: widget.onSelectedAtlasChanged,
                ),
                const SizedBox(height: EditorUiTokens.controlGap),
                DropdownButtonFormField<AtlasSliceKind>(
                  key: ValueKey<String>(
                    'slice_kind_${widget.selectedSliceKind.name}',
                  ),
                  initialValue: widget.selectedSliceKind,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Slice Kind',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AtlasSliceKind.prefab,
                      child: Text('Prefab Slice'),
                    ),
                    DropdownMenuItem(
                      value: AtlasSliceKind.tile,
                      child: Text('Tile Slice'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    widget.onSelectedSliceKindChanged(value);
                  },
                ),
                const SizedBox(height: EditorUiTokens.controlGap),
                TextField(
                  key: const ValueKey<String>('atlas_slice_id_field'),
                  controller: widget.sliceIdController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Slice ID',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'village_crate_01 or grass_dirt_32x32',
                  ),
                ),
                const SizedBox(height: EditorUiTokens.controlGap),
                TextField(
                  key: const ValueKey<String>('atlas_slice_tags_field'),
                  controller: widget.sliceTagsController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Slice Tags (comma separated)',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'obstacle, decoration, wall, ground',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          EditorSectionCard(
            key: const ValueKey<String>('atlas_slice_selection_section'),
            expansionKey: const ValueKey<String>(
              'atlas_slice_selection_section_toggle',
            ),
            title: 'Selection & Actions',
            description: 'Adjust the selection rectangle numerically and save it back to the slice list.',
            collapsible: !widget.hasLocalDraftChanges,
            initiallyExpanded: false,
            expanded: widget.hasLocalDraftChanges ? true : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditorZoomControls(
                  value: widget.atlasZoom,
                  min: widget.zoomMin,
                  max: widget.zoomMax,
                  step: widget.zoomStep,
                  onChanged: widget.onAtlasZoomChanged,
                ),
                const SizedBox(height: EditorUiTokens.controlGap),
                Text(widget.selectionLabel),
                const SizedBox(height: EditorUiTokens.controlGap),
                AtlasRegionFields(
                  xController: widget.selectionXController,
                  yController: widget.selectionYController,
                  widthController: widget.selectionWController,
                  heightController: widget.selectionHController,
                  onChanged: widget.onSelectionInputsChanged,
                ),
                const SizedBox(height: EditorUiTokens.controlGap),
                SwitchListTile.adaptive(
                  key: const ValueKey<String>('atlas_auto_slice_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-slice grid'),
                  subtitle: const Text(
                    'Snap selection to complete cells; drag across cells to combine them.',
                  ),
                  value: widget.autoSliceEnabled,
                  onChanged: widget.onAutoSliceEnabledChanged,
                ),
                if (widget.autoSliceEnabled) ...[
                  const SizedBox(height: EditorUiTokens.controlGap),
                  AtlasGridControls(
                    settings: widget.gridSettings,
                    onChanged: widget.onGridSettingsChanged,
                  ),
                ],
                if (widget.atlasSize != null) ...[
                  const SizedBox(height: EditorUiTokens.controlGap),
                  Text(
                    'Atlas size: '
                    '${widget.atlasSize!.width.toInt()}x'
                    '${widget.atlasSize!.height.toInt()} px',
                  ),
                ],
                const SizedBox(height: EditorUiTokens.sectionGap),
                PrefabEditorActionRow(
                  children: [
                    FilledButton.icon(
                      key: const ValueKey<String>('atlas_slice_save'),
                      onPressed: widget.onSaveSlice,
                      icon: const Icon(Icons.add_box_outlined),
                      label: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.sliceIdController,
                        builder: (context, value, _) {
                          final id = value.text.trim();
                          final label = widget.existingSliceIds.contains(id)
                              ? 'Update Slice'
                              : 'Create Slice';
                          return Text(label);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenePanel(BuildContext context) {
    final selectedAtlasPath = widget.selectedAtlasPath;
    final sceneHeaderTitle = selectedAtlasPath == null
        ? 'No atlas source selected'
        : p.basename(selectedAtlasPath);
    final sceneHeaderSubtitle = selectedAtlasPath == null
        ? 'Select an atlas/tileset source to start slicing.'
        : 'Showing ${_sliceKindDisplayName.toLowerCase()} slices '
              '(${widget.slices.length} visible).';

    return EditorPanelCard(
      key: const ValueKey<String>('atlas_scene_card'),
      title: 'Atlas Slicer View',
      bodyMode: EditorPanelBodyMode.expanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorSceneHeader(
            title: sceneHeaderTitle,
            subtitle: sceneHeaderSubtitle,
          ),
          const SizedBox(height: EditorUiTokens.sectionGap),
          Expanded(child: _buildAtlasCanvas()),
        ],
      ),
    );
  }

  Widget _buildSliceDisplayCard(BuildContext context) {
    final selectedSlice = widget.selectedSlice;
    final selectionBelongsToCurrentSource =
        selectedSlice != null &&
        widget.selectedAtlasPath != null &&
        selectedSlice.sourceImagePath.trim() ==
            widget.selectedAtlasPath!.trim();

    return SingleChildScrollView(
      key: const ValueKey<String>('atlas_slice_display_sidebar'),
      child: EditorSectionCard(
        key: const ValueKey<String>('atlas_slice_library_section'),
        expansionKey: const ValueKey<String>(
          'atlas_slice_library_section_toggle',
        ),
        title: 'Existing $_sliceKindDisplayName slices',
        description: 'Select a visual row to synchronize its inline editor.',
        trailing: Text('${widget.slices.length} total'),
        collapsible: true,
        initiallyExpanded: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrefabEditorPanelSummary(
              primaryText: widget.selectedAtlasPath == null
                  ? 'Select an atlas/tileset image to inspect slices.'
                  : 'Source: ${p.basename(widget.selectedAtlasPath!)}',
              secondaryText:
                  '$_selectedSliceDisplayLabel: '
                  '${widget.selectedSliceId ?? 'none'}',
              noticeText:
                  widget.selectedSliceId != null &&
                      selectedSlice != null &&
                      !selectionBelongsToCurrentSource
                  ? 'The current selection belongs to another source.'
                  : null,
            ),
            const SizedBox(height: EditorUiTokens.sectionGap),
            if (widget.slices.isEmpty)
              PrefabEditorEmptyState(
                message: widget.selectedAtlasPath == null
                    ? 'Select an atlas/tileset image first.'
                    : 'No ${_sliceKindDisplayName.toLowerCase()} '
                          'slices for this source yet.',
              )
            else
              for (final slice in widget.slices) _buildSliceRow(context, slice),
          ],
        ),
      ),
    );
  }

  Widget _buildSliceRow(BuildContext context, AtlasSliceDef slice) {
    final isSelected = widget.selectedSliceId == slice.id;

    return EditorListCard(
      key: ValueKey<String>('atlas_slice_row_${slice.id}'),
      isSelected: isSelected,
      onTap: () => widget.onSelectedSliceChanged(slice.id),
      semanticLabel:
          '${slice.id}, ${slice.width} by ${slice.height} pixels, '
          '${slice.tags.isEmpty ? 'no tags' : slice.tags.join(', ')}',
      preview: AtlasRegionPreviewTile(
        key: ValueKey<String>('atlas_slice_preview_${slice.id}'),
        imageCache: _previewImageCache,
        workspaceRootPath: widget.workspaceRootPath,
        sourceImagePath: slice.sourceImagePath,
        region: AtlasPixelRect(
          x: slice.x,
          y: slice.y,
          width: slice.width,
          height: slice.height,
        ),
      ),
      trailing: PrefabEditorDeleteButton(
        onPressed: () => widget.onDeleteSlice(slice.id),
      ),
      details: isSelected
          ? const Text(
              'Selected for editing in Source & Slice Setup and Selection & '
              'Actions.',
            )
          : null,
      child: PrefabEditorRowMetadata(
        title: slice.id,
        isSelected: isSelected,
        metadataLines: [
          '[${slice.x},${slice.y},${slice.width},${slice.height}]',
          '${slice.width}x${slice.height} px',
          if (slice.tags.isNotEmpty) 'tags=${slice.tags.join(', ')}',
        ],
      ),
    );
  }

  Widget _buildAtlasCanvas() {
    final selectedAtlasPath = widget.selectedAtlasPath;
    if (selectedAtlasPath == null) {
      return const PrefabEditorEmptyState(
        message: 'Select an atlas/tileset image to start slicing.',
      );
    }
    final atlasSize = widget.atlasSize;
    if (atlasSize == null) {
      return const PrefabEditorEmptyState(
        message: 'Loading atlas image metadata...',
      );
    }

    return AtlasImageViewport(
      workspaceRootPath: widget.workspaceRootPath,
      sourceImagePath: selectedAtlasPath,
      imageWidth: atlasSize.width.toInt(),
      imageHeight: atlasSize.height.toInt(),
      zoom: widget.atlasZoom,
      zoomMin: widget.zoomMin,
      zoomMax: widget.zoomMax,
      zoomStep: widget.zoomStep,
      autoSliceEnabled: widget.autoSliceEnabled,
      gridSettings: widget.gridSettings,
      selection: widget.selectionRectInImagePixels,
      existingRegions: <AtlasSelectionOverlay>[
        for (final slice in widget.slices)
          AtlasSelectionOverlay(
            id: slice.id,
            rect: AtlasPixelRect(
              x: slice.x,
              y: slice.y,
              width: slice.width,
              height: slice.height,
            ),
          ),
      ],
      selectedRegionId: widget.selectedSliceId,
      horizontalScrollController: widget.horizontalScrollController,
      verticalScrollController: widget.verticalScrollController,
      onZoomChanged: widget.onAtlasZoomChanged,
      onSelectionChanged: widget.onSelectionChanged,
    );
  }

  String get _sliceKindDisplayName {
    switch (widget.selectedSliceKind) {
      case AtlasSliceKind.prefab:
        return 'Prefab';
      case AtlasSliceKind.tile:
        return 'Tile';
    }
  }

  String get _selectedSliceDisplayLabel {
    switch (widget.selectedSliceKind) {
      case AtlasSliceKind.prefab:
        return 'Selected Prefab Slice';
      case AtlasSliceKind.tile:
        return 'Selected Tile Slice';
    }
  }
}
