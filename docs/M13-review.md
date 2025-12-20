# Milestone 13 Review — Enemy Navigation (Surface Graph + Jump Templates)

This document reviews the **Milestone 13** navigation implementation (surface extraction → surface graph build → deterministic A\* → runtime navigator → enemy steering integration).

Scope:
- Core navigation modules: `lib/core/navigation/**`
- Runtime state + integration: `lib/core/ecs/stores/surface_nav_state_store.dart`, `lib/core/ecs/systems/enemy_system.dart`, `lib/core/game_core.dart`
- Geometry identity + collision contracts that the nav depends on: `lib/core/collision/static_world_geometry.dart`, `lib/core/track/v0_track_streamer.dart`, `lib/core/ecs/systems/collision_system.dart`
- Tests: `test/core/*surface*`, `test/core/jump_template_test.dart`, `test/core/ground_enemy_jump_test.dart`

Non-goals for this review:
- Camera, combat, UI, rendering.
- Large refactors that are not required to keep M13 functional and deterministic.

---

## 1) High-level architecture check

### What’s implemented (modules + responsibilities)

- **Jump reachability template**
  - `lib/core/navigation/jump_template.dart`
  - Precomputes fixed-tick ballistic samples and exposes `findFirstLanding(dy, dxMin, dxMax)`.
  - Used at graph-build time only (good separation).

- **Surface extraction**
  - `lib/core/navigation/surface_extractor.dart`
  - Extracts “walkable tops” from `StaticWorldGeometry`:
    - `StaticSolid.sideTop` → a walk surface at `yTop = solid.minY`
    - Optional ground plane → a walk surface at `yTop = groundPlane.topY`
  - Merges adjacent segments at the same y within an epsilon.
  - Splits the ground plane around obstacle walls (important for “jump obstacle on same ground”).

- **Surface spatial index**
  - `lib/core/navigation/surface_spatial_index.dart`
  - Grid buckets (`GridIndex2D`) for fast “what surface is under me?” and “what surfaces are nearby?” queries.
  - Uses a stamp-based de-dupe list; avoids per-query allocations (good).

- **Graph build**
  - `lib/core/navigation/surface_graph_builder.dart`
  - Builds:
    - nodes: `WalkSurface`
    - edges: `SurfaceEdge` (`jump` / `drop`)
    - offsets: adjacency ranges in a single edge array
  - Determinism measures:
    - stable per-surface build loop
    - stable candidate ordering per takeoff sample

- **Pathfinding**
  - `lib/core/navigation/surface_pathfinder.dart`
  - Deterministic A\* with bounded expansions.
  - Now includes:
    - base edge cost (seconds, derived from `travelTicks`)
    - **run-to-takeoff cost** (dx/runSpeedX), with a `startX` hint
    - **fallback**: `edgePenaltySeconds` to bias toward fewer hops

- **Runtime navigation controller**
  - `lib/core/navigation/surface_navigator.dart`
  - Per-entity cached path with repath cooldown.
  - Converts “next edge” into a simple intent: `{ desiredX, jumpNow, hasPlan }`.

- **Runtime state**
  - `lib/core/ecs/stores/surface_nav_state_store.dart`
  - Stores per-entity plan list, cursor, active edge, current/target surface ids, repath cooldown, graphVersion.

- **Enemy integration**
  - `lib/core/ecs/systems/enemy_system.dart`
  - Ground enemy reads `SurfaceNavIntent` and:
    - steers using accel/decel toward `desiredX`
    - executes jump via `velY = -jumpSpeed` when `jumpNow=true`

- **Graph lifecycle**
  - `lib/core/game_core.dart`
  - Rebuilds surface graph on static geometry changes (spawn/cull) and pushes it into `EnemySystem`.

### Fit with repo constraints (Core determinism + modularity)

Overall, this fits the repo’s architecture rules well:
- Navigation is pure Core (no Flame/UI imports).
- Static geometry changes trigger rebuild; runtime is allocation-light and deterministic.
- Enemy system consumes a minimal intent contract (good for reuse).

---

## 2) What’s strong / good practice

- **Determinism is explicitly engineered**
  - Stable tie-breaking in A\* (`fScore`, then `gScore`, then `surfaceId`).
  - Stable candidate ordering for edge generation.
  - No reliance on `Map`/`Set` iteration order for path selection.

- **Runtime is low-allocation**
  - `SurfaceSpatialIndex.queryAabb` reuses output list + stamp array.
  - `SurfaceNavigator` reuses a candidate buffer; plans are reused lists.
  - `SurfacePathfinder` reuses internal arrays.

- **Clear separation between build-time and runtime**
  - Jump template and edge generation are build-time.
  - Runtime only locates surfaces, runs bounded A\* occasionally, and executes intents.

- **The ID scheme is aligned with streaming**
  - `StaticSolid.localSolidIndex` is set in `V0TrackStreamer` and combined with `chunkIndex`.
  - `packSurfaceId()` provides lexicographic ordering and stable identity within a graph build.

---

## 3) Correctness issues / gameplay contract gaps

### (High) Drop edges are generated but not cleanly executable

Code today:
- Builder emits `SurfaceEdgeKind.drop` edges with a `takeoffX` slightly beyond the edge.
- `SurfaceNavIntent` has no “drop commit” signal.
- `SurfaceNavigator` treats drop edges like jump edges (same state machine), but never forces “walk past the edge until airborne”.

Why it matters:
- With the current “stop within X distance” steering, a drop is very easy to **never actually trigger** (stop early and remain grounded).
- This becomes more likely now that `takeoffEps` is tuned to match `groundEnemyStopDistanceX`.

Minimal, scalable fix direction (no new systems required):
- Extend `SurfaceNavIntent` with `dropNow` (or `commitX` / `mustMoveUntilAirborne`).
- For drop edges, drive the entity slightly **past** the surface boundary until `grounded=false`, then keep aiming at `landingX` while falling.

### (High) `SurfaceExtractor` uses `assert` for a real identity contract

In `lib/core/navigation/surface_extractor.dart`:
- Missing `localSolidIndex` for chunk solids triggers `assert(false, ...)`.
- In release builds (asserts stripped), it silently falls back to `localSolidIndex = i`.

Why it matters:
- This turns a deterministic identity bug into a “works in debug, potentially unstable in release” bug.

Safer behavior:
- Throw a `StateError` for chunk solids with missing `localSolidIndex` (always, not just in debug).

### (Medium) Cost model is now “time-like”, but the graph node state is still “surface-only”

Pathfinding now includes a run-to-takeoff cost that depends on position (via `startX`).
This is enough to fix the *first decision* (“jump obstacle now”) but it’s only position-correct on the start surface.

Risk:
- If later you extend run cost to depend on *arrival X* per surface (more accurate), A\* state would need to include arrival position (or a conservative approximation), otherwise optimality can break.

Recommendation:
- Keep the current approach for V0 (good tradeoff).
- Document this explicitly in `SurfacePathfinder` so future changes don’t accidentally invalidate the state model.

---

## 4) Determinism audit (what to keep an eye on)

### Good
- `SurfaceGraphBuilder` produces deterministic edge order via:
  - deterministic surface list ordering (extract+sort)
  - deterministic candidate ordering per query
- `SurfacePathfinder` tie-breaks deterministically.
- `SurfaceSpatialIndex.queryAabb` has deterministic cell scan order.

### Watch-outs
- Both `packSurfaceId()` and `GridIndex2D.cellKey()` pack 2×32-bit lanes into a single `int` via `<< 32`.
  - This is fine on Dart VM/AOT (mobile).
  - If you ever target JS (Flutter web), 64-bit bit packing is not safe with JS number semantics. (V0 target is mobile, but it’s worth noting.)

---

## 5) Performance review (hot paths + build paths)

### Runtime (per tick)

Main runtime work per nav-enabled enemy:
- Locate current/target surface when grounded (spatial index query + small scan).
- Repath only every `repathCooldownTicks` and only when grounded.

This is a good shape for mobile:
- Allocation-light.
- Bounded A\* expansions.

### Graph rebuild (on spawn/cull)

Potential hotspots in `SurfaceGraphBuilder.build()`:
- **Per-takeoff `tempCandidates.sort`**
  - Sorting every query is deterministic, but it can dominate rebuild time if there are many takeoff samples.
- **Drop landing search is O(S)**
  - `_findFirstSurfaceBelow` scans all surfaces; called per surface per drop sample.
- **Edge explosion risk**
  - Keeping multiple jump edges per target (to support “nearest takeoff”) increases edge count and increases per-search neighbor iteration.

Why it’s still probably OK for V0:
- Rebuild cadence is tied to chunk spawn/cull, not every tick.
- Surface counts are expected to remain relatively small with V0 patterns.

Low-overhead mitigations (if needed later):
- Avoid sorting candidates per query by ensuring deterministic bucket ordering and accepting “surface index order” as the stable order.
- Add simple edge pruning:
  - cap takeoff samples per surface
  - keep only the best K edges per target surface (by cost + takeoff distance)

---

## 6) Redundancy / maintainability smells

- `V0GroundEnemyTuning.groundEnemyJumpCooldownSeconds` exists but is not enforced by navigation-driven jumping.
  - Either wire it back in (cooldown gating) or remove it to avoid “tuning that does nothing”.

- `GameCore` stores `_surfaceGraph` / `_surfaceSpatialIndex` but does not read them after assigning.
  - Either remove, or expose them intentionally for debug/telemetry.

- Epsilon usage is scattered (`1e-6`, `1e-9`, `1e-3`) across modules.
  - Not wrong, but it becomes hard to tune/debug.
  - A small “nav tolerances” struct/consts (still in Core) would improve clarity.

---

## 7) Test coverage review

Current strengths:
- Template determinism + correctness (`test/core/jump_template_test.dart`)
- Extraction merge correctness + spatial index sanity (`test/core/surface_extraction_test.dart`)
- Graph build determinism and basic edge expectations (`test/core/surface_graph_builder_test.dart`)
- Pathfinder determinism and “nearest takeoff from startX” behavior (`test/core/surface_pathfinder_test.dart`)
- End-to-end: ground enemy reaches a higher platform (`test/core/ground_enemy_jump_test.dart`)

Coverage gaps worth adding (prioritized):
1) **Obstacle jump on same ground**
   - Geometry: ground plane + obstacle block that splits the ground surface.
   - Expectation: ground enemy reaches a player beyond the obstacle via a same-y jump edge.
2) **Drop edge execution**
   - Geometry: platform with another platform below it.
   - Expectation: enemy can plan and actually execute a drop (requires the runtime “drop commit” contract).
3) **“Ceilings do not block jumps” contract**
   - Geometry: a low ceiling above the enemy; enemy still jumps to reach a target surface because `ignoreCeilings=true`.
4) **Graph version invalidation**
   - Simulate geometry rebuild; ensure cached plans invalidate and replans are deterministic.

---

## 8) Recommended next steps (minimal, scalable)

If the goal is “production-grade M13 without overengineering”, the top fixes are:

1) **Add an explicit drop-commit signal** to `SurfaceNavIntent` and handle it in `EnemySystem` steering.
2) **Replace the `assert(false, ...)` identity check** with a real runtime error for chunk solids missing `localSolidIndex`.
3) **Move magic nav knobs into tuning/config**
   - `edgePenaltySeconds`
   - `takeoffSampleMaxStep`
   - `takeoffEps` (or tie it explicitly to stop distance in one place)
4) Add the two missing end-to-end tests: obstacle jump, drop execution.

---

## Appendix — File map (quick links)

- Navigation:
  - `lib/core/navigation/jump_template.dart`
  - `lib/core/navigation/surface_extractor.dart`
  - `lib/core/navigation/surface_graph_builder.dart`
  - `lib/core/navigation/surface_graph.dart`
  - `lib/core/navigation/surface_spatial_index.dart`
  - `lib/core/navigation/surface_pathfinder.dart`
  - `lib/core/navigation/surface_navigator.dart`
  - `lib/core/navigation/surface_id.dart`
  - `lib/core/navigation/walk_surface.dart`

- Runtime integration:
  - `lib/core/ecs/stores/surface_nav_state_store.dart`
  - `lib/core/ecs/systems/enemy_system.dart`
  - `lib/core/game_core.dart`

- Identity / collision contracts:
  - `lib/core/collision/static_world_geometry.dart`
  - `lib/core/track/v0_track_streamer.dart`
  - `lib/core/ecs/systems/collision_system.dart`

