import 'dart:convert';

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:run_protocol/validated_run.dart';
import 'package:test/test.dart';

import 'package:replay_validator/src/firestore_value_codec.dart';
import 'package:replay_validator/src/google_api_helpers.dart';
import 'package:replay_validator/src/run_session_repository.dart';

void main() {
  test(
    'acquire preserves grace start and writes a fenced expiring lease',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return _jsonResponse(
            _runSessionDocument(
              state: 'pending_validation',
              validationAttempt: 7,
              internalErrorFirstAtMs: 1234,
            ).toJson(),
          );
        }
        if (request.method == 'PATCH') {
          return _jsonResponse(
            _runSessionDocument(
              state: 'validating',
              validationAttempt: 8,
              internalErrorFirstAtMs: 1234,
              validationLeaseToken: 'fixed-token',
              validationLeaseExpiresAtMs: 15000,
            ).toJson(),
          );
        }
        fail('Unexpected ${request.method} ${request.url}');
      });
      final repository = FirestoreRunSessionRepository(
        projectId: 'test-project',
        apiProvider: _TestApiProvider(firestore.FirestoreApi(client)),
        validationLeaseDuration: const Duration(seconds: 10),
        clockMs: () => 5000,
        leaseTokenFactory: () => 'fixed-token',
      );

      final result = await repository.acquireValidationLease(
        runSessionId: 'run_repo_test',
      );

      expect(result.status, RunSessionLeaseStatus.acquired);
      expect(result.session?.validationAttempt, 8);
      expect(result.session?.internalErrorFirstAtMs, 1234);
      expect(result.session?.validationLease?.token, 'fixed-token');
      expect(result.session?.validationLease?.expiresAtMs, 15000);
      expect(requests, hasLength(2));
      final patch = jsonDecode(requests.last.body) as Map<String, Object?>;
      final fields = decodeFirestoreFields(
        firestore.Document.fromJson(patch).fields,
      );
      expect(fields['state'], 'validating');
      expect(fields['validationLeaseToken'], 'fixed-token');
      expect(fields['validationLeaseExpiresAtMs'], 15000);
    },
  );

  test(
    'acquire retries a finalize-time lease contention immediately',
    () async {
      final requests = <http.Request>[];
      var patchAttempts = 0;
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return _jsonResponse(
            _runSessionDocument(
              state: 'pending_validation',
              validationAttempt: 1,
            ).toJson(),
          );
        }
        if (request.method == 'PATCH') {
          patchAttempts += 1;
          if (patchAttempts == 1) {
            return _failedPreconditionResponse();
          }
          return _jsonResponse(
            _runSessionDocument(
              state: 'validating',
              validationAttempt: 2,
              validationLeaseToken: 'fixed-token',
              validationLeaseExpiresAtMs: 605000,
            ).toJson(),
          );
        }
        fail('Unexpected ${request.method} ${request.url}');
      });
      final repository = FirestoreRunSessionRepository(
        projectId: 'test-project',
        apiProvider: _TestApiProvider(firestore.FirestoreApi(client)),
        clockMs: () => 5000,
        leaseTokenFactory: () => 'fixed-token',
      );

      final result = await repository.acquireValidationLease(
        runSessionId: 'run_repo_test',
      );

      expect(result.status, RunSessionLeaseStatus.acquired);
      expect(result.session?.validationAttempt, 2);
      expect(requests, hasLength(4));
    },
  );

  test('acquire leaves persistent lease contention to Cloud Tasks', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return _jsonResponse(
          _runSessionDocument(
            state: 'pending_validation',
            validationAttempt: 1,
          ).toJson(),
        );
      }
      if (request.method == 'PATCH') {
        return _failedPreconditionResponse();
      }
      fail('Unexpected ${request.method} ${request.url}');
    });
    final repository = FirestoreRunSessionRepository(
      projectId: 'test-project',
      apiProvider: _TestApiProvider(firestore.FirestoreApi(client)),
      clockMs: () => 5000,
      leaseTokenFactory: () => 'fixed-token',
    );

    final result = await repository.acquireValidationLease(
      runSessionId: 'run_repo_test',
    );

    expect(result.status, RunSessionLeaseStatus.alreadyValidating);
    expect(result.message, contains('after 2 immediate attempts'));
    expect(requests, hasLength(4));
  });

  test('expired validating lease is reclaimed with a new token', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return _jsonResponse(
          _runSessionDocument(
            state: 'validating',
            validationAttempt: 2,
            validationLeaseToken: 'expired-token',
            validationLeaseExpiresAtMs: 4999,
          ).toJson(),
        );
      }
      return _jsonResponse(
        _runSessionDocument(
          state: 'validating',
          validationAttempt: 3,
          validationLeaseToken: 'replacement-token',
          validationLeaseExpiresAtMs: 15000,
        ).toJson(),
      );
    });
    final repository = FirestoreRunSessionRepository(
      projectId: 'test-project',
      apiProvider: _TestApiProvider(firestore.FirestoreApi(client)),
      validationLeaseDuration: const Duration(seconds: 10),
      clockMs: () => 5000,
      leaseTokenFactory: () => 'replacement-token',
    );

    final result = await repository.acquireValidationLease(
      runSessionId: 'run_repo_test',
    );

    expect(result.status, RunSessionLeaseStatus.acquired);
    expect(result.session?.validationAttempt, 3);
    expect(result.session?.validationLease?.token, 'replacement-token');
    expect(result.message, contains('reclaimed'));
    expect(requests, hasLength(2));
  });

  test(
    'active validating lease remains retryable and is not replaced',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _jsonResponse(
          _runSessionDocument(
            state: 'validating',
            validationAttempt: 2,
            validationLeaseToken: 'active-token',
            validationLeaseExpiresAtMs: 5001,
          ).toJson(),
        );
      });
      final repository = FirestoreRunSessionRepository(
        projectId: 'test-project',
        apiProvider: _TestApiProvider(firestore.FirestoreApi(client)),
        clockMs: () => 5000,
        leaseTokenFactory: () => 'replacement-token',
      );

      final result = await repository.acquireValidationLease(
        runSessionId: 'run_repo_test',
      );

      expect(result.status, RunSessionLeaseStatus.alreadyValidating);
      expect(requests, hasLength(1));
    },
  );

  test('lease-owned retry rejects a stale token before patching', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return _jsonResponse(
        _runSessionDocument(
          state: 'validating',
          validationAttempt: 2,
          validationLeaseToken: 'current-token',
          validationLeaseExpiresAtMs: 15000,
        ).toJson(),
      );
    });
    final repository = FirestoreRunSessionRepository(
      projectId: 'test-project',
      apiProvider: _TestApiProvider(firestore.FirestoreApi(client)),
      clockMs: () => 5000,
    );

    await expectLater(
      repository.markPendingValidationRetry(
        runSessionId: 'run_repo_test',
        validationLeaseToken: 'stale-token',
        nextAttemptAtMs: 6000,
        message: 'retry',
      ),
      throwsA(isA<StaleValidationLeaseException>()),
    );
    expect(requests, hasLength(1));
  });

  test(
    'rejected handoff atomically writes evidence, grant, and terminal session',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path.contains('/run_sessions/')) {
          return _jsonResponse(
            _runSessionDocument(
              state: 'validating',
              validationAttempt: 1,
              validationLeaseToken: 'current-token',
              validationLeaseExpiresAtMs: 15000,
            ).toJson(),
          );
        }
        if (request.method == 'GET' &&
            request.url.path.contains('/reward_grants/')) {
          return _jsonResponse(_rewardGrantDocument().toJson());
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/documents:commit')) {
          return _jsonResponse(<String, Object?>{
            'writeResults': <Object?>[],
            'commitTime': '2026-07-18T00:00:01.000000Z',
          });
        }
        fail('Unexpected ${request.method} ${request.url}');
      });
      final repository = FirestoreRunSessionRepository(
        projectId: 'test-project',
        apiProvider: _TestApiProvider(firestore.FirestoreApi(client)),
        clockMs: () => 5000,
      );

      await repository.handoffRejectedRun(
        validatedRun: _rejectedRun(),
        validationLeaseToken: 'current-token',
        publicMessage: 'Replay was rejected.',
      );

      expect(requests, hasLength(3));
      final commit = firestore.CommitRequest.fromJson(
        jsonDecode(requests.last.body) as Map<String, Object?>,
      );
      expect(commit.writes, hasLength(3));
      final rewardFields = decodeFirestoreFields(
        commit.writes![1].update?.fields,
      );
      final sessionFields = decodeFirestoreFields(
        commit.writes![2].update?.fields,
      );
      expect(rewardFields['lifecycleState'], 'revoked_final');
      expect(rewardFields['settlementReason'], 'protocol_invalid');
      expect(sessionFields['state'], 'rejected');
      expect(sessionFields['validationLeaseToken'], isNull);
      expect(commit.writes![0].currentDocument?.exists, isFalse);
      expect(
        commit.writes![1].currentDocument?.updateTime,
        '2026-07-18T00:00:00.000000Z',
      );
      expect(
        commit.writes![2].currentDocument?.updateTime,
        '2026-07-18T00:00:00.000000Z',
      );
    },
  );

  test(
    'rejected handoff turns a commit precondition failure into a stale lease',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path.contains('/run_sessions/')) {
          return _jsonResponse(
            _runSessionDocument(
              state: 'validating',
              validationAttempt: 1,
              validationLeaseToken: 'current-token',
              validationLeaseExpiresAtMs: 15000,
            ).toJson(),
          );
        }
        if (request.method == 'GET' &&
            request.url.path.contains('/reward_grants/')) {
          return _jsonResponse(_rewardGrantDocument().toJson());
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/documents:commit')) {
          return _failedPreconditionResponse();
        }
        fail('Unexpected ${request.method} ${request.url}');
      });
      final repository = FirestoreRunSessionRepository(
        projectId: 'test-project',
        apiProvider: _TestApiProvider(firestore.FirestoreApi(client)),
        clockMs: () => 5000,
      );

      await expectLater(
        repository.handoffRejectedRun(
          validatedRun: _rejectedRun(),
          validationLeaseToken: 'current-token',
          publicMessage: 'Replay was rejected.',
        ),
        throwsA(isA<StaleValidationLeaseException>()),
      );

      expect(requests, hasLength(3));
      expect(
        requests.where(
          (request) =>
              request.method == 'POST' &&
              request.url.path.endsWith('/documents:commit'),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'accepted handoff classifies production FAILED_PRECONDITION as conflict',
    () async {
      final repository = FirestoreRunSessionRepository(
        projectId: 'test-project',
        apiProvider: _handoffConflictApiProvider(),
        clockMs: () => 5000,
      );

      await expectLater(
        repository.handoffAcceptedRunForSettlement(
          validatedRun: _acceptedRun(),
          validationLeaseToken: 'current-token',
        ),
        throwsA(isA<StaleValidationLeaseException>()),
      );
    },
  );

  test(
    'internal-error handoff classifies production FAILED_PRECONDITION as stale',
    () async {
      final repository = FirestoreRunSessionRepository(
        projectId: 'test-project',
        apiProvider: _handoffConflictApiProvider(),
        clockMs: () => 5000,
      );

      await expectLater(
        repository.handoffInternalError(
          runSessionId: 'run_repo_test',
          validationLeaseToken: 'current-token',
          publicMessage: 'Replay verification could not be completed.',
        ),
        throwsA(isA<StaleValidationLeaseException>()),
      );
    },
  );

  test(
    'retry release classifies production FAILED_PRECONDITION as stale',
    () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return _jsonResponse(
            _runSessionDocument(
              state: 'validating',
              validationAttempt: 1,
              validationLeaseToken: 'current-token',
              validationLeaseExpiresAtMs: 15000,
            ).toJson(),
          );
        }
        if (request.method == 'PATCH') {
          return _failedPreconditionResponse();
        }
        fail('Unexpected ${request.method} ${request.url}');
      });
      final repository = FirestoreRunSessionRepository(
        projectId: 'test-project',
        apiProvider: _TestApiProvider(firestore.FirestoreApi(client)),
        clockMs: () => 5000,
      );

      await expectLater(
        repository.markPendingValidationRetry(
          runSessionId: 'run_repo_test',
          validationLeaseToken: 'current-token',
          nextAttemptAtMs: 6000,
          message: 'retry',
        ),
        throwsA(isA<StaleValidationLeaseException>()),
      );
    },
  );
}

final class _TestApiProvider extends GoogleCloudApiProvider {
  _TestApiProvider(this.api);

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

http.Response _failedPreconditionResponse() {
  return _jsonResponse(<String, Object?>{
    'error': <String, Object?>{
      'code': 400,
      'message': 'stored version does not match required base version',
      'status': 'FAILED_PRECONDITION',
    },
  }, statusCode: 400);
}

_TestApiProvider _handoffConflictApiProvider() {
  final client = MockClient((request) async {
    if (request.method == 'GET' &&
        request.url.path.contains('/run_sessions/')) {
      return _jsonResponse(
        _runSessionDocument(
          state: 'validating',
          validationAttempt: 1,
          validationLeaseToken: 'current-token',
          validationLeaseExpiresAtMs: 15000,
        ).toJson(),
      );
    }
    if (request.method == 'GET' &&
        request.url.path.contains('/reward_grants/')) {
      return _jsonResponse(_rewardGrantDocument().toJson());
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/documents:commit')) {
      return _failedPreconditionResponse();
    }
    fail('Unexpected ${request.method} ${request.url}');
  });
  return _TestApiProvider(firestore.FirestoreApi(client));
}

firestore.Document _runSessionDocument({
  required String state,
  required int validationAttempt,
  int? internalErrorFirstAtMs,
  String? validationLeaseToken,
  int? validationLeaseExpiresAtMs,
}) {
  final ticket = RunTicket(
    runSessionId: 'run_repo_test',
    uid: 'uid_1',
    mode: RunMode.practice,
    seed: 42,
    tickHz: 60,
    gameCompatVersion: '2026.03.0',
    levelId: 'field',
    playerCharacterId: 'eloise',
    loadoutSnapshot: const <String, Object?>{'mask': 0},
    loadoutDigest:
        '0123456789012345678901234567890123456789012345678901234567890123',
    issuedAtMs: 1,
    expiresAtMs: 999999,
    singleUseNonce: 'nonce',
  );
  return firestore.Document(
    name:
        'projects/test-project/databases/(default)/documents/run_sessions/run_repo_test',
    updateTime: '2026-07-18T00:00:00.000000Z',
    fields: encodeFirestoreFields(<String, Object?>{
      'runSessionId': 'run_repo_test',
      'uid': 'uid_1',
      'mode': RunMode.practice.name,
      'state': state,
      'runTicket': ticket.toJson(),
      'uploadedReplay': <String, Object?>{
        'objectPath':
            'replay-submissions/pending/uid_1/run_repo_test/replay.bin.gz',
        'canonicalSha256': 'a' * 64,
        'contentLengthBytes': 100,
        'storageGeneration': '123',
        'finalizedAtMs': 1000,
      },
      'validationAttempt': validationAttempt,
      'internalErrorFirstAtMs': ?internalErrorFirstAtMs,
      'validationLeaseToken': ?validationLeaseToken,
      'validationLeaseExpiresAtMs': ?validationLeaseExpiresAtMs,
    }),
  );
}

firestore.Document _rewardGrantDocument() {
  return firestore.Document(
    name:
        'projects/test-project/databases/(default)/documents/reward_grants/run_repo_test',
    updateTime: '2026-07-18T00:00:00.000000Z',
    fields: encodeFirestoreFields(<String, Object?>{
      'runSessionId': 'run_repo_test',
      'uid': 'uid_1',
      'mode': RunMode.practice.name,
      'lifecycleState': 'provisional_created',
    }),
  );
}

ValidatedRun _rejectedRun() {
  return ValidatedRun(
    runSessionId: 'run_repo_test',
    uid: 'uid_1',
    mode: RunMode.practice,
    accepted: false,
    rejectionReason: 'protocol_invalid',
    score: 0,
    distanceMeters: 0,
    durationSeconds: 0,
    tick: 0,
    endedReason: 'rejected',
    goldEarned: 0,
    stats: const <String, Object?>{},
    replayDigest: 'a' * 64,
    replayStorageRef:
        'replay-submissions/pending/uid_1/run_repo_test/replay.bin.gz',
    replayStorageGeneration: '123',
    createdAtMs: 5000,
  );
}

ValidatedRun _acceptedRun() {
  return ValidatedRun(
    runSessionId: 'run_repo_test',
    uid: 'uid_1',
    mode: RunMode.practice,
    accepted: true,
    score: 10,
    distanceMeters: 1,
    durationSeconds: 1,
    tick: 60,
    endedReason: 'completed',
    goldEarned: 2,
    stats: const <String, Object?>{},
    replayDigest: 'a' * 64,
    replayStorageRef:
        'replay-submissions/pending/uid_1/run_repo_test/replay.bin.gz',
    replayStorageGeneration: '123',
    createdAtMs: 5000,
  );
}
