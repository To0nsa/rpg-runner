import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:rpg_runner/ui/input/desktop/runner_desktop_input_adapter.dart';

void main() {
  late ui.Image fixtureImage;

  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const Color(0x00000000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    fixtureImage = await picture.toImage(2048, 2048);
    picture.dispose();
  });

  tearDownAll(() => fixtureImage.dispose());

  testWidgets(
    'ready, input, pause, focus loss, restart, and stop are deterministic',
    (tester) async {
      final scenario = _scenario();
      final controller = RunnerChunkPlaytestController();
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
      await _pumpUntilPhase(tester, controller, RunnerChunkPlaytestPhase.ready);

      final initialRecord = _snapshotRecord(controller.snapshot!);
      expect(controller.status.runtimeGeneration, 1);
      expect(controller.snapshot!.tick, 0);
      expect(controller.start(), isTrue);
      expect(controller.start(), isFalse);
      await tester.pump();
      expect(controller.status.phase, RunnerChunkPlaytestPhase.running);

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
      expect(controller.status.phase, RunnerChunkPlaytestPhase.paused);
      expect(controller.resume(), isTrue);
      await tester.pump();

      expect(controller.restart(), isTrue);
      expect(controller.status.runtimeGeneration, 2);
      await _pumpUntilPhase(tester, controller, RunnerChunkPlaytestPhase.ready);
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
      expect(controller.status.phase, RunnerChunkPlaytestPhase.stopped);
      expect(controller.snapshot, isNull);
      expect(imageCaches.last.clearCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('game over stays backend-free and offers deterministic restart', (
    tester,
  ) async {
    final controller = RunnerChunkPlaytestController();
    await _mountHost(
      tester,
      scenario: _scenario(),
      controller: controller,
      imagesFactory: (_) => _FixtureImages(fixtureImage),
      onStop: () {},
    );
    await _pumpUntilPhase(tester, controller, RunnerChunkPlaytestPhase.ready);
    controller.start();
    await tester.pump();

    final gameWidget = tester.widget<GameWidget<RunnerFlameGame>>(
      find.byType(GameWidget<RunnerFlameGame>),
    );
    gameWidget.game!.controller.giveUp();
    await tester.pump();

    expect(controller.status.phase, RunnerChunkPlaytestPhase.gameOver);
    expect(find.text('Playtest ended'), findsOneWidget);
    expect(
      find.text('No rewards, replay, or score were recorded.'),
      findsOneWidget,
    );
    expect(controller.restart(), isTrue);
    await _pumpUntilPhase(tester, controller, RunnerChunkPlaytestPhase.ready);
    expect(controller.snapshot!.gameOver, isFalse);
    expect(controller.snapshot!.tick, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('asset failure is explicit, retryable, and stoppable once', (
    tester,
  ) async {
    final controller = RunnerChunkPlaytestController();
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
      RunnerChunkPlaytestPhase.failed,
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
      RunnerChunkPlaytestPhase.failed,
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
    final controller = RunnerChunkPlaytestController();
    var stopCount = 0;
    await _mountHost(
      tester,
      scenario: _scenario(),
      controller: controller,
      imagesFactory: (_) => _FixtureImages(fixtureImage),
      onStop: () => stopCount += 1,
    );
    await _pumpUntilPhase(tester, controller, RunnerChunkPlaytestPhase.ready);
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
    final controller = RunnerChunkPlaytestController();
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
    await _pumpUntilPhase(tester, controller, RunnerChunkPlaytestPhase.ready);
    expect(controller.status.runtimeGeneration, 3);
    expect(controller.snapshot!.tick, 0);

    expect(controller.restart(), isTrue);
    expect(controller.status.runtimeGeneration, 4);
    expect(controller.stop(), isTrue);
    expect(controller.restart(), isFalse);
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.status.phase, RunnerChunkPlaytestPhase.stopped);
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
    final controller = RunnerChunkPlaytestController();
    var stopCount = 0;
    await _mountHost(
      tester,
      scenario: _scenario(),
      controller: controller,
      imagesFactory: (_) => _FixtureImages(fixtureImage),
      onStop: () => stopCount += 1,
    );
    await _pumpUntilPhase(tester, controller, RunnerChunkPlaytestPhase.ready);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.25;
    await tester.pump();
    expect(controller.status.phase, RunnerChunkPlaytestPhase.ready);
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
    expect(controller.status.phase, RunnerChunkPlaytestPhase.running);
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
    expect(controller.status.phase, RunnerChunkPlaytestPhase.paused);
    expect(controller.restart(), isTrue);
    await _pumpUntilPhase(tester, controller, RunnerChunkPlaytestPhase.ready);
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
  required ChunkPlaytestScenario scenario,
  required RunnerChunkPlaytestController controller,
  required VoidCallback onStop,
  AssetBundle? assetBundle,
  RunnerChunkPlaytestImagesFactory? imagesFactory,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RunnerChunkPlaytestHost(
          scenario: scenario,
          controller: controller,
          assetBundle: assetBundle,
          imagesFactory: imagesFactory,
          onStop: onStop,
        ),
      ),
    ),
  );
}

Future<void> _pumpUntilPhase(
  WidgetTester tester,
  RunnerChunkPlaytestController controller,
  RunnerChunkPlaytestPhase phase, {
  List<Object>? reportedErrors,
}) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
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
  const selectedKey = 'forest_early_00';
  final level = LevelRegistry.byId(LevelId.forest);
  final listSource = switch (level.chunkPatternSource) {
    ChunkPatternListSource source => source,
    AssembledChunkPatternSource source => source.baseSource,
    _ => throw StateError('Forest test level must be list-backed.'),
  };
  final draftPattern = <ChunkPattern>[
    ...listSource.earlyPatterns,
    ...listSource.easyPatterns,
    ...listSource.normalPatterns,
    ...listSource.hardPatterns,
  ].singleWhere((pattern) => pattern.chunkKey == selectedKey);
  final draftTerrain = stagedAuthoredTerrain.chunks.singleWhere(
    (chunk) => chunk.chunkKey == selectedKey,
  );
  return ChunkPlaytestScenario(
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
  snapshot.levelId,
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
  Future<ui.Image> load(String fileName, {String? key}) async {
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
  Future<ui.Image> load(String fileName, {String? key}) async => image;

  @override
  void clearCache() {
    clearCount += 1;
  }
}
