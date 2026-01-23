/// Equipment slot category for weapons.
///
/// This determines which equipment slot(s) a weapon occupies,
/// not which ability slots it can power.
enum WeaponCategory {
  /// Main hand weapons (swords, axes, spears).
  primary,

  /// Off-hand equipment (shields, daggers, torches).
  offHand,

  /// Throwing weapons (knives, axes).
  projectile,
}
