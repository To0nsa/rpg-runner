import '../combat/damage_type.dart';
import '../projectiles/projectile_id.dart';
import '../snapshots/enums.dart';
import 'ability_def.dart';

/// Static registry of all available abilities.
/// In a real production app, this might be loaded from JSON/YAML.
class AbilityCatalog {
  const AbilityCatalog();

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
      animKey: AnimKey.punch,
      tags: {AbilityTag.melee, AbilityTag.light},
      baseDamage: 1500, // Fallback melee damage
    ),
    'common.enemy_strike': AbilityDef(
      id: 'common.enemy_strike',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.primary},
      targetingModel: TargetingModel.directional,
      hitDelivery: MeleeHitDelivery(
        sizeX: 1.0, sizeY: 1.0, offsetX: 0.5, offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 8, activeTicks: 4, recoveryTicks: 24,
      staminaCost: 0, manaCost: 0,
      cooldownTicks: 0,
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.strike,
      tags: {AbilityTag.melee, AbilityTag.physical},
      baseDamage: 0,
    ),
    'common.enemy_cast': AbilityDef(
      id: 'common.enemy_cast',
      category: AbilityCategory.magic,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimed,
      hitDelivery: ProjectileHitDelivery(
        projectileId: ProjectileId.thunderBolt,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 6, activeTicks: 2, recoveryTicks: 12,
      staminaCost: 0, manaCost: 0,
      cooldownTicks: 0,
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.cast,
      tags: {AbilityTag.projectile},
      requiredWeaponTypes: {WeaponType.projectileSpell},
      baseDamage: 500, // Thunder bolt legacy damage 5.0
      baseDamageType: DamageType.physical,
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
      animKey: AnimKey.strike,
      tags: {AbilityTag.melee, AbilityTag.physical},
      requiredTags: {AbilityTag.melee, AbilityTag.physical},
      requiredWeaponTypes: {WeaponType.oneHandedSword},
      baseDamage: 1500, // PlayerTuning meleeDamage 15.0
    ),

    'eloise.sword_parry': AbilityDef(
      id: 'eloise.sword_parry',
      category: AbilityCategory.defense,
      allowedSlots: {AbilitySlot.primary},
      targetingModel: TargetingModel.none,
      hitDelivery: SelfHitDelivery(),
      // 6 frames @ 0.06s = 0.36s -> ~22 ticks
      windupTicks: 4, activeTicks: 14, recoveryTicks: 4,
      staminaCost: 700, manaCost: 0,
      cooldownTicks: 30, // 0.50s
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.parry,
      tags: {AbilityTag.melee, AbilityTag.physical, AbilityTag.opener},
      requiredTags: {AbilityTag.melee, AbilityTag.physical},
      requiredWeaponTypes: {WeaponType.oneHandedSword},
      baseDamage: 0,
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
      cooldownTicks: 15, // 0.25s @ 60Hz (matches legacy cast cooldown)
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.shieldBash,
      tags: {AbilityTag.melee, AbilityTag.physical, AbilityTag.heavy},
      requiredTags: {AbilityTag.buff, AbilityTag.physical},
      requiredWeaponTypes: {WeaponType.shield},
      baseDamage: 1500, // Assuming standardized melee damage
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
      animKey: AnimKey.shieldBlock,
      tags: {AbilityTag.buff, AbilityTag.physical},
      requiredTags: {AbilityTag.buff},
      requiredWeaponTypes: {WeaponType.shield},
      baseDamage: 0,
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
        projectileId: ProjectileId.throwingKnife,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      // Cooldown 0.30s -> 18 ticks
      // Cost 5.0 -> 500
      windupTicks: 4, activeTicks: 2, recoveryTicks: 6,
      staminaCost: 500, manaCost: 0,
      cooldownTicks: 18,
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.throwItem,
      tags: {AbilityTag.projectile, AbilityTag.physical},
      requiredTags: {AbilityTag.projectile},
      requiredWeaponTypes: {WeaponType.throwingWeapon},
      baseDamage: 1000, // RangedWeaponCatalog.throwingKnife legacyDamage 10.0
    ),

    'eloise.ice_bolt': AbilityDef(
      id: 'eloise.ice_bolt',
      category: AbilityCategory.magic,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimed,
      hitDelivery: ProjectileHitDelivery(
        projectileId: ProjectileId.iceBolt,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      // Cost 10.0 -> 1000
      windupTicks: 6, activeTicks: 2, recoveryTicks: 8,
      staminaCost: 0, manaCost: 1000,
      cooldownTicks: 24,
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.cast,
      tags: {AbilityTag.projectile, AbilityTag.ice},
      requiredWeaponTypes: {WeaponType.projectileSpell},
      baseDamage: 1500, // SpellCatalog.iceBolt damage 15.0
      baseDamageType: DamageType.ice,
    ),

    'eloise.fire_bolt': AbilityDef(
      id: 'eloise.fire_bolt',
      category: AbilityCategory.magic,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimed,
      hitDelivery: ProjectileHitDelivery(
        projectileId: ProjectileId.fireBolt,
      ),
      // Cost 12.0 -> 1200
      windupTicks: 6, activeTicks: 2, recoveryTicks: 8,
      staminaCost: 0, manaCost: 1200,
      cooldownTicks: 15, // 0.25s @ 60Hz (matches legacy cast cooldown)
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.cast,
      tags: {AbilityTag.projectile, AbilityTag.fire},
      requiredWeaponTypes: {WeaponType.projectileSpell},
      baseDamage: 1800, // SpellCatalog.fireBolt damage 18.0
      baseDamageType: DamageType.fire,
    ),

    'eloise.thunder_bolt': AbilityDef(
      id: 'eloise.thunder_bolt',
      category: AbilityCategory.magic,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimed,
      hitDelivery: ProjectileHitDelivery(
        projectileId: ProjectileId.thunderBolt,
      ),
      // Cost 10.0 -> 1000
      windupTicks: 6, activeTicks: 2, recoveryTicks: 8,
      staminaCost: 0, manaCost: 1000,
      cooldownTicks: 15, // 0.25s @ 60Hz (matches legacy cast cooldown)
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.cast,
      tags: {AbilityTag.projectile, AbilityTag.lightning},
      requiredWeaponTypes: {WeaponType.projectileSpell},
      baseDamage: 500, // SpellCatalog.thunderBolt damage 5.0
      baseDamageType: DamageType.thunder,
    ),

    // ------------------------------------------------------------------------
    // ELOISE: MOBILITY
    // ------------------------------------------------------------------------
    'eloise.jump': AbilityDef(
      id: 'eloise.jump',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.jump},
      targetingModel: TargetingModel.none,
      hitDelivery: SelfHitDelivery(),
      windupTicks: 0,
      activeTicks: 0,
      recoveryTicks: 0,
      staminaCost: 200, // 2.0 stamina (matches default jump tuning)
      manaCost: 0,
      cooldownTicks: 0,
      interruptPriority: InterruptPriority.mobility,
      animKey: AnimKey.jump,
      tags: {AbilityTag.light},
      baseDamage: 0,
    ),

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
      animKey: AnimKey.dash,
      tags: {AbilityTag.light, AbilityTag.buff},
      baseDamage: 0,
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
      animKey: AnimKey.roll,
      tags: {AbilityTag.light, AbilityTag.buff},
      baseDamage: 0,
    ),
  };

  static AbilityDef? tryGet(AbilityKey key) => abilities[key];

  /// Instance helper for dependency-injected call sites.
  AbilityDef? resolve(AbilityKey key) => abilities[key];
}
