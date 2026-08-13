import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../atlas/atlas_grid.dart';
import '../../../atlas/atlas_pixel_rect.dart';
import '../../../atlas/atlas_selection.dart';
import 'atlas_grid_painter.dart';
import 'atlas_selection_painter.dart';
import 'scene_input_utils.dart';

/// Shared atlas canvas with pixel selection, optional grid snapping, and pan.
class AtlasImageViewport extends StatefulWidget {
  const AtlasImageViewport({
    super.key,
    required this.workspaceRootPath,
    required this.sourceImagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.zoom,
    required this.zoomMin,
    required this.zoomMax,
    required this.zoomStep,
    required this.autoSliceEnabled,
    required this.gridSettings,
    required this.selection,
    required this.horizontalScrollController,
    required this.verticalScrollController,
    required this.onZoomChanged,
    required this.onSelectionChanged,
    this.existingRegions = const <AtlasSelectionOverlay>[],
    this.selectedRegionId,
    this.canvasKey = const ValueKey<String>('atlas_scene_canvas'),
  });

  final String workspaceRootPath;
  final String sourceImagePath;
  final int imageWidth;
  final int imageHeight;
  final double zoom;
  final double zoomMin;
  final double zoomMax;
  final double zoomStep;
  final bool autoSliceEnabled;
  final AtlasGridSettings gridSettings;
  final AtlasPixelRect? selection;
  final List<AtlasSelectionOverlay> existingRegions;
  final String? selectedRegionId;
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<AtlasPixelRect> onSelectionChanged;
  final Key canvasKey;

  @override
  State<AtlasImageViewport> createState() => _AtlasImageViewportState();
}

class _AtlasImageViewportState extends State<AtlasImageViewport> {
  final AtlasGridDragController _gridDrag = AtlasGridDragController();
  Offset? _manualDragStart;
  bool _ctrlPanActive = false;

  @override
  Widget build(BuildContext context) {
    final absolutePath = p.normalize(
      p.join(widget.workspaceRootPath, widget.sourceImagePath),
    );
    final imageFile = File(absolutePath);
    if (!imageFile.existsSync()) {
      return Center(child: Text('Missing image: ${widget.sourceImagePath}'));
    }

    final scaledWidth = widget.imageWidth * widget.zoom;
    final scaledHeight = widget.imageHeight * widget.zoom;
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
          if (widget.autoSliceEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: AtlasGridPainter(
                    zoom: widget.zoom,
                    imageWidth: widget.imageWidth,
                    imageHeight: widget.imageHeight,
                    settings: widget.gridSettings,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: AtlasSelectionPainter(
                  zoom: widget.zoom,
                  selection: widget.selection,
                  existingRegions: widget.existingRegions,
                  selectedRegionId: widget.selectedRegionId,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Listener(
              key: widget.canvasKey,
              onPointerSignal: _onPointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: widget.autoSliceEnabled ? _onAutoSliceTap : null,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: (_) => _finishDrag(),
                onPanCancel: _finishDrag,
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
          controller: widget.verticalScrollController,
          child: SingleChildScrollView(
            controller: widget.horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: stack,
          ),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (SceneInputUtils.isCtrlPressed()) {
      _ctrlPanActive = true;
      return;
    }
    final position = _imagePosition(details.localPosition);
    if (widget.autoSliceEnabled) {
      final rect = _gridDrag.begin(
        settings: widget.gridSettings,
        imageWidth: widget.imageWidth,
        imageHeight: widget.imageHeight,
        x: position.dx,
        y: position.dy,
      );
      if (rect != null) widget.onSelectionChanged(rect);
      return;
    }
    _manualDragStart = position;
  }

  void _onAutoSliceTap(TapDownDetails details) {
    final position = _imagePosition(details.localPosition);
    final rect = _gridDrag.begin(
      settings: widget.gridSettings,
      imageWidth: widget.imageWidth,
      imageHeight: widget.imageHeight,
      x: position.dx,
      y: position.dy,
    );
    _gridDrag.end();
    if (rect != null) widget.onSelectionChanged(rect);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_ctrlPanActive || SceneInputUtils.isCtrlPressed()) {
      SceneInputUtils.panScrollControllers(
        horizontal: widget.horizontalScrollController,
        vertical: widget.verticalScrollController,
        pointerDelta: details.delta,
      );
      return;
    }
    final position = _imagePosition(details.localPosition);
    if (widget.autoSliceEnabled) {
      final rect = _gridDrag.update(
        settings: widget.gridSettings,
        imageWidth: widget.imageWidth,
        imageHeight: widget.imageHeight,
        x: position.dx,
        y: position.dy,
      );
      if (rect != null) widget.onSelectionChanged(rect);
      return;
    }
    final start = _manualDragStart;
    if (start == null) return;
    final state = AtlasSelectionState().withDrag(start, position);
    final rect = state.selectionRect;
    if (rect != null) widget.onSelectionChanged(rect);
  }

  Offset _imagePosition(Offset localPosition) => atlasImagePosition(
    localPosition: localPosition,
    zoom: widget.zoom,
    imageWidth: widget.imageWidth,
    imageHeight: widget.imageHeight,
  );

  void _finishDrag() {
    _ctrlPanActive = false;
    _manualDragStart = null;
    _gridDrag.end();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    final steps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (steps == 0) return;
    widget.onZoomChanged(
      (widget.zoom + (steps * widget.zoomStep))
          .clamp(widget.zoomMin, widget.zoomMax)
          .toDouble(),
    );
  }
}
