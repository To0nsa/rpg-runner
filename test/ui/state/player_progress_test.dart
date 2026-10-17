import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/ownership/player_progress.dart';
import 'package:rpg_runner/ui/state/ownership/enemy_defeats.dart';

void main() {
  test('level thresholds use cumulative XP and carry over multiple levels', () {
    for (final (xp, level, inLevel, next) in [
      (0, 1, 0, 100),
      (99, 1, 99, 100),
      (100, 2, 0, 124),
      (223, 2, 123, 124),
      (224, 3, 0, 154),
      (378, 4, 0, 191),
      (19600, 19, 0, 4804),
      (24404, 20, 0, 5957),
      (212894, 29, 41285, 41286),
      (212895, 30, 0, 0),
      (300000, 30, 0, 0),
    ]) {
      final progress = PlayerProgress(
        totalXp: xp,
        acceptedRuns: 0,
        damageDealt100: 0,
        damageTaken100: 0,
      );
      expect(progress.level, level);
      expect(progress.xpInLevel, inLevel);
      expect(progress.xpForNextLevel, next);
      expect(progress.isMaxLevel, level == PlayerProgress.maxLevel);
    }
  });

  test('old profiles start empty and malformed totals are rejected', () {
    expect(PlayerProgress.fromJson(null).level, 1);
    final legacy = PlayerProgress.fromJson({
      'schemaVersion': 1,
      'totalXp': 100,
      'acceptedRuns': 3,
      'damageDealt100': 0,
      'damageTaken100': 0,
    });
    expect(legacy.acceptedRuns, 3);
    expect(legacy.runsInMode('practice'), 0);
    expect(
      () => PlayerProgress.fromJson({
        'schemaVersion': 1,
        'totalXp': 0,
        'acceptedRuns': 0,
        'damageDealt100': -1,
        'damageTaken100': 0,
      }),
      throwsFormatException,
    );
  });

  test('profile defeat total derives from the shared per-enemy map', () {
    final defeats = EnemyDefeats(byEnemy: {'grojib': 10, 'derf': 2});
    expect(defeats.total, 12);
  });

  test('run detail is retained by level and mode', () {
    final progress = PlayerProgress.fromJson({
      'schemaVersion': 1,
      'totalXp': 0,
      'acceptedRuns': 4,
      'damageDealt100': 0,
      'damageTaken100': 0,
      'runsByLevel': {
        'forest': {'practice': 1, 'competitive': 1, 'weekly': 1},
        'field': {'practice': 1, 'competitive': 0, 'weekly': 0},
      },
    });
    expect(progress.runsInMode('practice'), 2);
    expect(progress.runsInMode('competitive'), 1);
    expect(progress.runsInMode('weekly'), 1);
    expect(progress.toJson()['runsByLevel'], progress.runsByLevel);
  });
}
