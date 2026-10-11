import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/replay/replay_command_codec.dart';

import 'game/replay/support/ghost_replay_fixture.dart';
import 'support/test_level.dart';

void main() {
  test('cold live miss holds world, inputs and recorder; resumes exact offline tick', () async {
    final f = _Fixture();
    addTearDown(f.dispose);
    f.advanceUntilWait();
    final before = f.controller.snapshot;
    final tick = f.controller.tick;
    final recorded = f.frames.length;
    final events = f.events.length;
    final actorBefore = actorFrameFields(f.core.buildActorFrameSnapshot());
    final work = await f.worker.next();
    f.controller.enqueue(JumpPressedCommand(tick: tick + 1));
    f.controller.enqueue(
      AbilitySlotHeldCommand(
        tick: tick + 1,
        slot: AbilitySlot.primary,
        held: true,
      ),
    );
    // A release during loading must override its queued hold, not become stuck.
    f.controller.enqueue(
      AbilitySlotHeldCommand(
        tick: tick + 1,
        slot: AbilitySlot.primary,
        held: false,
      ),
    );
    for (var i = 0; i < 100; i++) {
      f.controller.advanceFrame(1);
    }
    expect(f.controller.snapshot, same(before));
    expect(f.controller.prevSnapshot, same(before));
    expect(f.controller.tick, tick);
    expect(f.frames.length, recorded);
    expect(f.events.length, events);
    expect(actorFrameFields(f.core.buildActorFrameSnapshot()), actorBefore);
    expect(f.core.drainEvents(), isEmpty);
    expect(
      () => f.core.applyCommands([MoveAxisCommand(tick: tick + 1, axis: -1)]),
      throwsStateError,
    );
    expect(() => f.core.stepOneTick(), throwsStateError);
    expect(f.core.tick, tick);
    await work.complete();
    await _turn();
    expect(f.controller.terrainReadiness, TerrainReadiness.ready);
    expect(f.controller.tick, tick, reason: 'Completion never steps Core.');
    f.controller.advanceFrame(5);
    expect(
      f.controller.tick,
      tick,
      reason: 'Discard the frame spanning the wait.',
    );
    f.controller.advanceFrame(1 / 60);
    expect(f.controller.tick, tick + 1);
    expect(f.frames.length, recorded + 1);
    expect(
      f.frames.last.pressedMask & ReplayCommandFrameV1.pressedJumpBit,
      isNonZero,
    );
    final bit = 1 << AbilitySlot.primary.index;
    expect(f.frames.last.abilitySlotHeldChangedMask & bit, bit);
    expect(f.frames.last.abilitySlotHeldValueMask & bit, 0);
    f.compareWithOffline();
    expect(f.core.terrainPreparationStats!.misses, 1);
  });

  test('pause during preparation remains paused after completion', () async {
    final f = _Fixture();
    addTearDown(f.dispose);
    f.advanceUntilWait();
    final work = await f.worker.next();
    final tick = f.controller.tick;
    f.controller.setPaused(true);
    await work.complete();
    await _turn();
    f.controller.advanceFrame(1);
    expect(f.controller.tick, tick);
    expect(f.controller.snapshot.paused, isTrue);
    f.controller.setPaused(false);
    f.controller.advanceFrame(1);
    expect(f.controller.tick, tick);
    f.controller.advanceFrame(1 / 60);
    expect(f.controller.tick, tick + 1);
  });

  test(
    'failure retries same tick and queued input without restarting the run',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      f.advanceUntilWait();
      final work = await f.worker.next();
      final tick = f.controller.tick;
      final before = f.controller.snapshot;
      f.controller.enqueue(DashPressedCommand(tick: tick + 1));
      work.completer.completeError(StateError('worker unavailable'));
      await _turn();
      expect(f.controller.terrainReadiness, TerrainReadiness.failed);
      expect(
        f.controller.terrainError.toString(),
        contains('worker unavailable'),
      );
      f.controller.advanceFrame(100);
      expect(f.controller.snapshot, same(before));
      f.controller.retryTerrainPreparation();
      f.controller.advanceFrame(1 / 60);
      f.controller.advanceFrame(1 / 60);
      expect(f.controller.terrainReadiness, TerrainReadiness.preparing);
      final retried = await f.worker.next();
      expect(
        retried.bindings.map((b) => b.chunkIndex),
        work.bindings.map((b) => b.chunkIndex),
      );
      await retried.complete();
      await _turn();
      f.controller.advanceFrame(2);
      f.controller.advanceFrame(1 / 60);
      expect(f.controller.tick, tick + 1);
      expect(
        f.frames.last.pressedMask & ReplayCommandFrameV1.pressedDashBit,
        isNonZero,
      );
      expect(f.controller.terrainError, isNull);
      f.compareWithOffline();
    },
  );

  for (final terminal in ['shutdown', 'dispose', 'give up']) {
    test('$terminal fences a pending terrain result', () async {
      final f = _Fixture();
      addTearDown(f.worker.close);
      f.advanceUntilWait();
      final work = await f.worker.next();
      final tick = f.controller.tick;
      var notifications = 0;
      f.controller.addListener(() => notifications++);
      if (terminal == 'shutdown') f.controller.shutdown();
      if (terminal == 'give up') f.controller.giveUp();
      if (terminal == 'dispose') f.controller.dispose();
      final afterStop = notifications;
      await work.complete();
      await _turn();
      expect(notifications, afterStop);
      f.controller.advanceFrame(1);
      f.controller.retryTerrainPreparation();
      f.controller.setPaused(false);
      f.controller.advanceFrame(1);
      expect(f.controller.tick, tick);
      if (terminal != 'dispose') f.controller.dispose();
    });
  }

  test('prepared mode cannot silently revert to synchronous stepping', () {
    final core = _core();
    expect(core.prepareNextTick(), isNull);
    core.stepOneTick();
    final tick = core.tick;
    expect(() => core.stepOneTick(), throwsStateError);
    core.stopTerrainPreparation();
    expect(() => core.stepOneTick(), throwsStateError);
    expect(core.tick, tick);
  });
}

Future<void> _turn() => Future<void>.delayed(Duration.zero);

// Fast camera reaches a stream boundary before combat, while the generous
// offscreen grace keeps this pacing test independent of player movement.
const _tuning = CoreTuning(
  camera: CameraTuning(
    speedLagMulX: 10,
    accelX: 100000,
    earlySpeedMultiplier: 1,
    fallBehindGraceDistance: 100000,
  ),
);

GameCore _core({_Worker? worker}) => GameCore(
  seed: 42,
  levelDefinition: testFieldLevel(tuning: _tuning),
  playerCharacter: testPlayerCharacter,
  terrainPreparation: worker?.prepare ?? _prepare,
);

Future<StagedTerrainStreamCandidate> _prepare(
  List<StagedTerrainChunkBinding> bindings,
  List<TerrainSurfaceGraphBuildProfile> profiles,
) => const StagedTerrainStreamCandidateBuilder().buildFromBindingsCooperatively(
  bindings: bindings,
  geometryVersion: 0,
  groundEnemyProfiles: profiles,
);

class _Fixture {
  _Fixture() {
    core = _core(worker: worker);
    controller = GameController(core: core);
    controller.addAppliedCommandFrameListener(frames.add);
    controller.addEventListener((event) => events.add(eventFields(event)));
  }
  final worker = _Worker();
  late final GameCore core;
  late final GameController controller;
  final frames = <ReplayCommandFrameV1>[];
  final events = <Object>[];

  void advanceUntilWait() {
    for (
      var i = 0;
      i < 200 && controller.terrainReadiness == TerrainReadiness.ready;
      i++
    ) {
      controller.enqueue(MoveAxisCommand(tick: controller.tick + 1, axis: 1));
      controller.advanceFrame(1 / 60);
    }
    expect(controller.terrainReadiness, TerrainReadiness.preparing);
    expect(controller.tick, greaterThan(0));
  }

  void compareWithOffline() {
    final reference = _core();
    final referenceEvents = <Object>[];
    for (final frame in frames) {
      reference.applyCommands(ReplayCommandCodec.commandsFromFrame(frame));
      reference.stepOneTick();
      referenceEvents.addAll(reference.drainEvents().map(eventFields));
    }
    expect(
      actorFrameFields(core.buildActorFrameSnapshot()),
      actorFrameFields(reference.buildActorFrameSnapshot()),
    );
    final actual = core.buildSnapshot();
    final expected = reference.buildSnapshot();
    expect(actual.camera.centerX, expected.camera.centerX);
    expect(
      actual.stagedTerrainRenderSnapshot!.geometryVersion,
      expected.stagedTerrainRenderSnapshot!.geometryVersion,
    );
    expect(
      actual.stagedTerrainRenderSnapshot!.polygons.map((p) => p.sourceId),
      expected.stagedTerrainRenderSnapshot!.polygons.map((p) => p.sourceId),
    );
    expect(events, referenceEvents);
  }

  Future<void> dispose() async {
    controller.dispose();
    await worker.close();
  }
}

class _Worker {
  final _requests = StreamController<_Work>();
  late final _iterator = StreamIterator(_requests.stream);
  Future<StagedTerrainStreamCandidate> prepare(
    List<StagedTerrainChunkBinding> bindings,
    List<TerrainSurfaceGraphBuildProfile> profiles,
  ) {
    final work = _Work(bindings, profiles);
    _requests.add(work);
    return work.completer.future;
  }

  Future<_Work> next() async {
    if (!await _iterator.moveNext()) throw StateError('Worker closed.');
    return _iterator.current;
  }

  Future<void> close() async {
    await _iterator.cancel();
    await _requests.close();
  }
}

class _Work {
  _Work(this.bindings, this.profiles);
  final List<StagedTerrainChunkBinding> bindings;
  final List<TerrainSurfaceGraphBuildProfile> profiles;
  final completer = Completer<StagedTerrainStreamCandidate>();
  Future<void> complete() async =>
      completer.complete(await _prepare(bindings, profiles));
}
