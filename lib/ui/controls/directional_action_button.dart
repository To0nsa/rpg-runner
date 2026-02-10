import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';
import '../../game/input/aim_quantizer.dart';
import '../../game/input/charge_preview.dart';
import '../haptics/haptics_cue.dart';
import '../haptics/haptics_service.dart';
import 'control_button_visuals.dart';
import 'controls_tuning.dart';

/// Circular directional action control with optional charge commit.
///
/// Drag direction is normalized then quantized before forwarding to
/// `onAimDir`, so callers receive stable input suitable for deterministic
/// command routing. When charge is enabled, commit payload uses simulation
/// ticks (`chargeTickHz`).
class DirectionalActionButton extends StatefulWidget {
  const DirectionalActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onAimDir,
    required this.onAimClear,
    required this.onCommit,
    required this.projectileAimPreview,
    required this.tuning,
    required this.size,
    required this.deadzoneRadius,
    required this.cooldownRing,
    this.cancelHitboxRect,
    this.affordable = true,
    this.cooldownTicksLeft = 0,
    this.cooldownTicksTotal = 0,
    this.onChargeCommit,
    this.chargePreview,
    this.chargeOwnerId,
    this.chargeHalfTicks = 0,
    this.chargeFullTicks = 0,
    this.chargeTickHz = 60,
    this.enableChargeHaptics = true,
    this.haptics,
    this.forceCancelSignal,
  });

  final String label;
  final IconData icon;
  final void Function(double x, double y) onAimDir;
  final VoidCallback onAimClear;
  final VoidCallback onCommit;
  final AimPreviewModel projectileAimPreview;
  final DirectionalActionButtonTuning tuning;
  final CooldownRingTuning cooldownRing;
  final ValueListenable<Rect?>? cancelHitboxRect;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final double size;
  final double deadzoneRadius;
  final ValueChanged<int>? onChargeCommit;
  final ChargePreviewModel? chargePreview;
  final String? chargeOwnerId;
  final int chargeHalfTicks;
  final int chargeFullTicks;
  final int chargeTickHz;
  final bool enableChargeHaptics;
  final UiHaptics? haptics;
  final ValueListenable<int>? forceCancelSignal;

  @override
  State<DirectionalActionButton> createState() =>
      _DirectionalActionButtonState();
}

class _DirectionalActionButtonState extends State<DirectionalActionButton> {
  int? _pointer;
  bool _canceled = false;
  final Stopwatch _chargeWatch = Stopwatch();
  Timer? _chargeTimer;
  int _lastChargeTier = 0;
  int _lastChargeTicks = 0;
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
    _startChargeTracking();
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

    if (!_canceled) {
      if (_isChargeEnabled) {
        _updateChargeProgress();
        if (widget.onChargeCommit != null) {
          widget.onChargeCommit!.call(_lastChargeTicks);
        } else {
          widget.onCommit();
        }
      } else {
        widget.onCommit();
      }
    }
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
    _endChargeTracking();
  }

  void _resetAim() {
    _pointer = null;
    _canceled = false;
    widget.onAimClear();
    widget.projectileAimPreview.end();
    _endChargeTracking();
  }

  @override
  void dispose() {
    _detachForceCancelListener(widget.forceCancelSignal);
    _chargeTimer?.cancel();
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

  bool get _isChargeEnabled =>
      widget.onChargeCommit != null &&
      widget.chargeFullTicks > 0 &&
      widget.chargeTickHz > 0;

  void _startChargeTracking() {
    if (!_isChargeEnabled) return;
    _lastChargeTier = 0;
    _lastChargeTicks = 0;
    _chargeWatch
      ..reset()
      ..start();
    widget.chargePreview?.begin(
      ownerId: widget.chargeOwnerId ?? widget.label,
      halfTierTicks: widget.chargeHalfTicks,
      fullTierTicks: widget.chargeFullTicks,
    );
    _chargeTimer?.cancel();
    _chargeTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _updateChargeProgress(),
    );
  }

  void _updateChargeProgress() {
    if (!_isChargeEnabled || !_chargeWatch.isRunning) return;
    final elapsedMicros = _chargeWatch.elapsedMicroseconds;
    // Convert wall-clock hold time to simulation ticks so commit values use
    // the same unit as Core cooldown/charge rules.
    final ticks = (elapsedMicros * widget.chargeTickHz) ~/ 1000000;
    _lastChargeTicks = ticks < 0 ? 0 : ticks;
    widget.chargePreview?.updateChargeTicks(_lastChargeTicks);

    final tier = _lastChargeTicks >= widget.chargeFullTicks
        ? 2
        : (_lastChargeTicks >= widget.chargeHalfTicks ? 1 : 0);
    if (widget.enableChargeHaptics && tier > _lastChargeTier) {
      if (_lastChargeTier < 1 && tier >= 1) {
        widget.haptics?.trigger(UiHapticsCue.chargeHalfTierReached);
      }
      if (_lastChargeTier < 2 && tier >= 2) {
        widget.haptics?.trigger(UiHapticsCue.chargeFullTierReached);
      }
    }
    _lastChargeTier = tier;
  }

  void _endChargeTracking() {
    _chargeTimer?.cancel();
    _chargeTimer = null;
    _chargeWatch.stop();
    _chargeWatch.reset();
    _lastChargeTicks = 0;
    _lastChargeTier = 0;
    widget.chargePreview?.end();
  }
}
