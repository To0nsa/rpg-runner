import '../../combat/status/status.dart';
import '../../projectiles/projectile_id.dart';
import '../../snapshots/enums.dart';
import '../../weapons/weapon_proc.dart';
import '../ability_def.dart';

/// Eloise-authored playable ability definitions.
final Map<AbilityKey, AbilityDef> eloiseAbilityDefs = <AbilityKey, AbilityDef>{
  // --------------------------------------------------------------------------
  // ELOISE: PRIMARY (Sword)
  // --------------------------------------------------------------------------
  'eloise.bloodletter_slash': AbilityDef(
    id: 'eloise.bloodletter_slash',
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
    defaultCost: AbilityResourceCost(staminaCost100: 500), // 5.0 stamina
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
  'eloise.bloodletter_cleave': AbilityDef(
    id: 'eloise.bloodletter_cleave',
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
    defaultCost: AbilityResourceCost(staminaCost100: 550),
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
  'eloise.seeker_slash': AbilityDef(
    id: 'eloise.seeker_slash',
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
    defaultCost: AbilityResourceCost(staminaCost100: 550),
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

  'eloise.riposte_guard': AbilityDef(
    id: 'eloise.riposte_guard',
    category: AbilityCategory.defense,
    allowedSlots: {AbilitySlot.primary},
    inputLifecycle: AbilityInputLifecycle.holdMaintain,
    windupTicks: 2,
    activeTicks: 180,
    recoveryTicks: 2,
    holdMode: AbilityHoldMode.holdToMaintain,
    holdStaminaDrainPerSecond100: 700,
    damageIgnoredBp: 5000,
    grantsRiposteOnGuardedHit: true,
    cooldownTicks: 30, // 0.50s
    animKey: AnimKey.parry,
    requiredWeaponTypes: {WeaponType.oneHandedSword},
    payloadSource: AbilityPayloadSource.primaryWeapon,
  ),

  // --------------------------------------------------------------------------
  // ELOISE: SECONDARY (Shield)
  // --------------------------------------------------------------------------
  'eloise.concussive_bash': AbilityDef(
    id: 'eloise.concussive_bash',
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
    defaultCost: AbilityResourceCost(staminaCost100: 500),
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
  'eloise.concussive_breaker': AbilityDef(
    id: 'eloise.concussive_breaker',
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
    defaultCost: AbilityResourceCost(staminaCost100: 550),
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
  'eloise.seeker_bash': AbilityDef(
    id: 'eloise.seeker_bash',
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
    defaultCost: AbilityResourceCost(staminaCost100: 550),
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

  'eloise.aegis_riposte': AbilityDef(
    id: 'eloise.aegis_riposte',
    category: AbilityCategory.defense,
    allowedSlots: {AbilitySlot.secondary},
    inputLifecycle: AbilityInputLifecycle.holdMaintain,
    windupTicks: 2,
    activeTicks: 180,
    recoveryTicks: 2,
    holdMode: AbilityHoldMode.holdToMaintain,
    holdStaminaDrainPerSecond100: 700,
    damageIgnoredBp: 5000,
    grantsRiposteOnGuardedHit: true,
    cooldownTicks: 30,
    animKey: AnimKey.shieldBlock,
    requiredWeaponTypes: {WeaponType.shield},
    payloadSource: AbilityPayloadSource.secondaryWeapon,
  ),

  'eloise.shield_block': AbilityDef(
    id: 'eloise.shield_block',
    category: AbilityCategory.defense,
    allowedSlots: {AbilitySlot.secondary},
    inputLifecycle: AbilityInputLifecycle.holdMaintain,
    windupTicks: 2,
    activeTicks: 180,
    recoveryTicks: 2,
    holdMode: AbilityHoldMode.holdToMaintain,
    holdStaminaDrainPerSecond100: 700,
    damageIgnoredBp: 10000,
    grantsRiposteOnGuardedHit: false,
    cooldownTicks: 30,
    animKey: AnimKey.shieldBlock,
    requiredWeaponTypes: {WeaponType.shield},
    payloadSource: AbilityPayloadSource.secondaryWeapon,
  ),

  // --------------------------------------------------------------------------
  // ELOISE: PROJECTILE
  // --------------------------------------------------------------------------
  'eloise.homing_bolt': AbilityDef(
    id: 'eloise.homing_bolt',
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
    defaultCost: AbilityResourceCost(manaCost100: 800),
    costProfileByWeaponType: <WeaponType, AbilityResourceCost>{
      WeaponType.throwingWeapon: AbilityResourceCost(staminaCost100: 800),
    },
    cooldownTicks: 40,
    animKey: AnimKey.ranged,
    requiredWeaponTypes: {
      WeaponType.throwingWeapon,
      WeaponType.projectileSpell,
    },
    payloadSource: AbilityPayloadSource.projectile,
    baseDamage: 1300,
  ),

  'eloise.snap_shot': AbilityDef(
    id: 'eloise.snap_shot',
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
    defaultCost: AbilityResourceCost(manaCost100: 600),
    costProfileByWeaponType: <WeaponType, AbilityResourceCost>{
      WeaponType.throwingWeapon: AbilityResourceCost(staminaCost100: 600),
    },
    cooldownTicks: 14,
    animKey: AnimKey.ranged,
    requiredWeaponTypes: {
      WeaponType.throwingWeapon,
      WeaponType.projectileSpell,
    },
    payloadSource: AbilityPayloadSource.projectile,
    baseDamage: 900,
  ),

  'eloise.skewer_shot': AbilityDef(
    id: 'eloise.skewer_shot',
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
    defaultCost: AbilityResourceCost(manaCost100: 1000),
    costProfileByWeaponType: <WeaponType, AbilityResourceCost>{
      WeaponType.throwingWeapon: AbilityResourceCost(staminaCost100: 1000),
    },
    cooldownTicks: 32,
    animKey: AnimKey.ranged,
    requiredWeaponTypes: {
      WeaponType.throwingWeapon,
      WeaponType.projectileSpell,
    },
    payloadSource: AbilityPayloadSource.projectile,
    baseDamage: 1800,
  ),

  'eloise.overcharge_shot': AbilityDef(
    id: 'eloise.overcharge_shot',
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
    defaultCost: AbilityResourceCost(manaCost100: 1300),
    costProfileByWeaponType: <WeaponType, AbilityResourceCost>{
      WeaponType.throwingWeapon: AbilityResourceCost(staminaCost100: 1300),
    },
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

  // --------------------------------------------------------------------------
  // ELOISE: BONUS / BUFFS
  // --------------------------------------------------------------------------
  'eloise.arcane_haste': AbilityDef(
    id: 'eloise.arcane_haste',
    category: AbilityCategory.utility,
    allowedSlots: {AbilitySlot.spell},
    targetingModel: TargetingModel.none,
    inputLifecycle: AbilityInputLifecycle.tap,
    // Instant cast, short recovery.
    windupTicks: 0,
    activeTicks: 0,
    recoveryTicks: 10,
    defaultCost: AbilityResourceCost(manaCost100: 1000),
    cooldownTicks: 300, // 5s @ 60Hz
    animKey: AnimKey.cast,
    requiredWeaponTypes: {WeaponType.projectileSpell},
    payloadSource: AbilityPayloadSource.spellBook,
    selfStatusProfileId: StatusProfileId.speedBoost,
  ),
  'eloise.vital_surge': AbilityDef(
    id: 'eloise.vital_surge',
    category: AbilityCategory.utility,
    allowedSlots: {AbilitySlot.spell},
    targetingModel: TargetingModel.none,
    inputLifecycle: AbilityInputLifecycle.tap,
    windupTicks: 0,
    activeTicks: 0,
    recoveryTicks: 10,
    defaultCost: AbilityResourceCost(manaCost100: 1500),
    cooldownTicks: 420, // 7s @ 60Hz
    animKey: AnimKey.cast,
    requiredWeaponTypes: {WeaponType.projectileSpell},
    payloadSource: AbilityPayloadSource.spellBook,
    selfStatusProfileId: StatusProfileId.restoreHealth,
  ),
  'eloise.mana_infusion': AbilityDef(
    id: 'eloise.mana_infusion',
    category: AbilityCategory.utility,
    allowedSlots: {AbilitySlot.spell},
    targetingModel: TargetingModel.none,
    inputLifecycle: AbilityInputLifecycle.tap,
    windupTicks: 0,
    activeTicks: 0,
    recoveryTicks: 10,
    defaultCost: AbilityResourceCost(staminaCost100: 1500),
    cooldownTicks: 420, // 7s @ 60Hz
    animKey: AnimKey.cast,
    requiredWeaponTypes: {WeaponType.projectileSpell},
    payloadSource: AbilityPayloadSource.spellBook,
    selfStatusProfileId: StatusProfileId.restoreMana,
  ),
  'eloise.second_wind': AbilityDef(
    id: 'eloise.second_wind',
    category: AbilityCategory.utility,
    allowedSlots: {AbilitySlot.spell},
    targetingModel: TargetingModel.none,
    inputLifecycle: AbilityInputLifecycle.tap,
    windupTicks: 0,
    activeTicks: 0,
    recoveryTicks: 10,
    defaultCost: AbilityResourceCost(manaCost100: 1500),
    cooldownTicks: 420, // 7s @ 60Hz
    animKey: AnimKey.cast,
    requiredWeaponTypes: {WeaponType.projectileSpell},
    payloadSource: AbilityPayloadSource.spellBook,
    selfStatusProfileId: StatusProfileId.restoreStamina,
  ),

  // --------------------------------------------------------------------------
  // ELOISE: MOBILITY
  // --------------------------------------------------------------------------
  'eloise.jump': AbilityDef(
    id: 'eloise.jump',
    category: AbilityCategory.mobility,
    allowedSlots: {AbilitySlot.jump},
    inputLifecycle: AbilityInputLifecycle.tap,
    windupTicks: 0,
    activeTicks: 0,
    recoveryTicks: 0,
    defaultCost: AbilityResourceCost(
      staminaCost100: 200,
    ), // 2.0 stamina (matches default jump tuning)
    cooldownTicks: 0,
    animKey: AnimKey.jump,
  ),

  // Two-tap jump profile:
  // - First jump uses fixed lower impulse.
  // - Second tap (air jump) applies the same fixed impulse.
  // Timing of the second tap changes the resulting two-arc path.
  'eloise.double_jump': AbilityDef(
    id: 'eloise.double_jump',
    category: AbilityCategory.mobility,
    allowedSlots: {AbilitySlot.jump},
    inputLifecycle: AbilityInputLifecycle.tap,
    windupTicks: 0,
    activeTicks: 0,
    recoveryTicks: 0,
    defaultCost: AbilityResourceCost(staminaCost100: 200),
    groundJumpSpeedY: 450,
    airJumpSpeedY: 450,
    maxAirJumps: 1,
    airJumpCost: AbilityResourceCost(manaCost100: 200),
    cooldownTicks: 0,
    animKey: AnimKey.jump,
  ),

  'eloise.dash': AbilityDef(
    id: 'eloise.dash',
    category: AbilityCategory.mobility,
    allowedSlots: {AbilitySlot.mobility},
    targetingModel: TargetingModel.directional,
    inputLifecycle: AbilityInputLifecycle.tap,
    windupTicks: 0,
    activeTicks: 15,
    recoveryTicks: 0,
    defaultCost: AbilityResourceCost(staminaCost100: 200),
    cooldownTicks: 120,
    mobilitySpeedX: 550,
    animKey: AnimKey.dash,
  ),

  'eloise.roll': AbilityDef(
    id: 'eloise.roll',
    category: AbilityCategory.mobility,
    allowedSlots: {AbilitySlot.mobility},
    targetingModel: TargetingModel.directional,
    inputLifecycle: AbilityInputLifecycle.tap,
    windupTicks: 0,
    activeTicks: 10,
    recoveryTicks: 0,
    defaultCost: AbilityResourceCost(staminaCost100: 200),
    cooldownTicks: 120,
    mobilityImpact: MobilityImpactDef(
      hitPolicy: HitPolicy.oncePerTarget,
      statusProfileId: StatusProfileId.stunOnHit,
    ),
    mobilitySpeedX: 400,
    animKey: AnimKey.roll,
  ),
};
