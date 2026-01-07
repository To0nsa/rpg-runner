import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/enemies/enemy_id.dart';
import 'package:walkscape_runner/core/scoring/run_score_breakdown.dart';
import 'package:walkscape_runner/core/tuning/score_tuning.dart';

void main() {
  test('run score breakdown includes distance/time/collectibles/kills', () {
    const distanceUnits = 500.0;
    const tick = 120;
    const tickHz = 60;
    const tuning = ScoreTuning(
      timeScorePerSecond: 10,
      distanceScorePerMeter: 5,
      groundEnemyKillScore: 100,
      flyingEnemyKillScore: 150,
    );

    // Compute expected values dynamically.
    final expectedMeters = (distanceUnits / kWorldUnitsPerMeter).floor();
    final expectedDistancePoints = expectedMeters * tuning.distanceScorePerMeter;
    const expectedTimeSeconds = tick ~/ tickHz;
    const expectedTimePoints = expectedTimeSeconds * 10;
    const expectedCollectiblePoints = 100;
    const expectedKillPoints = 150;
    final expectedTotal = expectedDistancePoints +
        expectedTimePoints +
        expectedCollectiblePoints +
        expectedKillPoints;

    final breakdown = buildRunScoreBreakdown(
      tick: tick,
      distanceUnits: distanceUnits,
      collectibles: 2,
      collectibleScore: 100,
      enemyKillCounts: const [1, 0],
      tuning: tuning,
      tickHz: tickHz,
    );

    expect(breakdown.totalPoints, expectedTotal);
    expect(breakdown.rows, hasLength(4));

    final distance = breakdown.rows[0];
    expect(distance.kind, RunScoreRowKind.distance);
    expect(distance.count, expectedMeters);
    expect(distance.points, expectedDistancePoints);

    final time = breakdown.rows[1];
    expect(time.kind, RunScoreRowKind.time);
    expect(time.count, expectedTimeSeconds);
    expect(time.points, expectedTimePoints);

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
      tuning: const ScoreTuning(),
      tickHz: 60,
    );

    expect(breakdown.rows, hasLength(3));
    expect(
      breakdown.rows.where((row) => row.kind == RunScoreRowKind.enemyKill),
      isEmpty,
    );
  });
}
