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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 1, child: _buildInspectorCard(context)),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: _buildScenePanel(context)),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: _buildSliceDisplayCard(context)),
      ],
    );
  }

  Widget _buildInspectorCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inspector',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              TextField(
                controller: widget.sliceIdController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Slice ID',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: 'village_crate_01 or ground_tile_01',
                ),
              ),
              const SizedBox(height: 8),
              EditorZoomControls(
                value: widget.atlasZoom,
                min: widget.zoomMin,
                max: widget.zoomMax,
                step: widget.zoomStep,
                onChanged: widget.onAtlasZoomChanged,
              ),
              const SizedBox(height: 8),
              Text(widget.selectionLabel),
              const SizedBox(height: 8),
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
                      ),
                      onChanged: (_) => widget.onSelectionInputsChanged(),
                      onSubmitted: (_) => widget.onSelectionInputsChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.selectionYController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Selection Y',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      onChanged: (_) => widget.onSelectionInputsChanged(),
                      onSubmitted: (_) => widget.onSelectionInputsChanged(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                      ),
                      onChanged: (_) => widget.onSelectionInputsChanged(),
                      onSubmitted: (_) => widget.onSelectionInputsChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.selectionHController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Selection H',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      onChanged: (_) => widget.onSelectionInputsChanged(),
                      onSubmitted: (_) => widget.onSelectionInputsChanged(),
                    ),
                  ),
                ],
              ),
              if (widget.atlasSize != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Atlas size: '
                  '${widget.atlasSize!.width.toInt()}x'
                  '${widget.atlasSize!.height.toInt()} px',
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onAddSlice,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Add Slice'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScenePanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scene View', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              widget.selectedAtlasPath == null
                  ? 'Select an atlas/tileset source to start slicing.'
                  : 'Showing $_sliceKindDisplayName slices for '
                        '${p.basename(widget.selectedAtlasPath!)} '
                        '(${widget.slices.length} visible).',
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildAtlasCanvas()),
          ],
        ),
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

    return Card(
      key: const ValueKey<String>('atlas_slice_display_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_sliceKindDisplayName Slice List for:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              widget.selectedAtlasPath == null
                  ? 'Select an atlas/tileset image to inspect slices.'
                  : 'Source: ${p.basename(widget.selectedAtlasPath!)}',
            ),
            const SizedBox(height: 8),
            Text(
              '$_selectedSliceDisplayLabel: ${widget.selectedSliceId ?? 'none'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (widget.selectedSliceId != null &&
                selectedSlice != null &&
                !selectionBelongsToCurrentSource) ...[
              const SizedBox(height: 4),
              Text(
                'The current selection belongs to another source.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: widget.slices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          widget.selectedAtlasPath == null
                              ? 'Select an atlas/tileset image first.'
                              : 'No ${_sliceKindDisplayName.toLowerCase()} '
                                    'slices for this source yet.',
                        ),
                      ),
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
      ),
    );
  }

  Widget _buildSliceRow(BuildContext context, AtlasSliceDef slice) {
    final isSelected = widget.selectedSliceId == slice.id;

    return Card(
      key: ValueKey<String>('atlas_slice_row_${slice.id}'),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => widget.onSelectedSliceChanged(slice.id),
        child: Ink(
          color: isSelected ? const Color(0x1829C98E) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slice.id,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '[${slice.x},${slice.y},${slice.width},${slice.height}]',
                      ),
                      const SizedBox(height: 2),
                      Text('${slice.width}x${slice.height} px'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AtlasSlicePreviewTile(
                  key: ValueKey<String>('atlas_slice_preview_${slice.id}'),
                  imageCache: _previewImageCache,
                  workspaceRootPath: widget.workspaceRootPath,
                  slice: slice,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => widget.onDeleteSlice(slice.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAtlasCanvas() {
    final selectedAtlasPath = widget.selectedAtlasPath;
    if (selectedAtlasPath == null) {
      return const Center(
        child: Text('Select an atlas/tileset image to start slicing.'),
      );
    }
    final atlasSize = widget.atlasSize;
    if (atlasSize == null) {
      return const Center(child: Text('Loading atlas image metadata...'));
    }

    final absolutePath = p.normalize(
      p.join(widget.workspaceRootPath, selectedAtlasPath),
    );
    final imageFile = File(absolutePath);
    if (!imageFile.existsSync()) {
      return Center(child: Text('Missing image: $selectedAtlasPath'));
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
