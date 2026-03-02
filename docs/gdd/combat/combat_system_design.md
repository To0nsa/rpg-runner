# Combat Pipeline

This document tracks the current Core combat contracts used by `GameCore`.

## Data Primitives

### Damage and Combat IDs

- `DamageType`: `physical`, `fire`, `ice`, `water`, `thunder`, `acid`, `dark`, `bleed`, `earth`, `holy`
- `WeaponId`: stable melee/off-hand IDs
- `ReactiveProcHook`: `onDamaged`, `onLowHealth`
- `ProjectileId`: stable projectile item IDs (throwing + spell projectiles)
- `Faction`: friendly-fire routing

### Status System

- `StatusEffectType`: `dot`, `slow`, `stun`, `haste`, `damageReduction`, `vulnerable`, `weaken`, `drench`, `silence`, `resourceOverTime`, `offenseBuff`
- `StatusProfileId`: authored status bundles (for example `slowOnHit`, `burnOnHit`, `arcaneWard`, `focus`, `stunOnHit`, `restoreHealth`)
- `PurgeProfileId`: deterministic purge bundles (currently `cleanse`)
- `StatusApplication`: one profile application entry (magnitude, duration, period, optional type/resource metadata)
- `StatusProfileCatalog`: profile lookup

See `docs/gdd/combat/status/status_system_design.md`.

## ECS Stores (Combat-Relevant)

### Health, Damage, and Queues

| Store | Purpose |
|---|---|
| `HealthStore` | Current/max HP |
| `DamageResistanceStore` | Per-type incoming modifier bp |
| `InvulnerabilityStore` | Post-hit i-frame ticks |
| `LastDamageStore` | Last lethal/non-lethal source details |
| `DamageQueueStore` | Pending `DamageRequest`s processed by middleware + damage system |

### Status Effects

| Store | Purpose |
|---|---|
| `DotStore` | Active DoT channels (per damage type) |
| `SlowStore` | Active slow |
| `HasteStore` | Active haste |
| `DamageReductionStore` | Active ward-style direct-hit reduction |
| `OffenseBuffStore` | Active outgoing power/crit buff |
| `VulnerableStore` | Incoming-damage amplification |
| `WeakenStore` | Outgoing-damage reduction |
| `DrenchStore` | Action-speed reduction |
| `ResourceOverTimeStore` | Timed health/mana/stamina restoration |
| `StatusImmunityStore` | Per-status immunity mask |
| `StatModifierStore` | Derived move/action speed modifiers |
| `ControlLockStore` | Stun/cast lock flags |

### Ability State and Intents

| Store | Purpose |
|---|---|
| `ActiveAbilityStateStore` | Authoritative committed ability phase/timing |
| `AbilityInputBufferStore` | Buffered combat input during recovery |
| `MeleeIntentStore` | Queued melee execution payload |
| `ProjectileIntentStore` | Queued projectile execution payload |
| `SelfIntentStore` | Queued self-ability execution payload |
| `MobilityIntentStore` | Queued mobility execution payload |
| `AbilityChargeStore` | Authoritative held-duration charge state |

### Reactive/Guard Subsystems

| Store | Purpose |
|---|---|
| `ReactiveDamageEventQueueStore` | Post-damage outcomes consumed by reactive procs |
| `ReactiveProcCooldownStore` | Per-entity reactive proc internal cooldowns |
| `ParryConsumeStore` | One-riposte-per-activation guard bookkeeping |
| `RiposteStore` | Temporary one-shot riposte bonus |

### Loadout and Tags

| Store | Purpose |
|---|---|
| `EquippedLoadoutStore` | Equipped gear + ability IDs + slot mask + projectile slot spell selection |
| `CreatureTagStore` | Shared creature tags |

## Combat Tick Order (Current)

Combat-relevant ordering inside `GameCore.stepOneTick`:

1. `ControlLockSystem.step`
2. `ActiveAbilityPhaseSystem.step`
3. `AbilityChargeTrackingSystem.step`
4. `HoldAbilitySystem.step`
5. `AbilityActivationSystem.step` (player input -> intent commit)
6. Enemy combat intent writers: `EnemyCastSystem.step`, `EnemyMeleeSystem.step`
7. Intent execution: `SelfAbilitySystem.step`, `MeleeStrikeSystem.step`, `ProjectileLaunchSystem.step`
8. `HitboxFollowOwnerSystem.step`
9. Hit/contact resolution: `ProjectileHitSystem.step`, `HitboxDamageSystem.step`, `MobilityImpactSystem.step`
10. `ProjectileWorldCollisionSystem.step`
11. `EntityVisualCueCoalescer.resetForTick`
12. `StatusSystem.tickExisting`
13. `DamageMiddlewareSystem.step`
14. `DamageSystem.step`
15. `ReactiveProcSystem.step`
16. `StatusSystem.applyQueued`
17. `EntityVisualCueCoalescer.emit`

Notes:
- Player mobility/jump presses preempt queued/active combat intents before mobility/jump commit.
- Death/despawn handling runs after combat processing.

## Damage Pipeline

### `DamageRequest`

```dart
DamageRequest {
  target,
  amount100,
  critChanceBp,
  damageType,
  procs,
  source,
  sourceKind,
  sourceEnemyId,
  sourceProjectileId,
}
```

### Middleware Stage (`DamageMiddlewareSystem`)

Current middleware stack order:

1. `ParryMiddleware`
2. `WardMiddleware`

`ParryMiddleware`:
- Applies only while a configured guard ability is active (`AbilityPhase.active`).
- Ignores status-effect sourced damage (`DeathSourceKind.statusEffect`).
- Can reduce or cancel direct-hit queue entries.
- Can grant a one-shot riposte bonus at most once per guard activation.

`WardMiddleware`:
- Reduces direct-hit queued damage by `DamageReductionStore` magnitude.
- Cancels DoT/status-sourced queued damage while ward is active.

### Resolution Order in `DamageSystem`

Per uncanceled queue entry:

1. Skip when target has no `HealthStore` entry.
2. Skip when target has active i-frames (`InvulnerabilityStore.ticksLeft > 0`).
3. Apply source-side `weaken` outgoing penalty (when source entity exists and is weakened).
4. Roll/apply crit from `critChanceBp` (`+50%` crit bonus in V1 runtime).
5. Apply global defense (`ResolvedCharacterStats.applyDefense`).
6. Apply typed modifier: `DamageResistanceStore` typed mod + gear typed incoming mod.
7. Apply target `vulnerable` amplification.
8. Clamp `>= 0`, subtract HP, detect kill.
9. If HP changed (`nextHp < prevHp`):
   - process forced interrupt (`damageTaken`) when policy allows,
   - update `LastDamageStore`,
   - emit `onDamageApplied` callback,
   - enqueue `ReactiveDamageEventQueueStore` outcome.
10. Queue proc statuses when `amount100 > 0` and procs exist:
   - `onHit` -> target,
   - `onCrit` -> target (only if crit happened),
   - `onKill` -> source entity (only if this hit killed target),
   - chance roll per proc.
11. Apply post-hit i-frames.

Important nuance:
- Reactive proc outcomes are queued only when applied damage is non-zero.
- Proc status roll gating uses request `amount100 > 0` (not post-middleware/post-defense applied amount).

## Status Pipeline

### `StatusSystem.tickExisting`

Order inside `tickExisting`:

1. Apply pending purges.
2. Tick/apply `DotStore` pulses and queue DoT `DamageRequest`s.
3. Tick/apply smooth `ResourceOverTimeStore` restoration.
4. Tick durations for `damageReduction`, `offenseBuff`, `haste`, `slow`, `vulnerable`, `weaken`, `drench`.

### `StatusSystem.applyQueued`

Per queued status application:

1. Skip dead targets and targets without health.
2. Resolve profile -> applications.
3. Apply invulnerability blocking rules:
   - blocked while invulnerable: `dot`, `slow`, `stun`, `vulnerable`, `weaken`, `drench`, `silence`
   - not blocked: `haste`, `damageReduction`, `resourceOverTime`, `offenseBuff`
4. Apply `StatusImmunityStore` checks.
5. Apply optional damage-type scaling where authored (`scaleByDamageType`).
6. Apply/refresh status stores with strongest-wins and longer-duration tie behavior.
7. Refresh derived move/action modifiers.

Control-lock behavior:
- `stun`: adds `LockFlag.stun`, clears pending combat intents, cancels dash.
- `silence`: adds `LockFlag.cast`; additionally interrupts enemy projectile-slot casts only when they are still in windup.

### Purge Processing

`PurgeProfileId.cleanse` currently:
- removes `dot`, `slow`, `vulnerable`, `weaken`, `drench`
- clears `LockFlag.cast | LockFlag.stun`

## Projectile Payload Source Resolution

Projectile-slot cast payload resolution is deterministic and slot-aware.

For `AbilityPayloadSource.projectile`:

1. `resolveProjectilePayloadForAbilitySlot` first checks `projectileSlotSpellId` when slot is `AbilitySlot.projectile`.
2. Selected projectile spell is used only if:
   - it exists in `ProjectileCatalog`,
   - it is `WeaponType.spell`,
   - ability `requiredWeaponTypes` is empty or includes `WeaponType.spell`.
3. Otherwise fallback is equipped `projectileId`.

Proc merge rule for projectile-slot spell payloads:
- order is projectile item procs first, spellbook procs second.

Character policy note:
- `PlayerCatalog.projectileSlotAllowsThrowingWeapon` defines whether projectile-slot payload may use throwing fallback.
- Eloise currently sets this to `false`; UI/meta normalization enforces spell selection for projectile slot payload in that case.

## Payload Assembly (`HitPayloadBuilder`)

`AbilityActivationSystem` builds payloads through `HitPayloadBuilder` with this order:

1. Start from ability base payload (`baseDamage`, `baseDamageType`, ability procs).
2. Apply global offensive bonuses (`globalPowerBonusBp`, `globalCritChanceBonusBp`), including active `OffenseBuffStore` bonuses.
3. Apply optional payload-source damage-type override.
4. Merge proc lists in canonical order: ability -> item -> buffs -> passives.
5. Deduplicate procs by `(hook, statusProfileId)` key and clamp crit chance to `[0, 10000]`.

Damage type override rule:
- payload-source weapon damage type only overrides when ability base damage type is `physical`.

## Mobility Preemption Contract

On mobility/jump press in `AbilityActivationSystem`:

1. Clear queued combat intents (`melee`, `projectile`, `self`).
2. Clear buffered combat input.
3. Clear active non-mobility ability state.
4. Commit mobility/jump slot action.

This keeps mobility as the deterministic preemption path over combat actions.

## Extension Notes

### Add a new status

1. Add `StatusEffectType`.
2. Add/extend status store(s).
3. Add apply/tick logic in `StatusSystem`.
4. Add immunity bit mapping.
5. Add `StatusProfileId` + catalog entries.

### Add a new damage type

1. Add enum in `DamageType`.
2. Add fields/switch handling in `DamageResistanceStore` and stat bonuses/resolver.
3. Update authoring + tests for neutral/resist/vulnerable cases.
