import 'package:flutter/material.dart';

import 'package:runner_core/abilities/ability_def.dart';

import '../action_button.dart';
import '../ability_slot_visual_spec.dart';
import '../controls_tuning.dart';
import '../control_resource_usage.dart';

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
    this.label,
    this.abilityId,
    this.resources = ControlResourceUsage.none,
  });

  final ControlsTuning tuning;
  final double size;
  final VoidCallback onPressed;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final String? label;

  /// Equipped spell identity selects its semantic control symbol.
  final AbilityKey? abilityId;
  final ControlResourceUsage resources;

  @override
  Widget build(BuildContext context) {
    final slot = abilityRadialLayoutSpec.slotSpec(AbilitySlot.spell);
    final resolvedLabel = label ?? slot.label;
    final action = tuning.style.actionButton;
    final cooldownRing = tuning.style.cooldownRing;
    return ActionButton(
      label: resolvedLabel,
      icon: abilityRadialLayoutSpec.iconFor(
        AbilitySlot.spell,
        abilityId: abilityId,
      ),
      resources: resources,
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
