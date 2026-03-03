/// High-level equipment slots exposed by meta/loadout UI.
///
/// The values are stable and used by both persistence and picker routing.
enum GearSlot {
  /// Primary melee weapon slot.
  mainWeapon,

  /// Off-hand weapon slot (for example shields).
  offhandWeapon,

  /// Spellbook slot.
  spellBook,

  /// Accessory slot.
  accessory,
}
