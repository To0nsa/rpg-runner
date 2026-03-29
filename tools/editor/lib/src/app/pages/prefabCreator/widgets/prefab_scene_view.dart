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

class PrefabSceneValues {
  const PrefabSceneValues({
    required this.anchorX,
    required this.anchorY,
    required this.colliderOffsetX,
    required this.colliderOffsetY,
    required this.colliderWidth,
    required this.colliderHeight,
  });

  final int anchorX;
  final int anchorY;
  final int colliderOffsetX;
  final int colliderOffsetY;
  final int colliderWidth;
  final int colliderHeight;
}

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

enum _SceneHandleType { anchor, colliderCenter, colliderTop, colliderRight }

class _DragState {
  const _DragState({
    required this.pointer,
    required this.handle,
    required this.startLocal,
    required this.startValues,
    required this.zoom,
  });

  final int pointer;
  final _SceneHandleType handle;
  final Offset startLocal;
  final PrefabSceneValues startValues;
  final double zoom;
}

class _PrefabSceneViewState extends State<PrefabSceneView> {
  static const double _maxViewportWidth = 800;
  static const double _preferredViewportHeight = 500;
  static const double _canvasMargin = 128;
  static const double _minZoom = 0.2;
  static const double _maxZoom = 12.0;
  static const double _zoomStep = 0.1;
  static const double _zoomEpsilon = 0.000001;
  static const double _anchorHandleHitRadius = 10;
  static const double _colliderHandleHitRadius = 12;

  final Map<String, ui.Image> _imageCache = <String, ui.Image>{};
  final Set<String> _imageLoading = <String>{};
  _DragState? _dragState;
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
          else if (image == null)
            const Center(child: Text('Loading slice image...'))
          else
            Listener(
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
              child: CustomPaint(
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
    if ((event.buttons & kPrimaryButton) == 0) {
      return;
    }
    _ctrlPanActive = SceneInputUtils.isCtrlPressed();
    if (_ctrlPanActive) {
      _dragState = null;
      return;
    }
    final hit = _hitTestHandle(event.localPosition, canvasSize: canvasSize);
    if (hit == null) {
      return;
    }
    setState(() {
      _dragState = _DragState(
        pointer: event.pointer,
        handle: hit,
        startLocal: event.localPosition,
        startValues: widget.values,
        zoom: _zoom,
      );
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final drag = _dragState;
    if (drag == null || drag.pointer != event.pointer) {
      if (!_ctrlPanActive) {
        return;
      }
      if ((event.buttons & kPrimaryButton) == 0) {
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
    if ((event.buttons & kPrimaryButton) == 0) {
      setState(() {
        _dragState = null;
      });
      return;
    }
    final next = _valuesFromDrag(drag: drag, currentLocal: event.localPosition);
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
    if (event is! PointerScrollEvent) {
      return;
    }
    if (!SceneInputUtils.isCtrlPressed()) {
      return;
    }
    final deltaY = event.scrollDelta.dy;
    final steps = SceneInputUtils.zoomStepsFromScrollDeltaY(deltaY);
    if (steps < 1) {
      return;
    }
    for (var i = 0; i < steps; i += 1) {
      if (deltaY < 0) {
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

  PrefabSceneValues _valuesFromDrag({
    required _DragState drag,
    required Offset currentLocal,
  }) {
    final delta = currentLocal - drag.startLocal;
    final deltaX = delta.dx / drag.zoom;
    final deltaY = delta.dy / drag.zoom;
    final start = drag.startValues;
    final slice = widget.slice;

    switch (drag.handle) {
      case _SceneHandleType.anchor:
        final anchorX = (start.anchorX + deltaX).round().clamp(0, slice.width);
        final anchorY = (start.anchorY + deltaY).round().clamp(0, slice.height);
        return PrefabSceneValues(
          anchorX: anchorX,
          anchorY: anchorY,
          colliderOffsetX: start.colliderOffsetX,
          colliderOffsetY: start.colliderOffsetY,
          colliderWidth: start.colliderWidth,
          colliderHeight: start.colliderHeight,
        );
      case _SceneHandleType.colliderCenter:
        return PrefabSceneValues(
          anchorX: start.anchorX,
          anchorY: start.anchorY,
          colliderOffsetX: (start.colliderOffsetX + deltaX).round(),
          colliderOffsetY: (start.colliderOffsetY + deltaY).round(),
          colliderWidth: start.colliderWidth,
          colliderHeight: start.colliderHeight,
        );
      case _SceneHandleType.colliderTop:
        final startCenterY = start.anchorY + start.colliderOffsetY;
        final startHalfH = start.colliderHeight * 0.5;
        final bottom = startCenterY + startHalfH;
        var nextTop = (startCenterY - startHalfH) + deltaY;
        if (nextTop > bottom - 1) {
          nextTop = bottom - 1;
        }
        final nextHalf = (bottom - nextTop) * 0.5;
        final nextCenterY = nextTop + nextHalf;
        return PrefabSceneValues(
          anchorX: start.anchorX,
          anchorY: start.anchorY,
          colliderOffsetX: start.colliderOffsetX,
          colliderOffsetY: (nextCenterY - start.anchorY).round(),
          colliderWidth: start.colliderWidth,
          colliderHeight: (nextHalf * 2).round().clamp(1, 99999),
        );
      case _SceneHandleType.colliderRight:
        final startCenterX = start.anchorX + start.colliderOffsetX;
        final startHalfW = start.colliderWidth * 0.5;
        final left = startCenterX - startHalfW;
        var nextRight = (startCenterX + startHalfW) + deltaX;
        if (nextRight < left + 1) {
          nextRight = left + 1;
        }
        final nextHalf = (nextRight - left) * 0.5;
        final nextCenterX = left + nextHalf;
        return PrefabSceneValues(
          anchorX: start.anchorX,
          anchorY: start.anchorY,
          colliderOffsetX: (nextCenterX - start.anchorX).round(),
          colliderOffsetY: start.colliderOffsetY,
          colliderWidth: (nextHalf * 2).round().clamp(1, 99999),
          colliderHeight: start.colliderHeight,
        );
    }
  }

  _SceneHandleType? _hitTestHandle(Offset point, {required Size canvasSize}) {
    final geometry = _PrefabSceneGeometry(
      slice: widget.slice,
      values: widget.values,
      zoom: _zoom,
      viewportSize: canvasSize,
    );
    if (_distanceSquared(point, geometry.anchorHandleCenter) <=
        _anchorHandleHitRadius * _anchorHandleHitRadius) {
      return _SceneHandleType.anchor;
    }
    if (_distanceSquared(point, geometry.colliderCenterHandle) <=
        _colliderHandleHitRadius * _colliderHandleHitRadius) {
      return _SceneHandleType.colliderCenter;
    }
    if (_distanceSquared(point, geometry.colliderTopHandle) <=
        _colliderHandleHitRadius * _colliderHandleHitRadius) {
      return _SceneHandleType.colliderTop;
    }
    if (_distanceSquared(point, geometry.colliderRightHandle) <=
        _colliderHandleHitRadius * _colliderHandleHitRadius) {
      return _SceneHandleType.colliderRight;
    }
    return null;
  }

  double _distanceSquared(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return dx * dx + dy * dy;
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
  final _SceneHandleType? activeHandle;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _PrefabSceneGeometry(
      slice: slice,
      values: values,
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

    final colliderFill = Paint()
      ..color = const Color(0x4422D3EE)
      ..style = PaintingStyle.fill;
    final colliderStroke = Paint()
      ..color = const Color(0xFF7CE5FF)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawRect(geometry.colliderRect, colliderFill);
    canvas.drawRect(geometry.colliderRect, colliderStroke);

    final anchorCross = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 1.6;
    const arm = 6.0;
    canvas.drawLine(
      Offset(
        geometry.anchorHandleCenter.dx - arm,
        geometry.anchorHandleCenter.dy,
      ),
      Offset(
        geometry.anchorHandleCenter.dx + arm,
        geometry.anchorHandleCenter.dy,
      ),
      anchorCross,
    );
    canvas.drawLine(
      Offset(
        geometry.anchorHandleCenter.dx,
        geometry.anchorHandleCenter.dy - arm,
      ),
      Offset(
        geometry.anchorHandleCenter.dx,
        geometry.anchorHandleCenter.dy + arm,
      ),
      anchorCross,
    );

    _paintHandle(
      canvas,
      geometry.colliderCenterHandle,
      activeHandle == _SceneHandleType.colliderCenter,
      const Color(0xFFE8F4FF),
      const Color(0xFF0F1D28),
    );
    _paintHandle(
      canvas,
      geometry.colliderTopHandle,
      activeHandle == _SceneHandleType.colliderTop,
      const Color(0xFFE8F4FF),
      const Color(0xFF0F1D28),
    );
    _paintHandle(
      canvas,
      geometry.colliderRightHandle,
      activeHandle == _SceneHandleType.colliderRight,
      const Color(0xFFE8F4FF),
      const Color(0xFF0F1D28),
    );
    _paintHandle(
      canvas,
      geometry.anchorHandleCenter,
      activeHandle == _SceneHandleType.anchor,
      const Color(0xFFFF6B6B),
      const Color(0xFF2A0B0B),
      radius: 5,
    );
  }

  void _paintHandle(
    Canvas canvas,
    Offset center,
    bool selected,
    Color fillColor,
    Color strokeColor, {
    double radius = 6,
  }) {
    final fill = Paint()
      ..color = selected ? const Color(0xFFFFD97A) : fillColor
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = selected ? const Color(0xFFE59E00) : strokeColor
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);
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
    required PrefabSceneValues values,
    required this.zoom,
    required Size viewportSize,
  }) {
    final width = slice.width * zoom;
    final height = slice.height * zoom;
    final center = Offset(viewportSize.width * 0.5, viewportSize.height * 0.5);
    spriteRect = Rect.fromCenter(center: center, width: width, height: height);

    final anchorXLocal = values.anchorX * zoom;
    final anchorYLocal = values.anchorY * zoom;
    anchorHandleCenter = Offset(
      spriteRect.left + anchorXLocal,
      spriteRect.top + anchorYLocal,
    );

    final colliderCenterLocalX =
        (values.anchorX + values.colliderOffsetX) * zoom;
    final colliderCenterLocalY =
        (values.anchorY + values.colliderOffsetY) * zoom;
    final colliderCenter = Offset(
      spriteRect.left + colliderCenterLocalX,
      spriteRect.top + colliderCenterLocalY,
    );
    final halfW = values.colliderWidth * 0.5 * zoom;
    final halfH = values.colliderHeight * 0.5 * zoom;
    colliderRect = Rect.fromLTRB(
      colliderCenter.dx - halfW,
      colliderCenter.dy - halfH,
      colliderCenter.dx + halfW,
      colliderCenter.dy + halfH,
    );

    colliderCenterHandle = colliderCenter;
    colliderTopHandle = Offset(colliderRect.center.dx, colliderRect.top);
    colliderRightHandle = Offset(colliderRect.right, colliderRect.center.dy);
  }

  final double zoom;
  late final Rect spriteRect;
  late final Rect colliderRect;
  late final Offset anchorHandleCenter;
  late final Offset colliderCenterHandle;
  late final Offset colliderTopHandle;
  late final Offset colliderRightHandle;
}
