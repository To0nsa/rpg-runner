import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/leaderboard_entry.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/sort_key.dart';
import 'package:run_protocol/validated_run.dart';
import 'package:test/test.dart';

import 'package:replay_validator/src/leaderboard_projector.dart';

void main() {
  test(
    'materialized revision excludes timestamps and binds payload fields',
    () {
      final entry = _entry(
        boardId: 'board_revision',
        runSessionId: 'run_revision',
        uid: 'uid_revision',
        displayName: 'Revision Player',
        score: 1200,
        distanceMeters: 400,
        durationSeconds: 100,
        updatedAtMs: 1000,
        ghostEligible: true,
      );
      final first = buildLeaderboardTop10MaterializedRevision(
        boardId: entry.boardId,
        entries: <LeaderboardEntry>[entry],
      );
      final timestampOnly = buildLeaderboardTop10MaterializedRevision(
        boardId: entry.boardId,
        entries: <LeaderboardEntry>[_copyEntry(entry, updatedAtMs: 9000)],
      );
      final changedEvidence = buildLeaderboardTop10MaterializedRevision(
        boardId: entry.boardId,
        entries: <LeaderboardEntry>[
          _copyEntry(
            entry,
            replayDigest: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          ),
        ],
      );
      final changedReference = buildLeaderboardTop10MaterializedRevision(
        boardId: entry.boardId,
        entries: <LeaderboardEntry>[
          _copyEntry(
            entry,
            replayStorageRef:
                'replay-submissions/validated/run_revision_v2/replay.bin.gz',
          ),
        ],
      );
      final changedGeneration = buildLeaderboardTop10MaterializedRevision(
        boardId: entry.boardId,
        entries: <LeaderboardEntry>[
          _copyEntry(entry, replayStorageGeneration: '124'),
        ],
      );
      final changedDisplayName = buildLeaderboardTop10MaterializedRevision(
        boardId: entry.boardId,
        entries: <LeaderboardEntry>[
          _copyEntry(entry, displayName: 'Renamed Player'),
        ],
      );

      expect(first, hasLength(64));
      expect(timestampOnly, first);
      expect(changedEvidence, isNot(first));
      expect(changedReference, isNot(first));
      expect(changedGeneration, isNot(first));
      expect(changedDisplayName, isNot(first));
    },
  );

  test('empty board materialization is a no-op after convergence', () async {
    const boardId = 'board_empty';
    var nowMs = 1000;
    final store = _InMemoryLeaderboardProjectionStore();
    final projector = FirestoreLeaderboardProjector(
      projectId: 'demo-project',
      store: store,
      clockMs: () => nowMs,
    );

    await projector.reconcileBoard(boardId: boardId);
    nowMs = 2000;
    await projector.reconcileBoard(boardId: boardId);

    expect(store.top10WriteAttempts, 1);
    expect(store.top10Writes, <String>[boardId]);
    expect(store.top10UpdatedAtMsByBoard[boardId], 1000);
    expect(store.eligibilityWrites, isEmpty);
  });

  test('unchanged populated board performs no second-pass writes', () async {
    const boardId = 'board_unchanged';
    final entry = _entry(
      boardId: boardId,
      runSessionId: 'run_unchanged',
      uid: 'uid_unchanged',
      displayName: 'Unchanged Player',
      score: 1200,
      distanceMeters: 400,
      durationSeconds: 100,
      updatedAtMs: 500,
    );
    var nowMs = 1000;
    final store = _InMemoryLeaderboardProjectionStore(
      playerBestsByBoard: <String, Map<String, LeaderboardEntry>>{
        boardId: <String, LeaderboardEntry>{entry.uid: entry},
      },
    );
    final projector = FirestoreLeaderboardProjector(
      projectId: 'demo-project',
      store: store,
      clockMs: () => nowMs,
    );

    await projector.reconcileBoard(boardId: boardId);
    final convergedBestUpdatedAtMs =
        store.playerBestsByBoard[boardId]![entry.uid]!.updatedAtMs;
    nowMs = 2000;
    await projector.reconcileBoard(boardId: boardId);

    expect(store.top10WriteAttempts, 1);
    expect(store.eligibilityWrites, <String>['$boardId/${entry.uid}:true']);
    expect(store.top10UpdatedAtMsByBoard[boardId], 1000);
    expect(
      store.playerBestsByBoard[boardId]![entry.uid]!.updatedAtMs,
      convergedBestUpdatedAtMs,
    );
  });

  test(
    'legacy top10 view is rewritten once under the current authority',
    () async {
      const boardId = 'board_legacy';
      final store = _InMemoryLeaderboardProjectionStore(
        top10Views: <String, List<LeaderboardEntry>>{
          boardId: <LeaderboardEntry>[],
        },
        legacySourceRevisionBoards: <String>{boardId},
      );
      final projector = FirestoreLeaderboardProjector(
        projectId: 'demo-project',
        store: store,
        clockMs: () => 1000,
      );

      await projector.reconcileBoard(boardId: boardId);
      await projector.reconcileBoard(boardId: boardId);

      expect(store.top10WriteAttempts, 1);
      expect(
        store.top10MaterializationVersionsByBoard[boardId],
        leaderboardTop10MaterializationSchemaVersion,
      );
      expect(store.top10MaterializedRevisionsByBoard[boardId], hasLength(64));
      expect(store.legacySourceRevisionBoards, isNot(contains(boardId)));
    },
  );

  test('wrong materialization version forces one safe rewrite', () async {
    const boardId = 'board_old_materialization';
    final desiredRevision = buildLeaderboardTop10MaterializedRevision(
      boardId: boardId,
      entries: const <LeaderboardEntry>[],
    );
    final store = _InMemoryLeaderboardProjectionStore(
      top10Views: <String, List<LeaderboardEntry>>{
        boardId: <LeaderboardEntry>[],
      },
      top10MaterializationVersionsByBoard: <String, int>{boardId: 0},
      top10MaterializedRevisionsByBoard: <String, String>{
        boardId: desiredRevision,
      },
    );
    final projector = FirestoreLeaderboardProjector(
      projectId: 'demo-project',
      store: store,
      clockMs: () => 1000,
    );

    await projector.reconcileBoard(boardId: boardId);
    await projector.reconcileBoard(boardId: boardId);

    expect(store.top10WriteAttempts, 1);
    expect(
      store.top10MaterializationVersionsByBoard[boardId],
      leaderboardTop10MaterializationSchemaVersion,
    );
  });

  test('hidden promoted generation change does not rewrite top10', () async {
    const boardId = 'board_hidden_manifest_evidence';
    final entry = _entry(
      boardId: boardId,
      runSessionId: 'run_hidden_manifest_evidence',
      uid: 'uid_hidden_manifest_evidence',
      displayName: 'Manifest Player',
      score: 1200,
      distanceMeters: 400,
      durationSeconds: 100,
      updatedAtMs: 500,
      ghostEligible: true,
    );
    final store = _InMemoryLeaderboardProjectionStore(
      playerBestsByBoard: <String, Map<String, LeaderboardEntry>>{
        boardId: <String, LeaderboardEntry>{entry.uid: entry},
      },
      activeGhostManifestsByBoard:
          <String, Map<String, ActiveGhostManifestEvidence>>{
            boardId: <String, ActiveGhostManifestEvidence>{
              entry.entryId: _activeGhostManifestEvidenceFor(entry),
            },
          },
    );
    final projector = FirestoreLeaderboardProjector(
      projectId: 'demo-project',
      store: store,
      clockMs: () => 1000,
    );

    await projector.reconcileBoard(boardId: boardId);
    store.activeGhostManifestsByBoard[boardId]![entry.entryId] =
        _activeGhostManifestEvidenceFor(
          entry,
          promotedReplayStorageGeneration: '789',
        );
    await projector.reconcileBoard(boardId: boardId);

    expect(store.top10WriteAttempts, 1);
    expect(store.top10Views[boardId]!.single.ghostAvailable, isTrue);
  });

  test('outgoing player with false eligibility is not rewritten', () async {
    const boardId = 'board_outgoing';
    final current = <LeaderboardEntry>[
      for (var i = 0; i < 10; i++)
        _entry(
          boardId: boardId,
          runSessionId: 'run_current_$i',
          uid: 'uid_current_$i',
          displayName: 'Current $i',
          score: 2000 - i,
          distanceMeters: 500 - i,
          durationSeconds: 100 + i,
          updatedAtMs: 500,
          ghostEligible: true,
        ),
    ];
    final outgoing = _entry(
      boardId: boardId,
      runSessionId: 'run_outgoing',
      uid: 'uid_outgoing',
      displayName: 'Outgoing',
      score: 100,
      distanceMeters: 100,
      durationSeconds: 200,
      updatedAtMs: 500,
    );
    final previous = <LeaderboardEntry>[
      for (var i = 0; i < 9; i++) _copyEntry(current[i], rank: i + 1),
      _copyEntry(outgoing, ghostEligible: true, rank: 10),
    ];
    final store = _InMemoryLeaderboardProjectionStore(
      playerBestsByBoard: <String, Map<String, LeaderboardEntry>>{
        boardId: <String, LeaderboardEntry>{
          for (final entry in <LeaderboardEntry>[...current, outgoing])
            entry.uid: entry,
        },
      },
      top10Views: <String, List<LeaderboardEntry>>{boardId: previous},
      top10MaterializationVersionsByBoard: <String, int>{
        boardId: leaderboardTop10MaterializationSchemaVersion,
      },
      top10MaterializedRevisionsByBoard: <String, String>{
        boardId: buildLeaderboardTop10MaterializedRevision(
          boardId: boardId,
          entries: previous,
        ),
      },
    );
    final projector = FirestoreLeaderboardProjector(
      projectId: 'demo-project',
      store: store,
      clockMs: () => 1000,
    );

    await projector.reconcileBoard(boardId: boardId);

    expect(store.eligibilityWrites, isEmpty);
    expect(store.playerBestsByBoard[boardId]![outgoing.uid]!.updatedAtMs, 500);
    expect(store.top10Writes, <String>[boardId]);
  });

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
      expect(top10[0].ghostAvailable, isFalse);
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
    'top10 ghost availability follows active exposed manifest state',
    () async {
      const boardId = 'board_ghost_availability';
      const runSessionId = 'run_available';
      final entry = _entry(
        boardId: boardId,
        runSessionId: runSessionId,
        uid: 'uid_player',
        displayName: 'Player One',
        score: 1200,
        distanceMeters: 400,
        durationSeconds: 100,
        updatedAtMs: 1000,
      );
      final store = _InMemoryLeaderboardProjectionStore(
        playerBestsByBoard: <String, Map<String, LeaderboardEntry>>{
          boardId: <String, LeaderboardEntry>{entry.uid: entry},
        },
        activeGhostManifestsByBoard:
            <String, Map<String, ActiveGhostManifestEvidence>>{
              boardId: <String, ActiveGhostManifestEvidence>{
                runSessionId: _activeGhostManifestEvidenceFor(entry),
              },
            },
      );
      final projector = FirestoreLeaderboardProjector(
        projectId: 'demo-project',
        store: store,
        clockMs: () => 8000,
      );

      await projector.reconcileBoard(boardId: boardId);

      expect(store.top10Views[boardId]!.single.ghostEligible, isTrue);
      expect(store.top10Views[boardId]!.single.ghostAvailable, isTrue);

      store.activeGhostManifestsByBoard[boardId] =
          <String, ActiveGhostManifestEvidence>{};
      await projector.reconcileBoard(boardId: boardId);

      expect(store.top10Views[boardId]!.single.ghostEligible, isTrue);
      expect(store.top10Views[boardId]!.single.ghostAvailable, isFalse);
    },
  );

  test(
    'top10 ignores active ghosts whose evidence differs from player best',
    () async {
      const boardId = 'board_ghost_mismatch';
      const runSessionId = 'run_available';
      final entry = _entry(
        boardId: boardId,
        runSessionId: runSessionId,
        uid: 'uid_player',
        displayName: 'Player One',
        score: 1200,
        distanceMeters: 400,
        durationSeconds: 100,
        updatedAtMs: 1000,
      );
      final mismatchedEvidence = _activeGhostManifestEvidenceFor(
        _copyEntry(
          entry,
          replayDigest:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
      );
      final store = _InMemoryLeaderboardProjectionStore(
        playerBestsByBoard: <String, Map<String, LeaderboardEntry>>{
          boardId: <String, LeaderboardEntry>{entry.uid: entry},
        },
        activeGhostManifestsByBoard:
            <String, Map<String, ActiveGhostManifestEvidence>>{
              boardId: <String, ActiveGhostManifestEvidence>{
                runSessionId: mismatchedEvidence,
              },
            },
      );
      final projector = FirestoreLeaderboardProjector(
        projectId: 'demo-project',
        store: store,
        clockMs: () => 8000,
      );

      await projector.reconcileBoard(boardId: boardId);

      expect(store.top10Views[boardId]!.single.ghostAvailable, isFalse);
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
  bool ghostAvailable = false,
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
    ghostAvailable: ghostAvailable,
    replayStorageRef:
        'replay-submissions/validated/$runSessionId/replay.bin.gz',
    replayStorageGeneration: '123',
    replayDigest:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    updatedAtMs: updatedAtMs,
  );
}

ActiveGhostManifestEvidence _activeGhostManifestEvidenceFor(
  LeaderboardEntry entry, {
  String promotedReplayStorageGeneration = '456',
}) {
  return ActiveGhostManifestEvidence(
    boardId: entry.boardId,
    entryId: entry.entryId,
    runSessionId: entry.runSessionId,
    uid: entry.uid,
    replayStorageRef: 'ghosts/${entry.boardId}/${entry.entryId}/ghost.bin.gz',
    sourceReplayStorageRef: entry.replayStorageRef!,
    sourceReplayStorageGeneration: entry.replayStorageGeneration!,
    promotedReplayStorageGeneration: promotedReplayStorageGeneration,
    replayDigest: entry.replayDigest!,
  );
}

LeaderboardEntry _copyEntry(
  LeaderboardEntry source, {
  bool? ghostEligible,
  bool? ghostAvailable,
  int? updatedAtMs,
  int? rank,
  String? replayDigest,
  String? replayStorageRef,
  String? replayStorageGeneration,
  String? displayName,
}) {
  return LeaderboardEntry(
    boardId: source.boardId,
    entryId: source.entryId,
    runSessionId: source.runSessionId,
    uid: source.uid,
    displayName: displayName ?? source.displayName,
    characterId: source.characterId,
    score: source.score,
    distanceMeters: source.distanceMeters,
    durationSeconds: source.durationSeconds,
    sortKey: source.sortKey,
    ghostEligible: ghostEligible ?? source.ghostEligible,
    ghostAvailable: ghostAvailable ?? source.ghostAvailable,
    replayStorageRef: replayStorageRef ?? source.replayStorageRef,
    replayStorageGeneration:
        replayStorageGeneration ?? source.replayStorageGeneration,
    replayDigest: replayDigest ?? source.replayDigest,
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
    Map<String, Map<String, ActiveGhostManifestEvidence>>?
    activeGhostManifestsByBoard,
    Map<String, int>? top10MaterializationVersionsByBoard,
    Map<String, String>? top10MaterializedRevisionsByBoard,
    Map<String, int>? top10UpdatedAtMsByBoard,
    Set<String>? legacySourceRevisionBoards,
    this.top10WriteConflictsRemaining = 0,
    this.top10WriteFailuresRemaining = 0,
  }) : validatedRuns = validatedRuns ?? <String, ValidatedRun>{},
       displayNames = displayNames ?? <String, String>{},
       characterIds = characterIds ?? <String, String>{},
       playerBestsByBoard =
           playerBestsByBoard ?? <String, Map<String, LeaderboardEntry>>{},
       top10Views = top10Views ?? <String, List<LeaderboardEntry>>{},
       activeGhostManifestsByBoard =
           activeGhostManifestsByBoard ??
           <String, Map<String, ActiveGhostManifestEvidence>>{},
       top10MaterializationVersionsByBoard =
           top10MaterializationVersionsByBoard ?? <String, int>{},
       top10MaterializedRevisionsByBoard =
           top10MaterializedRevisionsByBoard ?? <String, String>{},
       top10UpdatedAtMsByBoard = top10UpdatedAtMsByBoard ?? <String, int>{},
       legacySourceRevisionBoards = legacySourceRevisionBoards ?? <String>{};

  final Map<String, ValidatedRun> validatedRuns;
  final Map<String, String> displayNames;
  final Map<String, String> characterIds;
  final Map<String, Map<String, LeaderboardEntry>> playerBestsByBoard;
  final Map<String, List<LeaderboardEntry>> top10Views;
  final Map<String, Map<String, ActiveGhostManifestEvidence>>
  activeGhostManifestsByBoard;
  final Map<String, int> top10MaterializationVersionsByBoard;
  final Map<String, String> top10MaterializedRevisionsByBoard;
  final Map<String, int> top10UpdatedAtMsByBoard;
  final Set<String> legacySourceRevisionBoards;

  final List<LeaderboardEntry> upsertedEntries = <LeaderboardEntry>[];
  final List<String> top10Writes = <String>[];
  final List<String> eligibilityWrites = <String>[];
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
      materializationSchemaVersion:
          top10MaterializationVersionsByBoard[boardId],
      materializedRevision: top10MaterializedRevisionsByBoard[boardId],
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
  Future<Map<String, ActiveGhostManifestEvidence>> loadActiveGhostManifests({
    required String boardId,
  }) async => Map<String, ActiveGhostManifestEvidence>.from(
    activeGhostManifestsByBoard[boardId] ??
        const <String, ActiveGhostManifestEvidence>{},
  );

  @override
  Future<bool> setPlayerBestGhostEligibleIfChanged({
    required String boardId,
    required String uid,
    required bool ghostEligible,
    required int nowMs,
  }) async {
    final existing = playerBestsByBoard[boardId]?[uid];
    if (existing == null) {
      return false;
    }
    if (existing.ghostEligible == ghostEligible) {
      return false;
    }
    playerBestsByBoard[boardId]![uid] = _copyEntry(
      existing,
      ghostEligible: ghostEligible,
      updatedAtMs: nowMs,
    );
    eligibilityWrites.add('$boardId/$uid:$ghostEligible');
    return true;
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
    top10MaterializationVersionsByBoard[boardId] =
        leaderboardTop10MaterializationSchemaVersion;
    top10MaterializedRevisionsByBoard[boardId] =
        buildLeaderboardTop10MaterializedRevision(
          boardId: boardId,
          entries: entries,
        );
    top10UpdatedAtMsByBoard[boardId] = updatedAtMs;
    legacySourceRevisionBoards.remove(boardId);
    top10Writes.add(boardId);
    return true;
  }
}
