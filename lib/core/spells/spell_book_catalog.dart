import '../abilities/ability_def.dart' show AbilityKey;
import '../stats/gear_stat_bonuses.dart';
import '../projectiles/projectile_item_id.dart';
import 'spell_book_def.dart';
import 'spell_book_id.dart';

/// Lookup table for spell books.
class SpellBookCatalog {
  const SpellBookCatalog();

  static const List<ProjectileItemId> _basicProjectileSpells =
      <ProjectileItemId>[ProjectileItemId.fireBolt];

  static const List<ProjectileItemId> _solidProjectileSpells =
      <ProjectileItemId>[ProjectileItemId.fireBolt, ProjectileItemId.iceBolt];

  static const List<ProjectileItemId> _allProjectileSpells = <ProjectileItemId>[
    ProjectileItemId.iceBolt,
    ProjectileItemId.fireBolt,
    ProjectileItemId.thunderBolt,
  ];

  static const List<AbilityKey> _basicBonusSpells = <AbilityKey>[
    'eloise.arcane_haste',
  ];

  static const List<AbilityKey> _solidBonusSpells = <AbilityKey>[
    'eloise.arcane_haste',
    'eloise.restore_health',
  ];

  static const List<AbilityKey> _allBonusSpells = <AbilityKey>[
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
          bonusAbilityIds: _basicBonusSpells,
          stats: GearStatBonuses(powerBonusBp: -100), // -1% Damage
        );
      case SpellBookId.solidSpellBook:
        return const SpellBookDef(
          id: SpellBookId.solidSpellBook,
          projectileSpellIds: _solidProjectileSpells,
          bonusAbilityIds: _solidBonusSpells,
          stats: GearStatBonuses(powerBonusBp: 100), // +1% Damage
        );
      case SpellBookId.epicSpellBook:
        return const SpellBookDef(
          id: SpellBookId.epicSpellBook,
          projectileSpellIds: _allProjectileSpells,
          bonusAbilityIds: _allBonusSpells,
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
