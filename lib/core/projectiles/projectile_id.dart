/// Identifies a projectile type for catalog lookup and rendering.
///
/// Each ID maps to a [ProjectileArchetype] in [ProjectileCatalog] and
/// determines visual appearance in the renderer.
enum ProjectileId {
  /// Player's primary ranged attack. Fast, short-lived.
  iceBolt,

  /// Enemy ranged attack. Slower but longer range.
  thunderBolt,

  /// Player's fire spell projectile. Medium speed and lifetime.
  fireBolt,

  /// Physical arrow projectile (ballistic).
  arrow,

  /// Physical throwing axe projectile (ballistic).
  throwingAxe,

  /// Physical throwing knife projectile (ballistic).
  throwingKnife,
}
