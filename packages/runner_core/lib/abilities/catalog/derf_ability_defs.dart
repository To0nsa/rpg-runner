import '../../combat/combat_pose_catalog.dart';

import 'package:runner_core/combat/damage_type.dart';

import '../../snapshots/enums.dart';
import '../../spell_impacts/spell_impact_id.dart';
import '../ability_def.dart';

/// Derf-authored abilities.
final Map<AbilityKey, AbilityDef> derfAbilityDefs = <AbilityKey, AbilityDef>{
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
};
