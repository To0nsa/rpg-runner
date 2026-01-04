class V0ScoreTuning {
  const V0ScoreTuning({
    this.timeScorePerSecond = 5,
    this.distanceScorePerMeter = 5,
    this.groundEnemyKillScore = 100,
    this.flyingEnemyKillScore = 150,
  }) : assert(timeScorePerSecond >= 0),
       assert(distanceScorePerMeter >= 0),
       assert(groundEnemyKillScore >= 0),
       assert(flyingEnemyKillScore >= 0);

  /// Points per real-time second survived (implemented deterministically via tickHz).
  final int timeScorePerSecond;

  /// Points per whole meter traveled (100 world units = 1 meter).
  final int distanceScorePerMeter;

  /// Points for killing an enemy (by type).
  final int groundEnemyKillScore;
  final int flyingEnemyKillScore;
}
