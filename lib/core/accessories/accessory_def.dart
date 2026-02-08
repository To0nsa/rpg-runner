import '../weapons/weapon_proc.dart';
import '../stats/gear_stat_bonuses.dart';
import 'accessory_id.dart';

/// Single equip slot for accessories (v0).
enum AccessorySlot { trinket }

/// Optional taxonomy for filtering and UI grouping.
enum AccessoryTag { offense, defense, utility, magic }

/// Backward-compatible alias used by accessory definitions.
///
/// `AccessoryStats` now resolves to the unified [GearStatBonuses] payload.
typedef AccessoryStats = GearStatBonuses;

/// Data definition for accessories (global inventory items).
class AccessoryDef {
  const AccessoryDef({
    required this.id,
    this.slot = AccessorySlot.trinket,
    this.tags = const <AccessoryTag>{},
    this.stats = const AccessoryStats(),
    this.procs = const <WeaponProc>[],
  });

  final AccessoryId id;
  final AccessorySlot slot;
  final Set<AccessoryTag> tags;
  final AccessoryStats stats;

  /// Optional procs applied on hit (future integration with payload builder).
  final List<WeaponProc> procs;
}
