/// Account-wide totals earned from accepted, replay-validated runs.
///
/// Damage is stored in hundredths of HP. Level is a display-only value derived
/// from lifetime XP, so an account cannot hold conflicting XP and level values.
final class PlayerProgress {
  const PlayerProgress({
    required this.totalXp,
    required this.acceptedRuns,
    required this.damageDealt100,
    required this.damageTaken100,
    this.runsByLevel = const {},
  });

  static const empty = PlayerProgress(
    totalXp: 0,
    acceptedRuns: 0,
    runsByLevel: {},
    damageDealt100: 0,
    damageTaken100: 0,
  );

  final int totalXp;
  final int acceptedRuns;
  /// Settled runs indexed by level, then mode. Older totals have no breakdown.
  final Map<String, Map<String, int>> runsByLevel;
  final int damageDealt100;
  final int damageTaken100;

  int runsInMode(String mode) => runsByLevel.values.fold<int>(
    0,
    (total, level) => total + (level[mode] ?? 0),
  );

  /// XP earned since the current level began.
  int get xpInLevel => totalXp - _xpBeforeLevel(level);

  /// XP required to advance from the current level.
  int get xpForNextLevel => 100 + 25 * (level - 1);

  int get level {
    var low = 1;
    var high = 2;
    while (_xpBeforeLevel(high) <= totalXp) {
      low = high;
      high *= 2;
    }
    while (high - low > 1) {
      final middle = low + (high - low) ~/ 2;
      if (_xpBeforeLevel(middle) <= totalXp) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low;
  }

  factory PlayerProgress.fromJson(Object? raw) {
    if (raw == null) return empty;
    if (raw is! Map || raw['schemaVersion'] != 1) {
      throw const FormatException('Unsupported player progression.');
    }
    return PlayerProgress(
      totalXp: _count(raw['totalXp']),
      acceptedRuns: _count(raw['acceptedRuns']),
      runsByLevel: _runsByLevel(raw['runsByLevel']),
      damageDealt100: _count(raw['damageDealt100']),
      damageTaken100: _count(raw['damageTaken100']),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'totalXp': totalXp,
    'acceptedRuns': acceptedRuns,
    'runsByLevel': runsByLevel,
    'damageDealt100': damageDealt100,
    'damageTaken100': damageTaken100,
  };

  static int _xpBeforeLevel(int level) {
    final completed = level - 1;
    return 100 * completed + 25 * completed * (completed - 1) ~/ 2;
  }

  static int _count(Object? raw) {
    if (raw is! int || raw < 0 || raw > 9007199254740991) {
      throw const FormatException('Invalid player progression count.');
    }
    return raw;
  }

  static Map<String, Map<String, int>> _runsByLevel(Object? raw) {
    if (raw == null) return const {};
    if (raw is! Map) {
      throw const FormatException('Invalid runs by level.');
    }
    return Map.unmodifiable(raw.map((key, value) {
      if (key is! String || key.isEmpty || value is! Map) {
        throw const FormatException('Invalid runs by level.');
      }
      return MapEntry(key, Map<String, int>.unmodifiable({
        for (final mode in ['practice', 'competitive', 'weekly'])
          mode: _count(value[mode]),
      }));
    }));
  }
}
