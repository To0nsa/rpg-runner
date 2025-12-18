/// Resource tuning for V0 (author in seconds, applied per fixed tick).
///
/// Values are based on the C++ reference (`tools/output/c++implementation.txt`).
class V0ResourceTuning {
  const V0ResourceTuning({
    this.playerHpMax = 100,
    this.playerHpRegenPerSecond = 1,
    this.playerManaMax = 100,
    this.playerManaRegenPerSecond = 3,
    this.playerStaminaMax = 100,
    this.playerStaminaRegenPerSecond = 1,
    this.playerHpStart,
    this.playerManaStart,
    this.playerStaminaStart,
    this.jumpStaminaCost = 2,
    this.dashStaminaCost = 2,
  });

  final double playerHpMax;
  final double playerHpRegenPerSecond;

  final double playerManaMax;
  final double playerManaRegenPerSecond;

  final double playerStaminaMax;
  final double playerStaminaRegenPerSecond;

  /// Optional starting values. When null, the corresponding `*Max` is used.
  final double? playerHpStart;
  final double? playerManaStart;
  final double? playerStaminaStart;

  /// Action costs (C++ reference: 2 stamina each for jump + dash).
  final double jumpStaminaCost;
  final double dashStaminaCost;
}
