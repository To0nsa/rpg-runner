import '../../combat/damage_type.dart';
import '../../snapshots/enums.dart';
import '../ability_def.dart';

/// Warrior sword arc: two preparation cells, one active cell, one recovery cell.
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
};
