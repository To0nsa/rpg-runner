import 'dart:convert';

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:run_protocol/leaderboard_entry.dart';
import 'package:test/test.dart';

import 'package:replay_validator/src/firestore_value_codec.dart';
import 'package:replay_validator/src/google_api_helpers.dart';
import 'package:replay_validator/src/leaderboard_projector.dart';

void main() {
  test('unchanged player best rolls back its read transaction', () async {
    const transactionId = 'dGVzdC10cmFuc2FjdGlvbg==';
    final existing = _entry(score: 1200, sortKey: '0001');
    final candidate = _entry(score: 1100, sortKey: '0002');
    var rollbackCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/documents:beginTransaction')) {
        return _jsonResponse(<String, Object?>{'transaction': transactionId});
      }
      if (request.method == 'GET' &&
          request.url.path.contains('/account_deletion_requests/')) {
        return _notFoundResponse();
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/player_bests/uid_player')) {
        return _jsonResponse(
          firestore.Document(
            name: request.url.path.substring(4),
            fields: encodeFirestoreFields(existing.toJson()),
          ).toJson(),
        );
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/documents:rollback')) {
        rollbackCalls += 1;
        expect(jsonDecode(request.body), <String, Object?>{
          'transaction': transactionId,
        });
        return _jsonResponse(const <String, Object?>{});
      }
      fail('Unexpected ${request.method} ${request.url}');
    });
    final store = FirestoreLeaderboardProjectionStore(
      projectId: 'test-project',
      apiProvider: _FirestoreApiProvider(firestore.FirestoreApi(client)),
    );

    final result = await store.replacePlayerBestIfBetter(candidate: candidate);

    expect(result, PlayerBestWriteResult.unchanged);
    expect(rollbackCalls, 1);
  });

  test('unchanged ghost eligibility rolls back without a write', () async {
    const transactionId = 'dGVzdC10cmFuc2FjdGlvbg==';
    final existing = _entry(score: 1200, sortKey: '0001');
    var rollbackCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/documents:beginTransaction')) {
        return _jsonResponse(<String, Object?>{'transaction': transactionId});
      }
      if (request.method == 'GET' &&
          request.url.path.contains('/account_deletion_requests/')) {
        return _notFoundResponse();
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/player_bests/uid_player')) {
        return _jsonResponse(
          firestore.Document(
            name: request.url.path.substring(4),
            fields: encodeFirestoreFields(existing.toJson()),
            updateTime: '2026-09-01T00:00:00Z',
          ).toJson(),
        );
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/documents:rollback')) {
        rollbackCalls += 1;
        return _jsonResponse(const <String, Object?>{});
      }
      fail('Unexpected ${request.method} ${request.url}');
    });
    final store = FirestoreLeaderboardProjectionStore(
      projectId: 'test-project',
      apiProvider: _FirestoreApiProvider(firestore.FirestoreApi(client)),
    );

    final changed = await store.setPlayerBestGhostEligibleIfChanged(
      boardId: existing.boardId,
      uid: existing.uid,
      ghostEligible: true,
      nowMs: 2000,
    );

    expect(changed, isFalse);
    expect(rollbackCalls, 1);
  });

  test('top10 snapshot decodes current materialization authority', () async {
    const revision =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/views/top10')) {
        return _jsonResponse(
          firestore.Document(
            name: request.url.path.substring(4),
            fields: encodeFirestoreFields(<String, Object?>{
              'boardId': 'board_competitive_2026_03_forest',
              'entries': const <Object?>[],
              'materializationSchemaVersion':
                  leaderboardTop10MaterializationSchemaVersion,
              'materializedRevision': revision,
              'updatedAtMs': 1000,
            }),
            updateTime: '2026-09-01T00:00:00Z',
          ).toJson(),
        );
      }
      fail('Unexpected ${request.method} ${request.url}');
    });
    final store = FirestoreLeaderboardProjectionStore(
      projectId: 'test-project',
      apiProvider: _FirestoreApiProvider(firestore.FirestoreApi(client)),
    );

    final snapshot = await store.loadTop10View(
      boardId: 'board_competitive_2026_03_forest',
    );

    expect(snapshot.exists, isTrue);
    expect(snapshot.entries, isEmpty);
    expect(
      snapshot.materializationSchemaVersion,
      leaderboardTop10MaterializationSchemaVersion,
    );
    expect(snapshot.materializedRevision, revision);
  });

  test(
    'top10 write persists current authority and removes legacy revision',
    () async {
      const transactionId = 'dGVzdC10cmFuc2FjdGlvbg==';
      Map<String, Object?>? committedBody;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/documents:beginTransaction')) {
          return _jsonResponse(<String, Object?>{'transaction': transactionId});
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/documents:commit')) {
          committedBody = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          return _jsonResponse(const <String, Object?>{});
        }
        fail('Unexpected ${request.method} ${request.url}');
      });
      final store = FirestoreLeaderboardProjectionStore(
        projectId: 'test-project',
        apiProvider: _FirestoreApiProvider(firestore.FirestoreApi(client)),
      );

      final committed = await store.writeTop10View(
        boardId: 'board_competitive_2026_03_forest',
        entries: const <LeaderboardEntry>[],
        updatedAtMs: 2000,
        expected: const Top10ViewSnapshot.missing(),
      );

      expect(committed, isTrue);
      final writes = committedBody!['writes']! as List;
      final write = Map<String, Object?>.from(writes.single as Map);
      final update = Map<String, Object?>.from(write['update']! as Map);
      final fields = Map<String, Object?>.from(update['fields']! as Map);
      final updateMask = Map<String, Object?>.from(write['updateMask']! as Map);
      expect(fields, contains('materializationSchemaVersion'));
      expect(fields, contains('materializedRevision'));
      expect(fields, isNot(contains('sourceRevision')));
      expect(updateMask['fieldPaths'], contains('sourceRevision'));
    },
  );
}

LeaderboardEntry _entry({required int score, required String sortKey}) {
  return LeaderboardEntry(
    boardId: 'board_competitive_2026_03_forest',
    entryId: 'run_best',
    runSessionId: 'run_best',
    uid: 'uid_player',
    displayName: 'Player One',
    characterId: 'eloise',
    score: score,
    distanceMeters: 500,
    durationSeconds: 120,
    sortKey: sortKey,
    ghostEligible: true,
    replayStorageRef: 'replay-submissions/validated/run_best.json',
    replayStorageGeneration: '1',
    replayDigest: 'a' * 64,
    updatedAtMs: 1000,
  );
}

final class _FirestoreApiProvider extends GoogleCloudApiProvider {
  _FirestoreApiProvider(this.api);

  final firestore.FirestoreApi api;

  @override
  Future<firestore.FirestoreApi> firestoreApi() async => api;
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

http.Response _notFoundResponse() {
  return _jsonResponse(<String, Object?>{
    'error': <String, Object?>{
      'code': 404,
      'message': 'not found',
      'status': 'NOT_FOUND',
    },
  }, statusCode: 404);
}
