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
    required this.score,
    required this.coins,
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

  /// Run score (placeholder for V0).
  final int score;

  /// Collected coins (placeholder for V0).
  final int coins;
}
