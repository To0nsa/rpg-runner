import 'accessory_def.dart';
import 'accessory_id.dart';

/// Lookup table for accessories.
class AccessoryCatalog {
  const AccessoryCatalog();

  AccessoryDef get(AccessoryId id) {
    switch (id) {
      case AccessoryId.speedBoots:
        return const AccessoryDef(
          id: AccessoryId.speedBoots,
          tags: {AccessoryTag.utility},
          stats: AccessoryStats(moveSpeedBonusBp: 500), // +5% Move Speed
        );
      case AccessoryId.goldenRing:
        return const AccessoryDef(
          id: AccessoryId.goldenRing,
          tags: {AccessoryTag.defense},
          stats: AccessoryStats(hpBonus100: 200), // +2% HP
        );
      case AccessoryId.teethNecklace:
        return const AccessoryDef(
          id: AccessoryId.teethNecklace,
          tags: {AccessoryTag.offense},
          stats: AccessoryStats(staminaBonus100: 200), // +2% Stamina
        );
    }
  }

  AccessoryDef? tryGet(AccessoryId id) {
    try {
      return get(id);
    } catch (_) {
      return null;
    }
  }
}
