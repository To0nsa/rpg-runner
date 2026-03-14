import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/leaderboard_entry.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/sort_key.dart';
import 'package:run_protocol/validated_run.dart';
import 'package:test/test.dart';

import 'package:replay_validator/src/ghost_publisher.dart';

void main() {
  test(
    'promotes top10 replay lineage to durable ghost manifest/object',
    () async {
      const boardId = 'board_competitive_2026_03_field';
      const runSessionId = 'run_top';
      final store = _InMemoryGhostPublicationStore(
        validatedRuns: <String, ValidatedRun>{
          runSessionId: _validatedRun(
            runSessionId: runSessionId,
            uid: 'uid_1',
            boardId: boardId,
            replayStorageRef:
                'replay-submissions/pending/uid_1/run_top/replay.bin.gz',
          ),
        },
        top10EntriesByBoard: <String, List<LeaderboardEntry>>{
          boardId: <LeaderboardEntry>[
            _entry(
              boardId: boardId,
              runSessionId: runSessionId,
              uid: 'uid_1',
              score: 1200,
              distanceMeters: 420,
              durationSeconds: 120,
              replayStorageRef:
                  'replay-submissions/pending/uid_1/run_top/replay.bin.gz',
              rank: 1,
            ),
          ],
        },
      );
      final objectStore = _InMemoryGhostObjectStore();
      final publisher = FirestoreGhostPublisher(
        projectId: 'demo',
        replayStorageBucket: 'bucket',
        publicationStore: store,
        objectStore: objectStore,
        clockMs: () => 10_000,
      );

      await publisher.updateGhostArtifacts(runSessionId: runSessionId);

      expect(objectStore.promotions, hasLength(1));
      expect(
        objectStore.promotions.single.source,
        'replay-submissions/pending/uid_1/run_top/replay.bin.gz',
      );
      expect(
        objectStore.promotions.single.destination,
        'ghosts/$boardId/$runSessionId/ghost.bin.gz',
      );
      final manifest = store.manifestsByBoard[boardId]![runSessionId]!;
      expect(manifest.status, GhostManifestStatus.active);
      expect(manifest.exposed, isTrue);
      expect(
        manifest.replayStorageRef,
        'ghosts/$boardId/$runSessionId/ghost.bin.gz',
      );
    },
  );

  test(
    'demotes previously active ghost when entry falls out of top10',
    () async {
      const boardId = 'board_competitive_2026_03_field';
      final store = _InMemoryGhostPublicationStore(
        validatedRuns: <String, ValidatedRun>{
          'run_new': _validatedRun(
            runSessionId: 'run_new',
            uid: 'uid_new',
            boardId: boardId,
            replayStorageRef:
                'replay-submissions/pending/uid_new/run_new/replay.bin.gz',
          ),
        },
        top10EntriesByBoard: <String, List<LeaderboardEntry>>{
          boardId: <LeaderboardEntry>[
            _entry(
              boardId: boardId,
              runSessionId: 'run_new',
              uid: 'uid_new',
              score: 1300,
              distanceMeters: 450,
              durationSeconds: 110,
              replayStorageRef:
                  'replay-submissions/pending/uid_new/run_new/replay.bin.gz',
              rank: 1,
            ),
          ],
        },
        manifestsByBoard: <String, Map<String, GhostManifestRecord>>{
          boardId: <String, GhostManifestRecord>{
            'run_old': GhostManifestRecord(
              boardId: boardId,
              entryId: 'run_old',
              runSessionId: 'run_old',
              uid: 'uid_old',
              replayStorageRef: 'ghosts/$boardId/run_old/ghost.bin.gz',
              sourceReplayStorageRef:
                  'replay-submissions/pending/uid_old/run_old/replay.bin.gz',
              score: 1000,
              distanceMeters: 390,
              durationSeconds: 140,
              sortKey: buildLeaderboardSortKey(
                score: 1000,
                distanceMeters: 390,
                durationSeconds: 140,
                entryId: 'run_old',
              ),
              rank: 1,
              status: GhostManifestStatus.active,
              exposed: true,
              updatedAtMs: 5_000,
              promotedAtMs: 5_000,
            ),
          },
        },
      );
      final objectStore = _InMemoryGhostObjectStore();
      final publisher = FirestoreGhostPublisher(
        projectId: 'demo',
        replayStorageBucket: 'bucket',
        publicationStore: store,
        objectStore: objectStore,
        clockMs: () => 20_000,
      );

      await publisher.updateGhostArtifacts(runSessionId: 'run_new');

      final demoted = store.manifestsByBoard[boardId]!['run_old']!;
      expect(demoted.status, GhostManifestStatus.demoted);
      expect(demoted.exposed, isFalse);
      expect(demoted.demotedAtMs, 20_000);
      expect(
        demoted.expiresAtMs,
        20_000 + const Duration(days: 7).inMilliseconds,
      );
    },
  );

  test('purges expired demoted ghosts and deletes durable object', () async {
    const boardId = 'board_competitive_2026_03_field';
    final store = _InMemoryGhostPublicationStore(
      validatedRuns: <String, ValidatedRun>{
        'run_new': _validatedRun(
          runSessionId: 'run_new',
          uid: 'uid_new',
          boardId: boardId,
          replayStorageRef:
              'replay-submissions/pending/uid_new/run_new/replay.bin.gz',
        ),
      },
      top10EntriesByBoard: <String, List<LeaderboardEntry>>{
        boardId: <LeaderboardEntry>[
          _entry(
            boardId: boardId,
            runSessionId: 'run_new',
            uid: 'uid_new',
            score: 1400,
            distanceMeters: 480,
            durationSeconds: 100,
            replayStorageRef:
                'replay-submissions/pending/uid_new/run_new/replay.bin.gz',
            rank: 1,
          ),
        ],
      },
      manifestsByBoard: <String, Map<String, GhostManifestRecord>>{
        boardId: <String, GhostManifestRecord>{
          'run_expired': GhostManifestRecord(
            boardId: boardId,
            entryId: 'run_expired',
            runSessionId: 'run_expired',
            uid: 'uid_old',
            replayStorageRef: 'ghosts/$boardId/run_expired/ghost.bin.gz',
            sourceReplayStorageRef:
                'replay-submissions/pending/uid_old/run_expired/replay.bin.gz',
            score: 900,
            distanceMeters: 350,
            durationSeconds: 180,
            sortKey: buildLeaderboardSortKey(
              score: 900,
              distanceMeters: 350,
              durationSeconds: 180,
              entryId: 'run_expired',
            ),
            rank: 9,
            status: GhostManifestStatus.demoted,
            exposed: false,
            updatedAtMs: 1_000,
            demotedAtMs: 1_000,
            expiresAtMs: 9_000,
          ),
        },
      },
    );
    final objectStore = _InMemoryGhostObjectStore();
    final publisher = FirestoreGhostPublisher(
      projectId: 'demo',
      replayStorageBucket: 'bucket',
      publicationStore: store,
      objectStore: objectStore,
      clockMs: () => 10_000,
    );

    await publisher.updateGhostArtifacts(runSessionId: 'run_new');

    expect(
      store.manifestsByBoard[boardId]!.containsKey('run_expired'),
      isFalse,
    );
    expect(objectStore.deletions, <String>[
      'ghosts/$boardId/run_expired/ghost.bin.gz',
    ]);
  });
}

ValidatedRun _validatedRun({
  required String runSessionId,
  required String uid,
  required String boardId,
  required String replayStorageRef,
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
    score: 1000,
    distanceMeters: 400,
    durationSeconds: 120,
    tick: 7200,
    endedReason: 'playerDied',
    goldEarned: 42,
    stats: const <String, Object?>{},
    replayDigest:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    replayStorageRef: replayStorageRef,
    createdAtMs: 1,
  );
}

LeaderboardEntry _entry({
  required String boardId,
  required String runSessionId,
  required String uid,
  required int score,
  required int distanceMeters,
  required int durationSeconds,
  required String replayStorageRef,
  required int rank,
}) {
  return LeaderboardEntry(
    boardId: boardId,
    entryId: runSessionId,
    runSessionId: runSessionId,
    uid: uid,
    displayName: uid,
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
    ghostEligible: true,
    replayStorageRef: replayStorageRef,
    updatedAtMs: 1,
    rank: rank,
  );
}

class _InMemoryGhostPublicationStore implements GhostPublicationStore {
  _InMemoryGhostPublicationStore({
    Map<String, ValidatedRun>? validatedRuns,
    Map<String, List<LeaderboardEntry>>? top10EntriesByBoard,
    Map<String, Map<String, GhostManifestRecord>>? manifestsByBoard,
  }) : validatedRuns = validatedRuns ?? <String, ValidatedRun>{},
       top10EntriesByBoard =
           top10EntriesByBoard ?? <String, List<LeaderboardEntry>>{},
       manifestsByBoard =
           manifestsByBoard ?? <String, Map<String, GhostManifestRecord>>{};

  final Map<String, ValidatedRun> validatedRuns;
  final Map<String, List<LeaderboardEntry>> top10EntriesByBoard;
  final Map<String, Map<String, GhostManifestRecord>> manifestsByBoard;

  @override
  Future<ValidatedRun?> loadValidatedRun({required String runSessionId}) async {
    return validatedRuns[runSessionId];
  }

  @override
  Future<List<LeaderboardEntry>> loadTop10Entries({
    required String boardId,
  }) async {
    return List<LeaderboardEntry>.from(
      top10EntriesByBoard[boardId] ?? const <LeaderboardEntry>[],
    );
  }

  @override
  Future<List<GhostManifestRecord>> listGhostManifests({
    required String boardId,
  }) async {
    return List<GhostManifestRecord>.from(
      (manifestsByBoard[boardId] ?? const <String, GhostManifestRecord>{})
          .values,
    );
  }

  @override
  Future<void> upsertGhostManifest({
    required GhostManifestRecord manifest,
  }) async {
    final board =
        manifestsByBoard[manifest.boardId] ?? <String, GhostManifestRecord>{};
    board[manifest.entryId] = manifest;
    manifestsByBoard[manifest.boardId] = board;
  }

  @override
  Future<void> deleteGhostManifest({
    required String boardId,
    required String entryId,
  }) async {
    manifestsByBoard[boardId]?.remove(entryId);
  }
}

class _InMemoryGhostObjectStore implements GhostObjectStore {
  final List<_Promotion> promotions = <_Promotion>[];
  final List<String> deletions = <String>[];

  @override
  Future<void> promoteReplayToGhost({
    required String sourceObjectPath,
    required String destinationObjectPath,
  }) async {
    promotions.add(
      _Promotion(source: sourceObjectPath, destination: destinationObjectPath),
    );
  }

  @override
  Future<void> deleteGhostObject({required String objectPath}) async {
    deletions.add(objectPath);
  }
}

class _Promotion {
  const _Promotion({required this.source, required this.destination});

  final String source;
  final String destination;
}
