import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:rpg_runner/core/abilities/ability_def.dart';
import '../../game/input/aim_preview.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'action_button.dart';
import 'ability_slot_visual_spec.dart';
import 'controls_tuning.dart';
import 'directional_action_button.dart';
import 'hold_action_button.dart';
import '../icons/ability_skill_icon.dart';
import 'layout/controls_radial_layout.dart';
import '../theme/ui_action_button_theme.dart';
import '../theme/ui_skill_icon_theme.dart';
import 'widgets/spell_control.dart';
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
    required this.onMobilityPressed,
    required this.onMobilityCommitted,
    required this.onMobilityHoldStart,
    required this.onMobilityHoldEnd,
    required this.onSecondaryPressed,
    required this.onSecondaryCommitted,
    required this.onSecondaryHoldStart,
    required this.onSecondaryHoldEnd,
    required this.onSpellPressed,
    required this.onProjectileCommitted,
    required this.onProjectilePressed,
    required this.onProjectileHoldStart,
    required this.onProjectileHoldEnd,
    required this.onAimDir,
    required this.onAimClear,
    required this.projectileAimPreview,
    required this.projectileAffordable,
    required this.projectileCooldownTicksLeft,
    required this.projectileCooldownTicksTotal,
    required this.onMeleeCommitted,
    required this.onMeleePressed,
    required this.onMeleeHoldStart,
    required this.onMeleeHoldEnd,
    required this.onMeleeChargeHoldStart,
    required this.onMeleeChargeHoldEnd,
    required this.equippedAbilityIdsBySlot,
    required this.meleeAimPreview,
    required this.aimCancelHitboxRect,
    required this.meleeAffordable,
    required this.meleeCooldownTicksLeft,
    required this.meleeCooldownTicksTotal,
    required this.meleeInputMode,
    required this.secondaryInputMode,
    required this.projectileInputMode,
    required this.mobilityInputMode,
    required this.chargeBarVisible,
    required this.chargeBarProgress01,
    required this.chargeBarTier,
    required this.jumpAffordable,
    required this.mobilityAffordable,
    required this.mobilityCooldownTicksLeft,
    required this.mobilityCooldownTicksTotal,
    required this.secondaryAffordable,
    required this.secondaryCooldownTicksLeft,
    required this.secondaryCooldownTicksTotal,
    required this.spellAffordable,
    required this.spellCooldownTicksLeft,
    required this.spellCooldownTicksTotal,
    required this.forceAimCancelSignal,
    this.tuning = ControlsTuning.fixed,
  });

  final ValueChanged<double> onMoveAxis;
  final VoidCallback onJumpPressed;
  final VoidCallback onMobilityPressed;
  final VoidCallback onMobilityCommitted;
  final VoidCallback onMobilityHoldStart;
  final VoidCallback onMobilityHoldEnd;
  final VoidCallback onSecondaryPressed;
  final VoidCallback onSecondaryCommitted;
  final VoidCallback onSecondaryHoldStart;
  final VoidCallback onSecondaryHoldEnd;
  final VoidCallback onSpellPressed;
  final VoidCallback onProjectileCommitted;
  final VoidCallback onProjectilePressed;
  final VoidCallback onProjectileHoldStart;
  final VoidCallback onProjectileHoldEnd;
  // Shared/global aim callbacks consumed by both projectile and melee controls.
  final void Function(double x, double y) onAimDir;
  final VoidCallback onAimClear;
  final AimPreviewModel projectileAimPreview;
  final bool chargeBarVisible;
  final double chargeBarProgress01;
  final int chargeBarTier;
  final bool projectileAffordable;
  final int projectileCooldownTicksLeft;
  final int projectileCooldownTicksTotal;
  final VoidCallback onMeleeCommitted;
  final VoidCallback onMeleePressed;
  final VoidCallback onMeleeHoldStart;
  final VoidCallback onMeleeHoldEnd;
  final VoidCallback onMeleeChargeHoldStart;
  final VoidCallback onMeleeChargeHoldEnd;
  final Map<AbilitySlot, AbilityKey> equippedAbilityIdsBySlot;
  final AimPreviewModel meleeAimPreview;
  final ValueListenable<Rect?> aimCancelHitboxRect;
  final bool meleeAffordable;
  final int meleeCooldownTicksLeft;
  final int meleeCooldownTicksTotal;
  final AbilityInputMode meleeInputMode;
  final AbilityInputMode secondaryInputMode;
  final AbilityInputMode projectileInputMode;
  final AbilityInputMode mobilityInputMode;
  final bool jumpAffordable;
  final bool mobilityAffordable;
  final int mobilityCooldownTicksLeft;
  final int mobilityCooldownTicksTotal;
  final bool secondaryAffordable;
  final int secondaryCooldownTicksLeft;
  final int secondaryCooldownTicksTotal;
  final bool spellAffordable;
  final int spellCooldownTicksLeft;
  final int spellCooldownTicksTotal;
  final ValueListenable<int> forceAimCancelSignal;
  final ControlsTuning tuning;

  @override
  Widget build(BuildContext context) {
    final themedTuning = _resolveRunControlsTuning(
      base: tuning,
      actionButtons: context.actionButtons,
    );
    final style = themedTuning.style;
    final action = style.actionButton;
    final directional = style.directionalActionButton;
    final cooldownRing = style.cooldownRing;
    final runAbilityIconSize = context.skillIcons.runRadialIconSize;
    final secondarySlot = abilityRadialLayoutSpec.slotSpec(
      AbilitySlot.secondary,
    );
    final mobilitySlot = abilityRadialLayoutSpec.slotSpec(AbilitySlot.mobility);
    final jumpSlot = abilityRadialLayoutSpec.slotSpec(AbilitySlot.jump);
    final layout = ControlsRadialLayoutSolver.solve(
      layout: themedTuning.layout,
      action: action,
      directional: directional,
    );
    ControlsAnchor anchorFor(AbilitySlot slot) =>
        abilityRadialLayoutSpec.anchorFor(layout: layout, slot: slot);
    double sizeFor(
      AbilitySlot slot, {
      AbilityRadialSlotFamily? familyOverride,
    }) => abilityRadialLayoutSpec.sizeFor(
      layout: layout,
      slot: slot,
      familyOverride: familyOverride,
    );
    String labelFor(AbilitySlot slot) =>
        abilityRadialLayoutSpec.slotSpec(slot).label.toUpperCase();
    Widget iconForSlot(AbilitySlot slot) => AbilitySkillIcon(
      abilityId: equippedAbilityIdsBySlot[slot],
      size: runAbilityIconSize,
    );

    return Stack(
      children: [
        Positioned(
          left: themedTuning.layout.edgePadding,
          bottom: themedTuning.layout.bottomEdgePadding,
          child: MovementControl(tuning: themedTuning, onMoveAxis: onMoveAxis),
        ),
        Positioned(
          right: anchorFor(AbilitySlot.projectile).right,
          bottom: anchorFor(AbilitySlot.projectile).bottom,
          child: ProjectileControl(
            tuning: themedTuning,
            inputMode: projectileInputMode,
            size: sizeFor(AbilitySlot.projectile),
            deadzoneRadius: layout.directionalDeadzoneRadius,
            label: labelFor(AbilitySlot.projectile),
            iconWidget: iconForSlot(AbilitySlot.projectile),
            onPressed: onProjectilePressed,
            onHoldStart: onProjectileHoldStart,
            onHoldEnd: onProjectileHoldEnd,
            onAimDir: onAimDir,
            onAimClear: onAimClear,
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
          right: anchorFor(AbilitySlot.spell).right,
          bottom: anchorFor(AbilitySlot.spell).bottom,
          child: SpellControl(
            tuning: themedTuning,
            size: sizeFor(AbilitySlot.spell),
            label: labelFor(AbilitySlot.spell),
            iconWidget: iconForSlot(AbilitySlot.spell),
            onPressed: onSpellPressed,
            affordable: spellAffordable,
            cooldownTicksLeft: spellCooldownTicksLeft,
            cooldownTicksTotal: spellCooldownTicksTotal,
          ),
        ),
        Positioned(
          right: anchorFor(AbilitySlot.secondary).right,
          bottom: anchorFor(AbilitySlot.secondary).bottom,
          child: secondaryInputMode == AbilityInputMode.holdMaintain
              ? HoldActionButton(
                  label: labelFor(AbilitySlot.secondary),
                  icon: secondarySlot.icon,
                  iconWidget: iconForSlot(AbilitySlot.secondary),
                  onHoldStart: onSecondaryHoldStart,
                  onHoldEnd: onSecondaryHoldEnd,
                  tuning: action,
                  cooldownRing: cooldownRing,
                  affordable: secondaryAffordable,
                  cooldownTicksLeft: secondaryCooldownTicksLeft,
                  cooldownTicksTotal: secondaryCooldownTicksTotal,
                  size: sizeFor(AbilitySlot.secondary),
                )
              : secondaryInputMode == AbilityInputMode.holdRelease
              ? HoldActionButton(
                  label: labelFor(AbilitySlot.secondary),
                  icon: secondarySlot.icon,
                  iconWidget: iconForSlot(AbilitySlot.secondary),
                  onHoldStart: onSecondaryHoldStart,
                  onHoldEnd: onSecondaryHoldEnd,
                  onRelease: onSecondaryCommitted,
                  tuning: action,
                  cooldownRing: cooldownRing,
                  affordable: secondaryAffordable,
                  cooldownTicksLeft: secondaryCooldownTicksLeft,
                  cooldownTicksTotal: secondaryCooldownTicksTotal,
                  size: sizeFor(AbilitySlot.secondary),
                )
              : secondaryInputMode == AbilityInputMode.holdAimRelease
              ? DirectionalActionButton(
                  label: labelFor(AbilitySlot.secondary),
                  icon: secondarySlot.icon,
                  iconWidget: iconForSlot(AbilitySlot.secondary),
                  onHoldStart: onSecondaryHoldStart,
                  onHoldEnd: onSecondaryHoldEnd,
                  onAimDir: onAimDir,
                  onAimClear: onAimClear,
                  onCommit: onSecondaryCommitted,
                  projectileAimPreview: meleeAimPreview,
                  tuning: directional,
                  cooldownRing: cooldownRing,
                  cancelHitboxRect: aimCancelHitboxRect,
                  affordable: secondaryAffordable,
                  cooldownTicksLeft: secondaryCooldownTicksLeft,
                  cooldownTicksTotal: secondaryCooldownTicksTotal,
                  size: sizeFor(
                    AbilitySlot.secondary,
                    familyOverride: AbilityRadialSlotFamily.directional,
                  ),
                  deadzoneRadius: layout.directionalDeadzoneRadius,
                  forceCancelSignal: forceAimCancelSignal,
                )
              : ActionButton(
                  label: labelFor(AbilitySlot.secondary),
                  icon: secondarySlot.icon,
                  iconWidget: iconForSlot(AbilitySlot.secondary),
                  onPressed: onSecondaryPressed,
                  tuning: action,
                  cooldownRing: cooldownRing,
                  affordable: secondaryAffordable,
                  cooldownTicksLeft: secondaryCooldownTicksLeft,
                  cooldownTicksTotal: secondaryCooldownTicksTotal,
                  size: sizeFor(AbilitySlot.secondary),
                ),
        ),
        Positioned(
          right: anchorFor(AbilitySlot.primary).right,
          bottom: anchorFor(AbilitySlot.primary).bottom,
          child: MeleeControl(
            tuning: themedTuning,
            inputMode: meleeInputMode,
            size: sizeFor(AbilitySlot.primary),
            deadzoneRadius: layout.directionalDeadzoneRadius,
            label: labelFor(AbilitySlot.primary),
            iconWidget: iconForSlot(AbilitySlot.primary),
            onPressed: onMeleePressed,
            onHoldStart: onMeleeHoldStart,
            onHoldEnd: onMeleeHoldEnd,
            onChargeHoldStart: onMeleeChargeHoldStart,
            onChargeHoldEnd: onMeleeChargeHoldEnd,
            onAimDir: onAimDir,
            onAimClear: onAimClear,
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
          right: anchorFor(AbilitySlot.mobility).right,
          bottom: anchorFor(AbilitySlot.mobility).bottom,
          child: mobilityInputMode == AbilityInputMode.tap
              ? ActionButton(
                  label: labelFor(AbilitySlot.mobility),
                  icon: mobilitySlot.icon,
                  iconWidget: iconForSlot(AbilitySlot.mobility),
                  onPressed: onMobilityPressed,
                  tuning: action,
                  cooldownRing: cooldownRing,
                  affordable: mobilityAffordable,
                  cooldownTicksLeft: mobilityCooldownTicksLeft,
                  cooldownTicksTotal: mobilityCooldownTicksTotal,
                  size: sizeFor(AbilitySlot.mobility),
                )
              : mobilityInputMode == AbilityInputMode.holdMaintain
              ? HoldActionButton(
                  label: labelFor(AbilitySlot.mobility),
                  icon: mobilitySlot.icon,
                  iconWidget: iconForSlot(AbilitySlot.mobility),
                  onHoldStart: onMobilityHoldStart,
                  onHoldEnd: onMobilityHoldEnd,
                  tuning: action,
                  cooldownRing: cooldownRing,
                  affordable: mobilityAffordable,
                  cooldownTicksLeft: mobilityCooldownTicksLeft,
                  cooldownTicksTotal: mobilityCooldownTicksTotal,
                  size: sizeFor(AbilitySlot.mobility),
                )
              : mobilityInputMode == AbilityInputMode.holdRelease
              ? HoldActionButton(
                  label: labelFor(AbilitySlot.mobility),
                  icon: mobilitySlot.icon,
                  iconWidget: iconForSlot(AbilitySlot.mobility),
                  onHoldStart: onMobilityHoldStart,
                  onHoldEnd: onMobilityHoldEnd,
                  onRelease: onMobilityCommitted,
                  tuning: action,
                  cooldownRing: cooldownRing,
                  affordable: mobilityAffordable,
                  cooldownTicksLeft: mobilityCooldownTicksLeft,
                  cooldownTicksTotal: mobilityCooldownTicksTotal,
                  size: sizeFor(AbilitySlot.mobility),
                )
              : DirectionalActionButton(
                  label: labelFor(AbilitySlot.mobility),
                  icon: mobilitySlot.icon,
                  iconWidget: iconForSlot(AbilitySlot.mobility),
                  onHoldStart: onMobilityHoldStart,
                  onHoldEnd: onMobilityHoldEnd,
                  onAimDir: onAimDir,
                  onAimClear: onAimClear,
                  onCommit: onMobilityCommitted,
                  projectileAimPreview: meleeAimPreview,
                  tuning: directional,
                  cooldownRing: cooldownRing,
                  cancelHitboxRect: aimCancelHitboxRect,
                  affordable: mobilityAffordable,
                  cooldownTicksLeft: mobilityCooldownTicksLeft,
                  cooldownTicksTotal: mobilityCooldownTicksTotal,
                  size: sizeFor(
                    AbilitySlot.mobility,
                    familyOverride: AbilityRadialSlotFamily.directional,
                  ),
                  deadzoneRadius: layout.directionalDeadzoneRadius,
                  forceCancelSignal: forceAimCancelSignal,
                ),
        ),
        Positioned(
          right: anchorFor(AbilitySlot.jump).right,
          bottom: anchorFor(AbilitySlot.jump).bottom,
          child: ActionButton(
            label: labelFor(AbilitySlot.jump),
            icon: jumpSlot.icon,
            iconWidget: iconForSlot(AbilitySlot.jump),
            onPressed: onJumpPressed,
            tuning: action,
            cooldownRing: cooldownRing,
            affordable: jumpAffordable,
            size: sizeFor(AbilitySlot.jump),
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

ControlsTuning _resolveRunControlsTuning({
  required ControlsTuning base,
  required UiActionButtonTheme actionButtons,
}) {
  final baseStyle = base.style;
  return ControlsTuning(
    layout: base.layout,
    moveButtons: base.moveButtons,
    style: ControlsStyleTuning(
      actionButton: actionButtons.resolveAction(
        base: baseStyle.actionButton,
        surface: UiActionButtonSurface.run,
      ),
      directionalActionButton: actionButtons.resolveDirectional(
        base: baseStyle.directionalActionButton,
        surface: UiActionButtonSurface.run,
      ),
      cooldownRing: baseStyle.cooldownRing,
      chargeBar: baseStyle.chargeBar,
    ),
  );
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
