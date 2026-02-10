import 'package:flutter/material.dart';

import '../action_button.dart';
import '../controls_tuning.dart';

/// Tap-only bonus control (self-targeted spells).
class BonusControl extends StatelessWidget {
  const BonusControl({
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
    final action = tuning.style.actionButton;
    final cooldownRing = tuning.style.cooldownRing;
    return ActionButton(
      label: 'Bonus',
      icon: Icons.star,
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
