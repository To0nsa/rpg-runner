import 'package:flutter/material.dart';

/// Two holdable movement buttons that emit a horizontal axis in [-1, 1].
///
/// - Hold left => -1
/// - Hold right => 1
/// - Hold both or none => 0
class MoveButtons extends StatefulWidget {
  const MoveButtons({
    super.key,
    required this.onAxisChanged,
    this.buttonWidth = 64,
    this.buttonHeight = 48,
    this.gap = 8,
    this.backgroundColor = const Color(0x33000000),
    this.foregroundColor = const Color(0xFFFFFFFF),
    this.borderColor = const Color(0x55FFFFFF),
    this.borderWidth = 1,
    this.borderRadius = 12,
  });

  final ValueChanged<double> onAxisChanged;
  final double buttonWidth;
  final double buttonHeight;
  final double gap;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;

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
    final leftMaxX = widget.buttonWidth;
    final rightMinX = widget.buttonWidth + widget.gap;
    if (x <= leftMaxX) return _MoveSide.left;
    if (x >= rightMinX) return _MoveSide.right;
    final middleX = widget.buttonWidth + widget.gap * 0.5;
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
    final totalWidth = widget.buttonWidth * 2 + widget.gap;
    return SizedBox(
      width: totalWidth,
      height: widget.buttonHeight,
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
              width: widget.buttonWidth,
              height: widget.buttonHeight,
              backgroundColor: widget.backgroundColor,
              foregroundColor: widget.foregroundColor,
              borderColor: widget.borderColor,
              borderWidth: widget.borderWidth,
              borderRadius: widget.borderRadius,
            ),
            SizedBox(width: widget.gap),
            _HoldMoveButton(
              label: 'Move right',
              icon: Icons.chevron_right,
              pressed: rightPressed,
              width: widget.buttonWidth,
              height: widget.buttonHeight,
              backgroundColor: widget.backgroundColor,
              foregroundColor: widget.foregroundColor,
              borderColor: widget.borderColor,
              borderWidth: widget.borderWidth,
              borderRadius: widget.borderRadius,
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
    required this.width,
    required this.height,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
  });

  final String label;
  final IconData icon;
  final bool pressed;
  final double width;
  final double height;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final base = pressed
        ? backgroundColor.withValues(
            alpha: (backgroundColor.a * 1.5).clamp(0, 1),
          )
        : backgroundColor;
    return Semantics(
      label: label,
      button: true,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: foregroundColor),
      ),
    );
  }
}

enum _MoveSide { left, right }
