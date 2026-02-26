import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';
import '../../game/input/aim_quantizer.dart';
import 'control_button_visuals.dart';
import 'controls_tuning.dart';

/// Circular directional action control for aim + release commit input.
///
/// Drag direction is normalized then quantized before forwarding to
/// `onAimDir`, so callers receive stable input suitable for deterministic
/// command routing.
class DirectionalActionButton extends StatefulWidget {
  const DirectionalActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.iconWidget,
    required this.onAimDir,
    required this.onAimClear,
    required this.onCommit,
    this.onHoldStart,
    this.onHoldEnd,
    required this.projectileAimPreview,
    required this.tuning,
    required this.size,
    required this.deadzoneRadius,
    required this.cooldownRing,
    this.cancelHitboxRect,
    this.affordable = true,
    this.cooldownTicksLeft = 0,
    this.cooldownTicksTotal = 0,
    this.forceCancelSignal,
  });

  final String label;
  final IconData icon;
  final Widget? iconWidget;
  final void Function(double x, double y) onAimDir;
  final VoidCallback onAimClear;
  final VoidCallback onCommit;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;
  final AimPreviewModel projectileAimPreview;
  final DirectionalActionButtonTuning tuning;
  final CooldownRingTuning cooldownRing;
  final ValueListenable<Rect?>? cancelHitboxRect;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final double size;
  final double deadzoneRadius;
  final ValueListenable<int>? forceCancelSignal;

  @override
  State<DirectionalActionButton> createState() =>
      _DirectionalActionButtonState();
}

class _DirectionalActionButtonState extends State<DirectionalActionButton> {
  int? _pointer;
  bool _canceled = false;
  bool _holdActive = false;
  int _lastForceCancelValue = 0;

  @override
  void initState() {
    super.initState();
    _attachForceCancelListener();
  }

  @override
  void didUpdateWidget(covariant DirectionalActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forceCancelSignal != widget.forceCancelSignal) {
      _detachForceCancelListener(oldWidget.forceCancelSignal);
      _attachForceCancelListener();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = ControlButtonVisualState.resolve(
      affordable: widget.affordable,
      cooldownTicksLeft: widget.cooldownTicksLeft,
      backgroundColor: widget.tuning.backgroundColor,
      foregroundColor: widget.tuning.foregroundColor,
    );

    return ControlButtonShell(
      size: widget.size,
      cooldownTicksLeft: widget.cooldownTicksLeft,
      cooldownTicksTotal: widget.cooldownTicksTotal,
      cooldownRing: widget.cooldownRing,
      child: IgnorePointer(
        ignoring: !visual.interactable,
        child: Listener(
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: Material(
            color: visual.backgroundColor,
            shape: const CircleBorder(),
            child: ControlButtonContent(
              label: widget.label,
              icon: widget.icon,
              iconWidget: widget.iconWidget,
              foregroundColor: visual.foregroundColor,
              labelFontSize: widget.tuning.labelFontSize,
              labelGap: widget.tuning.labelGap,
            ),
          ),
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _canceled = false;
    _holdActive = true;
    widget.onHoldStart?.call();
    widget.projectileAimPreview.begin();
    widget.onAimClear();
    _updateAim(event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _updateAim(event.localPosition);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;

    // Cancel is decided by where the pointer is released in *screen space*.
    // (The cancel hitbox cannot receive pointer events because the pointer
    // started on this button, so we must hit-test using the global position.)
    final cancelRect = widget.cancelHitboxRect?.value;
    if (cancelRect != null && cancelRect.contains(event.position)) {
      _cancelAim();
    }

    if (!_canceled) widget.onCommit();
    _resetAim();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    // System canceled the pointer stream -> treat as Cancel (never commit).
    _cancelAim();
    _resetAim();
  }

  void _updateAim(Offset localPosition) {
    if (_canceled) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len <= widget.deadzoneRadius) {
      widget.onAimClear();
      widget.projectileAimPreview.clearAim();
      return;
    }
    final nx = dx / len;
    final ny = dy / len;
    final qx = AimQuantizer.quantize(nx);
    final qy = AimQuantizer.quantize(ny);
    widget.onAimDir(qx, qy);
    widget.projectileAimPreview.updateAim(qx, qy);
  }

  void _cancelAim() {
    if (_canceled) return;
    _canceled = true;
    widget.onAimClear();
    widget.projectileAimPreview.end();
  }

  void _resetAim() {
    _endHoldIfActive();
    _pointer = null;
    _canceled = false;
    widget.onAimClear();
    widget.projectileAimPreview.end();
  }

  void _endHoldIfActive() {
    if (!_holdActive) return;
    _holdActive = false;
    widget.onHoldEnd?.call();
  }

  @override
  void dispose() {
    _detachForceCancelListener(widget.forceCancelSignal);
    _endHoldIfActive();
    super.dispose();
  }

  void _attachForceCancelListener() {
    final signal = widget.forceCancelSignal;
    if (signal == null) return;
    _lastForceCancelValue = signal.value;
    signal.addListener(_handleForceCancelSignal);
  }

  void _detachForceCancelListener(ValueListenable<int>? signal) {
    signal?.removeListener(_handleForceCancelSignal);
  }

  void _handleForceCancelSignal() {
    final signal = widget.forceCancelSignal;
    if (signal == null) return;
    final next = signal.value;
    if (next == _lastForceCancelValue) return;
    _lastForceCancelValue = next;

    if (_pointer != null) {
      _cancelAim();
      _resetAim();
    }
  }
}
