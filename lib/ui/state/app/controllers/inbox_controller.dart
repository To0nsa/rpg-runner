part of 'package:rpg_runner/ui/state/app/app_state.dart';

final class _AppStateInboxController extends _AppStateController {
  _AppStateInboxController(super._app);
  InboxSummary summary = const InboxSummary();
  List<InboxMessage> messages = const [];
  InboxCursor? _cursor;
  bool loading = false;
  String? loadError;
  final Set<String> busyMessages = {};
  int _generation = 0;
  Timer? _timer;
  Future<void>? _summaryInFlight;

  bool get available =>
      _app._inboxApi != null &&
      !_app.isDeveloperMode &&
      !_app._accountDeletionAccepted;
  bool get hasMore => _cursor != null;
  bool _current(String uid, int generation) =>
      !_app._disposed &&
      !_app._accountDeletionAccepted &&
      generation == _generation &&
      uid == _authSession.userId;

  void _applySummary(InboxSummary value) {
    if (value.revision >= summary.revision) summary = value;
  }

  void _replace(InboxMessage message) {
    messages = List.unmodifiable(
      messages.map((old) => old.id == message.id ? message : old),
    );
  }

  void resetAccount() {
    _generation += 1;
    _timer?.cancel();
    _timer = null;
    _summaryInFlight = null;
    summary = const InboxSummary();
    messages = const [];
    _cursor = null;
    busyMessages.clear();
    loading = false;
    loadError = null;
  }

  void updateForeground() {
    _timer?.cancel();
    _timer = null;
    if (!available ||
        !_bootstrapped ||
        !_app._runSubmissionController._foreground ||
        _app._disposed) {
      return;
    }
    unawaited(refreshSummary());
    // System mail needs modest foreground freshness; live chat will own its transport.
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(refreshSummary()),
    );
  }

  Future<void> refreshSummary() async {
    if (!available || !_bootstrapped || _app._disposed) return;
    final active = _summaryInFlight;
    if (active != null) {
      await active;
      // A settlement may have completed during the earlier read.
      if (!available || _app._disposed) return;
    }
    final pending = _refreshSummary();
    _summaryInFlight = pending;
    try {
      await pending;
    } finally {
      if (identical(_summaryInFlight, pending)) _summaryInFlight = null;
    }
  }

  Future<void> _refreshSummary() async {
    try {
      final session = await _ensureAuthSession();
      final generation = _generation;
      final value = await _app._inboxApi!.loadSummary(userId: session.userId);
      if (!_current(session.userId, generation)) return;
      _applySummary(value);
      _notifyListeners();
    } catch (_) {
      // Retain known attention during an outage; the inbox exposes an explicit retry.
    }
  }

  Future<void> load({bool more = false}) async {
    if (!available || loading || (more && _cursor == null)) return;
    loading = true;
    loadError = null;
    _notifyListeners();
    var generation = _generation;
    try {
      final session = await _ensureAuthSession();
      generation = _generation;
      final page = await _app._inboxApi!.loadPage(
        userId: session.userId,
        cursor: more ? _cursor : null,
      );
      if (!_current(session.userId, generation)) return;
      // A read or claim may have finished after this page's snapshot was taken.
      final oldById = {for (final message in messages) message.id: message};
      final incoming = page.messages.map((message) {
        final old = oldById[message.id];
        if (old != null &&
            ((old.readAtMs != null && message.readAtMs == null) ||
                (old.claimedAtMs != null && message.claimedAtMs == null))) {
          return old;
        }
        return message;
      });
      final merged = <String, InboxMessage>{if (more) ...oldById};
      for (final message in incoming) {
        merged[message.id] = message;
      }
      messages = List.unmodifiable(merged.values);
      _cursor = page.nextCursor;
      _applySummary(page.summary);
    } catch (_) {
      if (generation == _generation) {
        loadError = 'Unable to load messages. Please try again.';
      }
    } finally {
      if (generation == _generation && !_app._disposed) {
        loading = false;
        _notifyListeners();
      }
    }
  }

  Future<void> markRead(String messageId) async {
    if (!available || !busyMessages.add(messageId)) return;
    final generation = _generation;
    _notifyListeners();
    try {
      final session = await _ensureAuthSession();
      if (!_current(session.userId, generation)) return;
      final update = await _app._inboxApi!.markRead(
        userId: session.userId,
        messageId: messageId,
      );
      if (!_current(session.userId, generation)) return;
      _replace(update.message);
      _applySummary(update.summary);
    } finally {
      if (generation == _generation) {
        busyMessages.remove(messageId);
        _notifyListeners();
      }
    }
  }

  Future<void> claim(String messageId) async {
    if (!available || !busyMessages.add(messageId)) return;
    final generation = _generation;
    _notifyListeners();
    try {
      final session = await _ensureAuthSession();
      if (!_current(session.userId, generation)) return;
      await _app.flushOwnershipEdits(
        trigger: OwnershipFlushTrigger.connectivityRestored,
      );
      if (!_current(session.userId, generation)) return;
      for (var attempt = 0; attempt < 2; attempt += 1) {
        final result = await _app._inboxApi!.claim(
          userId: session.userId,
          messageId: messageId,
          commandId: _newCommandId(),
          expectedRevision: _ownershipRevision,
        );
        if (!_current(session.userId, generation)) return;
        if (result.ownership.canonicalState.revision >= _ownershipRevision) {
          _applyCanonicalState(result.ownership.canonicalState);
          await _reconcileSelectionProjectionFromOutbox(
            ownerUserId: session.userId,
          );
        }
        if (!_current(session.userId, generation)) return;
        _replace(result.message);
        _applySummary(result.summary);
        if (result.ownership.accepted) return;
        if (result.ownership.rejectedReason !=
            OwnershipRejectedReason.staleRevision) {
          break;
        }
      }
      throw StateError('Unable to claim reward. Please try again.');
    } finally {
      if (generation == _generation) {
        busyMessages.remove(messageId);
        _notifyListeners();
      }
    }
  }
}
