import '../../projectiles/projectile_id.dart';
import '../../snapshots/enums.dart';
import '../ability_def.dart';

/// Common/system-authored abilities shared by AI/system actors.
final Map<AbilityKey, AbilityDef> commonAbilityDefs = <AbilityKey, AbilityDef>{
  'common.enemy_cast': AbilityDef(
    id: 'common.enemy_cast',
    category: AbilityCategory.ranged,
    allowedSlots: {AbilitySlot.projectile},
    targetingModel: TargetingModel.aimed,
    inputLifecycle: AbilityInputLifecycle.holdRelease,
    hitDelivery: ProjectileHitDelivery(projectileId: ProjectileId.fireBolt),
    windupTicks: 6,
    activeTicks: 2,
    recoveryTicks: 12,
    cooldownTicks: 0,
    animKey: AnimKey.cast,
    requiredWeaponTypes: {WeaponType.spell},
    payloadSource: AbilityPayloadSource.projectile,
    baseDamage: 500, // Thunder bolt legacy damage 5.0
  ),
};
