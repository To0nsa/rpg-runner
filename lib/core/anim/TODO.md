# TODO — `lib/core/anim/anim_resolver.dart`

> Goal: make animation selection **correct + deterministic**, eliminate “global tick” frame drift, and harden the resolver against missing/invalid start ticks.

---

## P0 — Must fix (will cause visible glitches)

### [ ] Fix Spawn timing (currently assumes spawn starts at tick 0)

**Problem**: spawn condition uses `tick < spawnAnimTicks`, so any entity spawning after tick 0 will either:

* never show spawn anim, or
* show spawn anim at the wrong time window.

**Patch (core idea)**:

* Use `spawnStartTick` as the reference.
* Only show spawn if `spawnStartTick >= 0`.

**Acceptance**:

* Spawn anim plays for exactly `spawnAnimTicks` after `spawnStartTick`.
* Entities that spawn mid-run still show the spawn anim.

**Implementation sketch**:

* `final showSpawn = profile.supportsSpawn && signals.spawnAnimTicks > 0 && signals.spawnStartTick >= 0 && (tick - signals.spawnStartTick) < signals.spawnAnimTicks;`
* Resolve spawn using `animFrame: _frameFromTick(tick, signals.spawnStartTick)`.

---

### [ ] Stabilize Death timing (avoid falling back to `lastDamageTick`)

**Problem**:

* When `hp <= 0` but `deathPhase` is not set, resolver falls back to `_frameFromTick(tick, lastDamageTick)`.
* That’s fragile: `lastDamageTick` can be stale / missing / from a previous hit (esp. pooled entities or multi-hit sequences).

**Fix policy**:

1. Prefer `deathStartTick` whenever the entity is dead/dying.
2. Only fallback to `lastDamageTick` if you *must* support legacy cases, but make that path safe.

**Acceptance**:

* Death anim starts on the correct tick (first tick of death).
* No “death anim jumps forward” on spawn/despawn or after delayed kills.

**Tasks**:

* Update the `hp <= 0` branch to reference `deathStartTick` when available.
* Add a **strict invariant**: systems should always set `deathStartTick` when entering any death state.

---

### [ ] Make Active Action mapping strict (don’t return unknown keys)

**Problem**: `_mapActiveActionKey()` returns `key` by default.

* If a profile doesn’t actually support that key (or there’s no atlas entry), the renderer will try to play a non-existent animation.
* This can cause flicker, silent fallback, or asset lookup failures.

**Fix**:

* Default should be `null`, not `key`.
* Only pass through keys you *explicitly* whitelist.

**Acceptance**:

* If the action key isn’t supported/mapped → resolver falls through to normal locomotion/idle.

**Tasks**:

* Update `_mapActiveActionKey()`:

  * Keep explicit cases.
  * `default: return null;`
* (Optional) add an assert/log in debug builds when an unknown active action key is requested.

---

## P1 — Determinism upgrades (removes subtle drift)

### [ ] Make Stun animation deterministic relative to stun start

**Problem**: stun returns `animFrame: signals.tick`.

* That makes stun frames depend on global time.
* Two identical stuns starting on different ticks will appear in different phases, which looks noisy and breaks determinism assumptions if you ever re-sim/seek.

**Fix**:

* Add `stunStartTick` to `AnimSignals` and use `_frameFromTick(tick, stunStartTick)`.

**Acceptance**:

* On the first tick of stun lock, stun anim starts at frame 0.
* Multiple stuns always start from frame 0.

**Related changes (outside this file)**:

* Where `stunLocked` is computed, also compute `stunStartTick` (or store it in a lock/store).

---

### [ ] Stop using raw `tick` as `animFrame` for jump/fall (optional but cleaner)

**Problem**: jump/fall uses `animFrame: tick`.

* This is “global time driven” again. If jump/fall is looping it’s fine-ish, but if it’s authored as one-shot it’s wrong.

**Options**:

* **Option A (minimal)**: keep as-is for looped jump/fall strips.
* **Option B (better)**: add `airStartTick` or `jumpStartTick` and resolve frames relative.

**Acceptance**:

* If jump/fall is authored as one-shot, it progresses from frame 0 at start.

---

## P2 — Correctness hardening + maintainability

### [ ] Centralize “frame origin semantics”

Right now different branches use different semantics:

* Some use `_frameFromTick(tick, startTick)` (strike/cast/hit/death)
* Some use `tick` directly (stun/jump/fall/spawn currently)
* Some use a computed delta (dash)

**Task**:

* Create a clear convention in comments:

  * `animFrame` is always **relative tick since animation started** (preferred).
  * If an animation is looped and doesn’t need start tick, explain why you’re using `tick`.

---

### [ ] Clamp negative deltas defensively

**Problem**: in dash, you already clamp negative to 0. For other `_frameFromTick` uses, if a bad `startTick` sneaks in you can get negative frames.

**Task**:

* Consider making `_frameFromTick()` clamp at 0:

  * `final dt = startTick >= 0 ? tick - startTick : tick; return dt < 0 ? 0 : dt;`

**Acceptance**:

* No negative `animFrame` reaches renderer.

---

### [ ] Add resolver unit tests (cheap + high ROI)

Add tests covering the exact bugs you’re fixing:

**Tests**:

* Spawn: `tick=100`, `spawnStartTick=95`, `spawnAnimTicks=10` → spawn plays for ticks 95..104 and stops at 105.
* Death: `hp=0`, `deathStartTick=200`, `lastDamageTick=10` → death anim frame is `tick-200` not `tick-10`.
* ActiveAction mapping: unknown key returns `null` and resolver falls through.
* Stun: if you add `stunStartTick`, stun anim frame is `tick-stunStartTick`.

---

## Notes / Quick audit checklist

* [ ] Ensure `deathStartTick` is reliably populated for enemies AND player paths (don’t let “hp<=0 without deathPhase” happen long-term).
* [ ] Ensure spawn start tick is set at entity creation and survives snapshotting (if pooled entities exist).
* [ ] Ensure Active Action `frame` passed into resolver is already a relative frame/tick (document it).

---

## Suggested implementation order

1. Spawn fix (P0)
2. Death fix (P0)
3. Active action strict mapping (P0)
4. Stun start tick plumbing (P1)
5. Optional: unify tick-relative semantics + clamps + tests (P2)
