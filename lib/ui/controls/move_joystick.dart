import 'package:flutter/material.dart';

import 'controls_tuning.dart';

/// Fixed X-only joystick that emits the same -1/0/1 axis as MoveButtons.
/// One pointer owns the stick until release/cancel; other fingers remain free
/// for actions. Thumb displacement is visual and never scales gameplay input.
class MoveJoystick extends StatefulWidget {
  const MoveJoystick({
    super.key,
    required this.onAxisChanged,
    required this.tuning,
    required this.style,
  });

  final ValueChanged<double> onAxisChanged;
  final MoveJoystickTuning tuning;

  /// Shares the movement buttons' colors and border treatment.
  final MoveButtonsTuning style;

  @override
  State<MoveJoystick> createState() => _MoveJoystickState();
}

class _MoveJoystickState extends State<MoveJoystick> {
  int? _pointer;
  double _offset = 0;
  double _axis = 0;

  void _update(Offset position) {
    if (!mounted) return;
    final radius = (widget.tuning.size - widget.tuning.thumbSize) / 2;
    final offset = (position.dx - widget.tuning.size / 2).clamp(
      -radius,
      radius,
    );
    final axis = offset.abs() <= widget.tuning.deadzone ? 0.0 : offset.sign;
    setState(() => _offset = offset);
    _emit(axis);
  }

  void _emit(double axis) {
    if (axis == _axis) return;
    _axis = axis;
    widget.onAxisChanged(axis);
  }

  void _release(int pointer) {
    if (!mounted || pointer != _pointer) return;
    _pointer = null;
    setState(() => _offset = 0);
    _emit(0);
  }

  @override
  Widget build(BuildContext context) {
    final tuning = widget.tuning;
    final style = widget.style;
    return Semantics(
      label: 'Movement joystick',
      value: switch (_axis) {
        < 0 => 'Backward',
        > 0 => 'Forward',
        _ => 'Neutral',
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_pointer != null) return;
          _pointer = event.pointer;
          _update(event.localPosition);
        },
        onPointerMove: (event) {
          if (event.pointer == _pointer) _update(event.localPosition);
        },
        onPointerUp: (event) => _release(event.pointer),
        onPointerCancel: (event) => _release(event.pointer),
        child: Container(
          width: tuning.size,
          height: tuning.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: style.backgroundColor,
            border: Border.all(
              color: style.borderColor,
              width: style.borderWidth,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.chevron_left, color: style.foregroundColor),
                  Icon(Icons.chevron_right, color: style.foregroundColor),
                ],
              ),
              Transform.translate(
                offset: Offset(_offset, 0),
                child: Container(
                  width: tuning.thumbSize,
                  height: tuning.thumbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: style.foregroundColor.withValues(
                      alpha: _axis == 0 ? 0.4 : 0.8,
                    ),
                    border: Border.all(
                      color: style.borderColor,
                      width: style.borderWidth,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
