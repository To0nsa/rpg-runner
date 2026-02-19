import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/snapshots/enums.dart';
import '../../../game/input/aim_preview.dart';
import '../action_button.dart';
import '../controls_tuning.dart';
import '../directional_action_button.dart';
import '../hold_action_button.dart';

/// Resolves melee input mode (tap, hold-release, hold-maintain, directional aim-release).
class MeleeControl extends StatelessWidget {
  const MeleeControl({
    super.key,
    required this.tuning,
    required this.inputMode,
    required this.size,
    required this.deadzoneRadius,
    required this.onPressed,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onChargeHoldStart,
    required this.onChargeHoldEnd,
    required this.onAimDir,
    required this.onAimClear,
    required this.onCommitted,
    required this.aimPreview,
    required this.affordable,
    required this.cooldownTicksLeft,
    required this.cooldownTicksTotal,
    required this.cancelHitboxRect,
    required this.forceCancelSignal,
  });

  final ControlsTuning tuning;
  final AbilityInputMode inputMode;
  final double size;
  final double deadzoneRadius;

  final VoidCallback onPressed;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onChargeHoldStart;
  final VoidCallback onChargeHoldEnd;
  final void Function(double x, double y) onAimDir;
  final VoidCallback onAimClear;
  final VoidCallback onCommitted;

  final AimPreviewModel aimPreview;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final ValueListenable<Rect?> cancelHitboxRect;
  final ValueListenable<int> forceCancelSignal;

  @override
  Widget build(BuildContext context) {
    final action = tuning.style.actionButton;
    final directional = tuning.style.directionalActionButton;
    final cooldownRing = tuning.style.cooldownRing;
    if (inputMode == AbilityInputMode.tap) {
      return ActionButton(
        label: 'Sword',
        icon: Icons.sports_martial_arts_rounded,
        onPressed: onPressed,
        tuning: action,
        cooldownRing: cooldownRing,
        affordable: affordable,
        cooldownTicksLeft: cooldownTicksLeft,
        cooldownTicksTotal: cooldownTicksTotal,
        size: size,
      );
    }
    if (inputMode == AbilityInputMode.holdMaintain) {
      return HoldActionButton(
        label: 'Sword',
        icon: Icons.sports_martial_arts_rounded,
        onHoldStart: onHoldStart,
        onHoldEnd: onHoldEnd,
        tuning: action,
        cooldownRing: cooldownRing,
        affordable: affordable,
        cooldownTicksLeft: cooldownTicksLeft,
        cooldownTicksTotal: cooldownTicksTotal,
        size: size,
      );
    }
    if (inputMode == AbilityInputMode.holdRelease) {
      return HoldActionButton(
        label: 'Sword',
        icon: Icons.sports_martial_arts_rounded,
        onHoldStart: onChargeHoldStart,
        onHoldEnd: onChargeHoldEnd,
        onRelease: onCommitted,
        tuning: action,
        cooldownRing: cooldownRing,
        affordable: affordable,
        cooldownTicksLeft: cooldownTicksLeft,
        cooldownTicksTotal: cooldownTicksTotal,
        size: size,
      );
    }
    return DirectionalActionButton(
      label: 'Sword',
      icon: Icons.sports_martial_arts_rounded,
      onHoldStart: onChargeHoldStart,
      onHoldEnd: onChargeHoldEnd,
      onAimDir: onAimDir,
      onAimClear: onAimClear,
      onCommit: onCommitted,
      projectileAimPreview: aimPreview,
      tuning: directional,
      cooldownRing: cooldownRing,
      cancelHitboxRect: cancelHitboxRect,
      affordable: affordable,
      cooldownTicksLeft: cooldownTicksLeft,
      cooldownTicksTotal: cooldownTicksTotal,
      size: size,
      deadzoneRadius: deadzoneRadius,
      forceCancelSignal: forceCancelSignal,
    );
  }
}
