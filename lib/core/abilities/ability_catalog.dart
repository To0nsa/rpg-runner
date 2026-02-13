import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../projectiles/projectile_id.dart';
import '../snapshots/enums.dart';
import '../weapons/weapon_proc.dart';
import 'ability_def.dart';

/// Read-only ability definition lookup contract.
///
/// Systems should depend on this interface so tests and alternate catalogs can
/// be injected without coupling to static globals.
abstract interface class AbilityResolver {
  /// Returns the authored ability for [key], or null when unknown.
  AbilityDef? resolve(AbilityKey key);
}

/// Static registry of all available abilities.
///
/// This is currently code-authored data to keep ability tuning deterministic
/// and reviewable in source control.
class AbilityCatalog implements AbilityResolver {
  const AbilityCatalog();

  /// Shared default resolver for convenience call sites.
  static const AbilityCatalog shared = AbilityCatalog();

  /// Complete ability definition table keyed by [AbilityKey].
  ///
  /// Keys should remain stable because they are referenced by loadouts, tests,
  /// and persisted run/telemetry data.
  static const Map<AbilityKey, AbilityDef> abilities = {
    // ------------------------------------------------------------------------
    // COMMON SYSTEM ABILITIES
    // ------------------------------------------------------------------------
    'common.enemy_strike': AbilityDef(
      id: 'common.enemy_strike',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.primary},
      targetingModel: TargetingModel.directional,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: MeleeHitDelivery(
        sizeX: 1.0,
        sizeY: 1.0,
        offsetX: 0.5,
        offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 8,
      activeTicks: 4,
      recoveryTicks: 24,
      staminaCost: 0,
      manaCost: 0,
      cooldownTicks: 0,
      animKey: AnimKey.strike,
      baseDamage: 0,
    ),
    'common.enemy_cast': AbilityDef(
      id: 'common.enemy_cast',
      category: AbilityCategory.ranged,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimed,
      inputLifecycle: AbilityInputLifecycle.holdRelease,
      hitDelivery: ProjectileHitDelivery(
        projectileId: ProjectileId.thunderBolt,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 6,
      activeTicks: 2,
      recoveryTicks: 12,
      staminaCost: 0,
      manaCost: 0,
      cooldownTicks: 0,
      animKey: AnimKey.cast,
      requiredWeaponTypes: {WeaponType.projectileSpell},
      payloadSource: AbilityPayloadSource.projectile,
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
      inputLifecycle: AbilityInputLifecycle.holdRelease,
      hitDelivery: MeleeHitDelivery(
        sizeX: 32,
        sizeY: 32,
        offsetX: 12,
        offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      // 6 frames @ 0.06s = 0.36s -> ~22 ticks
      // Tuning: Active 0.10s (6 ticks)
      windupTicks: 8,
      activeTicks: 6,
      recoveryTicks: 8,
      staminaCost: 500,
      manaCost: 0, // 5.0 stamina
      cooldownTicks: 18, // 0.30s
      animKey: AnimKey.strike,
      requiredWeaponTypes: {WeaponType.oneHandedSword},
      payloadSource: AbilityPayloadSource.primaryWeapon,
      procs: <WeaponProc>[
        WeaponProc(
          hook: ProcHook.onHit,
          statusProfileId: StatusProfileId.meleeBleed,
          chanceBp: 10000,
        ),
      ],
      baseDamage: 1500, // PlayerTuning meleeDamage 15.0
    ),
    'eloise.charged_sword_strike': AbilityDef(
      id: 'eloise.charged_sword_strike',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.primary},
      targetingModel: TargetingModel.aimedCharge,
      inputLifecycle: AbilityInputLifecycle.holdRelease,
      hitDelivery: MeleeHitDelivery(
        sizeX: 32,
        sizeY: 32,
        offsetX: 12,
        offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 10,
      activeTicks: 6,
      recoveryTicks: 10,
      staminaCost: 550,
      manaCost: 0,
      cooldownTicks: 24,
      forcedInterruptCauses: <ForcedInterruptCause>{
        ForcedInterruptCause.stun,
        ForcedInterruptCause.death,
        ForcedInterruptCause.damageTaken,
      },
      animKey: AnimKey.strike,
      requiredWeaponTypes: {WeaponType.oneHandedSword},
      payloadSource: AbilityPayloadSource.primaryWeapon,
      chargeProfile: AbilityChargeProfile(
        tiers: <AbilityChargeTierDef>[
          AbilityChargeTierDef(minHoldTicks60: 0, damageScaleBp: 9000),
          AbilityChargeTierDef(
            minHoldTicks60: 8,
            damageScaleBp: 10800,
            critBonusBp: 500,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 16,
            damageScaleBp: 13000,
            critBonusBp: 1000,
          ),
        ],
      ),
      chargeMaxHoldTicks60: 150,
      procs: <WeaponProc>[
        WeaponProc(
          hook: ProcHook.onHit,
          statusProfileId: StatusProfileId.meleeBleed,
          chanceBp: 10000,
        ),
      ],
      baseDamage: 1600,
    ),
    'eloise.charged_sword_strike_auto_aim': AbilityDef(
      id: 'eloise.charged_sword_strike_auto_aim',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.primary},
      targetingModel: TargetingModel.homing,
      inputLifecycle: AbilityInputLifecycle.holdRelease,
      hitDelivery: MeleeHitDelivery(
        sizeX: 32,
        sizeY: 32,
        offsetX: 12,
        offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 10,
      activeTicks: 6,
      recoveryTicks: 10,
      staminaCost: 600,
      manaCost: 0,
      cooldownTicks: 24,
      forcedInterruptCauses: <ForcedInterruptCause>{
        ForcedInterruptCause.stun,
        ForcedInterruptCause.death,
        ForcedInterruptCause.damageTaken,
      },
      animKey: AnimKey.strike,
      requiredWeaponTypes: {WeaponType.oneHandedSword},
      payloadSource: AbilityPayloadSource.primaryWeapon,
      chargeProfile: AbilityChargeProfile(
        tiers: <AbilityChargeTierDef>[
          AbilityChargeTierDef(minHoldTicks60: 0, damageScaleBp: 9000),
          AbilityChargeTierDef(
            minHoldTicks60: 8,
            damageScaleBp: 10800,
            critBonusBp: 500,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 16,
            damageScaleBp: 13250,
            critBonusBp: 1000,
          ),
        ],
      ),
      chargeMaxHoldTicks60: 150,
      procs: <WeaponProc>[
        WeaponProc(
          hook: ProcHook.onHit,
          statusProfileId: StatusProfileId.meleeBleed,
          chanceBp: 10000,
        ),
      ],
      baseDamage: 1550,
    ),
    'eloise.sword_strike_auto_aim': AbilityDef(
      id: 'eloise.sword_strike_auto_aim',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.primary},
      targetingModel: TargetingModel.homing,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: MeleeHitDelivery(
        sizeX: 32,
        sizeY: 32,
        offsetX: 12,
        offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      // Match Sword Strike exactly; only targeting differs.
      windupTicks: 8,
      activeTicks: 6,
      recoveryTicks: 8,
      // Reliability tax for deterministic lock-on.
      staminaCost: 550,
      manaCost: 0,
      cooldownTicks: 24,
      animKey: AnimKey.strike,
      requiredWeaponTypes: {WeaponType.oneHandedSword},
      payloadSource: AbilityPayloadSource.primaryWeapon,
      procs: <WeaponProc>[
        WeaponProc(
          hook: ProcHook.onHit,
          statusProfileId: StatusProfileId.meleeBleed,
          chanceBp: 10000,
        ),
      ],
      baseDamage: 1400,
    ),

    'eloise.sword_parry': AbilityDef(
      id: 'eloise.sword_parry',
      category: AbilityCategory.defense,
      allowedSlots: {AbilitySlot.primary},
      targetingModel: TargetingModel.none,
      inputLifecycle: AbilityInputLifecycle.holdMaintain,
      hitDelivery: SelfHitDelivery(),
      // Hold defense up to 3s at 60Hz.
      windupTicks: 2,
      activeTicks: 180,
      recoveryTicks: 2,
      staminaCost: 0,
      manaCost: 0,
      holdMode: AbilityHoldMode.holdToMaintain,
      // Full 3s hold spends ~21.0 stamina (matches old one-shot cost envelope).
      holdStaminaDrainPerSecond100: 233,
      cooldownTicks: 30, // 0.50s
      animKey: AnimKey.parry,
      requiredWeaponTypes: {WeaponType.oneHandedSword},
      payloadSource: AbilityPayloadSource.primaryWeapon,
      baseDamage: 0,
    ),

    // ------------------------------------------------------------------------
    // ELOISE: SECONDARY (Shield)
    // ------------------------------------------------------------------------
    'eloise.shield_bash': AbilityDef(
      id: 'eloise.shield_bash',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.secondary},
      targetingModel: TargetingModel.directional,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: MeleeHitDelivery(
        sizeX: 32,
        sizeY: 32,
        offsetX: 12.0,
        offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 8,
      activeTicks: 6,
      recoveryTicks: 8,
      staminaCost: 500,
      manaCost: 0,
      cooldownTicks: 18, // 0.30s
      animKey: AnimKey.shieldBash,
      requiredWeaponTypes: {WeaponType.shield},
      payloadSource: AbilityPayloadSource.secondaryWeapon,
      procs: <WeaponProc>[
        WeaponProc(
          hook: ProcHook.onHit,
          statusProfileId: StatusProfileId.stunOnHit,
          chanceBp: 10000,
        ),
      ],
      baseDamage: 1500, // Assuming standardized melee damage
    ),
    'eloise.charged_shield_bash': AbilityDef(
      id: 'eloise.charged_shield_bash',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.secondary},
      targetingModel: TargetingModel.aimedCharge,
      inputLifecycle: AbilityInputLifecycle.holdRelease,
      hitDelivery: MeleeHitDelivery(
        sizeX: 32,
        sizeY: 32,
        offsetX: 12.0,
        offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 10,
      activeTicks: 6,
      recoveryTicks: 10,
      staminaCost: 550,
      manaCost: 0,
      cooldownTicks: 24,
      forcedInterruptCauses: <ForcedInterruptCause>{
        ForcedInterruptCause.stun,
        ForcedInterruptCause.death,
        ForcedInterruptCause.damageTaken,
      },
      animKey: AnimKey.shieldBash,
      requiredWeaponTypes: {WeaponType.shield},
      payloadSource: AbilityPayloadSource.secondaryWeapon,
      chargeProfile: AbilityChargeProfile(
        tiers: <AbilityChargeTierDef>[
          AbilityChargeTierDef(minHoldTicks60: 0, damageScaleBp: 9000),
          AbilityChargeTierDef(
            minHoldTicks60: 8,
            damageScaleBp: 10800,
            critBonusBp: 500,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 16,
            damageScaleBp: 13000,
            critBonusBp: 1000,
          ),
        ],
      ),
      chargeMaxHoldTicks60: 150,
      procs: <WeaponProc>[
        WeaponProc(
          hook: ProcHook.onHit,
          statusProfileId: StatusProfileId.stunOnHit,
          chanceBp: 10000,
        ),
      ],
      baseDamage: 1600,
    ),
    'eloise.shield_bash_auto_aim': AbilityDef(
      id: 'eloise.shield_bash_auto_aim',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.secondary},
      targetingModel: TargetingModel.homing,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: MeleeHitDelivery(
        sizeX: 32,
        sizeY: 32,
        offsetX: 12.0,
        offsetY: 0.0,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      // Match Shield Bash exactly; only targeting differs.
      windupTicks: 8,
      activeTicks: 6,
      recoveryTicks: 8,
      // Reliability tax for deterministic lock-on.
      staminaCost: 550,
      manaCost: 0,
      cooldownTicks: 24,
      animKey: AnimKey.shieldBash,
      requiredWeaponTypes: {WeaponType.shield},
      payloadSource: AbilityPayloadSource.secondaryWeapon,
      procs: <WeaponProc>[
        WeaponProc(
          hook: ProcHook.onHit,
          statusProfileId: StatusProfileId.stunOnHit,
          chanceBp: 10000,
        ),
      ],
      baseDamage: 1400,
    ),

    'eloise.shield_block': AbilityDef(
      id: 'eloise.shield_block',
      category: AbilityCategory.defense,
      allowedSlots: {AbilitySlot.secondary},
      targetingModel: TargetingModel.none,
      inputLifecycle: AbilityInputLifecycle.holdMaintain,
      hitDelivery: SelfHitDelivery(),
      // Match Sword Parry exactly (only required weapon differs).
      windupTicks: 2,
      activeTicks: 180,
      recoveryTicks: 2,
      staminaCost: 0,
      manaCost: 0,
      holdMode: AbilityHoldMode.holdToMaintain,
      holdStaminaDrainPerSecond100: 700,
      cooldownTicks: 30,
      animKey: AnimKey.shieldBlock,
      requiredWeaponTypes: {WeaponType.shield},
      payloadSource: AbilityPayloadSource.secondaryWeapon,
      baseDamage: 0,
    ),

    // ------------------------------------------------------------------------
    // ELOISE: PROJECTILE
    // ------------------------------------------------------------------------
    'eloise.auto_aim_shot': AbilityDef(
      id: 'eloise.auto_aim_shot',
      category: AbilityCategory.ranged,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.homing,
      inputLifecycle: AbilityInputLifecycle.tap,
      // Projectile id comes from the equipped projectile item at runtime.
      hitDelivery: ProjectileHitDelivery(
        projectileId: ProjectileId.iceBolt,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 10,
      activeTicks: 2,
      recoveryTicks: 12,
      staminaCost: 0,
      manaCost: 800,
      cooldownTicks: 40,
      animKey: AnimKey.ranged,
      requiredWeaponTypes: {
        WeaponType.throwingWeapon,
        WeaponType.projectileSpell,
      },
      payloadSource: AbilityPayloadSource.projectile,
      baseDamage: 1300,
    ),

    'eloise.quick_shot': AbilityDef(
      id: 'eloise.quick_shot',
      category: AbilityCategory.ranged,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimed,
      inputLifecycle: AbilityInputLifecycle.holdRelease,
      // Projectile id comes from the equipped projectile item at runtime.
      hitDelivery: ProjectileHitDelivery(
        projectileId: ProjectileId.throwingKnife,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 10,
      activeTicks: 2,
      recoveryTicks: 12,
      staminaCost: 0,
      manaCost: 600,
      cooldownTicks: 14,
      animKey: AnimKey.ranged,
      requiredWeaponTypes: {
        WeaponType.throwingWeapon,
        WeaponType.projectileSpell,
      },
      payloadSource: AbilityPayloadSource.projectile,
      baseDamage: 900,
    ),

    'eloise.piercing_shot': AbilityDef(
      id: 'eloise.piercing_shot',
      category: AbilityCategory.ranged,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimedLine,
      inputLifecycle: AbilityInputLifecycle.holdRelease,
      // Projectile id comes from the equipped projectile item at runtime.
      hitDelivery: ProjectileHitDelivery(
        projectileId: ProjectileId.throwingAxe,
        pierce: true,
        chainCount: 3,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 10,
      activeTicks: 2,
      recoveryTicks: 12,
      staminaCost: 0,
      manaCost: 1000,
      cooldownTicks: 32,
      animKey: AnimKey.ranged,
      requiredWeaponTypes: {
        WeaponType.throwingWeapon,
        WeaponType.projectileSpell,
      },
      payloadSource: AbilityPayloadSource.projectile,
      baseDamage: 1800,
    ),

    'eloise.charged_shot': AbilityDef(
      id: 'eloise.charged_shot',
      category: AbilityCategory.ranged,
      allowedSlots: {AbilitySlot.projectile},
      targetingModel: TargetingModel.aimedCharge,
      inputLifecycle: AbilityInputLifecycle.holdRelease,
      // Projectile id comes from the equipped projectile item at runtime.
      hitDelivery: ProjectileHitDelivery(
        projectileId: ProjectileId.fireBolt,
        hitPolicy: HitPolicy.oncePerTarget,
      ),
      windupTicks: 10,
      activeTicks: 2,
      recoveryTicks: 12,
      staminaCost: 0,
      manaCost: 1300,
      cooldownTicks: 40,
      forcedInterruptCauses: <ForcedInterruptCause>{
        ForcedInterruptCause.stun,
        ForcedInterruptCause.death,
        ForcedInterruptCause.damageTaken,
      },
      animKey: AnimKey.ranged,
      requiredWeaponTypes: {
        WeaponType.throwingWeapon,
        WeaponType.projectileSpell,
      },
      payloadSource: AbilityPayloadSource.projectile,
      chargeProfile: AbilityChargeProfile(
        tiers: <AbilityChargeTierDef>[
          AbilityChargeTierDef(
            minHoldTicks60: 0,
            damageScaleBp: 8200,
            speedScaleBp: 9000,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 5,
            damageScaleBp: 10000,
            critBonusBp: 500,
            speedScaleBp: 10500,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 10,
            damageScaleBp: 12250,
            critBonusBp: 1000,
            speedScaleBp: 12000,
            pierce: true,
            maxPierceHits: 2,
          ),
        ],
      ),
      chargeMaxHoldTicks60: 150,
      baseDamage: 2300,
    ),

    // ------------------------------------------------------------------------
    // ELOISE: BONUS / BUFFS
    // ------------------------------------------------------------------------
    'eloise.arcane_haste': AbilityDef(
      id: 'eloise.arcane_haste',
      category: AbilityCategory.utility,
      allowedSlots: {AbilitySlot.spell},
      targetingModel: TargetingModel.none,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: SelfHitDelivery(),
      // Instant cast, short recovery.
      windupTicks: 0,
      activeTicks: 0,
      recoveryTicks: 10,
      staminaCost: 0,
      manaCost: 1000,
      cooldownTicks: 300, // 5s @ 60Hz
      animKey: AnimKey.cast,
      requiredWeaponTypes: {WeaponType.projectileSpell},
      payloadSource: AbilityPayloadSource.spellBook,
      selfStatusProfileId: StatusProfileId.speedBoost,
      baseDamage: 0,
    ),
    'eloise.restore_health': AbilityDef(
      id: 'eloise.restore_health',
      category: AbilityCategory.utility,
      allowedSlots: {AbilitySlot.spell},
      targetingModel: TargetingModel.none,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: SelfHitDelivery(),
      windupTicks: 0,
      activeTicks: 0,
      recoveryTicks: 10,
      staminaCost: 0,
      manaCost: 1500,
      cooldownTicks: 420, // 7s @ 60Hz
      animKey: AnimKey.cast,
      requiredWeaponTypes: {WeaponType.projectileSpell},
      payloadSource: AbilityPayloadSource.spellBook,
      selfRestoreHealthBp: 3500, // Restore 35% max HP
      baseDamage: 0,
    ),
    'eloise.restore_mana': AbilityDef(
      id: 'eloise.restore_mana',
      category: AbilityCategory.utility,
      allowedSlots: {AbilitySlot.spell},
      targetingModel: TargetingModel.none,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: SelfHitDelivery(),
      windupTicks: 0,
      activeTicks: 0,
      recoveryTicks: 10,
      staminaCost: 1500,
      manaCost: 0,
      cooldownTicks: 420, // 7s @ 60Hz
      animKey: AnimKey.cast,
      requiredWeaponTypes: {WeaponType.projectileSpell},
      payloadSource: AbilityPayloadSource.spellBook,
      selfRestoreManaBp: 3500, // Restore 35% max mana
      baseDamage: 0,
    ),
    'eloise.restore_stamina': AbilityDef(
      id: 'eloise.restore_stamina',
      category: AbilityCategory.utility,
      allowedSlots: {AbilitySlot.spell},
      targetingModel: TargetingModel.none,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: SelfHitDelivery(),
      windupTicks: 0,
      activeTicks: 0,
      recoveryTicks: 10,
      staminaCost: 0,
      manaCost: 1500,
      cooldownTicks: 420, // 7s @ 60Hz
      animKey: AnimKey.cast,
      requiredWeaponTypes: {WeaponType.projectileSpell},
      payloadSource: AbilityPayloadSource.spellBook,
      selfRestoreStaminaBp: 3500, // Restore 35% max stamina
      baseDamage: 0,
    ),

    // ------------------------------------------------------------------------
    // ELOISE: MOBILITY
    // ------------------------------------------------------------------------
    'eloise.jump': AbilityDef(
      id: 'eloise.jump',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.jump},
      targetingModel: TargetingModel.none,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: SelfHitDelivery(),
      payloadSource: AbilityPayloadSource.none,
      windupTicks: 0,
      activeTicks: 0,
      recoveryTicks: 0,
      staminaCost: 200, // 2.0 stamina (matches default jump tuning)
      manaCost: 0,
      cooldownTicks: 0,
      animKey: AnimKey.jump,
      baseDamage: 0,
    ),

    'eloise.dash': AbilityDef(
      id: 'eloise.dash',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.mobility},
      targetingModel: TargetingModel.directional,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: SelfHitDelivery(),
      payloadSource: AbilityPayloadSource.none,
      // 4 frames @ 0.05s = 0.20s -> 12 ticks
      // Cooldown 2.0s -> 120 ticks
      // Cost 2.0 -> 200
      windupTicks: 0,
      activeTicks: 12,
      recoveryTicks: 0,
      staminaCost: 200,
      manaCost: 0,
      cooldownTicks: 120,
      animKey: AnimKey.dash,
      baseDamage: 0,
    ),
    'eloise.charged_aim_dash': AbilityDef(
      id: 'eloise.charged_aim_dash',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.mobility},
      targetingModel: TargetingModel.aimedCharge,
      inputLifecycle: AbilityInputLifecycle.holdRelease,
      hitDelivery: SelfHitDelivery(),
      payloadSource: AbilityPayloadSource.none,
      windupTicks: 0,
      activeTicks: 12,
      recoveryTicks: 0,
      staminaCost: 225,
      manaCost: 0,
      cooldownTicks: 120,
      animKey: AnimKey.dash,
      chargeProfile: AbilityChargeProfile(
        tiers: <AbilityChargeTierDef>[
          AbilityChargeTierDef(
            minHoldTicks60: 0,
            damageScaleBp: 10000,
            speedScaleBp: 9000,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 8,
            damageScaleBp: 10000,
            speedScaleBp: 11000,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 16,
            damageScaleBp: 10000,
            speedScaleBp: 12800,
          ),
        ],
      ),
      chargeMaxHoldTicks60: 150,
      baseDamage: 0,
    ),
    'eloise.charged_auto_dash': AbilityDef(
      id: 'eloise.charged_auto_dash',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.mobility},
      targetingModel: TargetingModel.homing,
      inputLifecycle: AbilityInputLifecycle.holdRelease,
      hitDelivery: SelfHitDelivery(),
      payloadSource: AbilityPayloadSource.none,
      windupTicks: 0,
      activeTicks: 12,
      recoveryTicks: 0,
      staminaCost: 240,
      manaCost: 0,
      cooldownTicks: 120,
      animKey: AnimKey.dash,
      chargeProfile: AbilityChargeProfile(
        tiers: <AbilityChargeTierDef>[
          AbilityChargeTierDef(
            minHoldTicks60: 0,
            damageScaleBp: 10000,
            speedScaleBp: 8800,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 8,
            damageScaleBp: 10000,
            speedScaleBp: 10600,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 16,
            damageScaleBp: 10000,
            speedScaleBp: 12300,
          ),
        ],
      ),
      chargeMaxHoldTicks60: 150,
      baseDamage: 0,
    ),
    'eloise.hold_auto_dash': AbilityDef(
      id: 'eloise.hold_auto_dash',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.mobility},
      targetingModel: TargetingModel.homing,
      inputLifecycle: AbilityInputLifecycle.holdMaintain,
      hitDelivery: SelfHitDelivery(),
      payloadSource: AbilityPayloadSource.none,
      windupTicks: 0,
      activeTicks: 60,
      recoveryTicks: 0,
      staminaCost: 240,
      manaCost: 0,
      holdMode: AbilityHoldMode.holdToMaintain,
      holdStaminaDrainPerSecond100: 120,
      cooldownTicks: 120,
      animKey: AnimKey.dash,
      chargeProfile: AbilityChargeProfile(
        tiers: <AbilityChargeTierDef>[
          AbilityChargeTierDef(
            minHoldTicks60: 0,
            damageScaleBp: 10000,
            speedScaleBp: 9000,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 8,
            damageScaleBp: 10000,
            speedScaleBp: 10800,
          ),
          AbilityChargeTierDef(
            minHoldTicks60: 16,
            damageScaleBp: 10000,
            speedScaleBp: 12400,
          ),
        ],
      ),
      chargeMaxHoldTicks60: 150,
      baseDamage: 0,
    ),

    'eloise.roll': AbilityDef(
      id: 'eloise.roll',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.mobility},
      targetingModel: TargetingModel.directional,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: SelfHitDelivery(),
      payloadSource: AbilityPayloadSource.none,
      // 10 frames @ 0.05s = 0.50s -> 30 ticks
      // Cost ~200? (Same as dash for now?)
      windupTicks: 3,
      activeTicks: 24,
      recoveryTicks: 3,
      staminaCost: 200,
      manaCost: 0,
      cooldownTicks: 120,
      animKey: AnimKey.roll,
      baseDamage: 0,
    ),
  };

  static final bool _integrityChecked = _validateIntegrity();

  static bool _validateIntegrity() {
    assert(() {
      final seenIds = <AbilityKey>{};
      for (final entry in abilities.entries) {
        final key = entry.key;
        final def = entry.value;
        if (key != def.id) {
          throw StateError(
            'AbilityCatalog key "$key" does not match AbilityDef.id "${def.id}".',
          );
        }
        if (!seenIds.add(def.id)) {
          throw StateError('Duplicate AbilityDef.id "${def.id}" in catalog.');
        }
      }
      return true;
    }());
    return true;
  }

  /// Legacy convenience lookup for static call sites.
  ///
  /// Prefer injecting [AbilityResolver] and calling [resolve].
  static AbilityDef? tryGet(AbilityKey key) {
    assert(_integrityChecked);
    return shared.resolve(key);
  }

  @override
  AbilityDef? resolve(AbilityKey key) {
    assert(_integrityChecked);
    return abilities[key];
  }
}
