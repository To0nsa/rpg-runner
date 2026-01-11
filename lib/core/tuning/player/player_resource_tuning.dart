/// Resource tuning (author in seconds, applied per fixed tick).
/// This includes health, mana, stamina, and their regeneration rates.
class ResourceTuning {
  const ResourceTuning({
    this.playerHpMax = 100,
    this.playerHpRegenPerSecond = 0.5,
    this.playerManaMax = 100,
    this.playerManaRegenPerSecond = 2.0,
    this.playerStaminaMax = 100,
    this.playerStaminaRegenPerSecond = 1.0,
    this.jumpStaminaCost = 2,
    this.dashStaminaCost = 2,
  });

  /// Maximum health points.
  final double playerHpMax;

  /// HP regenerated per second.
  final double playerHpRegenPerSecond;

  /// Maximum mana points.
  final double playerManaMax;

  /// Mana regenerated per second.
  final double playerManaRegenPerSecond;

  /// Maximum stamina points.
  final double playerStaminaMax;

  /// Stamina regenerated per second.
  final double playerStaminaRegenPerSecond;

  /// Stamina spent per jump.
  final double jumpStaminaCost;

  /// Stamina spent per dash.
  final double dashStaminaCost;
}
