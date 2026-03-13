import 'codecs/json_value_reader.dart';
import 'run_mode.dart';

final class BoardKey {
  const BoardKey({
    required this.mode,
    required this.levelId,
    required this.windowId,
    required this.rulesetVersion,
    required this.scoreVersion,
  }) : assert(mode != RunMode.practice, 'BoardKey mode cannot be practice');

  final RunMode mode;
  final String levelId;
  final String windowId;
  final String rulesetVersion;
  final String scoreVersion;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'mode': mode.name,
      'levelId': levelId,
      'windowId': windowId,
      'rulesetVersion': rulesetVersion,
      'scoreVersion': scoreVersion,
    };
  }

  factory BoardKey.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'boardKey');
    final mode = RunMode.parse(json['mode'], fieldName: 'boardKey.mode');
    if (mode == RunMode.practice) {
      throw FormatException('boardKey.mode cannot be practice.');
    }
    return BoardKey(
      mode: mode,
      levelId: readRequiredString(json, 'levelId'),
      windowId: readRequiredString(json, 'windowId'),
      rulesetVersion: readRequiredString(json, 'rulesetVersion'),
      scoreVersion: readRequiredString(json, 'scoreVersion'),
    );
  }
}
