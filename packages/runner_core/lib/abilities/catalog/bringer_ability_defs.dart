import '../../combat/combat_pose_catalog.dart';
import '../../combat/damage_type.dart';
import '../../combat/knockback.dart';
import '../../snapshots/enums.dart';
import '../../spell_impacts/spell_impact_id.dart';
import '../ability_def.dart';

/// First boss: committed scythe sweeps and captured-position death pillars.
final Map<AbilityKey, AbilityDef> bringerAbilityDefs = {
  'bringer.scythe_sweep': AbilityDef(
    id: 'bringer.scythe_sweep',
    category: AbilityCategory.melee,
    hitDelivery: MeleeHitDelivery(
      profile: CombatPoseCatalog.bringerScythe,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    // 60 Hz ticks: readable 400 ms windup, three blade frames, long recovery.
    windupTicks: 24,
    activeTicks: 18,
    recoveryTicks: 24,
    cooldownTicks: 108,
    cooldownGroupId: 0,
    animKey: AnimKey.strike,
    baseDamage: 800,
    knockback: const KnockbackDef(distance: 112, durationSeconds: .28),
    baseDamageType: DamageType.physical,
  ),
  'bringer.death_pillar': AbilityDef(
    id: 'bringer.death_pillar',
    category: AbilityCategory.ranged,
    targetingModel: TargetingModel.aimed,
    hitDelivery: TargetPointHitDelivery(
      profile: CombatPoseCatalog.bringerPillar,
      stepTimeSeconds: .08,
      hitPolicy: HitPolicy.oncePerTarget,
      impactEffectId: SpellImpactId.deathPillar,
    ),
    // The target is captured on commit. Six harmless ring frames precede damage.
    windupTicks: 36,
    activeTicks: 6,
    recoveryTicks: 18,
    cooldownTicks: 150,
    cooldownGroupId: 0,
    animKey: AnimKey.cast,
    baseDamage: 700,
    knockback: const KnockbackDef(distance: 112, durationSeconds: .28),
    baseDamageType: DamageType.dark,
  ),
};
