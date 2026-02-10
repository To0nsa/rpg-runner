/// HUD-only player data extracted from Core.
///
/// Separated from entity snapshots so the UI can render player stats
/// (HP bars, cooldowns, etc.) without scanning all entities.
library;

import 'enums.dart';

class PlayerHudSnapshot {
  const PlayerHudSnapshot({
    required this.hp,
    required this.hpMax,
    required this.mana,
    required this.manaMax,
    required this.stamina,
    required this.staminaMax,
    required this.meleeSlotValid,
    required this.secondarySlotValid,
    required this.projectileSlotValid,
    required this.mobilitySlotValid,
    required this.bonusSlotValid,
    required this.jumpSlotValid,
    required this.canAffordJump,
    required this.canAffordDash,
    required this.canAffordMelee,
    required this.canAffordSecondary,
    required this.canAffordProjectile,
    required this.canAffordBonus,
    required this.cooldownTicksLeft,
    required this.cooldownTicksTotal,
    required this.meleeInputMode,
    required this.secondaryInputMode,
    required this.projectileInputMode,
    required this.projectileChargeEnabled,
    required this.projectileChargeHalfTicks,
    required this.projectileChargeFullTicks,
    required this.lastDamageTick,
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

  /// Whether the primary slot ability is valid for the current loadout.
  final bool meleeSlotValid;

  /// Whether the secondary slot ability is valid for the current loadout.
  final bool secondarySlotValid;

  /// Whether the projectile slot ability is valid for the current loadout.
  final bool projectileSlotValid;

  /// Whether the mobility slot ability is valid for the current loadout.
  final bool mobilitySlotValid;

  /// Whether the bonus slot ability is valid for the current loadout.
  final bool bonusSlotValid;

  /// Whether the jump slot ability is valid for the current loadout.
  final bool jumpSlotValid;

  /// Whether stamina is sufficient for jumping.
  final bool canAffordJump;

  /// Whether stamina is sufficient for dashing.
  final bool canAffordDash;

  /// Whether stamina is sufficient for melee.
  final bool canAffordMelee;

  /// Whether resources are sufficient for the equipped secondary/off-hand ability.
  final bool canAffordSecondary;

  /// Whether resources are sufficient for the equipped projectile ability.
  final bool canAffordProjectile;

  /// Whether resources are sufficient for the equipped bonus ability.
  final bool canAffordBonus;

  /// Remaining cooldown ticks for each CooldownGroup.
  final List<int> cooldownTicksLeft;

  /// Total cooldown ticks for each CooldownGroup.
  final List<int> cooldownTicksTotal;

  /// Input interaction mode for melee slot.
  final AbilityInputMode meleeInputMode;

  /// Input interaction mode for secondary slot.
  final AbilityInputMode secondaryInputMode;

  /// Input interaction mode for projectile slot.
  final AbilityInputMode projectileInputMode;

  /// Whether the projectile slot supports tiered charge while holding.
  final bool projectileChargeEnabled;

  /// Charge hold threshold for half tier (runtime ticks).
  final int projectileChargeHalfTicks;

  /// Charge hold threshold for full tier (runtime ticks).
  final int projectileChargeFullTicks;

  /// Tick when this player most recently took non-zero damage (-1 if never).
  final int lastDamageTick;

  /// Collected collectibles.
  final int collectibles;

  /// Score value earned from collectibles.
  final int collectibleScore;
}
