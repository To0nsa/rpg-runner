import '../weapons/weapon_proc.dart';
import 'accessory_id.dart';

/// Single equip slot for accessories (v0).
enum AccessorySlot { trinket }

/// Optional taxonomy for filtering and UI grouping.
enum AccessoryTag { offense, defense, utility, magic }

/// Accessory stat modifiers (future-facing; not yet wired into Core systems).
class AccessoryStats {
  const AccessoryStats({
    this.hpBonus100 = 0,
    this.manaBonus100 = 0,
    this.staminaBonus100 = 0,
    this.moveSpeedBonusBp = 0,
    this.cooldownReductionBp = 0,
  });

  /// Fixed-point: 100 = 1.0
  final int hpBonus100;
  final int manaBonus100;
  final int staminaBonus100;

  /// Basis points: 100 = 1%
  final int moveSpeedBonusBp;
  final int cooldownReductionBp;
}

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
