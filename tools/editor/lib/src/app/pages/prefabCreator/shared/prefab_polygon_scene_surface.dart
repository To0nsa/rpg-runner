import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../shared/scene_input_utils.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import 'prefab_polygon_authoring_controller.dart';

/// Focusable Prefab-route surface for shared polygon interaction and painting.
///
/// The route supplies the visual source below this overlay and owns viewport
/// pan/zoom through callbacks. Tool/selection/preview state stays in
/// [controller]; only its accepted semantic results can reach session history.
class PrefabPolygonSceneSurface extends StatefulWidget {
  const PrefabPolygonSceneSurface({
    super.key,
    required this.controller,
    required this.transform,
    this.visualSource = const SizedBox.expand(),
    this.onPanDelta,
    this.onZoomSteps,
    this.vertexHitRadiusCanvasPx = 10,
    this.edgeHitRadiusCanvasPx = 7,
    this.semanticLabel = 'Prefab collision polygon editor',
  });

  final PrefabPolygonAuthoringController controller;
  final TerrainPolygonViewportTransform transform;
  final Widget visualSource;
  final ValueChanged<Offset>? onPanDelta;
  final ValueChanged<int>? onZoomSteps;
  final double vertexHitRadiusCanvasPx;
  final double edgeHitRadiusCanvasPx;
  final String semanticLabel;

  @override
  State<PrefabPolygonSceneSurface> createState() =>
      _PrefabPolygonSceneSurfaceState();
}

class _PrefabPolygonSceneSurfaceState extends State<PrefabPolygonSceneSurface> {
  late final FocusNode _focusNode;
  int? _gesturePointer;
  int? _panPointer;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'PrefabPolygonSceneSurface');
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
          key: const ValueKey<String>('prefab_polygon_scene_surface'),
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
                widget.visualSource,
                IgnorePointer(
                  child: CustomPaint(
                    painter: TerrainPolygonScenePainter(
                      projection: widget.controller.sceneProjection,
                      transform: widget.transform,
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
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) return;
    _focusNode.requestFocus();
    if (SceneInputUtils.shouldPanWithPrimaryDrag(event.buttons)) {
      _panPointer = event.pointer;
      _gesturePointer = null;
      return;
    }

    final point = widget.transform.canvasToSource(event.localPosition);
    final controller = widget.controller;
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
    if (_gesturePointer != event.pointer) return;
    _gesturePointer = null;
    widget.controller.commitGesture(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_panPointer == event.pointer) _panPointer = null;
    if (_gesturePointer != event.pointer) return;
    _gesturePointer = null;
    widget.controller.cancelActiveOperation();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    final steps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (steps != 0) widget.onZoomSteps?.call(steps);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final controller = widget.controller;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _gesturePointer = null;
      controller.cancelActiveOperation();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        controller.state.draft != null) {
      controller.saveDraft();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      controller.deleteSelection();
      return KeyEventResult.handled;
    }
    if (!HardwareKeyboard.instance.isControlPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        controller.redo();
      } else {
        if (controller.hasActiveOperation) _gesturePointer = null;
        controller.undo();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyY) {
      controller.redo();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
