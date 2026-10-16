import 'package:run_protocol/run_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('accepted result round trips stats and preserves them when sealed', () {
    final result = _run(
      playerRunStats: PlayerRunStats(
        damageDealt100: 12345,
        damageTaken100: 678,
      ),
    );
    final parsed = ValidatedRun.fromJson(result.toJson()).withReplayArtifact(
      replayStorageRef: 'validated/run',
      replayStorageGeneration: '1',
    );
    expect(parsed.playerRunStats!.damageDealt100, 12345);
    expect(parsed.playerRunStats!.damageTaken100, 678);
  });

  test('legacy result omits player stats', () {
    expect(ValidatedRun.fromJson(_run().toJson()).playerRunStats, isNull);
  });

  test('rejected result cannot carry player stats', () {
    final json =
        _run(
            playerRunStats: PlayerRunStats(
              damageDealt100: 1,
              damageTaken100: 0,
            ),
          ).toJson()
          ..['accepted'] = false
          ..['rejectionReason'] = 'invalidReplay';
    expect(() => ValidatedRun.fromJson(json), throwsFormatException);
  });

  test('invalid totals and versions fail at both boundaries', () {
    for (final count in [-1, 0.5, double.infinity, 9007199254740992]) {
      expect(
        () => PlayerRunStats.fromJson({
          'schemaVersion': 1,
          'damageDealt100': count,
          'damageTaken100': 0,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => PlayerRunStats.fromJson({
        'schemaVersion': 2,
        'damageDealt100': 0,
        'damageTaken100': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => PlayerRunStats(damageDealt100: -1, damageTaken100: 0),
      throwsArgumentError,
    );
  });
}

ValidatedRun _run({PlayerRunStats? playerRunStats}) => ValidatedRun(
  runSessionId: 'run',
  uid: 'user',
  mode: RunMode.practice,
  accepted: true,
  score: 100,
  distanceMeters: 1,
  durationSeconds: 1,
  tick: 60,
  endedReason: 'gaveUp',
  goldEarned: 0,
  stats: {},
  replayDigest: 'a' * 64,
  replayStorageRef: 'runs/run',
  createdAtMs: 1,
  playerRunStats: playerRunStats,
);
