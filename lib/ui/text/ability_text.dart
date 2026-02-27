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

String _titleCaseSnake(String source) {
  final words = source.split('_');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

const Map<AbilityKey, String> _displayNameOverrides = <AbilityKey, String>{
  // Primary: sword arts.
  'eloise.bloodletter_slash': 'Bloodletter Slash',
  'eloise.bloodletter_cleave': 'Bloodletter Cleave',
  'eloise.seeker_slash': 'Seeker Slash',
  'eloise.riposte_guard': 'Riposte Guard',

  // Secondary: shield arts.
  'eloise.concussive_bash': 'Concussive Bash',
  'eloise.concussive_breaker': 'Concussive Breaker',
  'eloise.seeker_bash': 'Seeker Bash',
  'eloise.aegis_riposte': 'Aegis Riposte',
  'eloise.shield_block': 'Shield block',

  // Projectile: ranged attacks.
  'eloise.snap_shot': 'Snap Shot',
  'eloise.quick_shot': 'Quick Shot',
  'eloise.skewer_shot': 'Skewer Shot',
  'eloise.overcharge_shot': 'Overcharge Bolt',

  // Spell: utility and sustain.
  'eloise.arcane_haste': 'Arcane Haste',
  'eloise.focus': 'Focus',
  'eloise.arcane_ward': 'Arcane Ward',
  'eloise.cleanse': 'Cleanse',
  'eloise.vital_surge': 'Vital Surge',
  'eloise.mana_infusion': 'Mana Infusion',
  'eloise.second_wind': 'Second Wind',

  // Mobility.
  'eloise.jump': 'Jump',
  'eloise.double_jump': 'Double Jump',
  'eloise.dash': 'Dash',
  'eloise.roll': 'Concussive Roll',
};
