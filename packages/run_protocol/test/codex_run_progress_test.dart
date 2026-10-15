import 'package:run_protocol/run_protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Codex evidence is detached, immutable and survives artifact sealing',
    () {
      final kills = {'grojib': 10, 'bringerOfDeath': 1};
      final evidence = CodexRunProgress(levelId: 'forest', enemyKills: kills);
      kills['grojib'] = 99;
      expect(evidence.enemyKills['grojib'], 10);
      expect(() => evidence.enemyKills['grojib'] = 5, throwsUnsupportedError);
      final run = _run(codex: evidence);
      final parsed = ValidatedRun.fromJson(run.toJson()).withReplayArtifact(
        replayStorageRef: 'validated/run',
        replayStorageGeneration: '1',
      );
      expect(parsed.codex!.toJson(), evidence.toJson());
      (evidence.toJson()['enemyKills']! as Map)['grojib'] = 0;
      expect(evidence.enemyKills['grojib'], 10);
    },
  );

  test('legacy results omit Codex evidence', () {
    expect(ValidatedRun.fromJson(_run().toJson()).codex, isNull);
  });

  test('ranked Codex evidence must match the board level', () {
    final json =
        _run(
            codex: CodexRunProgress(levelId: 'forest', enemyKills: {}),
          ).toJson()
          ..['mode'] = 'competitive'
          ..['boardId'] = 'board'
          ..['boardKey'] = {
            'mode': 'competitive',
            'levelId': 'field',
            'windowId': '2026-10',
            'rulesetVersion': 'rules-v2',
            'scoreVersion': 'score-v4',
          };
    expect(() => ValidatedRun.fromJson(json), throwsFormatException);
    (json['boardKey']! as Map)['levelId'] = 'forest';
    expect(ValidatedRun.fromJson(json).codex!.levelId, 'forest');
  });

  test('rejected results cannot carry discovery evidence', () {
    final json =
        _run(
            codex: CodexRunProgress(levelId: 'forest', enemyKills: {}),
          ).toJson()
          ..['accepted'] = false
          ..['rejectionReason'] = 'invalidReplay';
    expect(() => ValidatedRun.fromJson(json), throwsFormatException);
  });

  test('malformed counts and unknown versions fail decoding', () {
    for (final count in [-1, 0.5, double.infinity, 9007199254740992]) {
      expect(
        () => CodexRunProgress.fromJson({
          'schemaVersion': 1,
          'levelId': 'forest',
          'enemyKills': {'grojib': count},
        }),
        throwsFormatException,
      );
    }
    expect(
      () => CodexRunProgress.fromJson({
        'schemaVersion': 2,
        'levelId': 'forest',
        'enemyKills': {},
      }),
      throwsFormatException,
    );
    expect(
      () => CodexRunProgress(levelId: '', enemyKills: {}),
      throwsArgumentError,
    );
    expect(
      () => CodexRunProgress(levelId: 'forest', enemyKills: {'grojib': -1}),
      throwsArgumentError,
    );
  });
}

ValidatedRun _run({CodexRunProgress? codex}) => ValidatedRun(
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
  codex: codex,
);
