# TODO — `lib/core/anim/anim_resolver.dart`

Goal: make resolver output deterministic, branch-safe animation keys/frames.

Scope: resolver-only logic in this file.  
Signal sourcing/plumbing tasks belong to `lib/core/ecs/systems/anim/TODO.md`.

---

## Current state audit (as of now)

- `deathPhase == deathAnim` already uses `deathStartTick` (good).
- Active ability frame comes from `activeActionFrame` (good).
- Dash now resolves through active-action mapping only (no legacy dash-timer branch).
- Spawn window is relative to `spawnStartTick` (good).
- `hp <= 0` now prefers `deathStartTick` and falls back to frame 0 when missing.
- Active-action mapping is strict (unknown keys fall through).
- Jump/fall/idle/walk/run use global tick for `animFrame` by design.
- `AnimSystem` no longer wires player legacy strike/cast/ranged timestamps.
- `AnimResolver` no longer exposes or evaluates legacy strike/cast/ranged signal fields.

---

## P0 — Resolver correctness (high impact, local to this file)

### [x] Spawn window must be relative to `spawnStartTick`

Current behavior can miss or mis-time spawn animation for entities spawned after tick 0.

Tasks:
- Gate spawn on `spawnStartTick >= 0`.
- Use `(tick - spawnStartTick) < spawnAnimTicks`.
- Emit spawn frame via `_frameFromTick(tick, spawnStartTick)`.

Acceptance:
- Spawn plays exactly for the authored window after actual spawn tick.
- Mid-run spawns behave the same as tick-0 spawns.

### [x] Remove fragile death fallback to `lastDamageTick`

Current `hp <= 0` path can jump frames from stale hit data.

Tasks:
- Prefer `deathStartTick` whenever dead/death path is active.
- Keep legacy fallback only if unavoidable, and make it explicit in comments.

Acceptance:
- Death starts at frame 0 on first death tick.
- No frame jumps from stale `lastDamageTick`.

### [x] Make active-action mapping strict

Current default `return key` can request unsupported/unmapped animations.

Tasks:
- Change default mapping to `null`.
- Only pass keys explicitly supported by profile/case mapping.
- Optional debug assert/log when an unknown key is requested.

Acceptance:
- Unknown action keys fall through to normal resolver branches.
- No silent render lookups for missing animation strips.

### [x] Clamp `_frameFromTick` to non-negative

Defensive hardening against invalid future start ticks.

Acceptance:
- No negative `animFrame` leaves resolver.

---

## P1 — Determinism semantics (resolver + signal contract)

### [x] Define frame-origin policy for every branch

Document whether each branch is:
- relative-to-start (`_frameFromTick`), or
- global-tick-driven intentionally (looped cosmetic behavior).

Current mixed policy is now documented in resolver docs and covered by unit
tests to prevent regressions.

### [x] Stun should be relative to stun start (if design requires restart semantics)

Requires `stunStartTick` signal from AnimSystem/control-lock path.

Acceptance:
- Stun starts at frame 0 when stun is applied.
- Reapplied stun follows defined rule deterministically (continuous-window origin).

### [x] Decide jump/fall/locomotion frame policy

Decision:
- Keep global tick intentionally for jump/fall/idle/walk/run locomotion loops.

Rationale:
- Keeps loop phase continuity through brief state toggles.
- Avoids extra start-tick plumbing for locomotion-only strips.

---

## P2 — Tests and regression safety

### [x] Add resolver unit tests (not only AnimSystem integration tests)

Minimum cases:
- Spawn with `spawnStartTick` in mid-run.
- Dead entity with `deathStartTick` and stale `lastDamageTick`.
- Unknown active-action key falls through (no unsupported key emitted).
- `_frameFromTick` never returns negative.

### [x] Update/extend AnimSystem integration tests to match new resolver contract

Integration coverage now validates:
- spawn window from `spawnStartTick`,
- death frame origin from `deathStartTick`,
- strict active-action behavior,
- explicit AnimSystem read-only behavior.

---

## P3 — Cleanup after behavior decisions

### [x] Remove dead/legacy fields from `AnimSignals` when no longer needed

Examples addressed:
- removed legacy strike/cast/ranged timestamp fields from `AnimSignals`,
- removed resolver legacy-action branches in favor of active-action authority.

### [x] Keep this TODO aligned with `lib/core/ecs/systems/anim/TODO.md`

Avoid duplicated tasks with conflicting acceptance criteria.

---

## Suggested order

1. P0 resolver correctness fixes.
2. P2 resolver unit tests for new behavior.
3. P1 semantic decisions and required signal plumbing.
4. P3 contract cleanup after migration stabilizes.
