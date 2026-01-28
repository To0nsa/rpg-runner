# TODO — `lib/core/ecs/systems/anim_system.dart`

> Goal: ensure AnimSystem emits **correct, deterministic** `AnimSignals` for all entities (player + enemies) and updates `AnimStateStore` without hiding gameplay bugs.

---

## P0 — Must fix (current behavior is incorrect / missing)

### [ ] Wire **player spawnStartTick** (spawn cannot be correct without it)

**Symptom**: player signals don’t provide a real spawn start tick, so spawn anim either never plays (if resolver requires `spawnStartTick`) or only plays at global tick 0 (legacy behavior).

**Task**

* Add authoritative source for player spawn timing (choose one):

  * `SpawnStateStore` (recommended) storing `spawnStartTick` per entity
  * Or a one-shot “run start tick” for the player entity if player only spawns once per run
* Pass `spawnStartTick` into `AnimSignals.player(...)`.

**Acceptance**

* Spawn anim plays for exactly `spawnAnimTicks` after spawn, even if the player respawns mid-run.

---

### [ ] Provide **player death lifecycle** (`deathPhase` + `deathStartTick`)

**Symptom**: player signals hardcode `deathPhase: none`, so resolver can’t start death animation deterministically.

**Task**

* Pick a unified death representation for player + enemies:

  * Option A (recommended): use the existing `DeathStateStore` for player entity too
  * Option B: add minimal player-specific death tick fields
* Feed `deathPhase` and `deathStartTick` into `AnimSignals.player(...)`.

**Acceptance**

* On player death, death anim starts at frame 0 on the first death tick.
* No fallback to `lastDamageTick` is needed once systems always provide `deathStartTick`.

---

### [ ] Wire **dash ticks** (`dashTicksLeft`, `dashDurationTicks`)

**Symptom**: dash animation can’t trigger if the system never emits dash timing signals.

**Task**

* Identify dash state source (mobility store / intent / status).
* Emit:

  * `dashTicksLeft`
  * `dashDurationTicks`

**Acceptance**

* Dash anim plays exactly during dash window, and frame progresses deterministically.

---

### [ ] Stop emitting permanently disabled legacy timestamps for player (`lastMeleeTick/lastCastTick/lastRangedTick = -1`)

**Symptom**: legacy strike/cast/ranged anim paths are dead for player.

**Decision** (pick one and commit)

* **A — Remove legacy**: delete/ignore these fields for player entirely and rely on `ActiveAbilityStateStore` exclusively.
* **B — Support legacy**: wire real timestamps from intent stores / combat events.

**Acceptance**

* No “ghost” fields that are always `-1` unless they are explicitly deprecated.

---

## P1 — Determinism + visual consistency

### [ ] Add/emit **stunStartTick** (stun anim should be relative to stun start)

**Symptom**: with only `stunLocked: bool`, resolver tends to drive stun frames from global `tick`, producing phase noise.

**Task**

* Extend `AnimSignals` to include `stunStartTick`.
* Update the lock/control store to track the tick when stun became active.
* Emit `stunStartTick` from AnimSystem.

**Acceptance**

* Stun anim starts at frame 0 on stun application.
* Re-applying stun restarts (or follows your defined rule) deterministically.

---

### [ ] Clarify/guarantee `ActiveAbilityStateStore` semantics

**Risk**: if `activeAbility.frame` is not strictly relative to the ability start tick, animations will drift.

**Task**

* Document invariants:

  * `frame` is 0 on the first tick of the ability phase.
  * `frame` increments by 1 per sim tick while active.
* Ensure AnimSystem never “guesses” frame using global tick.

**Acceptance**

* Ability animations always start at frame 0.

---

## P2 — Maintainability + bug-proofing

### [ ] Make AnimSystem **read-only** with respect to gameplay state

**Rule**: AnimSystem should not cancel abilities, clear intents, or mutate combat state.

**Task**

* Audit for writes to gameplay stores.
* If any exist, move them to the owning gameplay system.

**Acceptance**

* Reordering AnimSystem in the pipeline never changes gameplay outcomes.

---

### [ ] Reduce duplication between `_stepPlayer` and `_stepEnemies`

**Task**

* Extract a small helper that builds `AnimSignals` from common store reads (hp, movement, stun, active ability, hit/death phases).
* Keep player-specific bits (dash/spawn) as overrides.

**Acceptance**

* Adding a new signal field requires changing code in one place.

---

### [ ] Add minimal unit tests (high ROI)

**Tests**

* Player spawn window uses `spawnStartTick`.
* Player death starts at `deathStartTick`.
* Dash emits correct frames.
* Active ability anim uses ability-relative frame.
* Stun uses `stunStartTick`.

---

## P3 — Performance (only after profiling)

### [ ] Avoid per-entity allocations if DevTools shows GC pressure

**Note**: keep resolver returning `AnimResult` until profiling proves it’s hot.

**If needed**

* Switch to `resolveInto(...)` that writes directly into `AnimStateStore` arrays.
* Or store `AnimKey + frameHint` directly without creating objects.

**Acceptance**

* Verified reduction in allocations + improved frame time/jank in profiler.

---

## Suggested implementation order

1. Player spawnStartTick (P0)
2. Player death state (P0)
3. Dash ticks (P0)
4. Decide legacy timestamps vs ActiveAbility-only (P0)
5. Stun start tick plumbing (P1)
6. Read-only audit + refactor helpers + tests (P2)
7. Perf only if profiled (P3)
