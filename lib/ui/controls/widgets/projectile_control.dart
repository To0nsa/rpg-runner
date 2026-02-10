import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/snapshots/enums.dart';
import '../../../game/input/aim_preview.dart';
import '../../../game/input/charge_preview.dart';
import '../../haptics/haptics_service.dart';
import '../action_button.dart';
import '../controls_tuning.dart';
import '../directional_action_button.dart';

/// Resolves projectile input mode (tap vs directional/charged) to a control.
class ProjectileControl extends StatelessWidget {
  const ProjectileControl({
    super.key,
    required this.tuning,
    required this.inputMode,
    required this.size,
    required this.deadzoneRadius,
    required this.onPressed,
    required this.onAimDir,
    required this.onAimClear,
    required this.onCommitted,
    required this.aimPreview,
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
  final double size;
  final double deadzoneRadius;

  final VoidCallback onPressed;
  final void Function(double x, double y) onAimDir;
  final VoidCallback onAimClear;
  final ValueChanged<int> onCommitted;

  final AimPreviewModel aimPreview;
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
        label: 'Projectile',
        icon: Icons.auto_awesome,
        onPressed: onPressed,
        tuning: action,
        cooldownRing: cooldownRing,
        affordable: affordable,
        cooldownTicksLeft: cooldownTicksLeft,
        cooldownTicksTotal: cooldownTicksTotal,
        size: size,
      );
    }
    return DirectionalActionButton(
      label: 'Projectile',
      icon: Icons.auto_awesome,
      onAimDir: onAimDir,
      onAimClear: onAimClear,
      onCommit: () => onCommitted(0),
      tuning: directional,
      cooldownRing: cooldownRing,
      onChargeCommit: onCommitted,
      chargePreview: chargePreview,
      chargeOwnerId: 'projectile',
      chargeHalfTicks: chargeEnabled ? chargeHalfTicks : 0,
      chargeFullTicks: chargeEnabled ? chargeFullTicks : 0,
      chargeTickHz: simulationTickHz,
      projectileAimPreview: aimPreview,
      haptics: haptics,
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
