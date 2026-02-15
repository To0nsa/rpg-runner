import '../abilities/ability_def.dart' show AbilityKey;
import '../stats/gear_stat_bonuses.dart';
import '../projectiles/projectile_id.dart';
import 'spell_book_def.dart';
import 'spell_book_id.dart';

/// Lookup table for spell books.
class SpellBookCatalog {
  const SpellBookCatalog();

  static const List<ProjectileId> _basicProjectileSpells = <ProjectileId>[
    ProjectileId.fireBolt,
    ProjectileId.acidBolt,
    ProjectileId.darkBolt,
    ProjectileId.thunderBolt,
    ProjectileId.iceBolt,
  ];

  static const List<ProjectileId> _solidProjectileSpells = <ProjectileId>[
    ProjectileId.fireBolt,
    ProjectileId.iceBolt,
  ];

  static const List<ProjectileId> _allProjectileSpells = <ProjectileId>[
    ProjectileId.iceBolt,
    ProjectileId.fireBolt,
    ProjectileId.acidBolt,
    ProjectileId.darkBolt,
    ProjectileId.thunderBolt,
  ];

  static const List<AbilityKey> _basicSpellSlotAbilities = <AbilityKey>[
    'eloise.arcane_haste',
  ];

  static const List<AbilityKey> _solidSpellSlotAbilities = <AbilityKey>[
    'eloise.arcane_haste',
    'eloise.restore_health',
  ];

  static const List<AbilityKey> _allSpellSlotAbilities = <AbilityKey>[
    'eloise.arcane_haste',
    'eloise.restore_health',
    'eloise.restore_mana',
    'eloise.restore_stamina',
  ];

  SpellBookDef get(SpellBookId id) {
    switch (id) {
      case SpellBookId.basicSpellBook:
        return const SpellBookDef(
          id: SpellBookId.basicSpellBook,
          projectileSpellIds: _basicProjectileSpells,
          spellAbilityIds: _basicSpellSlotAbilities,
          stats: GearStatBonuses(powerBonusBp: -100), // -1% Damage
        );
      case SpellBookId.solidSpellBook:
        return const SpellBookDef(
          id: SpellBookId.solidSpellBook,
          projectileSpellIds: _solidProjectileSpells,
          spellAbilityIds: _solidSpellSlotAbilities,
          stats: GearStatBonuses(powerBonusBp: 100), // +1% Damage
        );
      case SpellBookId.epicSpellBook:
        return const SpellBookDef(
          id: SpellBookId.epicSpellBook,
          projectileSpellIds: _allProjectileSpells,
          spellAbilityIds: _allSpellSlotAbilities,
          stats: GearStatBonuses(powerBonusBp: 200), // +2% Damage
        );
    }
  }

  SpellBookDef? tryGet(SpellBookId id) {
    try {
      return get(id);
    } catch (_) {
      return null;
    }
  }
}
