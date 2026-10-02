/// Scoring tuning (points per time, distance, kills).
library;

/// Shared metre scale: a 600-unit chunk spans 24 metres.
const int kWorldUnitsPerMeter = 25;

class ScoreTuning {
  const ScoreTuning({
    this.timeScorePerSecond = 5,
    this.distanceScorePerMeter = 5,
    this.groundEnemyKillScore = 100,
    this.unocoDemonKillScore = 150,
  }) : assert(timeScorePerSecond >= 0),
       assert(distanceScorePerMeter >= 0),
       assert(groundEnemyKillScore >= 0),
       assert(unocoDemonKillScore >= 0);

  /// Points per real-time second survived (implemented deterministically via tickHz).
  final int timeScorePerSecond;

  /// Points per whole metre of furthest progress (25 world units = 1 metre).
  final int distanceScorePerMeter;

  /// Points for killing an enemy (by type).
  final int groundEnemyKillScore;
  final int unocoDemonKillScore;
}
