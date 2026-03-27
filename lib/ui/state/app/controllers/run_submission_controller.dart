part of 'package:rpg_runner/ui/state/app/app_state.dart';

final class _AppStateRunSubmissionController extends _AppStateController {
  _AppStateRunSubmissionController(super._app);
  Future<RunSubmissionStatus> submitRunReplay({
    required String runSessionId,
    required RunMode runMode,
    required String replayFilePath,
    required String canonicalSha256,
    required int contentLengthBytes,
    String contentType = 'application/octet-stream',
    Map<String, Object?>? provisionalSummary,
  }) async {
    final session = await _ensureAuthSession();
    final pending = await _runSubmissionCoordinator.enqueueSubmission(
      runSessionId: runSessionId,
      runMode: runMode,
      replayFilePath: replayFilePath,
      canonicalSha256: canonicalSha256,
      contentLengthBytes: contentLengthBytes,
      contentType: contentType,
      provisionalSummary: provisionalSummary,
    );
    _runSubmissionStatuses[runSessionId] = RunSubmissionStatus.fromPending(
      pending,
    );
    _notifyListeners();
    final status = await _runSubmissionCoordinator.processRunSession(
      userId: session.userId,
      sessionId: session.sessionId,
      runSessionId: runSessionId,
    );
    _runSubmissionStatuses[runSessionId] = status;
    await _syncCanonicalAfterSubmissionStatuses(
      session: session,
      statuses: <RunSubmissionStatus>[status],
    );
    _notifyListeners();
    return status;
  }

  Future<RunSubmissionStatus> refreshRunSubmissionStatus({
    required String runSessionId,
  }) async {
    final session = await _ensureAuthSession();
    final status = await _runSubmissionCoordinator.refreshRunSessionStatus(
      userId: session.userId,
      sessionId: session.sessionId,
      runSessionId: runSessionId,
    );
    _runSubmissionStatuses[runSessionId] = status;
    await _syncCanonicalAfterSubmissionStatuses(
      session: session,
      statuses: <RunSubmissionStatus>[status],
    );
    _notifyListeners();
    return status;
  }

  Future<List<RunSubmissionStatus>> processPendingRunSubmissions() async {
    final session = await _ensureAuthSession();
    final statuses = await _runSubmissionCoordinator.processReadySubmissions(
      userId: session.userId,
      sessionId: session.sessionId,
    );
    if (statuses.isEmpty) {
      return const <RunSubmissionStatus>[];
    }
    for (final status in statuses) {
      _runSubmissionStatuses[status.runSessionId] = status;
    }
    await _syncCanonicalAfterSubmissionStatuses(
      session: session,
      statuses: statuses,
    );
    _notifyListeners();
    return statuses;
  }

  @override
  Future<void> _resumePendingRunSubmissions() async {
    try {
      await processPendingRunSubmissions();
    } catch (error) {
      debugPrint('Pending replay submission resume failed: $error');
    }
  }

  Future<void> _syncCanonicalAfterSubmissionStatuses({
    required AuthSession session,
    required Iterable<RunSubmissionStatus> statuses,
  }) async {
    final shouldRefreshCanonical = statuses.any(
      (status) => status.isRewardFinal,
    );
    if (!shouldRefreshCanonical) {
      return;
    }
    try {
      final canonical = await _ownershipApi.loadCanonicalState(
        userId: session.userId,
        sessionId: session.sessionId,
      );
      _applyCanonicalState(canonical);
    } catch (error) {
      debugPrint(
        'Run submission canonical sync failed after final reward status: $error',
      );
    }
  }
}
