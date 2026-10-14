import 'package:flutter/material.dart';

import 'control_button_visuals.dart';
import 'controls_tuning.dart';
import 'control_resource_usage.dart';
import '../theme/ui_action_button_theme.dart';

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
    this.resources = ControlResourceUsage.none,
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
  final ControlResourceUsage resources;
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
      resources: widget.resources,
      theme: context.actionButtons,
    );

    return ControlButtonShell(
      label: widget.label,
      interactable: visual.interactable,
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
          child: ControlButtonSurface(
            visual: visual,
            child: ControlButtonContent(
              icon: widget.icon,
              foregroundColor: visual.foregroundColor,
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
