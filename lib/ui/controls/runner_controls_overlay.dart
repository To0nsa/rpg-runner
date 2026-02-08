import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/input/aim_preview.dart';
import '../../game/input/charge_preview.dart';
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

    // Uniform size for all buttons in the grid
    final btnSize = action.size;

    // Grid configuration
    final gap = t.buttonGap;

    // 2x3 Grid definition (col, row) -> 0-indexed
    // col 0 is rightmost, row 0 is bottom
    //
    // [Secondary (0,1)] [Projectile (1,1)] [Bonus (2,1)]
    // [Jump (0,0)]      [Melee (1,0)]      [Dash (2,0)]

    double rightForCol(int col) {
      return t.edgePadding + col * (btnSize + gap);
    }

    double bottomForRow(int row) {
      return t.edgePadding + row * (btnSize + gap);
    }

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

        // --- Row 1 (Top) ---

        // Mob (Dash): Col 0, Row 1 (Top Right)
        Positioned(
          right: rightForCol(0),
          bottom: bottomForRow(1),
          child: ActionButton(
            label: 'Mob',
            icon: Icons.flash_on,
            onPressed: onDashPressed,
            affordable: dashAffordable,
            cooldownTicksLeft: dashCooldownTicksLeft,
            cooldownTicksTotal: dashCooldownTicksTotal,
            size: btnSize,
            backgroundColor: action.backgroundColor,
            foregroundColor: action.foregroundColor,
            labelFontSize: action.labelFontSize,
            labelGap: action.labelGap,
          ),
        ),

        // Prim (Melee): Col 1, Row 1 (Top Middle)
        Positioned(
          right: rightForCol(1),
          bottom: bottomForRow(1),
          child: meleeInputMode == AbilityInputMode.tap
              ? ActionButton(
                  label: 'Prim',
                  icon: Icons.close,
                  onPressed: onMeleePressed,
                  affordable: meleeAffordable,
                  cooldownTicksLeft: meleeCooldownTicksLeft,
                  cooldownTicksTotal: meleeCooldownTicksTotal,
                  size: btnSize,
                  backgroundColor: action.backgroundColor,
                  foregroundColor: action.foregroundColor,
                  labelFontSize: action.labelFontSize,
                  labelGap: action.labelGap,
                )
              : DirectionalActionButton(
                  label: 'Prim',
                  icon: Icons.close,
                  onAimDir: onMeleeAimDir,
                  onAimClear: onMeleeAimClear,
                  onCommit: onMeleeCommitted,
                  projectileAimPreview: meleeAimPreview,
                  cancelHitboxRect: aimCancelHitboxRect,
                  affordable: meleeAffordable,
                  cooldownTicksLeft: meleeCooldownTicksLeft,
                  cooldownTicksTotal: meleeCooldownTicksTotal,
                  size: btnSize,
                  deadzoneRadius: directional.deadzoneRadius,
                  backgroundColor: directional.backgroundColor,
                  foregroundColor: directional.foregroundColor,
                  labelFontSize: directional.labelFontSize,
                  labelGap: directional.labelGap,
                  forceCancelSignal: forceAimCancelSignal,
                ),
        ),

        // Proj (Projectile): Col 2, Row 1 (Top Left)
        Positioned(
          right: rightForCol(2),
          bottom: bottomForRow(1),
          child: projectileInputMode == AbilityInputMode.tap
              ? ActionButton(
                  label: 'Proj',
                  icon: Icons.auto_awesome,
                  onPressed: onProjectilePressed,
                  affordable: projectileAffordable,
                  cooldownTicksLeft: projectileCooldownTicksLeft,
                  cooldownTicksTotal: projectileCooldownTicksTotal,
                  size: btnSize,
                  backgroundColor: action.backgroundColor,
                  foregroundColor: action.foregroundColor,
                  labelFontSize: action.labelFontSize,
                  labelGap: action.labelGap,
                )
              : DirectionalActionButton(
                  label: 'Proj',
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
                  size: btnSize,
                  deadzoneRadius:
                      directional.deadzoneRadius, // Use standard deadzone
                  backgroundColor: directional.backgroundColor,
                  foregroundColor: directional.foregroundColor,
                  labelFontSize: directional.labelFontSize,
                  labelGap: directional.labelGap,
                  forceCancelSignal: forceAimCancelSignal,
                ),
        ),

        // --- Row 0 (Bottom) ---

        // Jump: Col 0, Row 0 (Bottom Right)
        Positioned(
          right: rightForCol(0),
          bottom: bottomForRow(0),
          child: ActionButton(
            label: 'Jump',
            icon: Icons.arrow_upward,
            onPressed: onJumpPressed,
            affordable: jumpAffordable,
            size: btnSize,
            backgroundColor: action.backgroundColor,
            foregroundColor: action.foregroundColor,
            labelFontSize: action.labelFontSize,
            labelGap: action.labelGap,
          ),
        ),

        // Sec (Secondary): Col 1, Row 0 (Bottom Middle)
        Positioned(
          right: rightForCol(1),
          bottom: bottomForRow(0),
          child: ActionButton(
            label: 'Sec',
            icon: Icons.shield,
            onPressed: onSecondaryPressed,
            affordable: secondaryAffordable,
            cooldownTicksLeft: secondaryCooldownTicksLeft,
            cooldownTicksTotal: secondaryCooldownTicksTotal,
            size: btnSize,
            backgroundColor: action.backgroundColor,
            foregroundColor: action.foregroundColor,
            labelFontSize: action.labelFontSize,
            labelGap: action.labelGap,
          ),
        ),

        // Bonus: Col 2, Row 0 (Bottom Left)
        Positioned(
          right: rightForCol(2),
          bottom: bottomForRow(0),
          child: bonusInputMode == AbilityInputMode.tap
              ? ActionButton(
                  label: 'Bonus',
                  icon: Icons.star,
                  onPressed: onBonusPressed,
                  affordable: bonusAffordable,
                  cooldownTicksLeft: bonusCooldownTicksLeft,
                  cooldownTicksTotal: bonusCooldownTicksTotal,
                  size: btnSize,
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
                  size: btnSize,
                  deadzoneRadius: directional.deadzoneRadius,
                  backgroundColor: directional.backgroundColor,
                  foregroundColor: directional.foregroundColor,
                  labelFontSize: directional.labelFontSize,
                  labelGap: directional.labelGap,
                  forceCancelSignal: forceAimCancelSignal,
                ),
        ),
        ValueListenableBuilder<ChargePreviewState>(
          valueListenable: projectileChargePreview,
          builder: (context, state, _) {
            if (!state.active) return const SizedBox.shrink();
            if (state.ownerId != 'projectile' && state.ownerId != 'bonus') {
              return const SizedBox.shrink();
            }
            final targetRow = state.ownerId == 'projectile' ? 1 : 0;
            return Positioned(
              right: rightForCol(2),
              bottom: bottomForRow(targetRow) + btnSize + 8,
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
