import 'package:flutter/foundation.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';
import 'package:runner_core/tuning/score_tuning.dart';

import '../../game/replay/run_recorder.dart';
import '../app/ui_routes.dart';
import '../state/ownership/selection_state.dart';
import '../state/run/run_submission_status.dart';
import 'run_reward_diagnostics.dart';

/// The existing AppState journal boundary; no account or transport ownership.
typedef RunReplayJournalWriter = Future<RunSubmissionStatus> Function({
  required String runSessionId,
  required RunMode runMode,
  required String replayArtifactId,
  required String canonicalSha256,
  required int contentLengthBytes,
  Map<String, Object?>? provisionalSummary,
});

/// Finalizes one attempt under immutable identity, even after its view leaves.
///
/// Concurrent/duplicate completion joins one operation. Failed saving can be
/// explicitly retried; a successfully journaled replay is never journaled twice.
/// Disposal detaches presentation only. The session awaits [pending] before
/// closing the recorder, so restart cannot close files during finalization.
final class RunReplayFinalization extends ChangeNotifier {
  RunReplayFinalization({required this.descriptor, required this.scoreTuning});

  final RunStartDescriptor descriptor;
  final ScoreTuning scoreTuning;
  RunEndedEvent? _event;
  Map<String, Object?>? _summary;
  Future<void>? _pending;
  Future<void>? get pending => _pending;
  bool get inFlight => _pending != null;
  bool _journaled = false;
  String? _error;
  RunSubmissionStatus? _status;
  bool get journaled => _journaled;
  String? get error => _error;
  RunSubmissionStatus? get status => _status;
  int? get goldEarned => _event?.goldEarned;
  bool _disposed = false;
  bool _retired = false;

  /// Already-started durable work finishes; a retired UI cannot start more work.
  void retire() => _retired = true;

  Future<void> complete(
    RunEndedEvent event, {
    required RunRecorder? recorder,
    required RunReplayJournalWriter? journal,
  }) {
    if (_retired) return _pending ?? Future<void>.value();
    if (_event != null) return _pending ?? Future<void>.value();
    if (event.runId != descriptor.runId) {
      throw StateError('Run completion belongs to another attempt.');
    }
    _event = event;
    _summary = Map.unmodifiable({
      'runId': event.runId,
      'tick': event.tick,
      'distance': event.distance,
      'reason': event.reason.name,
      'goldEarned': event.goldEarned,
      'score': buildRunScoreBreakdown(
        tick: event.tick,
        distanceUnits: event.distance,
        collectibles: event.stats.collectibles,
        collectibleScore: event.stats.collectibleScore,
        enemyKillCounts: event.stats.enemyKillCounts,
        rescuedNpcs: event.stats.rescuedNpcs,
        rescuePoints: event.stats.rescuePoints,
        excludedScoreTicks: event.stats.excludedScoreTicks,
        tuning: scoreTuning,
        tickHz: descriptor.tickHz,
      ).totalPoints,
      'collectibles': event.stats.collectibles,
      'collectibleScore': event.stats.collectibleScore,
      'enemyKillCounts': event.stats.enemyKillCounts,
      'rescuedNpcs': event.stats.rescuedNpcs,
      'rescuePoints': event.stats.rescuePoints,
    });
    return retry(recorder: recorder, journal: journal);
  }

  Future<void> retry({
    required RunRecorder? recorder,
    required RunReplayJournalWriter? journal,
  }) {
    if (_pending case final operation?) return operation;
    if (_retired) return Future<void>.value();
    if (_event == null || journaled || descriptor.isDeveloperPractice) {
      _publish();
      return Future<void>.value();
    }
    _error = null;
    // Schedule after assignment so synchronous failures cannot leave a completed
    // future in the in-flight slot or race session shutdown.
    _pending = Future<void>.microtask(() => _save(recorder, journal));
    _publish();
    return _pending!;
  }

  Future<void> _save(
    RunRecorder? recorder,
    RunReplayJournalWriter? journal,
  ) async {
    final id = descriptor.runSessionId;
    final summary = _summary!;
    try {
      if (recorder == null || journal == null) {
        throw StateError(
          'Replay saving prerequisites were unavailable. Retry before leaving.',
        );
      }
      final finalized = await RunRewardDiagnostics.instance.measure(
        id,
        'local_replay_save',
        () => recorder.finalize(clientSummary: summary),
      );
      _status = await RunRewardDiagnostics.instance.measure(
        id,
        'local_journal',
        () => journal(
          runSessionId: id,
          runMode: descriptor.runMode,
          replayArtifactId: finalized.replayArtifactId,
          canonicalSha256: finalized.replayBlob.canonicalSha256,
          contentLengthBytes: finalized.contentLengthBytes,
          provisionalSummary: summary,
        ),
      );
      _journaled = true;
    } catch (failure) {
      _error = '$failure';
      _status = RunSubmissionStatus(
        runSessionId: id,
        phase: RunSubmissionPhase.internalError,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        message: 'Replay could not be saved. Retry before leaving.',
      );
      debugPrint('Replay journaling failed for runSessionId=$id: $failure');
    } finally {
      _pending = null;
      _publish();
    }
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    retire();
    super.dispose();
  }
}
