import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';

import '../tutorial/campaign_tutorial_controller.dart';

import 'package:flutter/widgets.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/enums.dart';

import '../../game/game_controller.dart';
import '../../game/input/aim_preview.dart';
import '../../game/input/runner_gameplay_action.dart';
import '../../game/input/runner_input_router.dart';
import '../../game/input/runner_semantic_action_dispatcher.dart';
import '../haptics/boss_entrance_haptics_binding.dart';
import '../haptics/haptics_cue.dart';
import '../haptics/haptics_service.dart';
import 'desktop/runner_desktop_input_adapter.dart';

/// One attempt's input/feedback wiring, shared by product, training and tooling.
///
/// Hosts retain start/focus/resume policy. [stop] cancels input and detaches
/// subscriptions before the controller stops; [dispose] releases UI notifiers
/// after the old view unmounts. Aim models and the controller are borrowed.
final class RunnerGameplayBindings extends ChangeNotifier {
  RunnerGameplayBindings({
    required this.controller,
    required RunnerInputRouter input,
    required this.projectilePreview,
    required this.meleePreview,
    this.haptics,
    CampaignMissionDefinition? campaignMission,
    List<CampaignTutorialSequence> tutorialSequences = const [],
    Set<TutorialHudElement> initialTutorialHud = allTutorialHud,
  }) {
    tutorial = CampaignTutorialController(
      controller: controller,
      mission: campaignMission,
      sequences: tutorialSequences,
      initialHud: initialTutorialHud,
      cancelInput: cancelAll,
    )..addListener(_onTutorialChanged);
    actions = RunnerSemanticActionDispatcher(
      input: input,
      resolveInputMode: _resolveInputMode,
      isActionAllowed: tutorial.allows,
    );
    _lastDamageTick = controller.snapshot.hud.lastDamageTick;
    _lastTerrainReadiness = controller.terrainReadiness;
    controller.addListener(_onTick);
    controller.addEventListener(_onEvent);
    if (haptics case final feedback?) {
      _bossHaptics = BossEntranceHapticsBinding(
        controller: controller,
        haptics: feedback,
      );
    }
  }

  final GameController controller;
  final AimPreviewModel projectilePreview;
  final AimPreviewModel meleePreview;
  final UiHaptics? haptics;
  late final RunnerSemanticActionDispatcher actions;
  late final CampaignTutorialController tutorial;
  void _onTutorialChanged() {
    if (!_stopped) notifyListeners();
  }

  final aimCancelHitboxRect = ValueNotifier<Rect?>(null);
  final forceAimCancelSignal = ValueNotifier(0);
  final impactSignal = ValueNotifier(0);
  RunnerDesktopInputController? _desktop;
  RunnerDesktopInputController? get desktop => _desktop;
  BossEntranceHapticsBinding? _bossHaptics;
  int _movementEpoch = 0;
  int get movementEpoch => _movementEpoch;
  late int _lastDamageTick;
  late TerrainReadiness _lastTerrainReadiness;
  int _lastChargeTier = 0;
  bool _stopped = false;
  bool _disposed = false;

  /// Installs one initially disabled desktop controller for this attempt.
  /// Enabling gameplay and requesting focus remain host decisions.
  void attachDesktop({
    required RunnerDesktopAimGeometryResolver resolveAimGeometry,
    required VoidCallback onFocusLost,
    bool Function(RunnerGameplayAction action)? onActionStart,
  }) {
    if (_stopped) throw StateError('Cannot bind input to a stopped attempt.');
    if (_desktop != null) throw StateError('Desktop input is already bound.');
    _desktop = RunnerDesktopInputController(
      dispatcher: actions,
      resolveAimGeometry: resolveAimGeometry,
      onFocusLost: onFocusLost,
      onActionStart: onActionStart,
      onCancelPresentation: _cancelAimPresentation,
      onCancelAllPresentation: _cancelMovementPresentation,
    )..setEnabled(false);
  }

  /// Removes physical input before a host changes its touch/desktop scheme.
  void detachDesktop() {
    _desktop?.dispose();
    _desktop = null;
  }

  AbilityInputMode _resolveInputMode(RunnerGameplayAction action) {
    final hud = controller.snapshot.hud;
    return switch (action) {
      RunnerGameplayAction.primary => hud.meleeInputMode,
      RunnerGameplayAction.secondary => hud.secondaryInputMode,
      RunnerGameplayAction.projectile => hud.projectileInputMode,
      RunnerGameplayAction.mobility => hud.mobilityInputMode,
      _ => AbilityInputMode.tap,
    };
  }

  /// Neutralizes queued/held input and invalidates touch movement and aim.
  void cancelAll() {
    if (_stopped) return;
    if (_desktop case final desktop?) {
      desktop.cancelAll();
    } else {
      actions.cancelAll();
      _cancelAimPresentation();
      _cancelMovementPresentation();
    }
  }

  void _cancelAimPresentation() {
    projectilePreview.end();
    meleePreview.end();
    forceAimCancelSignal.value++;
  }

  void _cancelMovementPresentation() {
    _movementEpoch++;
    notifyListeners();
  }

  /// Drops interrupted abilities without releasing unrelated movement sources.
  /// A late key/pointer release cannot commit a canceled charge.
  void cancelAbilities() {
    if (_stopped) return;
    _desktop?.cancelAbilityActions();
    for (final action in RunnerGameplayAction.values) {
      if (action != RunnerGameplayAction.moveLeft &&
          action != RunnerGameplayAction.moveRight) {
        actions.cancelAction(action);
      }
    }
    actions.clearAimDir();
    if (_desktop == null) _cancelAimPresentation();
    actions.pumpHeldInputs();
  }

  void _onTick() {
    if (_stopped) return;
    _desktop?.refreshPointerAim();
    final readiness = controller.terrainReadiness;
    if (readiness != _lastTerrainReadiness) {
      _lastTerrainReadiness = readiness;
      if (readiness == TerrainReadiness.failed) cancelAll();
    }
    final hud = controller.snapshot.hud;
    final active = hud.chargeEnabled && hud.chargeActive;
    final tier = active ? hud.chargeTier : 0;
    if (active && tier > _lastChargeTier) {
      if (_lastChargeTier < 1 && tier >= 1) {
        haptics?.trigger(UiHapticsCue.chargeHalfTierReached);
      }
      if (_lastChargeTier < 2 && tier >= 2) {
        haptics?.trigger(UiHapticsCue.chargeFullTierReached);
      }
    }
    _lastChargeTier = tier;
    if (hud.lastDamageTick > _lastDamageTick) {
      _lastDamageTick = hud.lastDamageTick;
      if (active) cancelAbilities();
    }
  }

  void _onEvent(GameEvent event) {
    if (_stopped) return;
    if (event is PlayerImpactFeedbackEvent) {
      impactSignal.value++;
      haptics?.trigger(UiHapticsCue.playerHit);
    } else if (event is PlayerLandedHitFeedbackEvent) {
      haptics?.trigger(UiHapticsCue.playerLandedHit);
    } else if (event is AbilityHoldEndedEvent) {
      haptics?.trigger(switch (event.reason) {
        AbilityHoldEndReason.timeout => UiHapticsCue.holdAbilityTimedOut,
        AbilityHoldEndReason.staminaDepleted =>
          UiHapticsCue.holdAbilityStaminaDepleted,
      });
    } else if (event is AbilityChargeEndedEvent) {
      haptics?.trigger(UiHapticsCue.holdAbilityTimedOut);
      cancelAbilities();
    }
  }

  void stop() {
    if (_stopped) return;
    cancelAll();
    detachDesktop();
    _stopped = true;
    tutorial.stop();
    tutorial.removeListener(_onTutorialChanged);
    controller.removeListener(_onTick);
    controller.removeEventListener(_onEvent);
    _bossHaptics?.dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    stop();
    _disposed = true;
    tutorial.dispose();
    aimCancelHitboxRect.dispose();
    forceAimCancelSignal.dispose();
    impactSignal.dispose();
    super.dispose();
  }
}
