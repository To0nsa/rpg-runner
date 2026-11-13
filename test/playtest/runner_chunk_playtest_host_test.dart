import 'package:runner_core/events/game_event.dart';
import 'package:rpg_runner/ui/runner_gameplay_surface.dart';
import 'package:runner_core/campaign/campaign_registry.dart';
import 'package:rpg_runner/ui/campaign/campaign_catalog.dart';
import 'package:rpg_runner/ui/hud/game/score_overlay.dart';
import 'package:rpg_runner/ui/controls/action_button.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:rpg_runner/ui/tutorial/campaign_tutorial_overlay.dart';
import 'package:rpg_runner/ui/tutorial/campaign_tutorial_geometry.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/controls/widgets/jump_control.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_identity.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/finite_chunk_pattern_source.dart';
import 'package:runner_core/training/authored_training_field.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:rpg_runner/game/themes/authored_parallax_themes.dart';
import 'package:rpg_runner/game/themes/terrain_material_registry.dart';
import 'package:rpg_runner/ui/input/desktop/runner_desktop_input_adapter.dart';
import 'package:rpg_runner/ui/campaign/campaign_hud.dart';
import 'package:rpg_runner/ui/controls/move_buttons.dart';
import 'package:rpg_runner/ui/controls/move_joystick.dart';
import 'package:rpg_runner/ui/controls/hold_action_button.dart';
import 'package:rpg_runner/ui/controls/directional_action_button.dart';
import 'package:rpg_runner/ui/hud/game/game_overlay.dart';
import 'package:rpg_runner/ui/hud/game/resource_bar.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';

import '../test_support/fixture_sprite_bounds.dart';

void main() {
  late ui.Image fixtureImage;

  setUpAll(() async {
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide400')..addFont(
          rootBundle.load(
            'packages/lucide_icons_flutter/assets/build_font/LucideVariable-w400.ttf',
          ),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('CrimsonText')..addFont(
          rootBundle.load('assets/fonts/Crimson_Text/CrimsonText-Regular.ttf'),
        ))
        .load();
    await (FontLoader('Inter')..addFont(
          rootBundle.load('assets/fonts/Inter/static/Inter_24pt-Regular.ttf'),
        ))
        .load();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const Color(0x00000000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final bounds = fixtureSpriteBounds();
    fixtureImage = await picture.toImage(bounds.width, bounds.height);
    picture.dispose();
  });

  tearDownAll(() => fixtureImage.dispose());

  testWidgets(
    'unresolved presentation blocks start and pauses a live attempt',
    (tester) async {
      final controller = RunnerPlaytestController();
      controller.setPresentationBlocked(true);
      await _mountHost(
        tester,
        scenario: _campaignScenario(),
        controller: controller,
        onStop: () {},
        imagesFactory: (_) => _FixtureImages(fixtureImage),
      );
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(controller.start(), isFalse);
      controller.setPresentationBlocked(false);
      expect(controller.status.phase, RunnerPlaytestPhase.ready);
      expect(controller.start(), isTrue);
      await _pumpFrames(tester, 5);
      controller.setPresentationBlocked(true);
      expect(controller.status.phase, RunnerPlaytestPhase.paused);
      final snapshot = controller.snapshot;
      await _pumpFrames(tester, 5);
      expect(controller.snapshot, same(snapshot));
      expect(controller.resume(), isFalse);
      controller.setPresentationBlocked(false);
      expect(controller.status.phase, RunnerPlaytestPhase.paused);
      expect(controller.resume(), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  for (final mode in MovementControlMode.values) {
    testWidgets('campaign mobile HUD moves with $mode and cancels on pause', (
      tester,
    ) async {
      final controller = RunnerPlaytestController();
      await _mountHost(
        tester,
        scenario: _campaignScenario(),
        controller: controller,
        onStop: () {},
        presentation: RunnerPlaytestPresentation(
          showMobileHud: true,
          movementControlMode: mode,
          viewportMode: ViewportScaleMode.pixelPerfectCover,
          display: RunnerPlaytestDevicePresets.defaultPhone,
        ),
        imagesFactory: (_) => _FixtureImages(fixtureImage),
      );
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(find.byType(GameOverlay), findsOneWidget);
      expect(find.byType(ResourceBar), findsNWidgets(3));
      expect(find.byType(CampaignHud), findsOneWidget);
      expect(controller.snapshot!.hud.hasSecondarySlot, isTrue);
      expect(controller.snapshot!.hud.secondarySlotValid, isTrue);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(
        find.byKey(const ValueKey('playtest_movement_controls')),
        findsNothing,
      );
      expect(controller.start(), isTrue);
      await tester.pump();
      // Finish the post-frame focus request and its input-cancellation rebuild.
      await tester.pump();
      final startX = controller.snapshot!.playerEntity!.pos.x;
      final control = mode == MovementControlMode.arrows
          ? find.byType(MoveButtons)
          : find.byType(MoveJoystick);
      final bounds = _globalRect(tester, control);
      final down = mode == MovementControlMode.arrows
          ? Offset(bounds.right - 15, bounds.center.dy)
          : bounds.center;
      final pointer = await tester.startGesture(
        down,
        kind: PointerDeviceKind.mouse,
      );
      if (mode != MovementControlMode.arrows) {
        await pointer.moveBy(const Offset(45, 0));
      }
      await _pumpFrames(tester, 20);
      expect(controller.snapshot!.playerEntity!.pos.x, greaterThan(startX + 5));
      expect(controller.status.phase, RunnerPlaytestPhase.running);
      // No intervening frame: the epoch must still invalidate the held pointer.
      expect(controller.pause(), isTrue);
      expect(controller.resume(), isTrue);
      await _pumpFrames(tester, 20);
      final stoppedX = controller.snapshot!.playerEntity!.pos.x;
      await _pumpFrames(tester, 20);
      expect(controller.snapshot!.playerEntity!.pos.x, closeTo(stoppedX, .001));
      await pointer.up();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets('catalog shield can be held and presentation survives restart', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = RunnerPlaytestController();
    await _mountHost(
      tester,
      scenario: _campaignScenario(),
      controller: controller,
      onStop: () {},
      presentation: const RunnerPlaytestPresentation(
        showMobileHud: true,
        movementControlMode: MovementControlMode.fixedJoystick,
        viewportMode: ViewportScaleMode.pixelPerfectCover,
        display: RunnerPlaytestDevicePresets.defaultPhone,
      ),
      imagesFactory: (_) => _FixtureImages(fixtureImage),
    );
    await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
    final initial = _snapshotRecord(controller.snapshot!);
    expect(controller.status.runtimeGeneration, 1);
    expect(_snapshotRecord(controller.snapshot!), initial);
    expect(
      tester.widget<MoveJoystick>(find.byType(MoveJoystick)).floating,
      isFalse,
    );

    controller.start();
    await tester.pump();
    await tester.pump();
    final shield = find.byWidgetPredicate(
      (widget) => widget is HoldActionButton && widget.label == 'Shield',
    );
    expect(shield, findsOneWidget);
    final stamina = controller.snapshot!.hud.stamina;
    final pointer = await tester.startGesture(tester.getCenter(shield));
    await _pumpFrames(tester, 15);
    expect(controller.snapshot!.hud.stamina, lessThan(stamina));
    await pointer.up();
    final releasedStamina = controller.snapshot!.hud.stamina;
    await _pumpFrames(tester, 30);
    expect(
      controller.snapshot!.hud.stamina,
      greaterThanOrEqualTo(releasedStamina),
    );

    controller.restart();
    await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
    expect(_snapshotRecord(controller.snapshot!), initial);
    expect(find.byType(GameOverlay), findsOneWidget);
    expect(
      tester.getSize(find.byType(GameOverlay)),
      RunnerPlaytestDevicePresets.defaultPhone.size,
    );
    expect(
      tester.widget<MoveJoystick>(find.byType(MoveJoystick)).floating,
      isFalse,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'HUD can stay hidden and explicit loadout overrides are honored',
    (tester) async {
      final controller = RunnerPlaytestController();
      await _mountHost(
        tester,
        scenario: _campaignScenario(
          equippedLoadout: const EquippedLoadoutDef(),
        ),
        controller: controller,
        onStop: () {},
        presentation: const RunnerPlaytestPresentation(
          viewportMode: ViewportScaleMode.pixelPerfectCover,
          display: RunnerPlaytestDevicePresets.defaultPhone,
        ),
        imagesFactory: (_) => _FixtureImages(fixtureImage),
      );
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(controller.snapshot!.hud.hasSecondarySlot, isFalse);
      expect(find.byType(GameOverlay), findsNothing);
      expect(
        tester.getSize(find.byType(RunnerDesktopInputAdapter)),
        RunnerPlaytestDevicePresets.defaultPhone.size,
      );
      controller.restart();
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(find.byType(GameOverlay), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  for (final mode in <MovementControlMode?>[
    ...MovementControlMode.values,
    null,
  ]) {
    testWidgets('ordered tutorials reach combat after dash: $mode', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1100, 650));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = RunnerPlaytestController();
      final reviewKey = GlobalKey();
      final metadata = CampaignCatalog.mission('reporting_for_duty')!;
      await _mountHost(
        tester,
        reviewKey: reviewKey,
        scenario: CampaignPlaytestScenario(
          mission: campaignMissions[metadata.id]!,
          playerCharacter: PlayerCharacterRegistry.eloise,
          seed: 42,
        ),
        controller: controller,
        onStop: () {},
        appearance: RunnerPlaytestAppearance(
          parallaxThemes: authoredParallaxThemesById,
          terrainMaterials: TerrainMaterialRegistry.byKey,
          tutorialSequences: metadata.tutorialSequences,
          initialTutorialHud: metadata.initialTutorialHud,
        ),
        presentation: RunnerPlaytestPresentation(
          showMobileHud: mode != null,
          movementControlMode: mode ?? MovementControlMode.arrows,
          viewportMode: ViewportScaleMode.pixelPerfectCover,
          display: RunnerPlaytestDevicePresets.defaultPhone,
        ),
      );
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(find.byType(ResourceBar), findsNothing);
      expect(find.byType(ScoreOverlay), findsNothing);
      expect(find.byType(CampaignHud), findsNothing);
      expect(find.byType(ActionButton), findsNothing);
      expect(find.byType(HoldActionButton), findsNothing);
      TestGesture? held;
      late Offset point;
      if (mode == null) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      } else {
        final finder = mode == MovementControlMode.arrows
            ? find.byType(MoveButtons)
            : find.byType(MoveJoystick);
        final bounds = _globalRect(tester, finder);
        point = mode == MovementControlMode.arrows
            ? bounds.centerRight - const Offset(12, 0)
            : bounds.center;
        held = await tester.startGesture(point);
        if (mode != MovementControlMode.arrows) {
          await held.moveBy(const Offset(60, 0));
        }
      }
      await _pumpFrames(tester, 6);
      expect(find.text('Your first objective'), findsNothing);
      expect(controller.snapshot!.paused, isFalse);
      expect(find.byType(CampaignHud), findsNothing);
      for (
        var frame = 0;
        frame < 90 && find.text('Your first objective').evaluate().isEmpty;
        frame++
      ) {
        await _pumpFrames(tester, 1);
      }
      expect(find.text('Your first objective'), findsOneWidget);
      expect(controller.snapshot!.hud.collectibles, 0);
      expect(controller.snapshot!.paused, isTrue);
      expect(controller.snapshot!.campaign!.completed, 0);
      expect(
        find.byType(CampaignHud),
        mode == null ? findsNothing : findsOneWidget,
      );
      expect(find.byType(ScoreOverlay), findsNothing);
      final objectiveTick = controller.snapshot!.tick;
      if (mode == null) {
        tester
            .widget<RunnerDesktopInputAdapter>(
              find.byType(RunnerDesktopInputAdapter),
            )
            .controller
            .handleKeyEvent(
              const KeyRepeatEvent(
                physicalKey: PhysicalKeyboardKey.arrowRight,
                logicalKey: LogicalKeyboardKey.arrowRight,
                timeStamp: Duration.zero,
              ),
            );
      } else {
        await held!.moveBy(const Offset(3, 0));
      }
      await _pumpFrames(tester, 8);
      expect(controller.snapshot!.tick, objectiveTick);
      expect(find.text('Your first objective'), findsOneWidget);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'objectives_tutorial.png');
      }
      if (mode == null) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      } else {
        await held!.up();
        held = await tester.startGesture(point);
        if (mode != MovementControlMode.arrows) {
          await held.moveBy(const Offset(60, 0));
        }
      }
      // Preserve real continuous actor state from the authored spawn to its first coin.
      for (
        var frame = 0;
        frame < 300 && controller.snapshot!.hud.collectibles == 0;
        frame++
      ) {
        await _pumpFrames(tester, 1);
      }
      expect(controller.snapshot!.hud.collectibles, 1);
      expect(controller.snapshot!.campaign!.firstCoinCollected, isTrue);
      expect(controller.snapshot!.paused, isTrue);
      expect(find.text('Your first coin'), findsOneWidget);
      expect(
        find.byType(ScoreOverlay),
        mode == null ? findsNothing : findsOneWidget,
      );
      expect(find.byType(ResourceBar), findsNothing);
      expect(find.byType(ActionButton), findsNothing);
      final tick = controller.snapshot!.tick;
      if (mode == null) {
        tester
            .widget<RunnerDesktopInputAdapter>(
              find.byType(RunnerDesktopInputAdapter),
            )
            .controller
            .handleKeyEvent(
              const KeyRepeatEvent(
                physicalKey: PhysicalKeyboardKey.arrowRight,
                logicalKey: LogicalKeyboardKey.arrowRight,
                timeStamp: Duration.zero,
              ),
            );
      } else {
        await held!.moveBy(const Offset(3, 0));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _pumpFrames(tester, 8);
      expect(controller.snapshot!.tick, tick);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'first_coin_tutorial.png');
      }
      controller.setPresentationBlocked(true);
      expect(controller.resume(), isFalse);
      controller.setPresentationBlocked(false);
      expect(controller.resume(), isTrue);
      await tester.pump();
      expect(find.text('Your first coin'), findsOneWidget);
      expect(controller.snapshot!.tick, tick);
      final x = controller.snapshot!.playerEntity!.pos.x;
      if (mode == null) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      } else {
        await held!.up();
        held = await tester.startGesture(point);
        if (mode != MovementControlMode.arrows) {
          await held.moveBy(const Offset(60, 0));
        }
      }
      await _pumpFrames(tester, 10);
      expect(find.byType(CampaignTutorialOverlay), findsNothing);
      expect(controller.snapshot!.playerEntity!.pos.x, greaterThan(x));
      expect(
        find.byType(ScoreOverlay),
        mode == null ? findsNothing : findsOneWidget,
      );
      for (
        var frame = 0;
        frame < 240 && find.text('Obstacles ahead').evaluate().isEmpty;
        frame++
      ) {
        await _pumpFrames(tester, 1);
      }
      expect(find.text('Obstacles ahead'), findsOneWidget);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        inInclusiveRange(600, 605),
      );
      expect(controller.snapshot!.paused, isTrue);
      expect(find.byType(ResourceBar), findsNothing);
      expect(find.byType(ActionButton), findsNothing);
      final obstacleTick = controller.snapshot!.tick;
      final stamina = controller.snapshot!.hud.stamina;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await _pumpFrames(tester, 3);
      expect(controller.snapshot!.tick, obstacleTick);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'jump_obstacle_tutorial.png');
      }
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Step 2/3'), findsOneWidget);
      expect(
        find.byType(ActionButton),
        mode == null ? findsNothing : findsOneWidget,
      );
      expect(find.byType(ResourceBar), findsNothing);
      controller.setPresentationBlocked(true);
      expect(controller.resume(), isFalse);
      controller.setPresentationBlocked(false);
      expect(controller.resume(), isTrue);
      await tester.pump();
      expect(find.text('Step 2/3'), findsOneWidget);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'jump_button_tutorial.png');
      }
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Watch your stamina'), findsOneWidget);
      expect(
        find.byType(ResourceBar),
        mode == null ? findsNothing : findsNWidgets(3),
      );
      tester
          .widget<RunnerDesktopInputAdapter>(
            find.byType(RunnerDesktopInputAdapter),
          )
          .controller
          .handleKeyEvent(
            const KeyRepeatEvent(
              physicalKey: PhysicalKeyboardKey.space,
              logicalKey: LogicalKeyboardKey.space,
              timeStamp: Duration.zero,
            ),
          );
      await _pumpFrames(tester, 3);
      expect(controller.snapshot!.tick, obstacleTick);
      expect(controller.snapshot!.hud.stamina, stamina);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'jump_resources_tutorial.png');
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      if (mode == null) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      } else {
        await held!.up();
        held = await tester.startGesture(point);
        if (mode != MovementControlMode.arrows) {
          await held.moveBy(const Offset(60, 0));
        }
      }
      await _pumpFrames(tester, 3);
      expect(
        controller.snapshot!.tick,
        obstacleTick,
        reason: 'Movement cannot dismiss the jump lesson.',
      );
      if (mode == null) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      } else {
        await tester.tap(find.byType(ActionButton));
      }
      await _pumpFrames(tester, 4);
      expect(find.byType(CampaignTutorialOverlay), findsNothing);
      expect(controller.snapshot!.paused, isFalse);
      expect(controller.snapshot!.hud.stamina, lessThan(stamina));
      expect(controller.snapshot!.playerEntity!.vel!.y, lessThan(0));
      expect(find.byType(HoldActionButton), findsNothing);
      if (mode == null) await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      if (mode == null) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      } else {
        await held!.up();
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      for (
        var frame = 0;
        frame < 500 && !controller.snapshot!.paused;
        frame++
      ) {
        if (controller.snapshot!.playerEntity!.grounded) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
          await _pumpFrames(tester, 1);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        }
        await _pumpFrames(tester, 1);
      }
      expect(find.text('Water ahead'), findsOneWidget);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        inInclusiveRange(868, 875),
      );
      final waterTick = controller.snapshot!.tick;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await _pumpFrames(tester, 3);
      expect(controller.snapshot!.tick, waterTick);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'water_tutorial.png');
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await _pumpFrames(tester, 1);
      expect(find.text('Water ahead'), findsNothing);
      var stoppedAtPool = false;
      for (
        var frame = 0;
        frame < 300 && !controller.snapshot!.paused;
        frame++
      ) {
        if (!stoppedAtPool && controller.snapshot!.playerEntity!.pos.x >= 930) {
          stoppedAtPool = true;
          await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        }
        await _pumpFrames(tester, 1);
      }
      expect(find.text('Swim upward'), findsOneWidget);
      expect(controller.snapshot!.playerEntity!.isSwimming, isTrue);
      final swimTick = controller.snapshot!.tick;
      final swimStamina = controller.snapshot!.hud.stamina;
      tester
          .widget<RunnerDesktopInputAdapter>(
            find.byType(RunnerDesktopInputAdapter),
          )
          .controller
          .handleKeyEvent(
            const KeyRepeatEvent(
              physicalKey: PhysicalKeyboardKey.space,
              logicalKey: LogicalKeyboardKey.space,
              timeStamp: Duration.zero,
            ),
          );
      await _pumpFrames(tester, 3);
      expect(
        controller.snapshot!.tick,
        swimTick,
        reason: 'A Jump held before immersion cannot accept swimming guidance.',
      );
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'swimming_tutorial.png');
      }
      controller.pause();
      await tester.pump();
      expect(controller.resume(), isTrue);
      await tester.pump();
      expect(find.text('Swim upward'), findsOneWidget);
      expect(controller.snapshot!.tick, swimTick);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      if (mode == null) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      } else {
        await tester.tap(find.byType(ActionButton));
      }
      await _pumpFrames(tester, 3);
      expect(find.text('Swim upward'), findsNothing);
      expect(controller.snapshot!.playerEntity!.vel!.y, lessThan(0));
      expect(controller.snapshot!.hud.stamina, lessThan(swimStamina));
      if (mode == null) await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      if (!stoppedAtPool) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      for (
        var frame = 0;
        frame < 500 && !controller.snapshot!.paused;
        frame++
      ) {
        if (controller.snapshot!.playerEntity!.isSwimming &&
            controller.snapshot!.hud.canAffordJump) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
          await _pumpFrames(tester, 1);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        }
        await _pumpFrames(tester, 1);
      }
      expect(find.text('Scenery or obstacle?'), findsOneWidget);
      expect(controller.snapshot!.playerEntity!.grounded, isTrue);
      expect(controller.snapshot!.playerEntity!.isSwimming, isFalse);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        greaterThanOrEqualTo(984),
      );
      final decorationTick = controller.snapshot!.tick;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _pumpFrames(tester, 4);
      expect(controller.snapshot!.tick, decorationTick);
      expect(find.byType(HoldActionButton), findsNothing);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'decoration_tutorial.png');
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      if (mode == null) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      } else {
        held = await tester.startGesture(point);
        if (mode != MovementControlMode.arrows) {
          await held.moveBy(const Offset(60, 0));
        }
      }
      for (
        var frame = 0;
        frame < 120 && controller.snapshot!.playerEntity!.pos.x < 1150;
        frame++
      ) {
        await _pumpFrames(tester, 1);
      }
      expect(find.text('Scenery or obstacle?'), findsNothing);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        greaterThanOrEqualTo(1150),
      );
      // Keep the same actor and movement hold into the third chunk.
      for (
        var frame = 0;
        frame < 240 && !controller.snapshot!.paused;
        frame++
      ) {
        await _pumpFrames(tester, 1);
      }
      expect(find.text('Mind the gap'), findsOneWidget);
      expect(controller.snapshot!.playerEntity!.grounded, isTrue);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        inInclusiveRange(1325, 1330),
      );
      final gapTick = controller.snapshot!.tick;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _pumpFrames(tester, 4);
      expect(controller.snapshot!.tick, gapTick);
      expect(find.byType(HoldActionButton), findsNothing);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'gap_tutorial.png');
      }
      if (mode == null) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      } else {
        await held!.up();
        held = await tester.startGesture(point);
        if (mode != MovementControlMode.arrows) {
          await held.moveBy(const Offset(60, 0));
        }
      }
      for (
        var frame = 0;
        frame < 120 && controller.snapshot!.playerEntity!.pos.x < 1395;
        frame++
      ) {
        await _pumpFrames(tester, 1);
        expect(controller.snapshot!.playerEntity!.grounded, isTrue);
      }
      expect(find.text('Mind the gap'), findsNothing);
      final gapStamina = controller.snapshot!.hud.stamina;
      if (mode == null) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      } else {
        await tester.tap(find.byType(JumpControl));
      }
      await _pumpFrames(tester, 2);
      expect(controller.snapshot!.hud.stamina, lessThan(gapStamina));
      if (mode == null) await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      for (
        var frame = 0;
        frame < 150 && controller.snapshot!.playerEntity!.pos.x < 1510;
        frame++
      ) {
        await _pumpFrames(tester, 1);
      }
      if (mode == null) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      } else {
        await held!.up();
      }
      for (
        var frame = 0;
        frame < 120 && !controller.snapshot!.playerEntity!.grounded;
        frame++
      ) {
        await _pumpFrames(tester, 1);
      }
      expect(controller.snapshot!.gameOver, isFalse);
      expect(controller.snapshot!.playerEntity!.grounded, isTrue);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        greaterThanOrEqualTo(1490),
      );
      expect(find.text('Mind the gap'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      for (var i = 0; i < 400 && !controller.snapshot!.paused; i++) {
        final actor = controller.snapshot!.playerEntity!;
        if (actor.grounded && actor.pos.x >= 1560 && actor.pos.x < 1760) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
          await _pumpFrames(tester, 1);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        }
        await _pumpFrames(tester, 1);
      }
      expect(find.text('Platforms'), findsOneWidget);
      expect(controller.snapshot!.playerEntity!.grounded, isTrue);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        inInclusiveRange(1896, 1901),
      );
      final platformTick = controller.snapshot!.tick;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _pumpFrames(tester, 3);
      expect(controller.snapshot!.tick, platformTick);
      expect(find.byType(HoldActionButton), findsNothing);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'platform_tutorial.png');
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      if (mode == null) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      } else {
        held = await tester.startGesture(point);
        if (mode != MovementControlMode.arrows) {
          await held.moveBy(const Offset(60, 0));
        }
      }
      for (
        var i = 0;
        i < 120 && controller.snapshot!.playerEntity!.pos.x < 1970;
        i++
      ) {
        await _pumpFrames(tester, 1);
        expect(controller.snapshot!.playerEntity!.grounded, isTrue);
      }
      expect(find.text('Platforms'), findsNothing);
      final staminaBeforePlatform = controller.snapshot!.hud.stamina;
      if (mode == null) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      } else {
        await tester.tap(find.byType(JumpControl));
      }
      await _pumpFrames(tester, 2);
      expect(controller.snapshot!.hud.stamina, lessThan(staminaBeforePlatform));
      if (mode == null) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      }
      for (
        var i = 0;
        i < 60 && controller.snapshot!.playerEntity!.pos.x < 1980;
        i++
      ) {
        await _pumpFrames(tester, 1);
      }
      if (mode == null) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      } else {
        await held!.up();
      }
      for (
        var i = 0;
        i < 120 && !controller.snapshot!.playerEntity!.grounded;
        i++
      ) {
        await _pumpFrames(tester, 1);
      }
      expect(controller.snapshot!.gameOver, isFalse);
      expect(controller.snapshot!.playerEntity!.grounded, isTrue);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        inInclusiveRange(1960, 2022),
      );
      expect(controller.snapshot!.playerEntity!.pos.y, lessThan(200));
      expect(find.text('Platforms'), findsNothing);
      Future<void> walkTo(double x) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        for (
          var i = 0;
          i < 400 &&
              controller.snapshot!.playerEntity!.pos.x < x &&
              !controller.snapshot!.paused;
          i++
        ) {
          await _pumpFrames(tester, 1);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      }

      Future<void> jumpTo(double x) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await _pumpFrames(tester, 1);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        var released = false,
            airborne = !controller.snapshot!.playerEntity!.grounded;
        var landed = false;
        for (var i = 0; i < 240; i++) {
          if (!released && controller.snapshot!.playerEntity!.pos.x >= x) {
            await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
            released = true;
          }
          await _pumpFrames(tester, 1);
          final actor = controller.snapshot!.playerEntity!;
          airborne |= !actor.grounded;
          if (airborne && actor.grounded) {
            landed = true;
            break;
          }
        }
        if (!released) {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        }
        expect(
          landed,
          isTrue,
          reason: 'Land at $x: ${controller.snapshot!.playerEntity!.pos}',
        );
        expect(controller.snapshot!.gameOver, isFalse);
      }

      await jumpTo(2088);
      await jumpTo(2184);
      await jumpTo(2410);
      await walkTo(2460);
      await jumpTo(2576);
      await jumpTo(2688);
      await jumpTo(2805);
      await walkTo(2820);
      await jumpTo(2960);
      await walkTo(3080);
      await jumpTo(3210);
      await walkTo(3340);
      await jumpTo(3470);
      expect(find.text('Receive a blessing 0/1'), findsNothing);
      await walkTo(3900);
      expect(find.text('Receive a blessing'), findsOneWidget);
      expect(
        find.text('Receive a blessing 0/1'),
        mode == null ? findsNothing : findsOneWidget,
      );
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        inInclusiveRange(3732, 3738),
      );
      final blessingTick = controller.snapshot!.tick;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _pumpFrames(tester, 3);
      expect(controller.snapshot!.tick, blessingTick);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'blessing_objective.png');
      }
      Future<void> freshMove() async {
        if (mode == null) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
          await _pumpFrames(tester, 2);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        } else {
          final gesture = await tester.startGesture(point);
          if (mode != MovementControlMode.arrows) {
            await gesture.moveBy(const Offset(60, 0));
          }
          await _pumpFrames(tester, 2);
          await gesture.up();
        }
      }

      await freshMove();
      expect(controller.snapshot!.paused, isFalse);
      await walkTo(3800);
      await jumpTo(3830);
      expect(controller.snapshot!.campaign!.blessingReceived, isTrue);
      expect(controller.snapshot!.hud.blessings, hasLength(1));
      expect(find.text('A blessing received'), findsOneWidget);
      final explanation = find.ancestor(
        of: find.text('A blessing received'),
        matching: find.byType(Card),
      );
      final veil = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<TutorialVeilPainter>()
          .single;
      final surface = tester.getTopLeft(find.byType(CampaignTutorialOverlay));
      final opening = tutorialSpotlightRect(
        veil.target()!,
        veil.spotlight!,
      ).shift(surface);
      expect(
        tester.getRect(explanation).overlaps(opening),
        isFalse,
        reason: 'The explanation must leave the actual lit fire visible.',
      );
      expect(
        find.text('Receive a blessing 1/1'),
        mode == null ? findsNothing : findsOneWidget,
      );
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'blessing_received.png');
      }
      await freshMove();
      expect(
        controller.snapshot!.paused,
        isTrue,
        reason: 'The explanation advances with Next.',
      );
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Improved regeneration'), findsOneWidget);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'blessing_resources.png');
      }
      final grantedTick = controller.snapshot!.tick;
      await _pumpFrames(tester, 8);
      expect(controller.snapshot!.tick, grantedTick);
      await freshMove();
      expect(controller.snapshot!.paused, isFalse);
      await walkTo(3900);
      await jumpTo(4020);
      await walkTo(4210);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        greaterThanOrEqualTo(4200),
      );
      expect(controller.snapshot!.campaign!.blessingReceived, isTrue);
      for (var i = 0; i < 210; i++) {
        await _pumpFrames(tester, 1);
      }
      expect(find.text('Receive a blessing 1/1'), findsNothing);
      expect(find.text('Improved regeneration'), findsNothing);
      // Preserve actor state across the next real pool and into the downhill chunk.
      await walkTo(4300);
      await jumpTo(4472);
      await jumpTo(4584);
      await jumpTo(4680);
      expect(find.text('Mobility: Dash'), findsNothing);
      final mobilityButton = find.byWidgetPredicate(
        (w) => w is ActionButton && w.label == 'Mobility',
      );
      expect(mobilityButton, findsNothing);
      // A blocked key held before the reveal cannot dismiss the new lesson.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await walkTo(4800);
      expect(find.text('Mobility: Dash'), findsOneWidget);
      expect(controller.snapshot!.playerEntity!.grounded, isTrue);
      expect(controller.snapshot!.playerEntity!.isSwimming, isFalse);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        inInclusiveRange(4722, 4727),
      );
      final dashTick = controller.snapshot!.tick;
      tester
          .widget<RunnerDesktopInputAdapter>(
            find.byType(RunnerDesktopInputAdapter),
          )
          .controller
          .handleKeyEvent(
            const KeyRepeatEvent(
              physicalKey: PhysicalKeyboardKey.shiftLeft,
              logicalKey: LogicalKeyboardKey.shiftLeft,
              timeStamp: Duration.zero,
            ),
          );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await freshMove();
      await _pumpFrames(tester, 3);
      expect(controller.snapshot!.tick, dashTick);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'dash_tutorial.png');
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      final dashStamina = controller.snapshot!.hud.stamina;
      if (mode == null) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      } else {
        expect(mobilityButton, findsOneWidget);
        await tester.tap(mobilityButton);
      }
      await _pumpFrames(tester, 5);
      if (mode == null) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      }
      expect(find.text('Mobility: Dash'), findsNothing);
      expect(controller.snapshot!.paused, isFalse);
      expect(controller.snapshot!.playerEntity!.vel!.x, greaterThan(300));
      expect(controller.snapshot!.hud.stamina, lessThan(dashStamina - 1));
      await walkTo(4900);
      expect(
        controller.snapshot!.playerEntity!.pos.x,
        greaterThanOrEqualTo(4900),
      );
      expect(controller.snapshot!.gameOver, isFalse);
      expect(find.text('Mobility: Dash'), findsNothing);
      if (mode != null) expect(mobilityButton, findsOneWidget);
      // Continue across the real downhill seam into the authored Grojib encounter.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await walkTo(5700);
      expect(find.text('Your first enemy'), findsOneWidget);
      final combatSurface = tester.widget<RunnerGameplaySurface>(
        find.byType(RunnerGameplaySurface),
      );
      final enemyOpening = tutorialSpotlightRect(
        combatSurface.bindings.tutorial.worldTargetBounds!,
        combatSurface.bindings.tutorial.active!.spotlightFor(
          TutorialMovementControl.arrows,
          step: 0,
        )!,
      );
      final visibleWorld = tester
          .state<RunnerGameplaySurfaceState>(find.byType(RunnerGameplaySurface))
          .visibleWorldBounds!;
      expect(visibleWorld.contains(enemyOpening.topLeft), isTrue);
      expect(visibleWorld.contains(enemyOpening.bottomRight), isTrue);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'combat_enemy_tutorial.png');
      }
      final combatController = tester
          .widget<RunnerGameplaySurface>(find.byType(RunnerGameplaySurface))
          .runtime
          .controller;
      var combatHits = 0;
      combatController.addEventListener((event) {
        if (event is PlayerLandedHitFeedbackEvent) combatHits++;
      });
      expect(controller.snapshot!.gameOver, isFalse);
      final swordButton = find.byWidgetPredicate(
        (w) => w is ActionButton && w.label == 'Sword',
      );
      final projectileButton = find.byWidgetPredicate(
        (w) => w is ActionButton && w.label == 'Projectile',
      );
      expect(swordButton, findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Attack from a distance'), findsOneWidget);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(
          tester,
          reviewKey,
          'combat_projectile_tutorial.png',
        );
      }
      final shotTick = controller.snapshot!.tick;
      await _pumpFrames(tester, 3);
      expect(
        controller.snapshot!.tick,
        shotTick,
      ); // a previously held K cannot start
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      final manaBefore = controller.snapshot!.hud.mana;
      if (mode == null) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      } else {
        await tester.tap(projectileButton);
      }
      await _pumpFrames(tester, 18);
      expect(controller.snapshot!.hud.mana, lessThan(manaBefore - 5));
      expect(find.textContaining('Let the enemy approach'), findsOneWidget);
      expect(swordButton, findsNothing);
      final manaAfterShot = controller.snapshot!.hud.mana;
      // Repeated keyboard and touch attempts cannot fire a second shot.
      for (var i = 0; i < 240 && !controller.snapshot!.paused; i++) {
        if (i % 10 == 0) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
          if (mode != null) {
            await tester.tap(projectileButton, warnIfMissed: false);
          }
        }
        await _pumpFrames(tester, 1);
      }
      expect(
        controller.snapshot!.hud.mana,
        greaterThanOrEqualTo(manaAfterShot),
      );
      expect(find.text('Strike with your sword'), findsOneWidget);
      if (mode == MovementControlMode.arrows) {
        await _capturePreview(tester, reviewKey, 'combat_sword_tutorial.png');
      }
      expect(controller.snapshot!.hud.hp, controller.snapshot!.hud.hpMax);
      final swordStamina = controller.snapshot!.hud.stamina;
      final hitsBeforeSword = combatHits;
      final combatTrace = <String>[];
      combatController.addCompletedTickListener(() {
        if (combatTrace.length >= 20) return;
        final snap = combatController.snapshot;
        final foe = snap.entities.where((e) => e.enemyId != null).firstOrNull;
        final hero = snap.playerEntity!;
        combatTrace.add(
          '${snap.tick}: P ${hero.pos.x},${hero.pos.y} ${hero.anim.name}/${hero.animFrame}; E ${foe?.pos.x},${foe?.pos.y} ${foe?.anim.name}/${foe?.animFrame}; hp ${snap.hud.hp}',
        );
      });
      if (mode == null) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
      } else {
        await tester.tap(swordButton);
      }
      await _pumpFrames(tester, 18);
      expect(controller.snapshot!.paused, isFalse);
      expect(controller.snapshot!.hud.stamina, lessThan(swordStamina - 3));
      expect(find.textContaining('Let the enemy approach'), findsNothing);
      expect(find.text('Strike with your sword'), findsNothing);
      expect(
        combatHits,
        greaterThan(hitsBeforeSword),
        reason:
            'The introductory sword must land; hits before sword=$hitsBeforeSword, total=$combatHits. ${combatTrace.join(' / ')}',
      );
      expect(controller.snapshot!.hud.hp, controller.snapshot!.hud.hpMax);
      // Unlock is practical: after recovery a fresh projectile spends mana again.
      await _pumpFrames(tester, 20);
      final unlockedMana = controller.snapshot!.hud.mana;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await _pumpFrames(tester, 16);
      expect(controller.snapshot!.hud.mana, lessThan(unlockedMana - 5));
      expect(controller.snapshot!.gameOver, isFalse);
      controller.restart();
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(find.text('Moving around'), findsOneWidget);
      expect(find.byType(ScoreOverlay), findsNothing);
      expect(controller.snapshot!.hud.collectibles, 0);
      expect(controller.snapshot!.campaign!.firstCoinCollected, isFalse);
      expect(controller.snapshot!.campaign!.blessingReceived, isFalse);
      expect(controller.snapshot!.hud.blessings, isEmpty);
      expect(find.byType(CampaignHud), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  for (final mode in MovementControlMode.values) {
    testWidgets('movement tutorial starts with the same held $mode gesture', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1100, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tutorialReviewKey = GlobalKey();
      final controller = RunnerPlaytestController();
      await _mountHost(
        tester,
        reviewKey: tutorialReviewKey,
        scenario: _campaignScenario(),
        controller: controller,
        onStop: () {},
        appearance: RunnerPlaytestAppearance(
          parallaxThemes: authoredParallaxThemesById,
          terrainMaterials: TerrainMaterialRegistry.byKey,
          tutorialSequences: [CampaignMovementTutorial.movementIntroduction()],
        ),
        presentation: RunnerPlaytestPresentation(
          showMobileHud: true,
          viewportMode: ViewportScaleMode.pixelPerfectCover,
          movementControlMode: mode,
          display: RunnerPlaytestDevicePresets.defaultPhone,
        ),
      );
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(find.byType(CampaignTutorialOverlay), findsOneWidget);
      await _capturePreview(
        tester,
        tutorialReviewKey,
        'tutorial_${mode.name}.png',
      );
      expect(controller.snapshot!.tick, 0);
      expect(controller.start(), isFalse);
      final jump = find.byWidgetPredicate(
        (w) => w is ActionButton && w.label == 'Jump',
      );
      expect(jump, findsOneWidget);
      await tester.tapAt(tester.getCenter(jump));
      await tester.tapAt(const Offset(400, 200));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _pumpFrames(tester, 3);
      expect(controller.snapshot!.tick, 0);
      final finder = mode == MovementControlMode.arrows
          ? find.byType(MoveButtons)
          : find.byType(MoveJoystick);
      final bounds = _globalRect(tester, finder);
      if (mode == MovementControlMode.arrows) {
        await tester.tapAt(bounds.center);
        await tester.pump();
        expect(controller.status.phase, RunnerPlaytestPhase.ready);
      }
      final point = mode == MovementControlMode.arrows
          ? Offset(bounds.right - 16, bounds.center.dy)
          : bounds.center;
      controller.setPresentationBlocked(true);
      await tester.tapAt(point);
      await tester.pump();
      expect(controller.status.phase, RunnerPlaytestPhase.ready);
      controller.setPresentationBlocked(false);
      controller.releaseFocus();
      await tester.pump();
      final x = controller.snapshot!.playerEntity!.pos.x;
      final gesture = await tester.startGesture(point);
      expect(controller.status.phase, RunnerPlaytestPhase.running);
      await tester.pump();
      expect(find.byType(CampaignTutorialOverlay), findsNothing);
      if (mode != MovementControlMode.arrows) {
        await gesture.moveBy(const Offset(60, 0));
      }
      await _pumpFrames(tester, 18);
      expect(controller.snapshot!.playerEntity!.pos.x, greaterThan(x));
      await gesture.up();
      expect(controller.pause(), isTrue);
      await tester.pump();
      expect(controller.resume(), isTrue);
      await tester.pump();
      expect(find.byType(CampaignTutorialOverlay), findsNothing);
      expect(controller.restart(), isTrue);
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(find.byType(CampaignTutorialOverlay), findsOneWidget);
      expect(controller.snapshot!.tick, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets(
    'hidden HUD tutorial admits a movement key and retains its hold',
    (tester) async {
      final controller = RunnerPlaytestController();
      await _mountHost(
        tester,
        scenario: _campaignScenario(),
        controller: controller,
        onStop: () {},
        appearance: RunnerPlaytestAppearance(
          parallaxThemes: authoredParallaxThemesById,
          terrainMaterials: TerrainMaterialRegistry.byKey,
          tutorialSequences: [CampaignMovementTutorial.movementIntroduction()],
        ),
      );
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(
        find.text('Hold the left or right arrow key to start moving.'),
        findsOneWidget,
      );
      expect(find.byType(MoveButtons), findsNothing);
      final x = controller.snapshot!.playerEntity!.pos.x;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await _pumpFrames(tester, 18);
      expect(controller.status.phase, RunnerPlaytestPhase.running);
      expect(controller.snapshot!.playerEntity!.pos.x, greaterThan(x));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'mission device preview keeps game and HUD proportional across editor resizing',
    (tester) async {
      tester.view.physicalSize = const Size(1770, 797);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = RunnerPlaytestController();
      final reviewKey = GlobalKey();
      await _mountHost(
        tester,
        scenario: _campaignScenario(
          equippedLoadout: const EquippedLoadoutDef(
            mask: LoadoutSlotMask.all,
            abilityProjectileId: 'eloise.quick_shot',
          ),
        ),
        controller: controller,
        onStop: () {},
        presentation: RunnerPlaytestPresentation.mobile,
        reviewKey: reviewKey,
      );
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      controller.start();
      await tester.pump();
      await tester.pump();
      const device = RunnerPlaytestDevicePresets.defaultPhone;
      for (final (size, dpr) in [
        (const Size(1770, 797), 1.0),
        (const Size(1280, 800), 1.25),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpr;
        await tester.pump();
        final surface = _globalRect(
          tester,
          find.byType(RunnerDesktopInputAdapter),
        );
        final canvas = _globalRect(
          tester,
          find.byType(GameWidget<RunnerFlameGame>),
        );
        final logicalCanvas = tester.getSize(
          find.byType(GameWidget<RunnerFlameGame>),
        );
        expect(tester.getSize(find.byType(GameOverlay)), device.size);
        expect(
          tester.getSize(find.byType(RunnerDesktopInputAdapter)),
          device.size,
        );
        expect(
          surface.width / surface.height,
          closeTo(device.width / device.height, 1e-8),
        );
        expect(surface.left > 0 || surface.top > 0, isTrue);
        expect(_globalRect(tester, find.byType(GameOverlay)), surface);
        expect(canvas.left, lessThanOrEqualTo(surface.left));
        expect(canvas.top, lessThanOrEqualTo(surface.top));
        expect(canvas.right, greaterThanOrEqualTo(surface.right));
        expect(canvas.bottom, greaterThanOrEqualTo(surface.bottom));
        expect(canvas.width / canvas.height, closeTo(600 / 270, .0001));
        final hud = tester.widget<GameOverlay>(find.byType(GameOverlay));
        expect(hud.viewportMetrics!.viewW, logicalCanvas.width);
        expect(hud.viewportMetrics!.viewH, logicalCanvas.height);
        final zoom = surface.width / device.width;
        expect(
          (canvas.left - surface.left) / zoom,
          closeTo(hud.viewportMetrics!.offsetX, 1e-6),
        );
        expect(
          (canvas.top - surface.top) / zoom,
          closeTo(hud.viewportMetrics!.offsetY, 1e-6),
        );
        expect(
          MediaQuery.devicePixelRatioOf(
            tester.element(find.byType(GameOverlay)),
          ),
          device.devicePixelRatio,
        );
        // Cancel near the far edge of the scaled affordance. Mixing global
        // position with unscaled dimensions used to commit a shot here.
        final projectile = find.byWidgetPredicate(
          (w) => w is DirectionalActionButton && w.label == 'Projectile',
        );
        final mana = controller.snapshot!.hud.mana;
        final gesture = await tester.startGesture(tester.getCenter(projectile));
        await tester.pump();
        await tester.pump();
        final cancel = hud.aimCancelHitboxRect.value!;
        expect(cancel.width, closeTo(56 * zoom, 1e-6));
        final cancelPoint = Offset(cancel.right - 3 * zoom, cancel.center.dy);
        await gesture.moveTo(cancelPoint);
        await tester.pump();
        await gesture.up();
        await _pumpFrames(tester, 5);
        expect(controller.snapshot!.hud.mana, mana);
        expect(hud.projectileAimPreview.value.active, isFalse);
        final game = tester
            .widget<GameWidget<RunnerFlameGame>>(
              find.byType(GameWidget<RunnerFlameGame>),
            )
            .game!;
        final aims = <Offset>[];
        game.controller.addAppliedCommandFrameListener((frame) {
          if (frame.aimDirX != null) {
            aims.add(Offset(frame.aimDirX!, frame.aimDirY!));
          }
        });
        final snapshot = controller.snapshot!;
        final player = snapshot.playerEntity!;
        final camera = snapshot.camera;
        final renderedPlayer = Offset(
          (player.pos.x - camera.centerX + camera.viewWidth / 2)
                  .roundToDouble() *
              logicalCanvas.width /
              camera.viewWidth,
          (player.pos.y - camera.centerY + camera.viewHeight / 2)
                  .roundToDouble() *
              logicalCanvas.height /
              camera.viewHeight,
        );
        final gameBox = tester.renderObject<RenderBox>(
          find.byType(GameWidget<RunnerFlameGame>),
        );
        final target = gameBox.localToGlobal(
          renderedPlayer + const Offset(60, -60),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: target);
        await mouse.moveTo(target);
        await _pumpFrames(tester, 4);
        expect(aims, isNotEmpty);
        expect(aims.last.dx, closeTo(.70710678, .001));
        expect(aims.last.dy, closeTo(-.70710678, .001));
        await mouse.removePointer();
        if (dpr == 1) {
          await tester.runAsync(() async {
            final boundary =
                reviewKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('build/test/campaign_playtest_mobile.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
      }
      expect(controller.status.runtimeGeneration, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'whole-Level host uses authored identity, captured theme, and frozen restart',
    (tester) async {
      final focused = _scenario();
      final scenario = LevelPlaytestScenario(
        levelDefinition: LevelDefinition.authored(
          identity: AuthoredLevelIdentity('forest'),
          chunkPatternSource: focused.levelDefinition.chunkPatternSource,
          visualThemeId: 'draft_background',
          cameraCenterY: 121,
          groundTopY: focused.levelDefinition.groundTopY,
          assembly: focused.levelDefinition.assembly,
        ),
        terrainChunks: focused.terrainCatalog.chunksByKey.values,
        seed: 740,
        playerCharacter: focused.playerCharacter,
        equippedLoadout: focused.equippedLoadout,
      );
      final controller = RunnerPlaytestController();
      final images = _FixtureImages(fixtureImage);
      await _mountHost(
        tester,
        scenario: scenario,
        controller: controller,
        onStop: () {},
        imagesFactory: (_) => images,
        appearance: RunnerPlaytestAppearance(
          parallaxThemes: {
            'draft_background': const ParallaxTheme(
              backgroundLayers: [
                PixelParallaxLayerSpec(
                  assetPath: 'parallax/draft_background/layer_01.png',
                  parallaxFactor: .2,
                ),
              ],
              foregroundLayers: [],
            ),
          },
          terrainMaterials: TerrainMaterialRegistry.byKey,
        ),
      );
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      final initial = _snapshotRecord(controller.snapshot!);
      expect(
        controller.snapshot!.levelIdentity,
        AuthoredLevelIdentity('forest'),
      );
      expect(controller.snapshot!.visualThemeId, 'draft_background');
      expect(controller.start(), isTrue);
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.pause(), isTrue);
      expect(controller.restart(), isTrue);
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(_snapshotRecord(controller.snapshot!), initial);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'ready, input, pause, focus loss, restart, and stop are deterministic',
    (tester) async {
      final scenario = _scenario();
      final controller = RunnerPlaytestController();
      final imageCaches = <_FixtureImages>[];
      var stopCount = 0;
      await _mountHost(
        tester,
        scenario: scenario,
        controller: controller,
        imagesFactory: (_) {
          final images = _FixtureImages(fixtureImage);
          imageCaches.add(images);
          return images;
        },
        onStop: () => stopCount += 1,
      );
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);

      final initialRecord = _snapshotRecord(controller.snapshot!);
      expect(controller.status.runtimeGeneration, 1);
      expect(controller.snapshot!.tick, 0);
      expect(controller.start(), isTrue);
      expect(controller.start(), isFalse);
      await tester.pump();
      expect(controller.status.phase, RunnerPlaytestPhase.running);

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyD,
        physicalKey: PhysicalKeyboardKey.keyD,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.keyD,
        physicalKey: PhysicalKeyboardKey.keyD,
      );
      await tester.pump();
      expect(controller.snapshot!.tick, greaterThan(0));

      expect(controller.pause(), isTrue);
      expect(controller.pause(), isFalse);
      final pausedTick = controller.snapshot!.tick;
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.snapshot!.tick, pausedTick);
      expect(controller.resume(), isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.snapshot!.tick, greaterThan(pausedTick));

      expect(controller.releaseFocus(), isTrue);
      await tester.pump();
      expect(controller.status.phase, RunnerPlaytestPhase.paused);
      expect(controller.resume(), isTrue);
      await tester.pump();

      expect(controller.restart(), isTrue);
      expect(controller.status.runtimeGeneration, 2);
      await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
      expect(controller.snapshot!.tick, 0);
      expect(_snapshotRecord(controller.snapshot!), initialRecord);
      expect(imageCaches, hasLength(2));
      expect(imageCaches.first.clearCount, greaterThan(0));

      final gameWidget = tester.widget<GameWidget<RunnerFlameGame>>(
        find.byType(GameWidget<RunnerFlameGame>),
      );
      expect(gameWidget.game!.images, isNot(same(Flame.images)));
      expect(
        find.textContaining('PLAYTEST - NO REWARDS/REPLAY'),
        findsOneWidget,
      );

      expect(controller.stop(), isTrue);
      expect(controller.stop(), isFalse);
      await tester.pump();
      await tester.pump();
      expect(stopCount, 1);
      expect(controller.status.phase, RunnerPlaytestPhase.stopped);
      expect(controller.snapshot, isNull);
      expect(imageCaches.last.clearCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('game over stays backend-free and offers deterministic restart', (
    tester,
  ) async {
    final controller = RunnerPlaytestController();
    await _mountHost(
      tester,
      scenario: _scenario(),
      controller: controller,
      imagesFactory: (_) => _FixtureImages(fixtureImage),
      onStop: () {},
    );
    await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
    controller.start();
    await tester.pump();

    final gameWidget = tester.widget<GameWidget<RunnerFlameGame>>(
      find.byType(GameWidget<RunnerFlameGame>),
    );
    gameWidget.game!.controller.giveUp();
    await tester.pump();

    expect(controller.status.phase, RunnerPlaytestPhase.gameOver);
    expect(find.text('Playtest ended'), findsOneWidget);
    expect(
      find.text('No rewards, replay, or score were recorded.'),
      findsOneWidget,
    );
    expect(controller.restart(), isTrue);
    await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
    expect(controller.snapshot!.gameOver, isFalse);
    expect(controller.snapshot!.tick, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('asset failure is explicit, retryable, and stoppable once', (
    tester,
  ) async {
    final controller = RunnerPlaytestController();
    final imageCaches = <_FailingImages>[];
    final reportedErrors = <Object>[];
    var stopCount = 0;
    await _mountHost(
      tester,
      scenario: _scenario(),
      controller: controller,
      imagesFactory: (_) {
        final images = _FailingImages(fixtureImage);
        imageCaches.add(images);
        return images;
      },
      onStop: () => stopCount += 1,
    );
    await _pumpUntilPhase(
      tester,
      controller,
      RunnerPlaytestPhase.failed,
      reportedErrors: reportedErrors,
    );

    expect(controller.status.failureCode, 'runner_asset_missing');
    expect(controller.status.failureMessage, contains('fixture rejected'));
    expect(find.text('Playtest failed'), findsOneWidget);
    expect(imageCaches.single.failedLoadCount, 1);
    expect(reportedErrors, everyElement(isA<RunnerWorkspaceAssetException>()));
    final firstGeneration = controller.status.runtimeGeneration;

    expect(controller.restart(), isTrue);
    await _pumpUntilPhase(
      tester,
      controller,
      RunnerPlaytestPhase.failed,
      reportedErrors: reportedErrors,
    );
    expect(controller.status.runtimeGeneration, firstGeneration + 1);
    expect(imageCaches, hasLength(2));
    expect(imageCaches.last.failedLoadCount, 1);
    expect(controller.stop(), isTrue);
    await tester.pump();
    await tester.pump();
    expect(stopCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('widget disposal cancels runtime without implying host stop', (
    tester,
  ) async {
    final controller = RunnerPlaytestController();
    var stopCount = 0;
    await _mountHost(
      tester,
      scenario: _scenario(),
      controller: controller,
      imagesFactory: (_) => _FixtureImages(fixtureImage),
      onStop: () => stopCount += 1,
    );
    await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
    controller.start();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());

    expect(stopCount, 0);
    expect(controller.snapshot, isNull);
    expect(controller.pause(), isFalse);
    controller.dispose();
  });

  testWidgets('rapid restart and stop ignore every stale runtime callback', (
    tester,
  ) async {
    final controller = RunnerPlaytestController();
    var stopCount = 0;
    await _mountHost(
      tester,
      scenario: _scenario(),
      controller: controller,
      imagesFactory: (_) => _FixtureImages(fixtureImage),
      onStop: () => stopCount += 1,
    );

    expect(controller.restart(), isTrue);
    expect(controller.restart(), isTrue);
    expect(controller.status.runtimeGeneration, 3);
    await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
    expect(controller.status.runtimeGeneration, 3);
    expect(controller.snapshot!.tick, 0);

    expect(controller.restart(), isTrue);
    expect(controller.status.runtimeGeneration, 4);
    expect(controller.stop(), isTrue);
    expect(controller.restart(), isFalse);
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.status.phase, RunnerPlaytestPhase.stopped);
    expect(controller.status.runtimeGeneration, 4);
    expect(stopCount, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('resize and DPI changes preserve every host lifecycle command', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = RunnerPlaytestController();
    var stopCount = 0;
    await _mountHost(
      tester,
      scenario: _scenario(),
      controller: controller,
      imagesFactory: (_) => _FixtureImages(fixtureImage),
      onStop: () => stopCount += 1,
    );
    await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.25;
    await tester.pump();
    expect(controller.status.phase, RunnerPlaytestPhase.ready);
    expect(controller.start(), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    final tickBeforeResize = controller.snapshot!.tick;

    final adapter = find.byType(RunnerDesktopInputAdapter);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(adapter));
    await mouse.moveTo(tester.getCenter(adapter));
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyD,
      physicalKey: PhysicalKeyboardKey.keyD,
    );
    await tester.pump(const Duration(milliseconds: 100));

    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.5;
    await tester.pump(const Duration(milliseconds: 100));
    await mouse.moveTo(tester.getCenter(adapter) + const Offset(80, -40));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.status.phase, RunnerPlaytestPhase.running);
    expect(controller.snapshot!.tick, greaterThan(tickBeforeResize));

    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.keyD,
      physicalKey: PhysicalKeyboardKey.keyD,
    );
    expect(controller.pause(), isTrue);
    await tester.pump();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.25;
    await tester.pump();
    expect(controller.status.phase, RunnerPlaytestPhase.paused);
    expect(controller.restart(), isTrue);
    await _pumpUntilPhase(tester, controller, RunnerPlaytestPhase.ready);
    expect(controller.snapshot!.tick, 0);

    expect(controller.stop(), isTrue);
    await tester.pump();
    await tester.pump();
    expect(stopCount, 1);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

Future<void> _mountHost(
  WidgetTester tester, {
  required PlaytestScenario scenario,
  required RunnerPlaytestController controller,
  required VoidCallback onStop,
  AssetBundle? assetBundle,
  RunnerPlaytestImagesFactory? imagesFactory,
  RunnerPlaytestAppearance? appearance,
  RunnerPlaytestPresentation presentation = const RunnerPlaytestPresentation(),
  GlobalKey? reviewKey,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: createUiTheme(),
      home: Scaffold(
        body: RepaintBoundary(
          key: reviewKey,
          child: RunnerPlaytestHost(
            presentation: presentation,
            appearance:
                appearance ??
                RunnerPlaytestAppearance(
                  parallaxThemes: authoredParallaxThemesById,
                  terrainMaterials: TerrainMaterialRegistry.byKey,
                ),
            scenario: scenario,
            controller: controller,
            assetBundle: assetBundle,
            imagesFactory: imagesFactory,
            onStop: onStop,
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 17));
  }
}

Rect _globalRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

CampaignPlaytestScenario _campaignScenario({
  EquippedLoadoutDef? equippedLoadout,
}) {
  final field = trainingFieldDefinition;
  final flat = field.chunks.first;
  return CampaignPlaytestScenario(
    mission: CampaignMissionDefinition(
      id: 'hud_preview_fixture',
      route: FiniteChunkPatternSource([
        FiniteMissionChunk(
          id: 'first',
          sourceLevelId: 'training_field',
          tier: ChunkPatternTier.easy,
          pattern: ChunkPattern(
            name: flat.name,
            chunkKey: flat.chunkKey,
            spawnMarkers: const [],
          ),
        ),
      ]),
      terrainChunks: field.terrain.chunks,
      start: CampaignPoint(missionChunkId: 'first', x: 100, y: 224),
      exit: CampaignRegion(
        origin: CampaignPoint(missionChunkId: 'first', x: 570, y: 0),
        width: 30,
        height: 270,
      ),
      visualThemeId: field.visualThemeId,
    ),
    playerCharacter: PlayerCharacterRegistry.eloise,
    equippedLoadout: equippedLoadout,
    seed: 4401,
  );
}

Future<void> _pumpUntilPhase(
  WidgetTester tester,
  RunnerPlaytestController controller,
  RunnerPlaytestPhase phase, {
  List<Object>? reportedErrors,
}) async {
  // Terrain preparation crosses an isolate; simulated frame time cannot wait for it.
  final watch = Stopwatch()..start();
  while (watch.elapsed < const Duration(seconds: 30)) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    final reportedError = tester.takeException();
    if (reportedError != null) {
      if (reportedErrors == null) throw reportedError;
      reportedErrors.add(reportedError);
    }
    if (controller.status.phase == phase) {
      await tester.pump();
      return;
    }
  }
  fail(
    'Timed out waiting for ${phase.name}; '
    'current=${controller.status.phase.name} '
    'failure=${controller.status.failureCode}: '
    '${controller.status.failureMessage}',
  );
}

ChunkPlaytestScenario _scenario() {
  final level = LevelRegistry.byId(LevelId.forest);
  final listSource = switch (level.chunkPatternSource) {
    ChunkPatternListSource source => source,
    AssembledChunkPatternSource source => source.baseSource,
    _ => throw StateError('Forest test level must be list-backed.'),
  };
  final draftPattern = listSource.earlyPatterns.singleWhere(
    (pattern) => pattern.chunkKey == level.firstChunkKey,
  );
  final draftTerrain = stagedAuthoredTerrain.chunks.singleWhere(
    (chunk) => chunk.chunkKey == draftPattern.chunkKey,
  );
  return ChunkPlaytestScenario(
    terrainChunks: stagedAuthoredTerrain.chunks.where(
      (chunk) => chunk.levelId == 'forest',
    ),
    levelDefinition: level,
    visualThemeId: level.visualThemeId ?? 'forest',
    seed: 4401,
    draftPattern: draftPattern,
    draftTerrain: draftTerrain,
    playerCharacter: PlayerCharacterRegistry.eloise,
    equippedLoadout: const EquippedLoadoutDef(),
  );
}

String _snapshotRecord(GameStateSnapshot snapshot) => <Object?>[
  snapshot.tick,
  snapshot.runId,
  snapshot.seed,
  snapshot.levelIdentity,
  snapshot.visualThemeId,
  snapshot.distance,
  snapshot.camera.centerX,
  snapshot.camera.centerY,
  snapshot.hud.hp,
  snapshot.hud.mana,
  snapshot.hud.stamina,
  for (final entity in snapshot.entities)
    '${entity.id}|${entity.kind.name}|${entity.pos.x}|${entity.pos.y}|'
        '${entity.grounded}|${entity.facing.name}|${entity.anim.name}',
].join('\n');

final class _FailingImages extends Images {
  _FailingImages(this.image);

  final ui.Image image;
  int failedLoadCount = 0;

  @override
  Future<ui.Image> load(String fileName, {String? key, String? package}) async {
    if (fileName.endsWith('entities/player/idle.png')) {
      failedLoadCount += 1;
      await Future<void>.delayed(Duration.zero);
      throw RunnerWorkspaceAssetException(
        code: 'runner_asset_missing',
        assetKey: fileName,
        message: 'fixture rejected $fileName',
      );
    }
    return image;
  }

  @override
  void clearCache() {}
}

final class _FixtureImages extends Images {
  _FixtureImages(this.image);

  final ui.Image image;
  int clearCount = 0;

  @override
  Future<ui.Image> load(
    String fileName, {
    String? key,
    String? package,
  }) async => image;

  @override
  void clearCache() {
    clearCount += 1;
  }
}

Future<void> _capturePreview(WidgetTester tester, GlobalKey key, String name) =>
    tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/test/$name');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
