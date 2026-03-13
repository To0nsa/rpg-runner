import 'package:run_protocol/run_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('sort key preserves score desc, distance desc, duration asc', () {
    final betterScore = buildLeaderboardSortKey(
      score: 1200,
      distanceMeters: 300,
      durationSeconds: 80,
      entryId: 'a',
    );
    final worseScore = buildLeaderboardSortKey(
      score: 1100,
      distanceMeters: 999,
      durationSeconds: 1,
      entryId: 'b',
    );
    expect(betterScore.compareTo(worseScore), lessThan(0));

    final betterDistance = buildLeaderboardSortKey(
      score: 1200,
      distanceMeters: 301,
      durationSeconds: 80,
      entryId: 'c',
    );
    expect(betterDistance.compareTo(betterScore), lessThan(0));

    final betterDuration = buildLeaderboardSortKey(
      score: 1200,
      distanceMeters: 301,
      durationSeconds: 79,
      entryId: 'd',
    );
    expect(betterDuration.compareTo(betterDistance), lessThan(0));
  });
}
