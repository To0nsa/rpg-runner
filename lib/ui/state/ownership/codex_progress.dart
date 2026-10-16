/// Validated Competitive best scores used by Library location entries.
class CodexProgress {
  const CodexProgress._(this.competitiveBestScores);

  factory CodexProgress({Map<String, int> competitiveBestScores = const {}}) =>
      CodexProgress._(Map.unmodifiable(competitiveBestScores));

  static const empty = CodexProgress._({});
  final Map<String, int> competitiveBestScores;

  factory CodexProgress.fromJson(Object? raw) {
    if (raw == null) return empty;
    if (raw is! Map ||
        (raw['schemaVersion'] != 1 && raw['schemaVersion'] != 2)) {
      throw const FormatException('Unsupported Codex progression.');
    }
    if (raw['schemaVersion'] == 1) legacyKillsFromJson(raw);
    return CodexProgress(
      competitiveBestScores: _counts(raw['competitiveBestScores']),
    );
  }

  /// Reads an old kill map for projection until settlement moves it.
  static Map<String, int> legacyKillsFromJson(Object? raw) {
    if (raw is! Map || raw['schemaVersion'] != 1) return const {};
    return _counts(raw['enemyKills']);
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'competitiveBestScores': Map<String, int>.of(competitiveBestScores),
  };

  static Map<String, int> _counts(Object? raw) {
    if (raw is! Map || raw.length > 64) {
      throw const FormatException('Invalid Codex counts.');
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
        throw const FormatException('Invalid Codex count.');
      }
      result[entry.key as String] = value;
    }
    return result;
  }
}
