import 'package:flutter/material.dart';

import 'control_button_visuals.dart';
import 'controls_tuning.dart';
import 'control_resource_usage.dart';
import '../theme/ui_action_button_theme.dart';

/// Circular tap action control used by the combat HUD.
///
/// The button fires on pointer-down (`onTapDown`) for low-latency response and
/// is interactable only when `affordable` and not on cooldown.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.resources = ControlResourceUsage.none,
    required this.onPressed,
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
  final VoidCallback onPressed;
  final ActionButtonTuning tuning;
  final CooldownRingTuning cooldownRing;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visual = ControlButtonVisualState.resolve(
      affordable: affordable,
      cooldownTicksLeft: cooldownTicksLeft,
      backgroundColor: tuning.backgroundColor,
      foregroundColor: tuning.foregroundColor,
      resources: resources,
      theme: context.actionButtons,
    );

    return ControlButtonShell(
      label: label,
      interactable: visual.interactable,
      onSemanticTap: onPressed,
      size: size,
      cooldownTicksLeft: cooldownTicksLeft,
      cooldownTicksTotal: cooldownTicksTotal,
      cooldownRing: cooldownRing,
      child: ControlButtonSurface(
        visual: visual,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTapDown: visual.interactable ? (_) => onPressed() : null,
          onTap: null,
          child: ControlButtonContent(
            icon: icon,
            foregroundColor: visual.foregroundColor,
          ),
        ),
      ),
    );
  }
}
