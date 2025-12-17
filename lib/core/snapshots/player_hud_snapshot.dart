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
    required this.endurance,
    required this.enduranceMax,
    required this.score,
    required this.coins,
  });

  /// Current health.
  final int hp;

  /// Maximum health.
  final int hpMax;

  /// Current mana (resource for spells).
  final double mana;

  /// Maximum mana.
  final double manaMax;

  /// Current endurance (resource for physical actions like dash/attacks).
  final double endurance;

  /// Maximum endurance.
  final double enduranceMax;

  /// Run score (placeholder for V0).
  final int score;

  /// Collected coins (placeholder for V0).
  final int coins;
}
