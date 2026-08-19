import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
import 'package:runner_editor/src/session/editor_session_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accepts the native Windows Chunk Play lifecycle', (
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
        plugins: <AuthoringDomainPlugin>[ChunkDomainPlugin()],
      ),
      initialPluginId: ChunkDomainPlugin.pluginId,
      initialWorkspacePath: workspaceRoot,
    );
    await session.loadWorkspace();
    addTearDown(session.dispose);
    final documentBefore = session.document;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ChunkCreatorPage(
            controller: session,
            playtestPlatformSupported: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final workspaceFinder = find.byType(
      ChunkAuthoringWorkspace,
      skipOffstage: false,
    );
    final workspaceBefore = tester.state<ChunkAuthoringWorkspaceState>(
      workspaceFinder,
    );

    final readyWatch = Stopwatch()..start();
    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_playtest_button')),
    );
    await tester.pump();
    await _pumpUntilHostPhase(tester, RunnerChunkPlaytestPhase.ready);
    readyWatch.stop();
    final host = tester.widget<RunnerChunkPlaytestHost>(
      find.byType(RunnerChunkPlaytestHost),
    );
    final controller = host.controller;
    final handler =
        tester.state(find.byType(ChunkCreatorPage))
            as EditorPagePlaytestHandler;
    expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.enter), isTrue);
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.status.phase, RunnerChunkPlaytestPhase.running);

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

    final hostCenter = tester.getCenter(find.byType(RunnerChunkPlaytestHost));
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
    expect(controller.status.phase, RunnerChunkPlaytestPhase.running);
    final resizedHost = find.byType(RunnerChunkPlaytestHost);
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
    expect(controller.status.phase, RunnerChunkPlaytestPhase.paused);
    expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.keyP), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.status.phase, RunnerChunkPlaytestPhase.running);

    expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.f6), isTrue);
    await _pumpUntilHostPhase(tester, RunnerChunkPlaytestPhase.ready);
    expect(controller.snapshot!.tick, 0);
    expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.enter), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.status.phase, RunnerChunkPlaytestPhase.running);
    expect(handler.handlePlaytestShortcut(LogicalKeyboardKey.escape), isTrue);
    await _pumpUntilHostRemoved(tester);

    expect(session.document, same(documentBefore));
    expect(
      tester.state<ChunkAuthoringWorkspaceState>(workspaceFinder),
      same(workspaceBefore),
    );
    expect(_sourceHashes(workspaceRoot), filesBefore);
    expect(tester.takeException(), isNull);

    binding.reportData = <String, Object>{
      'acceptance': 'pass',
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
      'gameOverEvidence': 'test/playtest/runner_chunk_playtest_host_test.dart',
    };

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
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
  RunnerChunkPlaytestPhase phase,
) async {
  for (var attempt = 0; attempt < 600; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 25));
    final hostFinder = find.byType(RunnerChunkPlaytestHost);
    if (hostFinder.evaluate().isEmpty) continue;
    final controller = tester
        .widget<RunnerChunkPlaytestHost>(hostFinder)
        .controller;
    if (controller.status.phase == RunnerChunkPlaytestPhase.failed) {
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
    if (find.byType(RunnerChunkPlaytestHost).evaluate().isEmpty) {
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
    'assets/authoring/level/chunks/forest/forest_early_00.json',
    'packages/runner_core/lib/track/authored_chunk_patterns.dart',
    'packages/runner_core/lib/track/staged_authored_terrain.dart',
    'lib/game/themes/authored_parallax_themes.dart',
    'lib/game/themes/authored_terrain_materials.dart',
  ];
  return <String, String>{
    for (final path in paths)
      path: sha256
          .convert(File(p.join(workspaceRoot, path)).readAsBytesSync())
          .toString(),
  };
}
