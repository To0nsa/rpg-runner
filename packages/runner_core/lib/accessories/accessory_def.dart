import '../stats/gear_stat_bonuses.dart';
import '../weapons/reactive_proc.dart';
import 'accessory_id.dart';

/// Accessory equip location.
///
/// There is currently one accessory slot. Keeping this enum allows future
/// expansion (for example, ring/amulet split) without changing the model type.
enum AccessorySlot { trinket }

/// Immutable authored definition for an accessory item.
///
/// Accessories contribute aggregated stat bonuses and can optionally define
/// reactive procs (for example, low-health sustain triggers).
class AccessoryDef {
  const AccessoryDef({
    required this.id,
    this.slot = AccessorySlot.trinket,
    this.stats = const GearStatBonuses(),
    this.reactiveProcs = const <ReactiveProc>[],
  });

  /// Stable accessory key referenced by meta/inventory state.
  final AccessoryId id;

  /// Equip location this accessory occupies.
  final AccessorySlot slot;

  /// Additive stat contribution merged into resolved character stats.
  ///
  /// Values use [GearStatBonuses] units (`100 = 1%` for basis-point fields).
  final GearStatBonuses stats;

  /// Reactive proc definitions resolved from post-damage outcomes.
  final List<ReactiveProc> reactiveProcs;
}
