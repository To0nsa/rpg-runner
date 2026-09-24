import '../../combat/damage_type.dart';
import '../../snapshots/enums.dart';
import '../../projectiles/projectile_id.dart';
import '../ability_def.dart';

/// Attacks align execution with the reviewed release/impact cell in each strip.
final Map<AbilityKey, AbilityDef> npcAbilityDefs = {
  'npc_warrior.slash': AbilityDef(
    id: 'npc_warrior.slash',
    category: AbilityCategory.melee,
    allowedSlots: {AbilitySlot.primary},
    defaultCost: const AbilityResourceCost(staminaCost100: 400),
    hitDelivery: MeleeHitDelivery(
      sizeX: 48,
      sizeY: 38,
      offsetX: 0,
      offsetY: -3,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    baseDamage: 400,
    baseDamageType: DamageType.physical,
    windupTicks: 12,
    activeTicks: 6,
    recoveryTicks: 6,
    cooldownTicks: 48,
    animKey: AnimKey.strike,
  ),
  'npc_huntress.throw_spear': AbilityDef(
    id: 'npc_huntress.throw_spear',
    category: AbilityCategory.ranged,
    allowedSlots: {AbilitySlot.projectile},
    defaultCost: const AbilityResourceCost(staminaCost100: 500),
    hitDelivery: ProjectileHitDelivery(projectileId: ProjectileId.npcSpear),
    baseDamage: 450,
    baseDamageType: DamageType.physical,
    windupTicks: 36,
    activeTicks: 6,
    recoveryTicks: 0,
    cooldownTicks: 78,
    animKey: AnimKey.cast,
  ),
  'npc_huntress2.shoot_arrow': AbilityDef(
    id: 'npc_huntress2.shoot_arrow',
    category: AbilityCategory.ranged,
    allowedSlots: {AbilitySlot.projectile},
    defaultCost: const AbilityResourceCost(staminaCost100: 300),
    hitDelivery: ProjectileHitDelivery(projectileId: ProjectileId.npcArrow),
    baseDamage: 300,
    baseDamageType: DamageType.physical,
    windupTicks: 12,
    activeTicks: 6,
    recoveryTicks: 18,
    cooldownTicks: 60,
    animKey: AnimKey.cast,
  ),
};
