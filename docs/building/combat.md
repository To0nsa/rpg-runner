# Combat Pipeline

This document describes the Core combat primitives and how to extend them.

## Data primitives

- `DamageType`: categories used by resistance/vulnerability.
- `StatusProfileId`: stable IDs for on-hit status bundles.
- `StatusProfileCatalog`: maps IDs to application lists.
- `WeaponId`: stable IDs for melee weapons.
- `RangedWeaponId`: stable IDs for ranged/thrown weapons.
- `AmmoType`: ammo categories for ranged weapons.

## Stores

- `DamageResistanceStore`: per-entity damage modifiers.
- `StatusImmunityStore`: per-entity status immunities.
- `EquippedWeaponStore`: per-entity melee weapon selection.
- `EquippedRangedWeaponStore`: per-entity ranged weapon selection.
- `AmmoStore`: per-entity ammo pools for ranged weapons.
- `BurnStore`, `BleedStore`, `SlowStore`: active status state (SoA).
- `StatModifierStore`: derived modifiers (e.g., move speed).
- `CreatureTagStore`: reusable tags (humanoid, flying, etc.).

## Systems (tick order)

1. `StatusSystem.tickExisting`: ticks DoTs and queues damage.
2. `DamageSystem.step`: applies damage, queues status profiles.
3. `StatusSystem.applyQueued`: applies profiles + refreshes modifiers.

## Ranged / thrown weapons (not spells)

Ranged weapons are intentionally separate from spells:

- Costs: stamina + ammo (no mana, no `SpellId`).
- Output: weapon projectiles that still use the same `DamageRequest` +
  `StatusProfileId` pipeline as other hits.
- Ballistic projectiles participate in `CollisionSystem` (world collision) and
  despawn immediately on first world collision.

Key pieces:

- Data: `RangedWeaponDef`/`RangedWeaponCatalog`, `AmmoType`.
- Stores: `EquippedRangedWeaponStore`, `AmmoStore`, `RangedWeaponIntentStore`.
- Systems:
  - `PlayerRangedWeaponSystem` writes intents from input.
  - `RangedWeaponAttackSystem` spawns projectiles, spends resources, sets cooldown.
  - `ProjectileWorldCollisionSystem` removes ballistic projectiles on collision.

## Extending with a new status

1. Add a new `StatusEffectType` value.
2. Create a new SparseSet store if it needs state.
3. Implement apply + tick logic in `StatusSystem`.
4. Add a new `StatusProfileId` entry in the catalog.
