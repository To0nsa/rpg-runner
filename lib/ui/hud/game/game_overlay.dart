import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../game/game_controller.dart';
import '../../../game/spatial/offscreen_indicators.dart';
import '../../../game/input/aim_preview.dart';
import '../../../game/input/runner_gameplay_action.dart';
import '../../../game/input/runner_semantic_action_dispatcher.dart';
import '../../controls/runner_controls_overlay_radial.dart';
import '../../controls/movement_control_mode.dart';

import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';

import '../../controls/control_resource_usage.dart';

import '../../runner_game_ui_state.dart';
import '../../viewport/viewport_metrics.dart';
import 'offscreen_indicator_overlay.dart';
import 'pause_overlay.dart';
import 'terrain_loading_overlay.dart';
import 'ready_overlay.dart';
import 'boss_arena_hud.dart';
import 'survival_timer_overlay.dart';
import 'top_left_hud_overlay.dart';
import 'top_right_hud_overlay.dart';
import 'aim_cancel_button_overlay.dart';
import 'player_impact_border_overlay.dart';
import 'boss_entrance_border_overlay.dart';

class GameOverlay extends StatefulWidget {
  const GameOverlay({
    super.key,
    required this.controller,
    required this.input,
    required this.projectileAimPreview,
    required this.meleeAimPreview,
    required this.aimCancelHitboxRect,
    required this.forceAimCancelSignal,
    required this.playerImpactFeedbackSignal,
    required this.uiState,
    required this.onStart,
    required this.onTogglePause,
    required this.showExitButton,
    required this.onExit,
    required this.exitConfirmOpen,
    required this.onExitConfirmResume,
    required this.onExitConfirmExit,
    this.movementControlMode = MovementControlMode.arrows,
    this.movementInputEpoch = 0,
    this.indicatorFrames,
    this.viewportMetrics,
  });

  final GameController controller;
  final MovementControlMode movementControlMode;
  final int movementInputEpoch;
  final ValueListenable<OffscreenIndicatorFrame?>? indicatorFrames;
  final ViewportMetrics? viewportMetrics;
  final RunnerSemanticActionDispatcher input;
  final AimPreviewModel projectileAimPreview;
  final AimPreviewModel meleeAimPreview;
  final ValueNotifier<Rect?> aimCancelHitboxRect;
  final ValueListenable<int> forceAimCancelSignal;
  final ValueListenable<int> playerImpactFeedbackSignal;
  final RunnerGameUiState uiState;
  final VoidCallback onStart;
  final VoidCallback onTogglePause;
  final bool showExitButton;
  final VoidCallback? onExit;
  final bool exitConfirmOpen;
  final VoidCallback onExitConfirmResume;
  final VoidCallback onExitConfirmExit;

  @override
  State<GameOverlay> createState() => _GameOverlayState();

  Widget _buildOverlay(
    BuildContext context,
    ValueNotifier<ControlResourceUsage> warnings,
    GlobalKey hudRowKey,
    GlobalKey bossPanelKey,
  ) {
    final hud = controller.snapshot.hud;
    final projectileAffordable =
        hud.canAffordProjectile && hud.projectileSlotValid;
    final meleeAffordable = hud.canAffordMelee && hud.meleeSlotValid;
    final mobilityAffordable = hud.canAffordMobility && hud.mobilitySlotValid;
    final jumpAffordable = hud.canAffordJump && hud.jumpSlotValid;
    final secondaryAffordable =
        hud.canAffordSecondary && hud.secondarySlotValid;
    final spellAffordable = hud.canAffordSpell && hud.spellSlotValid;
    final hasSecondarySlot = hud.hasSecondarySlot;
    final hasProjectileSlot = hud.hasProjectileSlot;
    final chargeBarVisible = hud.chargeEnabled && hud.chargeActive;
    final chargeBarProgress01 = hud.chargeFullTicks > 0
        ? (hud.chargeTicks / hud.chargeFullTicks).clamp(0.0, 1.0)
        : 0.0;
    final equippedAbilityIdsBySlot = <AbilitySlot, AbilityKey>{
      AbilitySlot.primary: hud.abilityPrimaryId,
      AbilitySlot.secondary: hud.abilitySecondaryId,
      AbilitySlot.projectile: hud.abilityProjectileId,
      AbilitySlot.mobility: hud.abilityMobilityId,
      AbilitySlot.spell: hud.abilitySpellId,
      AbilitySlot.jump: hud.abilityJumpId,
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        if (uiState.isRunning &&
            indicatorFrames != null &&
            viewportMetrics != null)
          OffscreenIndicatorOverlay(
            frames: indicatorFrames!,
            metrics: viewportMetrics!,
            movementControlMode: movementControlMode,
            hudObstacles: [hudRowKey, bossPanelKey],
          ),
        IgnorePointer(
          ignoring:
              !uiState.isRunning ||
              controller.terrainReadiness == TerrainReadiness.failed,
          child: RunnerControlsOverlay(
            spellAbilityId: hud.abilitySpellId,
            movementInputEpoch: movementInputEpoch,
            movementControlMode: movementControlMode,
            movementEnabled:
                uiState.isRunning &&
                controller.terrainReadiness != TerrainReadiness.failed,
            onMoveAxis: input.setMoveAxis,
            onJumpPressed: () => input.triggerAction(RunnerGameplayAction.jump),
            onMobilityPressed: () =>
                input.triggerAction(RunnerGameplayAction.mobility),
            onMobilityCommitted: () =>
                input.commitAction(RunnerGameplayAction.mobility),
            onMobilityHoldStart: () =>
                input.beginAction(RunnerGameplayAction.mobility),
            onMobilityHoldEnd: () =>
                input.endAction(RunnerGameplayAction.mobility),
            onSecondaryPressed: () =>
                input.triggerAction(RunnerGameplayAction.secondary),
            onSecondaryCommitted: () =>
                input.commitAction(RunnerGameplayAction.secondary),
            onSecondaryHoldStart: () =>
                input.beginAction(RunnerGameplayAction.secondary),
            onSecondaryHoldEnd: () =>
                input.endAction(RunnerGameplayAction.secondary),
            onSpellPressed: () =>
                input.triggerAction(RunnerGameplayAction.spell),
            onProjectileCommitted: () =>
                input.commitAction(RunnerGameplayAction.projectile),
            onProjectilePressed: () =>
                input.triggerAction(RunnerGameplayAction.projectile),
            onProjectileHoldStart: () =>
                input.beginAction(RunnerGameplayAction.projectile),
            onProjectileHoldEnd: () =>
                input.endAction(RunnerGameplayAction.projectile),
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
            onMeleeCommitted: () =>
                input.commitAction(RunnerGameplayAction.primary),
            onMeleePressed: () =>
                input.triggerAction(RunnerGameplayAction.primary),
            onMeleeHoldStart: () =>
                input.beginAction(RunnerGameplayAction.primary),
            onMeleeHoldEnd: () => input.endAction(RunnerGameplayAction.primary),
            onMeleeChargeHoldStart: () =>
                input.beginAction(RunnerGameplayAction.primary),
            onMeleeChargeHoldEnd: () =>
                input.endAction(RunnerGameplayAction.primary),
            onResourceShortfall: (missing) =>
                warnings.value = ControlResourceUsage(
                  health: missing.health,
                  mana: missing.mana,
                  stamina: missing.stamina,
                ),
            missingResourcesBySlot: {
              for (final entry in equippedAbilityIdsBySlot.entries)
                if (switch (entry.key) {
                  AbilitySlot.primary =>
                    hud.meleeSlotValid && !hud.canAffordMelee,
                  AbilitySlot.secondary =>
                    hud.secondarySlotValid && !hud.canAffordSecondary,
                  AbilitySlot.projectile =>
                    hud.projectileSlotValid && !hud.canAffordProjectile,
                  AbilitySlot.mobility =>
                    hud.mobilitySlotValid && !hud.canAffordMobility,
                  AbilitySlot.spell =>
                    hud.spellSlotValid && !hud.canAffordSpell,
                  AbilitySlot.jump => hud.jumpSlotValid && !hud.canAffordJump,
                })
                  entry.key: ControlResourceUsage.shortfall(
                    cost: hud.abilityCostsBySlot[entry.key]!,
                    health: hud.hp,
                    mana: hud.mana,
                    stamina: hud.stamina,
                  ),
            },
            resourcesBySlot: {
              for (final entry in equippedAbilityIdsBySlot.entries)
                entry.key: ControlResourceUsage.fromAbility(
                  ability: AbilityCatalog.shared.resolve(entry.value),
                  cost: hud.abilityCostsBySlot[entry.key]!,
                ),
            },
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
            mobilityInputMode: hud.mobilityInputMode,
            jumpAffordable: jumpAffordable,
            mobilityAffordable: mobilityAffordable,
            mobilityCooldownTicksLeft:
                hud.cooldownTicksLeft[CooldownGroup.mobility],
            mobilityCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.mobility],
            secondaryAffordable: secondaryAffordable,
            secondaryCooldownTicksLeft:
                hud.cooldownTicksLeft[CooldownGroup.secondary],
            secondaryCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.secondary],
            spellAffordable: spellAffordable,
            spellCooldownTicksLeft: hud.cooldownTicksLeft[CooldownGroup.spell0],
            spellCooldownTicksTotal:
                hud.cooldownTicksTotal[CooldownGroup.spell0],
            forceAimCancelSignal: forceAimCancelSignal,
            hasSecondarySlot: hasSecondarySlot,
            hasProjectileSlot: hasProjectileSlot,
          ),
        ),
        PauseOverlay(
          visible: uiState.showPauseOverlay,
          exitConfirmOpen: exitConfirmOpen,
          onResume: onExitConfirmResume,
          onExit: onExitConfirmExit,
        ),
        ReadyOverlay(visible: uiState.showReadyOverlay, onTap: onStart),
        if (uiState.isRunning)
          TerrainLoadingOverlay(
            readiness: controller.terrainReadiness,
            onRetry: controller.retryTerrainPreparation,
            onExit: showExitButton ? onExit : null,
          ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                key: hudRowKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TopLeftHudOverlay(
                    controller: controller,
                    active: uiState.isRunning,
                    compact: constraints.maxWidth < 584,
                    warningSignal: warnings,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 1,
                      child: SurvivalTimerOverlay(controller: controller),
                    ),
                  ),
                  TopRightHudOverlay(
                    controller: controller,
                    uiState: uiState,
                    onStart: onStart,
                    onTogglePause: onTogglePause,
                    showExitButton: showExitButton,
                    onExit: onExit,
                  ),
                ],
              ),
            ),
          ),
        ),
        BossArenaHud(controller: controller, panelKey: bossPanelKey),
        AimCancelButtonOverlay(
          projectileAimPreview: projectileAimPreview,
          meleeAimPreview: meleeAimPreview,
          hitboxRect: aimCancelHitboxRect,
        ),
        Offstage(
          offstage: controller.snapshot.bossArena?.playerHeld ?? false,
          child: PlayerImpactBorderOverlay(
            triggerSignal: playerImpactFeedbackSignal,
          ),
        ),
        BossEntranceBorderOverlay(controller: controller),
      ],
    );
  }
}

class _GameOverlayState extends State<GameOverlay> {
  final _hudRowKey = GlobalKey();
  final _bossPanelKey = GlobalKey();
  final _warnings = ValueNotifier<ControlResourceUsage>(
    ControlResourceUsage.none,
  );

  @override
  void dispose() {
    _warnings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget._buildOverlay(context, _warnings, _hudRowKey, _bossPanelKey);
}
