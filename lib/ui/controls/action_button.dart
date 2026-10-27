import 'package:flutter/material.dart';

import 'control_button_visuals.dart';
import 'controls_tuning.dart';
import 'control_resource_usage.dart';
import '../theme/ui_action_button_theme.dart';

/// Circular tap action control used by the combat HUD.
///
/// The button fires on pointer-down (`onTapDown`) for low-latency response and
/// is interactable when affordable and either ready or granted a Core recast.
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
    this.recastAvailable = false,
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

  /// Core-authorized follow-up that can be used during the shared cooldown.
  /// Affordability remains independent; this widget never tracks follow-up time.
  final bool recastAvailable;
  final double size;

  @override
  Widget build(BuildContext context) {
    final displayedCooldown = recastAvailable ? 0 : cooldownTicksLeft;
    final visual = ControlButtonVisualState.resolve(
      affordable: affordable,
      cooldownTicksLeft: displayedCooldown,
      backgroundColor: tuning.backgroundColor,
      foregroundColor: tuning.foregroundColor,
      resources: resources,
      theme: context.actionButtons,
    );

    return ControlButtonShell(
      label: recastAvailable ? '$label, follow-up available' : label,
      interactable: visual.interactable,
      onSemanticTap: onPressed,
      size: size,
      cooldownTicksLeft: displayedCooldown,
      cooldownTicksTotal: cooldownTicksTotal,
      cooldownRing: cooldownRing,
      child: ControlButtonSurface(
        visual: visual,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTapDown: visual.interactable ? (_) => onPressed() : null,
          onTap: null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ControlButtonContent(
                icon: icon,
                foregroundColor: visual.foregroundColor,
              ),
              if (recastAvailable)
                Positioned(
                  right: size * 0.12,
                  bottom: size * 0.08,
                  child: IgnorePointer(
                    child: Text(
                      '+1',
                      style: TextStyle(
                        color: visual.foregroundColor,
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.bold,
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
