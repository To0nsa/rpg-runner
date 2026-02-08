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
    }
  }
}
