import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:rpg_runner/game/replay/ghost_playback_runner.dart';
import 'package:rpg_runner/game/replay/ghost_playback_source.dart';

import 'support/ghost_replay_fixture.dart';

void main() {
  for (final cooperative in [false, true]) {
    for (final level in ['field', 'forest']) {
      test(
        'worker preserves every $level tick/event (cooperative: $cooperative)',
        () async {
          final replay = ghostReplayFixture(levelId: level);
          final source = cooperative
              ? GhostPlaybackSource.cooperative(replay)
              : GhostPlaybackSource.start(replay);
          addTearDown(source.dispose);
          final reference = GhostPlaybackRunner.fromReplayBlob(replay);
          addTearDown(reference.dispose);
          var count = 0;
          var eventCount = 0;
          var done = false;
          while (!done) {
            final batch = await source.read(count == 0 ? 120 : 37);
            expect(batch, isNotEmpty);
            for (final sample in batch) {
              expect(sample.snapshot.tick, count);
              reference.advanceToTick(count);
              expect(
                actorFrameFields(sample.snapshot),
                actorFrameFields(reference.snapshot),
                reason: 'tick $count',
              );
              expect(
                sample.events.map(eventFields).toList(),
                reference.drainedEvents.map(eventFields).toList(),
                reason: 'events at tick $count',
              );
              expect(sample.isComplete, reference.isComplete);
              eventCount += sample.events.length;
              reference.clearDrainedEvents();
              count++;
              if (sample.isComplete) {
                expect(sample, same(batch.last));
                expect(sample.events.whereType<RunEndedEvent>(), hasLength(1));
                done = true;
              }
            }
          }
          expect(
            count,
            greaterThan(120),
            reason: 'Exercise multiple worker batches.',
          );
          expect(
            eventCount,
            greaterThan(1),
            reason: 'Exercise transient event transfer.',
          );
        },
      );
    }
  }

  test('zero-length replay returns its terminal tick once', () async {
    final source = GhostPlaybackSource.start(ghostReplayFixture(totalTicks: 0));
    addTearDown(source.dispose);
    final samples = await source.read(120);
    expect(samples, hasLength(1));
    expect(samples.single.snapshot.tick, 0);
    expect(samples.single.isComplete, isTrue);
    expect(samples.single.events.whereType<RunEndedEvent>(), hasLength(1));
    expect(await source.read(120), isEmpty);
  });

  test('worker startup errors complete the request', () async {
    final source = GhostPlaybackSource.start(
      ghostReplayFixture(levelId: 'unavailable-level'),
    );
    addTearDown(source.dispose);
    await expectLater(source.read(120), throwsA(isA<Error>()));
  });

  test('disposal during worker startup cancels pending reads', () async {
    final source = GhostPlaybackSource.start(ghostReplayFixture());
    final pending = source.read(120);
    final rejected = expectLater(pending, throwsStateError);
    source.dispose();
    await rejected;
    await expectLater(source.read(1), throwsStateError);
  });

  test('source rejects concurrent and oversized requests', () async {
    final source = GhostPlaybackSource.start(ghostReplayFixture());
    addTearDown(source.dispose);
    expect(() => source.read(121), throwsRangeError);
    final first = source.read(120);
    await expectLater(source.read(1), throwsStateError);
    expect(await first, hasLength(120));
  });
}
