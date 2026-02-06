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
        displayName: 'CDR',
        localizationKey: 'gear.stat.cooldown_reduction',
      ),
      CharacterStatDescriptor(
        id: CharacterStatId.critChance,
        displayName: 'Crit Chance',
        localizationKey: 'gear.stat.crit_chance',
      ),
    ];

CharacterStatDescriptor characterStatDescriptor(CharacterStatId id) {
  for (final descriptor in kCharacterStatDescriptors) {
    if (descriptor.id == id) return descriptor;
  }
  throw ArgumentError('Missing descriptor for $id');
}
