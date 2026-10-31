part of 'package:rpg_runner/ui/state/app/app_state.dart';

final class _AppStateRunSubmissionController extends _AppStateController {
  _AppStateRunSubmissionController(super._app);
  late final _scheduler = RunSubmissionScheduler(process: _pump);
  final Map<String, Future<RunSubmissionStatus>> _inFlight = {};
  final Set<String> _acknowledged = {};
  int _generation = 0;
  bool _foreground = false;
  Future<void>? _discovery;

  bool _isCurrent(AuthSession session, int generation) =>
      generation == _generation &&
      !_app._disposed &&
      !_app._accountDeletionAccepted &&
      _authSession.userId == session.userId;

  void setForeground(bool foreground) {
    if (_app.isDeveloperMode ||
        _app._disposed ||
        _app._accountDeletionAccepted) {
      return;
    }
    if (_foreground == foreground) return;
    _foreground = foreground;
    _scheduler.setForeground(foreground);
    for (final id in _runSubmissionStatuses.keys) {
      if (!_acknowledged.contains(id)) {
        RunRewardDiagnostics.instance.emit(id, 'lifecycle', {
          'foreground': foreground,
        });
      }
    }
    // Bootstrap owns sign-in; lifecycle recovery must not retry a failed login.
    if (foreground && _bootstrapped) {
      unawaited(_resumePendingRunSubmissions());
    }
  }

  void resetAccount() {
    _generation += 1;
    _runSubmissionCoordinator.clearPreparedUploads();
    _scheduler.clear();
    _inFlight.clear();
    _acknowledged.clear();
    RunRewardDiagnostics.instance.clear();
    _app._latestVerifiedReward = null;
    _discovery = null;
  }

  void dispose() {
    _generation += 1;
    _runSubmissionCoordinator.clearPreparedUploads();
    _scheduler.dispose();
    RunRewardDiagnostics.instance.clear();
  }

  Future<int?> _pump(String id) async {
    final status = await refreshRunSubmissionStatus(runSessionId: id);
    if (status.isTerminal &&
        (!status.isRewardFinal || _acknowledged.contains(id))) {
      return null;
    }
    return status.nextRetryAtMs ?? 0;
  }

  Future<RunSubmissionStatus> submitRunReplay({
    required String runSessionId,
    required RunMode runMode,
    required String replayArtifactId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String contentType = 'application/octet-stream',
    Map<String, Object?>? provisionalSummary,
  }) async {
    await journalRunReplay(
      runSessionId: runSessionId,
      runMode: runMode,
      replayArtifactId: replayArtifactId,
      canonicalSha256: canonicalSha256,
      contentLengthBytes: contentLengthBytes,
      contentType: contentType,
      provisionalSummary: provisionalSummary,
    );
    return processJournaledRunReplay(runSessionId: runSessionId);
  }

  Future<RunSubmissionStatus> journalRunReplay({
    required String runSessionId,
    required RunMode runMode,
    required String replayArtifactId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String contentType = 'application/octet-stream',
    Map<String, Object?>? provisionalSummary,
  }) async {
    final session = await _ensureAuthSession();
    final generation = _generation;
    final pending = await _runSubmissionCoordinator.enqueueSubmission(
      userId: session.userId,
      runSessionId: runSessionId,
      runMode: runMode,
      replayArtifactId: replayArtifactId,
      canonicalSha256: canonicalSha256,
      contentLengthBytes: contentLengthBytes,
      contentType: contentType,
      provisionalSummary: provisionalSummary,
    );
    final status = RunSubmissionStatus.fromPending(pending);
    if (!_isCurrent(session, generation)) return status;
    _runSubmissionStatuses[runSessionId] = status;
    _scheduler.track(runSessionId);
    _notifyListeners();
    return _runSubmissionStatuses[runSessionId]!;
  }

  Future<RunSubmissionStatus> processJournaledRunReplay({
    required String runSessionId,
  }) => refreshRunSubmissionStatus(runSessionId: runSessionId);

  Future<RunSubmissionStatus> refreshRunSubmissionStatus({
    required String runSessionId,
  }) async {
    final active = _inFlight[runSessionId];
    if (active != null) return active;
    final pending = _refresh(runSessionId);
    _inFlight[runSessionId] = pending;
    try {
      return await pending;
    } finally {
      if (identical(_inFlight[runSessionId], pending)) {
        _inFlight.remove(runSessionId);
      }
    }
  }

  Future<RunSubmissionStatus> _refresh(String runSessionId) async {
    final session = await _ensureAuthSession();
    final generation = _generation;
    final known = _runSubmissionStatuses[runSessionId];
    if (known != null &&
        known.isTerminal &&
        (!known.isRewardFinal || _acknowledged.contains(runSessionId))) {
      return known;
    }
    _scheduler.track(runSessionId);
    RunRewardDiagnostics.instance.emit(runSessionId, 'submission_pump');
    final status = known?.isRewardFinal == true
        ? known!
        : await _runSubmissionCoordinator.refreshRunSessionStatus(
            userId: session.userId,
            sessionId: session.sessionId,
            runSessionId: runSessionId,
          );
    if (!_isCurrent(session, generation)) return status;
    _runSubmissionStatuses[runSessionId] = status;
    _notifyListeners();
    await _syncCanonicalAfterSubmissionStatuses(
      session: session,
      generation: generation,
      statuses: <RunSubmissionStatus>[status],
    );
    if (!_isCurrent(session, generation)) return status;
    if (status.isTerminal &&
        (!status.isRewardFinal || _acknowledged.contains(runSessionId))) {
      _scheduler.forget(runSessionId);
    }
    _notifyListeners();
    return status;
  }

  Future<List<RunSubmissionStatus>> processPendingRunSubmissions() async {
    final session = await _ensureAuthSession();
    final generation = _generation;
    final local = await _runSubmissionCoordinator.loadLocalStatuses(
      userId: session.userId,
    );
    final statuses = <RunSubmissionStatus>[];
    for (final status in local) {
      if (!_isCurrent(session, generation)) break;
      statuses.add(
        await refreshRunSubmissionStatus(runSessionId: status.runSessionId),
      );
    }
    return statuses;
  }

  @override
  Future<void> _resumePendingRunSubmissions() async {
    final active = _discovery;
    if (active != null) return active;
    final pending = _discover();
    _discovery = pending;
    try {
      await pending;
    } finally {
      if (identical(_discovery, pending)) _discovery = null;
    }
  }

  Future<void> _discover() async {
    try {
      final session = await _ensureAuthSession();
      final generation = _generation;
      final statuses = await _runSubmissionCoordinator.loadLocalStatuses(
        userId: session.userId,
      );
      if (!_isCurrent(session, generation)) return;
      for (final status in statuses) {
        RunRewardDiagnostics.instance.emit(
          status.runSessionId,
          'spool_recovered',
          {'phase': status.phase.name, 'retryAtMs': status.nextRetryAtMs},
        );
        _runSubmissionStatuses.putIfAbsent(status.runSessionId, () => status);
        _scheduler.track(
          status.runSessionId,
          notBeforeMs: status.nextRetryAtMs,
        );
      }
      _notifyListeners();
    } catch (error) {
      debugPrint('Pending replay submission resume failed: $error');
    }
  }

  Future<void> _syncCanonicalAfterSubmissionStatuses({
    required AuthSession session,
    required int generation,
    required Iterable<RunSubmissionStatus> statuses,
  }) async {
    final shouldRefreshCanonical = statuses.any(
      (status) => status.isRewardFinal,
    );
    if (!shouldRefreshCanonical) {
      return;
    }
    final finalIds = statuses
        .where((s) => s.isRewardFinal)
        .map((s) => s.runSessionId)
        .toList();
    try {
      final canonical = await RunRewardDiagnostics.instance.measure(
        finalIds.first,
        'canonical_fetch',
        () => _ownershipApi.loadCanonicalState(
          userId: session.userId,
          sessionId: session.sessionId,
        ),
      );
      if (!_isCurrent(session, generation)) return;
      if (canonical.revision >= _ownershipRevision) {
        _applyCanonicalState(canonical);
        await _reconcileSelectionProjectionFromOutbox(
          ownerUserId: session.userId,
        );
      }
      if (!_isCurrent(session, generation)) return;
      for (final id in finalIds) {
        RunRewardDiagnostics.instance.canonical(
          id,
          revision: _ownershipRevision,
          gold: _app._progression.gold,
          xp: _app._progression.playerProgress.totalXp,
        );
      }
      for (final status in statuses.where((status) => status.isRewardFinal)) {
        await _runSubmissionCoordinator.acknowledgeFinalReward(
          runSessionId: status.runSessionId,
        );
        if (!_isCurrent(session, generation)) return;
        if (_acknowledged.add(status.runSessionId)) {
          _app._latestVerifiedReward = status;
          RunRewardDiagnostics.instance.emit(
            status.runSessionId,
            'receipt_acknowledged',
          );
        }
      }
      unawaited(_app.refreshInboxSummary());
    } catch (error) {
      debugPrint(
        'Run submission canonical sync failed after final reward status: $error',
      );
    }
  }
}
