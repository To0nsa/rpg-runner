import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:rpg_runner/game/replay/run_recorder.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/run/runner_run_session.dart';
import 'package:rpg_runner/ui/runner_game_widget.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';

void main() {
  testWidgets(
    'developer Practice plays, ends and restarts without recording or submission',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState.developer(
        store: SharedPrefsDeveloperProfileStore(),
      );
      addTearDown(state.dispose);
      await state.bootstrap();
      final sessions = <RunnerRunSession>[];
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: _app((descriptor) {
            final session = RunnerRunSession(
              descriptor: descriptor,
              createRecorder: (_) async =>
                  throw StateError('Developer recording is forbidden'),
            );
            sessions.add(session);
            return session;
          }, isDeveloperPractice: true),
        ),
      );
      await _until(tester, () => sessions.single.isReady);
      await tester.tap(find.text('Tap to start'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(sessions.single.controller.tick, greaterThan(0));
      sessions.single.controller.giveUp();
      await tester.pump();
      expect(
        find.textContaining('No rewards or leaderboard entries'),
        findsOneWidget,
      );
      if (find.text('Collect Score').evaluate().isNotEmpty) {
        await tester.tap(find.text('Collect Score'));
        await tester.pump();
        if (find.text('Skip').evaluate().isNotEmpty) {
          await tester.tap(find.text('Skip'));
          await tester.pump();
        }
      }
      await tester.tap(find.text('Restart'));
      await _until(tester, () => sessions.length == 2 && sessions.last.isReady);
      expect(sessions.last.descriptor.isDeveloperPractice, isTrue);
      expect(
        sessions.last.descriptor.runSessionId,
        isNot(sessions.first.descriptor.runSessionId),
      );
      expect(sessions.every((session) => session.recorder == null), isTrue);
      expect(state.progression.gold, 0);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets('Start waits for recorder and records the first live tick', (
    tester,
  ) async {
    final pending = Completer<RunRecorder>();
    final recorder = _Recorder();
    late RunnerRunSession session;
    await tester.pumpWidget(
      _app((descriptor) {
        return session = RunnerRunSession(
          descriptor: descriptor,
          createRecorder: (_) => pending.future,
        );
      }),
    );
    await _until(
      tester,
      () => session.game.loadState.value.phase == RunLoadPhase.worldReady,
    );
    expect(find.text('Tap to start'), findsNothing);
    expect(find.text('Preparing replay recorder...'), findsOneWidget);
    expect(session.controller.tick, 0);
    pending.complete(recorder);
    await tester.pump();
    expect(find.text('Tap to start'), findsOneWidget);
    await tester.tap(find.text('Tap to start'));
    await tester.pump(const Duration(milliseconds: 40));
    expect(session.controller.tick, greaterThan(0));
    expect(recorder.frames.first.tick, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(recorder.closed, isTrue);
  });

  testWidgets('running game resumes after the full background lifecycle', (
    tester,
  ) async {
    final recorder = _Recorder();
    final session = await _readySession(tester, recorder);
    await tester.tap(find.text('Tap to start'));
    await tester.pump(const Duration(milliseconds: 40));
    session.input.setMoveAxis(1);
    await tester.pump(const Duration(milliseconds: 40));
    expect(recorder.frames.last.moveAxis, 1);

    final pausedTick = session.controller.tick;
    _background(tester);
    await tester.pump(const Duration(milliseconds: 40));
    expect(session.controller.snapshot.paused, isTrue);
    expect(session.controller.tick, pausedTick);

    _resume(tester);
    expect(session.controller.snapshot.paused, isFalse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(session.controller.tick, greaterThan(pausedTick));
    expect(recorder.frames.last.moveAxis, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('manual pause survives backgrounding and resume', (tester) async {
    final session = await _readySession(tester, _Recorder());
    await tester.tap(find.text('Tap to start'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    final pausedTick = session.controller.tick;

    _background(tester);
    _resume(tester);
    await tester.pump(const Duration(milliseconds: 40));
    expect(session.controller.snapshot.paused, isTrue);
    expect(session.controller.tick, pausedTick);
    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('backgrounding drops a jump queued before the next tick', (
    tester,
  ) async {
    final recorder = _Recorder();
    final session = await _readySession(tester, recorder);
    await tester.tap(find.text('Tap to start'));
    await tester.pump(const Duration(milliseconds: 40));
    final tickBeforePause = session.controller.tick;
    session.input.pressJump();
    _background(tester);
    _resume(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final resumedFrames = recorder.frames.where(
      (frame) => frame.tick > tickBeforePause,
    );
    expect(resumedFrames, isNotEmpty);
    expect(resumedFrames.every((frame) => !frame.jumpPressed), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('backgrounding before Start keeps the ready game at tick zero', (
    tester,
  ) async {
    final session = await _readySession(tester, _Recorder());
    _background(tester);
    _resume(tester);
    await tester.pump(const Duration(milliseconds: 40));
    expect(session.controller.snapshot.paused, isTrue);
    expect(session.controller.tick, 0);
    expect(find.text('Tap to start'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final failWorld in [true, false]) {
    testWidgets('startup failure retries at tick zero (world: $failWorld)', (
      tester,
    ) async {
      final sessions = <RunnerRunSession>[];
      final recorders = <_Recorder>[];
      await tester.pumpWidget(
        _app((descriptor) {
          final first = sessions.isEmpty;
          final recorder = _Recorder();
          recorders.add(recorder);
          final session = RunnerRunSession(
            descriptor: descriptor,
            imageCache: first && failWorld ? _FailingPlayerImages() : null,
            createRecorder: (_) async {
              if (first && !failWorld) throw StateError('storage unavailable');
              return recorder;
            },
          );
          sessions.add(session);
          return session;
        }),
      );
      await _until(tester, () => find.text('Retry').evaluate().isNotEmpty);
      expect(find.text('Tap to start'), findsNothing);
      expect(sessions.single.controller.tick, 0);
      expect(
        sessions.single.failure,
        failWorld ? RunStartupFailure.world : RunStartupFailure.recorder,
      );
      await tester.tap(find.text('Retry'));
      await _until(
        tester,
        () => find.text('Tap to start').evaluate().isNotEmpty,
      );
      expect(sessions.length, 2);
      expect(
        sessions.last.descriptor.runSessionId,
        sessions.first.descriptor.runSessionId,
      );
      expect(sessions.last.controller.tick, 0);
      if (failWorld) expect(recorders.first.closed, isTrue);
      expect(find.text('Retry'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(recorders.last.closed, isTrue);
    });
  }

  testWidgets('late world failure clears images decoded after exit', (
    tester,
  ) async {
    final images = _PendingFailureImages();
    await tester.pumpWidget(
      _app(
        (descriptor) => RunnerRunSession(
          descriptor: descriptor,
          imageCache: images,
          createRecorder: (_) async => _Recorder(),
        ),
      ),
    );
    await _until(tester, () => images.playerRequested);
    await tester.pumpWidget(const SizedBox.shrink());
    // A different registry can finish decoding after the host's first cleanup.
    final pictureRecorder = ui.PictureRecorder();
    ui.Canvas(pictureRecorder);
    final picture = pictureRecorder.endRecording();
    images.add('late-image', picture.toImageSync(1, 1));
    picture.dispose();
    expect(images.containsKey('late-image'), isTrue);
    images.finish.complete();
    await _until(tester, () => !images.containsKey('late-image'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exit while recorder is pending closes its late result', (
    tester,
  ) async {
    final pending = Completer<RunRecorder>();
    final recorder = _Recorder();
    await tester.pumpWidget(
      _app(
        (descriptor) => RunnerRunSession(
          descriptor: descriptor,
          createRecorder: (_) => pending.future,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(recorder);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(Duration.zero);
    expect(recorder.closed, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  RunnerRunSession Function(RunStartDescriptor) create, {
  bool isDeveloperPractice = false,
}) => MaterialApp(
  theme: ThemeData(useMaterial3: true, extensions: [UiTokens.standard]),
  home: Scaffold(
    body: RunnerGameWidget(
      runSessionId: 'startup-widget-test',
      runId: 1,
      seed: 42,
      levelId: LevelId.field,
      sessionFactory: create,
      isDeveloperPractice: isDeveloperPractice,
    ),
  ),
);

Future<RunnerRunSession> _readySession(
  WidgetTester tester,
  _Recorder recorder,
) async {
  late RunnerRunSession session;
  await tester.pumpWidget(
    _app((descriptor) {
      return session = RunnerRunSession(
        descriptor: descriptor,
        createRecorder: (_) async => recorder,
      );
    }),
  );
  await _until(tester, () => session.isReady);
  return session;
}

void _background(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _resume(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
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

class _Recorder implements RunRecorder {
  bool closed = false;
  final frames = <ReplayCommandFrameV1>[];

  @override
  void appendFrame(ReplayCommandFrameV1 frame) {
    if (closed) throw StateError('closed');
    frames.add(frame);
  }

  @override
  Future<void> close() async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingPlayerImages extends Images {
  @override
  Future<ui.Image> load(String fileName, {String? key, String? package}) {
    if (fileName.contains('entities/player/')) {
      return Future.error(StateError('missing player image'));
    }
    return super.load(fileName, key: key, package: package);
  }
}

class _PendingFailureImages extends Images {
  final finish = Completer<void>();
  bool playerRequested = false;

  @override
  Future<ui.Image> load(String fileName, {String? key, String? package}) {
    if (fileName.contains('entities/player/')) {
      playerRequested = true;
      return finish.future.then((_) => throw StateError('late load failure'));
    }
    return super.load(fileName, key: key, package: package);
  }
}
