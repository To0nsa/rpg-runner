import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../../prefabs/models/models.dart';
import '../../../shared/editor_scene_view_utils.dart';
import '../../../shared/editor_scene_viewport_frame.dart';
import '../../../shared/editor_viewport_grid_painter.dart';
import '../../../shared/editor_zoom_controls.dart';
import '../../../shared/scene_input_utils.dart';
import '../../shared/prefab_overlay_interaction.dart';
import '../../shared/prefab_scene_values.dart';

part 'platform_module_scene_models.dart';

enum PlatformModuleSceneTool { paint, erase, move }

extension PlatformModuleSceneToolLabel on PlatformModuleSceneTool {
  String get label {
    switch (this) {
      case PlatformModuleSceneTool.paint:
        return 'Paint';
      case PlatformModuleSceneTool.erase:
        return 'Erase';
      case PlatformModuleSceneTool.move:
        return 'Move';
    }
  }
}

class PlatformModuleSceneView extends StatefulWidget {
  const PlatformModuleSceneView({
    super.key,
    required this.workspaceRootPath,
    required this.module,
    required this.tileSlices,
    required this.tool,
    required this.selectedTileSliceId,
    required this.onToolChanged,
    required this.onPaintCell,
    required this.onEraseCell,
    required this.onMoveCell,
    this.allowModuleEditing = true,
    this.overlayValues,
    this.onOverlayValuesChanged,
  });

  final String workspaceRootPath;
  final TileModuleDef module;
  final List<AtlasSliceDef> tileSlices;
  final PlatformModuleSceneTool tool;
  final String? selectedTileSliceId;
  final ValueChanged<PlatformModuleSceneTool> onToolChanged;
  final void Function(int gridX, int gridY, String sliceId) onPaintCell;
  final void Function(int gridX, int gridY) onEraseCell;
  final void Function(
    int sourceGridX,
    int sourceGridY,
    int targetGridX,
    int targetGridY,
  )
  onMoveCell;
  final bool allowModuleEditing;
  final PrefabSceneValues? overlayValues;
  final ValueChanged<PrefabSceneValues>? onOverlayValuesChanged;

  @override
  State<PlatformModuleSceneView> createState() =>
      _PlatformModuleSceneViewState();
}

class _PlatformModuleSceneViewState extends State<PlatformModuleSceneView> {
  static const double _minZoom = 0.25;
  static const double _maxZoom = 6.0;
  static const double _zoomStep = 0.1;
  static const double _canvasMargin = 96.0;
  static const double _minimumWorldPaddingPx = 64.0;
  static const double _worldPaddingTileMultiplier = 6.0;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final EditorUiImageCache _imageCache = EditorUiImageCache();

  double _zoom = 2.0;
  bool _ctrlPanActive = false;
  int? _activePointer;
  String? _lastAppliedCellKey;
  PrefabOverlayDragState? _overlayDragState;
  _ModuleCellDragState? _moduleCellDragState;

  @override
  void initState() {
    super.initState();
    _ensureAllSourceImagesLoaded();
  }

  @override
  void didUpdateWidget(covariant PlatformModuleSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        oldWidget.tileSlices != widget.tileSlices) {
      _ensureAllSourceImagesLoaded();
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tileSlicesById = <String, AtlasSliceDef>{
      for (final slice in widget.tileSlices)
        if (slice.id.isNotEmpty) slice.id: slice,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 900.0;
        final viewportHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 520.0;
        final viewportSize = Size(
          math.max(1.0, viewportWidth),
          math.max(1.0, viewportHeight),
        );
        final geometry = _ModuleSceneGeometry(
          module: widget.module,
          tileSlicesById: tileSlicesById,
          viewportSize: viewportSize,
          zoom: _zoom,
          minimumWorldPaddingPx: _minimumWorldPaddingPx,
          worldPaddingTileMultiplier: _worldPaddingTileMultiplier,
          canvasMargin: _canvasMargin,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Scene View',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: EditorZoomControls(
                      value: _zoom,
                      min: _minZoom,
                      max: _maxZoom,
                      step: _zoomStep,
                      onChanged: _setZoom,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.allowModuleEditing) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tool in PlatformModuleSceneTool.values) ...[
                      ChoiceChip(
                        key: ValueKey<String>('module_tool_${tool.name}'),
                        label: Text(tool.label),
                        selected: widget.tool == tool,
                        onSelected: (selected) {
                          if (!selected) {
                            return;
                          }
                          widget.onToolChanged(tool);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: EditorSceneViewportFrame(
                width: viewportSize.width,
                height: viewportSize.height,
                child: _buildScrollableCanvas(
                  geometry: geometry,
                  tileSlicesById: tileSlicesById,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScrollableCanvas({
    required _ModuleSceneGeometry geometry,
    required Map<String, AtlasSliceDef> tileSlicesById,
  }) {
    final canvas = SizedBox(
      width: geometry.canvasSize.width,
      height: geometry.canvasSize.height,
      child: Listener(
        key: const ValueKey<String>('platform_module_scene_canvas'),
        onPointerDown: (event) => _onPointerDown(event, geometry),
        onPointerMove: (event) => _onPointerMove(event, geometry),
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        onPointerSignal: _onPointerSignal,
        child: CustomPaint(
          painter: _PlatformModuleScenePainter(
            workspaceRootPath: widget.workspaceRootPath,
            module: widget.module,
            tileSlicesById: tileSlicesById,
            imageCache: _imageCache,
            loadedImageCount: _imageCache.loadedImageCount,
            geometry: geometry,
            selectedTileSliceId: widget.selectedTileSliceId,
            overlayValues: widget.overlayValues,
            activeOverlayHandle: _overlayDragState?.handle,
            movePreview: _buildMovePreview(),
          ),
        ),
      ),
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        key: const ValueKey<String>('platform_module_scene_vertical_scroll'),
        controller: _verticalScrollController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          key: const ValueKey<String>(
            'platform_module_scene_horizontal_scroll',
          ),
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: canvas,
        ),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event, _ModuleSceneGeometry geometry) {
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      return;
    }
    _activePointer = event.pointer;
    _ctrlPanActive = SceneInputUtils.shouldPanWithPrimaryDrag(event.buttons);
    _lastAppliedCellKey = null;
    if (_ctrlPanActive) {
      return;
    }
    if (_tryStartOverlayDrag(event, geometry)) {
      return;
    }
    if (!widget.allowModuleEditing) {
      return;
    }
    if (widget.tool == PlatformModuleSceneTool.move) {
      _tryStartModuleCellDrag(event.localPosition, geometry);
      return;
    }
    _applyTool(event.localPosition, geometry);
  }

  void _onPointerMove(PointerMoveEvent event, _ModuleSceneGeometry geometry) {
    if (_activePointer != event.pointer) {
      return;
    }
    if (_ctrlPanActive) {
      if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
        _resetPointerState();
        return;
      }
      SceneInputUtils.panScrollControllers(
        horizontal: _horizontalScrollController,
        vertical: _verticalScrollController,
        pointerDelta: event.delta,
      );
      return;
    }
    final overlayDrag = _overlayDragState;
    if (overlayDrag != null) {
      if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
        _resetPointerState();
        return;
      }
      final onOverlayValuesChanged = widget.onOverlayValuesChanged;
      if (onOverlayValuesChanged != null) {
        onOverlayValuesChanged(
          PrefabOverlayInteraction.valuesFromDrag(
            drag: overlayDrag,
            currentLocal: event.localPosition,
          ),
        );
      }
      return;
    }
    if (!widget.allowModuleEditing) {
      if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
        _resetPointerState();
      }
      return;
    }
    final moduleCellDrag = _moduleCellDragState;
    if (moduleCellDrag != null) {
      if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
        _commitModuleCellDrag();
        _resetPointerState();
        return;
      }
      _updateModuleCellDragTarget(event.localPosition, geometry);
      return;
    }
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      _resetPointerState();
      return;
    }
    _applyTool(event.localPosition, geometry);
  }

  void _onPointerEnd(PointerEvent _) {
    _commitModuleCellDrag();
    _resetPointerState();
  }

  void _resetPointerState() {
    final hadOverlayDrag = _overlayDragState != null;
    final hadModuleCellDrag = _moduleCellDragState != null;
    _ctrlPanActive = false;
    _activePointer = null;
    _lastAppliedCellKey = null;
    _overlayDragState = null;
    _moduleCellDragState = null;
    if (hadOverlayDrag || hadModuleCellDrag) {
      setState(() {});
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    final signedSteps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (signedSteps == 0) {
      return;
    }
    _setZoom(_zoom + (signedSteps * _zoomStep));
  }

  void _setZoom(double value) {
    final next = EditorSceneViewUtils.snapZoom(
      value: value,
      min: _minZoom,
      max: _maxZoom,
      step: _zoomStep,
    );
    if (EditorSceneViewUtils.zoomValuesEqual(next, _zoom)) {
      return;
    }
    setState(() {
      _zoom = next;
    });
  }

  void _applyTool(Offset localPosition, _ModuleSceneGeometry geometry) {
    final cell = geometry.gridCellFromLocal(localPosition);
    if (cell == null) {
      return;
    }
    final key = '${cell.gridX}:${cell.gridY}';
    if (key == _lastAppliedCellKey) {
      return;
    }
    _lastAppliedCellKey = key;

    switch (widget.tool) {
      case PlatformModuleSceneTool.paint:
        final sliceId = widget.selectedTileSliceId;
        if (sliceId == null || sliceId.isEmpty) {
          return;
        }
        widget.onPaintCell(cell.gridX, cell.gridY, sliceId);
      case PlatformModuleSceneTool.erase:
        widget.onEraseCell(cell.gridX, cell.gridY);
      case PlatformModuleSceneTool.move:
        return;
    }
  }

  _PlatformModuleSceneMovePreview? _buildMovePreview() {
    final drag = _moduleCellDragState;
    if (drag == null) {
      return null;
    }
    return _PlatformModuleSceneMovePreview(
      sourceGridX: drag.sourceGridX,
      sourceGridY: drag.sourceGridY,
      targetGridX: drag.targetGridX,
      targetGridY: drag.targetGridY,
      sliceId: drag.sliceId,
    );
  }

  void _commitModuleCellDrag() {
    final drag = _moduleCellDragState;
    if (drag == null) {
      return;
    }
    if (drag.sourceGridX == drag.targetGridX &&
        drag.sourceGridY == drag.targetGridY) {
      return;
    }
    widget.onMoveCell(
      drag.sourceGridX,
      drag.sourceGridY,
      drag.targetGridX,
      drag.targetGridY,
    );
  }

  void _tryStartModuleCellDrag(
    Offset localPosition,
    _ModuleSceneGeometry geometry,
  ) {
    final pointerWorld = geometry.worldFromLocal(localPosition);
    final hitCell = geometry.moduleCellHitFromLocal(localPosition);
    if (pointerWorld == null || hitCell == null) {
      return;
    }
    final sourceOriginWorld = Offset(
      hitCell.gridX * geometry.tilePixels,
      hitCell.gridY * geometry.tilePixels,
    );
    setState(() {
      _moduleCellDragState = _ModuleCellDragState(
        sourceGridX: hitCell.gridX,
        sourceGridY: hitCell.gridY,
        targetGridX: hitCell.gridX,
        targetGridY: hitCell.gridY,
        sliceId: hitCell.sliceId,
        grabOffsetWorld: pointerWorld - sourceOriginWorld,
      );
    });
  }

  void _updateModuleCellDragTarget(
    Offset localPosition,
    _ModuleSceneGeometry geometry,
  ) {
    final drag = _moduleCellDragState;
    if (drag == null) {
      return;
    }
    final pointerWorld = geometry.worldFromLocal(localPosition);
    if (pointerWorld == null) {
      return;
    }
    final candidateOrigin = pointerWorld - drag.grabOffsetWorld;
    final tileSize = geometry.tilePixels;
    final targetGridX = (candidateOrigin.dx / tileSize).floor();
    final targetGridY = (candidateOrigin.dy / tileSize).floor();
    if (targetGridX == drag.targetGridX && targetGridY == drag.targetGridY) {
      return;
    }
    setState(() {
      _moduleCellDragState = drag.copyWith(
        targetGridX: targetGridX,
        targetGridY: targetGridY,
      );
    });
  }

  bool _tryStartOverlayDrag(
    PointerDownEvent event,
    _ModuleSceneGeometry geometry,
  ) {
    final values = widget.overlayValues;
    final onOverlayValuesChanged = widget.onOverlayValuesChanged;
    final moduleBounds = geometry.moduleBoundsWorld;
    if (values == null ||
        onOverlayValuesChanged == null ||
        moduleBounds == null) {
      return false;
    }
    final handleGeometry = PrefabOverlayHandleGeometry.fromValues(
      values: values,
      anchorCanvasBase: geometry.canvasFromWorld(moduleBounds.topLeft),
      zoom: geometry.zoom,
    );
    final handle = PrefabOverlayHitTest.hitTestHandle(
      point: event.localPosition,
      geometry: handleGeometry,
      anchorHandleHitRadius: 10,
      colliderHandleHitRadius: 12,
    );
    if (handle == null) {
      return false;
    }
    final boundsWidth = moduleBounds.width.round().clamp(1, 99999);
    final boundsHeight = moduleBounds.height.round().clamp(1, 99999);
    setState(() {
      _overlayDragState = PrefabOverlayDragState(
        pointer: event.pointer,
        handle: handle,
        startLocal: event.localPosition,
        startValues: values,
        zoom: geometry.zoom,
        boundsWidthPx: boundsWidth,
        boundsHeightPx: boundsHeight,
      );
    });
    return true;
  }

  void _ensureAllSourceImagesLoaded() {
    for (final slice in widget.tileSlices) {
      final sourcePath = slice.sourceImagePath.trim();
      if (sourcePath.isEmpty) {
        continue;
      }
      _ensureImageLoadedForSource(sourcePath);
    }
  }

  void _ensureImageLoadedForSource(String sourcePath) {
    final absolutePath = _absoluteImagePath(sourcePath);
    () async {
      final image = await _imageCache.ensureLoaded(absolutePath);
      if (!mounted || image == null) {
        return;
      }
      setState(() {});
    }();
  }

  String _absoluteImagePath(String sourceImagePath) {
    return p.normalize(p.join(widget.workspaceRootPath, sourceImagePath));
  }
}
