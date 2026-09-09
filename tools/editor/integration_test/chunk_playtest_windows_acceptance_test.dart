import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:rpg_runner/playtest.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_authoring_workspace.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_page.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_navigation.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final isLevel in [false, true]) {
    final scope = isLevel ? 'Level' : 'Chunk';
    testWidgets('accepts the native Windows $scope Play lifecycle', (
      tester,
    ) async {
      expect(Platform.isWindows, isTrue);
      final workspaceRoot = p.normalize(
        p.absolute(p.join(Directory.current.path, '..', '..')),
      );
      final filesBefore = _sourceHashes(workspaceRoot);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: <AuthoringDomainPlugin>[
            if (isLevel) LevelDomainPlugin() else ChunkDomainPlugin(),
          ],
        ),
        initialPluginId: isLevel
            ? LevelDomainPlugin.pluginId
            : ChunkDomainPlugin.pluginId,
        initialWorkspacePath: workspaceRoot,
      );
      await session.loadWorkspace();
      addTearDown(session.dispose);
      final boundary = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: isLevel
                  ? LevelCreatorPage(
                      controller: session,
                      viewStore: null,
                      initialReturnContext: const LevelCreatorReturnContext(
                        levelId: 'forest',
                        previewSeed: 7531,
                      ),
                    )
                  : ChunkCreatorPage(controller: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final documentBefore = session.document;
      if (isLevel) await _captureLevel(boundary, workspaceRoot, 'edit');
      final workspaceFinder = find.byType(
        isLevel ? LevelCreatorPage : ChunkAuthoringWorkspace,
        skipOffstage: false,
      );
      final workspaceBefore = tester.state(workspaceFinder);

      final readyWatch = Stopwatch()..start();
      await tester.tap(
        find.byKey(
          ValueKey<String>(
            isLevel ? 'level_play_button' : 'chunk_playtest_button',
          ),
        ),
      );
      await tester.pump();
      await _pumpUntilHostPhase(tester, RunnerPlaytestPhase.ready);
      readyWatch.stop();
      if (isLevel) await _captureLevel(boundary, workspaceRoot, 'ready');
      final host = tester.widget<RunnerPlaytestHost>(
        find.byType(RunnerPlaytestHost),
      );
      expect(
        host.scenario,
        isLevel ? isA<LevelPlaytestScenario>() : isA<ChunkPlaytestScenario>(),
      );
      final controller = host.controller;
      final handler = tester.state(
        find.byType(isLevel ? LevelCreatorPage : ChunkCreatorPage),
      ) as EditorPagePlaytestHandler;
      expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.enter), isTrue);
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.status.phase, RunnerPlaytestPhase.running);

      final initialX = controller.snapshot!.playerEntity!.pos.x;
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyD,
        physicalKey: PhysicalKeyboardKey.keyD,
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.arrowRight,
        physicalKey: PhysicalKeyboardKey.arrowRight,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.keyD,
        physicalKey: PhysicalKeyboardKey.keyD,
      );
      await tester.pump(const Duration(milliseconds: 250));
      final rolloverX = controller.snapshot!.playerEntity!.pos.x;
      expect(rolloverX, greaterThan(initialX));
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.arrowRight,
        physicalKey: PhysicalKeyboardKey.arrowRight,
      );

      final hostCenter = tester.getCenter(find.byType(RunnerPlaytestHost));
      await _clickMouse(
        tester,
        position: hostCenter + const Offset(120, -20),
        buttons: kPrimaryMouseButton,
        pointer: 10,
      );
      await _clickMouse(
        tester,
        position: hostCenter + const Offset(120, -20),
        buttons: kSecondaryMouseButton,
        pointer: 11,
      );

      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.5;
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.status.phase, RunnerPlaytestPhase.running);
      final resizedHost = find.byType(RunnerPlaytestHost);
      final resizedCenter = tester.getCenter(resizedHost);
      final resizedTopLeft = tester.getTopLeft(resizedHost);
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 12,
      );
      await mouse.addPointer(location: resizedCenter);
      await mouse.moveTo(resizedCenter + const Offset(160, -60));
      await mouse.moveTo(resizedTopLeft + const Offset(2, 2));
      await mouse.moveTo(resizedCenter - const Offset(160, -60));
      await mouse.removePointer();
      await tester.pump();
      expect(tester.takeException(), isNull);

      handler.handlePlaytestAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();
      expect(controller.status.phase, RunnerPlaytestPhase.paused);
      expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.keyP), isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.status.phase, RunnerPlaytestPhase.running);

      expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.f6), isTrue);
      await _pumpUntilHostPhase(tester, RunnerPlaytestPhase.ready);
      expect(controller.snapshot!.tick, 0);
      expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.enter), isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.status.phase, RunnerPlaytestPhase.running);
      expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.escape), isTrue);
      await _pumpUntilHostRemoved(tester);

      expect(session.document, same(documentBefore));
      expect(tester.state(workspaceFinder), same(workspaceBefore));
      expect(_sourceHashes(workspaceRoot), filesBefore);
      expect(tester.takeException(), isNull);

      final report = <String, Object>{
        'acceptance': 'pass',
        'scope': scope,
        'nativeWindowsEngine': Platform.isWindows,
        'initialPhysicalSize': <int>[1280, 800],
        'initialDevicePixelRatio': 1,
        'scaledPhysicalSize': <int>[1920, 1200],
        'scaledDevicePixelRatio': 1.5,
        'prepareAndHostReadyMicros': readyWatch.elapsedMicroseconds,
        'keyboardRolloverDistance': rolloverX - initialX,
        'mouseButtons': <String>['primary', 'secondary'],
        'lifecyclePause': 'inactive -> paused -> explicit resume',
        'restartTick': 0,
        'stopRestoredEditState': true,
        'sourceHashesStable': true,
        'gameOverEvidence':
            'test/playtest/runner_chunk_playtest_host_test.dart',
      };

      binding.reportData = {...?binding.reportData, scope: report};
      debugPrint('AUTHORED_PLAYTEST_NATIVE ${jsonEncode(report)}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}

Future<void> _clickMouse(
  WidgetTester tester, {
  required Offset position,
  required int buttons,
  required int pointer,
}) async {
  final mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: pointer,
    buttons: buttons,
  );
  await mouse.addPointer(location: position);
  await mouse.down(position);
  await tester.pump(const Duration(milliseconds: 75));
  await mouse.up();
  await mouse.removePointer();
  await tester.pump(const Duration(milliseconds: 75));
}

Future<void> _pumpUntilHostPhase(
  WidgetTester tester,
  RunnerPlaytestPhase phase,
) async {
  for (var attempt = 0; attempt < 600; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 25));
    final hostFinder = find.byType(RunnerPlaytestHost);
    if (hostFinder.evaluate().isEmpty) continue;
    final controller = tester.widget<RunnerPlaytestHost>(hostFinder).controller;
    if (controller.status.phase == RunnerPlaytestPhase.failed) {
      fail(
        'Native host failed: ${controller.status.failureCode}: '
        '${controller.status.failureMessage}',
      );
    }
    if (controller.status.phase == phase) return;
  }
  fail('Timed out waiting for native host phase ${phase.name}.');
}

Future<void> _pumpUntilHostRemoved(WidgetTester tester) async {
  for (var attempt = 0; attempt < 240; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 25));
    if (find.byType(RunnerPlaytestHost).evaluate().isEmpty) {
      await tester.pump();
      await tester.pump();
      return;
    }
  }
  fail('Timed out waiting for the native host to return to Edit.');
}

Map<String, String> _sourceHashes(String workspaceRoot) {
  const paths = <String>[
    'assets/authoring/level/prefab_defs.json',
    'assets/authoring/level/tile_defs.json',
    'assets/authoring/level/level_defs.json',
    'assets/authoring/level/parallax_defs.json',
    'assets/authoring/level/terrain_material_defs.json',
    'packages/runner_core/lib/track/authored_chunk_patterns.dart',
    'packages/runner_core/lib/levels/level_id.dart',
    'packages/runner_core/lib/levels/level_registry.dart',
    'packages/runner_core/lib/track/staged_authored_terrain.dart',
    'lib/ui/levels/generated_level_ui_metadata.dart',
    'lib/game/themes/authored_parallax_themes.dart',
    'lib/game/themes/authored_terrain_materials.dart',
  ];
  return <String, String>{
    for (final file in Directory(
      p.join(workspaceRoot, 'assets/authoring/level/chunks'),
    ).listSync(recursive: true).whereType<File>())
      p.relative(file.path, from: workspaceRoot): sha256
          .convert(file.readAsBytesSync())
          .toString(),
    for (final path in paths)
      path: sha256
          .convert(File(p.join(workspaceRoot, path)).readAsBytesSync())
          .toString(),
  };
}

Future<void> _captureLevel(
  GlobalKey boundary,
  String root,
  String state,
) async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final frame = await render.toImage(pixelRatio: 1);
  try {
    final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      p.join(root, '.tmp', 'level-native-acceptance', '$state.png'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    frame.dispose();
  }
}
