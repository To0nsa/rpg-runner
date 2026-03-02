import 'accessory_def.dart';
import 'accessory_id.dart';
import '../stats/gear_stat_bonuses.dart';

/// Read-only authored accessory definitions.
///
/// This catalog uses an exhaustive enum switch so adding a new [AccessoryId]
/// forces a compile-time update here.
class AccessoryCatalog {
  const AccessoryCatalog();

  /// Returns the authored definition for [id].
  ///
  /// This API is intentionally non-nullable: every valid [AccessoryId] must
  /// resolve to a definition.
  AccessoryDef get(AccessoryId id) {
    switch (id) {
      case AccessoryId.speedBoots:
        return const AccessoryDef(
          id: AccessoryId.speedBoots,
          // 500 bp = +5% move speed.
          stats: GearStatBonuses(moveSpeedBonusBp: 500),
        );
      case AccessoryId.goldenRing:
        return const AccessoryDef(
          id: AccessoryId.goldenRing,
          // 200 bp = +2% max health.
          stats: GearStatBonuses(hpBonus100: 200),
        );
      case AccessoryId.teethNecklace:
        return const AccessoryDef(
          id: AccessoryId.teethNecklace,
          // 200 bp = +2% max stamina.
          stats: GearStatBonuses(staminaBonus100: 200),
        );
      case AccessoryId.diamondRing:
        return const AccessoryDef(
          id: AccessoryId.diamondRing,
          // 250 bp = +2.5% max mana.
          stats: GearStatBonuses(manaBonusBp: 250),
        );
      case AccessoryId.ironBoots:
        return const AccessoryDef(
          id: AccessoryId.ironBoots,
          // 700 bp = +7% defense.
          stats: GearStatBonuses(defenseBonusBp: 700),
        );
      case AccessoryId.oathBeads:
        return const AccessoryDef(
          id: AccessoryId.oathBeads,
          // 300 bp = +3% cooldown reduction.
          stats: GearStatBonuses(cooldownReductionBp: 300),
        );
      case AccessoryId.resilienceCape:
        return const AccessoryDef(
          id: AccessoryId.resilienceCape,
          // Counterpick resist package for status-heavy encounters.
          stats: GearStatBonuses(
            bleedResistanceBp: 1200,
            darkResistanceBp: 800,
          ),
        );
      case AccessoryId.strengthBelt:
        return const AccessoryDef(
          id: AccessoryId.strengthBelt,
          // Offense-forward pick with a small stamina comfort tax.
          stats: GearStatBonuses(globalPowerBonusBp: 500, staminaBonusBp: -100),
        );
    }
  }
}
