# Combat Pipeline

This document describes the Core combat primitives and how to extend them.

> **Reusability**: All combat systems work for any entity with the required components (player, enemies, NPCs). Design additions to be entity-agnostic.

Balance framework:

- `docs/gdd/combat/balance/README.md`
- `docs/gdd/combat/balance/balance_invariants.md`
- `docs/gdd/combat/balance/scenario_matrix.md`
- `docs/gdd/combat/balance/ability_tuning_template.md`

## Data Primitives

### Damage & Combat IDs

- `DamageType`: Categories for resistance/vulnerability (physical, fire, ice, thunder, bleed)
- Detailed resistance design + runtime contract: `docs/gdd/combat/resistance/resistance_system_design.md`
- `WeaponId`: Stable IDs for melee weapons
- `ProjectileId`: Stable ID used for projectile slot items and spawned projectile identity
- `Faction`: Entity faction for friendly-fire rules

### Status System

- `StatusEffectType`: Runtime status categories (burn, slow, bleed, stun, haste)
- `StatusProfileId`: Stable IDs for status bundles (none, iceBolt, fireBolt, meleeBleed, stunOnHit, speedBoost)
- `StatusApplication`: Single effect config (type, magnitude, duration, period)
- `StatusProfile`: Bundle of applications applied on hit
- `StatusProfileCatalog`: Maps IDs to application lists
- Detailed design + runtime contract: `docs/gdd/combat/status/status_system_design.md`

### Definitions

- `WeaponDef`: Melee/off-hand weapon payload (damageType, procs, stats, weaponType)
- `ProjectileDef`: Projectile slot item payload (spells + throws: projectileId, speed/lifetime/collider tuning, ballistic/gravity, damageType, procs, stats, weaponType)

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
| `StatusImmunityStore` | Per-entity status immunities |
| `StatModifierStore` | Derived modifiers (e.g., move speed from slow) |
| `ControlLockStore` | Action gating (stun, move, cast, etc.) |

### Equipment

| Store | Purpose |
|-------|---------|
| `EquippedLoadoutStore` | Per-entity loadout (weapons, projectile item, ability IDs, slot masks) |

### Other

| Store | Purpose |
|-------|---------|
| `CreatureTagStore` | Reusable tags (humanoid, flying, etc.) |

## Systems (Tick Order)

```
1. StatusSystem.tickExisting    → Ticks DoTs, queues damage requests
2. ControlLockSystem.step       → Refreshes active lock masks, clears expired locks
3. DamageMiddlewareSystem.step  → Applies combat rule edits/cancellations
4. DamageSystem.step            → Applies damage, rolls procs, queues status
5. StatusSystem.applyQueued     → Applies profiles, refreshes stat modifiers
```

## Damage Pipeline

### DamageRequest Flow

```dart
DamageRequest {
  target: EntityId,
  amount100: int,
  damageType: DamageType,
  procs: List<WeaponProc>,
  source: EntityId?,
  sourceKind: DeathSourceKind,
  sourceEnemyId: EnemyId?,
  sourceProjectileId: ProjectileId?,
}
```

### Damage Queue & Middleware

- Hit resolution systems append `DamageRequest` entries to `EcsWorld.damageQueue`.
- `DamageMiddlewareSystem` can cancel/modify queued damage (e.g., parry, shields).
- `DamageSystem` consumes the queue and skips canceled entries.

### Damage Formula

```
amountAfterCrit = applyCrit(baseDamage, critChanceBp)
amountAfterDefense = applyDefense(amountAfterCrit, defenseBonusBp)
combinedTypedMod = storeTypedModBp + (-gearTypedResistanceBp)
finalDamage = amountAfterDefense × (1 + combinedTypedMod)
```

Where:
- `storeTypedModBp` comes from `DamageResistanceStore` by `DamageType`.
- `gearTypedResistanceBp` comes from resolved gear stats.
- Positive combined mod = vulnerability (more damage).
- Negative combined mod = resistance (less damage).
- Zero combined mod = neutral.

### DamageSystem Processing

1. Resolve target's `HealthStore` component
2. Check `InvulnerabilityStore` for i-frames → skip if active
3. Resolve crit outcome and crit-adjusted amount
4. Apply global defense from resolved loadout stats
5. Apply combined typed modifier (`store + gear`)
6. Reduce `HealthStore.hp`
7. Record in `LastDamageStore` (for death messages/analytics)
8. Roll `procs` (onHit) for non-zero `amount100` and queue `StatusRequest` for triggered effects
9. Apply i-frames to `InvulnerabilityStore`

## Status Effect Pipeline

### StatusSystem.tickExisting

- Ticks `BurnStore`: applies fire damage per period
- Ticks `BleedStore`: applies bleed damage per period
- Ticks `SlowStore`: reduces duration, removes when expired
- Queues `DamageRequest` for DoT damage
- (*Note*: Stun expiry is handled by `ControlLockSystem`)

### StatusSystem.applyQueued

- Processes pending `StatusRequest` queue
- Looks up `StatusProfile` from catalog
- For each `StatusApplication`:
  - Check `StatusImmunityStore` → skip if immune
  - Apply magnitude scaling if `scaleByDamageType` (uses resistance mod)
  - Add/refresh appropriate store (burn, bleed, slow)
- For Stun: Adds lock to `ControlLockStore` and clears active intents (Melee, Projectile, Dash)
- Refreshes `StatModifierStore` (e.g., move speed from slow)

## Projectile Items (Spells + Throws)

Projectile slot items unify spells and throwing weapons under a single data
structure (`ProjectileDef`) and a single execution pipeline.

### Key Pieces

- **Data**: `ProjectileDef`/`ProjectileCatalog` (payload + motion/collider: id, speed/lifetime/collider, damageType, procs, stats)
- **Stores**: `EquippedLoadoutStore`, `ProjectileIntentStore`, `ProjectileOriginStore`
- **Systems**:
  - `AbilityActivationSystem` writes `ProjectileIntentDef` from player input
  - `ProjectileLaunchSystem` validates costs/cooldown, spawns projectiles, sets cooldowns
  - `ProjectileHitSystem` applies `DamageRequest` with `sourceProjectileId`
  - `ProjectileWorldCollisionSystem` removes ballistic projectiles on collision

### Projectile Flow

1. Player presses projectile → `AbilityActivationSystem` resolves ability + projectile item.
2. `ProjectileLaunchSystem` checks costs, sets `projectileCooldownTicksLeft`, spawns projectile.
3. Projectile hits target → `DamageRequest` with `sourceProjectileId`.
4. `DamageSystem` processes → applies damage + queues status/procs.

## Melee Weapons

### WeaponDef Structure

```dart
WeaponDef {
  id: WeaponId,
  weaponType: WeaponType,
  damageType: DamageType,
  procs: List<WeaponProc>,
  stats: GearStatBonuses,
}
```

Melee weapons contribute `damageType` and `procs` to the hit payload (merged with ability/buff/passive procs).

## Control Locks

We use a bitmask-based locking system to prevent actions (Stun, Move, Cast, etc.).

### ControlLockStore

- Stores `activeMask` and per-flag `untilTick` values.
- `LockFlag.stun` (Bit 0) is the master lock that blocks everything.
- `addLock(flag, duration)` refreshes expiry using `max(current, new)`.

### Gate Checks

Systems check `isLocked(flag)` or `isStunned()` before processing:
  - `isStunned()` -> Blocks Intent Creation (Melee, Projectile) and Movement (Input, Locomotion).

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
