# Status Effects

## Purpose

Status effects add combat depth by creating short, readable state changes over time:

- pressure tools (burn/bleed),
- control tools (slow/stun),
- self-tempo buffs (haste).

The status model must stay deterministic, data-authored, and reusable across player and enemies.

---

## Design Goals

1. Deterministic behavior at fixed tick rate (`tickHz`), no frame-time dependence.
2. Clear authoring contract: statuses are declared as `StatusProfile`s, not hardcoded per ability.
3. Multiplayer/ghost safety: same input + seed => same status outcomes and expiration.
4. Readable combat: each status has one primary gameplay purpose.

---

## Runtime Taxonomy (Current)

`StatusEffectType` currently includes:

- `burn` (DoT, fire)
- `bleed` (DoT, bleed)
- `slow` (move speed reduction)
- `stun` (control lock)
- `haste` (move speed increase)

`StatusProfileId` currently includes:

- `none`
- `iceBolt` -> slow
- `fireBolt` -> burn
- `meleeBleed` -> bleed
- `stunOnHit` -> stun
- `speedBoost` -> haste

---

## Current V1 Profile Table

| Profile | Effects | Default source(s) |
|---|---|---|
| `iceBolt` | `slow` 25% for 3.0s | projectile proc (ice bolt) |
| `fireBolt` | `burn` 5.0 DPS for 5.0s, 1.0s period | projectile proc (fire bolt) |
| `meleeBleed` | `bleed` 3.0 DPS for 4.0s, 1.0s period | melee proc (sword variants) |
| `stunOnHit` | `stun` for 0.5s | melee proc (shield bash variants) |
| `speedBoost` | `haste` +50% for 5.0s | self ability (`eloise.arcane_haste`) |

Notes:

- Magnitudes are fixed-point / bp (`100 = 1.0` for DoT DPS, `100 = 1%` for slow/haste).
- Status applications may be flagged `scaleByDamageType`.

---

## Authoritative Pipeline

### 1) Status source declaration

Statuses are sourced from:

- `WeaponProc` on damage events (`DamageSystem`),
- self abilities (`SelfAbilitySystem`) via `selfStatusProfileId`.

### 2) Queueing

- Systems enqueue `StatusRequest(target, profileId, damageType)`.
- Requests are stored in `StatusSystem` pending queue.

### 3) Tick existing statuses

`StatusSystem.tickExisting`:

- ticks burn/bleed/slow/haste durations,
- emits periodic DoT `DamageRequest`s for burn/bleed.

### 4) Apply queued statuses

`StatusSystem.applyQueued`:

- resolves profile entries,
- enforces immunity and guards,
- applies/refreshes status stores,
- updates derived movement modifier state.

### 5) Combat loop ordering

In `GameCore.stepOneTick`, status processing order is:

1. `StatusSystem.tickExisting` (queues DoT damage)
2. `DamageMiddlewareSystem.step`
3. `DamageSystem.step` (may enqueue new status requests from procs)
4. `StatusSystem.applyQueued`

This means DoT damage and on-hit status applications are deterministic within the same tick pipeline.

---

## Stacking, Refresh, and Clamps (Current Contract)

### Slow / Haste

- New stronger magnitude replaces weaker and refreshes duration.
- Equal magnitude extends duration to max remaining.
- Weaker magnitude is ignored.
- Slow magnitude clamp: `0..9000` bp.
- Haste magnitude clamp: `0..20000` bp.
- Final move speed multiplier clamp after all status math: `0.1..2.0`.

### Burn / Bleed (DoT)

- New higher DPS replaces lower DPS and refreshes duration.
- Equal DPS extends duration to max remaining.
- Lower DPS is ignored.
- On stronger replacement, period is updated and period timer resets.

### Stun

- Applies `LockFlag.stun` through `ControlLockStore`.
- Overlapping stuns extend via `max(untilTick, newUntilTick)`.
- Continuous stun window preserves original `stunStartTick`.
- On apply, current melee/projectile/self intents are canceled and active dash is stopped.

---

## Immunity, Resistance Scaling, and Gating

### Immunity

- Per-entity immunities are bitmask-based (`StatusImmunityStore`).
- Immune effects are skipped per application entry.

### Damage-type scaling

For applications with `scaleByDamageType = true`:

- status magnitude is increased when target has positive vulnerability for the incoming `damageType`,
- negative resistance does not reduce status magnitude in current implementation.

### Apply-time gating

Queued status applications are skipped when target:

- is dead,
- has no `HealthStore`,
- is currently invulnerable (`InvulnerabilityStore` ticks left > 0).

Implication: invulnerability currently blocks both harmful and beneficial profile applications.

---

## Determinism Rules

1. All durations are converted to ticks using authoritative tick math.
2. All magnitudes use integer fixed-point/basis points.
3. Proc chance rolls come from deterministic RNG.
4. Store iteration order is dense-array deterministic.
5. Status math is side-effect free outside explicit store writes and queued damage.

---

## UI / Snapshot Contract (Current)

Current snapshots do not expose a generic active-status list yet.

Player-visible effects are currently indirect:

- movement speed changes are reflected in movement behavior,
- stun is reflected through lock behavior and stun animation priority.

Future HUD status icon bars should be sourced from Core snapshot data, not from Game/UI inference.

---

## Extension Template (New Status Type)

When adding a new status:

1. Add enum value in `StatusEffectType`.
2. Add immunity mask mapping in `StatusImmunityStore`.
3. Add a dedicated status store (`lib/core/ecs/stores/status/`).
4. Add apply/tick behavior in `StatusSystem`.
5. If needed, project derived values into `StatModifierStore`.
6. Add one or more `StatusProfileId` definitions in `StatusProfileCatalog`.
7. Wire one source (proc, self ability, or enemy ability).
8. Add deterministic tests (apply, tick, stacking, immunity, expiry).

---

## Known Gaps and V2 Targets

1. No generic cleanse/purge/dispel mechanics yet.
2. No diminishing returns for repeated control effects.
3. No snapshot-level status list for HUD iconization/tooltips.
4. Invulnerability blocks beneficial statuses too; likely needs harmful/beneficial split.
5. Status magnitude scaling currently ignores negative resistances for `scaleByDamageType`.

