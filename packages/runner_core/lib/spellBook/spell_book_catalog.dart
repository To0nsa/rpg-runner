import '../stats/gear_stat_bonuses.dart';
import 'spell_book_def.dart';
import 'spell_book_id.dart';
import '../abilities/ability_def.dart';

/// Lookup table for spell books.
class SpellBookCatalog {
  const SpellBookCatalog();

  SpellBookDef get(SpellBookId id) {
    switch (id) {
      case SpellBookId.hunterFieldKit:
        return const SpellBookDef(
          id: SpellBookId.hunterFieldKit,
          weaponType: WeaponType.fieldKit,
          stats: GearStatBonuses(
            manaBonusBp: 1500,
            manaRegenBonusBp: 1000,
            globalCritChanceBonusBp: 500,
            staminaBonusBp: -500,
          ),
        );
      case SpellBookId.hunterLongtrailPack:
        return const SpellBookDef(
          id: SpellBookId.hunterLongtrailPack,
          weaponType: WeaponType.fieldKit,
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            manaRegenBonusBp: 1000,
            cooldownReductionBp: 500,
            healthRegenBonusBp: -500,
          ),
        );
      case SpellBookId.hunterMarksmanRoll:
        return const SpellBookDef(
          id: SpellBookId.hunterMarksmanRoll,
          weaponType: WeaponType.fieldKit,
          stats: GearStatBonuses(
            manaBonusBp: 1000,
            globalCritChanceBonusBp: 1000,
            cooldownReductionBp: 500,
            staminaRegenBonusBp: -500,
          ),
        );
      case SpellBookId.hunterQuickAccessSatchel:
        return const SpellBookDef(
          id: SpellBookId.hunterQuickAccessSatchel,
          weaponType: WeaponType.fieldKit,
          stats: GearStatBonuses(
            manaRegenBonusBp: 1000,
            globalCritChanceBonusBp: 500,
            cooldownReductionBp: 500,
            staminaBonusBp: -500,
          ),
        );
      case SpellBookId.hunterReserveBandolier:
        return const SpellBookDef(
          id: SpellBookId.hunterReserveBandolier,
          weaponType: WeaponType.fieldKit,
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            manaRegenBonusBp: 500,
            globalCritChanceBonusBp: 1000,
            staminaBonusBp: -1000,
          ),
        );
      case SpellBookId.hunterTrackerPouch:
        return const SpellBookDef(
          id: SpellBookId.hunterTrackerPouch,
          weaponType: WeaponType.fieldKit,
          stats: GearStatBonuses(
            manaBonusBp: 1000,
            manaRegenBonusBp: 500,
            globalCritChanceBonusBp: 1000,
            healthRegenBonusBp: -500,
          ),
        );
      case SpellBookId.hunterSurveyorCase:
        return const SpellBookDef(
          id: SpellBookId.hunterSurveyorCase,
          weaponType: WeaponType.fieldKit,
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            globalCritChanceBonusBp: 500,
            cooldownReductionBp: 500,
            staminaRegenBonusBp: -500,
          ),
        );
      case SpellBookId.hunterQuarryKit:
        return const SpellBookDef(
          id: SpellBookId.hunterQuarryKit,
          weaponType: WeaponType.fieldKit,
          stats: GearStatBonuses(
            manaRegenBonusBp: 500,
            globalCritChanceBonusBp: 1000,
            cooldownReductionBp: 500,
            staminaBonusBp: -1000,
          ),
        );
      case SpellBookId.apprenticePrimer:
        return const SpellBookDef(
          id: SpellBookId.apprenticePrimer,
          stats: GearStatBonuses(
            manaBonusBp: 1500,
            manaRegenBonusBp: 500,
            globalCritChanceBonusBp: 500,
            staminaBonusBp: -500,
          ),
        );
      case SpellBookId.bastionCodex:
        return const SpellBookDef(
          id: SpellBookId.bastionCodex,
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            manaRegenBonusBp: 1000,
            cooldownReductionBp: 500,
            healthRegenBonusBp: -500,
          ),
        );
      case SpellBookId.emberGrimoire:
        return const SpellBookDef(
          id: SpellBookId.emberGrimoire,
          stats: GearStatBonuses(
            manaBonusBp: 1000,
            globalCritChanceBonusBp: 1000,
            cooldownReductionBp: 500,
            staminaRegenBonusBp: -500,
          ),
        );
      case SpellBookId.tideAlmanac:
        return const SpellBookDef(
          id: SpellBookId.tideAlmanac,
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            manaRegenBonusBp: 500,
            cooldownReductionBp: 500,
            staminaBonusBp: -1000,
          ),
        );
      case SpellBookId.hexboundLexicon:
        return const SpellBookDef(
          id: SpellBookId.hexboundLexicon,
          stats: GearStatBonuses(
            manaBonusBp: 1000,
            manaRegenBonusBp: 1000,
            globalCritChanceBonusBp: 1000,
            healthRegenBonusBp: -500,
          ),
        );
      case SpellBookId.galeFolio:
        return const SpellBookDef(
          id: SpellBookId.galeFolio,
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            globalCritChanceBonusBp: 500,
            cooldownReductionBp: 500,
            staminaBonusBp: -500,
          ),
        );
      case SpellBookId.nullTestament:
        return const SpellBookDef(
          id: SpellBookId.nullTestament,
          stats: GearStatBonuses(
            manaBonusBp: 1500,
            manaRegenBonusBp: 1000,
            globalCritChanceBonusBp: 500,
            staminaRegenBonusBp: -500,
          ),
        );
      case SpellBookId.crownOfFocus:
        return const SpellBookDef(
          id: SpellBookId.crownOfFocus,
          stats: GearStatBonuses(
            manaBonusBp: 2000,
            globalCritChanceBonusBp: 1000,
            cooldownReductionBp: 500,
            staminaBonusBp: -1000,
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
