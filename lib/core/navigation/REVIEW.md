# Navigation Review (2026-02-20)

Scope: `lib/core/navigation/**` with runtime touchpoints in `lib/core/ecs/systems/enemy_navigation_system.dart` and `lib/core/ecs/systems/ground_enemy_locomotion_system.dart`.

Validation run:
- `flutter test test/core/jump_template_test.dart test/core/surface_extraction_test.dart test/core/surface_graph_builder_test.dart test/core/surface_navigator_commit_dir_inflight_test.dart test/core/surface_navigator_graph_version_test.dart test/core/surface_pathfinder_test.dart test/core/trajectory_predictor_test.dart` (all passed)
- `flutter test test/core/ground_enemy_locomotion_jump_snap_test.dart test/core/ground_enemy_jump_test.dart test/core/ground_enemy_gap_jump_test.dart test/core/ground_enemy_drop_test.dart test/core/ground_enemy_gap_multi_test.dart test/core/ground_enemy_obstacle_jump_test.dart test/core/ground_enemy_ignore_ceilings_test.dart test/core/surface_navigator_takeoff_and_standability_test.dart test/core/surface_navigator_commit_dir_inflight_test.dart test/core/surface_navigator_graph_version_test.dart test/core/surface_graph_builder_test.dart test/core/surface_pathfinder_test.dart test/core/trajectory_predictor_test.dart test/core/surface_extraction_test.dart test/core/surface_id_test.dart test/core/static_world_geometry_index_contract_test.dart` (all passed)
- `dart analyze lib/core/navigation` (no issues)
- `dart analyze lib/core/navigation lib/core/tuning/navigation_tuning.dart test/core/ground_enemy_locomotion_jump_snap_test.dart` (no issues)

## Clarifications (follow-up)
- Partial-overlap landing is confirmed as a temporary simplification, not a long-term target behavior.
- `groundSegments` should be guaranteed pre-split/disjoint by contract.
  - Streamed chunk generation already does this: `lib/core/track/chunk_builder.dart:102`.
  - Overlap/order is guarded in chunk generation: `lib/core/track/chunk_builder.dart:142`.
  - Core currently trusts provided segments when present: `lib/core/collision/static_world_geometry_index.dart:232`.
  - Query logic assumes sorted/disjoint segments: `lib/core/collision/static_world_geometry_index.dart:210`.
  - Base + streamed segments are concatenated directly: `lib/core/track_manager.dart:273`.

## Findings (ordered by severity)

### 1) High: Jump graph can emit physically impossible edges (ceiling/wall not validated)
Evidence:
- `lib/core/navigation/surface_graph_builder.dart:209`
- `lib/core/navigation/surface_graph_builder.dart:217`
- `lib/core/navigation/utils/jump_template.dart:164`

Why this hurts fluidity:
- Reachability is currently checked by `dy/dx` only, without obstacle clearance along the arc.
- NPCs can select jump edges that look valid in graph space but fail in runtime collision, causing repeated retries, stalls, and twitchy retarget behavior.

Recommended fix:
- Add arc collision validation during jump-edge generation (sampled swept collider against static tops/walls/ceilings).
- Reject edges whose trajectory intersects blocking geometry before landing.
- Add tests with overhead ceilings and side walls to ensure impossible jumps are never emitted.

### 2) High: A* cost model loses position context on intermediate surfaces
Evidence:
- `lib/core/navigation/surface_pathfinder.dart:169`
- `lib/core/navigation/surface_pathfinder.dart:180`

Why this hurts fluidity:
- After the first hop, run-to-takeoff cost is measured from `surface.centerX`, not from actual arrival position (`landingX`) of the previous edge.
- This can choose routes that are optimal in the abstract graph but require extra backtracking in execution, making NPC movement look indecisive.

Recommended fix:
- Upgrade search state from `surfaceIndex` to position-aware state (for example, `(surfaceIndex, anchorBucket)` or exact `arrivalX`).
- At minimum, carry predecessor `landingX` into transition-cost evaluation for neighbor scoring.

### 3) High: Ground segment ID generation can collide under heavy splitting
Evidence:
- `lib/core/navigation/surface_extractor.dart:38`
- `lib/core/navigation/surface_extractor.dart:116`

Why this hurts fluidity:
- Ground piece IDs are generated with a fixed stride (`localSegmentIndex * 1000 + i`).
- If a segment splits into many pieces, IDs can collide with other segments, which can corrupt `indexById` mapping and destabilize path/target lookups.

Recommended fix:
- Replace stride math with explicit bit packing of `(localSegmentIndex, pieceIndex)` into non-overlapping ranges.
- Add a debug assert that extracted surface IDs are unique per build.
- Reinforce the pre-split/disjoint `groundSegments` contract with ingest-time validation for authored/base geometry.

### 4) Medium: Drop takeoff logic is less robust than jump takeoff logic
Evidence:
- `lib/core/navigation/surface_navigator.dart:292`
- `lib/core/navigation/surface_navigator.dart:309`
- `lib/core/navigation/surface_navigator.dart:317`

Why this hurts fluidity:
- Jump activation supports “at or past takeoff” checks with commit direction.
- Drop activation still relies on symmetric distance-to-takeoff checks and does not apply commit direction during approach.
- At higher horizontal speeds this can produce overshoot and correction oscillation near ledges.

Recommended fix:
- Apply the same directional “past-takeoff” gate to drop edges.
- Keep commit direction enabled while approaching drop takeoff, not only after activation.

### 5) Medium: Surface detection and trajectory landing allow partial overlap instead of standable fit
Evidence:
- `lib/core/navigation/surface_navigator.dart:357`
- `lib/core/navigation/utils/trajectory_predictor.dart:173`

Why this hurts fluidity:
- Current checks accept any horizontal overlap, even if collider width does not fully fit on the surface.
- Near ledges and narrow platforms, this can flip surface ownership and landing predictions, leading to repath churn and jitter.

Recommended fix:
- Use standable range checks (`surface.xMin + halfWidth` to `surface.xMax - halfWidth`) consistently in locator and predictor.
- Because partial-overlap is temporary, migrate both call sites together and remove relaxed behavior once validated.

### 6) Medium: Trajectory predictor can miss thin platforms at high horizontal speed
Evidence:
- `lib/core/navigation/utils/trajectory_predictor.dart:112`
- `lib/core/navigation/utils/trajectory_predictor.dart:152`

Why this hurts fluidity:
- Landing queries sample only at current `x` each tick, with a vertical sweep, but no horizontal sweep between previous and current x.
- Fast lateral motion can skip narrow platforms in prediction, causing poor interception behavior.

Recommended fix:
- Sweep query AABB across both `prevX` and `x`, then resolve earliest valid crossing.
- Add tests for high `velX` with narrow platforms.

### 7) Medium: Hot-path allocation in trajectory prediction
Evidence:
- `lib/core/navigation/utils/trajectory_predictor.dart:104`

Why this hurts fluidity:
- `final candidates = <int>[];` allocates per prediction call.
- Enemy navigation runs every tick; repeated allocations increase GC pressure and can manifest as micro-stutter.

Recommended fix:
- Move candidate buffer to an instance field and clear/reuse it each call.

### 8) Low: Packed ID unpacking is incorrect for negative chunk indices
Evidence:
- `lib/core/navigation/types/surface_id.dart:48`
- `lib/core/navigation/types/surface_id.dart:50`

Why this matters:
- `unpackChunkIndex` returns unsigned values for negative chunks (`-1` becomes `4294967295`).
- This is currently low runtime impact because unpacking is rarely used, but it is a correctness bug in ID utilities.

Recommended fix:
- Sign-extend after unpack or use signed 32-bit decode helper.
- Add tests for `chunkIndex` values `-2`, `-1`, `0`, `1`.

## Current strengths
- Deterministic ordering/tie-break practices are consistently applied in graph build and pathfinding.
- Good baseline test coverage exists for extraction, graph build, pathfinding, navigator version invalidation, and trajectory prediction.
- Navigation data is cleanly separated from Flame/Flutter and stays in Core.

## Highest-value implementation order
1. Add jump arc obstruction validation in `SurfaceGraphBuilder` (Finding 1).
2. Make pathfinding position-aware (Finding 2).
3. Harden surface ownership/landing checks to require standable fit (Finding 5).
4. Improve drop activation robustness (Finding 4).
5. Clean up correctness/perf issues: ID collisions, predictor allocations, signed unpack (Findings 3, 7, 8).

## Suggested test additions
- Impossible jump rejection under ceiling/wall blockers.
- Position-aware routing preference tests (same surface, different arrivalX).
- Drop takeoff overshoot test at high speed.
- Standability-required surface locator and trajectory landing tests.
- Surface ID uniqueness test on heavily split ground segments.
- Negative chunk unpack round-trip tests.

## Refactor status (2026-02-20)
- Completed:
  - Ground ID safety + signed chunk unpack + provided `groundSegments` contract validation.
  - Standability migration for surface location and trajectory landing.
  - Drop takeoff robustness (directional past-takeoff + commit direction during approach).
  - Jump edge obstruction filtering (ceiling/wall blockers), with collision-capability flags on `JumpProfile`.
  - Position-aware intermediate path costs using predecessor `landingX`.
  - Trajectory predictor sweep/perf improvements.
  - Integration retune: reduced default replan cooldown to `12` ticks (~200 ms at 60 Hz), and raised baseline takeoff epsilon to `4.0` for non-overridden users.
  - Locomotion validation for jump snap + commit direction (`test/core/ground_enemy_locomotion_jump_snap_test.dart`).
- Post-plan follow-up (manual validation):
  - Run a live gameplay feel pass in the Flame scene (camera pressure + mixed enemy packs) to confirm no over-planning CPU spikes at higher concurrent enemy counts.

## Residual risks
- Retuned default `repathCooldownTicks` improves responsiveness but increases A* frequency; very high enemy counts may need per-level overrides.
- Automated tests validate deterministic behavior and edge handling; final subjective "naturalness" still requires manual feel-testing in play sessions.
