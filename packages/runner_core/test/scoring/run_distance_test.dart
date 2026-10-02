import 'package:runner_core/scoring/run_distance.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/tuning/score_tuning.dart';
import 'package:test/test.dart';

void main() {
  test('one chunk awards 24 metres and 120 distance points', () {
    final score = buildRunScoreBreakdown(
      tick: 0,
      distanceUnits: 600,
      collectibles: 0,
      collectibleScore: 0,
      enemyKillCounts: List.filled(EnemyId.values.length, 0),
      tuning: const ScoreTuning(),
      tickHz: 60,
    );
    expect(score.rows.first.count, 24);
    expect(score.rows.first.points, 120);
    expect(score.totalPoints, 120);
  });

  test(
    'whole metres use 25 units, including exact chunk and metre boundaries',
    () {
      expect(distanceUnitsToMeters(0), 0);
      expect(distanceUnitsToMeters(24.999), 0);
      expect(distanceUnitsToMeters(25), 1);
      expect(distanceUnitsToMeters(49.999), 1);
      expect(distanceUnitsToMeters(50), 2);
      expect(distanceUnitsToMeters(600), 24);
    },
  );

  test('retracing ground never earns distance twice', () {
    final distance = RunDistanceTracker();
    distance.recordMotion(250);
    expect(distanceUnitsToMeters(distance.distanceUnits), 10);
    distance.recordMotion(-125);
    expect(distanceUnitsToMeters(distance.distanceUnits), 10);
    distance.recordMotion(125);
    expect(distanceUnitsToMeters(distance.distanceUnits), 10);
    distance.recordMotion(25);
    expect(distanceUnitsToMeters(distance.distanceUnits), 11);
  });

  test('moving behind spawn cannot earn distance on the return to spawn', () {
    final distance = RunDistanceTracker();
    distance.recordMotion(-100);
    expect(distance.distanceUnits, 0);
    distance.recordMotion(100);
    expect(distance.distanceUnits, 0);
    distance.recordMotion(25);
    expect(distance.distanceUnits, 25);
    expect(RunDistanceTracker().distanceUnits, 0);
  });
}
