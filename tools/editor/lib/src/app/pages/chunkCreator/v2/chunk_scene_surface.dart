import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../shared/editor_scene_viewport.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import 'chunk_polygon_authoring_controller.dart';
import 'chunk_scene_coordinator.dart';

/// Focusable Chunk-route surface for shared polygon interaction and painting.
///
/// Shared viewport input routes navigation separately. Only semantic commits from
/// [controller] can reach the session document and its undo history.
class ChunkSceneSurface extends StatefulWidget {
  const ChunkSceneSurface({
    super.key,
    required this.controller,
    required this.transform,
    required this.activeDomain,
    this.background = const SizedBox.expand(),
    this.foreground = const SizedBox.shrink(),
    this.onPanDelta,
    this.onZoomSteps,
    this.onInspectWorldPoint,
    this.onSelectWorldPoint,
    this.onBeginDomainGesture,
    this.onUpdateDomainGesture,
    this.onEndDomainGesture,
    this.onCancelDomainGesture,
    this.onClearSelection,
    this.onDeleteSelection,
    this.onCompleteOperation,
    this.onBeforeTerrainResize,
    this.vertexHitRadiusCanvasPx = 10,
    this.edgeHitRadiusCanvasPx = 7,
    this.collisionSnapRadiusCanvasPx = 8,
    this.semanticLabel = 'Chunk authoring scene',
    this.showAuthoringOverlay = true,
    this.interactionEnabled = true,
  });

  final ChunkPolygonAuthoringController controller;
  final TerrainPolygonViewportTransform transform;
  final ChunkSceneDomain activeDomain;
  final Widget background;
  final Widget foreground;
  final ValueChanged<Offset>? onPanDelta;
  final ValueChanged<int>? onZoomSteps;
  final ValueChanged<Offset>? onInspectWorldPoint;
  final ValueChanged<Offset>? onSelectWorldPoint;
  final bool Function(int pointer, Offset worldPoint)? onBeginDomainGesture;
  final void Function(int pointer, Offset worldPoint)? onUpdateDomainGesture;
  final void Function(int pointer, Offset worldPoint)? onEndDomainGesture;
  final ValueChanged<int>? onCancelDomainGesture;
  final VoidCallback? onClearSelection;
  final VoidCallback? onDeleteSelection;
  final VoidCallback? onCompleteOperation;

  /// The workspace resolves pending inspector input before admitting a resize.
  final bool Function()? onBeforeTerrainResize;
  final double vertexHitRadiusCanvasPx;
  final double edgeHitRadiusCanvasPx;

  /// Visual-radius threshold for exact collision-boundary snapping.
  final double collisionSnapRadiusCanvasPx;
  final String semanticLabel;
  final bool showAuthoringOverlay;
  final bool interactionEnabled;

  @override
  State<ChunkSceneSurface> createState() => _ChunkSceneSurfaceState();
}

class _ChunkSceneSurfaceState extends State<ChunkSceneSurface> {
  late final FocusNode _focusNode;
  int? _gesturePointer;
  int? _domainGesturePointer;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ChunkSceneSurface');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: EditorScenePointerRegion(
          key: const ValueKey<String>('chunk_scene_surface'),
          onInteractionStart: _focusNode.requestFocus,
          onPanDelta: widget.onPanDelta,
          onZoomSteps: widget.onZoomSteps,
          canNavigate: () =>
              _gesturePointer == null && _domainGesturePointer == null,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: <Widget>[
                widget.background,
                if (widget.showAuthoringOverlay)
                  IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey<String>('chunk_authoring_overlay'),
                      painter: TerrainPolygonScenePainter(
                        projection: widget.controller.sceneProjection,
                        transform: widget.transform,
                        showRectangleResizeHandles:
                            widget.controller.state.tool ==
                                TerrainPolygonTool.select &&
                            widget.controller.state.draft == null,
                        pass: widget.activeDomain == ChunkSceneDomain.terrain
                            ? TerrainPolygonScenePass.geometry
                            : TerrainPolygonScenePass.combined,
                      ),
                    ),
                  ),
                IgnorePointer(child: widget.foreground),
                if (widget.showAuthoringOverlay &&
                    widget.activeDomain == ChunkSceneDomain.terrain)
                  IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey<String>(
                        'chunk_authoring_vertex_overlay',
                      ),
                      painter: TerrainPolygonScenePainter(
                        projection: widget.controller.sceneProjection,
                        transform: widget.transform,
                        showRectangleResizeHandles:
                            widget.controller.state.tool ==
                                TerrainPolygonTool.select &&
                            widget.controller.state.draft == null,
                        pass: TerrainPolygonScenePass.vertices,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.interactionEnabled) return;
    final point = widget.transform.canvasToSource(event.localPosition);
    final worldPoint = Offset(point.xHalfPixels * 0.5, point.yHalfPixels * 0.5);
    switch (widget.activeDomain) {
      case ChunkSceneDomain.layers:
        return;
      case ChunkSceneDomain.compiledEdgeInspection:
        widget.onInspectWorldPoint?.call(worldPoint);
        return;
      case ChunkSceneDomain.encounters ||
          ChunkSceneDomain.traps ||
          ChunkSceneDomain.water ||
          ChunkSceneDomain.prefabs ||
          ChunkSceneDomain.markers:
        final began =
            widget.onBeginDomainGesture?.call(event.pointer, worldPoint) ??
            false;
        if (began) {
          _domainGesturePointer = event.pointer;
        } else {
          widget.onSelectWorldPoint?.call(worldPoint);
        }
        return;
      case ChunkSceneDomain.terrain:
        break;
    }
    final controller = widget.controller;
    if (controller.state.tool == TerrainPolygonTool.createRectangle &&
        controller.beginCreateRectangle(
          pointer: event.pointer,
          point: point,
          snapRadiusHalfPixels: _collisionSnapRadiusHalfPixels,
        )) {
      _gesturePointer = event.pointer;
      return;
    }
    if (controller.state.draft != null) {
      if (controller.state.tool == TerrainPolygonTool.createPolygon) {
        controller.addDraftVertex(
          point,
          snapRadiusHalfPixels: _collisionSnapRadiusHalfPixels,
        );
      } else if (controller.beginDraftGesture(
        pointer: event.pointer,
        point: point,
        vertexRadiusHalfPixels: widget.transform.canvasRadiusToSourceHalfPixels(
          widget.vertexHitRadiusCanvasPx,
        ),
        edgeRadiusHalfPixels: widget.transform.canvasRadiusToSourceHalfPixels(
          widget.edgeHitRadiusCanvasPx,
        ),
        snapRadiusHalfPixels: _collisionSnapRadiusHalfPixels,
      )) {
        _gesturePointer = event.pointer;
      }
      return;
    }
    if (controller.state.tool == TerrainPolygonTool.createPolygon) {
      controller.beginCreatePolygon();
      controller.addDraftVertex(
        point,
        snapRadiusHalfPixels: _collisionSnapRadiusHalfPixels,
      );
      return;
    }
    final resizeCorner = controller.selectedRectangleCornerAt(
      point: point,
      radiusHalfPixels: widget.transform.canvasRadiusToSourceHalfPixels(
        widget.vertexHitRadiusCanvasPx,
      ),
    );
    if (resizeCorner != null) {
      if (widget.onBeforeTerrainResize?.call() == false) return;
      if (controller.beginResizeRectangle(
        pointer: event.pointer,
        point: point,
        vertexIndex: resizeCorner,
      )) {
        _gesturePointer = event.pointer;
      }
      return;
    }
    controller.selectAt(
      point: point,
      vertexRadiusHalfPixels: widget.transform.canvasRadiusToSourceHalfPixels(
        widget.vertexHitRadiusCanvasPx,
      ),
      edgeRadiusHalfPixels: widget.transform.canvasRadiusToSourceHalfPixels(
        widget.edgeHitRadiusCanvasPx,
      ),
    );
    if (controller.state.tool == TerrainPolygonTool.select) return;
    if (controller.beginGesture(pointer: event.pointer, point: point)) {
      _gesturePointer = event.pointer;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_domainGesturePointer == event.pointer) {
      widget.onUpdateDomainGesture?.call(
        event.pointer,
        _worldPoint(event.localPosition),
      );
      return;
    }
    if (_gesturePointer != event.pointer) return;
    widget.controller.updateGesture(
      pointer: event.pointer,
      point: widget.transform.canvasToSource(event.localPosition),
      snapRadiusHalfPixels: _collisionSnapRadiusHalfPixels,
    );
  }

  double get _collisionSnapRadiusHalfPixels => widget.transform
      .canvasRadiusToSourceHalfPixels(widget.collisionSnapRadiusCanvasPx);

  void _handlePointerUp(PointerUpEvent event) {
    if (_domainGesturePointer == event.pointer) {
      _domainGesturePointer = null;
      widget.onEndDomainGesture?.call(
        event.pointer,
        _worldPoint(event.localPosition),
      );
      return;
    }
    if (_gesturePointer != event.pointer) return;
    _gesturePointer = null;
    if (widget.controller.state.gesture?.kind ==
        TerrainPolygonGestureKind.resizeRectangle) {
      widget.controller.updateGesture(
        pointer: event.pointer,
        point: widget.transform.canvasToSource(event.localPosition),
        snapRadiusHalfPixels: _collisionSnapRadiusHalfPixels,
      );
    }
    widget.controller.commitGesture(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_domainGesturePointer == event.pointer) {
      _domainGesturePointer = null;
      widget.onCancelDomainGesture?.call(event.pointer);
    }
    if (_gesturePointer != event.pointer) return;
    _gesturePointer = null;
    widget.controller.cancelActiveOperation();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!widget.interactionEnabled) return KeyEventResult.ignored;
    final controller = widget.controller;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _gesturePointer = null;
      _domainGesturePointer = null;
      if (widget.activeDomain == ChunkSceneDomain.terrain) {
        controller.cancelActiveOperation();
      } else {
        widget.onClearSelection?.call();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (widget.activeDomain == ChunkSceneDomain.terrain &&
          controller.state.draft != null) {
        controller.saveDraft();
        return KeyEventResult.handled;
      }
      if (widget.onCompleteOperation != null) {
        widget.onCompleteOperation!();
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (widget.activeDomain == ChunkSceneDomain.terrain) {
        controller.deleteSelection();
      } else {
        widget.onDeleteSelection?.call();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Offset _worldPoint(Offset localPosition) {
    final point = widget.transform.canvasToSource(localPosition);
    return Offset(point.xHalfPixels * 0.5, point.yHalfPixels * 0.5);
  }
}
