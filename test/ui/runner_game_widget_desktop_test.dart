import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:rpg_runner/game/replay/run_recorder.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/controls/runner_controls_overlay_radial.dart';
import 'package:rpg_runner/ui/hud/game/desktop_controls_overlay.dart';
import 'package:rpg_runner/ui/input/desktop/runner_desktop_input_adapter.dart';
import 'package:rpg_runner/ui/input/runner_control_scheme.dart';
import 'package:rpg_runner/ui/run/runner_run_session.dart';
import 'package:rpg_runner/ui/runner_game_widget.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets(
    'desktop game over and restart replace input without held sources',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState.developer(
        store: SharedPrefsDeveloperProfileStore(),
      );
      addTearDown(state.dispose);
      await state.bootstrap();
      final harness = _Harness();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: _app(
            harness,
            RunnerControlScheme.desktop,
            isDeveloperPractice: true,
          ),
        ),
      );
      await _until(tester, () => harness.session.isReady);
      await _start(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await _advance(tester);
      final previous = harness.session;
      final oldInput = _adapter(tester);
      previous.controller.giveUp();
      await tester.pump();
      final endTick = previous.controller.tick;
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _advance(tester);
      expect(previous.controller.tick, endTick);
      expect(previous.controller.snapshot.gameOver, isTrue);
      if (find.text('Collect Score').evaluate().isNotEmpty) {
        await tester.tap(find.text('Collect Score'));
        await tester.pump();
        if (find.text('Skip').evaluate().isNotEmpty) {
          await tester.tap(find.text('Skip'));
          await tester.pump();
        }
      }
      await tester.tap(find.text('Restart'));
      await _until(
        tester,
        () => !identical(harness.session, previous) && harness.session.isReady,
      );
      expect(identical(oldInput, _adapter(tester)), isFalse);
      harness.session.controller.addAppliedCommandFrameListener(
        harness.recorder.frames.add,
      );
      await _start(tester);
      expect(
        harness.recorder.frames.every(
          (frame) => frame.moveAxis == null && frame.pressedMask == 0,
        ),
        isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await _advance(tester);
      expect(harness.recorder.frames.last.moveAxis, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await _unmount(tester);
    },
  );

  testWidgets(
    'automatic desktop starts on Enter and records physical controls',
    (tester) async {
      final harness = await _mount(
        tester,
        scheme: RunnerControlScheme.automatic,
      );
      expect(find.byType(DesktopControlsOverlay), findsOneWidget);
      expect(find.byType(RunnerControlsOverlay), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(harness.session.controller.tick, 0);
      await _start(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _advance(tester);
      expect(
        harness.recorder.frames.any((frame) => frame.moveAxis == 1),
        isTrue,
      );
      expect(harness.recorder.frames.any((frame) => frame.jumpPressed), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await _advance(tester);
      expect(harness.recorder.frames.last.moveAxis, isNull);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await _advance(tester);
      expect(harness.recorder.frames.last.moveAxis, -1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await _advance(tester);
      final mask = harness.recorder.frames.fold<int>(
        0,
        (value, frame) => value | frame.pressedMask,
      );
      expect(mask, ReplayCommandFrameV1.knownPressedMask);
      await _unmount(tester);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );

  testWidgets(
    'mouse aim and attacks reach the run while HUD clicks stay isolated',
    (tester) async {
      final harness = await _mount(tester);
      await _start(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(600, 300));
      await mouse.down(const Offset(600, 300));
      await mouse.up();
      await _advance(tester);
      expect(
        harness.recorder.frames.any((frame) => frame.strikePressed),
        isTrue,
      );
      expect(
        harness.recorder.frames.any((frame) => (frame.aimDirX ?? 0) > 0),
        isTrue,
      );
      final projectile = await tester.createGesture(
        pointer: 2,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await projectile.down(const Offset(600, 300));
      await projectile.up();
      await _advance(tester);
      expect(
        harness.recorder.frames.any((frame) => frame.projectilePressed),
        isTrue,
      );
      harness.recorder.frames.clear();
      await mouse.down(tester.getCenter(find.text('LMB / J')));
      await mouse.up();
      await _advance(tester);
      expect(
        harness.recorder.frames.every((frame) => frame.pressedMask == 0),
        isTrue,
      );
      await mouse.down(tester.getCenter(find.byTooltip('Pause')));
      await mouse.up();
      await tester.pump();
      expect(harness.session.controller.snapshot.paused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _advance(tester);
      expect(harness.session.controller.snapshot.paused, isFalse);
      expect(
        harness.recorder.frames.every((frame) => frame.pressedMask == 0),
        isTrue,
      );
      await mouse.removePointer();
      await projectile.removePointer();
      await _unmount(tester);
    },
  );

  testWidgets(
    'pause and deactivation cancel queued edges and require fresh input',
    (tester) async {
      final harness = await _mount(tester);
      await _start(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await _advance(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      final pausedTick = harness.session.controller.tick;
      expect(harness.session.controller.snapshot.paused, isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      harness.recorder.frames.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _advance(tester);
      expect(harness.session.controller.tick, greaterThan(pausedTick));
      expect(
        harness.recorder.frames.every(
          (frame) => frame.pressedMask == 0 && frame.moveAxis == null,
        ),
        isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(harness.session.controller.snapshot.paused, isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      harness.recorder.frames.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await _advance(tester);
      expect(harness.session.controller.snapshot.paused, isFalse);
      expect(
        harness.recorder.frames.every(
          (frame) => frame.pressedMask == 0 && frame.moveAxis == null,
        ),
        isTrue,
      );
      await _unmount(tester);
    },
  );

  testWidgets('focus loss pauses and clicking the surface does not resume', (
    tester,
  ) async {
    final harness = await _mount(tester);
    await _start(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await _advance(tester);
    _adapter(tester).releaseFocus();
    await tester.pump();
    expect(harness.session.controller.snapshot.paused, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(const Offset(600, 300));
    await mouse.up();
    await tester.pump();
    expect(harness.session.controller.snapshot.paused, isTrue);
    await tester.tap(find.byTooltip('Play'));
    await _advance(tester);
    expect(harness.session.controller.snapshot.paused, isFalse);
    expect(harness.recorder.frames.last.moveAxis, isNull);
    await mouse.removePointer();
    await _unmount(tester);
  });

  testWidgets('switching controls keeps the session and cancels held input', (
    tester,
  ) async {
    final harness = _Harness();
    final scheme = ValueNotifier(RunnerControlScheme.desktop);
    addTearDown(scheme.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: scheme,
        builder: (_, value, _) => _app(harness, value),
      ),
    );
    await _until(tester, () => harness.session.isReady);
    await _start(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await _advance(tester);
    final session = harness.session;
    scheme.value = RunnerControlScheme.touch;
    await tester.pump();
    expect(identical(harness.session, session), isTrue);
    expect(session.controller.snapshot.paused, isTrue);
    expect(find.byType(RunnerControlsOverlay), findsOneWidget);
    expect(find.byType(RunnerDesktopInputAdapter), findsNothing);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    await tester.tap(find.byTooltip('Play'));
    await _advance(tester);
    expect(session.controller.snapshot.paused, isFalse);
    expect(harness.recorder.frames.last.moveAxis, isNull);
    scheme.value = RunnerControlScheme.desktop;
    await tester.pump();
    expect(session.controller.snapshot.paused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _advance(tester);
    expect(session.controller.snapshot.paused, isFalse);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets(
    'recorder readiness gates keyboard start and startup retry replaces input',
    (tester) async {
      final pending = Completer<RunRecorder>();
      final harness = _Harness();
      var attempts = 0;
      await tester.pumpWidget(
        _app(
          harness,
          RunnerControlScheme.desktop,
          createRecorder: (_) {
            attempts++;
            return attempts == 1
                ? pending.future
                : Future.value(harness.recorder);
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(harness.session.controller.tick, 0);
      pending.completeError(StateError('test recording failure'));
      await _until(tester, () => find.text('Retry').evaluate().isNotEmpty);
      final oldInput = _adapter(tester);
      await tester.tap(find.text('Retry'));
      await _until(tester, () => harness.session.isReady);
      expect(identical(oldInput, _adapter(tester)), isFalse);
      expect(harness.session.controller.tick, 0);
      await _start(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await _advance(tester);
      expect(harness.recorder.frames.last.moveAxis, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await _unmount(tester);
    },
  );
}

RunnerDesktopInputController _adapter(WidgetTester tester) => tester
    .widget<RunnerDesktopInputAdapter>(find.byType(RunnerDesktopInputAdapter))
    .controller;

class _Harness {
  late RunnerRunSession session;
  final recorder = _Recorder();
}

Widget _app(
  _Harness harness,
  RunnerControlScheme scheme, {
  Future<RunRecorder> Function(RunRecorderHeader)? createRecorder,
  bool isDeveloperPractice = false,
}) => MaterialApp(
  theme: ThemeData(useMaterial3: true, extensions: [UiTokens.standard]),
  home: Scaffold(
    body: RunnerGameWidget(
      runSessionId: 'desktop-test',
      runId: 1,
      seed: 42,
      levelId: LevelId.field,
      controlScheme: scheme,
      isDeveloperPractice: isDeveloperPractice,
      sessionFactory: (RunStartDescriptor descriptor) =>
          harness.session = RunnerRunSession(
            descriptor: descriptor,
            createRecorder: createRecorder ?? (_) async => harness.recorder,
          ),
    ),
  ),
);

Future<_Harness> _mount(
  WidgetTester tester, {
  RunnerControlScheme scheme = RunnerControlScheme.desktop,
}) async {
  final harness = _Harness();
  await tester.pumpWidget(_app(harness, scheme));
  await _until(tester, () => harness.session.isReady);
  return harness;
}

Future<void> _start(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await _advance(tester);
  expect(find.text('Click or press Enter to start'), findsNothing);
}

Future<void> _advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 800 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    expect(tester.takeException(), isNull);
  }
  expect(ready(), isTrue);
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

class _Recorder implements RunRecorder {
  final frames = <ReplayCommandFrameV1>[];
  @override
  void appendFrame(ReplayCommandFrameV1 frame) => frames.add(frame);
  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
