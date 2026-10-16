import 'codecs/json_value_reader.dart';

/// Replay-derived combat totals for one accepted run, in hundredths of HP.
///
/// These are actual HP changes, not raw damage requests. Version 1 excludes
/// healing and health paid as an ability cost.
final class PlayerRunStats {
  PlayerRunStats({required this.damageDealt100, required this.damageTaken100}) {
    if (!_valid(damageDealt100) || !_valid(damageTaken100)) {
      throw ArgumentError('Invalid player run damage total.');
    }
  }

  static const int maxCount = 9007199254740991;

  final int damageDealt100;
  final int damageTaken100;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'damageDealt100': damageDealt100,
    'damageTaken100': damageTaken100,
  };

  factory PlayerRunStats.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'playerRunStats');
    if (readRequiredInt(json, 'schemaVersion') != 1) {
      throw const FormatException('Unsupported player run stats version.');
    }
    try {
      return PlayerRunStats(
        damageDealt100: readRequiredInt(json, 'damageDealt100'),
        damageTaken100: readRequiredInt(json, 'damageTaken100'),
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  static bool _valid(int value) => value >= 0 && value <= maxCount;
}
