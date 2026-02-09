# TODO — `lib/core/ecs/systems/anim/anim_system.dart`

Goal: ensure AnimSystem emits complete, deterministic `AnimSignals` and remains
read-only with respect to gameplay state.

Scope: signal assembly and `AnimStateStore` writes in this system.  
Resolver branch behavior belongs to `lib/core/anim/TODO.md`.

---

## Current state audit (as of now)

- Enemy `deathPhase` and `deathStartTick` are wired into `AnimSignals.enemy` (good).
- Player `deathPhase/deathStartTick` are provided by `GameCore` lifecycle state.
- Player emits `spawnStartTick` from authoritative spawn-time tracking.
- Dash animation now resolves only through active-action (`ability.animKey`).
- Stun emits both `stunLocked` and `stunStartTick` (continuous-window origin).
- Active action frame uses `activeAbility.elapsedTicks` (good).
- `_resolveActiveAction` is render-only (does not mutate gameplay stores).
- Player no longer wires legacy strike/cast/ranged timestamps in active signal assembly.
- Shared signal reads are centralized via `_readCommonSignals(...)`.

---

## P0 — Correctness and architecture safety

### [x] Make AnimSystem read-only (no gameplay mutation)

Problem:
- `_resolveActiveAction` currently clears `ActiveAbilityStateStore` on several branches.
- This couples rendering order to gameplay outcomes.

Tasks:
- Remove `world.activeAbility.clear(...)` calls from AnimSystem.
- Treat invalid/expired active ability as "no active action" for rendering only.
- Keep lifecycle authority in gameplay systems (for example `ActiveAbilityPhaseSystem`).

Acceptance:
- Calling AnimSystem multiple times in one tick does not change gameplay state.
- Reordering AnimSystem in the tick pipeline does not alter gameplay outcomes.

### [x] Wire player death lifecycle into signals

Problem:
- Player signals always use `deathPhase: none`, so resolver cannot use player death timing deterministically.

Tasks:
- Add/choose authoritative player death lifecycle source.
- Emit `deathPhase` and `deathStartTick` in `AnimSignals.player(...)`.
- Ensure player path matches resolver expectations from `lib/core/anim/TODO.md`.

Acceptance:
- Player death animation starts at frame 0 on death start tick.
- Player death frame origin is not derived from stale damage ticks.

### [x] Wire player `spawnStartTick`

Problem:
- AnimSystem emits only `spawnAnimTicks`, not the start tick.

Tasks:
- Add authoritative spawn start tick source for player entity.
- Emit `spawnStartTick` in `AnimSignals.player(...)`.

Acceptance:
- Spawn animation timing is correct for entities spawned mid-run, not only at run start.

---

## P1 — Determinism and contract clarity

### [x] Decide dash signal contract (legacy dash path vs active-action-only)

Current behavior:
- Dash rendering is already covered by active-action mapping for ability-driven dashes.
- Resolver no longer consumes legacy dash timer signals (`dashTicksLeft/dashDurationTicks`).

Decision:
- Option B: treat dash as active-action-only and remove legacy `dashTicksLeft`/`dashDurationTicks` signal usage.

Acceptance:
- Exactly one authoritative dash animation path is documented and tested.

### [x] Add stun start tick plumbing (if stun should restart from frame 0)

Problem:
- `stunLocked` alone is insufficient for relative frame timing.

Tasks:
- Extend signal contract with `stunStartTick` (requires control-lock source update).
- Emit stun start tick from AnimSystem once available.
- Use continuous-window semantics: refresh extends stun without restarting frame origin.

Acceptance:
- Stun frame origin is deterministic relative to stun application.

### [x] Remove or formally deprecate dead legacy timestamp wiring

Problem:
- Player previously set `lastStrikeTick/lastCastTick/lastRangedTick` to `-1` every tick.

Tasks:
- Either remove these fields from player signal path, or mark and document them as deprecated compatibility fields.

Acceptance:
- No ambiguous "always disabled" fields in active player signal construction.

---

## P2 — Tests and regression guards

### [x] Expand AnimSystem integration tests for signal correctness

Add/adjust tests for:
- Player spawn window with non-zero `spawnStartTick`.
- Player death frame origin from `deathStartTick`.
- Dash behavior for chosen contract (P1 decision).
- Stun behavior when `stunStartTick` is available.

### [x] Add read-only behavior test

Test:
- Running AnimSystem should not mutate `ActiveAbilityStateStore` (or other gameplay stores).

---

## P3 — Maintainability cleanup

### [x] Reduce signal-building duplication between player and enemy paths

Task:
- Extract focused helpers for shared store reads and signal defaults.

Acceptance:
- New signal fields are added in one place, not scattered logic.

### [x] Keep TODO alignment with resolver TODO

Task:
- Keep this file aligned with `lib/core/anim/TODO.md` so responsibilities do not drift.

---

## Suggested order

1. P0 read-only fix (high safety value).
2. P0 player death + spawn tick signal wiring.
3. P1 dash contract decision.
4. P1 stun start tick plumbing.
5. P2 test expansion.
6. P3 refactor/cleanup.
