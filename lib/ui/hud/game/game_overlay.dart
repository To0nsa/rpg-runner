import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../game/game_controller.dart';
import '../../../game/input/aim_preview.dart';
import '../../../game/input/runner_input_router.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import '../../controls/runner_controls_overlay_radial.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import '../../runner_game_ui_state.dart';
import 'pause_overlay.dart';
import 'ready_overlay.dart';
import 'top_center_hud_overlay.dart';
import 'top_left_hud_overlay.dart';
import 'top_right_hud_overlay.dart';
import 'aim_cancel_button_overlay.dart';

class GameOverlay extends StatelessWidget {
  const GameOverlay({
    super.key,
    required this.controller,
    required this.input,
    required this.projectileAimPreview,
    required this.meleeAimPreview,
    required this.aimCancelHitboxRect,
    required this.forceAimCancelSignal,
    required this.uiState,
    required this.onStart,
    required this.onTogglePause,
    required this.showExitButton,
    required this.onExit,
    required this.exitConfirmOpen,
    required this.onExitConfirmResume,
    required this.onExitConfirmExit,
  });

  final GameController controller;
  final RunnerInputRouter input;
  final AimPreviewModel projectileAimPreview;
  final AimPreviewModel meleeAimPreview;
  final ValueNotifier<Rect?> aimCancelHitboxRect;
  final ValueListenable<int> forceAimCancelSignal;
  final RunnerGameUiState uiState;
  final VoidCallback onStart;
  final VoidCallback onTogglePause;
  final bool showExitButton;
  final VoidCallback? onExit;
  final bool exitConfirmOpen;
  final VoidCallback onExitConfirmResume;
  final VoidCallback onExitConfirmExit;

  @override
  Widget build(BuildContext context) {
    final hud = controller.snapshot.hud;
    final projectileAffordable =
        hud.canAffordProjectile && hud.projectileSlotValid;
    final meleeAffordable = hud.canAffordMelee && hud.meleeSlotValid;
    final dashAffordable = hud.canAffordDash && hud.mobilitySlotValid;
    final jumpAffordable = hud.canAffordJump && hud.jumpSlotValid;
    final secondaryAffordable =
        hud.canAffordSecondary && hud.secondarySlotValid;
    final bonusAffordable = hud.canAffordBonus && hud.bonusSlotValid;
    final chargeBarVisible = hud.chargeEnabled && hud.chargeActive;
    final chargeBarProgress01 = hud.chargeFullTicks > 0
        ? (hud.chargeTicks / hud.chargeFullTicks).clamp(0.0, 1.0)
        : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: !uiState.isRunning,
          child: RunnerControlsOverlay(
            onMoveAxis: input.setMoveAxis,
            onJumpPressed: input.pressJump,
            onDashPressed: input.pressDash,
            onSecondaryPressed: input.pressSecondary,
            onSecondaryCommitted: input.commitSecondaryStrike,
            onSecondaryHoldStart:
                hud.secondaryInputMode == AbilityInputMode.holdAimRelease
                ? () => input.startAbilitySlotHold(AbilitySlot.secondary)
                : input.startSecondaryHold,
            onSecondaryHoldEnd:
                hud.secondaryInputMode == AbilityInputMode.holdAimRelease
                ? () => input.endAbilitySlotHold(AbilitySlot.secondary)
                : input.endSecondaryHold,
            onBonusPressed: input.pressBonus,
            onProjectileCommitted: () =>
                input.commitProjectileWithAim(clearAim: true),
            onProjectilePressed: input.pressProjectile,
            onProjectileHoldStart: () =>
                input.startAbilitySlotHold(AbilitySlot.projectile),
            onProjectileHoldEnd: () =>
                input.endAbilitySlotHold(AbilitySlot.projectile),
            onAimDir: input.setAimDir,
            onAimClear: input.clearAimDir,
            projectileAimPreview: projectileAimPreview,
            chargeBarVisible: chargeBarVisible,
            chargeBarProgress01: chargeBarProgress01,
            chargeBarTier: hud.chargeTier,
            projectileAffordable: projectileAffordable,
            projectileCooldownTicksLeft:
                hud.cooldownTicksLeft[CooldownGroup.projectile],
            projectileCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.projectile],
            onMeleeCommitted: input.commitMeleeStrike,
            onMeleePressed: input.pressStrike,
            onMeleeHoldStart: input.startPrimaryHold,
            onMeleeHoldEnd: input.endPrimaryHold,
            onMeleeChargeHoldStart: () =>
                input.startAbilitySlotHold(AbilitySlot.primary),
            onMeleeChargeHoldEnd: () =>
                input.endAbilitySlotHold(AbilitySlot.primary),
            meleeAimPreview: meleeAimPreview,
            aimCancelHitboxRect: aimCancelHitboxRect,
            meleeAffordable: meleeAffordable,
            meleeCooldownTicksLeft:
                hud.cooldownTicksLeft[CooldownGroup.primary],
            meleeCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.primary],
            meleeInputMode: hud.meleeInputMode,
            secondaryInputMode: hud.secondaryInputMode,
            projectileInputMode: hud.projectileInputMode,
            jumpAffordable: jumpAffordable,
            dashAffordable: dashAffordable,
            dashCooldownTicksLeft:
                hud.cooldownTicksLeft[CooldownGroup.mobility],
            dashCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.mobility],
            secondaryAffordable: secondaryAffordable,
            secondaryCooldownTicksLeft:
                hud.cooldownTicksLeft[CooldownGroup.secondary],
            secondaryCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.secondary],
            bonusAffordable: bonusAffordable,
            bonusCooldownTicksLeft: hud.cooldownTicksLeft[CooldownGroup.bonus0],
            bonusCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.bonus0],
            forceAimCancelSignal: forceAimCancelSignal,
          ),
        ),
        PauseOverlay(
          visible: uiState.showPauseOverlay,
          exitConfirmOpen: exitConfirmOpen,
          onResume: onExitConfirmResume,
          onExit: onExitConfirmExit,
        ),
        ReadyOverlay(visible: uiState.showReadyOverlay, onTap: onStart),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TopLeftHudOverlay(controller: controller),
          ),
        ),
        TopCenterHudOverlay(
          controller: controller,
          uiState: uiState,
          onStart: onStart,
          onTogglePause: onTogglePause,
        ),
        AimCancelButtonOverlay(
          projectileAimPreview: projectileAimPreview,
          meleeAimPreview: meleeAimPreview,
          hitboxRect: aimCancelHitboxRect,
        ),
        TopRightHudOverlay(
          controller: controller,
          showExitButton: showExitButton,
          onExit: onExit,
        ),
      ],
    );
  }
}
