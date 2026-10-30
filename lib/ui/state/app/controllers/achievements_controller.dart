part of 'package:rpg_runner/ui/state/app/app_state.dart';

/// Reuses canonical ownership and its revision protocol for manual milestone
/// claims. Account generations fence late network replies and duplicate taps.
final class _AppStateAchievementsController extends _AppStateController {
  _AppStateAchievementsController(super._app);
  int _generation = 0;
  bool claiming = false;
  Future<void>? _refreshInFlight;
  bool get available => !_app.isDeveloperMode && !_app._accountDeletionAccepted;

  void resetAccount() {
    _generation += 1;
    claiming = false;
    _refreshInFlight = null;
  }

  bool _current(String uid, int generation) =>
      !_app._disposed &&
      available &&
      generation == _generation &&
      _authSession.userId == uid;

  Future<void> refresh() async {
    if (!available || _app._disposed) return;
    final active = _refreshInFlight;
    if (active != null) return active;
    final pending = _refresh();
    _refreshInFlight = pending;
    try {
      await pending;
    } finally {
      if (identical(pending, _refreshInFlight)) _refreshInFlight = null;
    }
  }

  Future<void> _refresh() async {
    final generation = _generation;
    final session = await _ensureAuthSession();
    if (!_current(session.userId, generation)) return;
    await _app.flushOwnershipEdits(
      trigger: OwnershipFlushTrigger.connectivityRestored,
    );
    if (!_current(session.userId, generation)) return;
    final canonical = await _ownershipApi.loadCanonicalState(
      userId: session.userId,
      sessionId: session.sessionId,
    );
    if (!_current(session.userId, generation)) return;
    await _apply(canonical, session.userId);
    if (_current(session.userId, generation)) _notifyListeners();
  }

  Future<void> _apply(OwnershipCanonicalState canonical, String uid) async {
    if (canonical.revision < _ownershipRevision) return;
    _applyCanonicalState(canonical);
    await _reconcileSelectionProjectionFromOutbox(ownerUserId: uid);
  }

  Future<void> claim(String? achievementId) async {
    if (!available || claiming || _app._disposed) return;
    final generation = _generation;
    claiming = true;
    _notifyListeners();
    try {
      final session = await _ensureAuthSession();
      if (!_current(session.userId, generation)) return;
      await _app.flushOwnershipEdits(
        trigger: OwnershipFlushTrigger.connectivityRestored,
      );
      if (!_current(session.userId, generation)) return;
      for (var attempt = 0; attempt < 2; attempt += 1) {
        final result = await _ownershipApi.claimAchievements(
          ClaimAchievementsCommand(
            userId: session.userId,
            sessionId: session.sessionId,
            expectedRevision: _ownershipRevision,
            commandId: _newCommandId(),
            achievementId: achievementId,
          ),
        );
        if (!_current(session.userId, generation)) return;
        await _apply(result.canonicalState, session.userId);
        if (!_current(session.userId, generation)) return;
        if (result.accepted) return;
        if (result.rejectedReason != OwnershipRejectedReason.staleRevision) {
          break;
        }
      }
      throw StateError(
        'Unable to claim achievement rewards. Please try again.',
      );
    } finally {
      if (generation == _generation && !_app._disposed) {
        claiming = false;
        _notifyListeners();
      }
    }
  }
}
