# Combat Pipeline

This document reflects the current Core combat contracts used by `GameCore`.

## Data Primitives

### Damage and Combat IDs

- `DamageType`: `physical`, `fire`, `ice`, `water`, `thunder`, `acid`, `dark`, `bleed`, `earth`, `holy`
- `WeaponId`: stable melee/off-hand IDs
- `ProjectileId`: stable projectile item IDs (throwing + spell projectiles)
- `Faction`: friendly-fire routing

### Status System

- `StatusEffectType`: `dot`, `slow`, `stun`, `haste`, `damageReduction`, `vulnerable`, `weaken`, `drench`, `silence`, `resourceOverTime`
- `StatusProfileId`: authored bundles (for example `slowOnHit`, `burnOnHit`, `arcaneWard`, `stunOnHit`, `restoreHealth`)
- `StatusApplication`: one application entry (magnitude, duration, optional period/type/resource)
- `StatusProfileCatalog`: stable profile lookup

See `docs/gdd/combat/status/status_system_design.md`.

## ECS Stores

### Health and Damage

| Store | Purpose |
|---|---|
| `HealthStore` | Current/max HP |
| `DamageResistanceStore` | Per-type incoming modifier bp |
| `InvulnerabilityStore` | Post-hit i-frame ticks |
| `LastDamageStore` | Last lethal/non-lethal source details |

### Status Effects

| Store | Purpose |
|---|---|
| `DotStore` | Active DoT channels (by damage type) |
| `SlowStore` | Active slow |
| `HasteStore` | Active haste |
| `DamageReductionStore` | Active ward-style direct-hit reduction |
| `VulnerableStore` | Incoming-damage amplification |
| `WeakenStore` | Outgoing-damage reduction |
| `DrenchStore` | Action-speed reduction |
| `ResourceOverTimeStore` | Timed health/mana/stamina restore |
| `StatusImmunityStore` | Per-status immunity mask |
| `StatModifierStore` | Derived move/action speed modifiers |
| `ControlLockStore` | Stun/cast/etc. lock flags |

### Loadout and Tags

| Store | Purpose |
|---|---|
| `EquippedLoadoutStore` | Equipped gear + ability IDs |
| `CreatureTagStore` | Shared creature tags |

## Combat Tick Order (Current)

Combat-relevant order inside `GameCore.stepOneTick`:

1. `ControlLockSystem.step`
2. `ActiveAbilityPhaseSystem.step`
3. `AbilityChargeTrackingSystem.step`
4. `HoldAbilitySystem.step`
5. Intent writing/execution systems (self/melee/projectile/mobility)
6. Hit resolution systems queue `DamageRequest`/`StatusRequest`
7. `StatusSystem.tickExisting`
8. `DamageMiddlewareSystem.step`
9. `DamageSystem.step`
10. `StatusSystem.applyQueued`

## Damage Pipeline

### `DamageRequest`

```dart
DamageRequest {
  target,
  amount100,
  damageType,
  critChanceBp,
  procs,
  source,
  sourceKind,
  sourceEnemyId,
  sourceProjectileId,
}
```

### Resolution Order in `DamageSystem`

1. Skip if no health or invulnerable
2. Apply attacker `weaken` (outgoing penalty)
3. Roll/apply crit
4. Apply global defense (`ResolvedCharacterStats.applyDefense`)
5. Apply typed modifier: `baseTypedModBp + gearIncomingModBp`
6. Apply target `vulnerable`
7. Clamp `>= 0`, subtract HP
8. Record `LastDamageStore`, emit callbacks, process forced interrupt on damage-taken
9. Queue on-hit proc statuses
10. Apply i-frames

## Status Pipeline

### `StatusSystem.tickExisting`

- Ticks and applies periodic damage from `DotStore`
- Ticks `ResourceOverTimeStore` and applies smooth resource restoration
- Ticks `slow/haste/damageReduction/vulnerable/weaken/drench`
- Queues DoT `DamageRequest`s

### `StatusSystem.applyQueued`

- Resolves `StatusProfileId` -> applications
- Applies immunity checks and optional damage-type scaling
- Applies or refreshes status stores
- Applies stun/cast locks in `ControlLockStore`
- Refreshes derived move/action modifiers

### Damage middleware note

- `WardMiddleware` consumes `DamageReductionStore`:
  - direct hits are reduced by ward magnitude
  - DoT (`DeathSourceKind.statusEffect`) is canceled while ward is active

## Projectile Items (Spells + Throws)

Projectile abilities use one execution path while payload is resolved from the equipped projectile source:

- Throwing weapon (`ProjectileId.throwingKnife`/`throwingAxe`) or
- Spell projectile selected from spellbook grants (`projectileSlotSpellId`)

Core systems involved: `AbilityActivationSystem`, `ProjectileLaunchSystem`, `ProjectileHitSystem`, `ProjectileWorldCollisionSystem`, `DamageSystem`.

## Mobility Abilities

Mobility is authored as `AbilityCategory.mobility` and can include optional contact effects via `MobilityImpactDef`.

- Commits through `AbilityActivationSystem`
- Execution through `MobilitySystem`
- Contact overlaps through `MobilityImpactSystem`
- Mobility press preempts queued/active combat intents

## Extension Notes

### Add a new status

1. Add `StatusEffectType`
2. Add/extend status store(s)
3. Add apply/tick logic in `StatusSystem`
4. Add immunity bit mapping
5. Add `StatusProfileId` + catalog entries

### Add a new damage type

1. Add enum in `DamageType`
2. Add fields/switch handling in `DamageResistanceStore` and stat bonuses/resolver
3. Update authoring + tests for neutral/resist/vulnerable cases
