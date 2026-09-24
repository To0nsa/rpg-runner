/// Shared authoring/runtime admission bounds for rescue encounters.
abstract final class EncounterLimits {
  static const maxEncountersPerChunk = 4;
  static const maxNpcsPerEncounter = 4;
  static const maxEnemiesPerEncounter = 8;
  static const maxLiveEncounters = 16;
  static const maxLiveParticipants =
      maxLiveEncounters * (maxNpcsPerEncounter + maxEnemiesPerEncounter);

  /// Initial rescue bonus, in points per living NPC; authored overrides win.
  static const defaultPointsPerNpc = 250;
  static const maxPointsPerNpc = 100000;

  /// Exact integer ceiling shared with JavaScript/JSON score consumers.
  static const maxExactScore = 9007199254740991;

  static void validatePoints(int points) {
    if (points < 0 || points > maxPointsPerNpc) {
      throw ArgumentError.value(
        points,
        'pointsPerNpc',
        'Must be 0..$maxPointsPerNpc.',
      );
    }
  }

  /// Fails before mutation if a reward cannot be represented exactly on web.
  static int addAward(
    int current, {
    required int survivors,
    required int points,
  }) {
    validatePoints(points);
    if (current < 0 ||
        current > maxExactScore ||
        survivors < 0 ||
        survivors > maxNpcsPerEncounter) {
      throw ArgumentError('Invalid rescue award input.');
    }
    final award = survivors * points;
    if (current > maxExactScore - award) {
      throw StateError('Rescue score exceeds the exact shared integer range.');
    }
    return current + award;
  }
}
