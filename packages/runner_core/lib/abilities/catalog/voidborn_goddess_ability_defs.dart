import '../../combat/voidborn_goddess_pose_catalog.dart';
import '../../combat/damage_type.dart';
import '../../snapshots/enums.dart';
import '../ability_def.dart';
import '../../projectiles/projectile_id.dart';
import '../../spell_impacts/spell_impact_id.dart';

/// Timings use 60 Hz authoring ticks; cooldown group zero is local to each actor.
final Map<AbilityKey, AbilityDef> voidbornGoddessAbilityDefs = {
  'goddess.reposition_out': AbilityDef(
    id: 'goddess.reposition_out',
    category: AbilityCategory.mobility,
    hitDelivery: const SelfHitDelivery(),
    windupTicks: 0,
    activeTicks: 18,
    recoveryTicks: 1,
    cooldownTicks: 0,
    animKey: AnimKey.teleportOut,
  ),
  'goddess.reposition_in': AbilityDef(
    id: 'goddess.reposition_in',
    category: AbilityCategory.mobility,
    hitDelivery: const SelfHitDelivery(),
    windupTicks: 0,
    activeTicks: 12,
    recoveryTicks: 18,
    cooldownTicks: 0,
    animKey: AnimKey.spawn,
  ),
  'goddess.dodge': AbilityDef(
    id: 'goddess.dodge',
    category: AbilityCategory.mobility,
    hitDelivery: const SelfHitDelivery(),
    windupTicks: 0,
    // 133 ms vanish; one recovery tick preserves identity for the AI transition.
    activeTicks: 8,
    recoveryTicks: 1,
    cooldownTicks: 0,
    animKey: AnimKey.teleportOut,
  ),
  'goddess.claw_combo': AbilityDef(
    id: 'goddess.claw_combo',
    category: AbilityCategory.melee,
    hitDelivery: const MeleeHitDelivery(
      profile: VoidbornGoddessPoseCatalog.goddessClaws,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 840,
    baseDamageType: DamageType.physical,
    windupTicks: 24,
    activeTicks: 54,
    recoveryTicks: 18,
    cooldownTicks: 150,
    cooldownGroupId: 0,
    animKey: AnimKey.strike,
  ),
  'goddess.orb': AbilityDef(
    id: 'goddess.orb',
    category: AbilityCategory.ranged,
    hitDelivery: const ProjectileHitDelivery(
      projectileId: ProjectileId.goddessOrb,
    ),
    baseDamage: 720,
    baseDamageType: DamageType.dark,
    // 0.45 seconds at 60 Hz: a brisk cast with a visible release warning.
    windupTicks: 27,
    activeTicks: 6,
    recoveryTicks: 24,
    cooldownTicks: 110,
    cooldownGroupId: 0,
    animKey: AnimKey.cast,
  ),
  'goddess.eruption': AbilityDef(
    id: 'goddess.eruption',
    category: AbilityCategory.ranged,
    hitDelivery: const TargetPointHitDelivery(
      profile: VoidbornGoddessPoseCatalog.goddessEruption,
      // Ten warning frames: nominally 0.6 seconds before the slap.
      stepTimeSeconds: .06,
      hitPolicy: HitPolicy.oncePerTarget,
      impactEffectId: SpellImpactId.goddessEruption,
      anchor: TargetPointAnchor.surfaceBelow,
    ),
    baseDamage: 1200,
    baseDamageType: DamageType.dark,
    windupTicks: 60,
    activeTicks: 240,
    recoveryTicks: 36,
    cooldownTicks: 360,
    cooldownGroupId: 0,
    animKey: AnimKey.ranged,
  ),
};
