import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:http/http.dart' as http;
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:run_protocol/validated_run.dart';

import 'package:replay_validator/src/firestore_value_codec.dart';
import 'package:replay_validator/src/google_api_helpers.dart';
import 'package:replay_validator/src/run_session_repository.dart';

Future<void> main(List<String> arguments) async {
  final args = _parseArgs(arguments);
  final projectId = _requireArg(args, 'project');
  final drillId =
      'rvhandoff-${DateTime.now().millisecondsSinceEpoch}-'
      '${_shortToken(DateTime.now().microsecondsSinceEpoch.toString())}';
  final authClient = _BearerClient(
    http.Client(),
    await _readGcloudAccessToken(),
  );
  final directApi = firestore.FirestoreApi(authClient);
  final results = <Map<String, Object?>>[];

  try {
    for (final handoff in _Handoff.values) {
      for (final fault in _faultsFor(handoff)) {
        final fixture = _Fixture(
          projectId: projectId,
          drillId: drillId,
          handoff: handoff,
          fault: fault,
        );
        await _seedFixture(directApi, fixture);
        try {
          final client = _CommitFaultClient(
            inner: authClient,
            fault: fault,
            beforeCommit: () =>
                _injectConflict(api: directApi, fixture: fixture),
          );
          final repository = FirestoreRunSessionRepository(
            projectId: projectId,
            apiProvider: _DrillApiProvider(firestore.FirestoreApi(client)),
            clockMs: () => fixture.nowMs,
          );

          Object? observedError;
          try {
            await _performHandoff(repository, fixture);
          } catch (error) {
            observedError = error;
          }
          await _verifyScenario(
            api: directApi,
            fixture: fixture,
            observedError: observedError,
          );
          results.add(<String, Object?>{
            'handoff': handoff.name,
            'fault': fault.name,
            'result': 'pass',
            'fixtureHash': _shortToken(fixture.runSessionId),
          });
        } finally {
          await _deleteFixture(directApi, fixture);
          await _verifyDeleted(directApi, fixture);
        }
      }
    }
  } finally {
    authClient.close();
  }

  final grouped = <String, int>{};
  for (final result in results) {
    final key = result['handoff']! as String;
    grouped[key] = (grouped[key] ?? 0) + 1;
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'schemaVersion': 1,
      'projectId': projectId,
      'observedAt': DateTime.now().toUtc().toIso8601String(),
      'drillIdHash': _shortToken(drillId),
      'scenarioCount': results.length,
      'passedCount': results.length,
      'handoffCounts': grouped,
      'scenarios': results,
      'residualFixtureCount': 0,
    }),
  );
}

enum _Handoff { accepted, rejected, internalError }

enum _Fault {
  none,
  sessionConflict,
  rewardConflict,
  validatedConflict,
  beforeCommitFailure,
  afterCommitResponseLoss,
  staleLeaseToken,
  expiredLease,
}

List<_Fault> _faultsFor(_Handoff handoff) {
  return <_Fault>[
    _Fault.none,
    _Fault.sessionConflict,
    _Fault.rewardConflict,
    if (handoff != _Handoff.internalError) _Fault.validatedConflict,
    _Fault.beforeCommitFailure,
    _Fault.afterCommitResponseLoss,
    _Fault.staleLeaseToken,
    _Fault.expiredLease,
  ];
}

final class _Fixture {
  _Fixture({
    required this.projectId,
    required this.drillId,
    required this.handoff,
    required this.fault,
  }) : nowMs = DateTime.now().millisecondsSinceEpoch,
       runSessionId = '$drillId-${handoff.name}-${fault.name}'.toLowerCase(),
       uid = '$drillId-fixture-user'.toLowerCase();

  final String projectId;
  final String drillId;
  final _Handoff handoff;
  final _Fault fault;
  final int nowMs;
  final String runSessionId;
  final String uid;

  String get database => 'projects/$projectId/databases/(default)';
  String get sessionPath => '$database/documents/run_sessions/$runSessionId';
  String get grantPath => '$database/documents/reward_grants/$runSessionId';
  String get validatedPath =>
      '$database/documents/validated_runs/$runSessionId';
  String get leaseToken => 'lease-${_shortToken(runSessionId)}';
  String get replayPath =>
      'replay-submissions/pending/$uid/$runSessionId/replay.bin.gz';
}

Future<void> _seedFixture(firestore.FirestoreApi api, _Fixture fixture) async {
  final issuedAtMs = fixture.nowMs - const Duration(minutes: 1).inMilliseconds;
  final ticket = RunTicket(
    runSessionId: fixture.runSessionId,
    uid: fixture.uid,
    mode: RunMode.practice,
    seed: 42,
    tickHz: 60,
    gameCompatVersion: '2026.03.0',
    levelId: 'field',
    playerCharacterId: 'eloise',
    loadoutSnapshot: const <String, Object?>{'mask': 0},
    loadoutDigest: 'a' * 64,
    issuedAtMs: issuedAtMs,
    expiresAtMs: issuedAtMs + const Duration(hours: 24).inMilliseconds,
    singleUseNonce: 'nonce-${fixture.runSessionId}',
  );
  final leaseExpiresAtMs = fixture.fault == _Fault.expiredLease
      ? fixture.nowMs - 1
      : fixture.nowMs + const Duration(minutes: 10).inMilliseconds;
  final session = <String, Object?>{
    'runSessionId': fixture.runSessionId,
    'uid': fixture.uid,
    'mode': RunMode.practice.name,
    'state': 'validating',
    'runTicket': ticket.toJson(),
    'uploadedReplay': <String, Object?>{
      'objectPath': fixture.replayPath,
      'canonicalSha256': 'b' * 64,
      'contentLengthBytes': 100,
      'storageGeneration': '1',
      'finalizedAtMs': fixture.nowMs,
    },
    'validationAttempt': 8,
    'validationLeaseToken': fixture.leaseToken,
    'validationLeaseExpiresAtMs': leaseExpiresAtMs,
    'updatedAtMs': fixture.nowMs,
  };
  final grant = <String, Object?>{
    'runSessionId': fixture.runSessionId,
    'uid': fixture.uid,
    'mode': RunMode.practice.name,
    'lifecycleState': 'provisional_created',
    'updatedAtMs': fixture.nowMs,
  };
  await api.projects.databases.documents.commit(
    firestore.CommitRequest(
      writes: <firestore.Write>[
        firestore.Write(
          update: firestore.Document(
            name: fixture.sessionPath,
            fields: encodeFirestoreFields(session),
          ),
          currentDocument: firestore.Precondition(exists: false),
        ),
        firestore.Write(
          update: firestore.Document(
            name: fixture.grantPath,
            fields: encodeFirestoreFields(grant),
          ),
          currentDocument: firestore.Precondition(exists: false),
        ),
      ],
    ),
    fixture.database,
  );
}

Future<void> _performHandoff(
  FirestoreRunSessionRepository repository,
  _Fixture fixture,
) async {
  final leaseToken = fixture.fault == _Fault.staleLeaseToken
      ? 'stale-${fixture.leaseToken}'
      : fixture.leaseToken;
  switch (fixture.handoff) {
    case _Handoff.accepted:
      await repository.handoffAcceptedRunForSettlement(
        validatedRun: _validatedRun(fixture, accepted: true),
        validationLeaseToken: leaseToken,
      );
      return;
    case _Handoff.rejected:
      await repository.handoffRejectedRun(
        validatedRun: _validatedRun(fixture, accepted: false),
        validationLeaseToken: leaseToken,
        publicMessage: 'Replay was rejected.',
      );
      return;
    case _Handoff.internalError:
      await repository.handoffInternalError(
        runSessionId: fixture.runSessionId,
        validationLeaseToken: leaseToken,
        publicMessage: 'Replay verification could not be completed.',
      );
      return;
  }
}

ValidatedRun _validatedRun(_Fixture fixture, {required bool accepted}) {
  return ValidatedRun(
    runSessionId: fixture.runSessionId,
    uid: fixture.uid,
    mode: RunMode.practice,
    accepted: accepted,
    rejectionReason: accepted ? null : 'protocol_invalid',
    score: accepted ? 10 : 0,
    distanceMeters: accepted ? 1 : 0,
    durationSeconds: accepted ? 1 : 0,
    tick: accepted ? 60 : 0,
    endedReason: accepted ? 'completed' : 'rejected',
    goldEarned: accepted ? 2 : 0,
    stats: const <String, Object?>{},
    replayDigest: 'b' * 64,
    replayStorageRef: fixture.replayPath,
    replayStorageGeneration: '1',
    createdAtMs: fixture.nowMs,
  );
}

Future<void> _injectConflict({
  required firestore.FirestoreApi api,
  required _Fixture fixture,
}) async {
  final target = switch (fixture.fault) {
    _Fault.sessionConflict => fixture.sessionPath,
    _Fault.rewardConflict => fixture.grantPath,
    _Fault.validatedConflict => fixture.validatedPath,
    _ => null,
  };
  if (target == null) {
    return;
  }
  if (fixture.fault == _Fault.validatedConflict) {
    await api.projects.databases.documents.patch(
      firestore.Document(
        fields: encodeFirestoreFields(<String, Object?>{
          'drillConflictMarker': fixture.runSessionId,
        }),
      ),
      target,
      currentDocument_exists: false,
    );
    return;
  }
  await api.projects.databases.documents.patch(
    firestore.Document(
      fields: encodeFirestoreFields(<String, Object?>{
        'drillConflictMarker': fixture.runSessionId,
      }),
    ),
    target,
    updateMask_fieldPaths: const <String>['drillConflictMarker'],
  );
}

Future<void> _verifyScenario({
  required firestore.FirestoreApi api,
  required _Fixture fixture,
  required Object? observedError,
}) async {
  final session = decodeFirestoreFields(
    (await api.projects.databases.documents.get(fixture.sessionPath)).fields,
  );
  final grant = decodeFirestoreFields(
    (await api.projects.databases.documents.get(fixture.grantPath)).fields,
  );
  final validated = await _getIfPresent(api, fixture.validatedPath);
  final committed =
      fixture.fault == _Fault.none ||
      fixture.fault == _Fault.afterCommitResponseLoss;

  if (fixture.fault == _Fault.none) {
    if (observedError != null) {
      throw StateError(
        '${fixture.handoff.name}/${fixture.fault.name} failed: $observedError',
      );
    }
  } else if (fixture.fault == _Fault.afterCommitResponseLoss) {
    if (observedError is! SocketException) {
      throw StateError(
        '${fixture.handoff.name}/${fixture.fault.name} did not lose response.',
      );
    }
  } else if (fixture.fault == _Fault.beforeCommitFailure) {
    if (observedError is! SocketException) {
      throw StateError(
        '${fixture.handoff.name}/${fixture.fault.name} did not fail before commit.',
      );
    }
  } else {
    if (observedError is! StaleValidationLeaseException) {
      throw StateError(
        '${fixture.handoff.name}/${fixture.fault.name} expected stale lease, '
        'got $observedError.',
      );
    }
  }

  if (committed) {
    final expectedSessionState = switch (fixture.handoff) {
      _Handoff.accepted => 'settlement_pending',
      _Handoff.rejected => 'rejected',
      _Handoff.internalError => 'internal_error',
    };
    final expectedGrantState = fixture.handoff == _Handoff.accepted
        ? 'settlement_pending'
        : 'revoked_final';
    if (session['state'] != expectedSessionState ||
        grant['lifecycleState'] != expectedGrantState) {
      throw StateError(
        '${fixture.handoff.name}/${fixture.fault.name} committed incoherent state.',
      );
    }
    if (fixture.handoff == _Handoff.internalError && validated != null) {
      throw StateError('Internal-error handoff wrote validated-run evidence.');
    }
    if (fixture.handoff != _Handoff.internalError) {
      final fields = decodeFirestoreFields(validated?.fields);
      if (fields['accepted'] != (fixture.handoff == _Handoff.accepted)) {
        throw StateError(
          '${fixture.handoff.name}/${fixture.fault.name} evidence is incoherent.',
        );
      }
    }
    if (fixture.fault == _Fault.afterCommitResponseLoss) {
      final retryRepository = FirestoreRunSessionRepository(
        projectId: fixture.projectId,
        apiProvider: _DrillApiProvider(api),
        clockMs: () => fixture.nowMs,
      );
      final duplicate = await retryRepository.acquireValidationLease(
        runSessionId: fixture.runSessionId,
      );
      final expectedDuplicateStatus = fixture.handoff == _Handoff.accepted
          ? RunSessionLeaseStatus.invalidState
          : RunSessionLeaseStatus.alreadyTerminal;
      if (duplicate.status != expectedDuplicateStatus) {
        throw StateError(
          '${fixture.handoff.name} response-loss retry was not idempotent.',
        );
      }
    }
    return;
  }

  if (session['state'] != 'validating' ||
      grant['lifecycleState'] != 'provisional_created') {
    throw StateError(
      '${fixture.handoff.name}/${fixture.fault.name} partially committed.',
    );
  }
  if (fixture.fault == _Fault.validatedConflict) {
    final fields = decodeFirestoreFields(validated?.fields);
    if (fields['drillConflictMarker'] != fixture.runSessionId) {
      throw StateError('Validated-run conflict marker was not preserved.');
    }
  } else if (validated != null) {
    throw StateError(
      '${fixture.handoff.name}/${fixture.fault.name} wrote partial evidence.',
    );
  }
}

Future<firestore.Document?> _getIfPresent(
  firestore.FirestoreApi api,
  String path,
) async {
  try {
    return await api.projects.databases.documents.get(path);
  } catch (error) {
    if (isApiNotFound(error)) {
      return null;
    }
    rethrow;
  }
}

Future<void> _deleteFixture(
  firestore.FirestoreApi api,
  _Fixture fixture,
) async {
  for (final path in <String>[
    fixture.validatedPath,
    fixture.grantPath,
    fixture.sessionPath,
  ]) {
    try {
      await api.projects.databases.documents.delete(path);
    } catch (error) {
      if (!isApiNotFound(error)) {
        rethrow;
      }
    }
  }
}

Future<void> _verifyDeleted(
  firestore.FirestoreApi api,
  _Fixture fixture,
) async {
  for (final path in <String>[
    fixture.validatedPath,
    fixture.grantPath,
    fixture.sessionPath,
  ]) {
    if (await _getIfPresent(api, path) != null) {
      throw StateError(
        '${fixture.handoff.name}/${fixture.fault.name} cleanup left residue.',
      );
    }
  }
}

final class _CommitFaultClient extends http.BaseClient {
  _CommitFaultClient({
    required this.inner,
    required this.fault,
    required this.beforeCommit,
  });

  final http.Client inner;
  final _Fault fault;
  final Future<void> Function() beforeCommit;
  var _faultApplied = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isCommit =
        request.method == 'POST' &&
        request.url.path.endsWith('/documents:commit');
    if (!isCommit || _faultApplied) {
      return inner.send(request);
    }
    _faultApplied = true;
    if (fault == _Fault.beforeCommitFailure) {
      throw const SocketException('Injected failure before Firestore commit.');
    }
    await beforeCommit();
    final response = await inner.send(request);
    if (fault == _Fault.afterCommitResponseLoss) {
      throw const SocketException(
        'Injected loss of successful commit response.',
      );
    }
    return response;
  }
}

final class _BearerClient extends http.BaseClient {
  _BearerClient(this.inner, this.accessToken);

  final http.Client inner;
  final String accessToken;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['authorization'] = 'Bearer $accessToken';
    return inner.send(request);
  }

  @override
  void close() {
    inner.close();
  }
}

final class _DrillApiProvider extends GoogleCloudApiProvider {
  _DrillApiProvider(this.api);

  final firestore.FirestoreApi api;

  @override
  Future<firestore.FirestoreApi> firestoreApi() async => api;
}

Future<String> _readGcloudAccessToken() async {
  final ProcessResult result;
  if (Platform.isWindows) {
    result = await Process.run('powershell.exe', const <String>[
      '-NoProfile',
      '-Command',
      'gcloud auth print-access-token',
    ]);
  } else {
    result = await Process.run('gcloud', const <String>[
      'auth',
      'print-access-token',
    ]);
  }
  if (result.exitCode != 0) {
    throw StateError('Unable to obtain the active gcloud access token.');
  }
  final token = result.stdout.toString().trim();
  if (token.isEmpty) {
    throw StateError('The active gcloud access token was empty.');
  }
  return token;
}

Map<String, String> _parseArgs(List<String> arguments) {
  final parsed = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final name = arguments[index];
    if (!name.startsWith('--') || index + 1 >= arguments.length) {
      throw FormatException('Expected --name value arguments.');
    }
    parsed[name.substring(2)] = arguments[index + 1];
  }
  return parsed;
}

String _requireArg(Map<String, String> args, String name) {
  final value = args[name]?.trim();
  if (value == null || value.isEmpty) {
    throw FormatException('--$name is required.');
  }
  return value;
}

String _shortToken(String value) {
  var hash = 0xcbf29ce484222325;
  for (final codeUnit in utf8.encode(value)) {
    hash ^= codeUnit;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
