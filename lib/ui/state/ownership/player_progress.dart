import 'dart:math' as math;

/// Account-wide totals earned from accepted, replay-validated runs.
///
/// Damage is stored in hundredths of HP. Level is a display-only value derived
/// from lifetime XP, so an account cannot hold conflicting XP and level values.
final class PlayerProgress {
  /// Highest displayed account level; lifetime XP can continue to grow.
  static const maxLevel = 30;

  static const _firstLevelXp = 100;
  // A 24% step puts level 19 -> 20 above 30 runs at 150 XP per good run.
  static const _xpGrowthFactor = 1.24;

  static final List<int> _xpBeforeLevels = _buildXpThresholds();

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
  int get xpInLevel => isMaxLevel ? 0 : totalXp - _xpBeforeLevels[level - 1];

  /// XP required to advance from the current level.
  int get xpForNextLevel =>
      isMaxLevel ? 0 : _xpBeforeLevels[level] - _xpBeforeLevels[level - 1];

  bool get isMaxLevel => level == maxLevel;

  int get level {
    for (var candidate = 2; candidate <= maxLevel; candidate++) {
      if (totalXp < _xpBeforeLevels[candidate - 1]) return candidate - 1;
    }
    return maxLevel;
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

  static List<int> _buildXpThresholds() {
    final thresholds = <int>[0];
    for (var level = 1; level < maxLevel; level++) {
      // Round each level's cost before accumulating so carry matches the bar.
      final cost = (_firstLevelXp * math.pow(_xpGrowthFactor, level - 1))
          .round();
      thresholds.add(thresholds.last + cost);
    }
    return List<int>.unmodifiable(thresholds);
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
    return Map.unmodifiable(
      raw.map((key, value) {
        if (key is! String || key.isEmpty || value is! Map) {
          throw const FormatException('Invalid runs by level.');
        }
        return MapEntry(
          key,
          Map<String, int>.unmodifiable({
            for (final mode in ['practice', 'competitive', 'weekly'])
              mode: _count(value[mode]),
          }),
        );
      }),
    );
  }
}
