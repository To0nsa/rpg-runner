import 'ability_def.dart';

/// Static registry of all available abilities.
/// In a real production app, this might be loaded from JSON/YAML.
class AbilityCatalog {
  static const Map<AbilityKey, AbilityDef> abilities = {
    // ------------------------------------------------------------------------
    // FALLBACKS
    // ------------------------------------------------------------------------
    'common.unarmed_strike': AbilityDef(
      id: 'common.unarmed_strike',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.primary},
      targetingModel: TargetingModel.directional,
      hitDelivery: MeleeHitDelivery(
        sizeX: 1.0, sizeY: 1.0, offsetX: 0.5, offsetY: 0.0, 
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 4, activeTicks: 2, recoveryTicks: 4,
      staminaCost: 0, manaCost: 0,
      cooldownTicks: 0,
      interruptPriority: InterruptPriority.combat,
      animKey: 'punch',
      tags: {AbilityTag.melee, AbilityTag.light},
    ),

    // ------------------------------------------------------------------------
    // ELOISE: PRIMARY (Sword)
    // ------------------------------------------------------------------------
    'eloise.sword_strike': AbilityDef(
      id: 'eloise.sword_strike',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.primary},
      targetingModel: TargetingModel.directional,
      hitDelivery: MeleeHitDelivery(
        sizeX: 1.5, sizeY: 1.5, offsetX: 1.0, offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      // 6 frames @ 0.06s = 0.36s -> ~22 ticks
      // Tuning: Active 0.10s (6 ticks)
      windupTicks: 8, activeTicks: 6, recoveryTicks: 8,
      staminaCost: 500, manaCost: 0, // 5.0 stamina
      cooldownTicks: 18, // 0.30s
      interruptPriority: InterruptPriority.combat,
      animKey: 'strike',
      tags: {AbilityTag.melee, AbilityTag.physical},
    ),

    'eloise.sword_parry': AbilityDef(
      id: 'eloise.sword_parry',
      category: AbilityCategory.defense,
      allowedSlots: {AbilitySlot.primary},
      targetingModel: TargetingModel.none,
      hitDelivery: SelfHitDelivery(),
      // 6 frames @ 0.06s = 0.36s -> ~22 ticks
      windupTicks: 4, activeTicks: 12, recoveryTicks: 6,
      staminaCost: 500, manaCost: 0,
      cooldownTicks: 30, // 0.50s (est)
      interruptPriority: InterruptPriority.combat,
      animKey: 'parry',
      tags: {AbilityTag.melee, AbilityTag.physical, AbilityTag.opener},
    ),

    // ------------------------------------------------------------------------
    // ELOISE: SECONDARY (Shield)
    // ------------------------------------------------------------------------
    'eloise.shield_bash': AbilityDef(
      id: 'eloise.shield_bash',
      category: AbilityCategory.defense,
      allowedSlots: {AbilitySlot.secondary},
      targetingModel: TargetingModel.directional,
      hitDelivery: MeleeHitDelivery(
        sizeX: 1.2, sizeY: 1.2, offsetX: 0.8, offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 8, activeTicks: 4, recoveryTicks: 10,
      staminaCost: 1200, manaCost: 0,
      cooldownTicks: 24,
      interruptPriority: InterruptPriority.combat,
      animKey: 'shield_bash',
      tags: {AbilityTag.melee, AbilityTag.physical, AbilityTag.heavy},
    ),

    'eloise.shield_block': AbilityDef(
      id: 'eloise.shield_block',
      category: AbilityCategory.defense,
      allowedSlots: {AbilitySlot.secondary},
      targetingModel: TargetingModel.none,
      hitDelivery: SelfHitDelivery(),
      windupTicks: 3, activeTicks: 0, recoveryTicks: 6,
      staminaCost: 500, manaCost: 0,
      cooldownTicks: 12,
      interruptPriority: InterruptPriority.combat,
      animKey: 'shield_block',
      tags: {AbilityTag.buff, AbilityTag.physical},
    ),

    // ------------------------------------------------------------------------
    // ELOISE: PROJECTILE
    // ------------------------------------------------------------------------
    'eloise.throwing_knife': AbilityDef(
      id: 'eloise.throwing_knife',
      category: AbilityCategory.ranged,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimed,
      hitDelivery: ProjectileHitDelivery(
        projectileId: 'knife',
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      // Cooldown 0.30s -> 18 ticks
      // Cost 5.0 -> 500
      windupTicks: 4, activeTicks: 2, recoveryTicks: 6,
      staminaCost: 500, manaCost: 0,
      cooldownTicks: 18,
      interruptPriority: InterruptPriority.combat,
      animKey: 'throw',
      tags: {AbilityTag.projectile, AbilityTag.physical},
    ),

    'eloise.ice_bolt': AbilityDef(
      id: 'eloise.ice_bolt',
      category: AbilityCategory.magic,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimed,
      hitDelivery: ProjectileHitDelivery(
        projectileId: 'ice_bolt',
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      // Cost 10.0 -> 1000
      windupTicks: 6, activeTicks: 2, recoveryTicks: 8,
      staminaCost: 0, manaCost: 1000,
      cooldownTicks: 24,
      interruptPriority: InterruptPriority.combat,
      animKey: 'cast',
      tags: {AbilityTag.projectile, AbilityTag.ice},
    ),

    'eloise.fire_bolt': AbilityDef(
      id: 'eloise.fire_bolt',
      category: AbilityCategory.magic,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimed,
      hitDelivery: ProjectileHitDelivery(
        projectileId: 'fire_bolt',
      ),
      // Cost 12.0 -> 1200
      windupTicks: 6, activeTicks: 2, recoveryTicks: 8,
      staminaCost: 0, manaCost: 1200,
      cooldownTicks: 30,
      interruptPriority: InterruptPriority.combat,
      animKey: 'cast',
      tags: {AbilityTag.projectile, AbilityTag.fire},
    ),

    'eloise.thunder_bolt': AbilityDef(
      id: 'eloise.thunder_bolt',
      category: AbilityCategory.magic,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimed,
      hitDelivery: ProjectileHitDelivery(
        projectileId: 'thunder_bolt',
      ),
      // Cost 10.0 -> 1000
      windupTicks: 6, activeTicks: 2, recoveryTicks: 8,
      staminaCost: 0, manaCost: 1000,
      cooldownTicks: 36,
      interruptPriority: InterruptPriority.combat,
      animKey: 'cast',
      tags: {AbilityTag.projectile, AbilityTag.lightning},
    ),

    // ------------------------------------------------------------------------
    // ELOISE: MOBILITY
    // ------------------------------------------------------------------------
    'eloise.dash': AbilityDef(
      id: 'eloise.dash',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.mobility},
      targetingModel: TargetingModel.directional,
      hitDelivery: SelfHitDelivery(),
      // 4 frames @ 0.05s = 0.20s -> 12 ticks
      // Cooldown 2.0s -> 120 ticks
      // Cost 2.0 -> 200
      windupTicks: 0, activeTicks: 12, recoveryTicks: 0,
      staminaCost: 200, manaCost: 0,
      cooldownTicks: 120,
      interruptPriority: InterruptPriority.mobility,
      canBeInterruptedBy: {}, 
      animKey: 'dash',
      tags: {AbilityTag.light, AbilityTag.buff},
    ),

    'eloise.roll': AbilityDef(
      id: 'eloise.roll',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.mobility},
      targetingModel: TargetingModel.directional,
      hitDelivery: SelfHitDelivery(),
      // 10 frames @ 0.05s = 0.50s -> 30 ticks
      // Cost ~200? (Same as dash for now?)
      windupTicks: 3, activeTicks: 24, recoveryTicks: 3,
      staminaCost: 200, manaCost: 0,
      cooldownTicks: 120,
      interruptPriority: InterruptPriority.mobility,
      animKey: 'roll',
      tags: {AbilityTag.light, AbilityTag.buff},
    ),
  };
}
