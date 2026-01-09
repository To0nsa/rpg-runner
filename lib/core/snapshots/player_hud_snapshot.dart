/// HUD-only player data extracted from Core.
///
/// Separated from entity snapshots so the UI can render player stats
/// (HP bars, cooldowns, etc.) without scanning all entities.
class PlayerHudSnapshot {
  const PlayerHudSnapshot({
    required this.hp,
    required this.hpMax,
    required this.mana,
    required this.manaMax,
    required this.stamina,
    required this.staminaMax,
    required this.canAffordJump,
    required this.canAffordDash,
    required this.canAffordMelee,
    required this.canAffordProjectile,
    required this.canAffordRangedWeapon,
    required this.dashCooldownTicksLeft,
    required this.dashCooldownTicksTotal,
    required this.meleeCooldownTicksLeft,
    required this.meleeCooldownTicksTotal,
    required this.projectileCooldownTicksLeft,
    required this.projectileCooldownTicksTotal,
    required this.rangedWeaponCooldownTicksLeft,
    required this.rangedWeaponCooldownTicksTotal,
    required this.rangedAmmo,
    required this.collectibles,
    required this.collectibleScore,
  });

  /// Current health.
  final double hp;

  /// Maximum health.
  final double hpMax;

  /// Current mana (resource for spells).
  final double mana;

  /// Maximum mana.
  final double manaMax;

  /// Current stamina (resource for physical actions like jump/dash).
  final double stamina;

  /// Maximum stamina.
  final double staminaMax;

  /// Whether stamina is sufficient for jumping.
  final bool canAffordJump;

  /// Whether stamina is sufficient for dashing.
  final bool canAffordDash;

  /// Whether stamina is sufficient for melee.
  final bool canAffordMelee;

  /// Whether mana is sufficient for projectile casting.
  final bool canAffordProjectile;

  /// Whether stamina + ammo are sufficient for the equipped ranged weapon.
  final bool canAffordRangedWeapon;

  /// Remaining dash cooldown ticks.
  final int dashCooldownTicksLeft;

  /// Total dash cooldown ticks.
  final int dashCooldownTicksTotal;

  /// Remaining melee cooldown ticks.
  final int meleeCooldownTicksLeft;

  /// Total melee cooldown ticks.
  final int meleeCooldownTicksTotal;

  /// Remaining projectile cooldown ticks.
  final int projectileCooldownTicksLeft;

  /// Total projectile cooldown ticks.
  final int projectileCooldownTicksTotal;

  /// Remaining ranged weapon cooldown ticks.
  final int rangedWeaponCooldownTicksLeft;

  /// Total ranged weapon cooldown ticks.
  final int rangedWeaponCooldownTicksTotal;

  /// Ammo count for the equipped ranged weapon's ammo type.
  final int rangedAmmo;

  /// Collected collectibles.
  final int collectibles;

  /// Score value earned from collectibles.
  final int collectibleScore;
}
