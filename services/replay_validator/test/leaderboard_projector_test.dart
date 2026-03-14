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
    expect(store.top10Writes, isEmpty);
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
    boardKey: const BoardKey(
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
  Future<LeaderboardEntry?> loadPlayerBest({
    required String boardId,
    required String uid,
  }) async {
    return playerBestsByBoard[boardId]?[uid];
  }

  @override
  Future<void> upsertPlayerBest({required LeaderboardEntry entry}) async {
    final board =
        playerBestsByBoard[entry.boardId] ?? <String, LeaderboardEntry>{};
    board[entry.uid] = entry;
    playerBestsByBoard[entry.boardId] = board;
    upsertedEntries.add(entry);
  }

  @override
  Future<List<LeaderboardEntry>> loadTop10ViewEntries({
    required String boardId,
  }) async {
    return List<LeaderboardEntry>.from(
      top10Views[boardId] ?? const <LeaderboardEntry>[],
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
  Future<void> writeTop10View({
    required String boardId,
    required List<LeaderboardEntry> entries,
    required int updatedAtMs,
  }) async {
    top10Views[boardId] = entries
        .map((entry) => _copyEntry(entry, updatedAtMs: updatedAtMs))
        .toList(growable: false);
    top10Writes.add(boardId);
  }
}
