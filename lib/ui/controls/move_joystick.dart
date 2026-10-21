import 'package:flutter/material.dart';

import 'controls_tuning.dart';
import '../components/hud_frame.dart';
import '../theme/ui_hud_theme.dart';

/// X-only joystick that emits the same -1/0/1 axis as MoveButtons.
/// One pointer owns the stick until release/cancel; other fingers remain free
/// for actions. Thumb displacement is visual and never scales gameplay input.
/// In floating mode, bounded constraints define the activation area and the
/// base center's horizontal limits. Fixed mode uses a base-sized touch target.
/// The original pointer stays captured even when dragging outside that area.
class MoveJoystick extends StatefulWidget {
  const MoveJoystick({
    super.key,
    required this.onAxisChanged,
    required this.tuning,
    required this.style,
    this.floating = true,
    this.restingPadding = EdgeInsets.zero,
  });

  final ValueChanged<double> onAxisChanged;
  final MoveJoystickTuning tuning;

  /// Shares the movement buttons' colors and border treatment.
  final MoveButtonsTuning style;

  /// Whether the base starts under the touch and follows overdrag. When false,
  /// it stays at rest and touch-down immediately resolves relative to its center.
  final bool floating;

  /// Insets from the activation area's left/bottom edges for the idle base.
  final EdgeInsets restingPadding;

  @override
  State<MoveJoystick> createState() => _MoveJoystickState();
}

class _MoveJoystickState extends State<MoveJoystick> {
  int? _pointer;
  double _offset = 0;
  double _axis = 0;
  Offset? _base;

  Offset _boundedBase(Offset base, double width) =>
      Offset(base.dx.clamp(0.0, width), base.dy);

  void _update(Offset position, Offset idle, double width) {
    if (!mounted) return;
    final radius = (widget.tuning.size - widget.tuning.thumbSize) / 2;
    final base = widget.floating ? _boundedBase(_base ?? idle, width) : idle;
    final offset = (position.dx - base.dx).clamp(-radius, radius);
    final axis = offset.abs() <= widget.tuning.deadzone ? 0.0 : offset.sign;
    setState(() {
      _offset = offset;
      if (widget.floating) {
        // Follow excess travel up to the activation area's horizontal edges.
        // Vertical movement only repositions the artwork.
        _base = _boundedBase(Offset(position.dx - offset, position.dy), width);
      }
    });
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
    setState(() {
      _offset = 0;
      _base = null;
    });
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = widget.floating && constraints.hasBoundedWidth
              ? constraints.maxWidth
              : tuning.size;
          final height = widget.floating && constraints.hasBoundedHeight
              ? constraints.maxHeight
              : tuning.size;
          final halfWidth = (tuning.size / 2).clamp(0.0, width / 2);
          final halfHeight = (tuning.size / 2).clamp(0.0, height / 2);
          final idle = Offset(
            (widget.restingPadding.left + tuning.size / 2).clamp(
              halfWidth,
              width - halfWidth,
            ),
            (height - widget.restingPadding.bottom - tuning.size / 2).clamp(
              halfHeight,
              height - halfHeight,
            ),
          );
          final base = widget.floating
              ? _boundedBase(_base ?? idle, width)
              : idle;
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (!mounted || _pointer != null) return;
              _pointer = event.pointer;
              if (widget.floating) {
                setState(
                  () => _base = _boundedBase(event.localPosition, width),
                );
              } else {
                _update(event.localPosition, idle, width);
              }
            },
            onPointerMove: (event) {
              if (event.pointer == _pointer) {
                _update(event.localPosition, idle, width);
              }
            },
            onPointerUp: (event) => _release(event.pointer),
            onPointerCancel: (event) => _release(event.pointer),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: base.dx - tuning.size / 2,
                    top: base.dy - tuning.size / 2,
                    child: IgnorePointer(
                      child: HudMedallion(
                        child: Container(
                          key: const ValueKey('movement_joystick_base'),
                          width: tuning.size,
                          height: tuning.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: style.backgroundColor,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    Icons.chevron_left,
                                    color: style.foregroundColor,
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: style.foregroundColor,
                                  ),
                                ],
                              ),
                              Transform.translate(
                                offset: Offset(_offset, 0),
                                child: HudMedallion(
                                  child: Container(
                                    key: const ValueKey(
                                      'movement_joystick_thumb',
                                    ),
                                    width: tuning.thumbSize,
                                    height: tuning.thumbSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _axis == 0
                                          ? context.hudTheme.background
                                          : context.hudTheme.wear,
                                    ),
                                    child: Icon(
                                      Icons.drag_handle,
                                      size: 20,
                                      color: style.foregroundColor.withValues(
                                        alpha: .65,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
