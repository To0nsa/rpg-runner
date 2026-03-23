import 'package:runner_core/combat/damage_type.dart';

import '../../projectiles/projectile_id.dart';
import '../../snapshots/enums.dart';
import '../ability_def.dart';

/// Unoco Demon ability definitions.
final Map<AbilityKey, AbilityDef> unocoAbilityDefs = <AbilityKey, AbilityDef>{
  'unoco.fire_bolt_cast': AbilityDef(
    id: 'unoco.fire_bolt_cast',
    category: AbilityCategory.ranged,
    targetingModel: TargetingModel.aimed,
    inputLifecycle: AbilityInputLifecycle.holdRelease,
    hitDelivery: ProjectileHitDelivery(projectileId: ProjectileId.fireBolt),
    defaultCost: AbilityResourceCost(manaCost100: 2500),
    windupTicks: 6,
    activeTicks: 2,
    recoveryTicks: 12,
    cooldownTicks: 150, // 2.5s @ 60Hz
    animKey: AnimKey.cast,
    baseDamage: 500, // Thunder bolt legacy damage 5.0
    baseDamageType: DamageType.fire,
  ),
  'unoco.strike': AbilityDef(
    id: 'unoco.strike',
    category: AbilityCategory.melee,
    allowedSlots: {AbilitySlot.primary},
    inputLifecycle: AbilityInputLifecycle.tap,
    hitDelivery: MeleeHitDelivery(
      sizeX: 56.0,
      sizeY: 32.0,
      offsetX: 0.0,
      offsetY: 0.0,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 800,
    baseDamageType: DamageType.physical,
    windupTicks: 15,
    activeTicks: 4,
    recoveryTicks: 17,
    cooldownTicks: 60,
    animKey: AnimKey.strike,
  ),
};
