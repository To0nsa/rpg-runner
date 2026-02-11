import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'action_button.dart';
import 'controls_tuning.dart';
import 'directional_action_button.dart';
import 'hold_action_button.dart';
import 'layout/controls_radial_layout.dart';
import 'widgets/bonus_control.dart';
import 'widgets/melee_control.dart';
import 'widgets/movement_control.dart';
import 'widgets/projectile_control.dart';

/// Radial in-run control overlay that maps ability modes to concrete widgets.
///
/// This widget is composition-only: it receives authoritative affordability,
/// cooldown ticks, and input modes from outside, then renders the corresponding
/// controls and forwards UI intent callbacks.
class RunnerControlsOverlay extends StatelessWidget {
  const RunnerControlsOverlay({
    super.key,
    required this.onMoveAxis,
    required this.onJumpPressed,
    required this.onDashPressed,
    required this.onSecondaryPressed,
    required this.onSecondaryCommitted,
    required this.onSecondaryHoldStart,
    required this.onSecondaryHoldEnd,
    required this.onBonusPressed,
    required this.onProjectileCommitted,
    required this.onProjectilePressed,
    required this.onProjectileHoldStart,
    required this.onProjectileHoldEnd,
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
    required this.onMeleeHoldStart,
    required this.onMeleeHoldEnd,
    required this.onMeleeChargeHoldStart,
    required this.onMeleeChargeHoldEnd,
    required this.meleeAimPreview,
    required this.aimCancelHitboxRect,
    required this.meleeAffordable,
    required this.meleeCooldownTicksLeft,
    required this.meleeCooldownTicksTotal,
    required this.meleeInputMode,
    required this.secondaryInputMode,
    required this.projectileInputMode,
    required this.chargeBarVisible,
    required this.chargeBarProgress01,
    required this.chargeBarTier,
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
  final VoidCallback onSecondaryCommitted;
  final VoidCallback onSecondaryHoldStart;
  final VoidCallback onSecondaryHoldEnd;
  final VoidCallback onBonusPressed;
  final VoidCallback onProjectileCommitted;
  final VoidCallback onProjectilePressed;
  final VoidCallback onProjectileHoldStart;
  final VoidCallback onProjectileHoldEnd;
  final void Function(double x, double y) onProjectileAimDir;
  final VoidCallback onProjectileAimClear;
  final AimPreviewModel projectileAimPreview;
  final bool chargeBarVisible;
  final double chargeBarProgress01;
  final int chargeBarTier;
  final bool projectileAffordable;
  final int projectileCooldownTicksLeft;
  final int projectileCooldownTicksTotal;
  final void Function(double x, double y) onMeleeAimDir;
  final VoidCallback onMeleeAimClear;
  final VoidCallback onMeleeCommitted;
  final VoidCallback onMeleePressed;
  final VoidCallback onMeleeHoldStart;
  final VoidCallback onMeleeHoldEnd;
  final VoidCallback onMeleeChargeHoldStart;
  final VoidCallback onMeleeChargeHoldEnd;
  final AimPreviewModel meleeAimPreview;
  final ValueListenable<Rect?> aimCancelHitboxRect;
  final bool meleeAffordable;
  final int meleeCooldownTicksLeft;
  final int meleeCooldownTicksTotal;
  final AbilityInputMode meleeInputMode;
  final AbilityInputMode secondaryInputMode;
  final AbilityInputMode projectileInputMode;
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
    final cooldownRing = style.cooldownRing;
    final layout = ControlsRadialLayoutSolver.solve(
      layout: tuning.layout,
      action: action,
      directional: style.directionalActionButton,
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
            onHoldStart: onProjectileHoldStart,
            onHoldEnd: onProjectileHoldEnd,
            onAimDir: onProjectileAimDir,
            onAimClear: onProjectileAimClear,
            onCommitted: onProjectileCommitted,
            aimPreview: projectileAimPreview,
            affordable: projectileAffordable,
            cooldownTicksLeft: projectileCooldownTicksLeft,
            cooldownTicksTotal: projectileCooldownTicksTotal,
            cancelHitboxRect: aimCancelHitboxRect,
            forceCancelSignal: forceAimCancelSignal,
          ),
        ),
        Positioned(
          right: layout.bonus.right,
          bottom: layout.bonus.bottom,
          child: BonusControl(
            tuning: tuning,
            size: layout.actionSize,
            onPressed: onBonusPressed,
            affordable: bonusAffordable,
            cooldownTicksLeft: bonusCooldownTicksLeft,
            cooldownTicksTotal: bonusCooldownTicksTotal,
          ),
        ),
        Positioned(
          right: layout.secondary.right,
          bottom: layout.secondary.bottom,
          child: secondaryInputMode == AbilityInputMode.holdMaintain
              ? HoldActionButton(
                  label: 'Sec',
                  icon: Icons.shield,
                  onHoldStart: onSecondaryHoldStart,
                  onHoldEnd: onSecondaryHoldEnd,
                  tuning: action,
                  cooldownRing: cooldownRing,
                  affordable: secondaryAffordable,
                  cooldownTicksLeft: secondaryCooldownTicksLeft,
                  cooldownTicksTotal: secondaryCooldownTicksTotal,
                  size: layout.actionSize,
                )
              : secondaryInputMode == AbilityInputMode.holdAimRelease
              ? DirectionalActionButton(
                  label: 'Sec',
                  icon: Icons.shield,
                  onHoldStart: onSecondaryHoldStart,
                  onHoldEnd: onSecondaryHoldEnd,
                  onAimDir: onMeleeAimDir,
                  onAimClear: onMeleeAimClear,
                  onCommit: onSecondaryCommitted,
                  projectileAimPreview: meleeAimPreview,
                  tuning: style.directionalActionButton,
                  cooldownRing: cooldownRing,
                  cancelHitboxRect: aimCancelHitboxRect,
                  affordable: secondaryAffordable,
                  cooldownTicksLeft: secondaryCooldownTicksLeft,
                  cooldownTicksTotal: secondaryCooldownTicksTotal,
                  size: layout.directionalSize,
                  deadzoneRadius: layout.directionalDeadzoneRadius,
                  forceCancelSignal: forceAimCancelSignal,
                )
              : ActionButton(
                  label: 'Sec',
                  icon: Icons.shield,
                  onPressed: onSecondaryPressed,
                  tuning: action,
                  cooldownRing: cooldownRing,
                  affordable: secondaryAffordable,
                  cooldownTicksLeft: secondaryCooldownTicksLeft,
                  cooldownTicksTotal: secondaryCooldownTicksTotal,
                  size: layout.actionSize,
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
            onHoldStart: onMeleeHoldStart,
            onHoldEnd: onMeleeHoldEnd,
            onChargeHoldStart: onMeleeChargeHoldStart,
            onChargeHoldEnd: onMeleeChargeHoldEnd,
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
            tuning: action,
            cooldownRing: cooldownRing,
            affordable: dashAffordable,
            cooldownTicksLeft: dashCooldownTicksLeft,
            cooldownTicksTotal: dashCooldownTicksTotal,
            size: layout.actionSize,
          ),
        ),
        Positioned(
          right: layout.jump.right,
          bottom: layout.jump.bottom,
          child: ActionButton(
            label: 'Jump',
            icon: Icons.arrow_upward,
            onPressed: onJumpPressed,
            tuning: action,
            cooldownRing: cooldownRing,
            affordable: jumpAffordable,
            size: layout.jumpSize,
          ),
        ),
        if (chargeBarVisible)
          Positioned(
            right: layout.projectileCharge.right,
            bottom: layout.projectileCharge.bottom,
            child: _ChargeBar(
              tuning: style.chargeBar,
              progress01: chargeBarProgress01,
              tier: chargeBarTier,
            ),
          ),
      ],
    );
  }
}

class _ChargeBar extends StatelessWidget {
  const _ChargeBar({
    required this.tuning,
    required this.progress01,
    required this.tier,
  });

  final ChargeBarTuning tuning;

  /// Normalized progress in [0, 1].
  final double progress01;

  /// Charge tier bucket: 0 = idle, 1 = half, 2 = full.
  final int tier;

  @override
  Widget build(BuildContext context) {
    final clamped = progress01.clamp(0.0, 1.0);
    final fillColor = switch (tier) {
      2 => tuning.fullTierColor,
      1 => tuning.halfTierColor,
      _ => tuning.idleColor,
    };
    return Container(
      width: tuning.width,
      height: tuning.height,
      padding: EdgeInsets.all(tuning.padding),
      decoration: BoxDecoration(
        color: tuning.backgroundColor,
        borderRadius: BorderRadius.circular(tuning.outerRadius),
        border: Border.all(
          color: tuning.borderColor,
          width: tuning.borderWidth,
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          child: Container(
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(tuning.innerRadius),
            ),
          ),
        ),
      ),
    );
  }
}
