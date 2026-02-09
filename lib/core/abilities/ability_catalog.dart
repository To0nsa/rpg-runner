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
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.strike,
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
      windupTicks: 6,
      activeTicks: 2,
      recoveryTicks: 12,
      staminaCost: 0,
      manaCost: 0,
      cooldownTicks: 0,
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.cast,
      requiredWeaponTypes: {WeaponType.projectileSpell},
      payloadSource: AbilityPayloadSource.projectileItem,
      baseDamage: 500, // Thunder bolt legacy damage 5.0
      baseDamageType: DamageType.physical,
    ),

    // ------------------------------------------------------------------------
    // ELOISE: PRIMARY (Sword)
    // ------------------------------------------------------------------------
    'eloise.sword_strike': AbilityDef(
      id: 'eloise.sword_strike',
      category: AbilityCategory.melee,
      allowedSlots: {AbilitySlot.primary, AbilitySlot.bonus},
      targetingModel: TargetingModel.directional,
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
      interruptPriority: InterruptPriority.combat,
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

    'eloise.sword_parry': AbilityDef(
      id: 'eloise.sword_parry',
      category: AbilityCategory.defense,
      allowedSlots: {AbilitySlot.primary, AbilitySlot.bonus},
      targetingModel: TargetingModel.none,
      hitDelivery: SelfHitDelivery(),
      // 6 frames @ 0.06s = 0.36s -> ~22 ticks
      windupTicks: 2,
      activeTicks: 18,
      recoveryTicks: 2,
      staminaCost: 700,
      manaCost: 0,
      cooldownTicks: 30, // 0.50s
      interruptPriority: InterruptPriority.combat,
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
      category: AbilityCategory.defense,
      allowedSlots: {AbilitySlot.secondary, AbilitySlot.bonus},
      targetingModel: TargetingModel.directional,
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
      interruptPriority: InterruptPriority.combat,
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

    'eloise.shield_block': AbilityDef(
      id: 'eloise.shield_block',
      category: AbilityCategory.defense,
      allowedSlots: {AbilitySlot.secondary, AbilitySlot.bonus},
      targetingModel: TargetingModel.none,
      hitDelivery: SelfHitDelivery(),
      // Match Sword Parry exactly (only required weapon differs).
      // 7 frames x ~0.052s ~= 0.364s -> ~22 ticks @ 60Hz
      windupTicks: 2,
      activeTicks: 18,
      recoveryTicks: 2,
      staminaCost: 700,
      manaCost: 0,
      cooldownTicks: 30,
      interruptPriority: InterruptPriority.combat,
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
      category: AbilityCategory.magic,
      allowedSlots: {AbilitySlot.projectile, AbilitySlot.bonus},
      targetingModel: TargetingModel.homing,
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
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.ranged,
      requiredWeaponTypes: {
        WeaponType.throwingWeapon,
        WeaponType.projectileSpell,
      },
      payloadSource: AbilityPayloadSource.projectileItem,
      baseDamage: 1300,
    ),

    'eloise.quick_shot': AbilityDef(
      id: 'eloise.quick_shot',
      category: AbilityCategory.ranged,
      allowedSlots: {AbilitySlot.projectile, AbilitySlot.bonus},
      targetingModel: TargetingModel.aimed,
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
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.ranged,
      requiredWeaponTypes: {
        WeaponType.throwingWeapon,
        WeaponType.projectileSpell,
      },
      payloadSource: AbilityPayloadSource.projectileItem,
      baseDamage: 900,
    ),

    'eloise.piercing_shot': AbilityDef(
      id: 'eloise.piercing_shot',
      category: AbilityCategory.ranged,
      allowedSlots: {AbilitySlot.projectile, AbilitySlot.bonus},
      targetingModel: TargetingModel.aimedLine,
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
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.ranged,
      requiredWeaponTypes: {
        WeaponType.throwingWeapon,
        WeaponType.projectileSpell,
      },
      payloadSource: AbilityPayloadSource.projectileItem,
      baseDamage: 1800,
    ),

    'eloise.charged_shot': AbilityDef(
      id: 'eloise.charged_shot',
      category: AbilityCategory.magic,
      allowedSlots: {AbilitySlot.projectile, AbilitySlot.bonus},
      targetingModel: TargetingModel.aimedCharge,
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
      interruptPriority: InterruptPriority.combat,
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
      payloadSource: AbilityPayloadSource.projectileItem,
      baseDamage: 2300,
    ),

    // ------------------------------------------------------------------------
    // ELOISE: BONUS / BUFFS
    // ------------------------------------------------------------------------
    'eloise.arcane_haste': AbilityDef(
      id: 'eloise.arcane_haste',
      category: AbilityCategory.utility,
      allowedSlots: {AbilitySlot.bonus},
      targetingModel: TargetingModel.none,
      hitDelivery: SelfHitDelivery(),
      // Instant cast, short recovery.
      windupTicks: 0,
      activeTicks: 0,
      recoveryTicks: 10,
      staminaCost: 0,
      manaCost: 1000,
      cooldownTicks: 300, // 5s @ 60Hz
      interruptPriority: InterruptPriority.combat,
      animKey: AnimKey.cast,
      requiredWeaponTypes: {WeaponType.projectileSpell},
      payloadSource: AbilityPayloadSource.spellBook,
      selfStatusProfileId: StatusProfileId.speedBoost,
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
      hitDelivery: SelfHitDelivery(),
      payloadSource: AbilityPayloadSource.none,
      windupTicks: 0,
      activeTicks: 0,
      recoveryTicks: 0,
      staminaCost: 200, // 2.0 stamina (matches default jump tuning)
      manaCost: 0,
      cooldownTicks: 0,
      interruptPriority: InterruptPriority.mobility,
      animKey: AnimKey.jump,
      baseDamage: 0,
    ),

    'eloise.dash': AbilityDef(
      id: 'eloise.dash',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.mobility},
      targetingModel: TargetingModel.directional,
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
      interruptPriority: InterruptPriority.mobility,
      canBeInterruptedBy: {},
      animKey: AnimKey.dash,
      baseDamage: 0,
    ),

    'eloise.roll': AbilityDef(
      id: 'eloise.roll',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.mobility},
      targetingModel: TargetingModel.directional,
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
      interruptPriority: InterruptPriority.mobility,
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
