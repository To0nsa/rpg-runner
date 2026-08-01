import 'dart:convert';
import 'dart:math';

import 'package:run_protocol/run_ticket.dart';
import 'package:run_protocol/validated_run.dart';
import 'package:googleapis/firestore/v1.dart' as firestore;

import 'account_deletion_fence.dart';
import 'firestore_value_codec.dart';
import 'google_api_helpers.dart';
import 'validated_replay_archiver.dart';

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

final class ValidationLease {
  const ValidationLease({required this.token, required this.expiresAtMs});

  final String token;
  final int expiresAtMs;
}

final class StaleValidationLeaseException implements Exception {
  const StaleValidationLeaseException(this.runSessionId);

  final String runSessionId;

  @override
  String toString() => 'Stale validation lease for "$runSessionId".';
}

final class UploadedReplayRef {
  const UploadedReplayRef({
    required this.objectPath,
    required this.canonicalSha256,
    required this.contentLengthBytes,
    required this.finalizedAtMs,
    this.contentType,
    this.storageGeneration,
  });

  final String objectPath;
  final String canonicalSha256;
  final int contentLengthBytes;
  final int finalizedAtMs;
  final String? contentType;
  final String? storageGeneration;
}

final class ValidatorRunSession {
  const ValidatorRunSession({
    required this.runSessionId,
    required this.uid,
    required this.runTicket,
    required this.uploadedReplay,
    required this.validationAttempt,
    this.validationLease,
    this.internalErrorFirstAtMs,
  });

  final String runSessionId;
  final String uid;
  final RunTicket runTicket;
  final UploadedReplayRef uploadedReplay;
  final int validationAttempt;
  final ValidationLease? validationLease;
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
    required String validationLeaseToken,
  });

  Future<void> handoffRejectedRun({
    required ValidatedRun validatedRun,
    required String validationLeaseToken,
    required String publicMessage,
  });

  Future<void> handoffInternalError({
    required String runSessionId,
    required String validationLeaseToken,
    required String publicMessage,
  });

  Future<void> markPendingValidationRetry({
    required String runSessionId,
    required String validationLeaseToken,
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
    required String validationLeaseToken,
    required int nextAttemptAtMs,
    required String message,
    int? internalErrorFirstAtMs,
  }) async {}

  @override
  Future<void> handoffAcceptedRunForSettlement({
    required ValidatedRun validatedRun,
    required String validationLeaseToken,
  }) async {}

  @override
  Future<void> handoffRejectedRun({
    required ValidatedRun validatedRun,
    required String validationLeaseToken,
    required String publicMessage,
  }) async {}

  @override
  Future<void> handoffInternalError({
    required String runSessionId,
    required String validationLeaseToken,
    required String publicMessage,
  }) async {}
}

class FirestoreRunSessionRepository implements RunSessionRepository {
  static const int _maxImmediateLeaseAcquireAttempts = 2;

  FirestoreRunSessionRepository({
    required this.projectId,
    required this.apiProvider,
    this.validationLeaseDuration = const Duration(minutes: 10),
    int Function()? clockMs,
    String Function()? leaseTokenFactory,
    FirestoreAccountDeletionFence? deletionFence,
  }) : _clockMs = clockMs ?? _defaultClockMs,
       _leaseTokenFactory = leaseTokenFactory ?? _defaultLeaseToken,
       _deletionFence =
           deletionFence ??
           FirestoreAccountDeletionFence(
             projectId: projectId,
             apiProvider: apiProvider,
           ) {
    if (validationLeaseDuration <= Duration.zero) {
      throw ArgumentError.value(
        validationLeaseDuration,
        'validationLeaseDuration',
        'must be positive',
      );
    }
  }

  final String projectId;
  final GoogleCloudApiProvider apiProvider;
  final Duration validationLeaseDuration;
  final int Function() _clockMs;
  final String Function() _leaseTokenFactory;
  final FirestoreAccountDeletionFence _deletionFence;

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
    for (
      var attempt = 0;
      attempt < _maxImmediateLeaseAcquireAttempts;
      attempt += 1
    ) {
      final result = await _acquireValidationLeaseOnce(
        firestoreApi: firestoreApi,
        docPath: docPath,
        runSessionId: runSessionId,
      );
      if (result != null) {
        return result;
      }
    }

    return RunSessionLeaseAcquireResult(
      status: RunSessionLeaseStatus.alreadyValidating,
      message:
          'runSessionId "$runSessionId" lease contention persisted after '
          '$_maxImmediateLeaseAcquireAttempts immediate attempts.',
    );
  }

  /// Returns null only for an optimistic-concurrency conflict that can be
  /// resolved by immediately reading the session again.
  Future<RunSessionLeaseAcquireResult?> _acquireValidationLeaseOnce({
    required firestore.FirestoreApi firestoreApi,
    required String docPath,
    required String runSessionId,
  }) async {
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
    final nowMs = _clockMs();
    final existingLeaseExpiresAtMs =
        _readInt(decoded['validationLeaseExpiresAtMs']) ??
        _legacyLeaseExpiresAtMs(decoded);
    final reclaimingExpiredLease =
        state == 'validating' &&
        existingLeaseExpiresAtMs != null &&
        existingLeaseExpiresAtMs <= nowMs;
    if (state == 'validating' && !reclaimingExpiredLease) {
      return RunSessionLeaseAcquireResult(
        status: RunSessionLeaseStatus.alreadyValidating,
        message: existingLeaseExpiresAtMs == null
            ? 'runSessionId "$runSessionId" has an active legacy validation '
                  'lease without an expiry.'
            : 'runSessionId "$runSessionId" is already validating until '
                  '$existingLeaseExpiresAtMs.',
      );
    }
    // Accept both states to avoid a race where Cloud Tasks dispatches a freshly
    // enqueued validation task before the finalize flow flips uploaded ->
    // pending_validation.
    if (state != 'pending_validation' &&
        state != 'uploaded' &&
        !reclaimingExpiredLease) {
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
    final leaseToken = _leaseTokenFactory();
    if (leaseToken.trim().isEmpty) {
      throw StateError(
        'Validation lease token factory returned an empty token.',
      );
    }
    final leaseExpiresAtMs = nowMs + validationLeaseDuration.inMilliseconds;
    final patch = firestore.Document(
      fields: encodeFirestoreFields(<String, Object?>{
        'state': 'validating',
        'updatedAtMs': nowMs,
        'validationAttempt': nextAttempt,
        'validationStartedAtMs': nowMs,
        'validationLeaseToken': leaseToken,
        'validationLeaseExpiresAtMs': leaseExpiresAtMs,
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
          'validationLeaseToken',
          'validationLeaseExpiresAtMs',
          'message',
        ],
      );
    } catch (error) {
      if (isApiConflict(error)) {
        return null;
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
        validationLease: ValidationLease(
          token: leaseToken,
          expiresAtMs: leaseExpiresAtMs,
        ),
        internalErrorFirstAtMs: session.internalErrorFirstAtMs,
      ),
      message: reclaimingExpiredLease
          ? 'runSessionId "$runSessionId" expired validation lease reclaimed.'
          : 'runSessionId "$runSessionId" validation lease acquired.',
    );
  }

  @override
  Future<void> handoffAcceptedRunForSettlement({
    required ValidatedRun validatedRun,
    required String validationLeaseToken,
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
    _assertValidationHandoffBindings(
      runSessionId: runSessionId,
      session: session,
      rewardGrant: rewardGrant,
      validatedRun: validatedRun,
      validationLeaseToken: validationLeaseToken,
    );

    final nowMs = _clockMs();
    final validatedRunPayload = validatedRun.toJson();
    final validatedReplayPayload = _validatedReplayPayload(
      runSessionId: runSessionId,
      session: session,
      validatedRun: validatedRun,
      archivedAtMs: nowMs,
    );
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
      'settlementRepairDisposition': 'retryable',
      'settlementRepairClassifiedAtMs': nowMs,
      'settlementRepairAttempts': 0,
      'message': 'Reward settlement pending.',
      'validationLeaseToken': null,
      'validationLeaseExpiresAtMs': null,
      if (validatedReplayPayload != null)
        'validatedReplay': validatedReplayPayload,
    };

    try {
      final transaction = await _deletionFence.begin(
        uids: <String>[validatedRun.uid],
      );
      await transaction.commit(<firestore.Write>[
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
      ]);
    } catch (error) {
      if (isApiConflict(error)) {
        throw StaleValidationLeaseException(runSessionId);
      }
      rethrow;
    }
  }

  @override
  Future<void> handoffRejectedRun({
    required ValidatedRun validatedRun,
    required String validationLeaseToken,
    required String publicMessage,
  }) async {
    if (validatedRun.accepted) {
      throw ArgumentError.value(
        validatedRun.accepted,
        'validatedRun.accepted',
        'Rejected handoff requires a rejected run.',
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
    final sessionUpdateTime = _requireUpdateTime(
      sessionDocument,
      'runSessionId "$runSessionId"',
    );
    final rewardGrantUpdateTime = _requireUpdateTime(
      rewardGrantDocument,
      'reward grant "$runSessionId"',
    );
    _assertValidationHandoffBindings(
      runSessionId: runSessionId,
      session: session,
      rewardGrant: rewardGrant,
      validatedRun: validatedRun,
      validationLeaseToken: validationLeaseToken,
    );

    final nowMs = _clockMs();
    final validatedRunPayload = validatedRun.toJson();
    final rewardGrantPayload = _revokedRewardGrantPayload(
      nowMs: nowMs,
      settlementReason: validatedRun.rejectionReason ?? 'rejected',
    );
    final sessionPayload = <String, Object?>{
      'state': RunSessionTerminalState.rejected.wireValue,
      'updatedAtMs': nowMs,
      'terminalAtMs': nowMs,
      'message': publicMessage,
      'validationLeaseToken': null,
      'validationLeaseExpiresAtMs': null,
    };
    await _commitTerminalHandoff(
      runSessionId: runSessionId,
      uid: validatedRun.uid,
      validatedRunPath: validatedRunPath,
      validatedRunPayload: validatedRunPayload,
      rewardGrantPath: rewardGrantPath,
      rewardGrantPayload: rewardGrantPayload,
      rewardGrantUpdateTime: rewardGrantUpdateTime,
      sessionPath: sessionPath,
      sessionPayload: sessionPayload,
      sessionUpdateTime: sessionUpdateTime,
    );
  }

  @override
  Future<void> handoffInternalError({
    required String runSessionId,
    required String validationLeaseToken,
    required String publicMessage,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final sessionPath = _runSessionDocPath(runSessionId);
    final rewardGrantPath = _rewardGrantDocPath(runSessionId);
    final sessionDocument = await firestoreApi.projects.databases.documents.get(
      sessionPath,
    );
    final rewardGrantDocument = await firestoreApi.projects.databases.documents
        .get(rewardGrantPath);
    final session = decodeFirestoreFields(sessionDocument.fields);
    final rewardGrant = decodeFirestoreFields(rewardGrantDocument.fields);
    final sessionUpdateTime = _requireUpdateTime(
      sessionDocument,
      'runSessionId "$runSessionId"',
    );
    final rewardGrantUpdateTime = _requireUpdateTime(
      rewardGrantDocument,
      'reward grant "$runSessionId"',
    );
    _assertLeaseAndRewardBindings(
      runSessionId: runSessionId,
      session: session,
      rewardGrant: rewardGrant,
      validationLeaseToken: validationLeaseToken,
    );

    final nowMs = _clockMs();
    final rewardGrantPayload = _revokedRewardGrantPayload(
      nowMs: nowMs,
      settlementReason: RunSessionTerminalState.internalError.wireValue,
    );
    final sessionPayload = <String, Object?>{
      'state': RunSessionTerminalState.internalError.wireValue,
      'updatedAtMs': nowMs,
      'terminalAtMs': nowMs,
      'message': publicMessage,
      'validationLeaseToken': null,
      'validationLeaseExpiresAtMs': null,
    };
    try {
      final transaction = await _deletionFence.begin(
        uids: <String>[_requireUid(session['uid'])],
      );
      await transaction.commit(<firestore.Write>[
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
      ]);
    } catch (error) {
      if (isApiConflict(error)) {
        throw StaleValidationLeaseException(runSessionId);
      }
      rethrow;
    }
  }

  /*
   * A pending retry releases the lease. The next delivery must acquire a new
   * token before it can write validation-owned state.
   */
  @override
  Future<void> markPendingValidationRetry({
    required String runSessionId,
    required String validationLeaseToken,
    required int nextAttemptAtMs,
    required String message,
    int? internalErrorFirstAtMs,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final path = _runSessionDocPath(runSessionId);
    final ownedLease = await _loadOwnedLease(
      firestoreApi: firestoreApi,
      path: path,
      runSessionId: runSessionId,
      validationLeaseToken: validationLeaseToken,
    );
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
            'validationLeaseToken': null,
            'validationLeaseExpiresAtMs': null,
          }),
        ),
        path,
        updateMask_fieldPaths: const <String>[
          'state',
          'updatedAtMs',
          'validationNextAttemptAtMs',
          'message',
          'internalErrorFirstAtMs',
          'validationLeaseToken',
          'validationLeaseExpiresAtMs',
        ],
        currentDocument_updateTime: ownedLease.updateTime,
      );
    } catch (error) {
      if (isApiConflict(error)) {
        throw StaleValidationLeaseException(runSessionId);
      }
      rethrow;
    }
  }

  void _assertValidationHandoffBindings({
    required String runSessionId,
    required Map<String, Object?> session,
    required Map<String, Object?> rewardGrant,
    required ValidatedRun validatedRun,
    required String validationLeaseToken,
  }) {
    _assertLeaseAndRewardBindings(
      runSessionId: runSessionId,
      session: session,
      rewardGrant: rewardGrant,
      validationLeaseToken: validationLeaseToken,
    );
    if (session['uid'] != validatedRun.uid) {
      throw StateError(
        'runSessionId "$runSessionId" uid does not match validated run.',
      );
    }
    if (session['mode'] != validatedRun.mode.name) {
      throw StateError(
        'runSessionId "$runSessionId" mode does not match validated run.',
      );
    }
    if (session['boardId'] != validatedRun.boardId ||
        !_sameJsonValue(session['boardKey'], validatedRun.boardKey?.toJson())) {
      throw StateError(
        'runSessionId "$runSessionId" board context does not match validated run.',
      );
    }
    final uploadedReplay = session['uploadedReplay'];
    if (uploadedReplay is! Map ||
        uploadedReplay['canonicalSha256'] != validatedRun.replayDigest) {
      throw StateError(
        'runSessionId "$runSessionId" replay evidence does not match validated run.',
      );
    }
    final matchesUploadedReplay =
        uploadedReplay['objectPath'] == validatedRun.replayStorageRef &&
        uploadedReplay['storageGeneration'] ==
            validatedRun.replayStorageGeneration;
    final matchesValidatedReplay = _isSealedValidatedReplay(
      runSessionId: runSessionId,
      uploadedReplay: uploadedReplay,
      validatedRun: validatedRun,
    );
    if (!matchesUploadedReplay && !matchesValidatedReplay) {
      throw StateError(
        'runSessionId "$runSessionId" replay artifact does not preserve the '
        'uploaded replay evidence.',
      );
    }
  }

  Map<String, Object?>? _validatedReplayPayload({
    required String runSessionId,
    required Map<String, Object?> session,
    required ValidatedRun validatedRun,
    required int archivedAtMs,
  }) {
    final uploadedReplay = session['uploadedReplay'];
    if (uploadedReplay is! Map ||
        !_isSealedValidatedReplay(
          runSessionId: runSessionId,
          uploadedReplay: uploadedReplay,
          validatedRun: validatedRun,
        )) {
      return null;
    }
    return <String, Object?>{
      'objectPath': validatedRun.replayStorageRef,
      'storageGeneration': validatedRun.replayStorageGeneration,
      'canonicalSha256': validatedRun.replayDigest,
      'sourceObjectPath': uploadedReplay['objectPath'],
      'sourceStorageGeneration': uploadedReplay['storageGeneration'],
      'archivedAtMs': archivedAtMs,
    };
  }

  bool _isSealedValidatedReplay({
    required String runSessionId,
    required Map uploadedReplay,
    required ValidatedRun validatedRun,
  }) {
    final sourceObjectPath = uploadedReplay['objectPath'];
    final sourceGeneration = uploadedReplay['storageGeneration'];
    final destinationGeneration = validatedRun.replayStorageGeneration;
    return sourceObjectPath is String &&
        sourceObjectPath.isNotEmpty &&
        sourceGeneration is String &&
        RegExp(r'^[1-9][0-9]*$').hasMatch(sourceGeneration) &&
        destinationGeneration != null &&
        RegExp(r'^[1-9][0-9]*$').hasMatch(destinationGeneration) &&
        validatedRun.replayStorageRef ==
            validatedReplayObjectPath(runSessionId);
  }

  void _assertLeaseAndRewardBindings({
    required String runSessionId,
    required Map<String, Object?> session,
    required Map<String, Object?> rewardGrant,
    required String validationLeaseToken,
  }) {
    if (session['state'] != 'validating') {
      throw StateError(
        'runSessionId "$runSessionId" must be validating before handoff.',
      );
    }
    if (session['validationLeaseToken'] != validationLeaseToken) {
      throw StaleValidationLeaseException(runSessionId);
    }
    final leaseExpiresAtMs = _readInt(session['validationLeaseExpiresAtMs']);
    if (leaseExpiresAtMs == null || leaseExpiresAtMs <= _clockMs()) {
      throw StaleValidationLeaseException(runSessionId);
    }
    if (session['uid'] != rewardGrant['uid'] ||
        rewardGrant['runSessionId'] != runSessionId) {
      throw StateError(
        'reward grant "$runSessionId" does not match the validating session.',
      );
    }
    if (session['mode'] != rewardGrant['mode']) {
      throw StateError(
        'reward grant "$runSessionId" mode does not match the session.',
      );
    }
    final rewardState = rewardGrant['lifecycleState'];
    if (rewardState != 'provisional_created' &&
        rewardState != 'provisional_visible') {
      throw StateError(
        'reward grant "$runSessionId" must be provisional before handoff.',
      );
    }
    if (session['boardId'] != rewardGrant['boardId'] ||
        !_sameJsonValue(session['boardKey'], rewardGrant['boardKey'])) {
      throw StateError(
        'reward grant "$runSessionId" board context does not match the session.',
      );
    }
  }

  Map<String, Object?> _revokedRewardGrantPayload({
    required int nowMs,
    required String settlementReason,
  }) {
    return <String, Object?>{
      'lifecycleState': 'revoked_final',
      'updatedAtMs': nowMs,
      'revokedAtMs': nowMs,
      'revokedFinalAtMs': nowMs,
      'settlementReason': settlementReason,
      'lastTransitionBy': 'validator_terminal_handoff',
      'revokedFinalBy': 'validator_terminal_handoff',
    };
  }

  Future<void> _commitTerminalHandoff({
    required String runSessionId,
    required String uid,
    required String validatedRunPath,
    required Map<String, Object?> validatedRunPayload,
    required String rewardGrantPath,
    required Map<String, Object?> rewardGrantPayload,
    required String rewardGrantUpdateTime,
    required String sessionPath,
    required Map<String, Object?> sessionPayload,
    required String sessionUpdateTime,
  }) async {
    try {
      final transaction = await _deletionFence.begin(uids: <String>[uid]);
      await transaction.commit(<firestore.Write>[
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
      ]);
    } catch (error) {
      if (isApiConflict(error)) {
        throw StaleValidationLeaseException(runSessionId);
      }
      rethrow;
    }
  }

  String _requireUpdateTime(firestore.Document document, String label) {
    final updateTime = document.updateTime;
    if (updateTime == null || updateTime.isEmpty) {
      throw StateError('$label is missing updateTime.');
    }
    return updateTime;
  }

  String _requireUid(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw StateError('Run-session uid must be a non-empty string.');
    }
    return value.trim();
  }

  Future<_OwnedLeaseDocument> _loadOwnedLease({
    required firestore.FirestoreApi firestoreApi,
    required String path,
    required String runSessionId,
    required String validationLeaseToken,
  }) async {
    final existing = await firestoreApi.projects.databases.documents.get(path);
    final decoded = decodeFirestoreFields(existing.fields);
    if (decoded['state'] != 'validating' ||
        decoded['validationLeaseToken'] != validationLeaseToken) {
      throw StaleValidationLeaseException(runSessionId);
    }
    final leaseExpiresAtMs = _readInt(decoded['validationLeaseExpiresAtMs']);
    if (leaseExpiresAtMs == null || leaseExpiresAtMs <= _clockMs()) {
      throw StaleValidationLeaseException(runSessionId);
    }
    final updateTime = existing.updateTime;
    if (updateTime == null || updateTime.isEmpty) {
      throw StateError('runSessionId "$runSessionId" is missing updateTime.');
    }
    return _OwnedLeaseDocument(updateTime: updateTime);
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
    final finalizedAtMs = _readInt(raw['finalizedAtMs']);
    final contentType = raw['contentType'];
    final storageGeneration = raw['storageGeneration'];
    if (objectPath is! String ||
        objectPath.trim().isEmpty ||
        canonicalSha256 is! String ||
        canonicalSha256.trim().isEmpty ||
        contentLengthBytes == null ||
        contentLengthBytes <= 0 ||
        finalizedAtMs == null ||
        finalizedAtMs <= 0) {
      throw const FormatException('uploadedReplay payload is invalid.');
    }
    return UploadedReplayRef(
      objectPath: objectPath.trim(),
      canonicalSha256: canonicalSha256.trim(),
      contentLengthBytes: contentLengthBytes,
      finalizedAtMs: finalizedAtMs,
      contentType: contentType is String && contentType.trim().isNotEmpty
          ? contentType.trim()
          : null,
      storageGeneration:
          storageGeneration is String && storageGeneration.trim().isNotEmpty
          ? storageGeneration.trim()
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

  int? _legacyLeaseExpiresAtMs(Map<String, Object?> decoded) {
    final startedAtMs = _readInt(decoded['validationStartedAtMs']);
    if (startedAtMs == null) {
      return null;
    }
    return startedAtMs + validationLeaseDuration.inMilliseconds;
  }

  bool _isTerminalState(String state) {
    return state == 'validated' ||
        state == 'rejected' ||
        state == 'expired' ||
        state == 'cancelled' ||
        state == 'internal_error';
  }
}

final class _OwnedLeaseDocument {
  const _OwnedLeaseDocument({required this.updateTime});

  final String updateTime;
}

int _defaultClockMs() => DateTime.now().millisecondsSinceEpoch;

String _defaultLeaseToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
