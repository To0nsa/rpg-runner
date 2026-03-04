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
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            manaRegenBonusBp: 1200,
            globalCritChanceBonusBp: 1200,
            cooldownReductionBp: 800,
            staminaBonusBp: -1000,
            staminaRegenBonusBp: -500,
            healthRegenBonusBp: -800,
          ),
        );
      case SpellBookId.bastionCodex:
        return const SpellBookDef(
          id: SpellBookId.bastionCodex,
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            manaRegenBonusBp: 1200,
            globalCritChanceBonusBp: 1000,
            cooldownReductionBp: 800,
            staminaBonusBp: -800,
            staminaRegenBonusBp: -800,
            healthRegenBonusBp: -800,
          ),
        );
      case SpellBookId.emberGrimoire:
        return const SpellBookDef(
          id: SpellBookId.emberGrimoire,
          stats: GearStatBonuses(
            manaBonusBp: 1700,
            manaRegenBonusBp: 1200,
            globalCritChanceBonusBp: 1200,
            cooldownReductionBp: 800,
            staminaBonusBp: -1000,
            staminaRegenBonusBp: -800,
            healthRegenBonusBp: -500,
          ),
        );
      case SpellBookId.tideAlmanac:
        return const SpellBookDef(
          id: SpellBookId.tideAlmanac,
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            manaRegenBonusBp: 1000,
            globalCritChanceBonusBp: 1200,
            cooldownReductionBp: 800,
            staminaBonusBp: -1000,
            staminaRegenBonusBp: -800,
            healthRegenBonusBp: -500,
          ),
        );
      case SpellBookId.hexboundLexicon:
        return const SpellBookDef(
          id: SpellBookId.hexboundLexicon,
          stats: GearStatBonuses(
            manaBonusBp: 1600,
            manaRegenBonusBp: 1200,
            globalCritChanceBonusBp: 1200,
            cooldownReductionBp: 800,
            staminaBonusBp: -1000,
            staminaRegenBonusBp: -700,
            healthRegenBonusBp: -800,
          ),
        );
      case SpellBookId.galeFolio:
        return const SpellBookDef(
          id: SpellBookId.galeFolio,
          stats: GearStatBonuses(
            cooldownReductionBp: 800,
            manaBonusBp: 2000,
            manaRegenBonusBp: 1200,
            globalCritChanceBonusBp: 1000,
            staminaBonusBp: -1000,
            staminaRegenBonusBp: -800,
            healthRegenBonusBp: -800,
          ),
        );
      case SpellBookId.nullTestament:
        return const SpellBookDef(
          id: SpellBookId.nullTestament,
          stats: GearStatBonuses(
            manaBonusBp: 1800,
            manaRegenBonusBp: 1200,
            globalCritChanceBonusBp: 1200,
            cooldownReductionBp: 700,
            staminaBonusBp: -1000,
            staminaRegenBonusBp: -700,
            healthRegenBonusBp: -800,
          ),
        );
      case SpellBookId.crownOfFocus:
        return const SpellBookDef(
          id: SpellBookId.crownOfFocus,
          stats: GearStatBonuses(
            globalCritChanceBonusBp: 1200,
            manaBonusBp: 2000,
            manaRegenBonusBp: 1000,
            cooldownReductionBp: 800,
            staminaBonusBp: -1000,
            staminaRegenBonusBp: -800,
            healthRegenBonusBp: -500,
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
