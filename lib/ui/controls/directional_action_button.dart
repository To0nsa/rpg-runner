import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';

class DirectionalActionButton extends StatefulWidget {
  const DirectionalActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onAimDir,
    required this.onAimClear,
    required this.onCommit,
    required this.aimPreview,
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
  final AimPreviewModel aimPreview;
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
  bool _leftButtonOnce = false;
  bool _canceled = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: Material(
          color: widget.backgroundColor,
          shape: const CircleBorder(),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.foregroundColor),
                SizedBox(height: widget.labelGap),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: widget.labelFontSize,
                    color: widget.foregroundColor,
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
    if (_pointer != null) return;
    _pointer = event.pointer;
    _leftButtonOnce = false;
    _canceled = false;
    widget.aimPreview.begin();
    widget.onAimClear();
    _updateAim(event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final inside = _isInside(event.localPosition);
    if (!inside && !_leftButtonOnce) {
      _leftButtonOnce = true;
    }
    if (inside && _leftButtonOnce) {
      _cancelAim();
      return;
    }
    _updateAim(event.localPosition);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    if (!_canceled) {
      widget.onCommit();
    }
    _resetAim();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
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
      widget.aimPreview.clearAim();
      return;
    }
    final nx = dx / len;
    final ny = dy / len;
    widget.onAimDir(nx, ny);
    widget.aimPreview.updateAim(nx, ny);
  }

  void _cancelAim() {
    if (_canceled) return;
    _canceled = true;
    widget.onAimClear();
    widget.aimPreview.end();
  }

  void _resetAim() {
    _pointer = null;
    _leftButtonOnce = false;
    _canceled = false;
    widget.onAimClear();
    widget.aimPreview.end();
  }

  bool _isInside(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final radius = widget.size / 2;
    return (dx * dx + dy * dy) <= radius * radius;
  }
}
