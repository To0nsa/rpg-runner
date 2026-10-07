import '../../combat/shoggoth_pose_catalog.dart';
import '../../combat/damage_type.dart';
import '../../snapshots/enums.dart';
import '../ability_def.dart';
import '../../enemies/enemy_id.dart';
import '../../bosses/boss_utility_delivery.dart';
import '../../projectiles/projectile_id.dart';

/// Timings use 60 Hz authoring ticks; cooldown group zero is local to each actor.
final Map<AbilityKey, AbilityDef> shoggothAbilityDefs = {
  'shoggoth.tentacle_sweep': AbilityDef(
    id: 'shoggoth.tentacle_sweep',
    category: AbilityCategory.melee,
    hitDelivery: const MeleeHitDelivery(
      profile: ShoggothPoseCatalog.shoggothSweep,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 700,
    baseDamageType: DamageType.physical,
    windupTicks: 24,
    activeTicks: 24,
    recoveryTicks: 18,
    cooldownTicks: 100,
    cooldownGroupId: 0,
    animKey: AnimKey.strike,
  ),
  'shoggoth.spinning_charge': AbilityDef(
    id: 'shoggoth.spinning_charge',
    category: AbilityCategory.melee,
    hitDelivery: const MeleeHitDelivery(
      profile: ShoggothPoseCatalog.shoggothSpin,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 600,
    baseDamageType: DamageType.physical,
    windupTicks: 30,
    activeTicks: 36,
    recoveryTicks: 24,
    cooldownTicks: 140,
    cooldownGroupId: 0,
    animKey: AnimKey.strike2,
  ),
  'shoggoth.orb': AbilityDef(
    id: 'shoggoth.orb',
    category: AbilityCategory.ranged,
    hitDelivery: const ProjectileHitDelivery(
      projectileId: ProjectileId.shoggothOrb,
    ),
    baseDamage: 600,
    baseDamageType: DamageType.dark,
    windupTicks: 42,
    activeTicks: 6,
    recoveryTicks: 24,
    cooldownTicks: 110,
    cooldownGroupId: 0,
    animKey: AnimKey.cast,
  ),
  'shoggoth.summon': AbilityDef(
    id: 'shoggoth.summon',
    category: AbilityCategory.utility,
    hitDelivery: const BossSummonDelivery(
      enemyId: EnemyId.shoggothMinion,
      maxAlive: 3,
      lifetimeSeconds: 12,
    ),
    baseDamage: 0,
    baseDamageType: DamageType.physical,
    windupTicks: 42,
    activeTicks: 6,
    recoveryTicks: 18,
    cooldownTicks: 150,
    cooldownGroupId: 0,
    animKey: AnimKey.ranged,
  ),
  'shoggoth.teleport': AbilityDef(
    id: 'shoggoth.teleport',
    category: AbilityCategory.utility,
    hitDelivery: const BossTeleportDelivery(),
    baseDamage: 0,
    baseDamageType: DamageType.physical,
    windupTicks: 36,
    activeTicks: 1,
    recoveryTicks: 54,
    cooldownTicks: 110,
    cooldownGroupId: 0,
    animKey: AnimKey.teleportOut,
  ),
};
