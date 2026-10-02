/// Run-local effects granted by world interactions. IDs also define stacking:
/// granting the same blessing again never changes its amount or start tick.
enum LevelBlessingId { regeneration }

/// Flat additions in hundredths of resource per second, after loadout bonuses.
/// A blessing lasts until its owning player/run is destroyed, including while
/// its source chunk is absent. These modest defaults are initial playtest tuning.
final class LevelBlessingDefinition {
  const LevelBlessingDefinition({
    required this.healthRegen100,
    required this.manaRegen100,
    required this.staminaRegen100,
  });

  final int healthRegen100;
  final int manaRegen100;
  final int staminaRegen100;

  static LevelBlessingDefinition get(LevelBlessingId id) => switch (id) {
    LevelBlessingId.regeneration => const LevelBlessingDefinition(
      healthRegen100: 5,
      manaRegen100: 20,
      staminaRegen100: 10,
    ),
  };
}

/// Immutable HUD projection; the grant tick supports pause-safe initial feedback.
final class LevelBlessingSnapshot {
  const LevelBlessingSnapshot({required this.id, required this.grantedAtTick});
  final LevelBlessingId id;
  final int grantedAtTick;
}
