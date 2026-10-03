import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/actor_frame_snapshot.dart';
import 'package:rpg_runner/game/replay/buffered_ghost_playback.dart';
import 'package:rpg_runner/game/replay/ghost_playback_source.dart';
import 'package:rpg_runner/game/replay/ghost_playback_runner.dart';

import 'support/ghost_replay_fixture.dart';

void main() {
  test(
    'underrun freezes, catch-up restores adjacency, events are consumed once',
    () async {
      final source = _ManualSource();
      final replay = BufferedGhostPlayback(
        replayBlob: ghostReplayFixture(totalTicks: 180),
        sourceFactory: (_) => source,
      );
      addTearDown(replay.dispose);
      final events = <GameEvent>[];
      replay.addListener(() {
        events.addAll(replay.frame?.events ?? const []);
        expect(
          replay.debugBufferedFrameCount,
          lessThanOrEqualTo(BufferedGhostPlayback.capacity),
        );
      });
      final ready = replay.prepare();
      expect(source.requests.single.count, 120);
      source.complete(0, 0, endTick: 180);
      final preview = await ready;
      expect(preview, hasLength(120));
      expect(replay.frame!.current.tick, 0);
      expect(replay.debugBufferedFrameCount, 119);

      replay.advanceToTick(60);
      expect(replay.frame!.previous.tick, 59);
      expect(replay.frame!.current.tick, 60);
      expect(source.requests, hasLength(2));
      replay.advanceToTick(130);
      expect(replay.frame!.current.tick, 119);
      expect(identical(replay.frame!.previous, replay.frame!.current), isTrue);
      final frozen = replay.frame;
      replay.advanceToTick(130);
      expect(identical(replay.frame, frozen), isTrue);
      expect(
        source.requests,
        hasLength(2),
        reason: 'One in-flight batch only.',
      );
      source.complete(1, 120, endTick: 180);
      await _settle();
      expect(replay.frame!.current.tick, 130);
      expect(replay.frame!.previous.tick, 129);
      expect(replay.isComplete, isFalse);
      expect(
        source.disposed,
        isTrue,
        reason: 'Production ends before terminal playback.',
      );
      replay.advanceToTick(500);
      expect(replay.frame!.current.tick, 180);
      expect(identical(replay.frame!.previous, replay.frame!.current), isTrue);
      expect(replay.isComplete, isTrue);
      expect(
        events.whereType<EntityVisualCueEvent>().map((e) => e.tick),
        List.generate(181, (i) => i),
      );
      expect(events.whereType<RunEndedEvent>(), hasLength(1));
      final terminal = replay.frame;
      replay.advanceToTick(1000);
      expect(identical(terminal, replay.frame), isTrue);
    },
  );

  test('paused live tick neither advances nor repeatedly refills', () async {
    final source = _ManualSource();
    final replay = BufferedGhostPlayback(
      replayBlob: ghostReplayFixture(),
      sourceFactory: (_) => source,
    );
    addTearDown(replay.dispose);
    final ready = replay.prepare();
    source.complete(0, 0);
    await ready;
    replay.advanceToTick(60);
    source.complete(1, 120);
    await _settle();
    expect(replay.debugBufferedFrameCount, 120);
    final frame = replay.frame;
    for (var i = 0; i < 100; i++) {
      replay.advanceToTick(60);
    }
    expect(identical(frame, replay.frame), isTrue);
    expect(source.requests, hasLength(2));
    replay.advanceToTick(1);
    expect(replay.frame!.current.tick, 60, reason: 'Playback never rewinds.');
  });

  for (final afterReady in [false, true]) {
    test(
      'dispose fences late results (after readiness: $afterReady)',
      () async {
        final source = _ManualSource();
        final replay = BufferedGhostPlayback(
          replayBlob: ghostReplayFixture(),
          sourceFactory: (_) => source,
        );
        var notifications = 0;
        replay.addListener(() {
          notifications++;
        });
        final ready = replay.prepare();
        if (afterReady) {
          source.complete(0, 0);
          await ready;
          replay.advanceToTick(60);
        }
        final before = notifications;
        replay.dispose();
        expect(source.disposed, isTrue);
        source.complete(afterReady ? 1 : 0, afterReady ? 120 : 0);
        await ready;
        await _settle();
        expect(notifications, before);
        expect(replay.frame, isNull);
        expect(replay.debugBufferedFrameCount, 0);
      },
    );
  }

  test(
    'failed refill clears the ghost without throwing from live advancement',
    () async {
      final source = _ManualSource();
      final replay = BufferedGhostPlayback(
        replayBlob: ghostReplayFixture(),
        sourceFactory: (_) => source,
      );
      addTearDown(replay.dispose);
      final ready = replay.prepare();
      source.complete(0, 0);
      await ready;
      replay.advanceToTick(60);
      source.requests.last.result.completeError(StateError('worker failed'));
      await _settle();
      expect(replay.error, isStateError);
      expect(replay.frame, isNull);
      expect(source.disposed, isTrue);
      expect(() => replay.advanceToTick(10000), returnsNormally);
    },
  );

  test(
    'invalid sequence fails preparation instead of publishing future data',
    () async {
      final source = _ManualSource();
      final replay = BufferedGhostPlayback(
        replayBlob: ghostReplayFixture(),
        sourceFactory: (_) => source,
      );
      addTearDown(replay.dispose);
      final ready = replay.prepare();
      source.complete(0, 1);
      expect(await ready, isEmpty);
      expect(replay.error, isStateError);
      expect(replay.frame, isNull);
      expect(source.disposed, isTrue);
    },
  );

  test(
    'buffered native playback matches synchronous replay across hitches',
    () async {
      final blob = ghostReplayFixture(levelId: 'forest', totalTicks: 900);
      final replay = BufferedGhostPlayback(replayBlob: blob);
      final reference = GhostPlaybackRunner.fromReplayBlob(blob);
      addTearDown(replay.dispose);
      addTearDown(reference.dispose);
      final events = <GameEvent>[];
      replay.addListener(() {
        events.addAll(replay.frame?.events ?? const []);
      });
      await replay.prepare();
      expect(replay.error, isNull);
      for (var tick = 0; tick <= blob.totalTicks + 73; tick += 73) {
        replay.advanceToTick(tick);
        reference.advanceToTick(tick);
        for (
          var tries = 0;
          tries < 500 &&
              !replay.isComplete &&
              (replay.frame?.current.tick ?? -1) < reference.tick;
          tries++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        expect(replay.error, isNull);
        expect(
          actorFrameFields(replay.frame!.current),
          actorFrameFields(reference.snapshot),
        );
        expect(
          events.map(eventFields).toList(),
          reference.drainedEvents.map(eventFields).toList(),
        );
        expect(replay.debugBufferedFrameCount, lessThanOrEqualTo(120));
        if (replay.isComplete) break;
        expect(replay.frame!.previous.tick, math.max(0, reference.tick - 1));
      }
      expect(replay.isComplete, isTrue);
    },
  );
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

class _Request {
  _Request(this.count);
  final int count;
  final result = Completer<List<GhostPlaybackSample>>();
}

class _ManualSource implements GhostPlaybackSource {
  final requests = <_Request>[];
  bool disposed = false;

  @override
  Future<List<GhostPlaybackSample>> read(int maxFrames) {
    final request = _Request(maxFrames);
    requests.add(request);
    return request.result.future;
  }

  void complete(int index, int startTick, {int endTick = 10000}) {
    final request = requests[index];
    request.result.complete([
      for (
        var tick = startTick;
        tick < startTick + request.count && tick <= endTick;
        tick++
      )
        GhostPlaybackSample(
          snapshot: ActorFrameSnapshot(
            tick: tick,
            distance: tick.toDouble(),
            gameOver: tick == endTick,
            entities: const [],
          ),
          isComplete: tick == endTick,
          events: [
            EntityVisualCueEvent(
              tick: tick,
              entityId: 1,
              kind: EntityVisualCueKind.directHit,
              intensityBp: 100,
            ),
            if (tick == endTick)
              RunEndedEvent(
                runId: 1,
                tick: tick,
                distance: tick.toDouble(),
                reason: RunEndReason.gaveUp,
                goldEarned: 0,
                stats: const RunEndStats(
                  collectibles: 0,
                  collectibleScore: 0,
                  enemyKillCounts: [],
                ),
              ),
          ],
        ),
    ]);
  }

  @override
  void dispose() {
    disposed = true;
  }
}
