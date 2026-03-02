/// Canonical stat identifiers for the V1 character stat model.
enum CharacterStatId {
  health,
  mana,
  stamina,
  defense,
  power,
  moveSpeed,
  cooldownReduction,
  critChance,
  physicalResistance,
  fireResistance,
  iceResistance,
  waterResistance,
  thunderResistance,
  acidResistance,
  darkResistance,
  bleedResistance,
  earthResistance,
  holyResistance,
}

/// Stable metadata for stat display and future localization mapping.
class CharacterStatDescriptor {
  const CharacterStatDescriptor({
    required this.id,
    required this.displayName,
    required this.localizationKey,
  });

  final CharacterStatId id;
  final String displayName;
  final String localizationKey;
}

const List<CharacterStatDescriptor> kCharacterStatDescriptors =
    <CharacterStatDescriptor>[
      CharacterStatDescriptor(
        id: CharacterStatId.health,
        displayName: 'Health',
        localizationKey: 'gear.stat.health',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.mana,
        displayName: 'Mana',
        localizationKey: 'gear.stat.mana',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.stamina,
        displayName: 'Stamina',
        localizationKey: 'gear.stat.stamina',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.defense,
        displayName: 'Defense',
        localizationKey: 'gear.stat.defense',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.power,
        displayName: 'Power',
        localizationKey: 'gear.stat.power',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.moveSpeed,
        displayName: 'Move Speed',
        localizationKey: 'gear.stat.move_speed',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.cooldownReduction,
        displayName: 'Cooldown Reduction',
        localizationKey: 'gear.stat.cooldown_reduction',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.critChance,
        displayName: 'Crit Chance',
        localizationKey: 'gear.stat.crit_chance',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.physicalResistance,
        displayName: 'Physical Resist',
        localizationKey: 'gear.stat.physical_resistance',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.fireResistance,
        displayName: 'Fire Resist',
        localizationKey: 'gear.stat.fire_resistance',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.iceResistance,
        displayName: 'Ice Resist',
        localizationKey: 'gear.stat.ice_resistance',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.waterResistance,
        displayName: 'Water Resist',
        localizationKey: 'gear.stat.water_resistance',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.thunderResistance,
        displayName: 'Thunder Resist',
        localizationKey: 'gear.stat.thunder_resistance',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.acidResistance,
        displayName: 'Acid Resist',
        localizationKey: 'gear.stat.acid_resistance',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.darkResistance,
        displayName: 'Dark Resist',
        localizationKey: 'gear.stat.dark_resistance',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.bleedResistance,
        displayName: 'Bleed Resist',
        localizationKey: 'gear.stat.bleed_resistance',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.earthResistance,
        displayName: 'Earth Resist',
        localizationKey: 'gear.stat.earth_resistance',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.holyResistance,
        displayName: 'Holy Resist',
        localizationKey: 'gear.stat.holy_resistance',
      ),
    ];

CharacterStatDescriptor characterStatDescriptor(CharacterStatId id) {
  for (final descriptor in kCharacterStatDescriptors) {
    if (descriptor.id == id) return descriptor;
  }
  throw ArgumentError('Missing descriptor for $id');
}
