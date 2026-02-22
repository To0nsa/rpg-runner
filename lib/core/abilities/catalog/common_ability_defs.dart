import '../../combat/damage_type.dart';
import '../../projectiles/projectile_id.dart';
import '../../snapshots/enums.dart';
import '../ability_def.dart';

/// Common/system-authored abilities shared by AI/system actors.
final Map<AbilityKey, AbilityDef> commonAbilityDefs = <AbilityKey, AbilityDef>{
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
      projectileId: ProjectileId.fireBolt,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    windupTicks: 6,
    activeTicks: 2,
    recoveryTicks: 12,
    cooldownTicks: 0,
    animKey: AnimKey.cast,
    requiredWeaponTypes: {WeaponType.projectileSpell},
    payloadSource: AbilityPayloadSource.projectile,
    baseDamage: 500, // Thunder bolt legacy damage 5.0
    baseDamageType: DamageType.physical,
  ),
};
