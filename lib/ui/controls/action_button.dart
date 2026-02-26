import 'package:flutter/material.dart';

import 'control_button_visuals.dart';
import 'controls_tuning.dart';

/// Circular tap action control used by the combat HUD.
///
/// The button fires on pointer-down (`onTapDown`) for low-latency response and
/// is interactable only when `affordable` and not on cooldown.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.iconWidget,
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
  final Widget? iconWidget;
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
    );

    return ControlButtonShell(
      size: size,
      cooldownTicksLeft: cooldownTicksLeft,
      cooldownTicksTotal: cooldownTicksTotal,
      cooldownRing: cooldownRing,
      child: Material(
        color: visual.backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTapDown: visual.interactable ? (_) => onPressed() : null,
          onTap: null,
          child: ControlButtonContent(
            label: label,
            icon: icon,
            iconWidget: iconWidget,
            foregroundColor: visual.foregroundColor,
            labelFontSize: tuning.labelFontSize,
            labelGap: tuning.labelGap,
          ),
        ),
      ),
    );
  }
}
