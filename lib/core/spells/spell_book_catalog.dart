import '../stats/gear_stat_bonuses.dart';
import '../projectiles/projectile_item_id.dart';
import 'spell_book_def.dart';
import 'spell_book_id.dart';

/// Lookup table for spell books.
class SpellBookCatalog {
  const SpellBookCatalog();

  static const List<ProjectileItemId> _allProjectileSpells = <ProjectileItemId>[
    ProjectileItemId.iceBolt,
    ProjectileItemId.fireBolt,
    ProjectileItemId.thunderBolt,
  ];

  SpellBookDef get(SpellBookId id) {
    switch (id) {
      case SpellBookId.basicSpellBook:
        return const SpellBookDef(
          id: SpellBookId.basicSpellBook,
          projectileSpellIds: _allProjectileSpells,
          stats: GearStatBonuses(powerBonusBp: -100), // -1% Damage
        );
      case SpellBookId.solidSpellBook:
        return const SpellBookDef(
          id: SpellBookId.solidSpellBook,
          projectileSpellIds: _allProjectileSpells,
          stats: GearStatBonuses(powerBonusBp: 100), // +1% Damage
        );
      case SpellBookId.epicSpellBook:
        return const SpellBookDef(
          id: SpellBookId.epicSpellBook,
          projectileSpellIds: _allProjectileSpells,
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
