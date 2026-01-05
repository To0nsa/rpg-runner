import '../../core/events/game_event.dart';
import '../../core/scoring/run_score_breakdown.dart';
import '../../core/tuning/v0_score_tuning.dart';

class RunResult {
  const RunResult({
    required this.runId,
    required this.endedAtMs,
    required this.endedReason,
    required this.score,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.tick,
  });

  final int runId;
  final int endedAtMs;
  final RunEndReason endedReason;
  final int score;
  final int distanceMeters;
  final int durationSeconds;
  final int tick;

  RunResult copyWith({
    int? runId,
    int? endedAtMs,
  }) {
    return RunResult(
      runId: runId ?? this.runId,
      endedAtMs: endedAtMs ?? this.endedAtMs,
      endedReason: endedReason,
      score: score,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      tick: tick,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'runId': runId,
        'endedAtMs': endedAtMs,
        'endedReason': endedReason.name,
        'score': score,
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'tick': tick,
      };

  static RunResult fromJson(Map<String, dynamic> json) {
    final reasonName = json['endedReason'] as String?;
    final reason = _reasonFromName(reasonName);
    return RunResult(
      runId: json['runId'] as int? ?? 0,
      endedAtMs: json['endedAtMs'] as int? ?? 0,
      endedReason: reason,
      score: json['score'] as int? ?? 0,
      distanceMeters: json['distanceMeters'] as int? ?? 0,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      tick: json['tick'] as int? ?? 0,
    );
  }

  static RunEndReason _reasonFromName(String? name) {
    if (name == null) return RunEndReason.playerDied;
    for (final value in RunEndReason.values) {
      if (value.name == name) return value;
    }
    return RunEndReason.playerDied;
  }
}

RunResult buildRunResult({
  required RunEndedEvent event,
  required V0ScoreTuning scoreTuning,
  required int tickHz,
  required int endedAtMs,
}) {
  final breakdown = buildRunScoreBreakdown(
    tick: event.tick,
    distanceUnits: event.distance,
    collectibles: event.stats.collectibles,
    collectibleScore: event.stats.collectibleScore,
    enemyKillCounts: event.stats.enemyKillCounts,
    tuning: scoreTuning,
    tickHz: tickHz,
  );

  final distanceMeters = (event.distance / 100.0).floor();
  final durationSeconds = tickHz <= 0 ? 0 : event.tick ~/ tickHz;

  return RunResult(
    runId: 0,
    endedAtMs: endedAtMs,
    endedReason: event.reason,
    score: breakdown.totalPoints,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    tick: event.tick,
  );
}
