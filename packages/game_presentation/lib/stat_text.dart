import 'package:runner_core/stats/character_stat_id.dart';

import 'game_localization.dart';

/// Stat labels are presentation-owned; Core descriptors remain locale-independent.
String characterStatDisplayName(
  CharacterStatId id, {
  required GameLocalizations strings,
  ManaPresentation manaPresentation = ManaPresentation.mana,
}) => switch (id) {
  CharacterStatId.health => strings.statHealth,
  CharacterStatId.mana => strings.statMana(resource: manaPresentation.name),
  CharacterStatId.stamina => strings.statStamina,
  CharacterStatId.healthRegen => strings.statHealthRegen,
  CharacterStatId.manaRegen => strings.statManaRegen(
    resource: manaPresentation.name,
  ),
  CharacterStatId.staminaRegen => strings.statStaminaRegen,
  CharacterStatId.defense => strings.statDefense,
  CharacterStatId.power => strings.statPower,
  CharacterStatId.moveSpeed => strings.statMoveSpeed,
  CharacterStatId.cooldownReduction => strings.statCooldownReduction,
  CharacterStatId.critChance => strings.statCritChance,
  CharacterStatId.physicalResistance => strings.statPhysicalResistance,
  CharacterStatId.fireResistance => strings.statFireResistance,
  CharacterStatId.iceResistance => strings.statIceResistance,
  CharacterStatId.waterResistance => strings.statWaterResistance,
  CharacterStatId.thunderResistance => strings.statThunderResistance,
  CharacterStatId.acidResistance => strings.statAcidResistance,
  CharacterStatId.darkResistance => strings.statDarkResistance,
  CharacterStatId.bleedResistance => strings.statBleedResistance,
  CharacterStatId.earthResistance => strings.statEarthResistance,
  CharacterStatId.holyResistance => strings.statHolyResistance,
};
