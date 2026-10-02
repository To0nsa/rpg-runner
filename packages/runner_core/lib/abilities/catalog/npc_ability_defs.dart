import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../weapons/weapon_proc.dart';
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
    // One attack cadence across distance changes and the melee opener sequence.
    cooldownGroupId: CooldownGroup.primary,
    animKey: AnimKey.cast,
  ),
  'npc_huntress.stab': AbilityDef(
    id: 'npc_huntress.stab',
    category: AbilityCategory.melee,
    allowedSlots: {AbilitySlot.primary},
    defaultCost: const AbilityResourceCost(staminaCost100: 400),
    hitDelivery: MeleeHitDelivery(
      sizeX: 48,
      sizeY: 20,
      offsetX: 0,
      offsetY: -3,
      hitPolicy: HitPolicy.oncePerTarget,
    ),
    // 3 direct damage plus the existing 3 DPS / 5 second bleed opener.
    baseDamage: 300,
    baseDamageType: DamageType.physical,
    procs: const [
      WeaponProc(
        hook: ProcHook.onHit,
        statusProfileId: StatusProfileId.meleeBleed,
        chanceBp: 10000,
      ),
    ],
    // Frame 3 is impact in both five-cell melee strips (6 ticks per cell at 60 Hz).
    windupTicks: 18,
    activeTicks: 6,
    recoveryTicks: 6,
    cooldownTicks: 48,
    animKey: AnimKey.strike,
  ),
  'npc_huntress.slash': AbilityDef(
    id: 'npc_huntress.slash',
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
    // Match the warrior's repeat melee damage and cadence; bleed is opener-only.
    baseDamage: 400,
    baseDamageType: DamageType.physical,
    windupTicks: 18,
    activeTicks: 6,
    recoveryTicks: 6,
    cooldownTicks: 48,
    animKey: AnimKey.strike2,
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
