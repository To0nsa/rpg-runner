import '../../combat/voidcaller_pose_catalog.dart';
import '../../combat/damage_type.dart';
import '../../snapshots/enums.dart';
import '../ability_def.dart';
import '../../enemies/enemy_id.dart';
import '../../bosses/boss_utility_delivery.dart';
import '../../projectiles/projectile_id.dart';
import '../../spell_impacts/spell_impact_id.dart';

/// Timings use 60 Hz authoring ticks; cooldown group zero is local to each actor.
final Map<AbilityKey, AbilityDef> voidcallerAbilityDefs = {
  'voidcaller.vertical_beam': AbilityDef(
    id: 'voidcaller.vertical_beam',
    category: AbilityCategory.ranged,
    hitDelivery: const TargetPointHitDelivery(
      profile: VoidcallerPoseCatalog.voidVerticalBeam,
      stepTimeSeconds: .08,
      hitPolicy: HitPolicy.oncePerTarget,
      impactEffectId: SpellImpactId.voidVerticalBeam,
      anchor: TargetPointAnchor.surfaceBelow,
    ),
    baseDamage: 700,
    baseDamageType: DamageType.dark,
    windupTicks: 48,
    activeTicks: 6,
    recoveryTicks: 24,
    cooldownTicks: 130,
    cooldownGroupId: 0,
    animKey: AnimKey.cast,
  ),
  'voidcaller.diagonal_beam': AbilityDef(
    id: 'voidcaller.diagonal_beam',
    category: AbilityCategory.ranged,
    hitDelivery: const TargetPointHitDelivery(
      profile: VoidcallerPoseCatalog.voidDiagonalBeam,
      stepTimeSeconds: .08,
      hitPolicy: HitPolicy.oncePerTarget,
      impactEffectId: SpellImpactId.voidDiagonalBeam,
      anchor: TargetPointAnchor.surfaceBelow,
    ),
    baseDamage: 700,
    baseDamageType: DamageType.dark,
    windupTicks: 48,
    activeTicks: 6,
    recoveryTicks: 24,
    cooldownTicks: 130,
    cooldownGroupId: 0,
    animKey: AnimKey.ranged,
  ),
  'voidcaller.claw': AbilityDef(
    id: 'voidcaller.claw',
    category: AbilityCategory.ranged,
    hitDelivery: const ProjectileHitDelivery(
      projectileId: ProjectileId.voidClaw,
    ),
    baseDamage: 600,
    baseDamageType: DamageType.fire,
    windupTicks: 36,
    activeTicks: 6,
    recoveryTicks: 24,
    cooldownTicks: 100,
    cooldownGroupId: 0,
    animKey: AnimKey.strike2,
  ),
  'voidcaller.summon': AbilityDef(
    id: 'voidcaller.summon',
    category: AbilityCategory.utility,
    hitDelivery: const BossSummonDelivery(
      enemyId: EnemyId.voidTentacle,
      maxAlive: 2,
      lifetimeSeconds: 12,
    ),
    baseDamage: 0,
    baseDamageType: DamageType.physical,
    windupTicks: 60,
    activeTicks: 6,
    recoveryTicks: 24,
    cooldownTicks: 150,
    cooldownGroupId: 0,
    animKey: AnimKey.ranged,
  ),
};
