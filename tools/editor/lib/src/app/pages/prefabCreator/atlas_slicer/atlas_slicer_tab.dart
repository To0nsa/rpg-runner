import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../prefabs/models/models.dart';
import '../../shared/atlas_selection_painter.dart';
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
    required this.workspaceRootPath,
    required this.selectionRectInImagePixels,
    required this.horizontalScrollController,
    required this.verticalScrollController,
    required this.onSelectedAtlasChanged,
    required this.onSelectedSliceKindChanged,
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
  final String workspaceRootPath;
  final Rect? selectionRectInImagePixels;
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;
  final ValueChanged<String?> onSelectedAtlasChanged;
  final ValueChanged<AtlasSliceKind> onSelectedSliceKindChanged;
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
  bool _ctrlPanActive = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (widget.atlasSize != null)
                  Text(
                    'Atlas size: ${widget.atlasSize!.width.toInt()}x${widget.atlasSize!.height.toInt()} px',
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: widget.onAddSlice,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Add Slice'),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.selectedSliceKind == AtlasSliceKind.prefab
                      ? 'Prefab Slices'
                      : 'Tile Slices',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _SlicesTable(
                  slices: widget.slices,
                  onDeleteSlice: widget.onDeleteSlice,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildAtlasCanvas()),
      ],
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

  void _onPointerSignal(PointerSignalEvent event) {
    final signedSteps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (signedSteps == 0) {
      return;
    }
    final nextZoom = widget.atlasZoom + (signedSteps * widget.zoomStep);
    widget.onAtlasZoomChanged(nextZoom.clamp(widget.zoomMin, widget.zoomMax));
  }
}

class _SlicesTable extends StatelessWidget {
  const _SlicesTable({required this.slices, required this.onDeleteSlice});

  final List<AtlasSliceDef> slices;
  final ValueChanged<String> onDeleteSlice;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Text('No slices yet.');
    }

    return SizedBox(
      height: 320,
      child: ListView.builder(
        itemCount: slices.length,
        itemBuilder: (context, index) {
          final slice = slices[index];
          return Card(
            child: ListTile(
              dense: true,
              title: Text(slice.id),
              subtitle: Text(
                '${slice.sourceImagePath} '
                '[${slice.x},${slice.y},${slice.width},${slice.height}]',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDeleteSlice(slice.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
