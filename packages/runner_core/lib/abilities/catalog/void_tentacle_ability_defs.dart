import '../../combat/void_tentacle_pose_catalog.dart';
import '../../combat/damage_type.dart';
import '../../snapshots/enums.dart';
import '../ability_def.dart';

/// Timings use 60 Hz authoring ticks; cooldown group zero is local to each actor.
final Map<AbilityKey, AbilityDef> voidTentacleAbilityDefs = {
  'void_tentacle.lash': AbilityDef(
    id: 'void_tentacle.lash',
    category: AbilityCategory.melee,
    hitDelivery: const MeleeHitDelivery(
      profile: VoidTentaclePoseCatalog.tentacleLash,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 300,
    baseDamageType: DamageType.physical,
    windupTicks: 30,
    activeTicks: 18,
    recoveryTicks: 18,
    cooldownTicks: 110,
    cooldownGroupId: 0,
    animKey: AnimKey.strike,
  ),
};
