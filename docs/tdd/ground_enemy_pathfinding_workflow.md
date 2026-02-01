# Ground Enemy Pathfinding & Navigation Workflow

This project uses **surface-graph navigation** for ground enemies (currently `EnemyId.grojib`), not tile-grid pathfinding.

At a high level:

1. **Offline/level-build step**: extract walkable **surfaces** and build a directed **surface graph** with *jump* and *drop* edges.
2. **Runtime (every tick)**:
   - choose a **navigation target** (player X, or predicted landing X if the player is airborne),
   - map both **enemy** and **target** onto **surface IDs**,
   - run **A\*** on the surface graph when needed,
   - output a small **intent** (`desiredX`, `jumpNow`, `commitMoveDirX`) used by the locomotion controller.

---

## 0) Key Files

### Navigation core
- `lib/core/navigation/surface_graph_builder.dart` — builds `SurfaceGraph` + `SurfaceSpatialIndex` from static geometry.
- `lib/core/navigation/types/surface_graph.dart` — graph types (`SurfaceGraph`, `SurfaceEdge`, `SurfaceEdgeKind`).
- `lib/core/navigation/surface_pathfinder.dart` — **A\*** implementation over the surface graph.
- `lib/core/navigation/surface_navigator.dart` — per-entity runtime controller that:
  - locates surfaces,
  - triggers replans,
  - executes edges (walk → takeoff → jump/drop → land).

### Runtime ECS integration (ground enemy AI)
- `lib/core/ecs/systems/enemy_navigation_system.dart` — computes navigation intents (targeting + calls `SurfaceNavigator.update`).
- `lib/core/ecs/stores/enemies/surface_nav_state_store.dart` — per-entity navigation state (surface IDs, path edges, cooldowns).
- `lib/core/ecs/stores/enemies/nav_intent_store.dart` — per-entity **output intent** (`desiredX`, `jumpNow`, `hasPlan`, `commitMoveDirX` + safe surface bounds).
- `lib/core/ecs/systems/ground_enemy_locomotion_system.dart` — turns nav intent into velocities/jumps.
- `lib/core/navigation/utils/trajectory_predictor.dart` — predicts where an airborne player will land.
- `lib/core/navigation/utils/surface_spatial_index.dart` — AABB-to-surface candidate query acceleration.
- `lib/core/navigation/types/nav_tolerances.dart` — epsilons affecting determinism and robustness.

---

## 1) Data Model (what the pathfinder runs on)

### 1.1 Walkable surfaces = graph nodes

A **surface** is a continuous walkable segment (top of a platform). Surfaces have:

- `xMin`, `xMax` (walkable horizontal extent)
- `yTop` (height)
- `id` (packed stable identifier via `surface_id.dart`)

Surfaces live in `SurfaceGraph.surfaces` and are indexed `0..N-1`.

### 1.2 Transitions = directed edges

A `SurfaceEdge` connects one surface to another:

- `to`: destination surface index
- `kind`: `jump` or `drop`
- `takeoffX`: where to leave the current surface
- `landingX`: where we expect to land on the next surface
- `commitDirX`: -1 / 0 / +1 direction lock used during approach/execution
- `travelTicks`: estimated time in ticks
- `cost`: cost used by A* (time-ish), including penalties

Edges are stored in CSR format:
- `edgeOffsets[i]..edgeOffsets[i+1]` are the outgoing edges for surface `i`.

---

## 2) Graph Build Pipeline (SurfaceGraphBuilder)

**Entry point**: `SurfaceGraphBuilder.build(geometry, jumpTemplate)`.

Pipeline:

1. **Extract surfaces** from static world geometry (`SurfaceExtractor`).
2. **Build a spatial index** (`SurfaceSpatialIndex.rebuild(surfaces)`) to support fast surface queries at runtime.
3. **Generate edges per surface**:
   - **Drop edges**: sample ledge endpoints, find the first surface below, create a `drop` edge.
   - **Jump edges**: sample takeoff points along the standable range, test reachability using a **precomputed jump arc** (`JumpReachabilityTemplate`), create `jump` edges to reachable surfaces.
4. Pack into CSR format and build `indexById` lookup.

**Important knobs** (in `SurfaceGraphBuilder`):
- `standableEps`: numeric tolerance when computing standable ranges.
- `dropSampleOffset`: nudges takeoff *past* the ledge so the entity actually falls.
- `takeoffSampleMaxStep`: controls edge density (more samples = more edges = more path options, higher build cost and runtime branching).

---

## 3) Runtime Target Selection (EnemyNavigationSystem)

**System**: `EnemyNavigationSystem.step(world, player, currentTick)`.

### 3.1 Raw target
Default is to chase the player:

- `rawTargetX = playerX`
- `rawTargetBottomY = playerBottomY` (derived from collider)
- `rawTargetGrounded = playerGrounded`

### 3.2 Airborne target prediction (TrajectoryPredictor)

If the player is **not grounded** and a `TrajectoryPredictor` exists:

- simulate trajectory tick-by-tick (semi-implicit Euler, matching gravity integration),
- detect the first surface intersection,
- return a `LandingPrediction` with predicted `(x, bottomY, surfaceIndex, ticksToLand)`.

If prediction succeeds, the target becomes the **predicted landing point** (and is treated as grounded for nav).

This prevents dumb behavior like enemies trying to path to the player mid-air where no surface exists.

### 3.3 Reaction delay (optional)
`GroundEnemyNavigationTuning.chaseTargetDelayTicks` introduces deterministic "reaction time".

Implementation detail:
- target samples are pushed into circular buffers (`_targetHistoryX`, etc.)
- the system reads a delayed entry (N ticks old) and uses that as `navTargetX/bottomY/grounded`.

### 3.4 Per-enemy intent generation
For each ground enemy (`EnemyId.grojib`):

- store `navTargetX` into `NavIntentStore.navTargetX`
- call `SurfaceNavigator.update(...)`
- write results into:
  - `NavIntentStore.desiredX`
  - `NavIntentStore.jumpNow`
  - `NavIntentStore.hasPlan`
  - `NavIntentStore.commitMoveDirX`

If no plan is available, the system additionally computes **safe surface bounds**
(from the enemy’s current surface) to clamp fallback movement and avoid walking off ledges.

---

## 4) Runtime Navigation State (SurfaceNavStateStore)

This store persists per-enemy navigation state:

- `graphVersion`: invalidates paths when the graph rebuilds
- `repathTicksLeft`: cooldown to avoid thrashing
- `currentSurfaceId`: where the enemy currently stands (if grounded)
- `targetSurfaceId`: where the target stands (if grounded)
- `pathEdges`: list of edge indices (the planned path)
- `pathCursor`: which edge we are executing
- `activeEdgeIndex`: currently “in execution” edge index (>= 0 means we have taken off / committed)

This SOA design is deliberate:
- no per-entity allocations in hot loops
- multiple enemies share a single `SurfaceNavigator`

---

## 5) Mapping positions to surfaces (SurfaceNavigator + SurfaceSpatialIndex)

**Step 1 in `SurfaceNavigator.update`** is locating surfaces:

- Query `SurfaceSpatialIndex.queryAabb(...)` for candidate surfaces near the entity’s footprint.
- Filter candidates by:
  - horizontal overlap with `[x - halfWidth, x + halfWidth]`
  - vertical proximity to `bottomY` within `surfaceEps`
- Pick the **highest** valid surface (lowest `yTop` in screen coords),
  tie-break by **surface ID** for determinism.

This produces:
- `currentSurfaceId` (only if the entity is grounded)
- `targetSurfaceId` (only if the target is grounded)

If either is unknown, pathfinding cannot run.

---

## 6) A* Pathfinding (SurfacePathfinder)

The actual path search for ground enemies is **A\*** over `SurfaceGraph`.

### 6.1 Inputs
`findPath(graph, startIndex, goalIndex, outEdges, startX, goalX)`

- `startIndex` / `goalIndex` are surface indices found via `indexOfSurfaceId`.
- `startX` / `goalX` (optional) refine cost calculations so paths are sensitive to the actual position along the surface.

### 6.2 Heuristic (admissible)
The heuristic is based on horizontal distance divided by run speed (time estimate).
That keeps A* optimal for the cost model (time-ish).

### 6.3 Edge cost model (time-ish)
Each edge’s cost includes:
- the edge’s intrinsic cost (transition + travel ticks)
- plus run distance to reach `takeoffX` and settle near `landingX`
- optionally a flat `edgePenaltySeconds` to discourage excessive transitions

### 6.4 Determinism + performance tricks
The implementation is optimized for many small searches:

- **generation stamps** (`_searchGeneration`, `_nodeGenerations`) avoid clearing arrays every search
- reusable arrays for `_gScore`, `_fScore`, `_cameFromEdge`, `_cameFromNode`, `_open`
- tie-breaking: prefer lower `g`, then lower surface ID (stable)
- open set uses **linear scan** (acceptable for small graphs; swap to a binary heap if graphs grow)

There’s also `maxExpandedNodes` to cap CPU and prevent runaway searches.

### 6.5 Output
`outEdges` becomes an ordered list of edge indices that must be executed from start to goal.

---

## 7) Repathing rules (SurfaceNavigator)

In `SurfaceNavigator.update`:

1. If `graphVersion` changed:
   - clear `pathEdges`, reset cursors, reset cooldown.
2. Decrement `repathTicksLeft`.
3. If `currentSurfaceId` or `targetSurfaceId` changed:
   - reset cooldown to allow immediate repath.
4. If grounded + cooldown expired + both surfaces known:
   - call A* and store plan in `pathEdges`
   - reset `pathCursor = 0`, `activeEdgeIndex = -1`
   - set `repathTicksLeft = repathCooldownTicks`

**Same-surface shortcut**:
- If current surface == target surface:
  - clear plan and return a direct intent toward `targetX`
  - note: this returns `hasPlan: false` by design (because no edges are needed)

---

## 8) Executing a plan (SurfaceNavigator -> intent)

When a plan exists, `SurfaceNavigator` emits a per-tick `SurfaceNavIntent`.

### 8.1 Plan empty / cursor past end
Return:
- `desiredX = targetX`
- `jumpNow = false`
- `hasPlan = false`

### 8.2 If `activeEdgeIndex >= 0` → we are executing an edge
Meaning: we already reached takeoff and committed.

- If grounded and `currentSurfaceId == surface(to)`:
  - edge is complete → advance cursor, clear active edge
- For **drop edges**:
  - while grounded: keep moving to `takeoffX` with `commitMoveDirX` (so we actually leave the ledge)
  - in flight: keep `commitMoveDirX` stable (prevents tiny reversals)
- For **jump edges**:
  - in flight: aim at `landingX`

### 8.3 Otherwise → approaching takeoff
- if close enough to takeoff:
  - set `activeEdgeIndex = edgeIndex`
  - emit `jumpNow = (edge.kind == jump)`
  - emit `commitMoveDirX = edge.commitDirX`
- else:
  - walk toward `takeoffX`
  - for jump edges, keep `commitMoveDirX` so the agent doesn't decelerate too early

The `takeoffEps` tolerance exists specifically to be robust at high speeds (avoid missing takeoff due to overshoot).

---

## 9) Converting intent to motion (GroundEnemyLocomotionSystem)

**System**: `GroundEnemyLocomotionSystem.step(...)` reads `NavIntentStore` and writes velocities.

### 9.1 DesiredX source
- If nav `hasPlan = true` → follow `NavIntent.desiredX`
- Else → fallback to `EngagementIntent.desiredTargetX` and clamp inside safe surface bounds (if known)

### 9.2 Horizontal steering
Uses an accel/decel controller:

- if `commitMoveDirX != 0`:
  - full-speed movement in that direction (no stopping near `desiredX`)
- else:
  - move toward `desiredX` until within `stopDistanceX`
  - apply arrival slow-down inside `arrivalSlowRadiusX`

### 9.3 Jump
If `jumpNow`:
- set `velY = -jumpSpeed` (jump impulse)

### 9.4 Jump “velocity snap” for reachability
When executing a **jump edge** with known `travelTicks`, the locomotion can **snap** `velX`
upward to ensure the arc reaches `landingX` within the edge’s expected travel time.

This is a pragmatic correction:
- keeps animation/AI planning consistent with the jump template assumptions
- avoids “almost makes it” misses due to small speed differences

---

## 10) Determinism & Tolerances

Key tolerances in `nav_tolerances.dart`:

- `navEps`, `navGeomEps`: very small, used for geometric equality and deterministic tie-breaks.
- `navSpatialEps`: larger (1 pixel) used for runtime surface detection robustness.
- `navTieEps`: used for A* tie-break comparisons.

**Warning**: changing these affects determinism and can shift which surface is selected in ambiguous cases.

---

## 11) Practical debugging checklist

When a ground enemy “doesn’t chase correctly”, check in this order:

1. **Graph exists** and is set into `EnemyNavigationSystem` and `GroundEnemyLocomotionSystem`.
2. Enemy has required stores:
   - `SurfaceNavStateStore`, `NavIntentStore`, `EngagementIntentStore`, `MeleeEngagementStore`.
3. Surface detection:
   - collider sizes (`halfWidth`, `offsetY`) correct,
   - `surfaceEps` not too small,
   - spatial index built with correct bounds/grid.
4. Plan execution edge cases:
   - drop edges need correct `commitDirX`,
   - `takeoffEps` too small can miss takeoff when fast.
5. Jump reachability mismatch:
   - jump template vs runtime physics mismatch will make “predicted reachable” jumps fail unless corrected by the velocity snap.

---

## 12) Scaling notes (if this grows)

- If graphs become large, replace linear open-set scan in `SurfacePathfinder` with a binary heap.
- Consider caching paths for common (surfaceIdStart, surfaceIdGoal) pairs if many enemies chase the same target and graph is static.
- If you add “one-way platforms”, “ladders”, etc., represent them as new edge kinds and keep execution logic in `SurfaceNavigator` (centralized, deterministic).

