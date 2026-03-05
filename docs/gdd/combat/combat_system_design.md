# Combat Pipeline

This document tracks the current Core combat contracts used by `GameCore`.

## High-Level Combat Flow

End-to-end combat sequence (authoritative runtime path):

1. Input is sampled into `PlayerInputStore` and routed by `AbilityActivationSystem`.
2. Ability commit resolves one action, pays commit-time costs when applicable,
   starts cooldown when applicable, stamps `ActiveAbilityStore`, and writes one
   intent store (`MeleeIntentStore`, `ProjectileIntentStore`, `SelfIntentStore`,
   or `MobilityIntentStore`).
3. Intent consumers execute in tick order:
   - `SelfAbilitySystem` (self status/purge),
   - `MeleeStrikeSystem` (spawn hitboxes),
   - `ProjectileLaunchSystem` (spawn projectiles),
   - `MobilitySystem` / `JumpSystem` (mobility motion + jump execution rules).
4. Contact systems produce combat requests:
   - `ProjectileHitSystem`, `HitboxDamageSystem`, `MobilityImpactSystem` ->
     `DamageQueueStore`
   - `SelfAbilitySystem`, `MobilityImpactSystem`, `DamageSystem` proc outcomes ->
     `StatusSystem` queue inputs
5. `DamageMiddlewareSystem` mutates/cancels queued entries, then `DamageSystem`
   resolves final damage, crits, typed modifiers, death attribution, and proc
   status enqueue.
6. `ReactiveProcSystem` consumes post-damage outcomes and can enqueue more
   statuses.
7. `StatusSystem.applyQueued` applies final queued status/purge effects for the tick.

## Data Primitives

### Damage and Combat IDs

These primitives are authoritative identifiers used by damage/status pipelines,
loadout persistence, and hit routing. Keep names stable for save/replay
compatibility.

#### `DamageType`

Current runtime set:

- `physical`, `fire`, `ice`, `water`, `thunder`, `acid`, `dark`, `bleed`, `earth`, `holy`

Runtime usage:

- `DamageRequest.damageType` and authored payload damage typing
- typed incoming modifier lookup in `DamageResistanceStore` + resolved gear stats
- optional status scaling input when `StatusApplication.scaleByDamageType = true`

Contract notes:

- no `none` damage type exists; neutral baseline is `physical` with `0` typed modifier
- typed modifiers use basis points (`100 bp = 1%`)

#### `DeathSourceKind`

High-level damage-source category attached to `DamageRequest`.

Current runtime set:

- `projectile`, `meleeHitbox`, `statusEffect`, `unknown`

Runtime usage:

- `DamageRequest.sourceKind` classification
- middleware branching (for example ward/parry behavior vs status-effect damage)
- death attribution and feedback routing (`LastDamageStore`, run-end death info, impact feedback)

Contract notes:

- use `unknown` only as fallback/sentinel when source classification is unavailable

#### `WeaponId`

Stable weapon catalog IDs for main-hand and off-hand loadout slots.

Current IDs:

- primary (`WeaponCategory.primary`): `plainsteel`, `waspfang`, `cinderedge`, `basiliskKiss`, `frostbrand`, `stormneedle`, `nullblade`, `sunlitVow`, `graveglass`, `duelistsOath`
- offhand (`WeaponCategory.offHand`): `roadguard`, `thornbark`, `cinderWard`, `tideguardShell`, `frostlockBuckler`, `ironBastion`, `stormAegis`, `nullPrism`, `warbannerGuard`, `oathwallRelic`

Contract notes:

- persisted using enum `.name` in loadout/meta JSON
- add IDs append-only and update all switch-based catalogs/presenters

#### `ProcHook`

Outgoing weapon-proc trigger points carried in payload `procs`.

Current hooks:

- `onHit`, `onBlock`, `onKill`, `onCrit`

Runtime usage:

- authored on `WeaponProc.hook`
- evaluated by `DamageSystem` when rolling queued proc status applications

Contract notes:

- current outgoing resolution paths use `onHit`, `onCrit`, and `onKill`
- `onBlock` exists in the enum but is currently not consumed by outgoing proc resolution

#### `ReactiveProcHook`

Current hooks:

- `onDamaged`: evaluated when post-resolution applied damage was non-zero (owner HP changed)
- `onLowHealth`: evaluated only on threshold crossing from `prevHp > threshold` to `nextHp <= threshold`

Contract notes:

- evaluated by `ReactiveProcSystem` from `ReactiveDamageEventQueueStore` outcomes (post-damage stage)
- deterministic by fixed proc order, cooldown keying, and deterministic RNG

#### `ReactiveProcTarget`

Target-selection primitive for reactive defensive procs.

Current runtime set:

- `self`, `attacker`

Runtime usage:

- authored on `ReactiveProc.target`
- resolved in `ReactiveProcSystem` after hook/chance/cooldown checks

Contract notes:

- `attacker`-targeted procs require a valid source entity in the reactive outcome; otherwise status application is skipped

#### `ProjectileId`

Stable projectile item IDs used for projectile-slot payload source resolution
and projectile render/event attribution.

Current IDs:

- sentinel: `unknown`
- projectile spell items: `iceBolt`, `fireBolt`, `acidBolt`, `darkBolt`, `earthBolt`, `holyBolt`, `waterBolt`, `thunderBolt`

Contract notes:

- `ProjectileId.unknown` is sentinel only and has no `ProjectileCatalog` entry
- projectile-slot payload resolution accepts selected IDs only when the item resolves and `weaponType == WeaponType.spell`
- persisted via enum `.name`; keep names stable

#### `Faction`

Current runtime values:

- `player`
- `enemy`

Friendly-fire routing:

- ally check is currently equality (`areAllies(a, b) => a == b`)
- hit resolution excludes owner and allies for melee hitboxes, projectile hits, and mobility impacts

#### `EnemyId`

Stable enemy archetype IDs used for source attribution and kill accounting.

Current runtime set:

- `unocoDemon`, `grojib`

Runtime usage:

- `DamageRequest.sourceEnemyId` attribution for lethal/non-lethal damage context
- run-end stats and per-enemy kill aggregation

Contract notes:

- IDs should remain stable for telemetry, progression, and replay-compatible attribution

### Status System

Status primitives define deterministic authored effects, profile IDs, and purge
contracts used by damage, ability, and reactive systems.

#### `StatusEffectType`

Current runtime set:

- `dot`, `slow`, `stun`, `haste`, `damageReduction`, `vulnerable`, `weaken`, `drench`, `silence`, `resourceOverTime`, `offenseBuff`

Runtime usage:

- maps to concrete status stores (`DotStore`, `SlowStore`, `HasteStore`, `DamageReductionStore`, `VulnerableStore`, `WeakenStore`, `DrenchStore`, `ResourceOverTimeStore`, `OffenseBuffStore`)
- drives control-lock integration for `stun`/`silence`
- drives invulnerability gating and immunity mask checks during queued apply

#### `StatusResourceType`

Resource channel for `StatusEffectType.resourceOverTime`:

- `health`, `mana`, `stamina`

#### `StatusProfileId`

Stable authored status bundle IDs:

- `none`, `slowOnHit`, `burnOnHit`, `arcaneWard`, `acidOnHit`, `weakenOnHit`, `drenchOnHit`, `silenceOnHit`, `meleeBleed`, `stunOnHit`, `speedBoost`, `restoreHealth`, `restoreMana`, `restoreStamina`, `focus`

Runtime usage:

- outgoing/on-hit proc application (`DamageSystem`)
- self ability application (`SelfAbilitySystem`)
- mobility contact status application (`MobilityImpactSystem`)
- reactive defensive proc application (`ReactiveProcSystem`)

Contract notes:

- `StatusProfileId.none` resolves to an empty application list (no-op)
- IDs are persistence/replay-facing and should be treated append-only

#### `PurgeProfileId`

Current deterministic purge IDs:

- `none`, `cleanse`

Contract notes:

- `none` is a no-op sentinel
- `cleanse` removes harmful channels (`dot`, `slow`, `vulnerable`, `weaken`, `drench`) and clears cast/stun lock flags

#### `StatusApplication`

One authored effect entry inside a profile.

Core fields and units:

- `type`: `StatusEffectType`
- `magnitude`: effect strength (bp for most modifiers; DoT uses fixed-point DPS where `100 = 1.0`)
- `durationSeconds`: total effect duration in seconds
- `periodSeconds`: pulse interval (periodic effects; default `1.0`)
- `scaleByDamageType`: whether positive combined typed modifier can scale magnitude up
- `dotDamageType`: required when `type == dot`
- `resourceType`: required when `type == resourceOverTime`
- `critBonusBp`: optional crit chance bonus for `offenseBuff`
- `applyOnApply`: optional immediate pulse when applied

Constructor invariants:

- `periodSeconds > 0`
- `durationSeconds >= 0`
- required metadata is present for `dot` and `resourceOverTime` types

#### `StatusProfileCatalog`

Deterministic lookup from `StatusProfileId` to `StatusProfile`:

- implemented as explicit enum-switch mapping (no hash-order dependency)
- returns ordered `StatusApplication` lists consumed by `StatusSystem.applyQueued`
- central authored source for current runtime profile behavior

#### `StatusRequest`

Runtime command primitive for queueing profile application.

Fields:

- `target`: entity receiving the profile
- `profileId`: authored `StatusProfileId`
- `damageType`: typed context for optional `scaleByDamageType` behavior (defaults to `DamageType.physical`)

Runtime usage:

- produced by outgoing proc resolution, self abilities, mobility impacts, and reactive procs
- consumed by `StatusSystem.applyQueued`

#### `PurgeRequest`

Runtime command primitive for queueing status/control purge.

Fields:

- `target`: entity to purge
- `profileId`: authored `PurgeProfileId`

Runtime usage:

- consumed by `StatusSystem.tickExisting` purge pass before periodic tick effects

See `docs/gdd/combat/status/status_system_design.md`.

## ECS Stores (Combat-Relevant)

### Health, Resources, Damage, and Queues

| Store | Purpose |
|---|---|
| `HealthStore` | Current/max HP |
| `ManaStore` | Current/max mana + regen accumulator (ability costs and status restoration) |
| `StaminaStore` | Current/max stamina + regen accumulator (ability costs, hold drains, and restoration) |
| `DamageResistanceStore` | Per-type incoming modifier bp |
| `InvulnerabilityStore` | Post-hit i-frame ticks |
| `LastDamageStore` | Last lethal/non-lethal source details |
| `DeathStateStore` | Death lifecycle gating used by combat systems (skip/deactivate dead entities) |
| `DamageQueueStore` | Pending `DamageRequest`s processed by middleware + damage system |
| `ReactiveDamageEventQueueStore` | Post-damage outcomes consumed by reactive proc resolution |

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

### Ability State, Input, and Cooldowns

| Store | Purpose |
|---|---|
| `PlayerInputStore` | Authoritative per-tick combat input (slot presses/holds/aim) |
| `MovementStore` | Facing + dash runtime state used by commit, preemption, and stun interruption |
| `ActiveAbilityStateStore` | Authoritative committed ability phase/timing |
| `AbilityInputBufferStore` | Buffered combat input during recovery |
| `AbilityChargeStateStore` | Authoritative held-duration charge tracking and release samples |
| `CooldownStore` | Per-entity per-group cooldown ticks for combat slots |
| `MeleeIntentStore` | Queued melee execution payload |
| `ProjectileIntentStore` | Queued projectile execution payload |
| `SelfIntentStore` | Queued self-ability execution payload |
| `MobilityIntentStore` | Queued mobility execution payload |

### Hit Delivery, Ownership, and Spatial Gating

| Store | Purpose |
|---|---|
| `TransformStore` | World position/velocity source for hitbox and projectile overlap checks |
| `ColliderAabbStore` | Collider extents/offsets for spatial hit tests and spawn offsets |
| `CollisionStateStore` | World-collision state used for projectile terrain/wall despawn |
| `FactionStore` | Friend-or-foe routing for hit filtering (friendly-fire prevention) |
| `ProjectileStore` | Active projectile damage payload + owner/faction metadata |
| `ProjectileOriginStore` | Source projectile-item attribution for events/death metadata |
| `HitboxStore` | Active melee/area hit payload and capsule geometry |
| `HitOnceStore` | Per-hitbox/per-projectile target dedupe (single-contact guarantees) |
| `LifetimeStore` | Deterministic expiry for short-lived hit entities (for example melee hitboxes) |
| `MobilityImpactStateStore` | Per-activation contact bookkeeping for mobility hit policies (`everyTick`/`once`/`oncePerTarget`) |

### Reactive/Guard Subsystems

| Store | Purpose |
|---|---|
| `ReactiveProcCooldownStore` | Per-entity reactive proc internal cooldowns |
| `ParryConsumeStore` | One-riposte-per-activation guard bookkeeping |
| `RiposteStore` | Temporary one-shot riposte bonus |

### Loadout, Stat Cache, and Tags

| Store | Purpose |
|---|---|
| `EquippedLoadoutStore` | Equipped gear + ability IDs + slot mask + projectile slot spell selection |
| `ResolvedStatsCacheStore` | Cached loadout-derived resolved stats for damage/status hot paths |
| `CreatureTagStore` | Shared creature tags |

### Enemy Combat Runtime State

| Store | Purpose |
|---|---|
| `EnemyStore` | Enemy identity/facing and melee telegraph metadata used by combat intent writers |
| `MeleeEngagementStore` | Melee enemy engagement phase state (`approach`/`engage`/`strike`/`recover`) |
| `EngagementIntentStore` | Desired melee slot/chase shaping used before strike commit decisions |
| `NavIntentStore` | Navigation intent output (desired X/jump/plan state) that drives approach into combat range |
| `SurfaceNavStateStore` | Ground-enemy path state over traversable surfaces for deterministic pursuit |
| `GroundEnemyChaseOffsetStore` | Deterministic per-enemy chase offset/speed variation to reduce enemy stacking |
| `FlyingEnemySteeringStore` | Deterministic hover/steering state for airborne enemies during combat positioning |

## Combat Tick Order

Combat and combat-adjacent ordering inside `GameCore.stepOneTick`:

1. `CooldownSystem.step`
2. `InvulnerabilitySystem.step`
3. `ControlLockSystem.step`
4. `ActiveAbilityPhaseSystem.step`
5. `AbilityChargeTrackingSystem.step`
6. `HoldAbilitySystem.step`
7. `EnemyNavigationSystem.step`
8. `EnemyEngagementSystem.step`
9. `GroundEnemyLocomotionSystem.step`
10. `FlyingEnemyLocomotionSystem.step`
11. `AbilityActivationSystem.step` (player input -> intent commit)
12. `JumpSystem.step`
13. `MovementSystem.step`
14. `MobilitySystem.step`
15. `GravitySystem.step`
16. `CollisionSystem.step`
17. `BroadphaseGrid.rebuild`
18. `ProjectileSystem.step` (moves already-active projectiles)
19. `EnemyCastSystem.step`
20. `EnemyMeleeSystem.step`
21. `SelfAbilitySystem.step`
22. `MeleeStrikeSystem.step`
23. `ProjectileLaunchSystem.step`
24. `HitboxFollowOwnerSystem.step`
25. `ProjectileHitSystem.step`
26. `HitboxDamageSystem.step`
27. `MobilityImpactSystem.step`
28. `ProjectileWorldCollisionSystem.step`
29. `EntityVisualCueCoalescer.resetForTick`
30. `StatusSystem.tickExisting`
31. `DamageMiddlewareSystem.step`
32. `DamageSystem.step`
33. `ReactiveProcSystem.step`
34. `PlayerImpactFeedbackGate.flushTick`
35. `StatusSystem.applyQueued`
36. `EntityVisualCueCoalescer.emit`
37. `EnemyCullSystem.step`
38. `EnemyDeathStateSystem.step`
39. `DeathDespawnSystem.step`
40. `HealthDespawnSystem.step`
41. `ResourceRegenSystem.step` (only when player survives combat/death checks)
42. `AnimSystem.step`
43. `LifetimeSystem.step`

Notes:
- Run-ending checks for `fellIntoGap` and `fellBehindCamera` happen before broadphase/hit resolution; when triggered, later combat phases do not run.
- If paused/game-over, `stepOneTick` returns early with no gameplay updates.
- During death-animation freeze ticks, only animation advances; combat systems do not run.
- Player mobility/jump presses still preempt queued/active combat intents before mobility/jump commit in `AbilityActivationSystem`.

## Ability Commit Semantics Matrix

| Commit path | Gate API | Cost timing | Cooldown timing | Intent output | Intent consumer | Runtime notes |
|---|---|---|---|---|---|---|
| `_commitMelee` | `AbilityGate.canCommitCombat` | commit-time (`_applyCommitSideEffects`) | commit-time (except `holdToMaintain` defer) | `MeleeIntentStore` | `MeleeStrikeSystem` | payload built via `HitPayloadBuilder` from ability + resolved weapon source |
| `_commitProjectile` | `AbilityGate.canCommitCombat` | commit-time (`_applyCommitSideEffects`) | commit-time (except `holdToMaintain` defer) | `ProjectileIntentStore` | `ProjectileLaunchSystem` | projectile source can be projectile item or spellbook; charge tuning applied post-build |
| `_commitSelf` | `AbilityGate.canCommitCombat` (`ignoreStun = ability.canCommitWhileStunned`) | commit-time (`_applyCommitSideEffects`) | commit-time (except `holdToMaintain` defer) | `SelfIntentStore` | `SelfAbilitySystem` | self abilities apply status/purge commands; no hit payload build |
| `_commitMobility` (`slot = mobility`) | `AbilityGate.canCommitMobility` | commit-time (`_applyCommitSideEffects`) | commit-time (except `holdToMaintain` defer) | `MobilityIntentStore` | `MobilitySystem` | preemption cancellation runs before gate checks |
| `_commitMobility` (`slot = jump`) | `AbilityGate.canCommitMobility` (resources passed as `0`) | execute-time in `JumpSystem` (ground/air jump cost profile) | execute-time in `JumpSystem` (`_startJumpCooldown`) | `MobilityIntentStore` (`slot = jump`) | `JumpSystem` (`MobilitySystem` skips jump intents) | jump affordability is authoritative in `JumpSystem`, not commit gate |

## Damage Pipeline

### Queue Inputs (`DamageQueueStore`)

Current producers:

- `ProjectileHitSystem` (projectile overlap hits)
- `HitboxDamageSystem` (melee hitbox overlaps)
- `MobilityImpactSystem` (mobility contact damage)
- `StatusSystem.tickExisting` DoT pulses (`sourceKind = statusEffect`)

Queue ingress contract:

- `DamageQueueStore.add` ignores requests where `amount100 <= 0`
- queued entries carry payload + source attribution metadata and a cancel flag
- canceled entries are skipped by downstream stages

### `DamageRequest`

```dart
DamageRequest {
  target,
  amount100,          // fixed-point: 100 = 1.0
  critChanceBp,       // basis points: 10000 = 100%
  damageType,
  procs,
  source,             // optional source entity
  sourceKind,         // DeathSourceKind
  sourceEnemyId,      // optional EnemyId attribution
  sourceProjectileId, // optional ProjectileId attribution
}
```

### Middleware Stage (`DamageMiddlewareSystem`)

Execution contract:

- middleware runs in configured list order, per queue index
- first canceled result short-circuits remaining middleware for that entry
- middleware mutates queue entries only (never health directly)

Current runtime stack order:

1. `ParryMiddleware`
2. `WardMiddleware`

`ParryMiddleware`:

- applies only when target has an active configured guard ability and phase is `AbilityPhase.active`
- ignores status-effect sourced entries (`DeathSourceKind.statusEffect`)
- can reduce or cancel queued direct-hit damage based on resolved guard mitigation
- can grant riposte once per guard activation (`ParryConsumeStore` + `RiposteStore`)

`WardMiddleware`:

- applies when target has active `DamageReductionStore`
- cancels status-effect damage while ward is active
- otherwise reduces queued direct-hit amount by ward magnitude bp, canceling if result `<= 0`

### Resolution Stage (`DamageSystem`)

Per uncanceled queue entry:

1. Skip when target has no `HealthStore` entry.
2. Skip when target has active i-frames (`InvulnerabilityStore.ticksLeft > 0`).
3. Apply source-side `weaken` outgoing penalty (when source entity exists and is weakened).
4. Resolve crit from `critChanceBp` (`+50%` crit bonus).
5. Apply global defense (`ResolvedCharacterStats.applyDefense`).
6. Apply typed incoming modifier:
   - `DamageResistanceStore` typed mod
   - `ResolvedCharacterStats` gear typed incoming mod
7. Apply target `vulnerable` amplification.
8. Clamp `>= 0`, subtract HP, detect kill.
9. If HP changed (`nextHp < prevHp`):
   - apply forced interrupt on `damageTaken` when policy allows,
   - update `LastDamageStore`,
   - emit `onDamageApplied` callback,
   - enqueue reactive outcome into `ReactiveDamageEventQueueStore`.
10. Queue proc statuses when `amount100 > 0` and procs exist:
   - `onHit` -> target,
   - `onCrit` -> target (only if crit happened),
   - `onKill` -> source entity (only if kill happened and source exists),
   - deterministic chance roll per proc.
11. Apply post-hit i-frames (`invulnerabilityTicksOnHit`) when target has `InvulnerabilityStore`.
12. After loop, clear `DamageQueueStore`.

### Output/Side-Effect Summary

- HP mutation: `HealthStore`
- death-cause attribution: `LastDamageStore`
- reactive input stream: `ReactiveDamageEventQueueStore`
- queued follow-up statuses: `StatusSystem.queue`
- player impact/visual feedback callbacks via `onDamageApplied`

Important nuances:

- Proc gating uses request `amount100 > 0` (pre-defense/pre-resistance), not final applied amount.
- `ProcHook.onBlock` exists but is not consumed in outgoing damage proc resolution.
- Reactive outcomes are added only when applied damage is strictly positive.
- If entry survives middleware and invulnerability checks, i-frames can still be refreshed even when final applied damage is `0`.

## Status Pipeline

### Queue Inputs

Status command queues are filled from multiple combat systems in the same tick:

- `SelfAbilitySystem` -> `queueStatus` and `queuePurge`
- `MobilityImpactSystem` -> `queueStatus`
- `DamageSystem` outgoing proc resolution -> `queueStatus`
- `ReactiveProcSystem` -> `queueStatus`

Queue gating:

- `StatusSystem.queue` ignores `StatusProfileId.none`
- `StatusSystem.queuePurge` ignores `PurgeProfileId.none`

### `StatusSystem.tickExisting`

Order inside `tickExisting`:

1. Apply pending purges.
2. Tick/apply `DotStore` channels and queue DoT `DamageRequest`s (`sourceKind = statusEffect`).
3. Tick/apply continuous `ResourceOverTimeStore` restoration.
4. Tick durations for `damageReduction`, `offenseBuff`, `haste`, `slow`, `vulnerable`, `weaken`, `drench`.

Ticking rules:

- dead targets are removed from active status stores during ticking
- DoT pulses use authored `periodTicks`; per pulse amount is derived from channel DPS and period ticks
- resource-over-time channels restore smoothly each tick through deterministic accumulator carry (not discrete pulse-timed ticks)

### `StatusSystem.applyQueued`

Execution order:

1. Set `currentTick` context for lock operations.
2. Apply all queued status requests (if any), then clear queue.
3. Recompute derived move/action modifiers in `StatModifierStore`.

Per queued request:

1. Skip dead targets and targets without `HealthStore`.
2. Resolve `StatusProfileId` -> ordered `StatusApplication` list.
3. Apply invulnerability gating:
   - blocked: `dot`, `slow`, `stun`, `vulnerable`, `weaken`, `drench`, `silence`
   - allowed: `haste`, `damageReduction`, `resourceOverTime`, `offenseBuff`
4. Apply `StatusImmunityStore` checks.
5. Apply optional typed scaling (`scaleByDamageType`):
   - uses `DamageResistanceStore` + resolved gear typed incoming mod
   - scales magnitude up only when combined typed modifier is positive
6. Apply magnitude gating:
   - non-`offenseBuff` applications require `magnitude > 0`
   - `offenseBuff` can still apply when power bonus is `0` but crit bonus is positive
7. Apply store/control updates with type-specific stacking/refresh rules.

Type-specific apply behavior:

- `dot` (`DotStore`): channel key is `dotDamageType`; stronger DPS replaces, equal DPS refreshes to longer duration
- `resourceOverTime` (`ResourceOverTimeStore`): channel key is `resourceType`; stronger `amountBp` replaces, equal `amountBp` refreshes
- `slow`, `haste`, `damageReduction`, `vulnerable`, `weaken`, `drench`: stronger magnitude replaces; equal magnitude extends only if longer
- `offenseBuff`: two-dimensional dominance check (`powerBonusBp`, `critBonusBp`); replace only when new pair dominates, equal pair can refresh
- `stun`: adds `LockFlag.stun`, clears pending combat intents (`melee`, `projectile`, `self`), cancels active dash
- `silence`: adds `LockFlag.cast`; interrupts enemy projectile-slot casts only while still in windup

Clamp/validation highlights:

- slow/vulnerable/weaken/drench clamped to `0..9000`
- damageReduction clamped to `0..10000`
- haste clamped to `0..20000`
- offense buff clamped to `power 0..20000`, `crit 0..10000`

### Purge Processing

`PurgeProfileId.cleanse` currently:

- removes `dot`, `slow`, `vulnerable`, `weaken`, `drench`
- clears `LockFlag.cast | LockFlag.stun`

Purge pass runs before DoT/resource ticking in the same `tickExisting` call.

Important nuances:

- `resourceOverTime.applyOnApply` can grant an immediate restore pulse at apply time.
- continuous resource-over-time ticking in `tickExisting` is intentionally pulse-callback free; visual pulse callbacks occur from apply-time pulse paths.
- `stun`, `slow`, and `haste` application paths require target `StatModifierStore`; entities without it skip those effects.
- queued request order and per-profile application order are preserved, giving deterministic status resolution for identical inputs.

## Projectile Payload Source Resolution

Projectile payload resolution is deterministic and loadout-driven. `_commitProjectile`
is authoritative and rejects commit when any required source data is unresolved.

### Commit Gate (`AbilityActivationSystem._commitProjectile`)

Projectile commit runs only when all are true:

- `ability.hitDelivery is ProjectileHitDelivery`
- `ability.category == AbilityCategory.ranged`
- `ability.payloadSource` is `AbilityPayloadSource.projectile` or `AbilityPayloadSource.spellBook`
- loadout mask includes `LoadoutSlotMask.projectile`

If any gate fails, no projectile intent is emitted.

### Source Resolution: `AbilityPayloadSource.projectile`

Resolver: `resolveProjectilePayloadForAbilitySlot(...)`

Resolution contract:

1. Slot must be `AbilitySlot.projectile`.
2. Read selected ID from `EquippedLoadoutStore.projectileSlotSpellId`.
3. Accept only when selected ID exists in `ProjectileCatalog`, selected item is
   `WeaponType.spell`, and ability required weapon types are empty or include
   `WeaponType.spell`.
4. Return `null` otherwise.

Commit behavior:

- `null` resolution rejects commit.
- `projectileId` = equipped projectile slot spell ID.
- Motion/shape inputs come from projectile item (`ballistic`, `gravityScale`,
  `speedUnitsPerSecond`, `originOffset`).
- Spell projectile origin uses `_spellOriginOffset(...)` when authored
  `originOffset == 0`.
- Payload source damage type comes from projectile item `damageType`.
- Payload source procs come from `_resolveProjectilePayloadProcs(...)`.
- `_commitProjectile` also hard-checks `requiredWeaponTypes` against resolved
  projectile `weaponType` before intent emit.

### Source Resolution: `AbilityPayloadSource.spellBook` (Projectile Delivery)

Resolution contract:

- Equipped spellbook must resolve in `SpellBookCatalog`; otherwise commit is rejected.
- `projectileId` comes from ability `ProjectileHitDelivery.projectileId`.
- `speedUnitsPerSecond` comes from `ProjectileCatalog.get(projectileId)`.
- Projectile physics defaults are forced for this path: `ballistic = false`,
  `gravityScale = 1.0`.
- `originOffset` uses `_spellOriginOffset(...)`.
- Payload source damage type and procs come from equipped spellbook.

### Proc Merge Rule (`_resolveProjectilePayloadProcs`)

For `WeaponType.spell` projectile payloads:

- projectile procs first, spellbook procs second
- if either side is empty/missing, return the non-empty side

`HitPayloadBuilder` performs final deterministic merge order and dedupe.

### Cost + Validation Coupling

- `resolveEffectiveAbilityCostForSlot` resolves payload weapon type through the
  same projectile payload resolution path, keeping cost profile selection aligned
  with commit-time payload source.
- `LoadoutValidator` performs pre-runtime legality checks (slot mask, projectile
  catalog existence, spell typing, required weapon type).
- Commit remains authoritative and can still reject invalid runtime state.

### Character Policy Notes

- Runtime projectile source selector is `EquippedLoadoutStore.projectileSlotSpellId`.
- Current projectile payload-source contract is spell-projectile-only
  (`WeaponType.spell`).
- Learned spell ownership is normalized upstream (meta/UI); commit assumes
  normalized loadout and validates payload resolvability only.

## Melee Payload Source Resolution

Melee payload resolution is deterministic and loadout-driven. `_commitMelee` is
authoritative and rejects commit when any required source data is unresolved.

### Commit Gate (`AbilityActivationSystem._commitMelee`)

Melee commit runs only when all are true:

- `ability.hitDelivery is MeleeHitDelivery`
- `ability.payloadSource` is `AbilityPayloadSource.none`, `AbilityPayloadSource.primaryWeapon`, or `AbilityPayloadSource.secondaryWeapon`
- source-specific loadout slot mask check passes:
  - `primaryWeapon` -> `LoadoutSlotMask.mainHand`
  - `secondaryWeapon` -> offhand slot, unless main weapon is two-handed (then main-hand slot)
  - `none` -> no additional slot-mask requirement

If any gate fails, no melee intent is emitted.

### Source Resolution by `AbilityPayloadSource`

`AbilityPayloadSource.primaryWeapon`:

- payload weapon ID resolves to equipped `mainWeaponId`
- payload source damage type comes from resolved weapon `damageType`
- payload source procs come from resolved weapon `procs`

`AbilityPayloadSource.secondaryWeapon`:

- effective secondary weapon ID resolves with two-handed mapping:
  - main is two-handed -> use `mainWeaponId`
  - otherwise use `offhandWeaponId`
- payload source damage type/procs come from the resolved effective weapon

`AbilityPayloadSource.none`:

- uses legacy slot fallback weapon context for payload enrichment:
  - triggered `AbilitySlot.secondary` -> `offhandWeaponId`
  - all other melee slots -> `mainWeaponId`
- resolved weapon still provides `damageType` and `procs` for `HitPayloadBuilder`

Rejected sources:

- `AbilityPayloadSource.projectile` and `AbilityPayloadSource.spellBook` are illegal for melee delivery and always reject commit.

### Cost and Validation Coupling

- `resolveEffectiveAbilityCostForSlot` is used for commit cost resolution on the
  same payload-source context.
- `LoadoutValidator` performs pre-runtime legality checks, including required
  weapon-type validation.
- Commit path remains authoritative and can still reject invalid runtime state.

### Character Policy Notes

- Current melee payload-source contract is weapon-context-only (`none`,
  `primaryWeapon`, `secondaryWeapon`).

## Self Payload Source Resolution

Self payload-source resolution is deterministic and loadout-driven.
`_commitSelf` is authoritative and rejects commit when required source context
cannot be resolved.

### Commit Gate (`AbilityActivationSystem._commitSelf`)

Self commit runs only when all are true:

- self ability commit path is selected (`SelfHitDelivery`)
- source-specific payload gate passes:
  - `none` -> always legal from payload-source perspective
  - `primaryWeapon` -> requires `LoadoutSlotMask.mainHand`
  - `secondaryWeapon` -> requires offhand slot, unless main is two-handed (then main-hand slot)
  - `projectile` -> requires `LoadoutSlotMask.projectile`
  - `spellBook` -> equipped spellbook must resolve in `SpellBookCatalog`

If any gate fails, no self intent is emitted.

### Source Resolution by `AbilityPayloadSource`

Self commit does not build a `HitPayload`; payload source is used for legality
and effective cost-profile resolution.

`AbilityPayloadSource.none`:

- no source item lookup required

`AbilityPayloadSource.primaryWeapon` / `AbilityPayloadSource.secondaryWeapon`:

- source context is resolved for legality + cost-profile selection

`AbilityPayloadSource.projectile`:

- source context is projectile-slot availability (mask gate) for legality + cost context

`AbilityPayloadSource.spellBook`:

- requires spellbook catalog resolution for legality + cost context

Commit output:

- `SelfIntentStore` receives `selfStatusProfileId` and `selfPurgeProfileId`
- commit-time costs/cooldown/active-ability side effects run through
  `_applyCommitSideEffects`

### Cost and Validation Coupling

- `resolveEffectiveAbilityCostForSlot` resolves effective payload weapon type for
  self ability cost profiles.
- `LoadoutValidator` performs pre-runtime legality checks, including required
  weapon-type validation.
- Commit path remains authoritative and can still reject invalid runtime state.

### Character Policy Notes

- Self payload source currently affects legality/cost context only; self effects
  are emitted from authored `selfStatusProfileId`/`selfPurgeProfileId`.

## Payload Assembly (`HitPayloadBuilder`)

`HitPayloadBuilder.build(...)` is the canonical, deterministic constructor for
intent payload snapshots (`damage100`, `critChanceBp`, `damageType`, `procs`,
`sourceId`, `abilityId`).

### Runtime Call Sites

- player melee commit (`AbilityActivationSystem._commitMelee`)
- player projectile commit (`AbilityActivationSystem._commitProjectile`)
- enemy projectile cast (`EnemyCastSystem`)

### Build Inputs (Current Runtime Wiring)

- always wired:
  - ability base payload (`baseDamage`, `baseDamageType`, ability procs)
  - `globalPowerBonusBp` and `globalCritChanceBonusBp` from resolved stats + active offense buff
  - payload-source weapon/projectile/spellbook `damageType` and `procs` as `weaponDamageType`/`weaponProcs`
- builder-supported but not currently passed by runtime call sites:
  - `buffProcs`
  - `passiveProcs`

### Assembly Order and Rules

1. Seed from ability base payload:
   - `finalDamage100 = ability.baseDamage`
   - `finalDamageType = ability.baseDamageType`
   - `finalCritChanceBp = globalCritChanceBonusBp` (ability has no authored base crit field)
2. Apply global power bonus to damage with integer fixed-point math:
   - `finalDamage100 = finalDamage100 * (10000 + globalPowerBonusBp) ~/ 10000`
   - clamp floor at `0` if negative
3. Apply optional damage-type override:
   - if `weaponDamageType != null` and current type is `physical`, override with weapon type
   - authored elemental ability types (`fire`, `ice`, etc.) are not overridden
4. Merge procs in canonical order:
   - ability -> weapon/item -> buffs -> passives
5. Deterministic dedupe (first wins):
   - dedupe key is `(hook, statusProfileId)`
   - later duplicates are dropped
6. Clamp `critChanceBp` to `[0, 10000]`.

### Post-Build Commit Tuning (Outside Builder)

For player melee/projectile commits, `AbilityActivationSystem` applies charge-tier
adjustments after payload build:

- `damage100` scaled by `chargeTuning.damageScaleBp`
- `critChanceBp` increased by `chargeTuning.critBonusBp` and clamped again

This keeps `HitPayloadBuilder` focused on base payload assembly while preserving
deterministic charge behavior in commit flow.

## Mobility Preemption Contract

`AbilityActivationSystem` treats mobility as a deterministic preemption path over
combat actions.

### Trigger Points

Preemption cancellation runs from two paths:

- raw mobility input path in `step` (`dashPressed`, `jumpPressed`)
- mobility-category commit path in `_commitMobility(...)` (covers non-direct calls)

### Cancellation Sequence (`_cancelCombatOnMobilityPress`)

1. Invalidate queued combat intents by setting `tick = -1` and `commitTick = -1` for:
   - `MeleeIntentStore`
   - `ProjectileIntentStore`
   - `SelfIntentStore`
2. Clear `AbilityInputBufferStore` if present.
3. Clear `ActiveAbilityStore` only when active ability is non-mobility
   (or missing/unresolvable authored def).

### Commit + Failure Coupling

- Cancellation executes before mobility gate checks.
- If mobility/jump commit fails (`stunned`, cooldown, missing body/movement,
  resource failure, `dashAlreadyActive`), cancellation is not rolled back.
- Net effect: a failed mobility press can still consume pending combat intent and
  buffered combat input.

### Jump-Specific Notes

- Jump uses the same preemption cancellation path.
- In `_commitMobility`, jump passes zero resource costs to `AbilityGate`; actual
  ground/air jump affordability + resource payment is resolved in `JumpSystem`.
- Jump intents are written to `MobilityIntentStore`; `MobilitySystem` ignores
  `AbilitySlot.jump`, and `JumpSystem` consumes those intents.

### Input Tie Behavior (Current Runtime)

- `dashPressed` is checked before `jumpPressed` in the same tick, so dash wins
  that tie.

## Combat Determinism Contract

Combat determinism is guaranteed by these runtime invariants:

1. Fixed combat system order in `GameCore.stepOneTick` (no runtime reordering).
2. Combat-critical arithmetic uses integer/fixed-point units:
   - damage/resources: `100 = 1.0`
   - percentages/chances/modifiers: basis points (`10000 = 100%`)
3. Randomness is system-owned and seed-derived:
   - `DamageSystem` owns crit/proc RNG state
   - `ReactiveProcSystem` owns reactive-proc RNG state
   - both seed from master run seed via deterministic salt mixing
4. Queue consumption order is deterministic:
   - `DamageQueueStore` iterates insertion order
   - `ReactiveDamageEventQueueStore` iterates insertion order
   - proc lists resolve in authored/canonical order
5. `HitPayloadBuilder` merge/dedupe rules are canonical and stable
   (`ability -> item -> buffs -> passives`, first duplicate wins by key).
6. Commit side effects are applied in a fixed sequence (`resources` -> `cooldown`
   -> `active ability`) when commit succeeds.
7. Run-end and death-freeze gates short-circuit later combat phases in a
   deterministic way.

Scope note:

- Direction/physics vectors use `double` values for aim/motion. Deterministic
  replay contract assumes identical command stream, tick rate, and runtime
  execution environment.

## Known Constraints and Intentional Gaps

- `ProcHook.onBlock` exists in enum contracts but is not consumed by outgoing
  damage proc resolution.
- `HitPayloadBuilder` supports `buffProcs` and `passiveProcs`, but current
  runtime call sites pass neither (current outgoing proc sources are ability +
  payload item).
- Melee/self commit paths rely primarily on normalized loadout + validator for
  required weapon-type legality; projectile commit path contains stricter
  runtime payload-source re-resolution checks.
- Self payload source `projectile` currently gates on projectile slot presence,
  not projectile item re-resolution at commit.

## Cross-Doc Alignment Notes

- Current runtime tie behavior for simultaneous mobility inputs is
  `dashPressed` before `jumpPressed` (dash wins same-tick tie).
- `docs/gdd/01_controls.md` still describes jump-first priority; align that
  document if runtime behavior remains canonical.
