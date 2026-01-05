import '../../../core/scoring/run_score_breakdown.dart';

enum ScoreFeedState { idle, feeding, complete }

class ScoreFeedRowState {
  ScoreFeedRowState({
    required this.row,
    required this.pointsPerSecond,
  }) : remainingPoints = row.points;

  final RunScoreRow row;
  final double pointsPerSecond;
  int remainingPoints;
  double carry = 0.0;
}

class ScoreFeedController {
  ScoreFeedController({
    required List<RunScoreRow> rows,
    required this.totalPoints,
    double feedDurationSeconds = 0.8,
  }) : _rows = [
          for (final row in rows)
            ScoreFeedRowState(
              row: row,
              pointsPerSecond:
                  row.points <= 0 ? 0.0 : row.points / feedDurationSeconds,
            ),
        ],
        displayScore = 0,
        feedState =
            totalPoints > 0 ? ScoreFeedState.idle : ScoreFeedState.complete;

  final int totalPoints;
  final List<ScoreFeedRowState> _rows;

  int displayScore;
  ScoreFeedState feedState;

  List<ScoreFeedRowState> get rows => _rows;

  bool startFeed() {
    if (feedState != ScoreFeedState.idle || totalPoints <= 0) return false;
    feedState = ScoreFeedState.feeding;
    return true;
  }

  bool tick(double dtSeconds) {
    if (feedState != ScoreFeedState.feeding || dtSeconds <= 0) {
      return false;
    }

    var gained = 0;
    var anyRemaining = false;

    for (final row in _rows) {
      if (row.remainingPoints <= 0 || row.pointsPerSecond <= 0) continue;
      row.carry += dtSeconds * row.pointsPerSecond;
      final raw = row.carry.floor();
      if (raw <= 0) {
        anyRemaining = true;
        continue;
      }
      row.carry -= raw;
      final consume =
          raw > row.remainingPoints ? row.remainingPoints : raw;
      row.remainingPoints -= consume;
      gained += consume;
      if (row.remainingPoints > 0) anyRemaining = true;
    }

    if (gained > 0) {
      displayScore += gained;
      if (displayScore > totalPoints) displayScore = totalPoints;
    }

    if (!anyRemaining) {
      completeFeed();
      return true;
    }

    return gained > 0;
  }

  void completeFeed() {
    displayScore = totalPoints;
    for (final row in _rows) {
      row.remainingPoints = 0;
      row.carry = 0.0;
    }
    feedState = ScoreFeedState.complete;
  }
}
