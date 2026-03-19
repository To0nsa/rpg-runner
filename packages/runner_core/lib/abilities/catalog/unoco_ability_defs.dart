import 'package:runner_core/combat/damage_type.dart';

import '../../projectiles/projectile_id.dart';
import '../../snapshots/enums.dart';
import '../ability_def.dart';

/// Unoco Demon ability definitions.
final Map<AbilityKey, AbilityDef> unocoAbilityDefs = <AbilityKey, AbilityDef>{
  'unoco.enemy_cast': AbilityDef(
    id: 'unoco.enemy_cast',
    category: AbilityCategory.ranged,
    hitDelivery: ProjectileHitDelivery(
      projectileId: ProjectileId.fireBolt,
      originOffset: 20.0,
    ),
    windupTicks: 6,
    activeTicks: 2,
    recoveryTicks: 12,
    cooldownTicks: 150, // 2.5s @ 60Hz
    animKey: AnimKey.cast,
    baseDamage: 500, // Thunder bolt legacy damage 5.0
    baseDamageType: DamageType.fire,
  ),
};
