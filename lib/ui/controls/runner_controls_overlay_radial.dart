import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';
import '../../game/input/charge_preview.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'action_button.dart';
import 'controls_tuning.dart';
import 'layout/controls_radial_layout.dart';
import 'widgets/bonus_control.dart';
import 'widgets/melee_control.dart';
import 'widgets/movement_control.dart';
import 'widgets/projectile_control.dart';

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
    final style = tuning.style;
    final action = style.actionButton;
    final layout = ControlsRadialLayoutSolver.solve(
      layout: tuning.layout,
      action: action,
      directional: style.directionalActionButton,
      bonusMode: bonusInputMode == AbilityInputMode.tap
          ? BonusAnchorMode.tap
          : BonusAnchorMode.directional,
    );

    return Stack(
      children: [
        Positioned(
          left: tuning.layout.edgePadding,
          bottom: tuning.layout.bottomEdgePadding,
          child: MovementControl(tuning: tuning, onMoveAxis: onMoveAxis),
        ),
        Positioned(
          right: layout.projectile.right,
          bottom: layout.projectile.bottom,
          child: ProjectileControl(
            tuning: tuning,
            inputMode: projectileInputMode,
            size: layout.directionalSize,
            deadzoneRadius: layout.directionalDeadzoneRadius,
            onPressed: onProjectilePressed,
            onAimDir: onProjectileAimDir,
            onAimClear: onProjectileAimClear,
            onCommitted: onProjectileCommitted,
            aimPreview: projectileAimPreview,
            chargePreview: projectileChargePreview,
            affordable: projectileAffordable,
            cooldownTicksLeft: projectileCooldownTicksLeft,
            cooldownTicksTotal: projectileCooldownTicksTotal,
            cancelHitboxRect: aimCancelHitboxRect,
            chargeEnabled: projectileChargeEnabled,
            chargeHalfTicks: projectileChargeHalfTicks,
            chargeFullTicks: projectileChargeFullTicks,
            simulationTickHz: simulationTickHz,
            forceCancelSignal: forceAimCancelSignal,
          ),
        ),
        Positioned(
          right: layout.bonus.right,
          bottom: layout.bonus.bottom,
          child: BonusControl(
            tuning: tuning,
            inputMode: bonusInputMode,
            usesMeleeAim: bonusUsesMeleeAim,
            size: bonusInputMode == AbilityInputMode.tap
                ? layout.actionSize
                : layout.directionalSize,
            deadzoneRadius: layout.directionalDeadzoneRadius,
            onPressed: onBonusPressed,
            onProjectileAimDir: onProjectileAimDir,
            onProjectileAimClear: onProjectileAimClear,
            onMeleeAimDir: onMeleeAimDir,
            onMeleeAimClear: onMeleeAimClear,
            onCommitted: onBonusCommitted,
            projectileAimPreview: projectileAimPreview,
            meleeAimPreview: meleeAimPreview,
            chargePreview: projectileChargePreview,
            affordable: bonusAffordable,
            cooldownTicksLeft: bonusCooldownTicksLeft,
            cooldownTicksTotal: bonusCooldownTicksTotal,
            cancelHitboxRect: aimCancelHitboxRect,
            chargeEnabled: bonusChargeEnabled,
            chargeHalfTicks: bonusChargeHalfTicks,
            chargeFullTicks: bonusChargeFullTicks,
            simulationTickHz: simulationTickHz,
            forceCancelSignal: forceAimCancelSignal,
          ),
        ),
        Positioned(
          right: layout.secondary.right,
          bottom: layout.secondary.bottom,
          child: ActionButton(
            label: 'Sec',
            icon: Icons.shield,
            onPressed: onSecondaryPressed,
            affordable: secondaryAffordable,
            cooldownTicksLeft: secondaryCooldownTicksLeft,
            cooldownTicksTotal: secondaryCooldownTicksTotal,
            size: layout.actionSize,
            backgroundColor: action.backgroundColor,
            foregroundColor: action.foregroundColor,
            labelFontSize: action.labelFontSize,
            labelGap: action.labelGap,
          ),
        ),
        Positioned(
          right: layout.melee.right,
          bottom: layout.melee.bottom,
          child: MeleeControl(
            tuning: tuning,
            inputMode: meleeInputMode,
            size: layout.directionalSize,
            deadzoneRadius: layout.directionalDeadzoneRadius,
            onPressed: onMeleePressed,
            onAimDir: onMeleeAimDir,
            onAimClear: onMeleeAimClear,
            onCommitted: onMeleeCommitted,
            aimPreview: meleeAimPreview,
            affordable: meleeAffordable,
            cooldownTicksLeft: meleeCooldownTicksLeft,
            cooldownTicksTotal: meleeCooldownTicksTotal,
            cancelHitboxRect: aimCancelHitboxRect,
            forceCancelSignal: forceAimCancelSignal,
          ),
        ),
        Positioned(
          right: layout.dash.right,
          bottom: layout.dash.bottom,
          child: ActionButton(
            label: 'Dash',
            icon: Icons.flash_on,
            onPressed: onDashPressed,
            affordable: dashAffordable,
            cooldownTicksLeft: dashCooldownTicksLeft,
            cooldownTicksTotal: dashCooldownTicksTotal,
            size: layout.actionSize,
            backgroundColor: action.backgroundColor,
            foregroundColor: action.foregroundColor,
            labelFontSize: action.labelFontSize,
            labelGap: action.labelGap,
          ),
        ),
        Positioned(
          right: layout.jump.right,
          bottom: layout.jump.bottom,
          child: ActionButton(
            label: 'Jump',
            icon: Icons.arrow_upward,
            onPressed: onJumpPressed,
            affordable: jumpAffordable,
            size: layout.jumpSize,
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
            final charge = state.ownerId == 'projectile'
                ? layout.projectileCharge
                : layout.bonusCharge;
            return Positioned(
              right: charge.right,
              bottom: charge.bottom,
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
