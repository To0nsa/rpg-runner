import 'package:flutter/material.dart';

import 'controls_tuning.dart';

/// Two holdable movement buttons that emit a horizontal axis in [-1, 1].
///
/// - Hold left => -1
/// - Hold right => 1
/// - Hold both or none => 0
class MoveButtons extends StatefulWidget {
  const MoveButtons({
    super.key,
    required this.onAxisChanged,
    required this.tuning,
  });

  final ValueChanged<double> onAxisChanged;
  final MoveButtonsTuning tuning;

  @override
  State<MoveButtons> createState() => _MoveButtonsState();
}

class _MoveButtonsState extends State<MoveButtons> {
  final Map<int, _MoveSide> _pointerSides = <int, _MoveSide>{};

  double _axis = 0.0;

  void _syncAxis() {
    final leftHeld = _pointerSides.values.contains(_MoveSide.left);
    final rightHeld = _pointerSides.values.contains(_MoveSide.right);
    final nextAxis = switch ((leftHeld, rightHeld)) {
      (true, false) => -1.0,
      (false, true) => 1.0,
      _ => 0.0,
    };
    if (nextAxis == _axis) return;
    _axis = nextAxis;
    widget.onAxisChanged(nextAxis);
  }

  _MoveSide _sideForX(double x) {
    final leftMaxX = widget.tuning.buttonWidth;
    final rightMinX = widget.tuning.buttonWidth + widget.tuning.gap;
    if (x <= leftMaxX) return _MoveSide.left;
    if (x >= rightMinX) return _MoveSide.right;
    // Pointer is in the visual gap: snap to the nearest side so sliding across
    // the center transitions smoothly without requiring a lift/re-tap.
    final middleX = widget.tuning.buttonWidth + widget.tuning.gap * 0.5;
    return x <= middleX ? _MoveSide.left : _MoveSide.right;
  }

  void _setPointerSide(int pointer, _MoveSide side) {
    final old = _pointerSides[pointer];
    if (old == side) return;
    _pointerSides[pointer] = side;
    setState(() {});
    _syncAxis();
  }

  void _removePointer(int pointer) {
    if (_pointerSides.remove(pointer) != null) {
      setState(() {});
      _syncAxis();
    }
  }

  @override
  Widget build(BuildContext context) {
    final leftPressed = _pointerSides.values.contains(_MoveSide.left);
    final rightPressed = _pointerSides.values.contains(_MoveSide.right);
    final totalWidth = widget.tuning.buttonWidth * 2 + widget.tuning.gap;
    return SizedBox(
      width: totalWidth,
      height: widget.tuning.buttonHeight,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) =>
            _setPointerSide(event.pointer, _sideForX(event.localPosition.dx)),
        onPointerMove: (event) =>
            _setPointerSide(event.pointer, _sideForX(event.localPosition.dx)),
        onPointerUp: (event) => _removePointer(event.pointer),
        onPointerCancel: (event) => _removePointer(event.pointer),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HoldMoveButton(
              label: 'Move left',
              icon: Icons.chevron_left,
              pressed: leftPressed,
              tuning: widget.tuning,
            ),
            SizedBox(width: widget.tuning.gap),
            _HoldMoveButton(
              label: 'Move right',
              icon: Icons.chevron_right,
              pressed: rightPressed,
              tuning: widget.tuning,
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldMoveButton extends StatelessWidget {
  const _HoldMoveButton({
    required this.label,
    required this.icon,
    required this.pressed,
    required this.tuning,
  });

  final String label;
  final IconData icon;
  final bool pressed;
  final MoveButtonsTuning tuning;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = tuning.backgroundColor;
    final base = pressed
        ? backgroundColor.withValues(
            alpha: (backgroundColor.a * 1.5).clamp(0, 1),
          )
        : backgroundColor;
    return Semantics(
      label: label,
      button: true,
      child: Container(
        width: tuning.buttonWidth,
        height: tuning.buttonHeight,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(tuning.borderRadius),
          border: Border.all(
            color: tuning.borderColor,
            width: tuning.borderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: tuning.foregroundColor),
      ),
    );
  }
}

enum _MoveSide { left, right }
