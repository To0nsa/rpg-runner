import '../../combat/bounty_hunter_pose_catalog.dart';
import '../../combat/combat_geometry.dart';
import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../projectiles/projectile_id.dart';
import '../../snapshots/enums.dart';
import '../../weapons/weapon_proc.dart';
import '../ability_def.dart';
import '../blink_mobility_def.dart';

/// Complete six-slot roster. Damage is per melee swing or total projectile fan.
final Map<AbilityKey, AbilityDef> bountyHunterAbilityDefs = {
  for (final def in [
    _cut(
      'quick_cut',
      BountyHunterPoseCatalog.quick,
      AnimKey.strike,
      1200,
      5,
      6,
      7,
      400,
    ),
    _cut(
      'twin_cut',
      BountyHunterPoseCatalog.twin,
      AnimKey.twinStrike,
      900,
      7,
      22,
      10,
      700,
    ),
    _cut(
      'lunge_slash',
      BountyHunterPoseCatalog.lunge,
      AnimKey.lunge,
      1700,
      10,
      10,
      12,
      800,
      lunge: 360,
    ),
    _bomb('blast_bomb', 2600, 240),
    _bomb('shrapnel_bomb', 1700, 300, status: StatusProfileId.meleeBleed),
    _bomb(
      'fire_bomb',
      1600,
      300,
      status: StatusProfileId.burnOnHit,
      type: DamageType.fire,
    ),
    _bomb(
      'concussion_bomb',
      1000,
      360,
      status: StatusProfileId.stunOnHit,
      radius: 54,
    ),
    _shot('snap_shot', 1300, 700, 30, autoAim: true),
    _shot('quick_shot', 900, 400, 16),
    _shot('piercing_shot', 1700, 1000, 36, pierce: true),
    _shot('scatter_shot', 2200, 1100, 42, scatter: true),
    _shot('charged_shot', 2300, 1300, 45, charged: true),
    _move('dash', AnimKey.dash, 12, 550, 200),
    AbilityDef(
      id: 'bounty_hunter.blink_dash',
      category: AbilityCategory.mobility,
      allowedSlots: {AbilitySlot.mobility},
      targetingModel: TargetingModel.directional,
      windupTicks: 12,
      activeTicks: 3,
      recoveryTicks: 15,
      cooldownTicks: 180,
      defaultCost: const AbilityResourceCost(staminaCost100: 400),
      blinkMobility: const BlinkMobilityDef(
        openDistance: 110,
        // Widest placed woodcamp tent: 92-unit collision shape at scale 1.5.
        maxObstacleWidth: 138,
        maxApproachDistance: 32,
      ),
      forcedInterruptCauses: {
        ForcedInterruptCause.stun,
        ForcedInterruptCause.death,
        ForcedInterruptCause.damageTaken,
      },
      animKey: AnimKey.teleportOut,
    ),
    _move('roll', AnimKey.roll, 18, 320, 300, grounded: true),
    _move('slide', AnimKey.slide, 24, 360, 400, grounded: true),
    _jump('jump'),
    _jump('double_jump', doubleJump: true),
    _field(
      'hunters_focus',
      status: StatusProfileId.focus,
      cost: 1200,
      cooldown: 420,
    ),
    _field(
      'mark_quarry',
      delivery: const MarkHitDelivery(),
      cost: 1000,
      cooldown: 420,
    ),
    _field(
      'forced_march',
      status: StatusProfileId.speedBoost,
      cost: 1000,
      cooldown: 300,
    ),
    _field(
      'field_dressing',
      status: StatusProfileId.restoreHealth,
      cost: 1500,
      cooldown: 480,
    ),
    _field(
      'antidote',
      purge: PurgeProfileId.cleanse,
      cost: 1400,
      cooldown: 480,
    ),
    _field(
      'second_wind',
      status: StatusProfileId.restoreStamina,
      cost: 1500,
      cooldown: 420,
    ),
    _field(
      'prepare_charges',
      status: StatusProfileId.restoreMana,
      cost: 1500,
      cooldown: 420,
      stamina: true,
    ),
  ])
    def.id: def,
};

AbilityDef _cut(
  String name,
  CombatStrikeProfile profile,
  AnimKey anim,
  int damage,
  int windup,
  int active,
  int recovery,
  int stamina, {
  double? lunge,
}) => AbilityDef(
  id: 'bounty_hunter.$name',
  category: AbilityCategory.melee,
  allowedSlots: {AbilitySlot.primary},
  targetingModel: TargetingModel.directional,
  hitDelivery: MeleeHitDelivery(
    profile: profile,
    hitPolicy: HitPolicy.oncePerTarget,
  ),
  payloadSource: AbilityPayloadSource.primaryWeapon,
  requiredWeaponTypes: {WeaponType.hunterBlade},
  baseDamage: damage,
  windupTicks: windup,
  activeTicks: active,
  recoveryTicks: recovery,
  defaultCost: AbilityResourceCost(staminaCost100: stamina),
  cooldownTicks: windup + active + recovery,
  activeForwardSpeedX: lunge,
  animKey: anim,
);

AbilityDef _bomb(
  String name,
  int damage,
  int cooldown, {
  StatusProfileId status = StatusProfileId.none,
  DamageType type = DamageType.physical,
  double radius = 48,
}) => AbilityDef(
  id: 'bounty_hunter.$name',
  category: AbilityCategory.ranged,
  allowedSlots: {AbilitySlot.secondary},
  hitDelivery: BombHitDelivery(
    projectileId: ProjectileId.hunterBomb,
    radius: radius,
  ),
  payloadSource: AbilityPayloadSource.secondaryWeapon,
  requiredWeaponTypes: {WeaponType.bombKit},
  baseDamage: damage,
  baseDamageType: type,
  procs: status == StatusProfileId.none
      ? []
      : [WeaponProc(hook: ProcHook.onHit, statusProfileId: status)],
  windupTicks: 18,
  activeTicks: 3,
  recoveryTicks: 9,
  // Unlimited uses: no resource cost. Four seconds is the basic bomb's cadence.
  cooldownTicks: cooldown,
  animKey: AnimKey.bombDrop,
);

AbilityDef _shot(
  String name,
  int damage,
  int cost,
  int cooldown, {
  bool autoAim = false,
  bool pierce = false,
  bool scatter = false,
  bool charged = false,
}) => AbilityDef(
  id: 'bounty_hunter.$name',
  category: AbilityCategory.ranged,
  allowedSlots: {AbilitySlot.projectile},
  targetingModel: autoAim
      ? TargetingModel.homing
      : charged
      ? TargetingModel.aimedCharge
      : pierce
      ? TargetingModel.aimedLine
      : TargetingModel.aimed,
  inputLifecycle: autoAim
      ? AbilityInputLifecycle.tap
      : AbilityInputLifecycle.holdRelease,
  hitDelivery: ProjectileHitDelivery(
    projectileId: ProjectileId.hunterPistol,
    pierce: pierce,
    chainCount: pierce ? 3 : 0,
    shotCount: scatter ? 5 : 1,
    spreadRadians: scatter ? .28 : 0,
  ),
  payloadSource: AbilityPayloadSource.projectile,
  requiredWeaponTypes: {WeaponType.firearm, WeaponType.crossbow},
  baseDamage: damage,
  windupTicks: 5,
  activeTicks: 2,
  recoveryTicks: 9,
  defaultCost: AbilityResourceCost(manaCost100: cost),
  cooldownTicks: cooldown,
  forcedInterruptCauses: {
    ...AbilityDef.defaultForcedInterruptCauses,
    if (charged) ForcedInterruptCause.damageTaken,
  },
  chargeProfile: !charged
      ? null
      : AbilityChargeProfile(
          tiers: [
            AbilityChargeTierDef(minHoldTicks60: 0, damageScaleBp: 7000),
            AbilityChargeTierDef(
              minHoldTicks60: 20,
              damageScaleBp: 10000,
              critBonusBp: 500,
            ),
            AbilityChargeTierDef(
              minHoldTicks60: 45,
              damageScaleBp: 15000,
              critBonusBp: 1000,
              pierce: true,
              maxPierceHits: 2,
            ),
          ],
        ),
  chargeMaxHoldTicks60: charged ? 150 : 0,
  animKey: AnimKey.ranged,
);

AbilityDef _move(
  String name,
  AnimKey anim,
  int ticks,
  double speed,
  int cost, {
  bool grounded = false,
}) => AbilityDef(
  id: 'bounty_hunter.$name',
  category: AbilityCategory.mobility,
  allowedSlots: {AbilitySlot.mobility},
  targetingModel: TargetingModel.directional,
  windupTicks: 0,
  activeTicks: ticks,
  recoveryTicks: 0,
  cooldownTicks: 120,
  mobilitySpeedX: speed,
  requiresGrounded: grounded,
  defaultCost: AbilityResourceCost(staminaCost100: cost),
  animKey: anim,
);

AbilityDef _jump(String name, {bool doubleJump = false}) => AbilityDef(
  id: 'bounty_hunter.$name',
  category: AbilityCategory.mobility,
  allowedSlots: {AbilitySlot.jump},
  windupTicks: 0,
  activeTicks: 0,
  recoveryTicks: 0,
  cooldownTicks: 0,
  defaultCost: const AbilityResourceCost(staminaCost100: 200),
  groundJumpSpeedY: doubleJump ? 450 : null,
  airJumpSpeedY: doubleJump ? 450 : null,
  maxAirJumps: doubleJump ? 1 : 0,
  airJumpCost: doubleJump
      ? const AbilityResourceCost(staminaCost100: 300)
      : AbilityResourceCost.zero,
  animKey: AnimKey.jump,
);

AbilityDef _field(
  String name, {
  StatusProfileId status = StatusProfileId.none,
  PurgeProfileId purge = PurgeProfileId.none,
  HitDeliveryDef delivery = const SelfHitDelivery(),
  required int cost,
  required int cooldown,
  bool stamina = false,
}) => AbilityDef(
  id: 'bounty_hunter.$name',
  category: AbilityCategory.utility,
  allowedSlots: {AbilitySlot.spell},
  hitDelivery: delivery,
  payloadSource: AbilityPayloadSource.spellBook,
  requiredWeaponTypes: {WeaponType.fieldKit},
  windupTicks: 0,
  activeTicks: 0,
  recoveryTicks: 10,
  cooldownTicks: cooldown,
  defaultCost: AbilityResourceCost(
    manaCost100: stamina ? 0 : cost,
    staminaCost100: stamina ? cost : 0,
  ),
  selfStatusProfileId: status,
  selfPurgeProfileId: purge,
  canCommitWhileStunned: purge != PurgeProfileId.none,
  animKey: AnimKey.cast,
);
