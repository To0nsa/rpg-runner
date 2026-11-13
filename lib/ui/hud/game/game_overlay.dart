import '../../tutorial/campaign_tutorial_geometry.dart';
import '../../tutorial/campaign_tutorial_practice_hint.dart';
import '../../tutorial/campaign_tutorial_controller.dart';

import 'package:runner_content_pipeline/campaign_tutorial.dart';

import '../../tutorial/campaign_tutorial_overlay.dart';
import '../../campaign/campaign_hud.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../game/game_controller.dart';
import '../../../game/spatial/offscreen_indicators.dart';
import '../../../game/input/aim_preview.dart';
import '../../../game/input/runner_gameplay_action.dart';
import '../../../game/input/runner_semantic_action_dispatcher.dart';
import '../../controls/runner_controls_overlay_radial.dart';
import '../../controls/movement_control_mode.dart';
import '../../input/runner_control_scheme.dart';
import 'desktop_controls_overlay.dart';

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
    this.tutorial,
    this.onTutorialAction,
    this.controlScheme = RunnerControlScheme.touch,
    this.indicatorFrames,
    this.viewportMetrics,
    this.trainingField = false,
    this.resourcesTrailing,
    this.showLifecycleOverlays = true,
  });

  final GameController controller;

  /// Training shares the controls/resources but has no runner HUD or menus.
  final bool trainingField;
  final Widget? resourcesTrailing;

  /// Tooling hosts can retain their own ready/pause panels around the real HUD.
  final bool showLifecycleOverlays;
  final RunnerControlScheme controlScheme;
  final MovementControlMode movementControlMode;
  final int movementInputEpoch;
  final CampaignTutorialController? tutorial;
  final bool Function(RunnerGameplayAction action)? onTutorialAction;
  bool get tutorialActive =>
      tutorial?.showing == true &&
      uiState.runLoaded &&
      !uiState.gameOver &&
      !exitConfirmOpen;
  bool _shows(TutorialHudElement element) =>
      tutorial?.isVisible(element) ?? true;
  Set<AbilitySlot> get _visibleSlots => {
    if (_shows(TutorialHudElement.jump)) AbilitySlot.jump,
    if (_shows(TutorialHudElement.primary)) AbilitySlot.primary,
    if (_shows(TutorialHudElement.secondary)) AbilitySlot.secondary,
    if (_shows(TutorialHudElement.projectile)) AbilitySlot.projectile,
    if (_shows(TutorialHudElement.spell)) AbilitySlot.spell,
    if (_shows(TutorialHudElement.mobility)) AbilitySlot.mobility,
  };
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
    GlobalKey desktopBarKey,
    GlobalKey movementKey,
    GlobalKey statsKey,
    GlobalKey objectivesKey,
    GlobalKey jumpKey,
    GlobalKey mobilityKey,
    GlobalKey projectileKey,
    GlobalKey primaryKey,
    GlobalKey resourcesKey,
    GlobalKey blessingResourcesKey,
    GlobalKey surfaceKey,
  ) {
    final hud = controller.snapshot.hud;
    final desktop = controlScheme == RunnerControlScheme.desktop;
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
      key: surfaceKey,
      fit: StackFit.expand,
      children: [
        if (_shows(TutorialHudElement.objectives) &&
            uiState.isRunning &&
            indicatorFrames != null &&
            viewportMetrics != null)
          OffscreenIndicatorOverlay(
            frames: indicatorFrames!,
            metrics: viewportMetrics!,
            movementControlMode: movementControlMode,
            touchControlsVisible: !desktop,
            hudObstacles: [hudRowKey, bossPanelKey, if (desktop) desktopBarKey],
          ),
        if (desktop)
          MediaQuery.removePadding(
            context: context,
            removeLeft: trainingField,
            removeTop: trainingField,
            removeRight: trainingField,
            removeBottom: trainingField,
            child: DesktopControlsOverlay(
              controller: controller,
              panelKey: desktopBarKey,
              blockedSlots: {
                if (tutorial?.projectileLocked == true) AbilitySlot.projectile,
              },
              visibleSlots: _visibleSlots,
            ),
          )
        else
          IgnorePointer(
            ignoring:
                (!uiState.isRunning && !tutorialActive) ||
                controller.terrainReadiness == TerrainReadiness.failed,
            child: RunnerControlsOverlay(
              secondaryAbilityId: hud.abilitySecondaryId,
              spellAbilityId: hud.abilitySpellId,
              movementInputEpoch: movementInputEpoch,
              movementTargetKey: movementKey,
              actionsEnabled:
                  uiState.isRunning ||
                  (tutorialActive && tutorial!.expectsAction),
              jumpTargetKey: jumpKey,
              mobilityTargetKey: mobilityKey,
              attackTargetKeys: {
                AbilitySlot.projectile: projectileKey,
                AbilitySlot.primary: primaryKey,
              },
              blockedSlots: {
                if (tutorial?.projectileLocked == true) AbilitySlot.projectile,
              },
              visibleSlots: _visibleSlots,
              onMovementEngage: tutorialActive
                  ? () =>
                        onTutorialAction?.call(
                          RunnerGameplayAction.moveRight,
                        ) ??
                        false
                  : null,
              movementControlMode: movementControlMode,
              movementEnabled:
                  (uiState.isRunning || tutorialActive) &&
                  controller.terrainReadiness != TerrainReadiness.failed,
              onMoveAxis: input.setMoveAxis,
              onJumpPressed: () {
                if (tutorialActive &&
                    onTutorialAction?.call(RunnerGameplayAction.jump) != true) {
                  return;
                }
                input.triggerAction(RunnerGameplayAction.jump);
              },
              onMobilityPressed: () {
                if (tutorialActive &&
                    onTutorialAction?.call(RunnerGameplayAction.mobility) !=
                        true) {
                  return;
                }
                input.triggerAction(RunnerGameplayAction.mobility);
              },
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
              onProjectilePressed: () {
                if (tutorialActive &&
                    onTutorialAction?.call(RunnerGameplayAction.projectile) !=
                        true) {
                  return;
                }
                input.triggerAction(RunnerGameplayAction.projectile);
              },
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
              onMeleePressed: () {
                if (tutorialActive &&
                    onTutorialAction?.call(RunnerGameplayAction.primary) !=
                        true) {
                  return;
                }
                input.triggerAction(RunnerGameplayAction.primary);
              },
              onMeleeHoldStart: () =>
                  input.beginAction(RunnerGameplayAction.primary),
              onMeleeHoldEnd: () =>
                  input.endAction(RunnerGameplayAction.primary),
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
              mobilityRecastAvailable: hud.mobilityRecastTicksLeft > 0,
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
              spellCooldownTicksLeft:
                  hud.cooldownTicksLeft[CooldownGroup.spell0],
              spellCooldownTicksTotal:
                  hud.cooldownTicksTotal[CooldownGroup.spell0],
              forceAimCancelSignal: forceAimCancelSignal,
              hasSecondarySlot: hasSecondarySlot,
              hasProjectileSlot: hasProjectileSlot,
            ),
          ),
        if (!trainingField && showLifecycleOverlays)
          PauseOverlay(
            visible: uiState.showPauseOverlay && !tutorialActive,
            exitConfirmOpen: exitConfirmOpen,
            onResume: onExitConfirmResume,
            onExit: onExitConfirmExit,
          ),
        if (!trainingField && showLifecycleOverlays)
          ReadyOverlay(
            visible: uiState.showReadyOverlay && !tutorialActive,
            onTap: onStart,
            desktop: desktop,
          ),
        if (uiState.isRunning)
          TerrainLoadingOverlay(
            readiness: controller.terrainReadiness,
            onRetry: controller.retryTerrainPreparation,
            onExit: showExitButton ? onExit : null,
          ),
        Align(
          alignment: Alignment.topCenter,
          // Training draws beneath the app bar; only its resource row consumes
          // the safe area so controls and screen feedback keep full-page bounds.
          child: SafeArea(
            left: trainingField,
            top: trainingField,
            right: trainingField,
            bottom: trainingField,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  key: hudRowKey,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_shows(TutorialHudElement.resources))
                          TopLeftHudOverlay(
                            resourcesTargetKey: resourcesKey,
                            blessingResourcesTargetKey: blessingResourcesKey,
                            showBlessings: _shows(TutorialHudElement.blessings),
                            controller: controller,
                            active: uiState.isRunning,
                            compact: constraints.maxWidth < 584,
                            warningSignal: warnings,
                          ),
                        if (_shows(TutorialHudElement.resources))
                          ?resourcesTrailing,
                        if (!trainingField)
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: 1,
                              child:
                                  !_shows(TutorialHudElement.objectives) ||
                                      controller.snapshot.campaign != null
                                  ? const SizedBox.shrink()
                                  : SurvivalTimerOverlay(
                                      controller: controller,
                                    ),
                            ),
                          ),
                        if (!trainingField)
                          TopRightHudOverlay(
                            showStart: !tutorialActive,
                            showStats: _shows(TutorialHudElement.runStats),
                            statsTargetKey: statsKey,
                            tutorialPaused: tutorialActive,
                            controller: controller,
                            uiState: uiState,
                            onStart: tutorialActive ? () {} : onStart,
                            onTogglePause: onTogglePause,
                            showExitButton: showExitButton,
                            onExit: onExit,
                          ),
                      ],
                    ),
                    // Centre on the display, independently of either side's HUD.
                    if (!trainingField &&
                        _shows(TutorialHudElement.objectives) &&
                        controller.snapshot.campaign != null)
                      Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 1,
                        child: CampaignHud(
                          showBlessingObjective:
                              tutorial?.showBlessingObjective ?? true,
                          key: objectivesKey,
                          controller: controller,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!trainingField && _shows(TutorialHudElement.objectives))
          BossArenaHud(controller: controller, panelKey: bossPanelKey),
        if (!desktop && _visibleSlots.isNotEmpty)
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
        if (!trainingField && _shows(TutorialHudElement.objectives))
          BossEntranceBorderOverlay(controller: controller),
        if (uiState.isRunning)
          CampaignTutorialPracticeHint(text: tutorial?.combatPracticeHint),
        if (tutorialActive)
          CampaignTutorialOverlay(
            tutorial: tutorial!.active!,
            control: desktop
                ? TutorialMovementControl.keyboard
                : tutorialMovementControl(movementControlMode),
            step: tutorial!.step,
            onNext: tutorial!.hasNextStep ? tutorial!.nextStep : null,
            worldTarget:
                tutorial!.worldTargetBounds != null && viewportMetrics != null
                ? () {
                    final world = tutorial!.worldTargetBounds;
                    return world == null
                        ? null
                        : campaignTutorialWorldTarget(
                            world,
                            controller.snapshot.camera,
                            viewportMetrics!,
                          );
                  }
                : null,
            targetKey: switch (tutorial!.target!) {
              CampaignTutorialTarget.movement => movementKey,
              CampaignTutorialTarget.objectives => objectivesKey,
              CampaignTutorialTarget.runStats => statsKey,
              CampaignTutorialTarget.jump => desktop ? null : jumpKey,
              CampaignTutorialTarget.mobility => desktop ? null : mobilityKey,
              CampaignTutorialTarget.projectile =>
                desktop ? null : projectileKey,
              CampaignTutorialTarget.primary => desktop ? null : primaryKey,
              CampaignTutorialTarget.resources => resourcesKey,
              CampaignTutorialTarget.blessingResources => blessingResourcesKey,
              CampaignTutorialTarget.enemy ||
              CampaignTutorialTarget.shrine ||
              CampaignTutorialTarget.obstacle ||
              CampaignTutorialTarget.gap ||
              CampaignTutorialTarget.platform ||
              CampaignTutorialTarget.decoration ||
              CampaignTutorialTarget.water => null,
            },
            surfaceKey: surfaceKey,
          ),
      ],
    );
  }
}

class _GameOverlayState extends State<GameOverlay> {
  final _hudRowKey = GlobalKey();
  final _movementKey = GlobalKey();
  final _statsKey = GlobalKey();
  final _objectivesKey = GlobalKey();
  final _jumpKey = GlobalKey();
  final _mobilityKey = GlobalKey();
  final _projectileKey = GlobalKey();
  final _primaryKey = GlobalKey();
  final _resourcesKey = GlobalKey();
  final _blessingResourcesKey = GlobalKey();
  final _surfaceKey = GlobalKey();
  final _bossPanelKey = GlobalKey();
  final _desktopBarKey = GlobalKey();
  final _warnings = ValueNotifier<ControlResourceUsage>(
    ControlResourceUsage.none,
  );

  @override
  void dispose() {
    _warnings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget._buildOverlay(
    context,
    _warnings,
    _hudRowKey,
    _bossPanelKey,
    _desktopBarKey,
    _movementKey,
    _statsKey,
    _objectivesKey,
    _jumpKey,
    _mobilityKey,
    _projectileKey,
    _primaryKey,
    _resourcesKey,
    _blessingResourcesKey,
    _surfaceKey,
  );
}
