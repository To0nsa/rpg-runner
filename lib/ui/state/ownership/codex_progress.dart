/// Account-wide progress read from canonical ownership after run settlement.
/// Maps use stable catalog names and are detached from decoded JSON.
class CodexProgress {
  const CodexProgress._(this.enemyKills, this.competitiveBestScores);

  factory CodexProgress({
    Map<String, int> enemyKills = const {},
    Map<String, int> competitiveBestScores = const {},
  }) => CodexProgress._(
    Map.unmodifiable(enemyKills),
    Map.unmodifiable(competitiveBestScores),
  );

  static const empty = CodexProgress._({}, {});
  final Map<String, int> enemyKills;
  final Map<String, int> competitiveBestScores;

  factory CodexProgress.fromJson(Object? raw) {
    if (raw == null) return empty;
    if (raw is! Map || raw['schemaVersion'] != 1) {
      throw const FormatException('Unsupported Codex progression.');
    }
    return CodexProgress(
      enemyKills: _counts(raw['enemyKills']),
      competitiveBestScores: _counts(raw['competitiveBestScores']),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'enemyKills': Map<String, int>.of(enemyKills),
    'competitiveBestScores': Map<String, int>.of(competitiveBestScores),
  };

  static Map<String, int> _counts(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid Codex counts.');
    final result = <String, int>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (entry.key is! String ||
          value is! num ||
          !value.isFinite ||
          value < 0 ||
          value > 9007199254740991 ||
          value != value.roundToDouble()) {
        throw const FormatException('Invalid Codex count.');
      }
      result[entry.key as String] = value.toInt();
    }
    return result;
  }
}
