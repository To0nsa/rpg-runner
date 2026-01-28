# TODO — `lib/core/ecs/stores/anim_state_store.dart`

> Goal: keep `AnimStateStore` **SoA-fast**, safe against misuse (silent resets), and aligned with how AnimSystem writes animation state.

---

## P0 — Correctness / misuse prevention

### [ ] Prevent silent state reset when `add()` is called for an existing entity

**Problem**: `addEntity(entity)` returns an index even if the entity already exists. Calling `add()` twice will overwrite current anim state (idle/0) and hide bugs.

**Fix options** (pick one):

**Option A (recommended): split intent explicitly**

* `ensure(int entity)` → add if missing, do not modify state if already present
* `reset(int entity)` → force idle + frame 0
* Keep `add()` private or remove it.

**Option B: strict add**

* `add(int entity)` asserts `!has(entity)` in debug builds (and/or throws in release if you want to be strict).

**Acceptance**

* Calling “add/ensure” twice never accidentally resets animation.
* Resets are explicit.

---

### [ ] Reduce redundancy between `add()` and `onDenseAdded()`

**Problem**: both set the default state to idle/0 (duplication).

**Task**

* Centralize default initialization in one place.

  * Usually: `onDenseAdded()` initializes arrays, and callers use `ensure()`.

**Acceptance**

* Only one initialization path exists.

---

## P1 — API clarity & ergonomics

### [ ] Provide explicit setters used by systems

AnimSystem likely does something like `store.anim[i]=...; store.animFrame[i]=...`.

**Task**

* Add small helpers for clarity and future invariants:

  * `setByIndex(int dense, AnimKey key, int frame)`
  * `set(int entity, AnimKey key, int frame)`

**Why**

* Makes it trivial to add clamps/invariants later without rewriting every call site.

**Acceptance**

* Systems don’t manually poke arrays everywhere.

---

### [ ] Consider adding getters with safe defaults

**Task**

* `AnimKey getAnim(int entity, {AnimKey defaultKey = AnimKey.idle})`
* `int getFrame(int entity, {int defaultFrame = 0})`

**Acceptance**

* Render path doesn’t need to special-case missing anim state.

---

## P2 — Invariants & safety

### [ ] Clamp/validate `animFrame` (debug)

**Problem**: negative frames or huge frames indicate broken start ticks upstream.

**Task**

* In debug builds:

  * assert `animFrame >= 0`
  * optionally assert `animFrame < someReasonableMax` (or leave unbounded but log)

**Acceptance**

* Broken upstream timing is caught early.

---

### [ ] Document store semantics

Add a short comment describing:

* What `animFrame` means (tick-relative frame hint)
* Whether it can be absolute tick (should converge to “relative ticks since anim start”)
* Who writes it (AnimSystem only)

**Acceptance**

* Future systems don’t mutate anim state.

---

## P3 — Performance (only if needed)

### [ ] Keep arrays tight and reuse memory

Already good: `ensureDenseLength` + `swapRemoveDense`.

**Task**

* If you start storing more fields, keep them SoA and avoid per-entity objects.

---

### [ ] Optional: expose a `writeView` for batched updates

If you want ultra-hot-loop writing:

* expose references or a tiny struct wrapper to avoid repeated bounds checks.

**Only do this after profiling.**

---

## Suggested implementation order

1. Add `ensure()` + `reset()` (or strict `add()`) (P0)
2. Remove redundant init path (P0)
3. Add `set()/setByIndex()` helpers (P1)
4. Add debug asserts + comments (P2)
5. Perf-only changes after profiling (P3)
