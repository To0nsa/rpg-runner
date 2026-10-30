import 'dart:convert';
import 'dart:io';

/// Diagnostic clocks never participate in replay authority or deadline checks.
final class RewardTiming {
  RewardTiming({void Function(String)? sink}) : _sink = sink ?? print;
  static final instance = RewardTiming();
  final void Function(String) _sink;
  final _clock = Stopwatch()..start();
  final _clockId = '$pid-${DateTime.now().microsecondsSinceEpoch}';
  int _sequence = 0;

  void emit(String id, String stage, Map<String, Object?> fields) {
    try {
      _sink(
        jsonEncode({
          'event': 'run_reward_timing',
          'schemaVersion': 1,
          'component': 'validator',
          'runSessionId': id,
          'clockId': _clockId,
          'sequence': ++_sequence,
          'utcMs': DateTime.now().millisecondsSinceEpoch,
          'monoUs': _clock.elapsedMicroseconds,
          'stage': stage,
          ...fields,
        }),
      );
    } catch (_) {
      // Logging failure must not change acceptance or cause another payout.
    }
  }

  Future<T> measure<T>(
    String id,
    String stage,
    Future<T> Function() action, {
    int? attempt,
  }) async {
    final span = ++_sequence;
    final watch = Stopwatch()..start();
    emit(id, stage, {'span': span, 'attempt': ?attempt, 'outcome': 'started'});
    var outcome = 'failed';
    try {
      final result = await action();
      outcome = 'completed';
      return result;
    } finally {
      emit(id, stage, {
        'span': span,
        'attempt': ?attempt,
        'outcome': outcome,
        'durationUs': watch.elapsedMicroseconds,
      });
    }
  }

  T measureSync<T>(
    String id,
    String stage,
    T Function() action, {
    int? attempt,
  }) {
    final span = ++_sequence;
    final watch = Stopwatch()..start();
    emit(id, stage, {'span': span, 'attempt': ?attempt, 'outcome': 'started'});
    var outcome = 'failed';
    try {
      final result = action();
      outcome = 'completed';
      return result;
    } finally {
      emit(id, stage, {
        'span': span,
        'attempt': ?attempt,
        'outcome': outcome,
        'durationUs': watch.elapsedMicroseconds,
      });
    }
  }
}
