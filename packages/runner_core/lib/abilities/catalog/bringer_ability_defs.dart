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
    // 60 Hz ticks: 267 ms windup; the complete sweep cycle is 1.5x faster.
    windupTicks: 16,
    activeTicks: 12,
    recoveryTicks: 16,
    cooldownTicks: 72,
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
      // 40 ms frames keep commit-to-damage at least 1.5x faster at 30/60/90 Hz.
      stepTimeSeconds: .04,
      hitPolicy: HitPolicy.oncePerTarget,
      impactEffectId: SpellImpactId.deathPillar,
    ),
    // 60 Hz ticks: 400 ms cast windup, then six harmless warning frames.
    windupTicks: 24,
    activeTicks: 4,
    recoveryTicks: 12,
    cooldownTicks: 100,
    cooldownGroupId: 0,
    animKey: AnimKey.cast,
    baseDamage: 700,
    knockback: const KnockbackDef(distance: 112, durationSeconds: .28),
    baseDamageType: DamageType.dark,
  ),
};
