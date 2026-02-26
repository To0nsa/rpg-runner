/// HUD-only player data extracted from Core.
///
/// Separated from entity snapshots so the UI can render player stats
/// (HP bars, cooldowns, etc.) without scanning all entities.
library;

import '../abilities/ability_def.dart';
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
    required this.spellSlotValid,
    required this.jumpSlotValid,
    required this.canAffordJump,
    required this.canAffordMobility,
    required this.canAffordMelee,
    required this.canAffordSecondary,
    required this.canAffordProjectile,
    required this.canAffordSpell,
    required this.cooldownTicksLeft,
    required this.cooldownTicksTotal,
    required this.meleeInputMode,
    required this.secondaryInputMode,
    required this.projectileInputMode,
    required this.mobilityInputMode,
    required this.chargeEnabled,
    required this.chargeHalfTicks,
    required this.chargeFullTicks,
    required this.chargeActive,
    required this.chargeTicks,
    required this.chargeTier,
    required this.lastDamageTick,
    required this.collectibles,
    required this.collectibleScore,
    required this.abilityPrimaryId,
    required this.abilitySecondaryId,
    required this.abilityProjectileId,
    required this.abilityMobilityId,
    required this.abilitySpellId,
    required this.abilityJumpId,
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

  /// Whether the spell slot ability is valid for the current loadout.
  final bool spellSlotValid;

  /// Whether the jump slot ability is valid for the current loadout.
  final bool jumpSlotValid;

  /// Whether stamina is sufficient for jumping.
  final bool canAffordJump;

  /// Whether stamina is sufficient for the equipped mobility ability.
  final bool canAffordMobility;

  /// Whether stamina is sufficient for melee.
  final bool canAffordMelee;

  /// Whether resources are sufficient for the equipped secondary/off-hand ability.
  final bool canAffordSecondary;

  /// Whether resources are sufficient for the equipped projectile ability.
  final bool canAffordProjectile;

  /// Whether resources are sufficient for the equipped spell slot ability.
  final bool canAffordSpell;

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

  /// Input interaction mode for mobility slot.
  final AbilityInputMode mobilityInputMode;

  /// Whether at least one equipped slot supports tiered charge.
  final bool chargeEnabled;

  /// Charge hold threshold for half tier (runtime ticks).
  final int chargeHalfTicks;

  /// Charge hold threshold for full tier (runtime ticks).
  final int chargeFullTicks;

  /// Whether a charge hold is currently active in Core state.
  final bool chargeActive;

  /// Current hold duration in runtime ticks for the active charge slot.
  final int chargeTicks;

  /// Current charge tier bucket from Core (0/1/2).
  final int chargeTier;

  /// Tick when this player most recently took non-zero damage (-1 if never).
  final int lastDamageTick;

  /// Collected collectibles.
  final int collectibles;

  /// Score value earned from collectibles.
  final int collectibleScore;

  /// Equipped primary-slot ability id for current player loadout.
  final AbilityKey abilityPrimaryId;

  /// Equipped secondary-slot ability id for current player loadout.
  final AbilityKey abilitySecondaryId;

  /// Equipped projectile-slot ability id for current player loadout.
  final AbilityKey abilityProjectileId;

  /// Equipped mobility-slot ability id for current player loadout.
  final AbilityKey abilityMobilityId;

  /// Equipped spell-slot ability id for current player loadout.
  final AbilityKey abilitySpellId;

  /// Equipped jump-slot ability id for current player loadout.
  final AbilityKey abilityJumpId;
}
