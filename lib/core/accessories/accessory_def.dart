import '../stats/gear_stat_bonuses.dart';
import 'accessory_id.dart';

/// Accessory equip location.
///
/// There is currently one accessory slot. Keeping this enum allows future
/// expansion (for example, ring/amulet split) without changing the model type.
enum AccessorySlot { trinket }

/// Immutable authored definition for an accessory item.
///
/// Accessories currently contribute only aggregated stat bonuses. Combat proc
/// behavior is intentionally modeled elsewhere and is not part of this payload.
class AccessoryDef {
  const AccessoryDef({
    required this.id,
    this.slot = AccessorySlot.trinket,
    this.stats = const GearStatBonuses(),
  });

  /// Stable accessory key referenced by meta/inventory state.
  final AccessoryId id;

  /// Equip location this accessory occupies.
  final AccessorySlot slot;

  /// Additive stat contribution merged into resolved character stats.
  ///
  /// Values use [GearStatBonuses] units (`100 = 1%` for basis-point fields).
  final GearStatBonuses stats;
}
