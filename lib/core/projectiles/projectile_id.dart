/// Identifies a projectile type for catalog lookup and rendering.
///
/// Each ID maps to a projectile item entry and determines visual appearance
/// in the renderer.
enum ProjectileId {
  /// Sentinel value for uninitialized/placeholder projectile slots.
  unknown,

  /// Player's primary ranged strike. Fast, short-lived.
  iceBolt,

  /// Player's fire spell projectile. Medium speed and lifetime.
  fireBolt,

  /// Player's acid spell projectile. Medium speed and lifetime.
  acidBolt,

  /// Player's dark spell projectile. Medium speed and short lifetime.
  darkBolt,

  /// Player's earth spell projectile. Medium speed and lifetime.
  earthBolt,

  /// Player's holy spell projectile. Medium speed and lifetime.
  holyBolt,

  /// Enemy ranged strike. Slower but longer range.
  thunderBolt,

  /// Physical throwing axe projectile (ballistic).
  throwingAxe,

  /// Physical throwing knife projectile (ballistic).
  throwingKnife,
}
