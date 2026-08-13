import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../shared/scene_input_utils.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import 'chunk_polygon_authoring_controller.dart';
import 'chunk_scene_coordinator.dart';

/// Focusable Chunk-route surface for shared polygon interaction and painting.
///
/// Viewport pan/zoom remains route-local. Only accepted semantic commits from
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
    this.vertexHitRadiusCanvasPx = 10,
    this.edgeHitRadiusCanvasPx = 7,
    this.semanticLabel = 'Chunk authoring scene',
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
  final double vertexHitRadiusCanvasPx;
  final double edgeHitRadiusCanvasPx;
  final String semanticLabel;

  @override
  State<ChunkSceneSurface> createState() => _ChunkSceneSurfaceState();
}

class _ChunkSceneSurfaceState extends State<ChunkSceneSurface> {
  late final FocusNode _focusNode;
  int? _gesturePointer;
  int? _panPointer;
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
        child: Listener(
          key: const ValueKey<String>('chunk_scene_surface'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          onPointerSignal: _handlePointerSignal,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: <Widget>[
                widget.background,
                IgnorePointer(
                  child: CustomPaint(
                    painter: TerrainPolygonScenePainter(
                      projection: widget.controller.sceneProjection,
                      transform: widget.transform,
                    ),
                  ),
                ),
                IgnorePointer(child: widget.foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) return;
    _focusNode.requestFocus();
    if (SceneInputUtils.shouldPanWithPrimaryDrag(event.buttons)) {
      _panPointer = event.pointer;
      _gesturePointer = null;
      _domainGesturePointer = null;
      return;
    }
    final point = widget.transform.canvasToSource(event.localPosition);
    final worldPoint = Offset(point.xHalfPixels * 0.5, point.yHalfPixels * 0.5);
    switch (widget.activeDomain) {
      case ChunkSceneDomain.compiledEdgeInspection:
        widget.onInspectWorldPoint?.call(worldPoint);
        return;
      case ChunkSceneDomain.prefabs || ChunkSceneDomain.markers:
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
        controller.beginCreateRectangle(pointer: event.pointer, point: point)) {
      _gesturePointer = event.pointer;
      return;
    }
    if (controller.state.draft != null) {
      if (controller.state.tool == TerrainPolygonTool.createPolygon) {
        controller.addDraftVertex(point);
      } else if (controller.beginDraftGesture(
        pointer: event.pointer,
        point: point,
        vertexRadiusHalfPixels: widget.transform.canvasRadiusToSourceHalfPixels(
          widget.vertexHitRadiusCanvasPx,
        ),
        edgeRadiusHalfPixels: widget.transform.canvasRadiusToSourceHalfPixels(
          widget.edgeHitRadiusCanvasPx,
        ),
      )) {
        _gesturePointer = event.pointer;
      }
      return;
    }
    if (controller.state.tool == TerrainPolygonTool.createPolygon) {
      controller.beginCreatePolygon();
      controller.addDraftVertex(point);
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
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) return;
    if (_panPointer == event.pointer) {
      widget.onPanDelta?.call(event.delta);
      return;
    }
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
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_panPointer == event.pointer) {
      _panPointer = null;
      return;
    }
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
    widget.controller.commitGesture(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_panPointer == event.pointer) _panPointer = null;
    if (_domainGesturePointer == event.pointer) {
      _domainGesturePointer = null;
      widget.onCancelDomainGesture?.call(event.pointer);
    }
    if (_gesturePointer != event.pointer) return;
    _gesturePointer = null;
    widget.controller.cancelActiveOperation();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    final steps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (steps != 0) widget.onZoomSteps?.call(steps);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
