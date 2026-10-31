part of 'package:rpg_runner/ui/state/app/app_state.dart';

final class _AppStateRunSubmissionController extends _AppStateController {
  _AppStateRunSubmissionController(super._app);
  late final _scheduler = RunSubmissionScheduler(process: _pump);
  final Map<String, Future<RunSubmissionStatus>> _inFlight = {};
  final Set<String> _acknowledged = {};
  int _generation = 0;
  bool _foreground = false;
  Future<void>? _discovery;
  final Map<String, StreamSubscription<RunSubmissionResponse>>
  _completionWatches = {};
  final Map<String, RunSubmissionResponse> _completions = {};
  int _watchEpoch = 0;
  final Map<String, PendingRunSubmission> _rewardPreviews = {};

  Iterable<PendingRunSubmission> get _visibleRewardPreviews sync* {
    final applied = _app._progression.appliedRewardGrantIds;
    for (final pending in _rewardPreviews.values) {
      if (_acknowledged.contains(pending.runSessionId) ||
          (applied?.contains(pending.runSessionId) ?? false)) {
        continue;
      }
      // A missing ID in a truncated/legacy history is ambiguous. Keep its
      // durable journal for recovery, but never add it to a possibly-paid total.
      if (pending.presentationBaseRevision == _ownershipRevision ||
          (applied != null &&
              (applied.length < ProgressionState.rewardGrantHistoryLimit ||
                  applied.contains(pending.presentationBaseGrantId)))) {
        yield pending;
      }
    }
  }

  int _summaryCount(PendingRunSubmission pending, String key) {
    final value = pending.provisionalSummary?[key];
    return value is int && value >= 0 && value <= 9007199254740991 ? value : 0;
  }

  int get previewGold => _visibleRewardPreviews.fold(
    0,
    (total, pending) => total + _summaryCount(pending, 'goldEarned'),
  );

  int get previewXp => _visibleRewardPreviews.fold(
    0,
    (total, pending) =>
        total + PlayerProgress.xpForScore(_summaryCount(pending, 'score')),
  );

  bool get hasRewardPreview => previewGold > 0 || previewXp > 0;

  void _rememberRewardPreview(PendingRunSubmission? pending) {
    if (pending == null || _acknowledged.contains(pending.runSessionId)) return;
    _rewardPreviews.putIfAbsent(pending.runSessionId, () => pending);
    reconcileRewardPreviews();
  }

  void reconcileRewardPreviews() {
    final applied = _app._progression.appliedRewardGrantIds;
    if (applied == null) return;
    _rewardPreviews.removeWhere((id, _) => applied.contains(id));
  }

  void _stopCompletionWatches() {
    _watchEpoch += 1;
    for (final subscription in _completionWatches.values) {
      unawaited(subscription.cancel());
    }
    _completionWatches.clear();
  }

  void _watchCompletion(String id, AuthSession session, int generation) {
    final source = _app._runCompletionSource;
    if (source == null ||
        !_foreground ||
        _acknowledged.contains(id) ||
        _completionWatches.containsKey(id) ||
        _completionWatches.length >= 8) {
      return;
    }
    final epoch = _watchEpoch;
    _completionWatches[id] = source
        .watch(userId: session.userId, runSessionId: id)
        .listen(
          (completion) {
            if (!_foreground ||
                epoch != _watchEpoch ||
                !_isCurrent(session, generation) ||
                _acknowledged.contains(id) ||
                completion.status.runSessionId != id ||
                completion.canonical == null ||
                !completion.status.isTerminal) {
              return;
            }
            _completions[id] = completion;
            RunRewardDiagnostics.instance.emit(id, 'completion_received', {
              'revision': completion.canonical!.revision,
            });
            unawaited(_receiveCompletion(id, session, generation, epoch));
          },
          onError: (Object error) {
            if (epoch != _watchEpoch || !_isCurrent(session, generation)) {
              return;
            }
            final subscription = _completionWatches.remove(id);
            if (subscription != null) unawaited(subscription.cancel());
            RunRewardDiagnostics.instance.emit(id, 'completion_watch_failed');
            // The durable queue already owns bounded polling and reconnect recovery.
          },
        );
  }

  Future<void> _receiveCompletion(
    String id,
    AuthSession session,
    int generation,
    int epoch,
  ) async {
    try {
      // Serialize with an upload/status response that may still be arriving.
      final active = _inFlight[id];
      if (active != null) {
        try {
          await active;
        } catch (_) {
          /* Receipt can recover the failed call. */
        }
      }
      if (!_foreground ||
          epoch != _watchEpoch ||
          !_isCurrent(session, generation) ||
          _acknowledged.contains(id)) {
        return;
      }
      await refreshRunSubmissionStatus(runSessionId: id);
    } catch (error) {
      debugPrint('Run completion application deferred: $error');
    }
  }

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
    if (!foreground) _stopCompletionWatches();
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
    _stopCompletionWatches();
    _completions.clear();
    _app._onlineRunSubmissionCoordinator?.clearPreparedUploads();
    _scheduler.clear();
    _inFlight.clear();
    _acknowledged.clear();
    _rewardPreviews.clear();
    RunRewardDiagnostics.instance.clear();
    _app._latestVerifiedReward = null;
    _app._latestRewardCorrection = null;
    _discovery = null;
  }

  void dispose() {
    _generation += 1;
    _stopCompletionWatches();
    _completions.clear();
    _app._onlineRunSubmissionCoordinator?.clearPreparedUploads();
    _scheduler.dispose();
    RunRewardDiagnostics.instance.clear();
  }

  Future<int?> _pump(String id) async {
    final status = await refreshRunSubmissionStatus(runSessionId: id);
    if (status.isTerminal &&
        (!status.isRewardFinal || _acknowledged.contains(id))) {
      return null;
    }
    final next = status.nextRetryAtMs ?? 0;
    if (_completionWatches.containsKey(id) &&
        !status.isTerminal &&
        status.serverStatus != null) {
      final fallbackAt = DateTime.now().millisecondsSinceEpoch + 10000;
      return next > fallbackAt ? next : fallbackAt;
    }
    return next;
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
    final grants = _app._progression.appliedRewardGrantIds;
    final pending = await _runSubmissionCoordinator.enqueueSubmission(
      userId: session.userId,
      runSessionId: runSessionId,
      runMode: runMode,
      replayArtifactId: replayArtifactId,
      canonicalSha256: canonicalSha256,
      contentLengthBytes: contentLengthBytes,
      contentType: contentType,
      provisionalSummary: provisionalSummary,
      presentationBaseRevision: _ownershipRevision,
      presentationBaseGrantId: grants == null || grants.isEmpty
          ? null
          : grants.last,
    );
    final status = RunSubmissionStatus.fromPending(pending);
    if (!_isCurrent(session, generation)) return status;
    _runSubmissionStatuses[runSessionId] = status;
    _rememberRewardPreview(pending);
    RunRewardDiagnostics.instance.emit(runSessionId, 'local_reward_preview');
    _scheduler.track(runSessionId);
    _watchCompletion(runSessionId, session, generation);
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
    _watchCompletion(runSessionId, session, generation);
    final completion = _completions[runSessionId];
    var status = completion != null
        ? RunSubmissionStatus.fromServerStatus(
            completion.status,
            canonical: completion.canonical,
          )
        : known?.isRewardFinal == true
        ? known!
        : await _runSubmissionCoordinator.refreshRunSessionStatus(
            userId: session.userId,
            sessionId: session.sessionId,
            runSessionId: runSessionId,
          );
    if (!_isCurrent(session, generation)) return status;
    final arrived = _completions[runSessionId];
    if (arrived != null) {
      status = RunSubmissionStatus.fromServerStatus(
        arrived.status,
        canonical: arrived.canonical,
      );
    }
    _runSubmissionStatuses[runSessionId] = status;
    _rememberRewardPreview(status.pendingSubmission);
    if (status.isTerminal && !status.isRewardFinal) {
      final removed = _rewardPreviews.remove(runSessionId);
      if (removed != null &&
          (_summaryCount(removed, 'goldEarned') > 0 ||
              PlayerProgress.xpForScore(_summaryCount(removed, 'score')) > 0)) {
        _app._latestRewardCorrection = status;
      }
    }
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
      final watch = _completionWatches.remove(runSessionId);
      if (watch != null) unawaited(watch.cancel());
      _completions.remove(runSessionId);
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
    if (_isCurrent(session, generation)) {
      for (final status in local) {
        _rememberRewardPreview(status.pendingSubmission);
      }
      _notifyListeners();
    }
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
        _rememberRewardPreview(status.pendingSubmission);
        _scheduler.track(
          status.runSessionId,
          notBeforeMs: status.nextRetryAtMs,
        );
        _watchCompletion(status.runSessionId, session, generation);
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
      final receipts = statuses.where((s) => s.isRewardFinal).toList();
      OwnershipCanonicalState? confirmed;
      if (receipts.every((s) => s.canonical != null)) {
        for (final receipt in receipts) {
          if (confirmed == null ||
              receipt.canonical!.revision > confirmed.revision) {
            confirmed = receipt.canonical;
          }
        }
      }
      final canonical =
          confirmed ??
          await RunRewardDiagnostics.instance.measure<OwnershipCanonicalState>(
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
        for (final id in finalIds) {
          _rewardPreviews.remove(id);
        }
        await _reconcileSelectionProjectionFromOutbox(
          ownerUserId: session.userId,
        );
      }
      if (!_isCurrent(session, generation)) return;
      // A newer canonical revision already includes an older final receipt.
      for (final id in finalIds) {
        _rewardPreviews.remove(id);
      }
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
          // Retain the small historical status, not one account snapshot per run.
          _runSubmissionStatuses[status.runSessionId] =
              RunSubmissionStatus.fromServerStatus(status.serverStatus!);
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
