import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'editor_scene_view_utils.dart';
import 'scene_input_utils.dart';

enum EditorSceneFit { actualSize, height }

/// View-only state shared by painted canvases and scrollable scene collections.
///
/// A centered canvas pans freely in screen pixels. A scrollable collection pans
/// within its scroll extents and centers only spare space. Callers rebuild after
/// changing this state; source edits and document history never enter it.
class EditorSceneViewportController {
  EditorSceneViewportController({
    this.minZoom = .25,
    this.maxZoom = 8,
    this.zoomStep = .25,
    this.initialZoom = 1,
    this.fit = EditorSceneFit.actualSize,
    this.alignment = Alignment.center,
    bool scrollable = false,
  }) : _zoom = initialZoom,
       horizontal = scrollable ? ScrollController() : null,
       vertical = scrollable ? ScrollController() : null;

  final double minZoom, maxZoom, zoomStep, initialZoom;
  final EditorSceneFit fit;
  final Alignment alignment;
  final ScrollController? horizontal, vertical;
  double _zoom;
  Offset _pan = Offset.zero;

  double get zoom => _zoom;
  Offset get pan => _pan;

  bool setZoom(double value) {
    final next = EditorSceneViewUtils.snapZoom(
      value: value,
      min: minZoom,
      max: maxZoom,
      step: zoomStep,
    );
    if (EditorSceneViewUtils.zoomValuesEqual(next, _zoom)) return false;
    _zoom = next;
    return true;
  }

  void restore({required double zoom, required Offset pan}) {
    setZoom(zoom);
    _pan = pan;
  }

  void panBy(Offset delta) {
    if (horizontal != null) {
      SceneInputUtils.panScrollControllers(
        horizontal: horizontal!,
        vertical: vertical!,
        pointerDelta: delta,
      );
    } else {
      _pan += delta;
    }
  }

  void scrollBy(Offset delta) => panBy(-delta);

  void reset() {
    _zoom = initialZoom;
    _pan = Offset.zero;
    if (horizontal?.hasClients == true) horizontal!.jumpTo(0);
    if (vertical?.hasClients == true) vertical!.jumpTo(0);
  }

  /// Computes the same scale and origin for rendering and inverse hit testing.
  /// Scene dimensions and returned points use world pixels; pan uses screen pixels.
  EditorSceneViewportLayout layout({
    required Size viewport,
    required Size scene,
  }) {
    if (!viewport.isFinite ||
        viewport.isEmpty ||
        !scene.isFinite ||
        scene.isEmpty) {
      throw ArgumentError(
        'Viewport and scene dimensions must be finite and positive.',
      );
    }
    final scale =
        zoom *
        (fit == EditorSceneFit.height ? viewport.height / scene.height : 1);
    final content = scene * scale;
    final spare = Offset(
      viewport.width - content.width,
      viewport.height - content.height,
    );
    final bounded = horizontal != null;
    final available = bounded
        ? Offset(math.max(0, spare.dx), math.max(0, spare.dy))
        : spare;
    final anchor = alignment.alongOffset(available);
    final translation = bounded
        ? -Offset(
            horizontal!.hasClients ? horizontal!.offset : 0,
            vertical!.hasClients ? vertical!.offset : 0,
          )
        : pan;
    return EditorSceneViewportLayout(
      scale: scale,
      contentSize: content,
      origin: anchor + translation,
      padding: bounded
          ? EdgeInsets.fromLTRB(
              anchor.dx,
              anchor.dy,
              available.dx - anchor.dx,
              available.dy - anchor.dy,
            )
          : EdgeInsets.zero,
    );
  }

  void dispose() {
    horizontal?.dispose();
    vertical?.dispose();
  }
}

/// A single frame's view transform; re-read after scrolling before hit testing.
class EditorSceneViewportLayout {
  const EditorSceneViewportLayout({
    required this.scale,
    required this.contentSize,
    required this.origin,
    required this.padding,
  });
  final double scale;
  final Size contentSize;
  final Offset origin;
  final EdgeInsets padding;

  Offset toWorld(Offset canvasPoint) => (canvasPoint - origin) / scale;
}

/// Owns pointer arbitration for both editor viewports. A pointer belongs to either
/// navigation or editing until release/cancel, even if Ctrl changes mid-drag.
/// Wheel zoom is consumed once and blocked while an edit gesture is active.
class EditorScenePointerRegion extends StatefulWidget {
  const EditorScenePointerRegion({
    super.key,
    required this.child,
    this.behavior = HitTestBehavior.opaque,
    this.onPanDelta,
    this.onZoomSteps,
    this.onScrollDelta,
    this.canNavigate,
    this.onInteractionStart,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
    this.onPointerHover,
  });
  final Widget child;
  final HitTestBehavior behavior;
  final ValueChanged<Offset>? onPanDelta, onScrollDelta;
  final ValueChanged<int>? onZoomSteps;
  final bool Function()? canNavigate;
  final VoidCallback? onInteractionStart;
  final PointerDownEventListener? onPointerDown;
  final PointerMoveEventListener? onPointerMove;
  final PointerUpEventListener? onPointerUp;
  final PointerCancelEventListener? onPointerCancel;
  final PointerHoverEventListener? onPointerHover;

  @override
  State<EditorScenePointerRegion> createState() =>
      _EditorScenePointerRegionState();
}

class _EditorScenePointerRegionState extends State<EditorScenePointerRegion> {
  int? _pointer;
  bool _panning = false;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: widget.behavior,
    onPointerDown: (event) {
      if (_pointer != null ||
          !SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
        return;
      }
      final pan = SceneInputUtils.shouldPanWithPrimaryDrag(event.buttons);
      if (pan && widget.canNavigate?.call() == false) return;
      _pointer = event.pointer;
      _panning = pan;
      widget.onInteractionStart?.call();
      if (!pan) widget.onPointerDown?.call(event);
    },
    onPointerMove: (event) {
      if (_pointer != event.pointer) return;
      if (_panning) {
        widget.onPanDelta?.call(event.delta);
      } else {
        widget.onPointerMove?.call(event);
      }
    },
    onPointerUp: (event) {
      if (_pointer != event.pointer) return;
      _pointer = null;
      if (!_panning) widget.onPointerUp?.call(event);
      _panning = false;
    },
    onPointerCancel: (event) {
      if (_pointer != event.pointer) return;
      _pointer = null;
      if (!_panning) widget.onPointerCancel?.call(event);
      _panning = false;
    },
    onPointerHover: (event) {
      if (_pointer == null) widget.onPointerHover?.call(event);
    },
    onPointerSignal: (event) {
      if (_pointer != null || widget.canNavigate?.call() == false) {
        if (event is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
        }
        return;
      }
      final steps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
      if (steps != 0 && widget.onZoomSteps != null) {
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (_) => widget.onZoomSteps!(steps),
        );
      } else if (event is PointerScrollEvent && widget.onScrollDelta != null) {
        final delta = HardwareKeyboard.instance.isShiftPressed
            ? Offset(event.scrollDelta.dy, event.scrollDelta.dx)
            : event.scrollDelta;
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (_) => widget.onScrollDelta!(delta),
        );
      }
    },
    child: widget.child,
  );
}
