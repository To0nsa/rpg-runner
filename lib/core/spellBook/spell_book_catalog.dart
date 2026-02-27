import '../stats/gear_stat_bonuses.dart';
import 'spell_book_def.dart';
import 'spell_book_id.dart';

/// Lookup table for spell books.
class SpellBookCatalog {
  const SpellBookCatalog();

  SpellBookDef get(SpellBookId id) {
    switch (id) {
      case SpellBookId.basicSpellBook:
        return const SpellBookDef(
          id: SpellBookId.basicSpellBook,
          stats: GearStatBonuses(powerBonusBp: -100), // -1% Damage
        );
      case SpellBookId.solidSpellBook:
        return const SpellBookDef(
          id: SpellBookId.solidSpellBook,
          stats: GearStatBonuses(powerBonusBp: 100), // +1% Damage
        );
      case SpellBookId.epicSpellBook:
        return const SpellBookDef(
          id: SpellBookId.epicSpellBook,
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
