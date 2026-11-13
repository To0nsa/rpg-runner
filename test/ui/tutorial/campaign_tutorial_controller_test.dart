import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/campaign/campaign_registry.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/game/input/runner_gameplay_action.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/ui/campaign/campaign_catalog.dart';
import 'package:rpg_runner/ui/input/runner_gameplay_bindings.dart';
import 'package:rpg_runner/ui/tutorial/campaign_tutorial_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('an unmet swimming hint cannot block a later route lesson', () async {
    final mission = campaignMissions['reporting_for_duty']!;
    final core = GameCore.campaignPlaytest(
      mission: mission,
      playerCharacter: PlayerCharacterRegistry.eloise,
      seed: 42,
    );
    await core.prepareNextTick();
    final controller = GameController(core: core)..setPaused(true);
    final input = RunnerInputRouter(controller: controller);
    final projectile = AimPreviewModel(), melee = AimPreviewModel();
    final bindings = RunnerGameplayBindings(
      controller: controller,
      input: input,
      projectilePreview: projectile,
      meleePreview: melee,
      campaignMission: mission,
      tutorialSequences: [
        CampaignSwimmingTutorial.introduction(),
        CampaignJumpTutorial.introduction(missionChunkId: 'mission_chunk_2'),
      ],
    );
    addTearDown(() {
      bindings.dispose();
      controller.dispose();
      projectile.dispose();
      melee.dispose();
    });
    expect(bindings.tutorial.startNormally(), isTrue);
    controller.setPaused(false);
    bindings.actions.setMoveAxis(1);
    for (
      var frame = 0;
      frame < 400 && bindings.tutorial.active == null;
      frame++
    ) {
      await core.prepareNextTick();
      bindings.actions.pumpHeldInputs();
      controller.advanceFrame(1 / 60);
    }
    expect(controller.snapshot.playerEntity!.isSwimming, isFalse);
    expect(bindings.tutorial.active, isA<CampaignJumpTutorial>());
    expect(controller.snapshot.playerEntity!.pos.x, inInclusiveRange(600, 605));
  });
  for (final (returnToPool, jumpGap) in [
    (false, true),
    (true, true),
    (false, false),
  ]) {
    test(
      'continuous tutorials through blessing, return to pool: $returnToPool, jump gap: $jumpGap',
      () async {
        final mission = campaignMissions['reporting_for_duty']!;
        final metadata = CampaignCatalog.mission(mission.id)!;
        final core = GameCore.campaignPlaytest(
          mission: mission,
          playerCharacter: PlayerCharacterRegistry.eloise,
          seed: 42,
        );
        await core.prepareNextTick();
        final controller = GameController(core: core)..setPaused(true);
        final router = RunnerInputRouter(controller: controller);
        final projectile = AimPreviewModel(), melee = AimPreviewModel();
        final bindings = RunnerGameplayBindings(
          controller: controller,
          input: router,
          projectilePreview: projectile,
          meleePreview: melee,
          campaignMission: mission,
          tutorialSequences: [
            for (final lesson in metadata.tutorialSequences)
              if (returnToPool && lesson is CampaignPlatformTutorial)
                CampaignPlatformTutorial.decode(
                  lesson.toJson()..['approachDistance'] = 20,
                )
              else if (returnToPool && lesson is CampaignGapTutorial)
                CampaignGapTutorial.decode(
                  lesson.toJson()..['approachDistance'] = 20,
                )
              else
                lesson,
          ],
          initialTutorialHud: metadata.initialTutorialHud,
        );
        addTearDown(() {
          bindings.dispose();
          controller.dispose();
          projectile.dispose();
          melee.dispose();
        });
        final tutorial = bindings.tutorial;
        final frames = <ReplayCommandFrameV1>[];
        controller.addAppliedCommandFrameListener(frames.add);
        expect(tutorial.visibleHud, {TutorialHudElement.movement});
        expect(tutorial.startNormally(), isFalse);
        expect(tutorial.acceptMovement(), isTrue);
        controller.setPaused(false);
        // Unpause discards its first frame delta. Commit idle ticks as well,
        // including initial terrain settling, before measuring actual walking.
        for (var frame = 0; frame < 15; frame++) {
          controller.advanceFrame(1 / 60);
        }
        expect(controller.tick, greaterThanOrEqualTo(12));
        expect(
          tutorial.active,
          isNull,
          reason: 'Neutral input must not introduce objectives.',
        );
        final startX = controller.snapshot.playerEntity!.pos.x;
        var acceptedTravel = 0.0;
        void recordTravel() {
          acceptedTravel +=
              core.buildTerrainPlayerDebugSnapshot()!.resolvedXTicks.abs() /
              1024;
        }

        controller.addCompletedTickListener(recordTravel);
        bindings.actions.setMoveAxis(-1);
        bindings.actions.pumpHeldInputs();
        controller.advanceFrame(.1);
        expect(tutorial.active, isNull, reason: 'Allow a real practice walk.');
        expect(controller.snapshot.paused, isFalse);
        expect(controller.snapshot.playerEntity!.pos.x, lessThan(startX));
        for (var tick = 0; tick < 120 && tutorial.active == null; tick++) {
          await core.prepareNextTick();
          bindings.actions.pumpHeldInputs();
          controller.advanceFrame(1 / 60);
        }
        // The authored obstacle behind spawn stops this walk before three metres.
        // Holding into it must not advance practice. Reverse and finish walking.
        expect(tutorial.active, isNull);
        expect(controller.snapshot.paused, isFalse);
        expect(
          acceptedTravel,
          lessThan(CampaignTutorialController.objectivesWalkDistance),
        );
        bindings.actions.setMoveAxis(1);
        for (var tick = 0; tick < 120 && tutorial.active == null; tick++) {
          await core.prepareNextTick();
          bindings.actions.pumpHeldInputs();
          controller.advanceFrame(1 / 60);
        }
        controller.removeCompletedTickListener(recordTravel);
        expect(
          acceptedTravel,
          greaterThanOrEqualTo(
            CampaignTutorialController.objectivesWalkDistance,
          ),
        );
        expect(tutorial.active, isA<CampaignObjectivesTutorial>());
        expect(controller.snapshot.paused, isTrue);
        expect(controller.snapshot.hud.collectibles, 0);
        expect(controller.snapshot.campaign!.required, 2);
        expect(tutorial.visibleHud, {
          TutorialHudElement.movement,
          TutorialHudElement.objectives,
        });
        final objectiveTick = controller.tick;
        controller.advanceFrame(.1);
        expect(controller.tick, objectiveTick);
        expect(tutorial.acceptMovement(), isTrue);
        controller.setPaused(false);
        bindings.actions.setMoveAxis(1);
        // Real authored mission, seed 42, catalog Éloïse; a finite 300 additional tick horizon
        // from the authored spawn to the first coin. No jump, teleport or terrain edits.
        var firstCoinTick = -1;
        controller.addCompletedTickListener(() {
          if (controller.snapshot.hud.collectibles > 0 && firstCoinTick < 0) {
            firstCoinTick = controller.tick;
          }
        });
        for (var frame = 0; frame < 50 && firstCoinTick < 0; frame++) {
          for (final action in RunnerGameplayAction.values.skip(2)) {
            bindings.actions.beginAction(action);
            bindings.actions.triggerAction(action);
            bindings.actions.commitAction(action);
            bindings.actions.releaseAction(action);
          }
          bindings.actions.setAimDir(1, 0);
          bindings.actions.pumpHeldInputs();
          controller.advanceFrame(.1);
          await core.prepareNextTick();
        }
        expect(firstCoinTick, greaterThan(0));
        expect(controller.tick, firstCoinTick);
        expect(controller.snapshot.hud.collectibles, 1);
        expect(controller.snapshot.campaign!.firstCoinCollected, isTrue);
        expect(controller.snapshot.campaign!.completed, 1);
        expect(controller.snapshot.paused, isTrue);
        expect(tutorial.active, isA<CampaignCoinTutorial>());
        expect(tutorial.visibleHud, {
          TutorialHudElement.movement,
          TutorialHudElement.objectives,
          TutorialHudElement.runStats,
        });
        expect(
          frames.every(
            (f) =>
                f.pressedMask == 0 &&
                f.abilitySlotHeldValueMask == 0 &&
                f.aimDirX == null,
          ),
          isTrue,
        );
        final frameCount = frames.length;
        bindings.actions.setMoveAxis(1);
        bindings.actions.pumpHeldInputs();
        controller.advanceFrame(.1);
        expect(frames.length, frameCount);
        tutorial.suspend();
        expect(tutorial.acceptMovement(), isFalse);
        tutorial.resumeGuidance();
        expect(controller.snapshot.paused, isTrue);
        expect(tutorial.acceptMovement(), isTrue);
        controller.setPaused(false);
        bindings.actions.setMoveAxis(-1);
        bindings.actions.pumpHeldInputs();
        controller.advanceFrame(1 / 60);
        expect(frames.last.moveAxis, -1);
        expect(tutorial.showing, isFalse);
        expect(tutorial.isVisible(TutorialHudElement.runStats), isTrue);
        // Continue from the same actor to the actual boundary of chunk two.
        bindings.actions.setMoveAxis(1);
        for (var frame = 0; frame < 240 && tutorial.active == null; frame++) {
          await core.prepareNextTick();
          bindings.actions.pumpHeldInputs();
          controller.advanceFrame(1 / 60);
        }
        expect(tutorial.active, isA<CampaignJumpTutorial>());
        expect(
          controller.snapshot.playerEntity!.pos.x,
          inInclusiveRange(600, 605),
        );
        expect(tutorial.step, 0);
        expect(tutorial.worldTargetBounds!.left, 615);
        final obstacleTick = controller.tick;
        final stamina = controller.snapshot.hud.stamina;
        expect(tutorial.acceptMovement(), isFalse);
        expect(tutorial.acceptAction(RunnerGameplayAction.jump), isFalse);
        expect(tutorial.isVisible(TutorialHudElement.jump), isFalse);
        tutorial.nextStep();
        expect(tutorial.step, 1);
        expect(tutorial.isVisible(TutorialHudElement.jump), isTrue);
        expect(tutorial.isVisible(TutorialHudElement.resources), isFalse);
        tutorial.suspend();
        tutorial.nextStep();
        expect(tutorial.step, 1);
        expect(tutorial.acceptAction(RunnerGameplayAction.jump), isFalse);
        tutorial.resumeGuidance();
        tutorial.nextStep();
        expect(tutorial.step, 2);
        expect(tutorial.isVisible(TutorialHudElement.resources), isTrue);
        expect(tutorial.acceptMovement(), isFalse);
        bindings.actions.triggerAction(RunnerGameplayAction.jump);
        controller.advanceFrame(.1);
        expect(controller.tick, obstacleTick);
        expect(controller.snapshot.hud.stamina, stamina);
        expect(tutorial.acceptAction(RunnerGameplayAction.jump), isTrue);
        controller.setPaused(false);
        bindings.actions.triggerAction(RunnerGameplayAction.jump);
        for (var frame = 0; frame < 4; frame++) {
          await core.prepareNextTick();
          controller.advanceFrame(1 / 60);
        }
        expect(controller.snapshot.hud.stamina, lessThan(stamina));
        expect(controller.snapshot.playerEntity!.vel!.y, lessThan(0));
        expect(tutorial.showing, isFalse);
        // Cross the authored rock with ordinary movement/jumps and continuous state.
        bindings.actions.setMoveAxis(1);
        for (var frame = 0; frame < 500 && tutorial.active == null; frame++) {
          await core.prepareNextTick();
          final actor = controller.snapshot.playerEntity!;
          if (actor.grounded &&
              (!returnToPool || actor.pos.x < 700 || actor.pos.x >= 815)) {
            bindings.actions.triggerAction(RunnerGameplayAction.jump);
          }
          bindings.actions.pumpHeldInputs();
          controller.advanceFrame(1 / 60);
        }
        expect(
          controller.snapshot.playerEntity!.pos.x,
          inInclusiveRange(868, 875),
        );
        expect(tutorial.active, isA<CampaignWaterTutorial>());
        expect(tutorial.worldTargetBounds!.left, 888);
        expect(tutorial.worldTargetBounds!.width, 96);
        expect(
          controller.snapshot.playerEntity!.grounded,
          isFalse,
          reason:
              'Approach guidance must also catch an airborne rock crossing.',
        );
        final waterTick = controller.tick;
        expect(tutorial.acceptAction(RunnerGameplayAction.jump), isFalse);
        controller.advanceFrame(.1);
        expect(controller.tick, waterTick);
        tutorial.suspend();
        expect(tutorial.acceptMovement(), isFalse);
        tutorial.resumeGuidance();
        expect(tutorial.acceptMovement(), isTrue);
        controller.setPaused(false);
        bindings.actions.setMoveAxis(1);
        void acceptDecoration() {
          expect(tutorial.active, isA<CampaignDecorationTutorial>());
          expect(controller.snapshot.playerEntity!.grounded, isTrue);
          expect(controller.snapshot.playerEntity!.isSwimming, isFalse);
          expect(
            controller.snapshot.playerEntity!.pos.x,
            greaterThanOrEqualTo(984),
          );
          expect(tutorial.worldTargetBounds!.left, 972);
          expect(tutorial.worldTargetBounds!.top, 82);
          expect(tutorial.worldTargetBounds!.width, 224);
          final visible = tutorial.visibleHud;
          expect(visible, {
            TutorialHudElement.movement,
            TutorialHudElement.objectives,
            TutorialHudElement.runStats,
            TutorialHudElement.jump,
            TutorialHudElement.resources,
          });
          final tick = controller.tick;
          controller.advanceFrame(.1);
          expect(controller.tick, tick);
          expect(tutorial.acceptAction(RunnerGameplayAction.jump), isFalse);
          tutorial.suspend();
          expect(tutorial.acceptMovement(), isFalse);
          tutorial.resumeGuidance();
          expect(tutorial.acceptMovement(), isTrue);
          expect(tutorial.visibleHud, visible);
          controller.setPaused(false);
          bindings.actions.setMoveAxis(1);
        }

        if (returnToPool) {
          // Jump from the far side of the rock and continue across the water.
          for (var frame = 0; frame < 240 && tutorial.active == null; frame++) {
            await core.prepareNextTick();
            bindings.actions.pumpHeldInputs();
            controller.advanceFrame(1 / 60);
            expect(controller.snapshot.playerEntity!.isSwimming, isFalse);
            if (!controller.snapshot.playerEntity!.grounded) {
              expect(
                tutorial.active,
                isNull,
                reason: 'Do not interrupt the airborne crossing.',
              );
            }
          }
          acceptDecoration();
          for (
            var frame = 0;
            frame < 120 && controller.snapshot.playerEntity!.pos.x < 1150;
            frame++
          ) {
            await core.prepareNextTick();
            bindings.actions.pumpHeldInputs();
            controller.advanceFrame(1 / 60);
            expect(tutorial.active, isNull);
          }
          expect(
            controller.snapshot.playerEntity!.pos.x,
            greaterThanOrEqualTo(1150),
          );
          bindings.actions.setMoveAxis(-1);
        }
        var firstSwimmingTick = -1;
        controller.addCompletedTickListener(() {
          if (controller.snapshot.playerEntity!.isSwimming &&
              firstSwimmingTick < 0) {
            firstSwimmingTick = controller.tick;
          }
        });
        // Let the same actor descend into the pool; no teleport or geometry edits.
        for (var frame = 0; frame < 300 && tutorial.active == null; frame++) {
          await core.prepareNextTick();
          if (returnToPool
              ? controller.snapshot.playerEntity!.pos.x <= 940
              : controller.snapshot.playerEntity!.pos.x >= 930) {
            bindings.actions.setMoveAxis(0);
          }
          bindings.actions.pumpHeldInputs();
          controller.advanceFrame(1 / 60);
        }
        expect(tutorial.active, isA<CampaignSwimmingTutorial>());
        expect(controller.snapshot.playerEntity!.isSwimming, isTrue);
        expect(controller.tick, firstSwimmingTick);
        expect(tutorial.expectsAction, isTrue);
        expect(tutorial.acceptMovement(), isFalse);
        final swimStamina = controller.snapshot.hud.stamina;
        controller.advanceFrame(.1);
        expect(controller.tick, firstSwimmingTick);
        tutorial.suspend();
        expect(tutorial.acceptAction(RunnerGameplayAction.jump), isFalse);
        tutorial.resumeGuidance();
        expect(tutorial.acceptAction(RunnerGameplayAction.jump), isTrue);
        controller.setPaused(false);
        bindings.actions.triggerAction(RunnerGameplayAction.jump);
        for (var frame = 0; frame < 3; frame++) {
          await core.prepareNextTick();
          controller.advanceFrame(1 / 60);
        }
        expect(controller.snapshot.playerEntity!.vel!.y, lessThan(0));
        expect(controller.snapshot.hud.stamina, lessThan(swimStamina));
        expect(tutorial.active, isNull);
        // Remain in water until the next actual immersion to prove once-per-attempt.
        var leftWater = !controller.snapshot.playerEntity!.isSwimming;
        for (
          var frame = 0;
          frame < 150 && !controller.snapshot.gameOver;
          frame++
        ) {
          await core.prepareNextTick();
          controller.advanceFrame(1 / 60);
          expect(tutorial.active, isNull);
          if (!controller.snapshot.playerEntity!.isSwimming) leftWater = true;
          if (leftWater && controller.snapshot.playerEntity!.isSwimming) break;
        }
        expect(leftWater, isTrue);
        expect(controller.snapshot.playerEntity!.isSwimming, isTrue);
        // Exit the actual pool using normal strokes, then walk through the tree.
        // Bypass/return also proves completed decoration guidance never repeats.
        bindings.actions.setMoveAxis(1);
        for (
          var frame = 0;
          frame < 500 && controller.snapshot.playerEntity!.pos.x < 1150;
          frame++
        ) {
          await core.prepareNextTick();
          if (controller.snapshot.playerEntity!.isSwimming &&
              controller.snapshot.hud.canAffordJump) {
            bindings.actions.triggerAction(RunnerGameplayAction.jump);
          }
          bindings.actions.pumpHeldInputs();
          controller.advanceFrame(1 / 60);
          if (tutorial.active != null) {
            expect(
              returnToPool,
              isFalse,
              reason: 'A completed lesson must not repeat.',
            );
            acceptDecoration();
          }
          if (controller.snapshot.gameOver) break;
        }
        expect(controller.snapshot.gameOver, isFalse);
        expect(
          controller.snapshot.playerEntity!.pos.x,
          greaterThanOrEqualTo(1150),
        );
        expect(tutorial.active, isNull);
        expect(tutorial.isVisible(TutorialHudElement.primary), isFalse);
        // Continue from spawn through the actual third-chunk gap. One variant
        // uses a later authored warning (20 units) and jumps before that window.
        var earlyJump = false;
        for (
          var frame = 0;
          frame < 240 &&
              tutorial.active == null &&
              controller.snapshot.playerEntity!.pos.x < 1510;
          frame++
        ) {
          await core.prepareNextTick();
          final actor = controller.snapshot.playerEntity!;
          if (returnToPool &&
              !earlyJump &&
              actor.grounded &&
              actor.pos.x >= 1390) {
            earlyJump = true;
            bindings.actions.triggerAction(RunnerGameplayAction.jump);
          }
          bindings.actions.pumpHeldInputs();
          controller.advanceFrame(1 / 60);
          if (controller.snapshot.gameOver) break;
        }
        if (!returnToPool) {
          expect(tutorial.active, isA<CampaignGapTutorial>());
          expect(controller.snapshot.playerEntity!.grounded, isTrue);
          expect(
            controller.snapshot.playerEntity!.pos.x,
            inInclusiveRange(1325, 1330),
          );
          expect(tutorial.worldTargetBounds!.left, 1421);
          expect(tutorial.worldTargetBounds!.width, 69);
          final hud = tutorial.visibleHud;
          final tick = controller.tick;
          controller.advanceFrame(.1);
          expect(controller.tick, tick);
          expect(tutorial.acceptAction(RunnerGameplayAction.jump), isFalse);
          tutorial.suspend();
          expect(tutorial.acceptMovement(), isFalse);
          tutorial.resumeGuidance();
          expect(tutorial.acceptMovement(), isTrue);
          expect(tutorial.visibleHud, hud);
          controller.setPaused(false);
          bindings.actions.setMoveAxis(1);
          for (
            var frame = 0;
            frame < 120 && controller.snapshot.playerEntity!.pos.x < 1395;
            frame++
          ) {
            await core.prepareNextTick();
            bindings.actions.pumpHeldInputs();
            controller.advanceFrame(1 / 60);
            expect(
              controller.snapshot.playerEntity!.grounded,
              isTrue,
              reason: 'Movement dismissal must not synthesize a jump.',
            );
          }
          if (jumpGap) {
            final stamina = controller.snapshot.hud.stamina;
            bindings.actions.triggerAction(RunnerGameplayAction.jump);
            await core.prepareNextTick();
            controller.advanceFrame(1 / 60);
            expect(controller.snapshot.hud.stamina, lessThan(stamina));
          }
        } else {
          expect(earlyJump, isTrue);
          expect(
            tutorial.active,
            isNull,
            reason: 'Do not pause an early airborne crossing.',
          );
        }
        for (var frame = 0; frame < 180; frame++) {
          await core.prepareNextTick();
          if (controller.snapshot.playerEntity!.pos.x >= 1510) {
            bindings.actions.setMoveAxis(0);
          }
          bindings.actions.pumpHeldInputs();
          controller.advanceFrame(1 / 60);
          expect(tutorial.active, isNull);
          if (controller.snapshot.gameOver ||
              (controller.snapshot.playerEntity!.grounded &&
                  controller.snapshot.playerEntity!.pos.x >= 1510)) {
            break;
          }
        }
        expect(
          controller.snapshot.gameOver,
          !jumpGap,
          reason: 'Walking into the opening must fail; an ordinary jump must cross.',
        );
        if (jumpGap) {
          expect(controller.snapshot.playerEntity!.grounded, isTrue);
          expect(
            controller.snapshot.playerEntity!.pos.x,
            greaterThanOrEqualTo(1510),
          );
        }
        if (jumpGap) {
          Future<void> frame() async {
            await core.prepareNextTick();
            bindings.actions.pumpHeldInputs();
            controller.advanceFrame(1 / 60);
            expect(controller.snapshot.gameOver, isFalse);
          }

          // Clear the remaining third-chunk rock using ordinary jumps.
          bindings.actions.setMoveAxis(1);
          for (
            var i = 0;
            i < 400 &&
                tutorial.active == null &&
                controller.snapshot.playerEntity!.pos.x <
                    (returnToPool ? 1930 : 1950);
            i++
          ) {
            final actor = controller.snapshot.playerEntity!;
            if (actor.grounded && actor.pos.x >= 1560 && actor.pos.x < 1760) {
              bindings.actions.triggerAction(RunnerGameplayAction.jump);
            }
            await frame();
          }
          final visible = tutorial.visibleHud;
          if (!returnToPool) {
            expect(tutorial.active, isA<CampaignPlatformTutorial>());
            expect(controller.snapshot.playerEntity!.grounded, isTrue);
            expect(
              controller.snapshot.playerEntity!.pos.x,
              inInclusiveRange(1896, 1901),
            );
            expect(tutorial.worldTargetBounds!.left, 1960);
            expect(tutorial.worldTargetBounds!.top, 160);
            expect(tutorial.worldTargetBounds!.width, 64);
            final tick = controller.tick;
            controller.advanceFrame(.1);
            expect(controller.tick, tick);
            expect(tutorial.acceptAction(RunnerGameplayAction.jump), isFalse);
            tutorial.suspend();
            expect(tutorial.acceptMovement(), isFalse);
            tutorial.resumeGuidance();
            expect(tutorial.acceptMovement(), isTrue);
            expect(tutorial.visibleHud, visible);
            controller.setPaused(false);
            bindings.actions.setMoveAxis(1);
            for (
              var i = 0;
              i < 120 && controller.snapshot.playerEntity!.pos.x < 1970;
              i++
            ) {
              await frame();
              expect(
                controller.snapshot.playerEntity!.grounded,
                isTrue,
                reason: 'Walking under the one-way platform must not hit a wall or auto-jump.',
              );
            }
          } else {
            expect(tutorial.active, isNull);
          }
          // Jump up through the platform, arrest horizontal movement over it,
          // then land on top. Repeat across the actual ascending/descending set.
          for (final (targetX, topY) in [
            (1980.0, 160.0),
            (2088.0, 112.0),
            (2184.0, 128.0),
          ]) {
            final before = controller.snapshot.hud.stamina;
            bindings.actions.triggerAction(RunnerGameplayAction.jump);
            var roseAbove = false, landed = false;
            for (var i = 0; i < 180; i++) {
              bindings.actions.setMoveAxis(
                controller.snapshot.playerEntity!.pos.x < targetX ? 1 : 0,
              );
              await frame();
              final actor = controller.snapshot.playerEntity!;
              if (i == 0) {
                expect(controller.snapshot.hud.stamina, lessThan(before));
              }
              if (!actor.grounded && actor.vel!.y < 0 && actor.pos.y < topY) {
                roseAbove = true;
              }
              expect(tutorial.active, isNull);
              if (roseAbove && actor.grounded) {
                landed = true;
                break;
              }
            }
            expect(
              roseAbove,
              isTrue,
              reason: 'Jump must pass upward through platform at $targetX.',
            );
            expect(landed, isTrue);
            final contact = core.buildTerrainPlayerDebugSnapshot()!;
            expect(contact.grounded, isTrue);
            expect(
              contact.supportPointYTicks / 1024,
              topY,
              reason: 'Must land on the platform top, not the ground below.',
            );
            expect(contact.supportEdgeId!.placementKey, isNotNull);
          }
          bindings.actions.setMoveAxis(1);
          bindings.actions.triggerAction(RunnerGameplayAction.jump);
          for (var i = 0; i < 300; i++) {
            if (controller.snapshot.playerEntity!.pos.x >= 2410) {
              bindings.actions.setMoveAxis(0);
            }
            await frame();
            expect(tutorial.active, isNull);
            if (controller.snapshot.playerEntity!.grounded &&
                controller.snapshot.playerEntity!.pos.x >= 2400) {
              break;
            }
          }
          expect(controller.snapshot.playerEntity!.grounded, isTrue);
          expect(
            controller.snapshot.playerEntity!.pos.x,
            greaterThanOrEqualTo(2400),
          );
          expect(tutorial.visibleHud, visible);
          expect(tutorial.showBlessingObjective, isFalse);
          Future<void> walkTo(double x) async {
            bindings.actions.setMoveAxis(1);
            for (
              var i = 0;
              i < 400 &&
                  controller.snapshot.playerEntity!.pos.x < x &&
                  tutorial.active == null;
              i++
            ) {
              await frame();
            }
          }

          Future<void> jumpTo(double x, {double? top}) async {
            final forward = controller.snapshot.playerEntity!.pos.x < x;
            bindings.actions.setMoveAxis(forward ? 1 : -1);
            bindings.actions.triggerAction(RunnerGameplayAction.jump);
            var airborne = false, landed = false;
            for (var i = 0; i < 240; i++) {
              if (forward
                  ? controller.snapshot.playerEntity!.pos.x >= x
                  : controller.snapshot.playerEntity!.pos.x <= x) {
                bindings.actions.setMoveAxis(0);
              }
              await frame();
              final actor = controller.snapshot.playerEntity!;
              airborne |= !actor.grounded;
              if (airborne && actor.grounded) {
                landed = true;
                break;
              }
            }
            expect(
              landed,
              isTrue,
              reason:
                  'Jump to $x must land; actor=${controller.snapshot.playerEntity!.pos}',
            );
            if (top != null) {
              expect(
                core.buildTerrainPlayerDebugSnapshot()!.supportPointYTicks /
                    1024,
                top,
              );
            }
          }

          // Continue across the real fifth-chunk pool using its two platforms.
          await walkTo(2460);
          await jumpTo(2576, top: 160);
          await jumpTo(2688, top: 128);
          await jumpTo(2805, top: 224);
          await walkTo(2820);
          await jumpTo(2960);
          await walkTo(3080);
          await jumpTo(3210, top: 224);
          await walkTo(3340);
          await jumpTo(3470, top: 224);
          await walkTo(3900);
          expect(tutorial.active, isA<CampaignBlessingTutorial>());
          expect(tutorial.step, 0);
          expect(controller.snapshot.playerEntity!.grounded, isTrue);
          expect(
            controller.snapshot.playerEntity!.pos.x,
            inInclusiveRange(3732, 3738),
          );
          expect(tutorial.showBlessingObjective, isTrue);
          expect(controller.snapshot.campaign!.blessingReceived, isFalse);
          final objectiveTick = controller.tick;
          tutorial.nextStep();
          expect(tutorial.step, 0);
          expect(tutorial.acceptAction(RunnerGameplayAction.jump), isFalse);
          controller.advanceFrame(.1);
          expect(controller.tick, objectiveTick);
          expect(tutorial.acceptMovement(), isTrue);
          controller.setPaused(false);
          await walkTo(3800);
          expect(tutorial.active, isNull);
          expect(controller.snapshot.campaign!.blessingReceived, isFalse);
          if (returnToPool) {
            await jumpTo(3890);
            expect(controller.snapshot.campaign!.blessingReceived, isFalse);
            expect(
              tutorial.active,
              isNull,
              reason: 'Bypassing the basin keeps practice pending.',
            );
            await jumpTo(3848, top: 160);
          } else {
            await jumpTo(3830, top: 160);
          }
          expect(
            tutorial.active,
            isA<CampaignBlessingTutorial>(),
            reason:
                'Landing: ${controller.snapshot.playerEntity!.pos}, '
                '${core.buildTerrainPlayerDebugSnapshot()}, '
                '${controller.snapshot.interactions.map((s) => (s.x, s.y, s.active))}',
          );
          expect(tutorial.step, 1);
          expect(controller.snapshot.campaign!.blessingReceived, isTrue);
          expect(controller.snapshot.campaign!.completed, 2);
          expect(controller.snapshot.hud.blessings, hasLength(1));
          expect(
            controller.snapshot.interactions.where((s) => s.active),
            hasLength(1),
          );
          expect(tutorial.acceptMovement(), isFalse);
          tutorial.suspend();
          tutorial.nextStep();
          expect(tutorial.step, 1);
          tutorial.resumeGuidance();
          tutorial.nextStep();
          expect(tutorial.step, 2);
          expect(tutorial.target, CampaignTutorialTarget.blessingResources);
          expect(tutorial.worldTargetBounds, isNull);
          expect(tutorial.isVisible(TutorialHudElement.blessings), isTrue);
          final receivedTick = controller.tick;
          controller.advanceFrame(.1);
          expect(controller.tick, receivedTick);
          expect(tutorial.acceptMovement(), isTrue);
          controller.setPaused(false);
          await walkTo(3900);
          await jumpTo(4020); // Clear the statue after the basin.
          await walkTo(4210);
          expect(tutorial.active, isNull);
          expect(controller.snapshot.campaign!.blessingReceived, isTrue);
          expect(
            controller.snapshot.playerEntity!.pos.x,
            greaterThanOrEqualTo(4200),
          );
          final fixturePath =
              Platform.environment['REPORTING_BLESSING_REPLAY_PATH'];
          if (!returnToPool && fixturePath != null) {
            final snapshot = controller.snapshot;
            await File(fixturePath).writeAsString(
              jsonEncode({
                'contentDigest': campaignContentDigest,
                'totalTicks': snapshot.tick,
                'commandStream': frames.map((f) => f.toJson()).toList(),
                'x': snapshot.playerEntity!.pos.x,
                'y': snapshot.playerEntity!.pos.y,
                'hp': snapshot.hud.hp,
                'mana': snapshot.hud.mana,
                'stamina': snapshot.hud.stamina,
                'collectibles': snapshot.hud.collectibles,
              }),
            );
          }
          // A view attaching after an early grant skips the now-obsolete objective page.
          tutorial.stop();
          final late = CampaignTutorialController(
            controller: controller,
            mission: mission,
            sequences: [
              metadata.tutorialSequences
                  .whereType<CampaignBlessingTutorial>()
                  .single,
            ],
            initialHud: {TutorialHudElement.movement},
            cancelInput: () {},
          );
          expect(late.startNormally(), isTrue);
          await frame();
          expect(late.active, isA<CampaignBlessingTutorial>());
          expect(late.step, 1);
          expect(late.showBlessingObjective, isTrue);
          late.dispose();
        }
        expect(tutorial.isVisible(TutorialHudElement.primary), isFalse);
        tutorial.stop();
        tutorial.nextStep();
        expect(tutorial.acceptAction(RunnerGameplayAction.jump), isFalse);
      },
    );
  }
}
