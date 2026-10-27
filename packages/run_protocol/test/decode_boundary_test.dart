import 'package:run_protocol/codecs/json_integer.dart';
import 'package:run_protocol/run_protocol.dart';
import 'package:test/test.dart';

void main() {
  final boardKey = BoardKey(
    mode: RunMode.competitive,
    levelId: 'field',
    windowId: 'window',
    rulesetVersion: 'rules',
    scoreVersion: 'score',
  );
  RunTicket ticket({int seed = 1}) => RunTicket(
    runSessionId: 'run',
    uid: 'uid',
    mode: RunMode.practice,
    seed: seed,
    tickHz: 30,
    gameCompatVersion: 'game',
    levelId: 'field',
    playerCharacterId: 'eloise',
    loadoutSnapshot: {},
    loadoutDigest: 'a' * 64,
    issuedAtMs: 1,
    expiresAtMs: 2,
    singleUseNonce: 'nonce',
  );
  BoardManifest board({int seed = 1}) => BoardManifest(
    boardId: 'board',
    boardKey: boardKey,
    gameCompatVersion: 'game',
    ghostVersion: 'ghost',
    tickHz: 30,
    seed: seed,
    opensAtMs: 1,
    closesAtMs: 2,
    status: BoardStatus.active,
  );
  ReplayBlobV1 replay({int seed = 1}) => ReplayBlobV1.withComputedDigest(
    runSessionId: 'run',
    tickHz: 30,
    seed: seed,
    levelId: 'field',
    playerCharacterId: 'eloise',
    loadoutSnapshot: {},
    totalTicks: 1,
    commandStream: [ReplayCommandFrameV1(tick: 1)],
  );
  LeaderboardEntry entry({int score = 1}) => LeaderboardEntry(
    boardId: 'board',
    entryId: 'entry',
    runSessionId: 'run',
    uid: 'uid',
    displayName: 'Name',
    characterId: 'eloise',
    score: score,
    distanceMeters: 1,
    durationSeconds: 1,
    sortKey: 'key',
    ghostEligible: false,
    updatedAtMs: 1,
  );
  ValidatedRun result({int score = 1}) => ValidatedRun(
    runSessionId: 'run',
    uid: 'uid',
    mode: RunMode.practice,
    accepted: true,
    score: score,
    distanceMeters: 1,
    durationSeconds: 1,
    tick: 30,
    endedReason: 'death',
    goldEarned: 1,
    stats: {},
    replayDigest: 'a' * 64,
    replayStorageRef: 'replay',
    createdAtMs: 1,
  );
  SubmissionReward reward({int delta = 1}) => SubmissionReward(
    status: SubmissionRewardStatus.finalReward,
    provisionalGold: 1,
    effectiveGoldDelta: delta,
    spendableGoldDelta: delta,
    updatedAtMs: 1,
  );
  SubmissionStatus status({int updatedAtMs = 1}) => SubmissionStatus(
    runSessionId: 'run',
    state: RunSessionState.issued,
    updatedAtMs: updatedAtMs,
  );

  final contracts =
      <
        (
          String,
          Map<String, Object?>,
          Object Function(Object?),
          Map<String, Object?>,
        )
      >[
        (
          'ticket',
          ticket().toJson(),
          RunTicket.fromJson,
          {
            'tickHz': 0,
            'expiresAtMs': 1,
            'boardId': 'unexpected',
            'loadoutSnapshot': {'mask': 0.5},
          },
        ),
        (
          'board',
          board().toJson(),
          BoardManifest.fromJson,
          {'tickHz': 0, 'closesAtMs': 1},
        ),
        (
          'frame',
          ReplayCommandFrameV1(tick: 1).toJson(),
          ReplayCommandFrameV1.fromJson,
          {'t': 0, 'ax': 1, 'pm': 64, 'hm': 64, 'hv': 1},
        ),
        (
          'replay',
          replay().toJson(),
          ReplayBlobV1.fromJson,
          {
            'boardId': 'unpaired',
            'canonicalSha256': 'bad',
            'loadoutSnapshot': {'invalid': double.infinity},
            'clientSummary': {'invalid': Object()},
          },
        ),
        (
          'entry',
          entry().toJson(),
          LeaderboardEntry.fromJson,
          {
            'score': -1,
            'rank': 0,
            'replayDigest': 'bad',
            'replayStorageGeneration': '0',
          },
        ),
        (
          'result',
          result().toJson(),
          ValidatedRun.fromJson,
          {
            'score': -1,
            'accepted': false,
            'stats': {'invalid': double.nan},
          },
        ),
        (
          'reward',
          reward().toJson(),
          SubmissionReward.fromJson,
          {'provisionalGold': -1, 'updatedAtMs': -1},
        ),
        (
          'status',
          status().toJson(),
          SubmissionStatus.fromJson,
          {
            'updatedAtMs': -1,
            'validatedRun': {...result().toJson(), 'runSessionId': 'other'},
            'reward': {...reward().toJson(), 'provisionalGold': -1},
          },
        ),
      ];
  for (final (name, valid, decode, invalidFields) in contracts) {
    for (final invalid in invalidFields.entries) {
      test('$name rejects malformed ${invalid.key} as FormatException', () {
        expect(
          () => decode({...valid, invalid.key: invalid.value}),
          throwsFormatException,
        );
      });
    }
    for (final field in valid.entries.where((e) => e.value is int)) {
      test('$name rejects overflowing ${field.key}', () {
        expect(
          () => decode({...valid, field.key: 1e100}),
          throwsFormatException,
        );
      });
    }
  }

  test('constructors reject unsafe wire integers in release builds', () {
    const unsafe = maxJsonSafeInteger + 1;
    for (final build in <Object Function()>[
      () => ticket(seed: unsafe),
      () => board(seed: unsafe),
      () => replay(seed: unsafe),
      () => ReplayCommandFrameV1(tick: unsafe),
      () => entry(score: unsafe),
      () => result(score: unsafe),
      () => reward(delta: unsafe),
      () => reward(delta: -unsafe),
      () => status(updatedAtMs: unsafe),
    ]) {
      expect(build, throwsArgumentError);
    }
  });
}
