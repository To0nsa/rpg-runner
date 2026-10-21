import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:rpg_runner/runner.dart';
import 'package:rpg_runner/ui/input/desktop/runner_desktop_input_adapter.dart';
import 'package:rpg_runner/ui/run/runner_run_session.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

/// Exercises the actual Windows engine with synthetic key/pointer/lifecycle
/// events. This is reproducible engine coverage, not physical-device acceptance.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'product desktop controls survive native Windows lifecycle and resize',
    (tester) async {
      expect(Platform.isWindows, isTrue);
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      late RunnerRunSession session;
      final frames = <ReplayCommandFrameV1>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [UiTokens.standard]),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: RunnerGameWidget(
                runSessionId: 'desktop-engine-smoke',
                runId: 1,
                seed: 42,
                levelId: LevelId.field,
                isDeveloperPractice: true,
                sessionFactory: (descriptor) {
                  session = RunnerRunSession(descriptor: descriptor);
                  session.controller.addAppliedCommandFrameListener(frames.add);
                  return session;
                },
              ),
            ),
          ),
        ),
      );
      await _until(tester, () => session.isReady);
      expect(find.byType(RunnerDesktopInputAdapter), findsOneWidget);
      await _capture(boundary, 'ready');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 50));
      expect(session.controller.snapshot.paused, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 100));
      expect(frames.any((frame) => frame.moveAxis == 1), isTrue);
      expect(frames.any((frame) => frame.jumpPressed), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(const Offset(800, 320));
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(frames.any((frame) => frame.strikePressed), isTrue);
      final ranged = await tester.createGesture(
        pointer: 2,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await ranged.down(const Offset(800, 320));
      await ranged.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(frames.any((frame) => frame.projectilePressed), isTrue);
      await _capture(boundary, 'running');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(session.controller.snapshot.paused, isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      frames.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        frames.every(
          (frame) => frame.pressedMask == 0 && frame.moveAxis == null,
        ),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(session.controller.snapshot.paused, isTrue);
      tester.view.physicalSize = const Size(1200, 780);
      tester.view.devicePixelRatio = 1.5;
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.moveTo(const Offset(600, 260));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump(const Duration(milliseconds: 50));
      expect(frames.last.aimDirX, isNotNull);
      expect(frames.any((frame) => frame.spellPressed), isTrue);
      await _capture(boundary, 'resized');
      final input = tester
          .widget<RunnerDesktopInputAdapter>(
            find.byType(RunnerDesktopInputAdapter),
          )
          .controller;
      input.releaseFocus();
      await tester.pump();
      expect(session.controller.snapshot.paused, isTrue);
      await mouse.removePointer();
      await ranged.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
      binding.reportData = {
        'desktopControls': 'passed',
        'events': 'synthetic',
        'sizes': ['1280x720 @1', '1200x780 @1.5'],
      };
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 1200 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
  }
  expect(ready(), isTrue);
  await tester.pump();
}

Future<void> _capture(GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage();
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final directory = Directory('build/desktop_controls_validation/screenshots')
      ..createSync(recursive: true);
    File('${directory.path}/$name.png')
        .writeAsBytesSync(bytes.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}
