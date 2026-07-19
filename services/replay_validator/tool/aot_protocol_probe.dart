import 'package:run_protocol/run_protocol.dart';

void main() {
  final valid = ReplayBlobV1.withComputedDigest(
    runSessionId: 'aot-protocol-probe',
    tickHz: 60,
    seed: 1,
    levelId: 'field',
    playerCharacterId: 'eloise',
    loadoutSnapshot: const <String, Object?>{},
    totalTicks: 1,
    commandStream: <ReplayCommandFrameV1>[ReplayCommandFrameV1(tick: 1)],
  ).toJson();

  _expectRejected(<String, Object?>{...valid, 'replayVersion': 999});
  _expectRejected(<String, Object?>{...valid, 'commandEncodingVersion': 999});
  _expectRejected(<String, Object?>{
    ...valid,
    'commandStream': <Object?>[
      <String, Object?>{'t': 1, 'pm': 1 << 30},
    ],
  });

  _expectArgumentError(() => ReplayCommandFrameV1(tick: 0));
  _expectArgumentError(
    () => BoardKey(
      mode: RunMode.practice,
      levelId: 'field',
      windowId: '2026-07',
      rulesetVersion: 'rules-v1',
      scoreVersion: 'score-v1',
    ),
  );
  _expectArgumentError(
    () => BoardManifest(
      boardId: 'board_1',
      boardKey: BoardKey(
        mode: RunMode.competitive,
        levelId: 'field',
        windowId: '2026-07',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      ),
      gameCompatVersion: '2026.03.0',
      ghostVersion: 'ghost-v1',
      tickHz: 0,
      seed: 1,
      opensAtMs: 1,
      closesAtMs: 2,
      status: BoardStatus.active,
    ),
  );
  _expectArgumentError(
    () => ReplayBlobV1.withComputedDigest(
      runSessionId: 'aot-protocol-probe',
      tickHz: 60,
      seed: 1,
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: const <String, Object?>{},
      totalTicks: 0,
      commandStream: const <ReplayCommandFrameV1>[],
      replayVersion: 2,
    ),
  );
  _expectArgumentError(
    () => LeaderboardEntry(
      boardId: 'board_1',
      entryId: 'entry_1',
      runSessionId: 'run_1',
      uid: 'user_1',
      displayName: 'Player',
      characterId: 'eloise',
      score: -1,
      distanceMeters: 0,
      durationSeconds: 0,
      sortKey: 'sort',
      ghostEligible: false,
      updatedAtMs: 0,
    ),
  );
  _expectArgumentError(
    () => ValidatedRun(
      runSessionId: 'run_1',
      uid: 'user_1',
      mode: RunMode.practice,
      accepted: false,
      score: 0,
      distanceMeters: 0,
      durationSeconds: 0,
      tick: 0,
      endedReason: 'rejected',
      goldEarned: 0,
      stats: const <String, Object?>{},
      replayDigest: 'a' * 64,
      replayStorageRef: 'runs/run_1/replay.json',
      createdAtMs: 0,
    ),
  );
  _expectArgumentError(
    () => RunTicket(
      runSessionId: 'run_1',
      uid: 'user_1',
      mode: RunMode.competitive,
      boardId: 'board_1',
      boardKey: BoardKey(
        mode: RunMode.weekly,
        levelId: 'field',
        windowId: '2026-07',
        rulesetVersion: 'rules-v1',
        scoreVersion: 'score-v1',
      ),
      seed: 1,
      tickHz: 60,
      gameCompatVersion: '2026.03.0',
      rulesetVersion: 'rules-v1',
      scoreVersion: 'score-v1',
      ghostVersion: 'ghost-v1',
      levelId: 'field',
      playerCharacterId: 'eloise',
      loadoutSnapshot: const <String, Object?>{},
      loadoutDigest: 'a' * 64,
      issuedAtMs: 1,
      expiresAtMs: 2,
      singleUseNonce: 'nonce_1',
    ),
  );
  _expectArgumentError(
    () => SubmissionReward(
      status: SubmissionRewardStatus.provisional,
      provisionalGold: -1,
      effectiveGoldDelta: 0,
      spendableGoldDelta: 0,
      updatedAtMs: 0,
    ),
  );
  _expectArgumentError(
    () => SubmissionStatus(
      runSessionId: 'run_1',
      state: RunSessionState.issued,
      updatedAtMs: -1,
    ),
  );
}

void _expectRejected(Map<String, Object?> replay) {
  try {
    ReplayBlobV1.fromJson(replay, verifyDigest: false);
  } on FormatException {
    return;
  }
  throw StateError('Malformed replay was accepted by the AOT protocol probe.');
}

void _expectArgumentError(Object? Function() build) {
  try {
    build();
  } on ArgumentError {
    return;
  }
  throw StateError(
    'Invalid protocol construction was accepted by the AOT probe.',
  );
}
