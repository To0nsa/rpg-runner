/// Account-wide, per-enemy defeats shared by Library gates and Profile stats.
final class EnemyDefeats {
  const EnemyDefeats._(this.byEnemy);

  factory EnemyDefeats({Map<String, int> byEnemy = const {}}) =>
      EnemyDefeats._(Map.unmodifiable(byEnemy));

  static const empty = EnemyDefeats._({});
  final Map<String, int> byEnemy;

  int get total => byEnemy.values.fold<int>(0, (sum, count) => sum + count);

  factory EnemyDefeats.fromJson(
    Object? raw, {
    Map<String, int> legacyCodexKills = const {},
  }) {
    if (raw == null) return EnemyDefeats(byEnemy: legacyCodexKills);
    if (raw is! Map || raw['schemaVersion'] != 1) {
      throw const FormatException('Unsupported enemy defeats.');
    }
    return EnemyDefeats(byEnemy: _counts(raw['byEnemy']));
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'byEnemy': Map<String, int>.of(byEnemy),
  };

  static Map<String, int> _counts(Object? raw) {
    if (raw is! Map || raw.length > 64) {
      throw const FormatException('Invalid enemy defeat counts.');
    }
    final result = <String, int>{};
    final idPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$');
    for (final entry in raw.entries) {
      final value = entry.value;
      if (entry.key is! String ||
          !idPattern.hasMatch(entry.key as String) ||
          value is! int ||
          value < 0 ||
          value > 9007199254740991) {
        throw const FormatException('Invalid enemy defeat count.');
      }
      result[entry.key as String] = value;
    }
    return result;
  }
}
