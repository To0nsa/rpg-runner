import '../../combat/combat_pose_catalog.dart';
import '../../combat/damage_type.dart';
import '../../snapshots/enums.dart';
import '../../spell_impacts/spell_impact_id.dart';
import '../ability_def.dart';

/// Normal Derf casts explosions; twisted Derf uses the extended tentacle.
final Map<AbilityKey, AbilityDef> derfAbilityDefs = {
  'derf.fire_explosion': AbilityDef(
    id: 'derf.fire_explosion',
    category: AbilityCategory.ranged,
    targetingModel: TargetingModel.aimed,
    inputLifecycle: AbilityInputLifecycle.holdRelease,
    hitDelivery: TargetPointHitDelivery(
      profile: CombatPoseCatalog.fireExplosion,
      stepTimeSeconds: .05,
      hitPolicy: HitPolicy.oncePerTarget,
      impactEffectId: SpellImpactId.fireExplosion,
    ),
    defaultCost: AbilityResourceCost(manaCost100: 2400),
    // Cast row authored active at frame 5 (1-based).
    windupTicks: 20,
    // Caster release pose; the impact owns its separate damage timeline.
    activeTicks: 8,
    recoveryTicks: 16,
    cooldownTicks: 120,
    animKey: AnimKey.cast,
    baseDamage: 700,
    baseDamageType: DamageType.fire,
  ),
  'derf.tentacle_strike': AbilityDef(
    id: 'derf.tentacle_strike',
    category: AbilityCategory.melee,
    hitDelivery: MeleeHitDelivery(
      profile: CombatPoseCatalog.derfTentacle,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    // At 60 Hz: 300 ms telegraph, 200 ms extension, 200 ms retraction.
    windupTicks: 18,
    activeTicks: 12,
    recoveryTicks: 12,
    cooldownTicks: 60,
    animKey: AnimKey.strike,
    baseDamage: 800,
    baseDamageType: DamageType.physical,
  ),
};
