import 'dart:convert';

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/leaderboard_entry.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/sort_key.dart';
import 'package:run_protocol/validated_run.dart';
import 'package:test/test.dart';

import 'package:replay_validator/src/account_deletion_fence.dart';
import 'package:replay_validator/src/ghost_publisher.dart';
import 'package:replay_validator/src/google_api_helpers.dart';

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
      expect(objectStore.promotions.single.sourceGeneration, '123');
      final manifest = store.manifestsByBoard[boardId]![runSessionId]!;
      expect(manifest.status, GhostManifestStatus.active);
      expect(manifest.exposed, isTrue);
      expect(
        manifest.replayStorageRef,
        'ghosts/$boardId/$runSessionId/ghost.bin.gz',
      );
      expect(manifest.sourceReplayStorageGeneration, '123');
      expect(manifest.promotedReplayStorageGeneration, '456');
      expect(manifest.replayDigest, 'a' * 64);
    },
  );

  test(
    'removes a newly promoted ghost when deletion fences its manifest',
    () async {
      const boardId = 'board_competitive_2026_03_field';
      const runSessionId = 'run_deleted';
      final store = _InMemoryGhostPublicationStore(
        validatedRuns: <String, ValidatedRun>{
          runSessionId: _validatedRun(
            runSessionId: runSessionId,
            uid: 'uid_deleted',
            boardId: boardId,
            replayStorageRef:
                'replay-submissions/pending/uid_deleted/run_deleted/replay.bin.gz',
          ),
        },
        top10EntriesByBoard: <String, List<LeaderboardEntry>>{
          boardId: <LeaderboardEntry>[
            _entry(
              boardId: boardId,
              runSessionId: runSessionId,
              uid: 'uid_deleted',
              score: 1200,
              distanceMeters: 420,
              durationSeconds: 120,
              replayStorageRef:
                  'replay-submissions/pending/uid_deleted/run_deleted/replay.bin.gz',
              rank: 1,
            ),
          ],
        },
      )..upsertError = const AccountDeletionInProgressException('uid_deleted');
      final objectStore = _InMemoryGhostObjectStore();
      final publisher = FirestoreGhostPublisher(
        projectId: 'demo',
        replayStorageBucket: 'bucket',
        publicationStore: store,
        objectStore: objectStore,
        clockMs: () => 10_000,
      );

      await expectLater(
        publisher.updateGhostArtifacts(runSessionId: runSessionId),
        throwsA(isA<AccountDeletionInProgressException>()),
      );

      expect(objectStore.deletions, <String>[
        'ghosts/$boardId/$runSessionId/ghost.bin.gz',
      ]);
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

  test(
    'reconciliation accepts a pinned active ghost after source cleanup',
    () async {
      const boardId = 'board_competitive_2026_03_field';
      const runSessionId = 'run_retained_ghost';
      final entry = _entry(
        boardId: boardId,
        runSessionId: runSessionId,
        uid: 'uid_1',
        score: 1200,
        distanceMeters: 420,
        durationSeconds: 120,
        replayStorageRef: 'replay-submissions/validated/$runSessionId.bin.gz',
        rank: 1,
      );
      final objectStore = _InMemoryGhostObjectStore()
        ..addGhostObject(
          objectPath: 'ghosts/$boardId/$runSessionId/ghost.bin.gz',
          storageGeneration: '456',
        );
      final store = _InMemoryGhostPublicationStore(
        top10EntriesByBoard: <String, List<LeaderboardEntry>>{
          boardId: <LeaderboardEntry>[entry],
        },
        manifestsByBoard: <String, Map<String, GhostManifestRecord>>{
          boardId: <String, GhostManifestRecord>{
            runSessionId: GhostManifestRecord(
              boardId: boardId,
              entryId: runSessionId,
              runSessionId: runSessionId,
              uid: 'uid_1',
              replayStorageRef: 'ghosts/$boardId/$runSessionId/ghost.bin.gz',
              sourceReplayStorageRef:
                  'replay-submissions/validated/$runSessionId.bin.gz',
              sourceReplayStorageGeneration: '123',
              promotedReplayStorageGeneration: '456',
              replayDigest: 'a' * 64,
              score: 1200,
              distanceMeters: 420,
              durationSeconds: 120,
              sortKey: entry.sortKey,
              rank: 1,
              status: GhostManifestStatus.active,
              exposed: true,
              updatedAtMs: 5_000,
              promotedAtMs: 5_000,
            ),
          },
        },
      );
      final publisher = FirestoreGhostPublisher(
        projectId: 'demo',
        replayStorageBucket: 'bucket',
        publicationStore: store,
        objectStore: objectStore,
        clockMs: () => 10_000,
      );

      await publisher.reconcileBoard(boardId: boardId);

      expect(objectStore.promotions, isEmpty);
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

  test('empty top10 demotes previously exposed ghosts', () async {
    const boardId = 'board_competitive_2026_03_field';
    final store = _InMemoryGhostPublicationStore(
      manifestsByBoard: <String, Map<String, GhostManifestRecord>>{
        boardId: <String, GhostManifestRecord>{
          'run_old': _activeManifest(boardId: boardId, runSessionId: 'run_old'),
        },
      },
    );
    final publisher = FirestoreGhostPublisher(
      projectId: 'demo',
      replayStorageBucket: 'bucket',
      publicationStore: store,
      objectStore: _InMemoryGhostObjectStore(),
      clockMs: () => 20_000,
    );

    await publisher.reconcileBoard(boardId: boardId);

    final manifest = store.manifestsByBoard[boardId]!['run_old']!;
    expect(manifest.status, GhostManifestStatus.demoted);
    expect(manifest.exposed, isFalse);
    expect(manifest.demotedAtMs, 20_000);
  });

  test('ghost copy pins source and destination generations', () async {
    late http.Request copyRequest;
    final client = MockClient((request) async {
      copyRequest = request;
      return http.Response(
        jsonEncode(<String, Object?>{'generation': '456'}),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    final objectStore = GoogleCloudStorageGhostObjectStore(
      bucketName: 'bucket',
      apiProvider: _StorageApiProvider(storage.StorageApi(client)),
    );

    final result = await objectStore.promoteReplayToGhost(
      sourceObjectPath: 'replays/run_1.bin.gz',
      sourceStorageGeneration: '123',
      destinationObjectPath: 'ghosts/board/run_1/ghost.bin.gz',
    );

    expect(result.destinationStorageGeneration, '456');
    expect(copyRequest.url.queryParameters['sourceGeneration'], '123');
    expect(copyRequest.url.queryParameters['ifSourceGenerationMatch'], '123');
    expect(copyRequest.url.queryParameters['ifGenerationMatch'], '0');
  });

  test(
    'ghost copy rejects an existing object with different evidence',
    () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount += 1;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{
                'code': 412,
                'message': 'destination exists',
                'status': 'PRECONDITION_FAILED',
              },
            }),
            412,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        final isSource = request.url.path.contains('replays%2Frun_1.bin.gz');
        return http.Response(
          jsonEncode(<String, Object?>{
            'generation': isSource ? '123' : '999',
            'size': '10',
            'crc32c': isSource ? 'source-crc' : 'other-crc',
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });
      final objectStore = GoogleCloudStorageGhostObjectStore(
        bucketName: 'bucket',
        apiProvider: _StorageApiProvider(storage.StorageApi(client)),
      );

      await expectLater(
        objectStore.promoteReplayToGhost(
          sourceObjectPath: 'replays/run_1.bin.gz',
          sourceStorageGeneration: '123',
          destinationObjectPath: 'ghosts/board/run_1/ghost.bin.gz',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('manifest repository follows every Firestore page token', () async {
    final requestedPageTokens = <String?>[];
    final client = MockClient((request) async {
      requestedPageTokens.add(request.url.queryParameters['pageToken']);
      final pageToken = request.url.queryParameters['pageToken'];
      return http.Response(
        jsonEncode(<String, Object?>{
          'documents': <Object?>[
            _manifestDocumentJson(
              entryId: pageToken == null ? 'run_1' : 'run_2',
            ),
          ],
          if (pageToken == null) 'nextPageToken': 'page-2',
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    final store = FirestoreGhostPublicationStore(
      projectId: 'demo',
      apiProvider: _FirestoreApiProvider(firestore.FirestoreApi(client)),
    );

    final manifests = await store.listGhostManifests(boardId: 'board_1');

    expect(manifests.map((manifest) => manifest.entryId), <String>[
      'run_1',
      'run_2',
    ]);
    expect(requestedPageTokens, <String?>[null, 'page-2']);
  });
}

GhostManifestRecord _activeManifest({
  required String boardId,
  required String runSessionId,
}) {
  return GhostManifestRecord(
    boardId: boardId,
    entryId: runSessionId,
    runSessionId: runSessionId,
    uid: 'uid_old',
    replayStorageRef: 'ghosts/$boardId/$runSessionId/ghost.bin.gz',
    sourceReplayStorageRef:
        'replay-submissions/pending/uid_old/$runSessionId/replay.bin.gz',
    sourceReplayStorageGeneration: '123',
    promotedReplayStorageGeneration: '456',
    replayDigest: 'a' * 64,
    score: 1000,
    distanceMeters: 390,
    durationSeconds: 140,
    sortKey: buildLeaderboardSortKey(
      score: 1000,
      distanceMeters: 390,
      durationSeconds: 140,
      entryId: runSessionId,
    ),
    rank: 1,
    status: GhostManifestStatus.active,
    exposed: true,
    updatedAtMs: 5_000,
    promotedAtMs: 5_000,
  );
}

Map<String, Object?> _manifestDocumentJson({required String entryId}) {
  Map<String, Object?> stringValue(String value) => <String, Object?>{
    'stringValue': value,
  };
  Map<String, Object?> integerValue(int value) => <String, Object?>{
    'integerValue': '$value',
  };
  return <String, Object?>{
    'name':
        'projects/demo/databases/(default)/documents/'
        'leaderboard_boards/board_1/ghost_manifests/$entryId',
    'fields': <String, Object?>{
      'boardId': stringValue('board_1'),
      'entryId': stringValue(entryId),
      'runSessionId': stringValue(entryId),
      'uid': stringValue('uid_1'),
      'replayStorageRef': stringValue('ghosts/board_1/$entryId/ghost.bin.gz'),
      'sourceReplayStorageRef': stringValue(
        'replay-submissions/pending/uid_1/$entryId/replay.bin.gz',
      ),
      'score': integerValue(1000),
      'distanceMeters': integerValue(400),
      'durationSeconds': integerValue(120),
      'sortKey': stringValue('0001:$entryId'),
      'rank': integerValue(1),
      'status': stringValue('active'),
      'exposed': <String, Object?>{'booleanValue': true},
      'updatedAtMs': integerValue(1),
    },
  };
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
    boardKey: BoardKey(
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
    replayStorageGeneration: '123',
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
    replayStorageGeneration: '123',
    replayDigest: 'a' * 64,
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
  Object? upsertError;

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
    final error = upsertError;
    if (error != null) {
      throw error;
    }
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
  final Set<String> _objects = <String>{};

  void addGhostObject({
    required String objectPath,
    required String storageGeneration,
  }) {
    _objects.add('$objectPath#$storageGeneration');
  }

  @override
  Future<GhostPromotionResult> promoteReplayToGhost({
    required String sourceObjectPath,
    required String sourceStorageGeneration,
    required String destinationObjectPath,
  }) async {
    promotions.add(
      _Promotion(
        source: sourceObjectPath,
        sourceGeneration: sourceStorageGeneration,
        destination: destinationObjectPath,
      ),
    );
    addGhostObject(objectPath: destinationObjectPath, storageGeneration: '456');
    return const GhostPromotionResult(destinationStorageGeneration: '456');
  }

  @override
  Future<bool> hasGhostObject({
    required String objectPath,
    required String storageGeneration,
  }) async => _objects.contains('$objectPath#$storageGeneration');

  @override
  Future<void> deleteGhostObject({required String objectPath}) async {
    deletions.add(objectPath);
  }
}

class _Promotion {
  const _Promotion({
    required this.source,
    required this.sourceGeneration,
    required this.destination,
  });

  final String source;
  final String sourceGeneration;
  final String destination;
}

final class _StorageApiProvider extends GoogleCloudApiProvider {
  _StorageApiProvider(this.api);

  final storage.StorageApi api;

  @override
  Future<storage.StorageApi> storageApi() async => api;
}

final class _FirestoreApiProvider extends GoogleCloudApiProvider {
  _FirestoreApiProvider(this.api);

  final firestore.FirestoreApi api;

  @override
  Future<firestore.FirestoreApi> firestoreApi() async => api;
}
