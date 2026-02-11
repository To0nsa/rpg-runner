import 'package:flutter/material.dart';

import 'control_button_visuals.dart';
import 'controls_tuning.dart';

/// Circular action button that starts on pointer-down and ends on release.
///
/// This widget tracks the initiating pointer id to avoid cross-pointer leaks on
/// multitouch surfaces. If the widget is disposed while held, it emits a final
/// `onHoldEnd` so caller state cannot remain latched.
class HoldActionButton extends StatefulWidget {
  const HoldActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onHoldStart,
    required this.onHoldEnd,
    this.onRelease,
    required this.tuning,
    required this.size,
    required this.cooldownRing,
    this.affordable = true,
    this.cooldownTicksLeft = 0,
    this.cooldownTicksTotal = 0,
  });

  final String label;
  final IconData icon;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback? onRelease;
  final ActionButtonTuning tuning;
  final CooldownRingTuning cooldownRing;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final double size;

  @override
  State<HoldActionButton> createState() => _HoldActionButtonState();
}

class _HoldActionButtonState extends State<HoldActionButton> {
  int? _pointer;

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
    widget.onHoldStart();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    widget.onHoldEnd();
    widget.onRelease?.call();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    widget.onHoldEnd();
  }

  @override
  void dispose() {
    if (_pointer != null) {
      widget.onHoldEnd();
    }
    super.dispose();
  }
}
