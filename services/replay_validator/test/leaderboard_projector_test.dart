import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/leaderboard_entry.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/sort_key.dart';
import 'package:run_protocol/validated_run.dart';
import 'package:test/test.dart';

import 'package:replay_validator/src/leaderboard_projector.dart';

void main() {
  test('lower-than-best run does not replace existing player best', () async {
    const boardId = 'board_competitive_2026_03_field';
    const uid = 'uid_player';
    final store = _InMemoryLeaderboardProjectionStore(
      validatedRuns: <String, ValidatedRun>{
        'run_lower': _validatedRun(
          runSessionId: 'run_lower',
          uid: uid,
          boardId: boardId,
          score: 950,
          distanceMeters: 350,
          durationSeconds: 150,
        ),
      },
      displayNames: const <String, String>{uid: 'Player One'},
      characterIds: const <String, String>{'run_lower': 'eloise'},
      playerBestsByBoard: <String, Map<String, LeaderboardEntry>>{
        boardId: <String, LeaderboardEntry>{
          uid: _entry(
            boardId: boardId,
            runSessionId: 'run_best',
            uid: uid,
            displayName: 'Player One',
            score: 1100,
            distanceMeters: 420,
            durationSeconds: 120,
            updatedAtMs: 1000,
          ),
        },
      },
    );
    final projector = FirestoreLeaderboardProjector(
      projectId: 'demo-project',
      store: store,
      clockMs: () => 5000,
    );

    await projector.projectValidatedRun(runSessionId: 'run_lower');

    expect(store.upsertedEntries, isEmpty);
    expect(store.top10Writes, hasLength(1));
    final best = store.playerBestsByBoard[boardId]![uid]!;
    expect(best.runSessionId, 'run_best');
    expect(best.score, 1100);
  });

  test(
    'improved run updates player best and refreshes top10 ordering',
    () async {
      const boardId = 'board_competitive_2026_03_field';
      const uid = 'uid_player';
      final oldBest = _entry(
        boardId: boardId,
        runSessionId: 'run_old_best',
        uid: uid,
        displayName: 'Player One',
        score: 1000,
        distanceMeters: 390,
        durationSeconds: 140,
        updatedAtMs: 1000,
        ghostEligible: true,
      );
      final rivalBest = _entry(
        boardId: boardId,
        runSessionId: 'run_rival_best',
        uid: 'uid_rival',
        displayName: 'Rival',
        score: 1050,
        distanceMeters: 400,
        durationSeconds: 130,
        updatedAtMs: 1000,
        ghostEligible: true,
      );
      final store = _InMemoryLeaderboardProjectionStore(
        validatedRuns: <String, ValidatedRun>{
          'run_improved': _validatedRun(
            runSessionId: 'run_improved',
            uid: uid,
            boardId: boardId,
            score: 1300,
            distanceMeters: 450,
            durationSeconds: 110,
          ),
        },
        displayNames: const <String, String>{
          uid: 'Player One',
          'uid_rival': 'Rival',
        },
        characterIds: const <String, String>{'run_improved': 'eloise'},
        playerBestsByBoard: <String, Map<String, LeaderboardEntry>>{
          boardId: <String, LeaderboardEntry>{
            uid: oldBest,
            'uid_rival': rivalBest,
          },
        },
        top10Views: <String, List<LeaderboardEntry>>{
          boardId: <LeaderboardEntry>[
            _copyEntry(rivalBest, rank: 1),
            _copyEntry(oldBest, rank: 2),
          ],
        },
      );
      final projector = FirestoreLeaderboardProjector(
        projectId: 'demo-project',
        store: store,
        clockMs: () => 8000,
      );

      await projector.projectValidatedRun(runSessionId: 'run_improved');

      expect(store.upsertedEntries, hasLength(1));
      final updatedBest = store.playerBestsByBoard[boardId]![uid]!;
      expect(updatedBest.runSessionId, 'run_improved');
      expect(updatedBest.score, 1300);

      expect(store.top10Writes, hasLength(1));
      final top10 = store.top10Views[boardId]!;
      expect(top10, hasLength(2));
      expect(top10[0].uid, uid);
      expect(top10[0].runSessionId, 'run_improved');
      expect(top10[0].rank, 1);
      expect(top10[0].ghostEligible, isTrue);
      expect(top10[1].uid, 'uid_rival');
      expect(top10[1].rank, 2);
      expect(store.playerBestsByBoard[boardId]![uid]!.ghostEligible, isTrue);
      expect(
        store.playerBestsByBoard[boardId]!['uid_rival']!.ghostEligible,
        isTrue,
      );
    },
  );

  test(
    'concurrent better and worse candidates preserve the better best',
    () async {
      const boardId = 'board_concurrent';
      const uid = 'uid_player';
      final store = _InMemoryLeaderboardProjectionStore(
        validatedRuns: <String, ValidatedRun>{
          'run_worse': _validatedRun(
            runSessionId: 'run_worse',
            uid: uid,
            boardId: boardId,
            score: 900,
            distanceMeters: 300,
            durationSeconds: 150,
          ),
          'run_better': _validatedRun(
            runSessionId: 'run_better',
            uid: uid,
            boardId: boardId,
            score: 1300,
            distanceMeters: 450,
            durationSeconds: 100,
          ),
        },
        displayNames: const <String, String>{uid: 'Player One'},
        characterIds: const <String, String>{
          'run_worse': 'eloise',
          'run_better': 'eloise',
        },
      );
      final projector = FirestoreLeaderboardProjector(
        projectId: 'demo-project',
        store: store,
        clockMs: () => 9000,
      );

      await Future.wait(<Future<void>>[
        projector.projectValidatedRun(runSessionId: 'run_worse'),
        projector.projectValidatedRun(runSessionId: 'run_better'),
      ]);

      expect(
        store.playerBestsByBoard[boardId]![uid]!.runSessionId,
        'run_better',
      );
    },
  );

  test(
    'top10 compare-and-swap conflict recomputes before completion',
    () async {
      const boardId = 'board_retry';
      const uid = 'uid_player';
      final store = _InMemoryLeaderboardProjectionStore(
        validatedRuns: <String, ValidatedRun>{
          'run_retry': _validatedRun(
            runSessionId: 'run_retry',
            uid: uid,
            boardId: boardId,
            score: 1200,
            distanceMeters: 400,
            durationSeconds: 100,
          ),
        },
        displayNames: const <String, String>{uid: 'Player One'},
        characterIds: const <String, String>{'run_retry': 'eloise'},
        top10WriteConflictsRemaining: 1,
      );
      final projector = FirestoreLeaderboardProjector(
        projectId: 'demo-project',
        store: store,
        clockMs: () => 9000,
      );

      await projector.projectValidatedRun(runSessionId: 'run_retry');

      expect(store.top10WriteAttempts, 2);
      expect(store.top10Writes, <String>[boardId]);
      expect(store.top10Views[boardId]!.single.runSessionId, 'run_retry');
    },
  );

  test(
    'retry after player-best write resumes an incomplete top10 projection',
    () async {
      const boardId = 'board_partial_projection';
      const uid = 'uid_player';
      final store = _InMemoryLeaderboardProjectionStore(
        validatedRuns: <String, ValidatedRun>{
          'run_partial': _validatedRun(
            runSessionId: 'run_partial',
            uid: uid,
            boardId: boardId,
            score: 1200,
            distanceMeters: 400,
            durationSeconds: 100,
          ),
        },
        displayNames: const <String, String>{uid: 'Player One'},
        characterIds: const <String, String>{'run_partial': 'eloise'},
        top10WriteFailuresRemaining: 1,
      );
      final projector = FirestoreLeaderboardProjector(
        projectId: 'demo-project',
        store: store,
        clockMs: () => 9000,
      );

      await expectLater(
        projector.projectValidatedRun(runSessionId: 'run_partial'),
        throwsA(isA<StateError>()),
      );
      expect(
        store.playerBestsByBoard[boardId]![uid]!.runSessionId,
        'run_partial',
      );

      await projector.projectValidatedRun(runSessionId: 'run_partial');

      expect(store.upsertedEntries, hasLength(1));
      expect(store.top10Views[boardId]!.single.runSessionId, 'run_partial');
    },
  );
}

ValidatedRun _validatedRun({
  required String runSessionId,
  required String uid,
  required String boardId,
  required int score,
  required int distanceMeters,
  required int durationSeconds,
}) {
  return ValidatedRun(
    runSessionId: runSessionId,
    uid: uid,
    boardId: boardId,
    boardKey: BoardKey(
      mode: RunMode.competitive,
      levelId: 'field',
      windowId: '2026-03',
      rulesetVersion: 'rules-v1',
      scoreVersion: 'score-v1',
    ),
    mode: RunMode.competitive,
    accepted: true,
    score: score,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    tick: durationSeconds * 60,
    endedReason: 'playerDied',
    goldEarned: 42,
    stats: const <String, Object?>{},
    replayDigest:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    replayStorageRef:
        'replay-submissions/pending/$uid/$runSessionId/replay.bin.gz',
    replayStorageGeneration: '123',
    createdAtMs: 1,
  );
}

LeaderboardEntry _entry({
  required String boardId,
  required String runSessionId,
  required String uid,
  required String displayName,
  required int score,
  required int distanceMeters,
  required int durationSeconds,
  required int updatedAtMs,
  bool ghostEligible = false,
}) {
  return LeaderboardEntry(
    boardId: boardId,
    entryId: runSessionId,
    runSessionId: runSessionId,
    uid: uid,
    displayName: displayName,
    characterId: 'eloise',
    score: score,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    sortKey: buildLeaderboardSortKey(
      score: score,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      entryId: runSessionId,
    ),
    ghostEligible: ghostEligible,
    updatedAtMs: updatedAtMs,
  );
}

LeaderboardEntry _copyEntry(
  LeaderboardEntry source, {
  bool? ghostEligible,
  int? updatedAtMs,
  int? rank,
}) {
  return LeaderboardEntry(
    boardId: source.boardId,
    entryId: source.entryId,
    runSessionId: source.runSessionId,
    uid: source.uid,
    displayName: source.displayName,
    characterId: source.characterId,
    score: source.score,
    distanceMeters: source.distanceMeters,
    durationSeconds: source.durationSeconds,
    sortKey: source.sortKey,
    ghostEligible: ghostEligible ?? source.ghostEligible,
    replayStorageRef: source.replayStorageRef,
    replayStorageGeneration: source.replayStorageGeneration,
    replayDigest: source.replayDigest,
    updatedAtMs: updatedAtMs ?? source.updatedAtMs,
    rank: rank ?? source.rank,
  );
}

class _InMemoryLeaderboardProjectionStore
    implements LeaderboardProjectionStore {
  _InMemoryLeaderboardProjectionStore({
    Map<String, ValidatedRun>? validatedRuns,
    Map<String, String>? displayNames,
    Map<String, String>? characterIds,
    Map<String, Map<String, LeaderboardEntry>>? playerBestsByBoard,
    Map<String, List<LeaderboardEntry>>? top10Views,
    this.top10WriteConflictsRemaining = 0,
    this.top10WriteFailuresRemaining = 0,
  }) : validatedRuns = validatedRuns ?? <String, ValidatedRun>{},
       displayNames = displayNames ?? <String, String>{},
       characterIds = characterIds ?? <String, String>{},
       playerBestsByBoard =
           playerBestsByBoard ?? <String, Map<String, LeaderboardEntry>>{},
       top10Views = top10Views ?? <String, List<LeaderboardEntry>>{};

  final Map<String, ValidatedRun> validatedRuns;
  final Map<String, String> displayNames;
  final Map<String, String> characterIds;
  final Map<String, Map<String, LeaderboardEntry>> playerBestsByBoard;
  final Map<String, List<LeaderboardEntry>> top10Views;

  final List<LeaderboardEntry> upsertedEntries = <LeaderboardEntry>[];
  final List<String> top10Writes = <String>[];
  int top10WriteConflictsRemaining;
  int top10WriteFailuresRemaining;
  int top10WriteAttempts = 0;

  @override
  Future<ValidatedRun?> loadValidatedRun({required String runSessionId}) async {
    return validatedRuns[runSessionId];
  }

  @override
  Future<String?> loadDisplayName({required String uid}) async {
    return displayNames[uid];
  }

  @override
  Future<String?> loadCharacterId({required String runSessionId}) async {
    return characterIds[runSessionId];
  }

  @override
  Future<PlayerBestWriteResult> replacePlayerBestIfBetter({
    required LeaderboardEntry candidate,
  }) async {
    final existing = playerBestsByBoard[candidate.boardId]?[candidate.uid];
    if (existing != null &&
        existing.sortKey.compareTo(candidate.sortKey) <= 0) {
      return PlayerBestWriteResult.unchanged;
    }
    final board =
        playerBestsByBoard[candidate.boardId] ?? <String, LeaderboardEntry>{};
    board[candidate.uid] = candidate;
    playerBestsByBoard[candidate.boardId] = board;
    upsertedEntries.add(candidate);
    return PlayerBestWriteResult.improved;
  }

  @override
  Future<Top10ViewSnapshot> loadTop10View({required String boardId}) async {
    return Top10ViewSnapshot(
      entries: List<LeaderboardEntry>.from(
        top10Views[boardId] ?? const <LeaderboardEntry>[],
      ),
      exists: top10Views.containsKey(boardId),
      updateTime: top10Views.containsKey(boardId)
          ? 'version-${top10Writes.length}'
          : null,
    );
  }

  @override
  Future<List<LeaderboardEntry>> listTopPlayerBests({
    required String boardId,
    required int limit,
  }) async {
    final values =
        (playerBestsByBoard[boardId] ?? const <String, LeaderboardEntry>{})
            .values
            .toList(growable: false)
          ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    if (values.length <= limit) {
      return values;
    }
    return values.sublist(0, limit);
  }

  @override
  Future<void> setPlayerBestGhostEligible({
    required String boardId,
    required String uid,
    required bool ghostEligible,
    required int nowMs,
  }) async {
    final existing = playerBestsByBoard[boardId]?[uid];
    if (existing == null) {
      return;
    }
    playerBestsByBoard[boardId]![uid] = _copyEntry(
      existing,
      ghostEligible: ghostEligible,
      updatedAtMs: nowMs,
    );
  }

  @override
  Future<bool> writeTop10View({
    required String boardId,
    required List<LeaderboardEntry> entries,
    required int updatedAtMs,
    required Top10ViewSnapshot expected,
  }) async {
    top10WriteAttempts += 1;
    if (top10WriteFailuresRemaining > 0) {
      top10WriteFailuresRemaining -= 1;
      throw StateError('injected top10 write failure');
    }
    if (top10WriteConflictsRemaining > 0) {
      top10WriteConflictsRemaining -= 1;
      return false;
    }
    top10Views[boardId] = entries
        .map((entry) => _copyEntry(entry, updatedAtMs: updatedAtMs))
        .toList(growable: false);
    top10Writes.add(boardId);
    return true;
  }
}
