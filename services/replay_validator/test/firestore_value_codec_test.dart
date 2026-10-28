import 'dart:convert';

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:replay_validator/src/firestore_value_codec.dart';
import 'package:replay_validator/src/ghost_publisher.dart';
import 'package:replay_validator/src/google_api_helpers.dart';
import 'package:replay_validator/src/leaderboard_projector.dart';
import 'package:test/test.dart';

void main() {
  test('empty REST map and array retain their value types', () {
    expect(
      decodeFirestoreValue(
        firestore.Value.fromJson({'mapValue': <String, dynamic>{}}),
      ),
      <String, Object?>{},
    );
    expect(
      decodeFirestoreValue(
        firestore.Value.fromJson({'arrayValue': <String, dynamic>{}}),
      ),
      <Object?>[],
    );
    expect(
      decodeFirestoreValue(firestore.Value.fromJson({'nullValue': null})),
      isNull,
    );
  });

  test('nested empty collections stay distinct from explicit null', () {
    final value = firestore.Value.fromJson({
      'mapValue': {
        'fields': {
          'list': {
            'arrayValue': {
              'values': [
                {'mapValue': <String, dynamic>{}},
                {'arrayValue': <String, dynamic>{}},
                {'nullValue': null},
              ],
            },
          },
        },
      },
    });
    expect(decodeFirestoreValue(value), {
      'list': [<String, Object?>{}, <Object?>[], null],
    });
  });

  test('projection stores read accepted runs with no enemy kills', () async {
    // The live staging failure had a valid Codex map with no kills. Firestore
    // omits the nested fields member when returning an empty map.
    final fields = encodeFirestoreFields({
      'runSessionId': 'run_empty_kills',
      'uid': 'test_player',
      'mode': 'competitive',
      'boardId': 'board_test',
      'boardKey': {
        'mode': 'competitive',
        'levelId': 'field',
        'windowId': '2026-10',
        'rulesetVersion': 'rules-v2',
        'scoreVersion': 'score-v4',
      },
      'accepted': true,
      'score': 685,
      'distanceMeters': 100,
      'durationSeconds': 17,
      'tick': 1047,
      'endedReason': 'fellIntoGap',
      'goldEarned': 2,
      'stats': {'collectibles': 2},
      'codex': {
        'schemaVersion': 1,
        'levelId': 'field',
        'enemyKills': <String, Object?>{},
      },
      'replayDigest': 'a' * 64,
      'replayStorageRef': 'replay-submissions/validated/run_empty_kills.bin.gz',
      'replayStorageGeneration': '1793213244200269',
      'createdAtMs': 1793213244044,
    });
    fields['codex']!.mapValue!.fields!['enemyKills'] = firestore.Value.fromJson(
      {'mapValue': <String, dynamic>{}},
    );
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, endsWith('/validated_runs/run_empty_kills'));
      return http.Response(
        jsonEncode(firestore.Document(fields: fields).toJson()),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(client.close);
    final provider = _FirestoreApiProvider(firestore.FirestoreApi(client));
    final leaderboard = FirestoreLeaderboardProjectionStore(
      projectId: 'test-project',
      apiProvider: provider,
    );
    final ghosts = FirestoreGhostPublicationStore(
      projectId: 'test-project',
      apiProvider: provider,
    );
    for (final load in [
      leaderboard.loadValidatedRun,
      ghosts.loadValidatedRun,
    ]) {
      final run = await load(runSessionId: 'run_empty_kills');
      expect(run, isNotNull);
      expect(run!.accepted, isTrue);
      expect(run.codex!.enemyKills, isEmpty);
      expect(run.stats, {'collectibles': 2});
      expect(run.replayStorageGeneration, '1793213244200269');
    }
  });
}

final class _FirestoreApiProvider extends GoogleCloudApiProvider {
  _FirestoreApiProvider(this.api);

  final firestore.FirestoreApi api;

  @override
  Future<firestore.FirestoreApi> firestoreApi() async => api;
}
