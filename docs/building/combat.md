# Combat Pipeline

This document describes the Core combat primitives and how to extend them.

## Data primitives

- `DamageType`: categories used by resistance/vulnerability.
- `StatusProfileId`: stable IDs for on-hit status bundles.
- `StatusProfileCatalog`: maps IDs to application lists.
- `WeaponId`: stable IDs for melee weapons.

## Stores

- `DamageResistanceStore`: per-entity damage modifiers.
- `StatusImmunityStore`: per-entity status immunities.
- `EquippedWeaponStore`: per-entity melee weapon selection.
- `BurnStore`, `BleedStore`, `SlowStore`: active status state (SoA).
- `StatModifierStore`: derived modifiers (e.g., move speed).
- `CreatureTagStore`: reusable tags (humanoid, flying, etc.).

## Systems (tick order)

1. `StatusSystem.tickExisting`: ticks DoTs and queues damage.
2. `DamageSystem.step`: applies damage, queues status profiles.
3. `StatusSystem.applyQueued`: applies profiles + refreshes modifiers.

## Extending with a new status

1. Add a new `StatusEffectType` value.
2. Create a new SparseSet store if it needs state.
3. Implement apply + tick logic in `StatusSystem`.
4. Add a new `StatusProfileId` entry in the catalog.
