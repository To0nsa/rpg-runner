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
          // Tempo baseline with stamina comfort and durability tax.
          stats: GearStatBonuses(
            moveSpeedBonusBp: 1000,
            staminaBonusBp: 1000,
            healthBonusBp: -500,
          ),
        );
      case AccessoryId.goldenRing:
        return const AccessoryDef(
          id: AccessoryId.goldenRing,
          // General survivability floor with lower stamina comfort.
          stats: GearStatBonuses(
            healthBonusBp: 1000,
            defenseBonusBp: 1000,
            staminaBonusBp: -500,
          ),
        );
      case AccessoryId.teethNecklace:
        return const AccessoryDef(
          id: AccessoryId.teethNecklace,
          // Stamina sustain package with a small health tax.
          stats: GearStatBonuses(staminaBonusBp: 2000, healthBonusBp: -500),
        );
      case AccessoryId.diamondRing:
        return const AccessoryDef(
          id: AccessoryId.diamondRing,
          // Caster sustain package with a small stamina tax.
          stats: GearStatBonuses(manaBonusBp: 2000, staminaBonusBp: -500),
        );
      case AccessoryId.ironBoots:
        return const AccessoryDef(
          id: AccessoryId.ironBoots,
          // Mitigation anchor with offense gain and route-speed tax.
          stats: GearStatBonuses(
            defenseBonusBp: 1000,
            globalPowerBonusBp: 1000,
            moveSpeedBonusBp: -300,
          ),
        );
      case AccessoryId.oathBeads:
        return const AccessoryDef(
          id: AccessoryId.oathBeads,
          // Rotation consistency package with a small health tax.
          stats: GearStatBonuses(
            cooldownReductionBp: 1000,
            globalPowerBonusBp: 500,
            healthBonusBp: -500,
          ),
        );
      case AccessoryId.resilienceCape:
        return const AccessoryDef(
          id: AccessoryId.resilienceCape,
          // Counterpick resist package with a small health tax.
          stats: GearStatBonuses(
            bleedResistanceBp: 1200,
            darkResistanceBp: 800,
            healthBonusBp: -500,
          ),
        );
      case AccessoryId.strengthBelt:
        return const AccessoryDef(
          id: AccessoryId.strengthBelt,
          // Offense-forward pick with crit pressure and stamina tax.
          stats: GearStatBonuses(
            globalPowerBonusBp: 500,
            globalCritChanceBonusBp: 500,
            staminaBonusBp: -500,
          ),
        );
    }
  }
}
