import '../../combat/shoggoth_minion_pose_catalog.dart';
import '../../combat/damage_type.dart';
import '../../snapshots/enums.dart';
import '../ability_def.dart';

/// Timings use 60 Hz authoring ticks; cooldown group zero is local to each actor.
final Map<AbilityKey, AbilityDef> shoggothMinionAbilityDefs = {
  'shoggoth_minion.bite': AbilityDef(
    id: 'shoggoth_minion.bite',
    category: AbilityCategory.melee,
    hitDelivery: const MeleeHitDelivery(
      profile: ShoggothMinionPoseCatalog.minionBite,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 200,
    baseDamageType: DamageType.physical,
    windupTicks: 24,
    activeTicks: 12,
    recoveryTicks: 18,
    cooldownTicks: 90,
    cooldownGroupId: 0,
    animKey: AnimKey.strike,
  ),
};
