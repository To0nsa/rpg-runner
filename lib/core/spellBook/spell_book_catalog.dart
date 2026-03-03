import '../stats/gear_stat_bonuses.dart';
import 'spell_book_def.dart';
import 'spell_book_id.dart';

/// Lookup table for spell books.
class SpellBookCatalog {
  const SpellBookCatalog();

  SpellBookDef get(SpellBookId id) {
    switch (id) {
      case SpellBookId.apprenticePrimer:
        return const SpellBookDef(
          id: SpellBookId.apprenticePrimer,
          stats: GearStatBonuses(manaBonusBp: 1000, globalCritChanceBonusBp: 500),
        );
      case SpellBookId.bastionCodex:
        return const SpellBookDef(
          id: SpellBookId.bastionCodex,
          stats: GearStatBonuses(
            manaBonusBp: 1500,
            manaRegenBonusBp: 500,
            cooldownReductionBp: 500,
            healthRegenBonusBp: -500,
          ),
        );
      case SpellBookId.emberGrimoire:
        return const SpellBookDef(
          id: SpellBookId.emberGrimoire,
          stats: GearStatBonuses(
            manaRegenBonusBp: 1200,
            cooldownReductionBp: 800,
            staminaBonusBp: -500,
          ),
        );
      case SpellBookId.tideAlmanac:
        return const SpellBookDef(
          id: SpellBookId.tideAlmanac,
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            cooldownReductionBp: 500,
            staminaRegenBonusBp: -500,
          ),
        );
      case SpellBookId.hexboundLexicon:
        return const SpellBookDef(
          id: SpellBookId.hexboundLexicon,
          stats: GearStatBonuses(
            globalCritChanceBonusBp: 1200,
            manaRegenBonusBp: 500,
            healthRegenBonusBp: -500,
          ),
        );
      case SpellBookId.galeFolio:
        return const SpellBookDef(
          id: SpellBookId.galeFolio,
          stats: GearStatBonuses(
            cooldownReductionBp: 800,
            manaBonusBp: 1000,
            staminaBonusBp: -1000,
          ),
        );
      case SpellBookId.nullTestament:
        return const SpellBookDef(
          id: SpellBookId.nullTestament,
          stats: GearStatBonuses(
            manaRegenBonusBp: 1000,
            globalCritChanceBonusBp: 500,
            healthRegenBonusBp: -500,
          ),
        );
      case SpellBookId.crownOfFocus:
        return const SpellBookDef(
          id: SpellBookId.crownOfFocus,
          stats: GearStatBonuses(
            globalCritChanceBonusBp: 1000,
            manaBonusBp: 1500,
            staminaRegenBonusBp: -800,
          ),
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
