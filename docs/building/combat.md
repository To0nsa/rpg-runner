# Combat Pipeline

This document describes the Core combat primitives and how to extend them.

> **Reusability**: All combat systems work for any entity with the required components (player, enemies, NPCs). Design additions to be entity-agnostic.

## Data Primitives

### Damage & Combat IDs

- `DamageType`: Categories for resistance/vulnerability (physical, fire, ice, thunder, bleed)
- `WeaponId`: Stable IDs for melee weapons
- `RangedWeaponId`: Stable IDs for ranged/thrown weapons
- `AmmoType`: Ammo categories for ranged weapons
- `SpellId`: Stable IDs for spells (iceBolt, thunderBolt, fireBolt)
- `ProjectileId`: Stable IDs for projectile types
- `Faction`: Entity faction for friendly-fire rules

### Status System

- `StatusEffectType`: Runtime status categories (burn, slow, bleed, stun)
- `StatusProfileId`: Stable IDs for on-hit status bundles (none, iceBolt, fireBolt, meleeBleed, stunOnHit)
- `StatusApplication`: Single effect config (type, magnitude, duration, period)
- `StatusProfile`: Bundle of applications applied on hit
- `StatusProfileCatalog`: Maps IDs to application lists

### Definitions

- `WeaponDef`: Melee weapon stats (damageType, statusProfileId)
- `RangedWeaponDef`: Ranged weapon stats (damage, ammo cost, cooldown)
- `SpellDef`: Spell properties (stats, projectileId)
- `ProjectileSpellStats`: Combat stats (manaCost, damage, damageType, statusProfileId)

## Stores (ECS Components)

### Health & Damage

| Store | Purpose |
|-------|---------|
| `HealthStore` | Current/max HP per entity |
| `DamageResistanceStore` | Per-type damage modifiers (physical, fire, ice, thunder, bleed) |
| `InvulnerabilityStore` | I-frame ticks remaining after damage |
| `LastDamageStore` | Source tracking for death events/analytics |

### Status Effects

| Store | Purpose |
|-------|---------|
| `BurnStore` | Active burn DoT state (SoA) |
| `BleedStore` | Active bleed DoT state (SoA) |
| `SlowStore` | Active slow state (SoA) |
| `StunStore` | Active stun state (SoA) |
| `StatusImmunityStore` | Per-entity status immunities |
| `StatModifierStore` | Derived modifiers (e.g., move speed from slow) |

### Equipment

| Store | Purpose |
|-------|---------|
| `EquippedWeaponStore` | Per-entity melee weapon selection |
| `EquippedRangedWeaponStore` | Per-entity ranged weapon selection |
| `EquippedSpellStore` | Per-entity spell selection |
| `AmmoStore` | Per-entity ammo pools for ranged weapons |

### Other

| Store | Purpose |
|-------|---------|
| `CreatureTagStore` | Reusable tags (humanoid, flying, etc.) |

## Systems (Tick Order)

```
1. StatusSystem.tickExisting   → Ticks DoTs, queues damage requests
2. DamageSystem.step           → Applies damage, queues status profiles
3. StatusSystem.applyQueued    → Applies profiles, refreshes stat modifiers
```

## Damage Pipeline

### DamageRequest Flow

```dart
DamageRequest {
  target: EntityId,
  amount: double,
  damageType: DamageType,
  statusProfileId: StatusProfileId,
  source: EntityId?,
  sourceKind: DeathSourceKind,
  sourceEnemyId: EnemyId?,
  sourceProjectileId: ProjectileId?,
  sourceSpellId: SpellId?,
}
```

### Damage Formula

```
finalDamage = baseDamage × (1 + resistanceMod)
```

Where `resistanceMod` is looked up from `DamageResistanceStore` by `DamageType`:
- Positive mod = vulnerability (e.g., +0.5 = 50% more damage)
- Negative mod = resistance (e.g., -0.25 = 25% less damage)
- Zero mod = neutral

### DamageSystem Processing

1. Resolve target's `HealthStore` component
2. Check `InvulnerabilityStore` for i-frames → skip if active
3. Apply resistance modifier from `DamageResistanceStore`
4. Reduce `HealthStore.hp`
5. Record in `LastDamageStore` (for death messages/analytics)
6. Queue status effects via `StatusRequest` if `statusProfileId != none`
7. Apply i-frames to `InvulnerabilityStore`

## Status Effect Pipeline

### StatusSystem.tickExisting

- Ticks `BurnStore`: applies fire damage per period
- Ticks `BleedStore`: applies bleed damage per period
- Ticks `SlowStore`: reduces duration, removes when expired
- Ticks `StunStore`: reduces duration, removes when expired
- Queues `DamageRequest` for DoT damage

### StatusSystem.applyQueued

- Processes pending `StatusRequest` queue
- Looks up `StatusProfile` from catalog
- For each `StatusApplication`:
  - Check `StatusImmunityStore` → skip if immune
  - Apply magnitude scaling if `scaleByDamageType` (uses resistance mod)
  - Add/refresh appropriate store (burn, bleed, slow, stun)
- Refreshes `StatModifierStore` (e.g., move speed from slow)

## Spell System

### SpellDef Structure

```dart
SpellDef {
  stats: ProjectileSpellStats {
    manaCost: double,
    damage: double,
    damageType: DamageType,
    statusProfileId: StatusProfileId,
  },
  projectileId: ProjectileId?,
}
```

### Spell Catalog

| SpellId | Damage Type | Status Profile | Mana Cost |
|---------|-------------|----------------|-----------|
| `iceBolt` | ice | iceBolt (slow) | 10 |
| `fireBolt` | fire | fireBolt (burn) | 12 |
| `thunderBolt` | thunder | none | 10 |

### Spell Flow

1. Player casts spell → `EquippedSpellStore` lookup
2. Check mana cost vs `ManaStore`
3. Spawn projectile with `SpellDef` combat stats
4. Projectile hits target → `DamageRequest` with spell metadata
5. `DamageSystem` processes → applies damage + queues status

## Ranged / Thrown Weapons (Not Spells)

Ranged weapons are intentionally separate from spells:

- **Costs**: Stamina + ammo (no mana, no `SpellId`)
- **Output**: Weapon projectiles using the same `DamageRequest` + `StatusProfileId` pipeline
- **Ballistic**: Participate in `CollisionSystem`, despawn on first world collision

### Key Pieces

- **Data**: `RangedWeaponDef`/`RangedWeaponCatalog`, `AmmoType`
- **Stores**: `EquippedRangedWeaponStore`, `AmmoStore`, `RangedWeaponIntentStore`
- **Systems**:
  - `PlayerRangedWeaponSystem` writes intents from input
  - `RangedWeaponAttackSystem` spawns projectiles, spends resources, sets cooldown
  - `ProjectileWorldCollisionSystem` removes ballistic projectiles on collision

## Melee Weapons

### WeaponDef Structure

```dart
WeaponDef {
  id: WeaponId,
  damageType: DamageType,
  statusProfileId: StatusProfileId,
}
```

Melee weapons contribute `damageType` and `statusProfileId` to the `DamageRequest` when hits are processed.

## Extending with a New Status

1. Add a new `StatusEffectType` value
2. Create a new SparseSet store in `lib/core/ecs/stores/status/`
3. Add store to `EcsWorld`
4. Implement apply + tick logic in `StatusSystem`
5. Add a new `StatusProfileId` entry in the catalog
6. Test with determinism checks

## Extending with a New Damage Type

1. Add value to `DamageType` enum
2. Add field to `DamageResistanceDef` and `DamageResistanceStore`
3. Update `modFor()` / `modForIndex()` switch statements
4. Test resistance/vulnerability interactions

## Mobility Abilities (TODO)

_Section placeholder for upcoming mobility system (dash, dodge, jump, teleport)._

Key considerations:
- Abilities should be entity-agnostic (reusable by enemies and other characters if possible and relevant)
- Use command pattern for activation (for player-characters, input events)
- Cooldown tracking via dedicated store
- Events for VFX/SFX triggers
