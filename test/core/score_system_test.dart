import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/enemies/enemy_id.dart';
import 'package:walkscape_runner/core/scoring/run_score_breakdown.dart';
import 'package:walkscape_runner/core/tuning/v0_score_tuning.dart';

void main() {
  test('run score breakdown includes distance/time/collectibles/kills', () {
    final breakdown = buildRunScoreBreakdown(
      tick: 120,
      distanceUnits: 500,
      collectibles: 2,
      collectibleScore: 100,
      enemyKillCounts: const [1, 0],
      tuning: const V0ScoreTuning(
        timeScorePerSecond: 10,
        distanceScorePerMeter: 5,
        groundEnemyKillScore: 100,
        flyingEnemyKillScore: 150,
      ),
      tickHz: 60,
    );

    expect(breakdown.totalPoints, 295);
    expect(breakdown.rows, hasLength(4));

    final distance = breakdown.rows[0];
    expect(distance.kind, RunScoreRowKind.distance);
    expect(distance.count, 5);
    expect(distance.points, 25);

    final time = breakdown.rows[1];
    expect(time.kind, RunScoreRowKind.time);
    expect(time.count, 2);
    expect(time.points, 20);

    final collectibles = breakdown.rows[2];
    expect(collectibles.kind, RunScoreRowKind.collectibles);
    expect(collectibles.count, 2);
    expect(collectibles.points, 100);

    final kills = breakdown.rows[3];
    expect(kills.kind, RunScoreRowKind.enemyKill);
    expect(kills.enemyId, EnemyId.flyingEnemy);
    expect(kills.count, 1);
    expect(kills.points, 150);
  });

  test('run score breakdown skips zero kill rows', () {
    final breakdown = buildRunScoreBreakdown(
      tick: 0,
      distanceUnits: 0,
      collectibles: 0,
      collectibleScore: 0,
      enemyKillCounts: const [0, 0],
      tuning: const V0ScoreTuning(),
      tickHz: 60,
    );

    expect(breakdown.rows, hasLength(3));
    expect(
      breakdown.rows.where((row) => row.kind == RunScoreRowKind.enemyKill),
      isEmpty,
    );
  });
}
