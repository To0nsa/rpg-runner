/// Identifies a projectile type for catalog lookup and rendering.
///
/// IDs include both player items and environmental projectiles. Player item
/// membership is defined by [playerEquippableProjectileIds].
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

  /// Player's water spell projectile. Medium speed and lifetime.
  waterBolt,

  /// Equippable thunder spell, also used by enemies.
  thunderBolt,

  /// Environmental trap projectile; never an equippable spell.
  poisonDart,
}

/// Explicit player spell catalog. Rendering may support additional projectiles.
const playerEquippableProjectileIds = <ProjectileId>[
  ProjectileId.iceBolt,
  ProjectileId.fireBolt,
  ProjectileId.acidBolt,
  ProjectileId.darkBolt,
  ProjectileId.earthBolt,
  ProjectileId.holyBolt,
  ProjectileId.waterBolt,
  ProjectileId.thunderBolt,
];
