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
