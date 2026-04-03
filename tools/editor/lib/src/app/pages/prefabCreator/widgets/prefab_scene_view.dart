import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../prefabs/prefab_models.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_viewport_grid_painter.dart';
import '../../shared/scene_input_utils.dart';
import 'prefab_overlay_interaction.dart';
import 'prefab_scene_values.dart';

class PrefabSceneView extends StatefulWidget {
  const PrefabSceneView({
    super.key,
    required this.workspaceRootPath,
    required this.slice,
    required this.values,
    required this.onChanged,
  });

  final String workspaceRootPath;
  final AtlasSliceDef slice;
  final PrefabSceneValues values;
  final ValueChanged<PrefabSceneValues> onChanged;

  @override
  State<PrefabSceneView> createState() => _PrefabSceneViewState();
}

class _PrefabSceneViewState extends State<PrefabSceneView> {
  static const double _maxViewportWidth = 800;
  static const double _preferredViewportHeight = 620;
  static const double _canvasMargin = 128;
  static const double _minZoom = 0.2;
  static const double _maxZoom = 12.0;
  static const double _zoomStep = 0.1;
  static const double _zoomEpsilon = 0.000001;
  static const double _anchorHandleHitRadius = 10;
  static const double _colliderHandleHitRadius = 12;

  final Map<String, ui.Image> _imageCache = <String, ui.Image>{};
  final Set<String> _imageLoading = <String>{};
  PrefabOverlayDragState? _dragState;
  bool _ctrlPanActive = false;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  double _zoom = 3.0;

  @override
  void initState() {
    super.initState();
    _ensureImageLoaded();
  }

  @override
  void didUpdateWidget(covariant PrefabSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slice.sourceImagePath != widget.slice.sourceImagePath ||
        oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _ensureImageLoaded();
    }
  }

  @override
  void dispose() {
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final absolutePath = _absoluteImagePath();
    final image = _imageCache[absolutePath];
    final imageExists = File(absolutePath).existsSync();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? math.min(_maxViewportWidth, constraints.maxWidth)
            : _maxViewportWidth;
        final hasBoundedHeight = constraints.maxHeight.isFinite;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: viewportWidth,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Prefab Scene View',
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
                ),
                const SizedBox(height: 8),
                Text(
                  'Slice: ${widget.slice.id} '
                  '[${widget.slice.width}x${widget.slice.height}]',
                ),
                const SizedBox(height: 8),
                if (hasBoundedHeight)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, viewportConstraints) {
                        final viewportHeight = viewportConstraints.maxHeight
                            .clamp(1.0, double.infinity)
                            .toDouble();
                        return _buildViewport(
                          viewportWidth: viewportWidth,
                          viewportHeight: viewportHeight,
                          image: image,
                          imageExists: imageExists,
                        );
                      },
                    ),
                  )
                else
                  _buildViewport(
                    viewportWidth: viewportWidth,
                    viewportHeight: _preferredViewportHeight,
                    image: image,
                    imageExists: imageExists,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewport({
    required double viewportWidth,
    required double viewportHeight,
    required ui.Image? image,
    required bool imageExists,
  }) {
    final safeHeight = math.max(1.0, viewportHeight);
    final viewportSize = Size(viewportWidth, safeHeight);
    final canvasSize = _sceneCanvasSize(viewportSize);
    return EditorSceneViewportFrame(
      width: viewportWidth,
      height: safeHeight,
      child: _buildScrollableSceneCanvas(
        canvasSize: canvasSize,
        image: image,
        imageExists: imageExists,
      ),
    );
  }

  Size _sceneCanvasSize(Size viewportSize) {
    final spriteWidth = widget.slice.width * _zoom;
    final spriteHeight = widget.slice.height * _zoom;
    final desiredWidth = spriteWidth + (_canvasMargin * 2);
    final desiredHeight = spriteHeight + (_canvasMargin * 2);
    return Size(
      math.max(viewportSize.width, desiredWidth),
      math.max(viewportSize.height, desiredHeight),
    );
  }

  Widget _buildScrollableSceneCanvas({
    required Size canvasSize,
    required ui.Image? image,
    required bool imageExists,
  }) {
    final canvas = SizedBox(
      width: canvasSize.width,
      height: canvasSize.height,
      child: _buildSceneCanvas(
        canvasSize: canvasSize,
        image: image,
        imageExists: imageExists,
      ),
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        key: const ValueKey<String>('prefab_scene_vertical_scroll'),
        controller: _verticalScrollController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          key: const ValueKey<String>('prefab_scene_horizontal_scroll'),
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: canvas,
        ),
      ),
    );
  }

  Widget _buildSceneCanvas({
    required Size canvasSize,
    required ui.Image? image,
    required bool imageExists,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1B2A36)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFF111A22))),
          CustomPaint(painter: EditorViewportGridPainter(zoom: _zoom)),
          if (!imageExists)
            Center(
              child: Text('Missing image: ${widget.slice.sourceImagePath}'),
            )
          else
            Listener(
              key: const ValueKey<String>('prefab_scene_canvas'),
              onPointerDown: (event) {
                _onPointerDown(event, canvasSize: canvasSize);
              },
              onPointerMove: (event) {
                _onPointerMove(event);
              },
              onPointerUp: (event) {
                _onPointerEnd(event);
              },
              onPointerCancel: (event) {
                _onPointerEnd(event);
              },
              onPointerSignal: _onPointerSignal,
              child: image == null
                  ? const Center(child: Text('Loading slice image...'))
                  : CustomPaint(
                      painter: _PrefabScenePainter(
                        image: image,
                        slice: widget.slice,
                        values: widget.values,
                        zoom: _zoom,
                        activeHandle: _dragState?.handle,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  String _absoluteImagePath() {
    return p.normalize(
      p.join(widget.workspaceRootPath, widget.slice.sourceImagePath),
    );
  }

  Future<void> _ensureImageLoaded() async {
    final absolutePath = _absoluteImagePath();
    if (_imageCache.containsKey(absolutePath) ||
        _imageLoading.contains(absolutePath)) {
      return;
    }
    _imageLoading.add(absolutePath);
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
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final codecFuture = ui.instantiateImageCodec(bytes);
    return codecFuture.then((codec) async {
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });
  }

  void _onPointerDown(PointerDownEvent event, {required Size canvasSize}) {
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      return;
    }
    _ctrlPanActive = SceneInputUtils.shouldPanWithPrimaryDrag(event.buttons);
    if (_ctrlPanActive) {
      _dragState = null;
      return;
    }
    final hit = _hitTestHandle(event.localPosition, canvasSize: canvasSize);
    if (hit == null) {
      return;
    }
    setState(() {
      _dragState = PrefabOverlayDragState(
        pointer: event.pointer,
        handle: hit,
        startLocal: event.localPosition,
        startValues: widget.values,
        zoom: _zoom,
        boundsWidthPx: widget.slice.width,
        boundsHeightPx: widget.slice.height,
      );
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final drag = _dragState;
    if (drag == null || drag.pointer != event.pointer) {
      if (!_ctrlPanActive) {
        return;
      }
      if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
        _ctrlPanActive = false;
        return;
      }
      SceneInputUtils.panScrollControllers(
        horizontal: _horizontalScrollController,
        vertical: _verticalScrollController,
        pointerDelta: event.delta,
      );
      return;
    }
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      setState(() {
        _dragState = null;
      });
      return;
    }
    final next = PrefabOverlayInteraction.valuesFromDrag(
      drag: drag,
      currentLocal: event.localPosition,
    );
    widget.onChanged(next);
  }

  void _onPointerEnd(PointerEvent event) {
    final drag = _dragState;
    if (drag != null && drag.pointer == event.pointer) {
      setState(() {
        _dragState = null;
      });
    }
    _ctrlPanActive = false;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    final signedSteps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (signedSteps == 0) {
      return;
    }
    final steps = signedSteps.abs();
    for (var i = 0; i < steps; i += 1) {
      if (signedSteps > 0) {
        _zoomIn();
      } else {
        _zoomOut();
      }
    }
  }

  void _zoomIn() {
    _setZoom(_zoom + _zoomStep);
  }

  void _zoomOut() {
    _setZoom(_zoom - _zoomStep);
  }

  void _setZoom(double value) {
    final snapped = (value / _zoomStep).roundToDouble() * _zoomStep;
    final next = snapped.clamp(_minZoom, _maxZoom).toDouble();
    if ((next - _zoom).abs() <= _zoomEpsilon) {
      return;
    }
    setState(() {
      _zoom = next;
    });
    _scheduleViewportCentering();
  }

  void _scheduleViewportCentering() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_horizontalScrollController.hasClients ||
          !_verticalScrollController.hasClients) {
        return;
      }
      final horizontalPosition = _horizontalScrollController.position;
      final verticalPosition = _verticalScrollController.position;
      final targetX = horizontalPosition.maxScrollExtent * 0.5;
      final targetY = verticalPosition.maxScrollExtent * 0.5;
      _horizontalScrollController.jumpTo(targetX);
      _verticalScrollController.jumpTo(targetY);
    });
  }

  PrefabOverlayHandleType? _hitTestHandle(
    Offset point, {
    required Size canvasSize,
  }) {
    final geometry = _PrefabSceneGeometry(
      slice: widget.slice,
      zoom: _zoom,
      viewportSize: canvasSize,
    );
    final overlayGeometry = PrefabOverlayHandleGeometry.fromValues(
      values: widget.values,
      anchorCanvasBase: geometry.spriteRect.topLeft,
      zoom: _zoom,
    );
    return PrefabOverlayHitTest.hitTestHandle(
      point: point,
      geometry: overlayGeometry,
      anchorHandleHitRadius: _anchorHandleHitRadius,
      colliderHandleHitRadius: _colliderHandleHitRadius,
    );
  }
}

class _PrefabScenePainter extends CustomPainter {
  const _PrefabScenePainter({
    required this.image,
    required this.slice,
    required this.values,
    required this.zoom,
    required this.activeHandle,
  });

  final ui.Image image;
  final AtlasSliceDef slice;
  final PrefabSceneValues values;
  final double zoom;
  final PrefabOverlayHandleType? activeHandle;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _PrefabSceneGeometry(
      slice: slice,
      zoom: zoom,
      viewportSize: size,
    );

    final srcRect = Rect.fromLTWH(
      slice.x.toDouble(),
      slice.y.toDouble(),
      slice.width.toDouble(),
      slice.height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      srcRect,
      geometry.spriteRect,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true,
    );

    final spriteBorder = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(geometry.spriteRect, spriteBorder);

    final overlayGeometry = PrefabOverlayHandleGeometry.fromValues(
      values: values,
      anchorCanvasBase: geometry.spriteRect.topLeft,
      zoom: zoom,
    );
    PrefabOverlayPainter.paint(
      canvas: canvas,
      geometry: overlayGeometry,
      activeHandle: activeHandle,
    );
  }

  @override
  bool shouldRepaint(covariant _PrefabScenePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.slice != slice ||
        oldDelegate.values != values ||
        oldDelegate.zoom != zoom ||
        oldDelegate.activeHandle != activeHandle;
  }
}

class _PrefabSceneGeometry {
  _PrefabSceneGeometry({
    required AtlasSliceDef slice,
    required this.zoom,
    required Size viewportSize,
  }) {
    final width = slice.width * zoom;
    final height = slice.height * zoom;
    final center = Offset(viewportSize.width * 0.5, viewportSize.height * 0.5);
    spriteRect = Rect.fromCenter(center: center, width: width, height: height);
  }

  final double zoom;
  late final Rect spriteRect;
}
