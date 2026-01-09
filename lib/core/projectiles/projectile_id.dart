/// Identifies a projectile type for catalog lookup and rendering.
///
/// Each ID maps to a [ProjectileArchetype] in [ProjectileCatalog] and
/// determines visual appearance in the renderer.
enum ProjectileId {
  /// Player's primary ranged attack. Fast, short-lived.
  iceBolt,

  /// Enemy ranged attack. Slower but longer range.
  lightningBolt,

  /// Physical arrow projectile (ballistic).
  arrow,

  /// Physical throwing axe projectile (ballistic).
  throwingAxe,
}
