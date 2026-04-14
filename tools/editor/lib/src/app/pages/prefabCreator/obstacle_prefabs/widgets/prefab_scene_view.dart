import 'dart:io';
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
import '../../shared/ui/prefab_editor_scene_controls.dart';
import '../../shared/ui/prefab_editor_ui_tokens.dart';
import '../../shared/prefab_overlay_interaction.dart';
import '../../shared/prefab_scene_values.dart';

class PrefabSceneView extends StatefulWidget {
  const PrefabSceneView({
    super.key,
    required this.workspaceRootPath,
    required this.slice,
    required this.values,
    required this.onChanged,
    this.showCardFrame = true,
    this.showColliderOverlay = true,
  });

  final String workspaceRootPath;
  final AtlasSliceDef slice;
  final PrefabSceneValues values;
  final ValueChanged<PrefabSceneValues> onChanged;
  final bool showCardFrame;
  final bool showColliderOverlay;

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
  static const double _anchorHandleHitRadius = 10;
  static const double _colliderHandleHitRadius = 12;

  final EditorUiImageCache _imageCache = EditorUiImageCache();
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
    _imageCache.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final absolutePath = _absoluteImagePath();
    final image = _imageCache.imageFor(absolutePath);
    final imageExists = File(absolutePath).existsSync();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? math.min(_maxViewportWidth, constraints.maxWidth)
            : _maxViewportWidth;
        final hasBoundedHeight = constraints.maxHeight.isFinite;

        final content = Padding(
          padding: const EdgeInsets.all(PrefabEditorUiTokens.sectionGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrefabEditorSceneControls(
                width: viewportWidth,
                zoomControls: EditorZoomControls(
                  value: _zoom,
                  min: _minZoom,
                  max: _maxZoom,
                  step: _zoomStep,
                  onChanged: _setZoom,
                ),
              ),
              const SizedBox(height: PrefabEditorUiTokens.controlGap),
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
        );

        if (!widget.showCardFrame) {
          return content;
        }
        return Card(child: content);
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
                        showColliderOverlay: widget.showColliderOverlay,
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
    final image = await _imageCache.ensureLoaded(absolutePath);
    if (!mounted || image == null) {
      return;
    }
    setState(() {});
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
    final overlayGeometry = _overlayGeometry(canvasSize);
    final colliderIndex = !widget.showColliderOverlay
        ? null
        : PrefabOverlayHitTest.hitTestColliderIndex(
            point: event.localPosition,
            geometry: overlayGeometry,
          );
    if (colliderIndex != null &&
        colliderIndex != widget.values.normalizedSelectedColliderIndex) {
      widget.onChanged(
        PrefabOverlayInteraction.valuesWithSelectedCollider(
          values: widget.values,
          selectedColliderIndex: colliderIndex,
        ),
      );
      return;
    }
    final hit = PrefabOverlayHitTest.hitTestHandle(
      point: event.localPosition,
      geometry: overlayGeometry,
      anchorHandleHitRadius: _anchorHandleHitRadius,
      colliderHandleHitRadius: _colliderHandleHitRadius,
      includeColliderHandles: widget.showColliderOverlay,
    );
    if (hit != null) {
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
      return;
    }
    if (!widget.showColliderOverlay) {
      return;
    }
    if (colliderIndex == null) {
      return;
    }
    widget.onChanged(
      PrefabOverlayInteraction.valuesWithSelectedCollider(
        values: widget.values,
        selectedColliderIndex: colliderIndex,
      ),
    );
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
    _scheduleViewportCentering();
  }

  void _scheduleViewportCentering() {
    EditorSceneViewUtils.scheduleViewportCentering(
      context: context,
      horizontal: _horizontalScrollController,
      vertical: _verticalScrollController,
    );
  }

  PrefabOverlayHandleGeometry _overlayGeometry(Size canvasSize) {
    final geometry = _PrefabSceneGeometry(
      slice: widget.slice,
      zoom: _zoom,
      viewportSize: canvasSize,
    );
    return PrefabOverlayHandleGeometry.fromValues(
      values: widget.values,
      anchorCanvasBase: geometry.spriteRect.topLeft,
      zoom: _zoom,
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
    required this.showColliderOverlay,
  });

  final ui.Image image;
  final AtlasSliceDef slice;
  final PrefabSceneValues values;
  final double zoom;
  final PrefabOverlayHandleType? activeHandle;
  final bool showColliderOverlay;

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
      showCollider: showColliderOverlay,
    );
  }

  @override
  bool shouldRepaint(covariant _PrefabScenePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.slice != slice ||
        oldDelegate.values != values ||
        oldDelegate.zoom != zoom ||
        oldDelegate.activeHandle != activeHandle ||
        oldDelegate.showColliderOverlay != showColliderOverlay;
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
