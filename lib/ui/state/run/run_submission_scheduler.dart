import 'dart:async';

/// One foreground queue for an authenticated player's durable submissions.
///
/// [process] returns null when local work is complete, or the next eligible
/// retry time in milliseconds since epoch. Errors back off without losing work.
/// Calls never overlap and are separated by at least one second across all runs.
/// Hosts must suspend the queue while inactive and clear it on account changes.
final class RunSubmissionScheduler {
  RunSubmissionScheduler({
    required Future<int?> Function(String runSessionId) process,
    int Function()? clock,
  }) : _process = process,
       _clock = clock ?? _now;

  final Future<int?> Function(String) _process;
  final int Function() _clock;
  final Map<String, _SubmissionSchedule> _pending = {};
  Timer? _timer;
  bool _foreground = false;
  bool _busy = false;
  bool _disposed = false;
  int _generation = 0;
  int _nextSequence = 0;
  int _nextRequestAt = 0;
  int _nextDelayedRequestAt = 0;

  void setForeground(bool value) {
    if (_disposed || _foreground == value) return;
    _foreground = value;
    _schedule();
  }

  /// Adds durable work once; repeated discovery preserves its backoff.
  void track(String id, {int? notBeforeMs}) {
    if (_disposed) return;
    _pending.putIfAbsent(
      id,
      () => _SubmissionSchedule(notBeforeMs ?? _clock(), _nextSequence++),
    );
    _schedule();
  }

  void forget(String id) {
    _pending.remove(id);
    _schedule();
  }

  /// Invalidates results from the old account without overlapping its request.
  void clear() {
    _generation += 1;
    _pending.clear();
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    clear();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || !_foreground || _busy || _pending.isEmpty) return;
    final earliest = _pending.values
        .map(_eligibleAt)
        .reduce((a, b) => a < b ? a : b);
    final due = earliest > _nextRequestAt ? earliest : _nextRequestAt;
    _timer = Timer(
      Duration(milliseconds: (due - _clock()).clamp(0, 2147483647)),
      () => unawaited(_pump()),
    );
  }

  Future<void> _pump() async {
    if (_disposed || !_foreground || _busy || _pending.isEmpty) return;
    final now = _clock();
    final entries =
        _pending.entries
            .where((entry) => _eligibleAt(entry.value) <= now)
            .toList()
          ..sort((a, b) => b.value.sequence.compareTo(a.value.sequence));
    if (entries.isEmpty) {
      _schedule();
      return;
    }
    final selected = entries.first;
    final generation = _generation;
    _busy = true;
    if (selected.value.attempts >= 60) {
      // A large old backlog shares one read/minute; recent runs retain the
      // fast lane without exhausting the server's 5,000/day user allowance.
      _nextDelayedRequestAt = _clock() + 60000;
    }
    try {
      final nextAttempt = await _process(selected.key);
      if (generation != _generation ||
          !identical(_pending[selected.key], selected.value)) {
        return;
      }
      if (nextAttempt == null) {
        _pending.remove(selected.key);
      } else {
        _defer(selected.value, notBefore: nextAttempt);
      }
    } catch (_) {
      if (generation == _generation &&
          identical(_pending[selected.key], selected.value)) {
        _defer(selected.value, notBefore: _clock() + 10000);
      }
    } finally {
      _busy = false;
      _nextRequestAt = _clock() + 1000;
      _schedule();
    }
  }

  int _eligibleAt(_SubmissionSchedule entry) =>
      entry.attempts >= 60 && _nextDelayedRequestAt > entry.dueAt
      ? _nextDelayedRequestAt
      : entry.dueAt;

  void _defer(_SubmissionSchedule entry, {required int notBefore}) {
    entry.attempts += 1;
    // A delayed run eventually costs at most one status read per minute;
    // the global gap also caps a backlog below the 120/minute user quota.
    final delay = switch (entry.attempts) {
      <= 10 => 1000,
      <= 35 => 2000,
      <= 59 => 10000,
      _ => 60000,
    };
    final due = _clock() + delay;
    entry.dueAt = due > notBefore ? due : notBefore;
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;
}

final class _SubmissionSchedule {
  _SubmissionSchedule(this.dueAt, this.sequence);
  int dueAt;
  final int sequence;
  int attempts = 0;
}
