import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../prefabs/prefab_models.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_viewport_grid_painter.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/scene_input_utils.dart';
import 'prefab_overlay_interaction.dart';
import 'prefab_scene_values.dart';

enum PlatformModuleSceneTool { paint, erase }

extension PlatformModuleSceneToolLabel on PlatformModuleSceneTool {
  String get label {
    switch (this) {
      case PlatformModuleSceneTool.paint:
        return 'Paint';
      case PlatformModuleSceneTool.erase:
        return 'Erase';
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
    required this.onPaintCell,
    required this.onEraseCell,
    this.overlayValues,
    this.onOverlayValuesChanged,
  });

  final String workspaceRootPath;
  final TileModuleDef module;
  final List<AtlasSliceDef> tileSlices;
  final PlatformModuleSceneTool tool;
  final String? selectedTileSliceId;
  final void Function(int gridX, int gridY, String sliceId) onPaintCell;
  final void Function(int gridX, int gridY) onEraseCell;
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
  final Map<String, ui.Image> _imageCache = <String, ui.Image>{};
  final Set<String> _imageLoading = <String>{};

  double _zoom = 2.0;
  bool _ctrlPanActive = false;
  int? _activePointer;
  String? _lastAppliedCellKey;
  PrefabOverlayDragState? _overlayDragState;

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
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
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
                EditorZoomControls(
                  value: _zoom,
                  min: _minZoom,
                  max: _maxZoom,
                  step: _zoomStep,
                  onChanged: _setZoom,
                ),
              ],
            ),
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
            imageByAbsolutePath: _imageCache,
            geometry: geometry,
            selectedTileSliceId: widget.selectedTileSliceId,
            overlayValues: widget.overlayValues,
            activeOverlayHandle: _overlayDragState?.handle,
          ),
        ),
      ),
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
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
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      _resetPointerState();
      return;
    }
    _applyTool(event.localPosition, geometry);
  }

  void _onPointerEnd(PointerEvent _) {
    _resetPointerState();
  }

  void _resetPointerState() {
    final hadOverlayDrag = _overlayDragState != null;
    _ctrlPanActive = false;
    _activePointer = null;
    _lastAppliedCellKey = null;
    _overlayDragState = null;
    if (hadOverlayDrag) {
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
    final snapped = (value / _zoomStep).roundToDouble() * _zoomStep;
    final next = snapped.clamp(_minZoom, _maxZoom).toDouble();
    if ((next - _zoom).abs() < 0.000001) {
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
    }
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
    if (_imageCache.containsKey(absolutePath) ||
        _imageLoading.contains(absolutePath)) {
      return;
    }
    _imageLoading.add(absolutePath);
    () async {
      try {
        final file = File(absolutePath);
        if (!file.existsSync()) {
          return;
        }
        final bytes = await file.readAsBytes();
        final image = await _decodeImage(bytes);
        if (!mounted) {
          image.dispose();
          return;
        }
        setState(() {
          _imageCache[absolutePath] = image;
        });
      } finally {
        _imageLoading.remove(absolutePath);
      }
    }();
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    return ui.instantiateImageCodec(bytes).then((codec) async {
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });
  }

  String _absoluteImagePath(String sourceImagePath) {
    return p.normalize(p.join(widget.workspaceRootPath, sourceImagePath));
  }
}

class _GridCell {
  const _GridCell({required this.gridX, required this.gridY});

  final int gridX;
  final int gridY;
}

class _ModuleSceneGeometry {
  _ModuleSceneGeometry({
    required this.module,
    required this.tileSlicesById,
    required this.viewportSize,
    required this.zoom,
    required this.minimumWorldPaddingPx,
    required this.worldPaddingTileMultiplier,
    required this.canvasMargin,
  }) : tilePixels = module.tileSize <= 0 ? 16.0 : module.tileSize.toDouble() {
    moduleBoundsWorld = _computeModuleBoundsWorld();
    final moduleBounds =
        moduleBoundsWorld ??
        Rect.fromCenter(
          center: Offset.zero,
          width: tilePixels,
          height: tilePixels,
        );
    final padding = math.max(
      minimumWorldPaddingPx,
      tilePixels * worldPaddingTileMultiplier,
    );
    worldRect = Rect.fromLTRB(
      math.min(0.0, moduleBounds.left) - padding,
      math.min(0.0, moduleBounds.top) - padding,
      math.max(tilePixels, moduleBounds.right) + padding,
      math.max(tilePixels, moduleBounds.bottom) + padding,
    );

    final worldWidthPixels = worldRect.width * zoom;
    final worldHeightPixels = worldRect.height * zoom;
    final desiredWidth = worldWidthPixels + (canvasMargin * 2);
    final desiredHeight = worldHeightPixels + (canvasMargin * 2);
    canvasSize = Size(
      math.max(viewportSize.width, desiredWidth),
      math.max(viewportSize.height, desiredHeight),
    );
    worldOrigin = Offset(
      (canvasSize.width - worldWidthPixels) * 0.5,
      (canvasSize.height - worldHeightPixels) * 0.5,
    );
    worldCanvasRect = Rect.fromLTWH(
      worldOrigin.dx,
      worldOrigin.dy,
      worldWidthPixels,
      worldHeightPixels,
    );
  }

  final TileModuleDef module;
  final Map<String, AtlasSliceDef> tileSlicesById;
  final Size viewportSize;
  final double zoom;
  final double minimumWorldPaddingPx;
  final double worldPaddingTileMultiplier;
  final double canvasMargin;
  final double tilePixels;
  late final Rect worldRect;
  late final Size canvasSize;
  late final Offset worldOrigin;
  late final Rect worldCanvasRect;
  late final Rect? moduleBoundsWorld;

  _GridCell? gridCellFromLocal(Offset localPosition) {
    if (module.tileSize <= 0) {
      return null;
    }
    final world = worldFromLocal(localPosition);
    if (world == null) {
      return null;
    }
    final tileSize = module.tileSize.toDouble();
    return _GridCell(
      gridX: (world.dx / tileSize).floor(),
      gridY: (world.dy / tileSize).floor(),
    );
  }

  Offset canvasFromWorld(Offset world) {
    final localX = (world.dx - worldRect.left) * zoom;
    final localY = (world.dy - worldRect.top) * zoom;
    return Offset(worldOrigin.dx + localX, worldOrigin.dy + localY);
  }

  Rect canvasRectFromWorld(Rect world) {
    final topLeft = canvasFromWorld(world.topLeft);
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      world.width * zoom,
      world.height * zoom,
    );
  }

  Offset? worldFromLocal(Offset local) {
    if (!worldCanvasRect.contains(local)) {
      return null;
    }
    final worldX = worldRect.left + ((local.dx - worldOrigin.dx) / zoom);
    final worldY = worldRect.top + ((local.dy - worldOrigin.dy) / zoom);
    return Offset(worldX, worldY);
  }

  Rect worldRectForCell(TileModuleCellDef cell) {
    final tileSize = tilePixels;
    final slice = tileSlicesById[cell.sliceId];
    final width = math.max(1, slice?.width ?? tileSize.toInt()).toDouble();
    final height = math.max(1, slice?.height ?? tileSize.toInt()).toDouble();
    return Rect.fromLTWH(
      cell.gridX * tileSize,
      cell.gridY * tileSize,
      width,
      height,
    );
  }

  Rect? _computeModuleBoundsWorld() {
    if (module.cells.isEmpty) {
      return null;
    }
    Rect? bounds;
    for (final cell in module.cells) {
      final rect = worldRectForCell(cell);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    return bounds;
  }
}

class _PlatformModuleScenePainter extends CustomPainter {
  const _PlatformModuleScenePainter({
    required this.workspaceRootPath,
    required this.module,
    required this.tileSlicesById,
    required this.imageByAbsolutePath,
    required this.geometry,
    required this.selectedTileSliceId,
    required this.overlayValues,
    required this.activeOverlayHandle,
  });

  final String workspaceRootPath;
  final TileModuleDef module;
  final Map<String, AtlasSliceDef> tileSlicesById;
  final Map<String, ui.Image> imageByAbsolutePath;
  final _ModuleSceneGeometry geometry;
  final String? selectedTileSliceId;
  final PrefabSceneValues? overlayValues;
  final PrefabOverlayHandleType? activeOverlayHandle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF111A22),
    );

    canvas.drawRect(
      geometry.worldCanvasRect,
      Paint()
        ..color = const Color(0xFF0D131A)
        ..style = PaintingStyle.fill,
    );
    EditorViewportGridPainter(zoom: geometry.zoom).paint(canvas, size);

    if (geometry.moduleBoundsWorld != null) {
      canvas.drawRect(
        geometry.canvasRectFromWorld(geometry.moduleBoundsWorld!),
        Paint()
          ..color = const Color(0x447CE5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    for (final cell in module.cells) {
      final slice = tileSlicesById[cell.sliceId];
      final worldRect = geometry.worldRectForCell(cell);
      final canvasRect = geometry.canvasRectFromWorld(worldRect);
      final image = slice == null ? null : _resolveSliceImage(slice);

      if (slice != null && image != null) {
        final srcRect = Rect.fromLTWH(
          slice.x.toDouble(),
          slice.y.toDouble(),
          slice.width.toDouble(),
          slice.height.toDouble(),
        );
        canvas.drawImageRect(
          image,
          srcRect,
          canvasRect,
          Paint()..filterQuality = FilterQuality.none,
        );
      } else {
        canvas.drawRect(
          canvasRect,
          Paint()
            ..color = slice == null
                ? const Color(0xFF7A2A2A)
                : _fallbackColorForSlice(cell.sliceId)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawRect(
        canvasRect,
        Paint()
          ..color = const Color(0xFF9CC6E4)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );

      if (cell.sliceId == selectedTileSliceId) {
        canvas.drawRect(
          canvasRect.inflate(0.8),
          Paint()
            ..color = const Color(0xFFFFD166)
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke,
        );
      }
    }

    _paintAnchorColliderOverlay(canvas);
  }

  void _paintAnchorColliderOverlay(Canvas canvas) {
    final values = overlayValues;
    final moduleBounds = geometry.moduleBoundsWorld;
    if (values == null || moduleBounds == null) {
      return;
    }
    final overlayGeometry = PrefabOverlayHandleGeometry.fromValues(
      values: values,
      anchorCanvasBase: geometry.canvasFromWorld(moduleBounds.topLeft),
      zoom: geometry.zoom,
    );
    PrefabOverlayPainter.paint(
      canvas: canvas,
      geometry: overlayGeometry,
      activeHandle: activeOverlayHandle,
    );
  }

  ui.Image? _resolveSliceImage(AtlasSliceDef slice) {
    final absolutePath = p.normalize(
      p.join(workspaceRootPath, slice.sourceImagePath),
    );
    return imageByAbsolutePath[absolutePath];
  }

  Color _fallbackColorForSlice(String sliceId) {
    var hash = 0;
    for (final code in sliceId.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.45, 0.85).toColor();
  }

  @override
  bool shouldRepaint(covariant _PlatformModuleScenePainter oldDelegate) {
    return oldDelegate.module != module ||
        oldDelegate.geometry.zoom != geometry.zoom ||
        oldDelegate.selectedTileSliceId != selectedTileSliceId ||
        oldDelegate.overlayValues != overlayValues ||
        oldDelegate.activeOverlayHandle != activeOverlayHandle ||
        oldDelegate.tileSlicesById.length != tileSlicesById.length ||
        oldDelegate.imageByAbsolutePath.length != imageByAbsolutePath.length;
  }
}
