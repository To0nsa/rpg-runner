import 'package:run_protocol/leaderboard_entry.dart';
import 'package:test/test.dart';

void main() {
  test('account level round trips and old entries omit it', () {
    final encoded = _entry(ghostAvailable: false).toJson();
    expect(encoded.containsKey('playerLevel'), isFalse);
    expect(LeaderboardEntry.fromJson(encoded).playerLevel, isNull);

    encoded['playerLevel'] = 7;
    expect(LeaderboardEntry.fromJson(encoded).playerLevel, 7);
    expect(LeaderboardEntry.fromJson(encoded).toJson()['playerLevel'], 7);
  });

  test('invalid account level fails at both constructor and decode', () {
    expect(
      () => _entry(ghostAvailable: false, playerLevel: 31),
      throwsArgumentError,
    );
    expect(
      () => LeaderboardEntry.fromJson(
        _entry(ghostAvailable: false).toJson()..['playerLevel'] = 0,
      ),
      throwsFormatException,
    );
    expect(
      () => LeaderboardEntry.fromJson(
        _entry(ghostAvailable: false).toJson()..['playerLevel'] = '7',
      ),
      throwsFormatException,
    );
  });

  test(
    'ghost availability round trips and missing legacy value fails closed',
    () {
      final entry = _entry(ghostAvailable: true);

      final encoded = entry.toJson();
      expect(encoded['ghostAvailable'], isTrue);
      expect(LeaderboardEntry.fromJson(encoded).ghostAvailable, isTrue);

      encoded.remove('ghostAvailable');
      expect(LeaderboardEntry.fromJson(encoded).ghostAvailable, isFalse);
    },
  );

  test('ghost availability rejects a non-boolean wire value', () {
    final encoded = _entry(ghostAvailable: false).toJson()
      ..['ghostAvailable'] = 'true';

    expect(() => LeaderboardEntry.fromJson(encoded), throwsFormatException);
  });
}

LeaderboardEntry _entry({required bool ghostAvailable, int? playerLevel}) {
  return LeaderboardEntry(
    boardId: 'board_1',
    entryId: 'entry_1',
    runSessionId: 'run_1',
    uid: 'uid_1',
    displayName: 'Player One',
    playerLevel: playerLevel,
    characterId: 'eloise',
    score: 1200,
    distanceMeters: 400,
    durationSeconds: 100,
    sortKey: '0000001200:0000000400:0000000100:entry_1',
    ghostEligible: true,
    ghostAvailable: ghostAvailable,
    updatedAtMs: 1000,
    rank: 1,
  );
}
