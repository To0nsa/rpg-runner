import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/campaign/campaign_registry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:runner_core/snapshots/player_hud_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/runner_gameplay_action.dart';
import 'package:rpg_runner/ui/tutorial/campaign_tutorial_controller.dart';

void main() {
  for (final block in [
    'before',
    'airborne',
    'water',
    'stamina',
    'cooldown',
    'invalid',
    'stun',
    'dashLock',
  ]) {
    test(
      'mobility waits for $block, then pauses once on a playable snapshot',
      () {
        final controller = _Controller();
        var cancelled = 0;
        final tutorial = CampaignTutorialController(
          controller: controller,
          mission: campaignMissions['reporting_for_duty']!,
          sequences: [
            CampaignMobilityTutorial.introduction(
              missionChunkId: 'mission_chunk_8',
            ),
          ],
          initialHud: {TutorialHudElement.movement},
          cancelInput: () => cancelled++,
        );
        addTearDown(tutorial.dispose);
        tutorial.startNormally();
        controller.snapshot.playerEntity = _actor(
          x: block == 'before' ? 4721 : 4722,
          grounded: block != 'airborne',
          swimming: block == 'water',
          lock: block == 'stun'
              ? EntityControlLockMask.stun
              : block == 'dashLock'
              ? EntityControlLockMask.dash
              : 0,
        );
        controller.snapshot.hud.canAffordMobility = block != 'stamina';
        controller.snapshot.hud.mobilitySlotValid = block != 'invalid';
        controller.snapshot.hud.cooldownTicksLeft[CooldownGroup.mobility] =
            block == 'cooldown' ? 1 : 0;
        controller.emitTick();
        expect(tutorial.showing, isFalse);
        expect(controller.paused, isFalse);
        expect(tutorial.isVisible(TutorialHudElement.mobility), isFalse);
        controller.snapshot.playerEntity = _actor();
        controller.snapshot.hud.canAffordMobility = true;
        controller.snapshot.hud.mobilitySlotValid = true;
        controller.snapshot.hud.cooldownTicksLeft[CooldownGroup.mobility] = 0;
        controller.emitTick();
        expect(tutorial.active, isA<CampaignMobilityTutorial>());
        expect(controller.paused, isTrue);
        expect(cancelled, 1);
        expect(tutorial.visibleHud, {
          TutorialHudElement.movement,
          TutorialHudElement.mobility,
        });
        expect(tutorial.acceptMovement(), isFalse);
        expect(tutorial.acceptAction(RunnerGameplayAction.jump), isFalse);
        tutorial.suspend();
        expect(tutorial.acceptAction(RunnerGameplayAction.mobility), isFalse);
        tutorial.resumeGuidance();
        expect(tutorial.acceptAction(RunnerGameplayAction.mobility), isTrue);
        expect(tutorial.allows(RunnerGameplayAction.mobility), isTrue);
        expect(tutorial.allows(RunnerGameplayAction.primary), isFalse);
        controller.emitTick();
        expect(tutorial.active, isNull);
        expect(cancelled, 1);
      },
    );
  }
  test(
    'another equipped mobility skill is revealed without a dash-only trap',
    () {
      final controller = _Controller();
      controller.snapshot.hud.abilityMobilityId = 'eloise.roll';
      final tutorial = CampaignTutorialController(
        controller: controller,
        mission: campaignMissions['reporting_for_duty']!,
        sequences: [
          CampaignMobilityTutorial.introduction(
            missionChunkId: 'mission_chunk_8',
          ),
        ],
        initialHud: {TutorialHudElement.movement},
        cancelInput: () {},
      );
      addTearDown(tutorial.dispose);
      tutorial.startNormally();
      controller.emitTick();
      expect(tutorial.showing, isFalse);
      expect(controller.paused, isFalse);
      expect(tutorial.allows(RunnerGameplayAction.mobility), isTrue);
      expect(controller.snapshot.hud.abilityMobilityId, 'eloise.roll');
    },
  );
}

EntityRenderSnapshot _actor({
  double x = 4722,
  bool grounded = true,
  bool swimming = false,
  int lock = 0,
}) => EntityRenderSnapshot(
  id: 1,
  kind: EntityKind.player,
  pos: Vec2(x, 162),
  facing: Facing.right,
  anim: AnimKey.idle,
  grounded: grounded,
  isSwimming: swimming,
  controlLockMask: lock,
);

// Snapshot policy fixtures only. Continuous route/input proof lives in the host test.
class _Controller extends Fake implements GameController {
  @override
  final _Snapshot snapshot = _Snapshot();
  final listeners = <VoidCallback>[];
  bool paused = false;
  @override
  int get tickHz => 60;
  @override
  void addCompletedTickListener(VoidCallback listener) =>
      listeners.add(listener);
  @override
  void removeCompletedTickListener(VoidCallback listener) =>
      listeners.remove(listener);
  @override
  void setPaused(bool value) => paused = value;
  void emitTick() {
    for (final listener in List.of(listeners)) {
      listener();
    }
  }
}

class _Snapshot extends Fake implements GameStateSnapshot {
  @override
  EntityRenderSnapshot playerEntity = _actor();
  @override
  final _Hud hud = _Hud();
  @override
  bool get gameOver => false;
}

class _Hud extends Fake implements PlayerHudSnapshot {
  @override
  String abilityMobilityId = 'eloise.dash';
  @override
  bool canAffordMobility = true;
  @override
  bool mobilitySlotValid = true;
  @override
  final cooldownTicksLeft = List.filled(8, 0);
}
