import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'action_button.dart';
import 'controls_tuning.dart';
import 'directional_action_button.dart';
import 'fixed_joystick.dart';
import 'floating_joystick.dart';

class RunnerControlsOverlay extends StatelessWidget {
  const RunnerControlsOverlay({
    super.key,
    required this.onMoveAxis,
    required this.onJumpPressed,
    required this.onDashPressed,
    required this.onSecondaryPressed,
    required this.onBonusPressed,
    required this.onBonusCommitted,
    required this.onProjectileCommitted,
    required this.onProjectilePressed,
    required this.onProjectileAimDir,
    required this.onProjectileAimClear,
    required this.projectileAimPreview,
    required this.projectileAffordable,
    required this.projectileCooldownTicksLeft,
    required this.projectileCooldownTicksTotal,
    required this.onMeleeAimDir,
    required this.onMeleeAimClear,
    required this.onMeleeCommitted,
    required this.onMeleePressed,
    required this.meleeAimPreview,
    required this.meleeAffordable,
    required this.meleeCooldownTicksLeft,
    required this.meleeCooldownTicksTotal,
    required this.meleeInputMode,
    required this.projectileInputMode,
    required this.bonusInputMode,
    required this.bonusUsesMeleeAim,
    required this.jumpAffordable,
    required this.dashAffordable,
    required this.dashCooldownTicksLeft,
    required this.dashCooldownTicksTotal,
    required this.secondaryAffordable,
    required this.secondaryCooldownTicksLeft,
    required this.secondaryCooldownTicksTotal,
    required this.bonusAffordable,
    required this.bonusCooldownTicksLeft,
    required this.bonusCooldownTicksTotal,
    this.tuning = ControlsTuning.fixed,
  });

  final ValueChanged<double> onMoveAxis;
  final VoidCallback onJumpPressed;
  final VoidCallback onDashPressed;
  final VoidCallback onSecondaryPressed;
  final VoidCallback onBonusPressed;
  final VoidCallback onBonusCommitted;
  final VoidCallback onProjectileCommitted;
  final VoidCallback onProjectilePressed;
  final void Function(double x, double y) onProjectileAimDir;
  final VoidCallback onProjectileAimClear;
  final AimPreviewModel projectileAimPreview;
  final bool projectileAffordable;
  final int projectileCooldownTicksLeft;
  final int projectileCooldownTicksTotal;
  final void Function(double x, double y) onMeleeAimDir;
  final VoidCallback onMeleeAimClear;
  final VoidCallback onMeleeCommitted;
  final VoidCallback onMeleePressed;
  final AimPreviewModel meleeAimPreview;
  final bool meleeAffordable;
  final int meleeCooldownTicksLeft;
  final int meleeCooldownTicksTotal;
  final AbilityInputMode meleeInputMode;
  final AbilityInputMode projectileInputMode;

  final AbilityInputMode bonusInputMode;
  final bool bonusUsesMeleeAim;
  final bool jumpAffordable;
  final bool dashAffordable;
  final int dashCooldownTicksLeft;
  final int dashCooldownTicksTotal;
  final bool secondaryAffordable;
  final int secondaryCooldownTicksLeft;
  final int secondaryCooldownTicksTotal;
  final bool bonusAffordable;
  final int bonusCooldownTicksLeft;
  final int bonusCooldownTicksTotal;
  final ControlsTuning tuning;

  @override
  Widget build(BuildContext context) {
    final t = tuning;
    final action = t.actionButton;
    final directional = t.directionalActionButton;
    final jumpSize = action.size * 1.4;
    final smallActionSize = action.size * 0.9;
    final smallDirectionalSize = directional.size * 0.9;
    final smallDeadzoneRadius = directional.deadzoneRadius * 0.9;

    // Arrange the 5 action slots (Mobility, Secondary, Primary, Projectile, Bonus)
    // in a clean radial arc around the Jump button.

    Offset polar(double radius, double degrees) {
      final radians = degrees * math.pi / 180.0;
      return Offset(math.cos(radians) * radius, math.sin(radians) * radius);
    }

    double rightFor(Offset centerOffset, double targetSize) {
      return t.edgePadding + jumpSize * 0.5 - centerOffset.dx - targetSize * 0.5;
    }

    double bottomFor(Offset centerOffset, double targetSize) {
      return t.edgePadding + jumpSize * 0.5 - centerOffset.dy - targetSize * 0.5;
    }

    final jumpRadius = jumpSize * 0.5;
    final ringGap = t.buttonGap * 0.9;
    final ringRadius =
        jumpRadius + math.max(smallDirectionalSize, smallActionSize) * 0.5 + ringGap;

    // Evenly spread the 5 action buttons over an arc above/left of the jump.
    // Degrees follow the standard unit circle, but note Flutter's Y axis points down.
    const startDeg = 160.0;
    const stepDeg = 35.0;

    //final dashOffset = polar(ringRadius, startDeg + stepDeg * 0);
    final meleeOffset = polar(ringRadius, startDeg + stepDeg * 0.2);
    final secondaryOffset = polar(ringRadius, startDeg + stepDeg * 1.6);
    final projectileOffset = polar(ringRadius, startDeg + stepDeg * 3);
    //final bonusOffset = polar(ringRadius, startDeg + stepDeg * 4);

    return Stack(
      children: [
        Positioned(
          left: t.edgePadding,
          bottom: t.bottomEdgePadding,
          child: t.joystickKind == ControlsJoystickKind.floating
              ? FloatingJoystick(
                  onAxisChanged: onMoveAxis,
                  areaSize: t.floatingJoystick.areaSize,
                  baseSize: t.floatingJoystick.baseSize,
                  knobSize: t.floatingJoystick.knobSize,
                  followSmoothing: t.floatingJoystick.followSmoothing,
                  baseColor: t.floatingJoystick.baseColor,
                  baseBorderColor: t.floatingJoystick.baseBorderColor,
                  baseBorderWidth: t.floatingJoystick.baseBorderWidth,
                  knobColor: t.floatingJoystick.knobColor,
                  knobBorderColor: t.floatingJoystick.knobBorderColor,
                  knobBorderWidth: t.floatingJoystick.knobBorderWidth,
                )
              : FixedJoystick(
                  onAxisChanged: onMoveAxis,
                  size: t.fixedJoystick.size,
                  knobSize: t.fixedJoystick.knobSize,
                  baseColor: t.fixedJoystick.baseColor,
                  baseBorderColor: t.fixedJoystick.baseBorderColor,
                  baseBorderWidth: t.fixedJoystick.baseBorderWidth,
                  knobColor: t.fixedJoystick.knobColor,
                  knobBorderColor: t.fixedJoystick.knobBorderColor,
                  knobBorderWidth: t.fixedJoystick.knobBorderWidth,
                ),
        ),
        Positioned(
          right: rightFor(projectileOffset, smallDirectionalSize),
          bottom: bottomFor(projectileOffset, smallDirectionalSize),
          child: projectileInputMode == AbilityInputMode.tap
              ? ActionButton(
                  label: 'Projectile',
                  icon: Icons.auto_awesome,
                  onPressed: onProjectilePressed,
                  affordable: projectileAffordable,
                  cooldownTicksLeft: projectileCooldownTicksLeft,
                  cooldownTicksTotal: projectileCooldownTicksTotal,
                  size: smallDirectionalSize,
                  backgroundColor: action.backgroundColor,
                  foregroundColor: action.foregroundColor,
                  labelFontSize: action.labelFontSize,
                  labelGap: action.labelGap,
                )
              : DirectionalActionButton(
                  label: 'Projectile',
                  icon: Icons.auto_awesome,
                  onAimDir: onProjectileAimDir,
                  onAimClear: onProjectileAimClear,
                  onCommit: onProjectileCommitted,
                  projectileAimPreview: projectileAimPreview,
                  affordable: projectileAffordable,
                  cooldownTicksLeft: projectileCooldownTicksLeft,
                  cooldownTicksTotal: projectileCooldownTicksTotal,
                  size: smallDirectionalSize,
                  deadzoneRadius: smallDeadzoneRadius,
                  backgroundColor: directional.backgroundColor,
                  foregroundColor: directional.foregroundColor,
                  labelFontSize: directional.labelFontSize,
                  labelGap: directional.labelGap,
                ),
        ),
/*         Positioned(
          right: rightFor(bonusOffset, smallActionSize),
          bottom: bottomFor(bonusOffset, smallActionSize),
          child: bonusInputMode == AbilityInputMode.tap
              ? ActionButton(
                  label: 'Bonus',
                  icon: Icons.star,
                  onPressed: onBonusPressed,
                  affordable: bonusAffordable,
                  cooldownTicksLeft: bonusCooldownTicksLeft,
                  cooldownTicksTotal: bonusCooldownTicksTotal,
                  size: smallActionSize,
                  backgroundColor: action.backgroundColor,
                  foregroundColor: action.foregroundColor,
                  labelFontSize: action.labelFontSize,
                  labelGap: action.labelGap,
                )
              : DirectionalActionButton(
                  label: 'Bonus',
                  icon: Icons.star,
                  onAimDir: bonusUsesMeleeAim ? onMeleeAimDir : onProjectileAimDir,
                  onAimClear: bonusUsesMeleeAim ? onMeleeAimClear : onProjectileAimClear,
                  onCommit: onBonusCommitted,
                  projectileAimPreview:
                      bonusUsesMeleeAim ? meleeAimPreview : projectileAimPreview,
                  affordable: bonusAffordable,
                  cooldownTicksLeft: bonusCooldownTicksLeft,
                  cooldownTicksTotal: bonusCooldownTicksTotal,
                  size: smallDirectionalSize,
                  deadzoneRadius: smallDeadzoneRadius,
                  backgroundColor: directional.backgroundColor,
                  foregroundColor: directional.foregroundColor,
                  labelFontSize: directional.labelFontSize,
                  labelGap: directional.labelGap,
                ),
        ), */
        Positioned(
          right: rightFor(secondaryOffset, smallActionSize),
          bottom: bottomFor(secondaryOffset, smallActionSize),
          child: ActionButton(
            label: 'Sec',
            icon: Icons.shield,
            onPressed: onSecondaryPressed,
            affordable: secondaryAffordable,
            cooldownTicksLeft: secondaryCooldownTicksLeft,
            cooldownTicksTotal: secondaryCooldownTicksTotal,
            size: smallActionSize,
            backgroundColor: action.backgroundColor,
            foregroundColor: action.foregroundColor,
            labelFontSize: action.labelFontSize,
            labelGap: action.labelGap,
          ),
        ),
        Positioned(
          right: rightFor(meleeOffset, smallDirectionalSize),
          bottom: bottomFor(meleeOffset, smallDirectionalSize),
          child: meleeInputMode == AbilityInputMode.tap
              ? ActionButton(
                  label: 'Atk',
                  icon: Icons.close,
                  onPressed: onMeleePressed,
                  affordable: meleeAffordable,
                  cooldownTicksLeft: meleeCooldownTicksLeft,
                  cooldownTicksTotal: meleeCooldownTicksTotal,
                  size: smallDirectionalSize,
                  backgroundColor: action.backgroundColor,
                  foregroundColor: action.foregroundColor,
                  labelFontSize: action.labelFontSize,
                  labelGap: action.labelGap,
                )
              : DirectionalActionButton(
                  label: 'Atk',
                  icon: Icons.close,
                  onAimDir: onMeleeAimDir,
                  onAimClear: onMeleeAimClear,
                  onCommit: onMeleeCommitted,
                  projectileAimPreview: meleeAimPreview,
                  affordable: meleeAffordable,
                  cooldownTicksLeft: meleeCooldownTicksLeft,
                  cooldownTicksTotal: meleeCooldownTicksTotal,
                  size: smallDirectionalSize,
                  deadzoneRadius: smallDeadzoneRadius,
                  backgroundColor: directional.backgroundColor,
                  foregroundColor: directional.foregroundColor,
                  labelFontSize: directional.labelFontSize,
                  labelGap: directional.labelGap,
                ),
        ),
/*         Positioned(
          right: rightFor(dashOffset, smallActionSize),
          bottom: bottomFor(dashOffset, smallActionSize),
          child: ActionButton(
            label: 'Dash',
            icon: Icons.flash_on,
            onPressed: onDashPressed,
            affordable: dashAffordable,
            cooldownTicksLeft: dashCooldownTicksLeft,
            cooldownTicksTotal: dashCooldownTicksTotal,
            size: smallActionSize,
            backgroundColor: action.backgroundColor,
            foregroundColor: action.foregroundColor,
            labelFontSize: action.labelFontSize,
            labelGap: action.labelGap,
          ),
        ), */
        Positioned(
          right: t.edgePadding,
          bottom: t.edgePadding,
          child: ActionButton(
            label: 'Jump',
            icon: Icons.arrow_upward,
            onPressed: onJumpPressed,
            affordable: jumpAffordable,
            size: jumpSize,
            backgroundColor: action.backgroundColor,
            foregroundColor: action.foregroundColor,
            labelFontSize: action.labelFontSize,
            labelGap: action.labelGap,
          ),
        ),
      ],
    );
  }
}
