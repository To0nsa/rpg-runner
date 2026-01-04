import '../enemies/enemy_id.dart';
import '../tuning/v0_score_tuning.dart';

enum RunScoreRowKind { distance, time, collectibles, enemyKill }

class RunScoreRow {
  const RunScoreRow({
    required this.kind,
    required this.count,
    required this.points,
    this.enemyId,
  });

  /// Row type (distance/time/collectibles/enemy kills).
  final RunScoreRowKind kind;

  /// Amount shown on the left side (meters, seconds, collectibles, kills).
  final int count;

  /// Total points contributed by this row.
  final int points;

  /// Enemy kind for kill rows.
  final EnemyId? enemyId;
}

class RunScoreBreakdown {
  const RunScoreBreakdown({
    required this.rows,
    required this.totalPoints,
  });

  final List<RunScoreRow> rows;
  final int totalPoints;
}

RunScoreBreakdown buildRunScoreBreakdown({
  required int tick,
  required double distanceUnits,
  required int collectibles,
  required int collectibleScore,
  required List<int> enemyKillCounts,
  required V0ScoreTuning tuning,
  required int tickHz,
  int unitsPerMeter = 100,
}) {
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

  var totalPoints = 0;
  for (final row in rows) {
    totalPoints += row.points;
  }

  return RunScoreBreakdown(
    rows: List<RunScoreRow>.unmodifiable(rows),
    totalPoints: totalPoints,
  );
}

int _enemyKillScore(V0ScoreTuning tuning, EnemyId enemyId) {
  switch (enemyId) {
    case EnemyId.groundEnemy:
      return tuning.groundEnemyKillScore;
    case EnemyId.flyingEnemy:
      return tuning.flyingEnemyKillScore;
  }
}
