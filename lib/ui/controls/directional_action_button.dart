import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';
import '../../game/input/aim_quantizer.dart';
import 'cooldown_ring.dart';

class DirectionalActionButton extends StatefulWidget {
  const DirectionalActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onAimDir,
    required this.onAimClear,
    required this.onCommit,
    required this.projectileAimPreview,
    this.cancelHitboxRect,
    this.affordable = true,
    this.cooldownTicksLeft = 0,
    this.cooldownTicksTotal = 0,
    this.size = 72,
    this.deadzoneRadius = 12,
    this.backgroundColor = const Color(0x33000000),
    this.foregroundColor = Colors.white,
    this.labelFontSize = 12,
    this.labelGap = 2,
  });

  final String label;
  final IconData icon;
  final void Function(double x, double y) onAimDir;
  final VoidCallback onAimClear;
  final VoidCallback onCommit;
  final AimPreviewModel projectileAimPreview;
  final ValueListenable<Rect?>? cancelHitboxRect;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final double size;
  final double deadzoneRadius;
  final Color backgroundColor;
  final Color foregroundColor;
  final double labelFontSize;
  final double labelGap;

  @override
  State<DirectionalActionButton> createState() =>
      _DirectionalActionButtonState();
}

class _DirectionalActionButtonState extends State<DirectionalActionButton> {
  int? _pointer;
  bool _canceled = false;

  @override
  Widget build(BuildContext context) {
    final interactable = widget.affordable && widget.cooldownTicksLeft <= 0;
    final effectiveForeground = widget.affordable
        ? widget.foregroundColor
        : _disabledForeground(widget.foregroundColor);
    final effectiveBackground = widget.affordable
        ? widget.backgroundColor
        : _disabledBackground(widget.backgroundColor);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: !interactable,
            child: Listener(
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              child: Material(
                color: effectiveBackground,
                shape: const CircleBorder(),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: effectiveForeground),
                      SizedBox(height: widget.labelGap),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: widget.labelFontSize,
                          color: effectiveForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: CooldownRing(
              cooldownTicksLeft: widget.cooldownTicksLeft,
              cooldownTicksTotal: widget.cooldownTicksTotal,
            ),
          ),
        ],
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _canceled = false;
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
      widget.onCommit();
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
  }

  void _resetAim() {
    _pointer = null;
    _canceled = false;
    widget.onAimClear();
    widget.projectileAimPreview.end();
  }

  Color _disabledForeground(Color color) => color.withValues(alpha: 0.35);

  Color _disabledBackground(Color color) =>
      color.withValues(alpha: color.a * 0.6);
}
