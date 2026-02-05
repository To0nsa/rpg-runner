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
          displayName: 'Speed Boots',
          description: 'Light footwear that boosts movement speed.',
          tags: {AccessoryTag.utility},
          stats: AccessoryStats(moveSpeedBonusBp: 500), // +5% Move Speed
        );
      case AccessoryId.goldenRing:
        return const AccessoryDef(
          id: AccessoryId.goldenRing,
          displayName: 'Golden Ring',
          description: 'A fortified ring that improves constitution.',
          tags: {AccessoryTag.defense},
          stats: AccessoryStats(hpBonus100: 200), // +2% HP
        );
      case AccessoryId.teethNecklace:
        return const AccessoryDef(
          id: AccessoryId.teethNecklace,
          displayName: 'Teeth Necklace',
          description: 'A savage charm that hardens combat endurance.',
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
