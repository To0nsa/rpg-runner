import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:rpg_runner/game/replay/run_recorder.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/run/runner_run_session.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final worldFirst in [true, false]) {
    test(
      'readiness awaits both dependencies (world first: $worldFirst)',
      () async {
        final pending = Completer<RunRecorder>();
        final recorder = _Recorder();
        final session = RunnerRunSession(
          descriptor: _descriptor,
          createRecorder: (_) => pending.future,
        );
        addTearDown(session.dispose);
        if (worldFirst) {
          _readyWorld(session);
        } else {
          pending.complete(recorder);
          await Future<void>.delayed(Duration.zero);
        }
        expect(session.isReady, isFalse);
        expect(session.controller.snapshot.paused, isTrue);
        expect(session.controller.tick, 0);
        if (worldFirst) {
          pending.complete(recorder);
        } else {
          _readyWorld(session);
        }
        await Future<void>.delayed(Duration.zero);
        expect(session.isReady, isTrue);
        expect(session.controller.snapshot.paused, isTrue);
        await session.stop();
        expect(session.isReady, isFalse);
        expect(recorder.closeCalls, 1);
      },
    );
  }

  test(
    'host mounting failure revokes readiness and stopped attempts ignore it',
    () async {
      final session = RunnerRunSession(
        descriptor: _descriptor,
        createRecorder: (_) async => _Recorder(),
      );
      addTearDown(session.dispose);
      _readyWorld(session);
      await Future<void>.delayed(Duration.zero);
      expect(session.isReady, isTrue);
      session.reportHostLoadFailure(StateError('mount failed'));
      expect(session.isReady, isFalse);
      expect(session.failure, RunStartupFailure.world);
      await session.stop();
      var notifications = 0;
      session.addListener(() => notifications++);
      session.reportHostLoadFailure(StateError('late failure'));
      expect(notifications, 0);
    },
  );

  test('recorder failure remains actionable after world completion', () async {
    final session = RunnerRunSession(
      descriptor: _descriptor,
      createRecorder: (_) async => throw StateError('disk unavailable'),
    );
    addTearDown(session.dispose);
    await Future<void>.delayed(Duration.zero);
    _readyWorld(session);
    expect(session.isReady, isFalse);
    expect(session.failure, RunStartupFailure.recorder);
    expect(session.errorMessage, contains('storage'));
    expect(session.controller.tick, 0);
    await session.stop();
  });

  test(
    'world failure cannot be overwritten by late recorder success',
    () async {
      final pending = Completer<RunRecorder>();
      final recorder = _Recorder();
      final session = RunnerRunSession(
        descriptor: _descriptor,
        createRecorder: (_) => pending.future,
      );
      addTearDown(session.dispose);
      session.game.loadState.value = RunLoadState(
        phase: RunLoadPhase.failed,
        progress: 0.35,
        error: StateError('missing sprite'),
      );
      pending.complete(recorder);
      await Future<void>.delayed(Duration.zero);
      expect(session.failure, RunStartupFailure.world);
      expect(session.isReady, isFalse);
      await session.stop();
      expect(recorder.closeCalls, 1);
    },
  );

  test(
    'disposal fences late completion and closes its recorder once',
    () async {
      final pending = Completer<RunRecorder>();
      final recorder = _Recorder();
      final session = RunnerRunSession(
        descriptor: _descriptor,
        createRecorder: (_) => pending.future,
      );
      var notifications = 0;
      session.addListener(() => notifications++);
      final stopped = session.stop();
      expect(identical(stopped, session.stop()), isTrue);
      session.dispose();
      pending.complete(recorder);
      await stopped;
      expect(recorder.closeCalls, 1);
      expect(notifications, 0);
      expect(session.recorder, isNull);
    },
  );
}

void _readyWorld(RunnerRunSession session) {
  session.game.loadState.value = const RunLoadState(
    phase: RunLoadPhase.worldReady,
    progress: 1,
  );
}

const _descriptor = RunStartDescriptor(
  runSessionId: 'startup-test',
  runId: 1,
  seed: 42,
  tickHz: 60,
  levelId: LevelId.field,
  playerCharacterId: PlayerCharacterId.eloise,
  runMode: RunMode.practice,
  equippedLoadout: EquippedLoadoutDef(),
);

class _Recorder implements RunRecorder {
  int closeCalls = 0;

  @override
  Future<void> close() async => closeCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
