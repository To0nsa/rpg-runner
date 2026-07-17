import 'package:run_protocol/run_ticket.dart';
import 'package:run_protocol/validated_run.dart';
import 'package:googleapis/firestore/v1.dart' as firestore;

import 'firestore_value_codec.dart';
import 'google_api_helpers.dart';

enum RunSessionLeaseStatus {
  acquired,
  notFound,
  alreadyTerminal,
  alreadyValidating,
  invalidState,
}

enum RunSessionTerminalState {
  validated,
  rejected,
  internalError;

  String get wireValue => switch (this) {
    RunSessionTerminalState.internalError => 'internal_error',
    _ => name,
  };
}

final class UploadedReplayRef {
  const UploadedReplayRef({
    required this.objectPath,
    required this.canonicalSha256,
    required this.contentLengthBytes,
    this.contentType,
  });

  final String objectPath;
  final String canonicalSha256;
  final int contentLengthBytes;
  final String? contentType;
}

final class ValidatorRunSession {
  const ValidatorRunSession({
    required this.runSessionId,
    required this.uid,
    required this.runTicket,
    required this.uploadedReplay,
    required this.validationAttempt,
    this.internalErrorFirstAtMs,
  });

  final String runSessionId;
  final String uid;
  final RunTicket runTicket;
  final UploadedReplayRef uploadedReplay;
  final int validationAttempt;
  final int? internalErrorFirstAtMs;
}

final class RunSessionLeaseAcquireResult {
  const RunSessionLeaseAcquireResult({
    required this.status,
    this.session,
    this.message,
  });

  final RunSessionLeaseStatus status;
  final ValidatorRunSession? session;
  final String? message;
}

abstract class RunSessionRepository {
  Future<RunSessionLeaseAcquireResult> acquireValidationLease({
    required String runSessionId,
  });

  Future<void> handoffAcceptedRunForSettlement({
    required ValidatedRun validatedRun,
  });

  Future<void> persistValidatedRun({required ValidatedRun validatedRun});

  Future<void> markTerminal({
    required String runSessionId,
    required RunSessionTerminalState terminalState,
    String? message,
  });

  Future<void> markPendingValidationRetry({
    required String runSessionId,
    required int nextAttemptAtMs,
    required String message,
    int? internalErrorFirstAtMs,
  });
}

class NoopRunSessionRepository implements RunSessionRepository {
  @override
  Future<RunSessionLeaseAcquireResult> acquireValidationLease({
    required String runSessionId,
  }) async {
    return const RunSessionLeaseAcquireResult(
      status: RunSessionLeaseStatus.notFound,
      message: 'Noop run-session repository is not wired.',
    );
  }

  @override
  Future<void> markPendingValidationRetry({
    required String runSessionId,
    required int nextAttemptAtMs,
    required String message,
    int? internalErrorFirstAtMs,
  }) async {}

  @override
  Future<void> handoffAcceptedRunForSettlement({
    required ValidatedRun validatedRun,
  }) async {}

  @override
  Future<void> markTerminal({
    required String runSessionId,
    required RunSessionTerminalState terminalState,
    String? message,
  }) async {}

  @override
  Future<void> persistValidatedRun({
    required ValidatedRun validatedRun,
  }) async {}
}

class FirestoreRunSessionRepository implements RunSessionRepository {
  FirestoreRunSessionRepository({
    required this.projectId,
    required this.apiProvider,
    int Function()? clockMs,
  }) : _clockMs = clockMs ?? _defaultClockMs;

  final String projectId;
  final GoogleCloudApiProvider apiProvider;
  final int Function() _clockMs;

  String get _databaseRoot => 'projects/$projectId/databases/(default)';
  String _runSessionDocPath(String runSessionId) =>
      '$_databaseRoot/documents/run_sessions/$runSessionId';
  String _validatedRunDocPath(String runSessionId) =>
      '$_databaseRoot/documents/validated_runs/$runSessionId';
  String _rewardGrantDocPath(String runSessionId) =>
      '$_databaseRoot/documents/reward_grants/$runSessionId';

  @override
  Future<RunSessionLeaseAcquireResult> acquireValidationLease({
    required String runSessionId,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final docPath = _runSessionDocPath(runSessionId);
    firestore.Document document;
    try {
      document = await firestoreApi.projects.databases.documents.get(docPath);
    } catch (error) {
      if (isApiNotFound(error)) {
        return RunSessionLeaseAcquireResult(
          status: RunSessionLeaseStatus.notFound,
          message: 'runSessionId "$runSessionId" was not found.',
        );
      }
      rethrow;
    }

    final decoded = decodeFirestoreFields(document.fields);
    final state = decoded['state'];
    if (state is! String) {
      return RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.invalidState,
        message: 'runSessionId "$runSessionId" has invalid state payload.',
      );
    }
    if (_isTerminalState(state)) {
      return RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.alreadyTerminal,
        message: 'runSessionId "$runSessionId" is already terminal ($state).',
      );
    }
    if (state == 'validating') {
      return RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.alreadyValidating,
        message: 'runSessionId "$runSessionId" is already validating.',
      );
    }
    // Accept both states to avoid a race where Cloud Tasks dispatches a freshly
    // enqueued validation task before the finalize flow flips uploaded ->
    // pending_validation.
    if (state != 'pending_validation' && state != 'uploaded') {
      return RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.invalidState,
        message:
            'runSessionId "$runSessionId" must be pending_validation or '
            'uploaded; got "$state".',
      );
    }

    final session = _decodeValidatorRunSession(decoded, runSessionId);
    if (session == null) {
      return RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.invalidState,
        message: 'runSessionId "$runSessionId" is missing ticket/upload data.',
      );
    }
    final nextAttempt = session.validationAttempt + 1;
    final updateTime = document.updateTime;
    if (updateTime == null || updateTime.isEmpty) {
      return RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.invalidState,
        message: 'runSessionId "$runSessionId" is missing document updateTime.',
      );
    }
    final nowMs = _clockMs();
    final patch = firestore.Document(
      fields: encodeFirestoreFields(<String, Object?>{
        'state': 'validating',
        'updatedAtMs': nowMs,
        'validationAttempt': nextAttempt,
        'validationStartedAtMs': nowMs,
        'message': null,
      }),
    );

    try {
      await firestoreApi.projects.databases.documents.patch(
        patch,
        docPath,
        currentDocument_updateTime: updateTime,
        updateMask_fieldPaths: const <String>[
          'state',
          'updatedAtMs',
          'validationAttempt',
          'validationStartedAtMs',
          'message',
        ],
      );
    } catch (error) {
      if (isApiConflict(error)) {
        return RunSessionLeaseAcquireResult(
          status: RunSessionLeaseStatus.alreadyValidating,
          message:
              'runSessionId "$runSessionId" lease conflict; likely already '
              'claimed.',
        );
      }
      rethrow;
    }

    return RunSessionLeaseAcquireResult(
      status: RunSessionLeaseStatus.acquired,
      session: ValidatorRunSession(
        runSessionId: session.runSessionId,
        uid: session.uid,
        runTicket: session.runTicket,
        uploadedReplay: session.uploadedReplay,
        validationAttempt: nextAttempt,
      ),
      message: 'runSessionId "$runSessionId" validation lease acquired.',
    );
  }

  @override
  Future<void> persistValidatedRun({required ValidatedRun validatedRun}) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final path = _validatedRunDocPath(validatedRun.runSessionId);
    final payload = validatedRun.toJson();
    await firestoreApi.projects.databases.documents.patch(
      firestore.Document(fields: encodeFirestoreFields(payload)),
      path,
      updateMask_fieldPaths: payload.keys.toList(growable: false),
    );
  }

  @override
  Future<void> handoffAcceptedRunForSettlement({
    required ValidatedRun validatedRun,
  }) async {
    if (!validatedRun.accepted) {
      throw ArgumentError.value(
        validatedRun.accepted,
        'validatedRun.accepted',
        'Accepted settlement handoff requires an accepted run.',
      );
    }

    final firestoreApi = await apiProvider.firestoreApi();
    final runSessionId = validatedRun.runSessionId;
    final sessionPath = _runSessionDocPath(runSessionId);
    final rewardGrantPath = _rewardGrantDocPath(runSessionId);
    final validatedRunPath = _validatedRunDocPath(runSessionId);
    final sessionDocument = await firestoreApi.projects.databases.documents.get(
      sessionPath,
    );
    final rewardGrantDocument = await firestoreApi.projects.databases.documents
        .get(rewardGrantPath);
    final session = decodeFirestoreFields(sessionDocument.fields);
    final rewardGrant = decodeFirestoreFields(rewardGrantDocument.fields);
    final sessionUpdateTime = sessionDocument.updateTime;
    final rewardGrantUpdateTime = rewardGrantDocument.updateTime;
    if (sessionUpdateTime == null || sessionUpdateTime.isEmpty) {
      throw StateError('runSessionId "$runSessionId" is missing updateTime.');
    }
    if (rewardGrantUpdateTime == null || rewardGrantUpdateTime.isEmpty) {
      throw StateError('reward grant "$runSessionId" is missing updateTime.');
    }
    _assertSettlementHandoffBindings(
      runSessionId: runSessionId,
      session: session,
      rewardGrant: rewardGrant,
      validatedRun: validatedRun,
    );

    final nowMs = _clockMs();
    final validatedRunPayload = validatedRun.toJson();
    final rewardGrantPayload = <String, Object?>{
      'lifecycleState': 'settlement_pending',
      'updatedAtMs': nowMs,
      'settlementPendingAtMs': nowMs,
      'goldAmount': validatedRun.goldEarned,
      'uid': validatedRun.uid,
      'mode': validatedRun.mode.name,
      if (validatedRun.boardId != null) 'boardId': validatedRun.boardId,
      if (validatedRun.boardKey != null)
        'boardKey': validatedRun.boardKey!.toJson(),
      'validatedRunRef': 'validated_runs/$runSessionId',
      'lastTransitionBy': 'validator_handoff',
      'settlementReason': null,
    };
    final sessionPayload = <String, Object?>{
      'state': 'settlement_pending',
      'updatedAtMs': nowMs,
      'settlementPendingAtMs': nowMs,
      'message': 'Reward settlement pending.',
    };

    try {
      await firestoreApi.projects.databases.documents.commit(
        firestore.CommitRequest(
          writes: <firestore.Write>[
            firestore.Write(
              update: firestore.Document(
                name: validatedRunPath,
                fields: encodeFirestoreFields(validatedRunPayload),
              ),
              currentDocument: firestore.Precondition(exists: false),
            ),
            firestore.Write(
              update: firestore.Document(
                name: rewardGrantPath,
                fields: encodeFirestoreFields(rewardGrantPayload),
              ),
              updateMask: firestore.DocumentMask(
                fieldPaths: rewardGrantPayload.keys.toList(growable: false),
              ),
              currentDocument: firestore.Precondition(
                updateTime: rewardGrantUpdateTime,
              ),
            ),
            firestore.Write(
              update: firestore.Document(
                name: sessionPath,
                fields: encodeFirestoreFields(sessionPayload),
              ),
              updateMask: firestore.DocumentMask(
                fieldPaths: sessionPayload.keys.toList(growable: false),
              ),
              currentDocument: firestore.Precondition(
                updateTime: sessionUpdateTime,
              ),
            ),
          ],
        ),
        _databaseRoot,
      );
    } catch (error) {
      if (isApiConflict(error)) {
        throw StateError(
          'Accepted settlement handoff conflicted for "$runSessionId".',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> markTerminal({
    required String runSessionId,
    required RunSessionTerminalState terminalState,
    String? message,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final path = _runSessionDocPath(runSessionId);
    final nowMs = _clockMs();
    await firestoreApi.projects.databases.documents.patch(
      firestore.Document(
        fields: encodeFirestoreFields(<String, Object?>{
          'state': terminalState.wireValue,
          'updatedAtMs': nowMs,
          'terminalAtMs': nowMs,
          'message': message,
        }),
      ),
      path,
      updateMask_fieldPaths: const <String>[
        'state',
        'updatedAtMs',
        'terminalAtMs',
        'message',
      ],
    );
  }

  @override
  Future<void> markPendingValidationRetry({
    required String runSessionId,
    required int nextAttemptAtMs,
    required String message,
    int? internalErrorFirstAtMs,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final path = _runSessionDocPath(runSessionId);
    final existing = await firestoreApi.projects.databases.documents.get(path);
    final existingState = decodeFirestoreFields(existing.fields)['state'];
    if (existingState != 'validating') {
      return;
    }
    final updateTime = existing.updateTime;
    if (updateTime == null || updateTime.isEmpty) {
      throw StateError('runSessionId "$runSessionId" is missing updateTime.');
    }
    final nowMs = _clockMs();
    try {
      await firestoreApi.projects.databases.documents.patch(
        firestore.Document(
          fields: encodeFirestoreFields(<String, Object?>{
            'state': 'pending_validation',
            'updatedAtMs': nowMs,
            'validationNextAttemptAtMs': nextAttemptAtMs,
            'message': message,
            'internalErrorFirstAtMs': internalErrorFirstAtMs,
          }),
        ),
        path,
        updateMask_fieldPaths: const <String>[
          'state',
          'updatedAtMs',
          'validationNextAttemptAtMs',
          'message',
          'internalErrorFirstAtMs',
        ],
        currentDocument_updateTime: updateTime,
      );
    } catch (error) {
      if (isApiConflict(error)) {
        return;
      }
      rethrow;
    }
  }

  void _assertSettlementHandoffBindings({
    required String runSessionId,
    required Map<String, Object?> session,
    required Map<String, Object?> rewardGrant,
    required ValidatedRun validatedRun,
  }) {
    if (session['state'] != 'validating') {
      throw StateError(
        'runSessionId "$runSessionId" must be validating before handoff.',
      );
    }
    if (session['uid'] != validatedRun.uid) {
      throw StateError(
        'runSessionId "$runSessionId" uid does not match validated run.',
      );
    }
    if (session['mode'] != validatedRun.mode.name ||
        rewardGrant['mode'] != validatedRun.mode.name) {
      throw StateError(
        'runSessionId "$runSessionId" mode does not match validated run.',
      );
    }
    if (rewardGrant['uid'] != validatedRun.uid ||
        rewardGrant['runSessionId'] != runSessionId) {
      throw StateError(
        'reward grant "$runSessionId" does not match the validated run.',
      );
    }
    final rewardState = rewardGrant['lifecycleState'];
    if (rewardState != 'provisional_created' &&
        rewardState != 'provisional_visible') {
      throw StateError(
        'reward grant "$runSessionId" must be provisional before handoff.',
      );
    }
    if (session['boardId'] != validatedRun.boardId ||
        rewardGrant['boardId'] != validatedRun.boardId ||
        !_sameJsonValue(session['boardKey'], validatedRun.boardKey?.toJson()) ||
        !_sameJsonValue(
          rewardGrant['boardKey'],
          validatedRun.boardKey?.toJson(),
        )) {
      throw StateError(
        'runSessionId "$runSessionId" board context does not match validated run.',
      );
    }
  }

  bool _sameJsonValue(Object? left, Object? right) {
    if (left is Map && right is Map) {
      if (left.length != right.length) {
        return false;
      }
      for (final entry in left.entries) {
        if (!right.containsKey(entry.key) ||
            !_sameJsonValue(entry.value, right[entry.key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) {
        return false;
      }
      for (var index = 0; index < left.length; index += 1) {
        if (!_sameJsonValue(left[index], right[index])) {
          return false;
        }
      }
      return true;
    }
    return left == right;
  }

  ValidatorRunSession? _decodeValidatorRunSession(
    Map<String, Object?> decoded,
    String fallbackRunSessionId,
  ) {
    final uid = decoded['uid'];
    final runTicketRaw = decoded['runTicket'];
    final uploadedReplayRaw = decoded['uploadedReplay'];
    if (uid is! String ||
        uid.trim().isEmpty ||
        runTicketRaw is! Map ||
        uploadedReplayRaw is! Map) {
      return null;
    }
    final normalizedRunSessionId =
        (decoded['runSessionId'] as String?)?.trim().isNotEmpty == true
        ? (decoded['runSessionId'] as String).trim()
        : fallbackRunSessionId;
    try {
      final runTicket = RunTicket.fromJson(
        Map<String, Object?>.from(runTicketRaw),
      );
      final uploadedReplay = _decodeUploadedReplay(uploadedReplayRaw);
      final attempt = _readInt(decoded['validationAttempt']) ?? 0;
      return ValidatorRunSession(
        runSessionId: normalizedRunSessionId,
        uid: uid.trim(),
        runTicket: runTicket,
        uploadedReplay: uploadedReplay,
        validationAttempt: attempt,
        internalErrorFirstAtMs: _readInt(decoded['internalErrorFirstAtMs']),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  UploadedReplayRef _decodeUploadedReplay(Map<Object?, Object?> raw) {
    final objectPath = raw['objectPath'];
    final canonicalSha256 = raw['canonicalSha256'];
    final contentLengthBytes = _readInt(raw['contentLengthBytes']);
    final contentType = raw['contentType'];
    if (objectPath is! String ||
        objectPath.trim().isEmpty ||
        canonicalSha256 is! String ||
        canonicalSha256.trim().isEmpty ||
        contentLengthBytes == null ||
        contentLengthBytes <= 0) {
      throw const FormatException('uploadedReplay payload is invalid.');
    }
    return UploadedReplayRef(
      objectPath: objectPath.trim(),
      canonicalSha256: canonicalSha256.trim(),
      contentLengthBytes: contentLengthBytes,
      contentType: contentType is String && contentType.trim().isNotEmpty
          ? contentType.trim()
          : null,
    );
  }

  int? _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  bool _isTerminalState(String state) {
    return state == 'validated' ||
        state == 'rejected' ||
        state == 'expired' ||
        state == 'cancelled' ||
        state == 'internal_error';
  }
}

int _defaultClockMs() => DateTime.now().millisecondsSinceEpoch;
