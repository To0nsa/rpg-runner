import 'dart:convert';
import 'dart:io';

import 'package:run_protocol/run_mode.dart';

import 'pending_run_submission.dart';
import 'run_session_api.dart';
import 'run_start_remote_exception.dart';
import 'run_submission_spool_store.dart';
import 'run_submission_status.dart';

typedef RunSubmissionClock = int Function();

abstract class RunReplayUploader {
  Future<void> uploadReplay({
    required RunUploadGrant uploadGrant,
    required String replayFilePath,
    required int contentLengthBytes,
    required String contentType,
  });
}

class HttpRunReplayUploader implements RunReplayUploader {
  HttpRunReplayUploader({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<void> uploadReplay({
    required RunUploadGrant uploadGrant,
    required String replayFilePath,
    required int contentLengthBytes,
    required String contentType,
  }) async {
    if (uploadGrant.uploadMethod.toUpperCase() != 'PUT') {
      throw const RunReplayUploadException(
        code: 'unsupported-upload-method',
        message: 'Replay upload grant method is not supported.',
      );
    }
    if (contentLengthBytes <= 0) {
      throw const RunReplayUploadException(
        code: 'invalid-content-length',
        message: 'Replay content length must be greater than zero.',
      );
    }
    if (contentLengthBytes > uploadGrant.maxBytes) {
      throw RunReplayUploadException(
        code: 'content-length-exceeds-grant',
        message:
            'Replay content length $contentLengthBytes exceeds upload grant max '
            '${uploadGrant.maxBytes}.',
      );
    }

    final replayFile = File(replayFilePath);
    if (!await replayFile.exists()) {
      throw RunReplayUploadException(
        code: 'replay-file-missing',
        message: 'Replay file does not exist at "$replayFilePath".',
      );
    }
    final fileLength = await replayFile.length();
    if (fileLength != contentLengthBytes) {
      throw RunReplayUploadException(
        code: 'content-length-mismatch',
        message:
            'Replay file length $fileLength did not match expected '
            '$contentLengthBytes.',
      );
    }

    final uploadUri = Uri.parse(uploadGrant.uploadUrl);
    final request = await _httpClient.openUrl(
      uploadGrant.uploadMethod,
      uploadUri,
    );
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      uploadGrant.contentType.isEmpty ? contentType : uploadGrant.contentType,
    );
    request.headers.set(
      HttpHeaders.contentLengthHeader,
      contentLengthBytes.toString(),
    );
    await request.addStream(replayFile.openRead());
    final response = await request.close();
    final accepted = response.statusCode >= 200 && response.statusCode < 300;
    if (accepted) {
      await response.drain<void>();
      return;
    }
    final responseBody = await utf8.decodeStream(response);
    final code =
        response.statusCode == HttpStatus.forbidden &&
            _bodyContainsAccessDenied(responseBody)
        ? 'upload-access-denied'
        : 'upload-rejected';
    throw RunReplayUploadException(
      code: code,
      message: _buildUploadRejectedMessage(
        statusCode: response.statusCode,
        responseBody: responseBody,
      ),
      statusCode: response.statusCode,
    );
  }
}

final class RunReplayUploadException implements Exception {
  const RunReplayUploadException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    final statusSegment = statusCode == null ? '' : ' statusCode=$statusCode';
    return 'RunReplayUploadException(code=$code$statusSegment, message=$message)';
  }
}

class RunSubmissionCoordinator {
  RunSubmissionCoordinator({
    required RunSessionApi runSessionApi,
    required RunSubmissionSpoolStore spoolStore,
    RunReplayUploader? replayUploader,
    RunSubmissionClock? clock,
    List<Duration>? retryBackoffSchedule,
    this.verificationDelayedThresholdMs =
        RunSubmissionStatus.defaultVerificationDelayedThresholdMs,
  }) : _runSessionApi = runSessionApi,
       _spoolStore = spoolStore,
       _replayUploader = replayUploader ?? HttpRunReplayUploader(),
       _clock = clock ?? _defaultClock,
       _retryBackoffSchedule =
           retryBackoffSchedule ?? _defaultRetryBackoffSchedule;

  final RunSessionApi _runSessionApi;
  final RunSubmissionSpoolStore _spoolStore;
  final RunReplayUploader _replayUploader;
  final RunSubmissionClock _clock;
  final List<Duration> _retryBackoffSchedule;
  final int verificationDelayedThresholdMs;

  static const List<Duration> _defaultRetryBackoffSchedule = <Duration>[
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
    'unauthenticated',
    'not-found',
    'already-exists',
    'unimplemented',
  };

  Future<PendingRunSubmission> enqueueSubmission({
    required String runSessionId,
    required RunMode runMode,
    required String replayFilePath,
    required String canonicalSha256,
    required int contentLengthBytes,
    String contentType = 'application/octet-stream',
    Map<String, Object?>? provisionalSummary,
  }) async {
    final nowMs = _clock();
    final pending = PendingRunSubmission(
      runSessionId: runSessionId,
      runMode: runMode,
      replayFilePath: replayFilePath,
      canonicalSha256: canonicalSha256,
      contentLengthBytes: contentLengthBytes,
      contentType: contentType,
      step: PendingRunSubmissionStep.queued,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
      provisionalSummary: provisionalSummary,
    );
    await _spoolStore.upsert(submission: pending);
    return pending;
  }

  Future<List<RunSubmissionStatus>> loadLocalStatuses() async {
    final nowMs = _clock();
    final pendingEntries = await _spoolStore.loadAll();
    return pendingEntries
        .map(
          (pending) => RunSubmissionStatus.fromPending(
            pending,
            nowMs: nowMs,
            verificationDelayedThresholdMs: verificationDelayedThresholdMs,
          ),
        )
        .toList(growable: false);
  }

  Future<List<RunSubmissionStatus>> processReadySubmissions({
    required String userId,
    required String sessionId,
  }) async {
    final nowMs = _clock();
    final pendingEntries = await _spoolStore.loadAll();
    final statuses = <RunSubmissionStatus>[];
    for (final pending in pendingEntries) {
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
      pending = pending.copyWith(
        step: PendingRunSubmissionStep.requestingUploadGrant,
        updatedAtMs: _clock(),
        nextAttemptAtMs: 0,
        lastErrorCode: null,
        lastErrorMessage: null,
      );
      await _spoolStore.upsert(submission: pending);

      final uploadGrant = await _runSessionApi.createUploadGrant(
        userId: userId,
        sessionId: sessionId,
        runSessionId: runSessionId,
      );

      pending = pending.copyWith(
        step: PendingRunSubmissionStep.uploading,
        updatedAtMs: _clock(),
        objectPath: uploadGrant.objectPath,
      );
      await _spoolStore.upsert(submission: pending);

      await _replayUploader.uploadReplay(
        uploadGrant: uploadGrant,
        replayFilePath: pending.replayFilePath,
        contentLengthBytes: pending.contentLengthBytes,
        contentType: pending.contentType,
      );

      pending = pending.copyWith(
        step: PendingRunSubmissionStep.finalizing,
        updatedAtMs: _clock(),
        uploadCompletedAtMs: _clock(),
      );
      await _spoolStore.upsert(submission: pending);

      final submissionStatus = await _runSessionApi.finalizeUpload(
        userId: userId,
        sessionId: sessionId,
        runSessionId: runSessionId,
        canonicalSha256: pending.canonicalSha256,
        contentLengthBytes: pending.contentLengthBytes,
        contentType: pending.contentType,
        objectPath: uploadGrant.objectPath,
        provisionalSummary: pending.provisionalSummary,
      );

      if (submissionStatus.isTerminal) {
        await _spoolStore.remove(runSessionId: runSessionId);
        return RunSubmissionStatus.fromServerStatus(
          submissionStatus,
          nowMs: _clock(),
          verificationDelayedThresholdMs: verificationDelayedThresholdMs,
        );
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
      await _spoolStore.upsert(submission: pending);
      return RunSubmissionStatus.fromServerStatus(
        submissionStatus,
        pendingSubmission: pending,
        nowMs: _clock(),
        verificationDelayedThresholdMs: verificationDelayedThresholdMs,
      );
    } catch (error) {
      final failedAtMs = _clock();
      if (!_isRetryableError(error)) {
        await _spoolStore.remove(runSessionId: runSessionId);
        return RunSubmissionStatus(
          runSessionId: runSessionId,
          phase: RunSubmissionPhase.internalError,
          updatedAtMs: failedAtMs,
          message: _errorMessage(error),
        );
      }
      final nextAttempt = pending.attemptCount + 1;
      final retryAtMs =
          failedAtMs + retryDelayForAttempt(nextAttempt).inMilliseconds;
      final failedPending = pending.copyWith(
        step: PendingRunSubmissionStep.retryScheduled,
        updatedAtMs: failedAtMs,
        attemptCount: nextAttempt,
        nextAttemptAtMs: retryAtMs,
        lastErrorCode: _errorCode(error),
        lastErrorMessage: _errorMessage(error),
      );
      await _spoolStore.upsert(submission: failedPending);
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
      if (statusCode == HttpStatus.requestTimeout ||
          statusCode == HttpStatus.tooManyRequests) {
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
    final nowMs = _clock();
    final status = await _runSessionApi.loadSubmissionStatus(
      userId: userId,
      sessionId: sessionId,
      runSessionId: runSessionId,
    );
    if (status.isTerminal) {
      await _spoolStore.remove(runSessionId: runSessionId);
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
    await _spoolStore.upsert(submission: refreshedPending);
    return RunSubmissionStatus.fromServerStatus(
      status,
      pendingSubmission: refreshedPending,
      nowMs: nowMs,
      verificationDelayedThresholdMs: verificationDelayedThresholdMs,
    );
  }
}

int _defaultClock() => DateTime.now().millisecondsSinceEpoch;

bool _bodyContainsAccessDenied(String body) {
  final normalized = body.toLowerCase();
  return normalized.contains('accessdenied') ||
      normalized.contains('access denied');
}

String _buildUploadRejectedMessage({
  required int statusCode,
  required String responseBody,
}) {
  final normalizedBody = _singleLineText(responseBody);
  if (statusCode == HttpStatus.forbidden) {
    final lower = normalizedBody.toLowerCase();
    if (lower.contains('storage.objects.create')) {
      return 'Replay upload denied (HTTP 403): replay upload service account '
          'is missing storage.objects.create permission.';
    }
    if (lower.contains('accessdenied') || lower.contains('access denied')) {
      return 'Replay upload denied (HTTP 403): storage access denied.';
    }
  }
  if (normalizedBody.isEmpty) {
    return 'Replay upload rejected with HTTP $statusCode.';
  }
  return 'Replay upload rejected with HTTP $statusCode: '
      '${_trimForUi(normalizedBody, maxChars: 280)}';
}

String _singleLineText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _trimForUi(String value, {required int maxChars}) {
  if (value.length <= maxChars) {
    return value;
  }
  return '${value.substring(0, maxChars - 3)}...';
}
