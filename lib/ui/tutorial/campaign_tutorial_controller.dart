import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/tuning/score_tuning.dart';

import '../../game/game_controller.dart';
import '../../game/input/runner_gameplay_action.dart';
import 'campaign_combat_guidance.dart';

/// One attempt's guidance and cumulative HUD access, shared by product and Play.
/// Hosts retain readiness, foreground, calibration and user-pause authority.
final class CampaignTutorialController extends ChangeNotifier {
  CampaignTutorialController({
    required this.controller,
    this.mission,
    required List<CampaignTutorialSequence> sequences,
    required Set<TutorialHudElement> initialHud,
    required this.cancelInput,
  }) : _sequences = List.unmodifiable(sequences.where((s) => s.enabled)),
       _visible = {...initialHud},
       _lastPlayerX = controller.snapshot.playerEntity?.pos.x {
    if (sequences.any(
          (lesson) =>
              lesson.missionChunkId != null ||
              lesson is CampaignBlessingTutorial,
        ) &&
        mission == null) {
      throw ArgumentError('Chunk tutorials require the captured mission.');
    }
    if (mission != null) validateCampaignTutorialTargets(sequences, mission!);
    if (_sequences.firstOrNull?.trigger ==
        CampaignTutorialTrigger.missionStart) {
      _activate(_sequences.first);
    }
    controller.addCompletedTickListener(_onTick);
    if (_sequences.any((s) => s is CampaignCombatTutorial)) {
      controller.addEventListener(_onEvent);
    }
  }

  final GameController controller;
  final CampaignMissionDefinition? mission;
  int _step = 0;
  int get step => _step;
  CampaignTutorialTarget? get target => _active?.targetAt(_step);
  bool get expectsAction =>
      showing &&
      {
        CampaignTutorialContinuation.jump,
        CampaignTutorialContinuation.mobility,
        CampaignTutorialContinuation.projectile,
        CampaignTutorialContinuation.primary,
      }.contains(_active!.continuationAt(_step));
  bool get hasNextStep =>
      showing &&
      _active!.continuationAt(_step) == CampaignTutorialContinuation.next;

  /// World targets share camera/HUD projection; their sources stay chunk-local.
  Rect? get worldTargetBounds {
    final lesson = _active;
    if (lesson is CampaignCombatTutorial &&
        target == CampaignTutorialTarget.enemy) {
      return _combat?.targetBounds;
    }
    if (lesson is CampaignBlessingTutorial &&
        target == CampaignTutorialTarget.shrine) {
      final shrine = lesson.resolveShrine(mission!);
      final b = shrine.bounds;
      return Rect.fromLTWH(
        _chunkOrigin(shrine.missionChunkId) + b.x,
        b.y,
        b.width,
        b.height,
      );
    }
    if (lesson is CampaignPlatformTutorial) {
      final b = lesson.resolvePlatform(mission!).bounds;
      return Rect.fromLTWH(
        _chunkOrigin(lesson.missionChunkId) + b.x,
        b.y,
        b.width,
        b.height,
      );
    }
    if (lesson is CampaignGapTutorial) {
      final bounds = lesson.resolveGap(mission!).bounds;
      return Rect.fromLTWH(
        _chunkOrigin(lesson.missionChunkId) + bounds.x,
        bounds.y,
        bounds.width,
        bounds.height,
      );
    }
    if (lesson is CampaignDecorationTutorial) {
      final bounds = campaignTutorialSpriteBounds(
        lesson.resolveDecoration(mission!),
      );
      return Rect.fromLTWH(
        _chunkOrigin(lesson.missionChunkId) + bounds.x,
        bounds.y,
        bounds.width,
        bounds.height,
      );
    }
    if (lesson is CampaignWaterTutorial) {
      final water = lesson.resolveWater(mission!);
      return Rect.fromLTWH(
        _chunkOrigin(lesson.missionChunkId) + water.x,
        water.y.toDouble(),
        water.width.toDouble(),
        water.height.toDouble(),
      );
    }
    if (lesson is! CampaignJumpTutorial ||
        target != CampaignTutorialTarget.obstacle) {
      return null;
    }
    final bounds = lesson.obstacle;
    final x = _chunkOrigin(lesson.missionChunkId) + bounds.x;
    return Rect.fromLTWH(x, bounds.y, bounds.width, bounds.height);
  }

  double _chunkOrigin(String id) =>
      mission!.worldX(CampaignPoint(missionChunkId: id, x: 0, y: 0));

  void nextStep() {
    if (!hasNextStep) return;
    cancelInput();
    _step++;
    _visible.addAll(_active!.revealsAt(_step));
    notifyListeners();
  }

  final VoidCallback cancelInput;
  final List<CampaignTutorialSequence> _sequences;
  final Set<TutorialHudElement> _visible;
  // Let the player practise either direction before interrupting with objectives.
  static const objectivesWalkDistance = 3.0 * kWorldUnitsPerMeter;
  double? _lastPlayerX;
  double _walkedDistance = 0;
  CampaignTutorialSequence? _active;
  final _completed = <String>{};
  bool _started = false, _suspended = false, _stopped = false;
  CampaignCombatGuidance? _combat;

  /// Borrowed from the mounted gameplay surface; accounts for device cropping.
  Rect? Function()? resolveVisibleWorldBounds;
  bool _publishedProjectileLock = false;
  bool get projectileLocked => _combat?.projectileLocked ?? false;
  Map<String, String>? get combatPracticeHint =>
      projectileLocked && !_stopped && !controller.snapshot.gameOver && !showing
      ? _combat?.lesson.practiceHint
      : null;

  void _onEvent(GameEvent event) {
    if (!_stopped && event is PlayerAttackExecutedEvent) {
      _combat?.executed(event);
    }
  }

  bool _blessingIntroduced = false;
  bool _practisingBlessing = false;

  /// Objective visibility is guidance only; Core still requires the real landing.
  bool get showBlessingObjective =>
      _blessingIntroduced ||
      controller.snapshot.campaign?.blessingReceived == true ||
      !_sequences.any((s) => s is CampaignBlessingTutorial);

  CampaignTutorialSequence? get active => _active;
  bool get suspended => _suspended;
  bool get showing =>
      !_stopped &&
      _active != null &&
      !_suspended &&
      !controller.snapshot.gameOver;
  bool isVisible(TutorialHudElement element) => _visible.contains(element);
  Set<TutorialHudElement> get visibleHud => Set.unmodifiable(_visible);

  bool allows(RunnerGameplayAction action) =>
      !_stopped &&
      _active == null &&
      isVisible(hudForAction(action)) &&
      !(action == RunnerGameplayAction.projectile && projectileLocked);

  /// Called only after the host admits a fresh movement down event. Existing
  /// held inputs were cancelled at interruption, before this can accept again.
  bool acceptMovement() => acceptAction(RunnerGameplayAction.moveRight);

  /// The host must admit the fresh physical press before unpausing. This does
  /// not synthesize a command: the same press follows ordinary input routing.
  bool acceptAction(RunnerGameplayAction action) {
    if (_stopped || !showing) return false;
    final accepted = switch (_active!.continuationAt(_step)) {
      CampaignTutorialContinuation.movement =>
        action == RunnerGameplayAction.moveLeft ||
            action == RunnerGameplayAction.moveRight,
      CampaignTutorialContinuation.jump => action == RunnerGameplayAction.jump,
      CampaignTutorialContinuation.mobility =>
        action == RunnerGameplayAction.mobility,
      CampaignTutorialContinuation.projectile =>
        action == RunnerGameplayAction.projectile,
      CampaignTutorialContinuation.primary =>
        action == RunnerGameplayAction.primary,
      CampaignTutorialContinuation.next => false,
    };
    if (!accepted) return false;
    if (_active is CampaignCombatTutorial) {
      _combat!.accept(
        action == RunnerGameplayAction.projectile
            ? AbilitySlot.projectile
            : AbilitySlot.primary,
      );
    } else if (_active is CampaignBlessingTutorial && _step == 0) {
      _practisingBlessing = true;
    } else {
      _completed.add(_active!.id);
      if (_active is CampaignBlessingTutorial) _practisingBlessing = false;
    }
    _active = null;
    _started = true;
    notifyListeners();
    return true;
  }

  bool startNormally() {
    if (_stopped || _active != null) return false;
    _started = true;
    return true;
  }

  void suspend() {
    if (_stopped || _active == null || _suspended) return;
    _suspended = true;
    notifyListeners();
  }

  /// Resumes guidance only; an active lesson continues to hold simulation pause.
  void resumeGuidance() {
    if (_stopped || !_suspended) return;
    _suspended = false;
    notifyListeners();
  }

  void _activate(CampaignTutorialSequence lesson) {
    _active = lesson;
    _step = 0;
    if (lesson is CampaignBlessingTutorial) {
      _blessingIntroduced = true;
      // A successful early landing goes straight to the reward explanation.
      if (controller.snapshot.campaign?.blessingReceived == true) _step = 1;
      _visible.addAll(lesson.revealsAt(0));
    }
    _visible.addAll(lesson.revealsAt(_step));
  }

  void _onTick() {
    if (_stopped ||
        !_started ||
        _active != null ||
        _completed.length >= _sequences.length ||
        controller.snapshot.gameOver) {
      return;
    }
    final player = controller.snapshot.playerEntity;
    final x = player?.pos.x;
    if (x != null && _lastPlayerX != null) {
      // Render anchors also shift when turning or settling. Limit observed
      // motion to horizontal travel possible at this tick's velocity.
      _walkedDistance += math.min(
        (x - _lastPlayerX!).abs(),
        (player?.vel?.x ?? 0).abs() / controller.tickHz,
      );
    }
    _lastPlayerX = x;
    final pending = _sequences.where(
      (lesson) => !_completed.contains(lesson.id),
    );
    final required = pending.where((lesson) => !lesson.optional).firstOrNull;
    if (required is CampaignCombatTutorial) {
      _combat ??= CampaignCombatGuidance(required);
      final page = _combat!.observe(
        controller,
        visibleWorldBounds: resolveVisibleWorldBounds?.call(),
      );
      if (_combat!.phase == CombatGuidancePhase.complete) {
        _completed.add(required.id);
        for (var i = 0; i < required.stepCount; i++) {
          _visible.addAll(required.revealsAt(i));
        }
        notifyListeners();
        return;
      }
      if (page != null) {
        _activate(required);
        _step = page;
        _visible.addAll(required.revealsAt(page));
        cancelInput();
        controller.setPaused(true);
      }
      // Publish execution feedback once, without rebuilding on every approach tick.
      final changed = _publishedProjectileLock != projectileLocked;
      _publishedProjectileLock = projectileLocked;
      if (page != null || changed) notifyListeners();
      return;
    }
    // Replays may equip another mobility skill. Keep that build and reveal its
    // control here without demanding a Dash gesture or teaching the wrong skill.
    if (required is CampaignMobilityTutorial &&
        _mobilityPositionReached(required, player) &&
        !_hasDash) {
      _completed.add(required.id);
      _visible.addAll(required.reveals);
      notifyListeners();
      return;
    }
    // An early jump can bypass the grounded approach window. Once safely across,
    // retire that explanation rather than interrupting late or blocking the queue.
    final approach = _groundedApproach(required);
    if (approach != null && player?.grounded == true && x! >= approach.right) {
      _completed.add(required!.id);
      final visibleCount = _visible.length;
      _visible.addAll(required.reveals);
      if (_visible.length != visibleCount) notifyListeners();
      return;
    }
    // Route lessons retain authored order. Optional hints can interrupt while
    // waiting for a later route trigger, and never become a queue barrier.
    final next = required != null && _triggered(required, player)
        ? required
        : pending
              .where((lesson) => lesson.optional && _triggered(lesson, player))
              .firstOrNull;
    if (next == null) return;
    _activate(next);
    // Set the lesson before cancellation/pause can notify other listeners.
    // No later tick in this frame may consume buffered movement or abilities.
    cancelInput();
    controller.setPaused(true);
    notifyListeners();
  }

  bool _triggered(CampaignTutorialSequence next, EntityRenderSnapshot? player) {
    final x = player?.pos.x;
    return switch (next.trigger) {
      CampaignTutorialTrigger.enemyApproached => false,
      CampaignTutorialTrigger.missionStart => false,
      CampaignTutorialTrigger.movementStarted =>
        _walkedDistance >= objectivesWalkDistance,
      CampaignTutorialTrigger.firstCoinCollected =>
        controller.snapshot.hud.collectibles > 0,
      CampaignTutorialTrigger.chunkEntered =>
        next is CampaignJumpTutorial &&
            x != null &&
            x >= _chunkOrigin(next.missionChunkId),
      CampaignTutorialTrigger.waterApproached =>
        next is CampaignWaterTutorial &&
            x != null &&
            x >=
                _chunkOrigin(next.missionChunkId) +
                    next.resolveWater(mission!).x -
                    next.approachDistance,
      CampaignTutorialTrigger.waterCleared =>
        next is CampaignDecorationTutorial &&
            player != null &&
            player.grounded &&
            !player.isSwimming &&
            x! >=
                _chunkOrigin(next.missionChunkId) +
                    next.resolveWater(mission!).x +
                    next.resolveWater(mission!).width,
      CampaignTutorialTrigger.gapApproached ||
      CampaignTutorialTrigger.platformApproached => _groundedApproachTriggered(
        next,
        player,
      ),
      CampaignTutorialTrigger.blessingApproached =>
        next is CampaignBlessingTutorial &&
            (controller.snapshot.campaign?.blessingReceived == true ||
                (!_practisingBlessing &&
                    player?.grounded == true &&
                    !player!.isSwimming &&
                    x! >=
                        _chunkOrigin(
                              next.resolveShrine(mission!).missionChunkId,
                            ) +
                            next.resolveShrine(mission!).left -
                            next.approachDistance)),
      CampaignTutorialTrigger.mobilityReached =>
        next is CampaignMobilityTutorial &&
            _mobilityPositionReached(next, player) &&
            _hasDash &&
            controller.snapshot.hud.mobilitySlotValid &&
            controller.snapshot.hud.canAffordMobility &&
            controller.snapshot.hud.cooldownTicksLeft[CooldownGroup.mobility] ==
                0 &&
            (player!.controlLockMask &
                    (EntityControlLockMask.dash |
                        EntityControlLockMask.stun)) ==
                0,
      // Do not freeze an unaffordable or locked stroke: paused resource/cooldown
      // clocks could never make the requested action available. Keep it eligible.
      CampaignTutorialTrigger.firstSwimming =>
        player?.isSwimming == true &&
            controller.snapshot.hud.jumpSlotValid &&
            controller.snapshot.hud.canAffordJump &&
            (player!.controlLockMask &
                    (EntityControlLockMask.jump |
                        EntityControlLockMask.stun)) ==
                0,
    };
  }

  bool get _hasDash => const {
    'eloise.dash',
    'eloise.double_dash',
    'bounty_hunter.dash',
  }.contains(controller.snapshot.hud.abilityMobilityId);

  bool _mobilityPositionReached(
    CampaignMobilityTutorial lesson,
    EntityRenderSnapshot? player,
  ) =>
      player != null &&
      player.grounded &&
      !player.isSwimming &&
      player.pos.x >= _chunkOrigin(lesson.missionChunkId) + lesson.triggerX;

  ({double left, double right, double distance})? _groundedApproach(
    CampaignTutorialSequence? lesson,
  ) {
    if (lesson is CampaignGapTutorial) {
      final gap = lesson.resolveGap(mission!);
      final left = _chunkOrigin(lesson.missionChunkId) + gap.x;
      return (
        left: left,
        right: left + gap.width,
        distance: lesson.approachDistance,
      );
    }
    if (lesson is CampaignPlatformTutorial) {
      final platform = lesson.resolvePlatform(mission!);
      final origin = _chunkOrigin(lesson.missionChunkId);
      return (
        left: origin + platform.left,
        right: origin + platform.right,
        distance: lesson.approachDistance,
      );
    }
    return null;
  }

  bool _groundedApproachTriggered(
    CampaignTutorialSequence lesson,
    EntityRenderSnapshot? player,
  ) {
    if (player == null || !player.grounded || player.isSwimming) return false;
    final approach = _groundedApproach(lesson)!;
    return player.pos.x >= approach.left - approach.distance &&
        player.pos.x < approach.left;
  }

  void stop() {
    if (_stopped) return;
    _stopped = true;
    controller.removeCompletedTickListener(_onTick);
    if (_sequences.any((s) => s is CampaignCombatTutorial)) {
      controller.removeEventListener(_onEvent);
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

TutorialHudElement hudForAction(RunnerGameplayAction action) =>
    switch (action) {
      RunnerGameplayAction.moveLeft ||
      RunnerGameplayAction.moveRight => TutorialHudElement.movement,
      RunnerGameplayAction.jump => TutorialHudElement.jump,
      RunnerGameplayAction.primary => TutorialHudElement.primary,
      RunnerGameplayAction.secondary => TutorialHudElement.secondary,
      RunnerGameplayAction.projectile => TutorialHudElement.projectile,
      RunnerGameplayAction.spell => TutorialHudElement.spell,
      RunnerGameplayAction.mobility => TutorialHudElement.mobility,
    };
