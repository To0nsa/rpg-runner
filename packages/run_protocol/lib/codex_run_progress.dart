import 'codecs/json_value_reader.dart';

/// Replay-derived Codex evidence. IDs are stable names, never enum ordinals.
///
/// Only accepted validator results carry this payload. Counts describe this run,
/// not lifetime totals. Version 1 permits at most 64 enemy identities.
final class CodexRunProgress {
  CodexRunProgress({
    required this.levelId,
    required Map<String, int> enemyKills,
  }) : enemyKills = Map.unmodifiable(enemyKills) {
    if (!_validId(levelId) || enemyKills.length > 64) {
      throw ArgumentError('Invalid Codex level or enemy count.');
    }
    for (final entry in enemyKills.entries) {
      if (!_validId(entry.key) || entry.value < 0 || entry.value > maxCount) {
        throw ArgumentError('Invalid Codex enemy kill count.');
      }
    }
  }

  static const int maxCount = 9007199254740991;
  final String levelId;
  final Map<String, int> enemyKills;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'levelId': levelId,
    'enemyKills': Map<String, int>.of(enemyKills),
  };

  factory CodexRunProgress.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'codex');
    if (readRequiredInt(json, 'schemaVersion') != 1) {
      throw const FormatException('Unsupported Codex evidence version.');
    }
    final kills = readRequiredObject(json, 'enemyKills');
    try {
      return CodexRunProgress(
        levelId: readRequiredString(json, 'levelId'),
        enemyKills: {
          for (final key in kills.keys) key: readRequiredInt(kills, key),
        },
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  static bool _validId(String id) =>
      RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$').hasMatch(id);
}
