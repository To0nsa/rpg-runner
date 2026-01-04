/// HUD-only data extracted from the Core.
///
/// Split from entity snapshots so the UI can render player stats without
/// scanning all entities every frame.
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
    required this.dashCooldownTicksLeft,
    required this.dashCooldownTicksTotal,
    required this.meleeCooldownTicksLeft,
    required this.meleeCooldownTicksTotal,
    required this.projectileCooldownTicksLeft,
    required this.projectileCooldownTicksTotal,
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

  /// Collected collectibles (placeholder for V0).
  final int collectibles;

  /// Score value earned from collectibles (not yet applied to run score).
  final int collectibleScore;
}
