import '../enemies/enemy_id.dart';
import '../tuning/score_tuning.dart';

/// Categories of score contributions shown in the end-of-run breakdown.
enum RunScoreRowKind {
  /// Points earned from distance traveled.
  distance,

  /// Points earned from survival time.
  time,

  /// Points earned from collected items.
  collectibles,

  /// Points earned from killing enemies (one row per enemy type).
  enemyKill,
}

/// A single line item in the score breakdown UI.
///
/// Each row shows a category, a count (e.g., meters, seconds, kills),
/// and the points contributed by that category.
class RunScoreRow {
  const RunScoreRow({
    required this.kind,
    required this.count,
    required this.points,
    this.enemyId,
  });

  /// Row category (distance/time/collectibles/enemy kills).
  final RunScoreRowKind kind;

  /// Quantity displayed (meters, seconds, collectible count, or kill count).
  final int count;

  /// Total points contributed by this row.
  final int points;

  /// For [RunScoreRowKind.enemyKill] rows, identifies the enemy type.
  final EnemyId? enemyId;
}

/// Complete score breakdown for a finished run.
///
/// Contains itemized rows and the computed total. Used by the game-over UI
/// to display how the player earned their score.
class RunScoreBreakdown {
  const RunScoreBreakdown({
    required this.rows,
    required this.totalPoints,
  });

  /// Itemized score contributions (distance, time, collectibles, enemy kills).
  final List<RunScoreRow> rows;

  /// Sum of all row points.
  final int totalPoints;
}

/// Computes the score breakdown for a completed run.
///
/// Converts raw game stats (ticks, distance units, kill counts) into
/// player-facing values (meters, seconds) and calculates points using
/// [ScoreTuning] multipliers.
RunScoreBreakdown buildRunScoreBreakdown({
  required int tick,
  required double distanceUnits,
  required int collectibles,
  required int collectibleScore,
  required List<int> enemyKillCounts,
  required ScoreTuning tuning,
  required int tickHz,
  int unitsPerMeter = 100,
}) {
  // Convert internal units to player-facing values.
  final meters =
      unitsPerMeter <= 0 ? 0 : (distanceUnits / unitsPerMeter).floor();
  final timeSeconds = tickHz <= 0 ? 0 : tick ~/ tickHz;

  final rows = <RunScoreRow>[
    RunScoreRow(
      kind: RunScoreRowKind.distance,
      count: meters,
      points: meters * tuning.distanceScorePerMeter,
    ),
    RunScoreRow(
      kind: RunScoreRowKind.time,
      count: timeSeconds,
      points: timeSeconds * tuning.timeScorePerSecond,
    ),
    RunScoreRow(
      kind: RunScoreRowKind.collectibles,
      count: collectibles,
      points: collectibleScore,
    ),
  ];

  // Add a row for each enemy type with at least one kill.
  for (final enemyId in EnemyId.values) {
    final index = enemyId.index;
    final kills = index < enemyKillCounts.length ? enemyKillCounts[index] : 0;
    if (kills <= 0) continue;
    rows.add(
      RunScoreRow(
        kind: RunScoreRowKind.enemyKill,
        count: kills,
        points: kills * _enemyKillScore(tuning, enemyId),
        enemyId: enemyId,
      ),
    );
  }

  // Sum all rows for total.
  var totalPoints = 0;
  for (final row in rows) {
    totalPoints += row.points;
  }

  return RunScoreBreakdown(
    rows: List<RunScoreRow>.unmodifiable(rows),
    totalPoints: totalPoints,
  );
}

/// Returns the point value for killing one enemy of [enemyId] type.
int _enemyKillScore(ScoreTuning tuning, EnemyId enemyId) {
  switch (enemyId) {
    case EnemyId.groundEnemy:
      return tuning.groundEnemyKillScore;
    case EnemyId.flyingEnemy:
      return tuning.flyingEnemyKillScore;
  }
}
