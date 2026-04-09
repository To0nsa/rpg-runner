import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../prefabs/models/models.dart';
import '../../shared/atlas_slice_preview_tile.dart';
import '../../shared/atlas_selection_painter.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_viewport_grid_painter.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/scene_input_utils.dart';
import '../shared/ui/prefab_editor_action_row.dart';
import '../shared/ui/prefab_editor_delete_button.dart';
import '../shared/ui/prefab_editor_empty_state.dart';
import '../shared/ui/prefab_editor_panel_card.dart';
import '../shared/ui/prefab_editor_panel_summary.dart';
import '../shared/ui/prefab_editor_row_metadata.dart';
import '../shared/ui/prefab_editor_scene_header.dart';
import '../shared/ui/prefab_editor_section_card.dart';
import '../shared/ui/prefab_editor_selectable_row_card.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';
import '../shared/ui/prefab_editor_ui_tokens.dart';

/// Atlas slicing view for prefab and tile source rectangles.
class AtlasSlicerTab extends StatefulWidget {
  const AtlasSlicerTab({
    super.key,
    required this.atlasImagePaths,
    required this.selectedAtlasPath,
    required this.selectedSliceKind,
    required this.sliceIdController,
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
    required this.selectedSliceId,
    required this.selectedSlice,
    required this.workspaceRootPath,
    required this.selectionRectInImagePixels,
    required this.horizontalScrollController,
    required this.verticalScrollController,
    required this.onSelectedAtlasChanged,
    required this.onSelectedSliceKindChanged,
    required this.onSelectedSliceChanged,
    required this.onAtlasZoomChanged,
    required this.onSelectionInputsChanged,
    required this.onAddSlice,
    required this.onDeleteSlice,
    required this.onSelectionDragStart,
    required this.onSelectionDragUpdate,
  });

  final List<String> atlasImagePaths;
  final String? selectedAtlasPath;
  final AtlasSliceKind selectedSliceKind;
  final TextEditingController sliceIdController;
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
  final String? selectedSliceId;
  final AtlasSliceDef? selectedSlice;
  final String workspaceRootPath;
  final Rect? selectionRectInImagePixels;
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;
  final ValueChanged<String?> onSelectedAtlasChanged;
  final ValueChanged<AtlasSliceKind> onSelectedSliceKindChanged;
  final ValueChanged<String> onSelectedSliceChanged;
  final ValueChanged<double> onAtlasZoomChanged;
  final VoidCallback onSelectionInputsChanged;
  final VoidCallback onAddSlice;
  final ValueChanged<String> onDeleteSlice;
  final void Function(Offset localPosition, Size imageSize)
  onSelectionDragStart;
  final void Function(Offset localPosition, Size imageSize)
  onSelectionDragUpdate;

  @override
  State<AtlasSlicerTab> createState() => _AtlasSlicerTabState();
}

class _AtlasSlicerTabState extends State<AtlasSlicerTab> {
  final EditorUiImageCache _previewImageCache = EditorUiImageCache();
  bool _ctrlPanActive = false;

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
    return PrefabEditorPanelCard(
      title: 'Atlas Slicer Controls',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorSectionCard(
            title: 'Source & Slice Setup',
            description:
                'Choose the atlas image, slice kind, and target slice id.',
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
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
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
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
                TextField(
                  controller: widget.sliceIdController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Slice ID',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'village_crate_01 or grass_dirt_32x32',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          PrefabEditorSectionCard(
            title: 'Selection & Actions',
            description:
                'Adjust the selection rectangle numerically and commit it as a slice.',
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
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
                Text(widget.selectionLabel),
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.selectionXController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Selection X',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'X in px from the left',
                        ),
                        onChanged: (_) => widget.onSelectionInputsChanged(),
                        onSubmitted: (_) => widget.onSelectionInputsChanged(),
                      ),
                    ),
                    const SizedBox(width: PrefabEditorUiTokens.controlGap),
                    Expanded(
                      child: TextField(
                        controller: widget.selectionYController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Selection Y',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Y in px from the top',
                        ),
                        onChanged: (_) => widget.onSelectionInputsChanged(),
                        onSubmitted: (_) => widget.onSelectionInputsChanged(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PrefabEditorUiTokens.controlGap),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.selectionWController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Selection W',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Width in px',
                        ),
                        onChanged: (_) => widget.onSelectionInputsChanged(),
                        onSubmitted: (_) => widget.onSelectionInputsChanged(),
                      ),
                    ),
                    const SizedBox(width: PrefabEditorUiTokens.controlGap),
                    Expanded(
                      child: TextField(
                        controller: widget.selectionHController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Selection H',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Height in px',
                        ),
                        onChanged: (_) => widget.onSelectionInputsChanged(),
                        onSubmitted: (_) => widget.onSelectionInputsChanged(),
                      ),
                    ),
                  ],
                ),
                if (widget.atlasSize != null) ...[
                  const SizedBox(height: PrefabEditorUiTokens.controlGap),
                  Text(
                    'Atlas size: '
                    '${widget.atlasSize!.width.toInt()}x'
                    '${widget.atlasSize!.height.toInt()} px',
                  ),
                ],
                const SizedBox(height: PrefabEditorUiTokens.sectionGap),
                PrefabEditorActionRow(
                  children: [
                    FilledButton.icon(
                      onPressed: widget.onAddSlice,
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('Add Slice'),
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

    return PrefabEditorPanelCard(
      title: 'Atlas Slicer View',
      expandBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorSceneHeader(
            title: sceneHeaderTitle,
            subtitle: sceneHeaderSubtitle,
          ),
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
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

    return PrefabEditorPanelCard(
      cardKey: const ValueKey<String>('atlas_slice_display_card'),
      title: '$_sliceKindDisplayName Slices',
      expandBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefabEditorPanelSummary(
            primaryText: widget.selectedAtlasPath == null
                ? 'Select an atlas/tileset image to inspect slices.'
                : 'Source: ${p.basename(widget.selectedAtlasPath!)}',
            secondaryText:
                '$_selectedSliceDisplayLabel: ${widget.selectedSliceId ?? 'none'}',
            noticeText:
                widget.selectedSliceId != null &&
                    selectedSlice != null &&
                    !selectionBelongsToCurrentSource
                ? 'The current selection belongs to another source.'
                : null,
          ),
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          Expanded(
            child: widget.slices.isEmpty
                ? PrefabEditorEmptyState(
                    message: widget.selectedAtlasPath == null
                        ? 'Select an atlas/tileset image first.'
                        : 'No ${_sliceKindDisplayName.toLowerCase()} '
                              'slices for this source yet.',
                  )
                : ListView.builder(
                    itemCount: widget.slices.length,
                    itemBuilder: (context, index) {
                      final slice = widget.slices[index];
                      return _buildSliceRow(context, slice);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliceRow(BuildContext context, AtlasSliceDef slice) {
    final isSelected = widget.selectedSliceId == slice.id;

    return PrefabEditorSelectableRowCard(
      key: ValueKey<String>('atlas_slice_row_${slice.id}'),
      isSelected: isSelected,
      onTap: () => widget.onSelectedSliceChanged(slice.id),
      preview: AtlasSlicePreviewTile(
        key: ValueKey<String>('atlas_slice_preview_${slice.id}'),
        imageCache: _previewImageCache,
        workspaceRootPath: widget.workspaceRootPath,
        slice: slice,
      ),
      trailing: PrefabEditorDeleteButton(
        onPressed: () => widget.onDeleteSlice(slice.id),
      ),
      child: PrefabEditorRowMetadata(
        title: slice.id,
        isSelected: isSelected,
        metadataLines: [
          '[${slice.x},${slice.y},${slice.width},${slice.height}]',
          '${slice.width}x${slice.height} px',
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

    final absolutePath = p.normalize(
      p.join(widget.workspaceRootPath, selectedAtlasPath),
    );
    final imageFile = File(absolutePath);
    if (!imageFile.existsSync()) {
      return PrefabEditorEmptyState(
        message: 'Missing image: $selectedAtlasPath',
      );
    }

    final scaledWidth = atlasSize.width * widget.atlasZoom;
    final scaledHeight = atlasSize.height * widget.atlasZoom;

    final stack = SizedBox(
      width: scaledWidth,
      height: scaledHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.file(
              imageFile,
              width: scaledWidth,
              height: scaledHeight,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: EditorViewportGridPainter(zoom: widget.atlasZoom),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: AtlasSelectionPainter(
                  zoom: widget.atlasZoom,
                  selectionRectInImagePixels: widget.selectionRectInImagePixels,
                  existingSlices: widget.slices,
                  selectedSliceId: widget.selectedSliceId,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Listener(
              key: const ValueKey<String>('atlas_scene_canvas'),
              onPointerSignal: _onPointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  if (SceneInputUtils.isCtrlPressed()) {
                    _ctrlPanActive = true;
                    return;
                  }
                  widget.onSelectionDragStart(details.localPosition, atlasSize);
                },
                onPanUpdate: (details) {
                  if (_ctrlPanActive || SceneInputUtils.isCtrlPressed()) {
                    SceneInputUtils.panScrollControllers(
                      horizontal: widget.horizontalScrollController,
                      vertical: widget.verticalScrollController,
                      pointerDelta: details.delta,
                    );
                    return;
                  }
                  widget.onSelectionDragUpdate(
                    details.localPosition,
                    atlasSize,
                  );
                },
                onPanEnd: (_) {
                  _ctrlPanActive = false;
                },
              ),
            ),
          ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1B2A36)),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          key: const ValueKey<String>('atlas_scene_vertical_scroll'),
          controller: widget.verticalScrollController,
          child: SingleChildScrollView(
            key: const ValueKey<String>('atlas_scene_horizontal_scroll'),
            controller: widget.horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: stack,
          ),
        ),
      ),
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

  void _onPointerSignal(PointerSignalEvent event) {
    final signedSteps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (signedSteps == 0) {
      return;
    }
    final nextZoom = widget.atlasZoom + (signedSteps * widget.zoomStep);
    widget.onAtlasZoomChanged(
      nextZoom.clamp(widget.zoomMin, widget.zoomMax).toDouble(),
    );
  }
}
