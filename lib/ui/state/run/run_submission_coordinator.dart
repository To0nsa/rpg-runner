import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/submission_status.dart'
    show RunSessionState, SubmissionRewardStatus, SubmissionStatus;

import '../../run/run_reward_diagnostics.dart';
import 'local_replay_artifact_store.dart';
import 'pending_run_submission.dart';
import 'run_session_api.dart';
import 'run_replay_uploader.dart';

export 'run_replay_uploader.dart'
    show RunReplayUploader, RunReplayUploadException;
import 'run_start_remote_exception.dart';
import 'run_submission_spool_store.dart';
import 'run_submission_status.dart';

typedef RunSubmissionClock = int Function();

class RunSubmissionCoordinator {
  RunSubmissionCoordinator({
    required RunSessionApi runSessionApi,
    required RunSubmissionSpoolStore spoolStore,
    RunReplayUploader? replayUploader,
    LocalReplayArtifactStore? localReplayArtifactStore,
    RunSubmissionClock? clock,
    List<Duration>? retryBackoffSchedule,
    this.verificationDelayedThresholdMs =
        RunSubmissionStatus.defaultVerificationDelayedThresholdMs,
  }) : _runSessionApi = runSessionApi,
       _spoolStore = spoolStore,
       _replayUploader = replayUploader ?? createRunReplayUploader(),
       _localReplayArtifactStore =
           localReplayArtifactStore ?? createLocalReplayArtifactStore(),
       _clock = clock ?? _defaultClock,
       _retryBackoffSchedule =
           retryBackoffSchedule ?? _defaultRetryBackoffSchedule;

  final RunSessionApi _runSessionApi;
  final RunSubmissionSpoolStore _spoolStore;
  final RunReplayUploader _replayUploader;
  final LocalReplayArtifactStore _localReplayArtifactStore;
  final RunSubmissionClock _clock;
  final List<Duration> _retryBackoffSchedule;
  final int verificationDelayedThresholdMs;
  bool _localSubmissionsDiscarded = false;
  final Set<Future<void>> _spoolMutations = <Future<void>>{};
  final Map<(String, String), Future<RunUploadGrant>> _preparedGrants = {};

  /// Best-effort work for an actual run, never a prerequisite for starting it.
  /// Credentials stay in memory and are consumed once, with an expiry margin.
  Future<void> prepareUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    if (_localSubmissionsDiscarded) return;
    final key = (userId, runSessionId);
    if (_preparedGrants.containsKey(key)) return;
    while (_preparedGrants.length >= 4) {
      _preparedGrants.remove(_preparedGrants.keys.first);
    }
    final pending = _requestUploadGrant(
      userId: userId,
      sessionId: sessionId,
      runSessionId: runSessionId,
      stage: 'upload_grant_prepare',
    );
    _preparedGrants[key] = pending;
    try {
      await pending;
    } catch (_) {
      if (identical(_preparedGrants[key], pending)) _preparedGrants.remove(key);
      // Submission retries authoritatively when the replay is available.
    }
  }

  void clearPreparedUploads() => _preparedGrants.clear();

  Future<RunUploadGrant> _requestUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
    String stage = 'upload_grant',
  }) => RunRewardDiagnostics.instance.measure(runSessionId, stage, () async {
    final grant = await _runSessionApi.createUploadGrant(
      userId: userId,
      sessionId: sessionId,
      runSessionId: runSessionId,
    );
    if (grant.runSessionId != runSessionId) {
      throw const FormatException('Upload grant belongs to another run.');
    }
    return grant;
  });

  Future<RunUploadGrant> _takeUploadGrant({
    required String userId,
    required String sessionId,
    required PendingRunSubmission submission,
  }) async {
    final prepared = _preparedGrants.remove((userId, submission.runSessionId));
    if (prepared != null) {
      try {
        final grant = await prepared;
        if (grant.expiresAtMs > _clock() + 30000 &&
            grant.contentType == submission.contentType &&
            grant.maxBytes >= submission.contentLengthBytes) {
          RunRewardDiagnostics.instance.emit(
            submission.runSessionId,
            'upload_grant_reused',
          );
          return grant;
        }
      } catch (_) {
        /* Normal submission owns retries after preparation fails. */
      }
    }
    return _requestUploadGrant(
      userId: userId,
      sessionId: sessionId,
      runSessionId: submission.runSessionId,
    );
  }

  Future<void> _persistSubmission({required PendingRunSubmission submission}) =>
      RunRewardDiagnostics.instance.measure(
        submission.runSessionId,
        'spool_write',
        () => _mutateSpool(() => _spoolStore.upsert(submission: submission)),
        fields: {
          'step': submission.step.name,
          'attempt': submission.attemptCount,
          'retryAtMs': submission.nextAttemptAtMs,
        },
      );

  Future<void> _removeSubmission({required String runSessionId}) =>
      _mutateSpool(() => _spoolStore.remove(runSessionId: runSessionId));

  Future<void> _mutateSpool(Future<void> Function() mutation) async {
    if (_localSubmissionsDiscarded) return;
    final pending = mutation();
    _spoolMutations.add(pending);
    try {
      await pending;
    } finally {
      _spoolMutations.remove(pending);
    }
  }

  static const List<Duration> _defaultRetryBackoffSchedule = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
  ];

  static const Set<String> _nonRetryableRemoteErrorCodes = <String>{
    'invalid-argument',
    'failed-precondition',
    'permission-denied',
    'not-found',
    'already-exists',
    'unimplemented',
  };

  Future<PendingRunSubmission> enqueueSubmission({
    required String userId,
    required String runSessionId,
    required RunMode runMode,
    required String replayArtifactId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String contentType = 'application/octet-stream',
    Map<String, Object?>? provisionalSummary,
  }) async {
    if (_localSubmissionsDiscarded) {
      throw StateError('Local submissions have been discarded.');
    }
    final nowMs = _clock();
    final pending = PendingRunSubmission(
      ownerUserId: userId,
      runSessionId: runSessionId,
      runMode: runMode,
      replayArtifactId: replayArtifactId,
      canonicalSha256: canonicalSha256,
      contentLengthBytes: contentLengthBytes,
      contentType: contentType,
      step: PendingRunSubmissionStep.queued,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
      provisionalSummary: provisionalSummary,
    );
    await _persistSubmission(submission: pending);
    return pending;
  }

  Future<List<RunSubmissionStatus>> loadLocalStatuses({
    required String userId,
  }) async {
    final nowMs = _clock();
    final pendingEntries = await _spoolStore.loadAll();
    return pendingEntries
        .where((pending) => pending.ownerUserId == userId)
        .map(
          (pending) => RunSubmissionStatus.fromPending(
            pending,
            nowMs: nowMs,
            verificationDelayedThresholdMs: verificationDelayedThresholdMs,
          ),
        )
        .toList(growable: false);
  }

  /// Removes durable upload metadata and the app-owned recorder spool.
  ///
  /// Both cleanup steps are attempted so a missing or locked replay file does
  /// not leave the submission spool behind after account deletion.
  /// This permanently fences spool mutations for this coordinator instance.
  Future<void> discardAllLocalSubmissions() async {
    _localSubmissionsDiscarded = true;
    clearPreparedUploads();
    for (final pending in _spoolMutations.toList()) {
      try {
        await pending;
      } catch (_) {
        /* The caller owns the mutation error. */
      }
    }
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _spoolStore.clear();
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      await _localReplayArtifactStore.clear();
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }

  Future<List<RunSubmissionStatus>> processReadySubmissions({
    required String userId,
    required String sessionId,
  }) async {
    if (_localSubmissionsDiscarded) return const <RunSubmissionStatus>[];
    final nowMs = _clock();
    final pendingEntries = await _spoolStore.loadAll();
    final statuses = <RunSubmissionStatus>[];
    for (final pending in pendingEntries) {
      if (pending.ownerUserId != userId) {
        continue;
      }
      if (_isRetryDeferred(pending, nowMs)) {
        statuses.add(
          RunSubmissionStatus.fromPending(
            pending,
            nowMs: nowMs,
            verificationDelayedThresholdMs: verificationDelayedThresholdMs,
          ),
        );
        continue;
      }
      final status = await processRunSession(
        userId: userId,
        sessionId: sessionId,
        runSessionId: pending.runSessionId,
      );
      statuses.add(status);
    }
    return List<RunSubmissionStatus>.unmodifiable(statuses);
  }

  Future<RunSubmissionStatus> processRunSession({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    final loaded = await _spoolStore.load(runSessionId: runSessionId);
    if (loaded == null) {
      throw StateError(
        'No pending submission was found for runSessionId "$runSessionId".',
      );
    }
    if (loaded.ownerUserId != userId) {
      throw StateError(
        'Pending submission "$runSessionId" belongs to another account.',
      );
    }
    var pending = loaded;
    final nowMs = _clock();
    if (_isRetryDeferred(pending, nowMs)) {
      return RunSubmissionStatus.fromPending(
        pending,
        nowMs: nowMs,
        verificationDelayedThresholdMs: verificationDelayedThresholdMs,
      );
    }
    if (pending.step == PendingRunSubmissionStep.awaitingServerStatus) {
      return _loadServerStatus(
        userId: userId,
        sessionId: sessionId,
        runSessionId: runSessionId,
        pendingSubmission: pending,
      );
    }

    try {
      // A timed-out call may already have committed. Reconcile before issuing a
      // new grant, which is forbidden once the server has accepted the upload.
      if (pending.step != PendingRunSubmissionStep.queued) {
        final status = await _readServerStatus(
          userId: userId,
          sessionId: sessionId,
          runSessionId: runSessionId,
        );
        if (status.state != RunSessionState.issued &&
            status.state != RunSessionState.uploading) {
          return await _receiveServerStatus(status, pending);
        }
      }

      if (pending.uploadCompletedAtMs == null || pending.objectPath == null) {
        pending = pending.copyWith(
          step: PendingRunSubmissionStep.requestingUploadGrant,
          updatedAtMs: _clock(),
          nextAttemptAtMs: 0,
          lastErrorCode: null,
          lastErrorMessage: null,
        );
        await _persistSubmission(submission: pending);

        final uploadGrant = await _takeUploadGrant(
          userId: userId,
          sessionId: sessionId,
          submission: pending,
        );

        pending = pending.copyWith(
          step: PendingRunSubmissionStep.uploading,
          updatedAtMs: _clock(),
          objectPath: uploadGrant.objectPath,
        );
        await _persistSubmission(submission: pending);

        await RunRewardDiagnostics.instance.measure(
          runSessionId,
          'upload',
          () => _replayUploader.uploadReplay(
            uploadGrant: uploadGrant,
            replayArtifactId: pending.replayArtifactId,
            contentLengthBytes: pending.contentLengthBytes,
            contentType: pending.contentType,
          ),
        );

        pending = pending.copyWith(
          step: PendingRunSubmissionStep.finalizing,
          updatedAtMs: _clock(),
          uploadCompletedAtMs: _clock(),
        );
        await _persistSubmission(submission: pending);
      }

      final submissionStatus = await RunRewardDiagnostics.instance.measure(
        runSessionId,
        'finalize',
        () => _runSessionApi.finalizeUpload(
          userId: userId,
          sessionId: sessionId,
          runSessionId: runSessionId,
          canonicalSha256: pending.canonicalSha256,
          contentLengthBytes: pending.contentLengthBytes,
          contentType: pending.contentType,
          objectPath: pending.objectPath,
          provisionalSummary: pending.provisionalSummary,
        ),
      );

      if (submissionStatus.isTerminal) {
        return await _receiveServerStatus(submissionStatus, pending);
      }

      pending = pending.copyWith(
        step: PendingRunSubmissionStep.awaitingServerStatus,
        updatedAtMs: _clock(),
        finalizedAtMs: _clock(),
        attemptCount: 0,
        nextAttemptAtMs: 0,
        lastErrorCode: null,
        lastErrorMessage: null,
      );
      await _persistSubmission(submission: pending);
      return RunSubmissionStatus.fromServerStatus(
        submissionStatus,
        pendingSubmission: pending,
        nowMs: _clock(),
        verificationDelayedThresholdMs: verificationDelayedThresholdMs,
      );
    } catch (error) {
      RunRewardDiagnostics.instance.emit(runSessionId, 'submission_failure', {
        'step': pending.step.name,
        'attempt': pending.attemptCount,
        'retryable': _isRetryableError(error),
      });
      final failedAtMs = _clock();
      // Malformed/missing finalize responses cannot prove a failed commit.
      // Keep the receipt until the server answers authoritatively on recovery.
      final ambiguousFinalization =
          pending.uploadCompletedAtMs != null && error is FormatException;
      if (!_isRetryableError(error) && !ambiguousFinalization) {
        await _removeSubmission(runSessionId: runSessionId);
        return RunSubmissionStatus(
          runSessionId: runSessionId,
          phase: RunSubmissionPhase.internalError,
          updatedAtMs: failedAtMs,
          message: _errorMessage(error),
        );
      }
      final nextAttempt = pending.attemptCount + 1;
      var delay = retryDelayForAttempt(nextAttempt);
      // A quota response is different from a dropped connection: short network
      // retries must not turn server throttling into more quota pressure.
      final throttled =
          error is RunStartRemoteException &&
              error.code == 'resource-exhausted' ||
          error is RunReplayUploadException && error.statusCode == 429;
      if (throttled && delay < const Duration(seconds: 30)) {
        delay = const Duration(seconds: 30);
      }
      final retryAtMs = failedAtMs + delay.inMilliseconds;
      final failedPending = pending.copyWith(
        step: PendingRunSubmissionStep.retryScheduled,
        updatedAtMs: failedAtMs,
        attemptCount: nextAttempt,
        nextAttemptAtMs: retryAtMs,
        lastErrorCode: _errorCode(error),
        lastErrorMessage: _errorMessage(error),
      );
      await _persistSubmission(submission: failedPending);
      return RunSubmissionStatus.fromPending(
        failedPending,
        nowMs: failedAtMs,
        verificationDelayedThresholdMs: verificationDelayedThresholdMs,
      );
    }
  }

  Future<RunSubmissionStatus> refreshRunSessionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    final pending = await _spoolStore.load(runSessionId: runSessionId);
    if (pending != null && pending.ownerUserId != userId) {
      throw StateError(
        'Pending submission "$runSessionId" belongs to another account.',
      );
    }
    if (pending != null &&
        pending.step != PendingRunSubmissionStep.awaitingServerStatus) {
      return processRunSession(
        userId: userId,
        sessionId: sessionId,
        runSessionId: runSessionId,
      );
    }
    return _loadServerStatus(
      userId: userId,
      sessionId: sessionId,
      runSessionId: runSessionId,
      pendingSubmission: pending,
    );
  }

  Duration retryDelayForAttempt(int attemptCount) {
    if (_retryBackoffSchedule.isEmpty) {
      return Duration.zero;
    }
    final index = attemptCount <= 0 ? 0 : attemptCount - 1;
    if (index >= _retryBackoffSchedule.length) {
      return _retryBackoffSchedule.last;
    }
    return _retryBackoffSchedule[index];
  }

  /// Removes a final reward receipt only after canonical ownership was loaded.
  /// Until then it survives app closure and is retried by the foreground queue.
  Future<void> acknowledgeFinalReward({required String runSessionId}) =>
      _removeSubmission(runSessionId: runSessionId);

  bool _isRetryDeferred(PendingRunSubmission pending, int nowMs) {
    return pending.step == PendingRunSubmissionStep.retryScheduled &&
        pending.nextAttemptAtMs > nowMs;
  }

  bool _isRetryableError(Object error) {
    if (error is RunReplayUploadException) {
      final statusCode = error.statusCode;
      if (statusCode == null) {
        return true;
      }
      if (statusCode == 408 || statusCode == 429) {
        return true;
      }
      return statusCode >= 500;
    }
    if (error is RunStartRemoteException) {
      return !_nonRetryableRemoteErrorCodes.contains(error.code);
    }
    if (error is FormatException) {
      return false;
    }
    return true;
  }

  String _errorCode(Object error) {
    if (error is RunStartRemoteException) {
      return error.code;
    }
    if (error is RunReplayUploadException) {
      return error.code;
    }
    if (error is FormatException) {
      return 'invalid-response';
    }
    return 'submission-processing-failed';
  }

  String _errorMessage(Object error) {
    if (error is RunStartRemoteException) {
      return error.message ?? error.code;
    }
    if (error is RunReplayUploadException) {
      return error.message;
    }
    return error.toString();
  }

  Future<RunSubmissionStatus> _loadServerStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required PendingRunSubmission? pendingSubmission,
  }) async {
    final status = await _readServerStatus(
      userId: userId,
      sessionId: sessionId,
      runSessionId: runSessionId,
    );
    return _receiveServerStatus(status, pendingSubmission);
  }

  Future<SubmissionStatus> _readServerStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    final status = await RunRewardDiagnostics.instance.measure(
      runSessionId,
      'status_poll',
      () => _runSessionApi.loadSubmissionStatus(
        userId: userId,
        sessionId: sessionId,
        runSessionId: runSessionId,
      ),
    );
    RunRewardDiagnostics.instance.emit(runSessionId, 'status_received', {
      'state': status.state.name,
      'reward': status.reward?.status.name,
    });
    if (status.runSessionId != runSessionId) {
      throw const FormatException('Submission status belongs to another run.');
    }
    return status;
  }

  Future<RunSubmissionStatus> _receiveServerStatus(
    SubmissionStatus status,
    PendingRunSubmission? pendingSubmission,
  ) async {
    if (pendingSubmission != null &&
        status.runSessionId != pendingSubmission.runSessionId) {
      throw const FormatException('Submission status belongs to another run.');
    }
    final nowMs = _clock();
    final runSessionId = status.runSessionId;
    if (status.isTerminal) {
      if (status.reward?.status != SubmissionRewardStatus.finalReward) {
        await _removeSubmission(runSessionId: runSessionId);
      } else if (pendingSubmission != null) {
        await _persistSubmission(
          submission: pendingSubmission.copyWith(
            step: PendingRunSubmissionStep.awaitingServerStatus,
            updatedAtMs: nowMs,
            nextAttemptAtMs: 0,
            lastErrorCode: null,
            lastErrorMessage: null,
          ),
        );
      }
      return RunSubmissionStatus.fromServerStatus(
        status,
        nowMs: nowMs,
        verificationDelayedThresholdMs: verificationDelayedThresholdMs,
      );
    }
    if (pendingSubmission == null) {
      return RunSubmissionStatus.fromServerStatus(
        status,
        nowMs: nowMs,
        verificationDelayedThresholdMs: verificationDelayedThresholdMs,
      );
    }
    final refreshedPending = pendingSubmission.copyWith(
      step: PendingRunSubmissionStep.awaitingServerStatus,
      updatedAtMs: nowMs,
      lastErrorCode: null,
      lastErrorMessage: null,
    );
    await _persistSubmission(submission: refreshedPending);
    return RunSubmissionStatus.fromServerStatus(
      status,
      pendingSubmission: refreshedPending,
      nowMs: nowMs,
      verificationDelayedThresholdMs: verificationDelayedThresholdMs,
    );
  }
}

int _defaultClock() => DateTime.now().millisecondsSinceEpoch;
