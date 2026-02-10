import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/snapshots/enums.dart';
import '../../../game/input/aim_preview.dart';
import '../../../game/input/charge_preview.dart';
import '../../haptics/haptics_service.dart';
import '../action_button.dart';
import '../controls_tuning.dart';
import '../directional_action_button.dart';
import '../hold_action_button.dart';

/// Resolves bonus input mode and routes aim to projectile or melee channels.
class BonusControl extends StatelessWidget {
  const BonusControl({
    super.key,
    required this.tuning,
    required this.inputMode,
    required this.usesMeleeAim,
    required this.size,
    required this.deadzoneRadius,
    required this.onPressed,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onProjectileAimDir,
    required this.onProjectileAimClear,
    required this.onMeleeAimDir,
    required this.onMeleeAimClear,
    required this.onCommitted,
    required this.projectileAimPreview,
    required this.meleeAimPreview,
    required this.chargePreview,
    required this.affordable,
    required this.cooldownTicksLeft,
    required this.cooldownTicksTotal,
    required this.cancelHitboxRect,
    required this.chargeEnabled,
    required this.chargeHalfTicks,
    required this.chargeFullTicks,
    required this.simulationTickHz,
    required this.haptics,
    required this.forceCancelSignal,
  });

  final ControlsTuning tuning;
  final AbilityInputMode inputMode;
  final bool usesMeleeAim;
  final double size;
  final double deadzoneRadius;

  final VoidCallback onPressed;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final void Function(double x, double y) onProjectileAimDir;
  final VoidCallback onProjectileAimClear;
  final void Function(double x, double y) onMeleeAimDir;
  final VoidCallback onMeleeAimClear;
  final ValueChanged<int> onCommitted;

  final AimPreviewModel projectileAimPreview;
  final AimPreviewModel meleeAimPreview;
  final ChargePreviewModel chargePreview;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final ValueListenable<Rect?> cancelHitboxRect;

  final bool chargeEnabled;
  final int chargeHalfTicks;
  final int chargeFullTicks;
  final int simulationTickHz;
  final UiHaptics haptics;
  final ValueListenable<int> forceCancelSignal;

  @override
  Widget build(BuildContext context) {
    final action = tuning.style.actionButton;
    final directional = tuning.style.directionalActionButton;
    final cooldownRing = tuning.style.cooldownRing;
    if (inputMode == AbilityInputMode.tap) {
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
    if (inputMode == AbilityInputMode.holdMaintain) {
      return HoldActionButton(
        label: 'Bonus',
        icon: Icons.star,
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
    return DirectionalActionButton(
      label: 'Bonus',
      icon: Icons.star,
      onAimDir: usesMeleeAim ? onMeleeAimDir : onProjectileAimDir,
      onAimClear: usesMeleeAim ? onMeleeAimClear : onProjectileAimClear,
      onCommit: () => onCommitted(0),
      tuning: directional,
      cooldownRing: cooldownRing,
      onChargeCommit: onCommitted,
      chargePreview: usesMeleeAim ? null : chargePreview,
      chargeOwnerId: 'bonus',
      chargeHalfTicks: (!usesMeleeAim && chargeEnabled) ? chargeHalfTicks : 0,
      chargeFullTicks: (!usesMeleeAim && chargeEnabled) ? chargeFullTicks : 0,
      chargeTickHz: simulationTickHz,
      haptics: haptics,
      projectileAimPreview: usesMeleeAim
          ? meleeAimPreview
          : projectileAimPreview,
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
