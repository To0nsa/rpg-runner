import '../../core/abilities/ability_def.dart';

/// User-facing display name for an [AbilityKey].
///
/// Kept in one place so call sites can later move to localization keys without
/// changing widget logic.
String abilityDisplayName(AbilityKey id) {
  final override = _displayNameOverrides[id];
  if (override != null) return override;
  final dot = id.indexOf('.');
  final raw = dot >= 0 ? id.substring(dot + 1) : id;
  return _titleCaseSnake(raw);
}

/// Short user-facing role text for an [AbilityKey].
String abilityRoleText(AbilityKey id) {
  return _roleTextOverrides[id] ?? '';
}

String _titleCaseSnake(String source) {
  final words = source.split('_');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

const Map<AbilityKey, String> _displayNameOverrides = <AbilityKey, String>{
  'eloise.auto_aim_shot': 'Auto-Aim Shot',
  'eloise.quick_shot': 'Quick Shot',
  'eloise.piercing_shot': 'Piercing Shot',
  'eloise.charged_shot': 'Charged Shot',
};

const Map<AbilityKey, String> _roleTextOverrides = <AbilityKey, String>{
  'eloise.auto_aim_shot': 'Reliable lock-on, lower efficiency',
  'eloise.quick_shot': 'Fast weave shot, low damage per action',
  'eloise.piercing_shot': 'Line-up reward, inconsistent in duels',
  'eloise.charged_shot':
      'Tiered charge: tap/half/full scale damage, speed, and effects',
};
