import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/snapshots/enums.dart';
import '../../../game/input/aim_preview.dart';
import '../../../game/input/charge_preview.dart';
import '../action_button.dart';
import '../controls_tuning.dart';
import '../directional_action_button.dart';

class BonusControl extends StatelessWidget {
  const BonusControl({
    super.key,
    required this.tuning,
    required this.inputMode,
    required this.usesMeleeAim,
    required this.size,
    required this.deadzoneRadius,
    required this.onPressed,
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
    required this.forceCancelSignal,
  });

  final ControlsTuning tuning;
  final AbilityInputMode inputMode;
  final bool usesMeleeAim;
  final double size;
  final double deadzoneRadius;

  final VoidCallback onPressed;
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
  final ValueListenable<int> forceCancelSignal;

  @override
  Widget build(BuildContext context) {
    final action = tuning.style.actionButton;
    final directional = tuning.style.directionalActionButton;
    if (inputMode == AbilityInputMode.tap) {
      return ActionButton(
        label: 'Bonus',
        icon: Icons.star,
        onPressed: onPressed,
        affordable: affordable,
        cooldownTicksLeft: cooldownTicksLeft,
        cooldownTicksTotal: cooldownTicksTotal,
        size: size,
        backgroundColor: action.backgroundColor,
        foregroundColor: action.foregroundColor,
        labelFontSize: action.labelFontSize,
        labelGap: action.labelGap,
      );
    }
    return DirectionalActionButton(
      label: 'Bonus',
      icon: Icons.star,
      onAimDir: usesMeleeAim ? onMeleeAimDir : onProjectileAimDir,
      onAimClear: usesMeleeAim ? onMeleeAimClear : onProjectileAimClear,
      onCommit: () => onCommitted(0),
      onChargeCommit: onCommitted,
      chargePreview: usesMeleeAim ? null : chargePreview,
      chargeOwnerId: 'bonus',
      chargeHalfTicks: (!usesMeleeAim && chargeEnabled) ? chargeHalfTicks : 0,
      chargeFullTicks: (!usesMeleeAim && chargeEnabled) ? chargeFullTicks : 0,
      chargeTickHz: simulationTickHz,
      projectileAimPreview: usesMeleeAim
          ? meleeAimPreview
          : projectileAimPreview,
      cancelHitboxRect: cancelHitboxRect,
      affordable: affordable,
      cooldownTicksLeft: cooldownTicksLeft,
      cooldownTicksTotal: cooldownTicksTotal,
      size: size,
      deadzoneRadius: deadzoneRadius,
      backgroundColor: directional.backgroundColor,
      foregroundColor: directional.foregroundColor,
      labelFontSize: directional.labelFontSize,
      labelGap: directional.labelGap,
      forceCancelSignal: forceCancelSignal,
    );
  }
}
