import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/run/firebase_run_session_api.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:rpg_runner/ui/state/run/run_start_remote_exception.dart';

void main() {
  for (final malformed in <String, Object?>{
    'tickHz': 0,
    'seed': 1e100,
    'expiresAtMs': 1,
    'loadoutSnapshot': {'mask': 0.5},
  }.entries) {
    test(
      'malformed ticket ${malformed.key} becomes invalid-response',
      () async {
        final source = _RecordingRunSessionSource()
          ..ticketOverrides = {malformed.key: malformed.value};
        final api = FirebaseRunSessionApi(source: source);
        await expectLater(
          api.createRunSession(
            userId: 'uid_1',
            sessionId: 'session_1',
            mode: RunMode.practice,
            levelId: LevelId.field,
            gameCompatVersion: '2026.03.0',
          ),
          throwsA(
            isA<RunStartRemoteException>().having(
              (error) => error.code,
              'code',
              'invalid-response',
            ),
          ),
        );
      },
    );
  }
  test('run create sends one bounded client request ID', () async {
    final source = _RecordingRunSessionSource();
    final api = FirebaseRunSessionApi(
      source: source,
      requestIdFactory: () => 'run_request_test_1',
    );

    final ticket = await api.createRunSession(
      userId: 'uid_1',
      sessionId: 'session_1',
      mode: RunMode.practice,
      levelId: LevelId.field,
      gameCompatVersion: '2026.03.0',
    );

    expect(source.clientRequestIds, <String>['run_request_test_1']);
    expect(ticket.runSessionId, 'run_1');
  });

  test('default run request IDs are unique and backend-safe', () {
    final ids = List<String>.generate(100, (_) => createRunClientRequestId());

    expect(ids.toSet(), hasLength(ids.length));
    for (final id in ids) {
      expect(id.length, lessThanOrEqualTo(96));
      expect(id, matches(RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._:-]*$')));
    }
  });
}

final class _RecordingRunSessionSource implements FirebaseRunSessionSource {
  final List<String> clientRequestIds = <String>[];
  Map<String, Object?> ticketOverrides = {};

  @override
  Future<Map<String, dynamic>> createRunSession({
    required String userId,
    required String sessionId,
    required String clientRequestId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    clientRequestIds.add(clientRequestId);
    return <String, dynamic>{
      'runTicket': {
        ...RunTicket(
          runSessionId: 'run_1',
          uid: userId,
          mode: mode,
          seed: 1,
          tickHz: 60,
          gameCompatVersion: gameCompatVersion,
          levelId: levelId.name,
          playerCharacterId: 'eloise',
          loadoutSnapshot: const <String, Object?>{},
          loadoutDigest: 'digest',
          issuedAtMs: 1,
          expiresAtMs: 2,
          singleUseNonce: 'nonce',
        ).toJson(),
        ...ticketOverrides,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) {
    throw UnimplementedError();
  }
}
