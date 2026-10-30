import 'dart:convert';

/// Local diagnostic output only. A process clock must never be subtracted from
/// another process/device clock; UTC timestamps are correlation hints.
final class RunRewardDiagnostics {
  RunRewardDiagnostics({required this.enabled, void Function(String)? sink})
    : _sink = sink ?? print,
      clockId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  static RunRewardDiagnostics instance = RunRewardDiagnostics(
    enabled: const bool.fromEnvironment(
      'RUN_REWARD_TRACE',
      defaultValue: String.fromEnvironment('FLUTTER_APP_FLAVOR') == 'dev',
    ),
  );

  final bool enabled;
  final void Function(String) _sink;
  final String clockId;
  final Stopwatch _clock = Stopwatch()..start();
  int _sequence = 0;
  final Map<String, _Presentation> _presentations = {};

  void emit(
    String runSessionId,
    String stage, [
    Map<String, Object?> fields = const {},
  ]) {
    if (!enabled) return;
    try {
      _sink(
        jsonEncode({
          'event': 'run_reward_timing',
          'schemaVersion': 1,
          'component': 'client',
          'runSessionId': runSessionId,
          'clockId': clockId,
          'sequence': ++_sequence,
          'utcMs': DateTime.now().millisecondsSinceEpoch,
          'monoUs': _clock.elapsedMicroseconds,
          'stage': stage,
          ...fields,
        }),
      );
    } catch (_) {
      // Diagnostics must never change saving, retries or reward completion.
    }
  }

  Future<T> measure<T>(
    String id,
    String stage,
    Future<T> Function() action, {
    Map<String, Object?> fields = const {},
  }) async {
    if (!enabled) return action();
    final span = ++_sequence;
    final watch = Stopwatch()..start();
    emit(id, stage, {...fields, 'span': span, 'outcome': 'started'});
    var outcome = 'failed';
    try {
      final result = await action();
      outcome = 'completed';
      return result;
    } finally {
      emit(id, stage, {
        ...fields,
        'span': span,
        'outcome': outcome,
        'durationUs': watch.elapsedMicroseconds,
      });
    }
  }

  void canonical(
    String id, {
    required int revision,
    required int gold,
    required int xp,
  }) {
    if (!enabled) return;
    // Bound diagnostic memory even if a player never returns to the hub.
    if (_presentations.length >= 64 && !_presentations.containsKey(id)) {
      _presentations.remove(_presentations.keys.first);
    }
    _presentations.putIfAbsent(id, () => _Presentation(revision, gold, xp));
    emit(id, 'canonical_applied', {'revision': revision});
  }

  void clear() => _presentations.clear();

  /// Called after a foreground, current-route paint. This is framework-frame
  /// evidence, not a GPU presentation timestamp or proof the player saw it.
  void painted({
    required int revision,
    required String metric,
    required int value,
    required int target,
    required String surface,
  }) {
    if (!enabled) return;
    for (final entry in _presentations.entries.toList()) {
      final pending = entry.value;
      if (pending.revision != revision ||
          target != (metric == 'gold' ? pending.gold : pending.xp)) {
        continue;
      }
      void mark(String stage) {
        if (pending.seen.add(stage)) {
          emit(entry.key, stage, {'revision': revision, 'surface': surface});
        }
      }

      mark('${metric}_frame');
      if (value == target) mark('${metric}_target_frame');
      if (pending.seen.contains('gold_target_frame') &&
          pending.seen.contains('xp_target_frame')) {
        _presentations.remove(entry.key);
      }
    }
  }
}

final class _Presentation {
  _Presentation(this.revision, this.gold, this.xp);
  final int revision;
  final int gold;
  final int xp;
  final Set<String> seen = {};
}
