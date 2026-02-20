import 'package:flutter/material.dart';

import '../../../core/abilities/ability_def.dart';
import '../action_button.dart';
import '../ability_slot_visual_spec.dart';
import '../controls_tuning.dart';

/// Tap-only spell slot control (self-targeted spells).
class SpellControl extends StatelessWidget {
  const SpellControl({
    super.key,
    required this.tuning,
    required this.size,
    required this.onPressed,
    required this.affordable,
    required this.cooldownTicksLeft,
    required this.cooldownTicksTotal,
  });

  final ControlsTuning tuning;
  final double size;
  final VoidCallback onPressed;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;

  @override
  Widget build(BuildContext context) {
    final slot = abilityRadialLayoutSpec.slotSpec(AbilitySlot.spell);
    final action = tuning.style.actionButton;
    final cooldownRing = tuning.style.cooldownRing;
    return ActionButton(
      label: slot.label,
      icon: slot.icon,
      onPressed: onPressed,
      tuning: action,
      cooldownRing: cooldownRing,
      affordable: affordable,
      cooldownTicksLeft: cooldownTicksLeft,
      cooldownTicksTotal: cooldownTicksTotal,
      size: size,
    );
  }
}
