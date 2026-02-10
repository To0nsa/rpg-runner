import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';
import '../../game/input/charge_preview.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'action_button.dart';
import 'controls_tuning.dart';
import 'directional_action_button.dart';
import 'move_buttons.dart';

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
    required this.aimCancelHitboxRect,
    required this.meleeAffordable,
    required this.meleeCooldownTicksLeft,
    required this.meleeCooldownTicksTotal,
    required this.meleeInputMode,
    required this.projectileInputMode,
    required this.bonusInputMode,
    required this.bonusUsesMeleeAim,
    required this.projectileChargePreview,
    required this.projectileChargeEnabled,
    required this.projectileChargeHalfTicks,
    required this.projectileChargeFullTicks,
    required this.bonusChargeEnabled,
    required this.bonusChargeHalfTicks,
    required this.bonusChargeFullTicks,
    required this.simulationTickHz,
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
    required this.forceAimCancelSignal,
    this.tuning = ControlsTuning.fixed,
  });

  final ValueChanged<double> onMoveAxis;
  final VoidCallback onJumpPressed;
  final VoidCallback onDashPressed;
  final VoidCallback onSecondaryPressed;
  final VoidCallback onBonusPressed;
  final ValueChanged<int> onBonusCommitted;
  final ValueChanged<int> onProjectileCommitted;
  final VoidCallback onProjectilePressed;
  final void Function(double x, double y) onProjectileAimDir;
  final VoidCallback onProjectileAimClear;
  final AimPreviewModel projectileAimPreview;
  final ChargePreviewModel projectileChargePreview;
  final bool projectileAffordable;
  final int projectileCooldownTicksLeft;
  final int projectileCooldownTicksTotal;
  final void Function(double x, double y) onMeleeAimDir;
  final VoidCallback onMeleeAimClear;
  final VoidCallback onMeleeCommitted;
  final VoidCallback onMeleePressed;
  final AimPreviewModel meleeAimPreview;
  final ValueListenable<Rect?> aimCancelHitboxRect;
  final bool meleeAffordable;
  final int meleeCooldownTicksLeft;
  final int meleeCooldownTicksTotal;
  final AbilityInputMode meleeInputMode;
  final AbilityInputMode projectileInputMode;

  final AbilityInputMode bonusInputMode;
  final bool bonusUsesMeleeAim;
  final bool projectileChargeEnabled;
  final int projectileChargeHalfTicks;
  final int projectileChargeFullTicks;
  final bool bonusChargeEnabled;
  final int bonusChargeHalfTicks;
  final int bonusChargeFullTicks;
  final int simulationTickHz;
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
  final ValueListenable<int> forceAimCancelSignal;
  final ControlsTuning tuning;

  @override
  Widget build(BuildContext context) {
    final t = tuning;
    final action = t.actionButton;
    final directional = t.directionalActionButton;
    final jumpSize = action.size * 1.6;
    final smallActionSize = action.size * 1.0;
    final smallDirectionalSize = directional.size * 1.0;
    final smallDeadzoneRadius = directional.deadzoneRadius * 1.0;

    Offset polar(double radius, double degrees) {
      final radians = degrees * math.pi / 180.0;
      return Offset(math.cos(radians) * radius, math.sin(radians) * radius);
    }

    double rightFor(Offset centerOffset, double targetSize) {
      return t.edgePadding +
          jumpSize * 0.5 -
          centerOffset.dx -
          targetSize * 0.5;
    }

    double bottomFor(Offset centerOffset, double targetSize) {
      return t.edgePadding +
          jumpSize * 0.5 -
          centerOffset.dy -
          targetSize * 0.5;
    }

    final jumpRadius = jumpSize * 0.5;
    final ringGap = t.buttonGap * 0.9;
    final ringRadius =
        jumpRadius +
        math.max(smallDirectionalSize, smallActionSize) * 0.5 +
        ringGap;

    const startDeg = 160.0;
    const stepDeg = 35.0;

    final dashOffset = polar(ringRadius, startDeg + stepDeg * -0.4);
    final meleeOffset = polar(ringRadius, startDeg + stepDeg * 3.8);
    final secondaryOffset = polar(ringRadius, startDeg + stepDeg * 1.0);
    final projectileOffset = polar(ringRadius, startDeg + stepDeg * 2.4);
    const bonusVerticalOffset = 72.0;
    final bonusButtonSize = bonusInputMode == AbilityInputMode.tap
        ? smallActionSize
        : smallDirectionalSize;
    final bonusRight = rightFor(meleeOffset, bonusButtonSize);
    final bonusBottom =
        bottomFor(meleeOffset, bonusButtonSize) + bonusVerticalOffset;

    return Stack(
      children: [
        Positioned(
          left: t.edgePadding,
          bottom: t.bottomEdgePadding,
          child: MoveButtons(
            onAxisChanged: onMoveAxis,
            buttonWidth: t.moveButtonWidth,
            buttonHeight: t.moveButtonHeight,
            gap: t.moveButtonGap,
            backgroundColor: t.moveButtonBackgroundColor,
            foregroundColor: t.moveButtonForegroundColor,
            borderColor: t.moveButtonBorderColor,
            borderWidth: t.moveButtonBorderWidth,
            borderRadius: t.moveButtonBorderRadius,
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
                  onCommit: () => onProjectileCommitted(0),
                  onChargeCommit: onProjectileCommitted,
                  chargePreview: projectileChargePreview,
                  chargeOwnerId: 'projectile',
                  chargeHalfTicks: projectileChargeEnabled
                      ? projectileChargeHalfTicks
                      : 0,
                  chargeFullTicks: projectileChargeEnabled
                      ? projectileChargeFullTicks
                      : 0,
                  chargeTickHz: simulationTickHz,
                  projectileAimPreview: projectileAimPreview,
                  cancelHitboxRect: aimCancelHitboxRect,
                  affordable: projectileAffordable,
                  cooldownTicksLeft: projectileCooldownTicksLeft,
                  cooldownTicksTotal: projectileCooldownTicksTotal,
                  size: smallDirectionalSize,
                  deadzoneRadius: smallDeadzoneRadius,
                  backgroundColor: directional.backgroundColor,
                  foregroundColor: directional.foregroundColor,
                  labelFontSize: directional.labelFontSize,
                  labelGap: directional.labelGap,
                  forceCancelSignal: forceAimCancelSignal,
                ),
        ),
        Positioned(
          right: bonusRight,
          bottom: bonusBottom,
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
                  onAimDir: bonusUsesMeleeAim
                      ? onMeleeAimDir
                      : onProjectileAimDir,
                  onAimClear: bonusUsesMeleeAim
                      ? onMeleeAimClear
                      : onProjectileAimClear,
                  onCommit: () => onBonusCommitted(0),
                  onChargeCommit: onBonusCommitted,
                  chargePreview: bonusUsesMeleeAim
                      ? null
                      : projectileChargePreview,
                  chargeOwnerId: 'bonus',
                  chargeHalfTicks: (!bonusUsesMeleeAim && bonusChargeEnabled)
                      ? bonusChargeHalfTicks
                      : 0,
                  chargeFullTicks: (!bonusUsesMeleeAim && bonusChargeEnabled)
                      ? bonusChargeFullTicks
                      : 0,
                  chargeTickHz: simulationTickHz,
                  projectileAimPreview: bonusUsesMeleeAim
                      ? meleeAimPreview
                      : projectileAimPreview,
                  cancelHitboxRect: aimCancelHitboxRect,
                  affordable: bonusAffordable,
                  cooldownTicksLeft: bonusCooldownTicksLeft,
                  cooldownTicksTotal: bonusCooldownTicksTotal,
                  size: smallDirectionalSize,
                  deadzoneRadius: smallDeadzoneRadius,
                  backgroundColor: directional.backgroundColor,
                  foregroundColor: directional.foregroundColor,
                  labelFontSize: directional.labelFontSize,
                  labelGap: directional.labelGap,
                  forceCancelSignal: forceAimCancelSignal,
                ),
        ),
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
                  cancelHitboxRect: aimCancelHitboxRect,
                  affordable: meleeAffordable,
                  cooldownTicksLeft: meleeCooldownTicksLeft,
                  cooldownTicksTotal: meleeCooldownTicksTotal,
                  size: smallDirectionalSize,
                  deadzoneRadius: smallDeadzoneRadius,
                  backgroundColor: directional.backgroundColor,
                  foregroundColor: directional.foregroundColor,
                  labelFontSize: directional.labelFontSize,
                  labelGap: directional.labelGap,
                  forceCancelSignal: forceAimCancelSignal,
                ),
        ),
        Positioned(
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
        ),
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
        ValueListenableBuilder<ChargePreviewState>(
          valueListenable: projectileChargePreview,
          builder: (context, state, _) {
            if (!state.active) return const SizedBox.shrink();
            if (state.ownerId != 'projectile' && state.ownerId != 'bonus') {
              return const SizedBox.shrink();
            }
            final chargeRight = state.ownerId == 'projectile'
                ? rightFor(projectileOffset, smallDirectionalSize)
                : bonusRight;
            final chargeBottom = state.ownerId == 'projectile'
                ? bottomFor(projectileOffset, smallDirectionalSize) +
                      smallDirectionalSize +
                      8
                : bonusBottom + bonusButtonSize + 8;
            return Positioned(
              right: chargeRight,
              bottom: chargeBottom,
              child: _ChargeBar(progress01: state.progress01, tier: state.tier),
            );
          },
        ),
      ],
    );
  }
}

class _ChargeBar extends StatelessWidget {
  const _ChargeBar({required this.progress01, required this.tier});

  final double progress01;
  final int tier;

  @override
  Widget build(BuildContext context) {
    final clamped = progress01.clamp(0.0, 1.0);
    final fillColor = switch (tier) {
      2 => const Color(0xFF6EDC8C),
      1 => const Color(0xFFF0C15A),
      _ => const Color(0xFF9FA8B2),
    };
    return Container(
      width: 84,
      height: 14,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xAA11161D),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF2C3A47), width: 1),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          child: Container(
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      ),
    );
  }
}
