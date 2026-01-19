/// Identifies a spell type for catalog lookup and casting.
///
/// Each ID maps to a [SpellDef] in [SpellCatalog] defining costs,
/// damage, and the associated projectile (if any).
enum SpellId {
  /// Player's primary ranged attack.
  iceBolt,

  /// Enemy ranged attack.
  thunderBolt,
}

