import '../../core/abilities/ability_def.dart';

/// User-facing display name for an [AbilityKey].
///
/// Kept in one place so call sites can later move to localization keys without
/// changing widget logic.
String abilityDisplayName(AbilityKey id) {
  final dot = id.indexOf('.');
  final raw = dot >= 0 ? id.substring(dot + 1) : id;
  return _titleCaseSnake(raw);
}

String _titleCaseSnake(String source) {
  final words = source.split('_');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
