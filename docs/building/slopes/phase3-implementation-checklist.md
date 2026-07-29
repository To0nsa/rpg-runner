# Slopes Phase 3 - Sloped Surface Graphs And Enemy Cutover Readiness Checklist

- Created: July 20, 2026
- Status: Accepted July 28, 2026; all deterministic, allocation, capacity,
  performance, documentation, and validation gates pass
- Source plan: [plan.md](plan.md)
- Frozen gameplay decisions:
  [phase0-gameplay-decisions.md](phase0-gameplay-decisions.md)
- Frozen technical contracts:
  [phase0-technical-contracts.md](phase0-technical-contracts.md)
- Golden/performance specification:
  [phase0-golden-performance-spec.md](phase0-golden-performance-spec.md)
- Consumer inventory:
  [phase0-consumer-inventory.md](phase0-consumer-inventory.md)
- Accepted geometry foundation:
  [phase1-implementation-checklist.md](phase1-implementation-checklist.md)
- Accepted actor-neutral controller:
  [phase2-implementation-checklist.md](phase2-implementation-checklist.md)

## 1) Goal And Exit Outcome

Generalize the existing horizontal surface-navigation stack to canonical
sloped terrain, migrate every current enemy to an explicit terrain policy in
an isolated Core authority, and prove that collision, navigation, placement,
and streaming-version behavior agree.

At Phase 3 acceptance:

- one immutable sloped surface set is shared by all enemy graph profiles
- Grojib and Hashash have profile-specific graphs without different node
  identity or ordering
- walk, jump, drop, lookup, standability, and trajectory prediction use
  segment/capsule geometry rather than constant `yTop`
- grounded enemies use the accepted capsule controller and final support state
- Unoco Demon has swept solid-terrain contact and deterministic clearance
  steering without a flight graph
- Derf and Hashash teleport use explicit capsule-clearance placement queries
- terrain-dependent spawn queries preserve marker/RNG ordering and accepted
  same-support failure behavior
- geometry, collision index, surface set, graph variants, and their version
  publish atomically in the Phase 3 harness
- every current enemy archetype has deterministic scenario and policy evidence
- graph/controller/allocation/whole-Core budgets pass

Phase 3 is cutover readiness, not the production terrain cutover. Normal
repository-backed levels continue to use legacy streamed rectangles until
Phases 4-6 provide authored polygons, generation, rendering, streaming, and
content migration.

## 2) Phase Boundary And Non-Goals

In scope:

- Core navigation representation and deterministic graph construction
- shared surface lookup, standability, and placement queries
- per-enemy traversal/contact profiles
- grounded enemy terrain motion and navigation/locomotion integration
- Unoco Demon terrain contact, hover reference, and clearance steering
- Derf placement and Hashash ambush destination validation
- enemy/item spawn-placement query behavior against Phase 1 geometry
- geometry/graph version invalidation and atomic test-harness publication
- enemy/nav signatures, scenario goldens, capacity, allocation, and timing
- TDD/GDD updates for behavior actually delivered in this phase

Out of scope:

- editor polygon schema, migrations, tools, and generator output (Phase 4)
- production chunk polygon streaming and geometry-driven rendering (Phase 5)
- ballistic projectile terrain migration
- direct production authority cutover or legacy rectangle removal (Phase 6)
- replay compatibility issuance, board rollout, and production deployment
  (Phase 7)
- new enemies, attacks, jump abilities, one-way drop-through input, or balance
  changes

Do not weaken or bypass a Phase 1/2 invariant to make navigation pass. Record a
counterexample in §25 before changing an accepted numeric/contact contract.

## 3) Frozen Gameplay Matrix

These values are already user-accepted. Implement them without reopening
balance questions.

| Actor | Terrain policy | Walkable slope | Step/snap | Surface speed | Special rule |
| --- | --- | ---: | ---: | --- | --- |
| Grojib | grounded dynamic capsule | `45°` inclusive | `4 px` / `4 px` | constant distance along surface | valid jump/drop may reach a separate eligible surface |
| Hashash | grounded dynamic capsule plus validated teleport | `60°` inclusive | `4 px` / `4 px` | constant distance along surface | primary right/above ambush, mirrored left/above fallback, then cancel |
| Unoco Demon | flying dynamic capsule | not grounded | none | existing bounded flight tuning | solids block every side; one-way terrain is ignored |
| Derf | kinematic placement capsule | placement at `15°` inclusive | none | stationary | same-support clamp, `32 px` perch, otherwise skip |

Additional frozen behavior:

- Grojib and Hashash retain current one-way behavior: pass from below, land and
  navigate from the authored top side, no endpoint wall, no drop-through input.
- grounded jumps launch world-up; support normals add no launch impulse
- ground enemies use final post-solver support for grounded animation
- sprites, combat bounds, cast origins, and hitboxes remain upright/world-space
- chase and melee stand-off offsets remain world-X distances
- Unoco Demon retains the authored `60-180 px` hover band above local terrain
- invalid optional spawns are skipped and consume no replacement RNG
- Hashash's fixed teleport fallback order consumes no RNG

## 4) Current Implementation Map

The implementation must deliberately migrate these existing responsibilities.

| Current owner | Flat/AABB assumption to replace | Required Phase 3 outcome |
| --- | --- | --- |
| `navigation/types/walk_surface.dart` | `[xMin,xMax]` plus constant `yTop` | immutable directed segment with `yAt(x)`, tangent, normal, length, collision mode, and canonical source identity |
| `navigation/surface_extractor.dart` | extracts and merges rectangle top faces | extracts canonical exposed upward-facing edge segments once |
| `navigation/utils/surface_spatial_index.dart` | indexes thin horizontal slabs | indexes exact segment bounds with reusable deterministic query buffers |
| `navigation/utils/standability.dart` | horizontal-width/AABB support | profile-aware capsule support interval and clearance |
| `navigation/surface_graph_builder.dart` | rebuilds horizontal nodes for each jump profile | consumes one shared surface set and emits profile-specific eligibility/edges |
| `navigation/surface_pathfinder.dart` | jump/drop graph only | deterministic `walk`/`jump`/`drop` A* cost and tie-breaks |
| `navigation/surface_navigator.dart` | bottom-Y surface location | prior support ID/version plus exact segment lookup |
| `navigation/utils/trajectory_predictor.dart` | horizontal-band crossing | swept descending capsule versus eligible sloped segments |
| `ecs/systems/enemy_navigation_system.dart` | AABB bottom/width and flat target | prior validated support, predicted sloped landing, shared surface identity |
| `ecs/systems/ground_enemy_locomotion_system.dart` | world-X velocity plus legacy collision | constant surface-distance intent composed before terrain motion |
| `ecs/systems/world_motion_authority.dart` | terrain harness rejects enemies | exactly-once player and enemy terrain dispatch by explicit policy |
| `ecs/systems/flying_enemy_locomotion_system.dart` | global ground reference/no terrain solve | local-terrain hover reference plus swept solid contact |
| `ecs/systems/hashash_teleport_ambush_system.dart` | unchecked destination write | ordered authority-owned clearance query and safe cancel |
| `spawn_service.dart` | `groundTopY`/highest flat `yTop`/AABB solids | exact support/clearance placement result and stable diagnostic |
| `track_manager.dart` | rectangle index and horizontal graph publication | unchanged production path plus isolated atomic terrain bundle evidence |

Before editing, repeat this inventory against the current tree and add any new
enemy, body, placement, or navigation consumer discovered after July 20, 2026.

## 5) Implementation Order

Implement in dependency order:

1. baseline existing enemy/navigation behavior and signatures
2. freeze enemy capsule/profile definitions
3. build the shared sloped surface set and index
4. implement standability, location, and placement queries
5. build profile-specific walk/jump/drop graphs
6. migrate pathfinder, navigator, and trajectory prediction
7. generalize world-motion dispatch and grounded enemy locomotion
8. integrate Unoco Demon, Derf, Hashash teleport, and spawn queries
9. prove atomic geometry/graph replacement and mixed-enemy behavior
10. close goldens, allocation/capacity/performance, docs, and findings

Do not connect normal production construction to terrain authority in this
phase.

## 6) Baseline And Compatibility Evidence

- [x] Record the starting revision, dirty flag, OS, Dart/Flutter versions, and
      relevant dependency lock state.
- [x] Run `dart analyze packages/runner_core`.
- [x] Run all `packages/runner_core` tests.
- [x] Run the full root `test/core` suite.
- [x] Run replay-validator analysis and tests.
- [x] Record current Grojib and Hashash path/position/attack outcomes on flat
      geometry for fixed seeds and command streams.
- [x] Record current Unoco hover, steering, cast, melee, and spawn behavior.
- [x] Record current Hashash deferred spawn, teleport timing, destination,
      strike queue, cancellation, and cooldown behavior.
- [x] Record current Derf placement, facing, cast origin, and target behavior.
- [x] Record existing graph node/edge ordering and A* tie-break behavior.
- [x] Confirm normal construction and replay validation still use the legacy
      authority before Phase 3 work begins.

Flat compatibility is intentional behavior parity, not necessarily byte parity
with the legacy graph representation. Any outcome drift must be classified and
reviewed before its golden is updated.

## 7) Enemy Capsule And Traversal Profiles

Derive each capsule from the current collider exactly:

```text
radius = old halfX
verticalHalfSegment = max(0, old halfY - radius)
offset = old collider offset
derived AABB = old collider AABB
```

Frozen definitions:

| Enemy | Radius | Vertical half-segment | Authored offset |
| --- | ---: | ---: | --- |
| Unoco Demon | `8.125` | `0.5` | `(0.0, 2.0)` |
| Grojib | `19.5` | `5.5` | `(-4.0, 18.0)` |
| Hashash | `14.0` | `7.5` | `(-1.0, 7.0)` |
| Derf | `11.5` | `12.75` | `(0.0, 7.0)` |

- [x] Add immutable enemy world-contact shape/profile definitions to the
      authoritative enemy catalog or a catalog-owned resolver.
- [x] Quantize every shape/profile value once at construction.
- [x] Preserve the existing authored-facing offset mirror rule.
- [x] Prove the derived AABB is exact for both facings and all four enemies.
- [x] Keep combat, pickup, broad-phase, culling, and render bounds on the
      derived AABB.
- [x] Give Grojib a `45°`, 4-pixel step/snap grounded profile.
- [x] Give Hashash a `60°`, 4-pixel step/snap grounded profile.
- [x] Give both grounded enemies constant distance-along-surface locomotion.
- [x] Give Unoco a flying profile with no support, snap, step, gravity, or
      one-way contact.
- [x] Give Derf a kinematic clearance profile; do not integrate it per tick.
- [x] Preserve Grojib/Hashash ceiling-ignore and one-way behavior explicitly;
      do not inherit player defaults accidentally.
- [x] Fail construction when a current enemy has no explicit terrain policy.

Tests:

- [x] invalid dimensions and non-finite authoring values fail
- [x] exact tick values and derived bounds for all four enemies
- [x] mirrored offset parity for left/right facing
- [x] profile slope/step/snap/one-way/ceiling flags are explicit
- [x] catalog enumeration and policy enumeration contain the same four IDs

## 8) Shared Sloped Surface Set

Create one immutable surface set from canonical `TerrainGeometry`. Extraction
must not depend on an enemy profile.

Each node exposes at minimum:

- canonical `TerrainEdgeId`
- physics-tick endpoints and inclusive X range
- exact/deterministic `yAt(x)`
- tangent and outward normal
- integer or deterministically quantized segment length
- collision mode
- previous/next compatible exposed-edge adjacency
- ledge endpoint classification
- stable chain identity derived without hashing collisions

- [x] Use canonical `TerrainEdgeId` as the graph node's persistent identity
      and deterministic tie-break; do not hash it into a legacy packed integer.
- [x] Cache graph node indices in runtime nav state only with the exact bundle
      version and clear them before use on every version mismatch.
- [x] Do not retain a node index across bundle versions.
- [x] Include exposed, upward-facing, X-monotonic, non-vertical candidate
      surfaces in canonical edge-ID order.
- [x] Keep over-limit slopes in the shared set; profile filtering happens
      later.
- [x] Preserve solid versus one-way classification.
- [x] Exclude walls, ceilings, internal/shared boundaries, and invalid seams
      from standable candidates.
- [x] Build connected chains only through compatible exact endpoints.
- [x] Preserve intentional ledges and incompatible material/collision-mode
      boundaries.
- [x] Derive chain identity from the canonical lowest member identity and
      verify uniqueness.
- [x] Reuse the Phase 1 geometry version; do not invent an independent surface
      version.
- [x] Remove constant-`yTop` assumptions from the new representation.
- [ ] Keep one navigation node representation; any temporary legacy adapter
      must emit that representation rather than maintaining a second graph
      model.

Tests:

- [x] flat, uphill, downhill, vertical, ceiling, and one-way edges
- [x] flat-slope-flat, convex peak, concave valley, and intentional ledge
- [x] exact and incompatible cross-polygon/chunk seams
- [x] clockwise/counterclockwise input parity
- [x] negative coordinates and overlapping X ranges
- [x] canonical IDs/order across input permutations and fresh processes
- [x] no-op geometry rebuild produces the same surface/chain signature

## 9) Surface Spatial Index And Query Buffers

- [x] Index full segment bounds, not a thin slab at one `yTop`.
- [x] Reuse the accepted Phase 1 grid and canonical candidate ordering where
      practical.
- [x] Query into caller-owned buffers with stamp-based deduplication.
- [x] Sort candidates by canonical surface identity only after deduplication.
- [x] Expose candidate count, cells visited, and buffer resize count.
- [x] Never truncate candidates to satisfy a budget.
- [x] Handle exact cell boundaries, long slopes, negative coordinates, and
      5120-edge hard-stream bounds.
- [x] Prove zero steady-state query-buffer growth after warmup.

Tests:

- [x] indexed results match brute-force segment-bounds queries
- [x] duplicate cell occupancy yields one candidate
- [x] stable order is independent of insertion order
- [x] queries above, below, and across a sloped segment are complete
- [x] representative and hard-stream capacities do not truncate

## 10) Standability, Support Location, And Placement Query

Build one actor-neutral query layer used by graph construction, runtime
navigation, spawn placement, and teleport validation.

The query result records:

- validity/failure reason
- body and capsule center in physics ticks
- support point and `TerrainEdgeId`
- support tangent/normal and slope
- same-support clamped X when allowed
- geometry version
- query diagnostics/candidate counts

- [x] Use the complete upright capsule for terrain clearance.
- [x] Use exact `yAt(x)` and the support normal; never reconstruct a flat
      bottom Y.
- [x] Separate runtime navigation support fraction from spawn support width.
- [x] Preserve the existing per-enemy runtime support fraction used by jump
      profiles unless a measured counterexample requires review.
- [x] Require full capsule-width support for grounded spawns.
- [x] Require profile-eligible slope/collision mode.
- [x] Highest-surface lookup prefers smallest world Y, then canonical edge ID.
- [x] Same-support clamp never crosses a ledge, chain break, or source boundary.
- [x] Full-clearance validation checks walls, ceilings, undersides, adjacent
      polygons, and capsule endpoint contacts.
- [x] One-way back sides do not block a clearance-only flying/teleport query
      when the actor policy ignores them.
- [x] Return stable typed failure diagnostics; do not silently relocate.

Tests:

- [x] surface lookup at every slope transition and exact endpoint
- [x] profile difference at `45°`, between `45-60°`, exactly `60°`, and over
      `60°`
- [x] narrow peaks, insufficient support, blocked headroom, and adjacent wall
- [x] solid/one-way surfaces with overlapping X ranges
- [x] highest-surface and same-support tie-breaks
- [x] full-width spawn versus runtime partial-support distinction
- [x] geometry-version mismatch invalidates a retained result

## 11) Shared Nodes And Per-Enemy Graph Variants

Refactor graph construction into:

1. one shared immutable surface set and spatial index
2. one Grojib graph view
3. one Hashash graph view

Both graph variants contain the same nodes, IDs, indices, and ordering. They
may differ only in node eligibility and directed traversal edges.

- [x] Add an explicit `walk` edge kind alongside `jump` and `drop`.
- [x] Store profile eligibility without deleting or reordering shared nodes.
- [x] Assert shared node identity/order on every publication.
- [x] Generate walk edges for compatible adjacent segments and accepted
      4-pixel transitions.
- [x] Require the same capsule/clearance query used at runtime.
- [x] Exclude over-profile slopes from ordinary walking.
- [x] Preserve deterministic CSR edge grouping and ordering.
- [x] Define walk cost from distance along the surface divided by the enemy's
      authored locomotion speed.
- [x] Keep jump/drop costs time-based as currently authored.
- [x] Make all cost/tie-break math deterministic and signature-visible.
- [x] Do not add fallback edges merely to make every target reachable.

Tests:

- [x] shared node IDs/order with different eligibility and edge sets
- [x] Grojib rejects a `46-60°` walk route that Hashash accepts
- [x] both accept their exact inclusive limits
- [x] connected slopes and compatible seams emit ordinary walk edges
- [x] a 4-pixel feasible transition emits walk; 5 pixels does not
- [x] blocked/narrow/steep transition emits no walk edge
- [x] walk cost equals measured constant-surface-speed travel time
- [x] repeated graph builds and input permutations produce identical CSR

## 12) Jump And Drop Graph Construction

- [x] Compute takeoff Y from the source segment at takeoff X.
- [x] Compute landing Y/normal from the destination at landing X.
- [x] Use profile-specific standability and slope eligibility.
- [x] Use existing deterministic jump templates and tick integration.
- [x] Sweep the complete capsule through solid terrain for obstruction.
- [x] Respect each enemy's ceiling and one-way policy.
- [x] Reject arcs blocked by walls, ceilings when applicable, sloped
      undersides, endpoints, or intervening terrain.
- [x] Find the earliest valid landing on the collision-valid side.
- [x] Drop from the true ledge and select the first valid support below.
- [x] Preserve takeoff sampling bounds and document any changed sample rule.
- [x] Tie-break equal landings by tick, vertical priority, then canonical
      surface ID.
- [x] Never emit jump/drop edges to an ineligible destination.

Tests:

- [x] flat-to-slope, slope-to-flat, slope-to-slope jump
- [x] uphill/downhill takeoff in both directions
- [x] landing at an endpoint, on a narrow surface, and at the slope limit
- [x] one-way landing from above and pass from below
- [x] convex peak and concave valley near takeoff
- [x] wall, ceiling, underside, and intermediate-platform obstruction
- [x] drop from both ledges to the first eligible sloped support
- [x] high-speed/thin-surface landing without tunneling
- [x] equal-time candidate order remains stable

## 13) Pathfinder And Runtime Navigator

- [x] Preserve deterministic A* and reusable path buffers.
- [x] Extend A* to `walk`, `jump`, and `drop` edges.
- [x] Preserve stable cost, preferred-direction, and surface-ID tie-breaks.
- [x] Read prior-tick validated support ID/version for the enemy.
- [x] Read the player's prior-tick support for grounded target reasoning.
- [x] Invalidate current/last/target support, path, cursor, and active edge
      before AI runs when geometry/graph version changes.
- [x] Use the shared query only when retained support is absent or needs
      validation.
- [x] Follow connected same-chain geometry without repeated repath or segment
      oscillation.
- [x] Preserve takeoff approach and in-flight commit direction.
- [x] Complete an edge only on validated destination support.
- [x] Clamp no-plan fallback to the last known eligible support; never
      teleport or cross an ineligible ledge.
- [x] Preserve nav/move/stun lock semantics.

Tests:

- [x] same-chain chase across multiple slope segments
- [x] target crosses a seam or moves to another chain
- [x] target becomes airborne and lands on a slope
- [x] path preference/tie-break parity in both horizontal directions
- [x] takeoff overshoot does not oscillate
- [x] in-flight jump/drop direction remains committed
- [x] wrong landing does not complete the active edge
- [x] graph-version replacement clears all stale references immediately
- [x] no-plan fallback remains on eligible terrain

## 14) Sloped Trajectory Prediction

- [x] Match Core's fixed-tick gravity/velocity integration.
- [x] Predict the full capsule/support path, not a center ray or horizontal
      bottom band.
- [x] Query swept segment bounds each predicted tick.
- [x] Accept only descending contact on a profile-eligible surface.
- [x] Return exact landing point, support ID, geometry version, and tick.
- [x] Choose earliest tick, then highest surface, then canonical ID.
- [x] Reuse candidate/output buffers in repeated AI queries.
- [x] Return no landing when the first contact is a wall/ceiling or clearance
      is insufficient.

Tests:

- [x] vertical and diagonal fall onto flat and sloped surfaces
- [x] high-speed fall onto a thin sloped platform
- [x] jump arc landing uphill/downhill
- [x] multiple crossed surfaces select the first valid landing
- [x] ascending/back-side/one-way-invalid contacts are ignored
- [x] too-wide capsule and blocked landing return no result
- [x] predictor result agrees with the accepted controller replay

## 15) Multi-Body World-Motion Authority

Generalize the isolated player authority into one terrain dispatcher that owns
every enabled non-kinematic actor in the Phase 3 harness exactly once.

- [x] Preserve one `prepareTick` and one `step` audit per Core tick.
- [x] Iterate bodies in stable entity order.
- [x] Initialize capsule, traversal, contact, and resolved-motion stores for
      player, Grojib, Hashash, and Unoco according to policy.
- [x] Reuse one controller/result scratch set per traversal profile; do not
      allocate per entity/tick.
- [x] Read prior support before AI and publish final support after motion.
- [x] Compose locomotion, jump, mobility/teleport state, gravity, and external
      velocity before the one terrain solve.
- [x] Keep Derf kinematic and validate only explicit placement/mutation.
- [x] Continue to reject unsupported dynamic bodies and ballistic projectiles
      in the Phase 3 harness.
- [x] Do not fall back to legacy AABB collision for a terrain-owned body.
- [x] Write derived AABB/contact compatibility only after the final transform.
- [x] Preserve the player-distance return contract.
- [x] Keep normal production construction on `LegacyWorldMotionAuthority`.

Body disposition after Phase 3:

| Body | Harness disposition |
| --- | --- |
| player | grounded terrain capsule |
| Grojib | grounded terrain capsule |
| Hashash | grounded terrain capsule plus validated teleport |
| Unoco Demon | flying solid-only terrain capsule |
| Derf | kinematic clearance-validated capsule |
| disabled/other kinematic | explicitly ignored by motion |
| ballistic projectile | explicit later-phase rejection |
| unknown enabled dynamic body | typed hard failure |

Tests:

- [x] zero/one/many enemies are integrated exactly once
- [x] stable entity order cannot change outcomes
- [x] missing policy/store fails before partial integration
- [x] geometry replacement invalidates every affected support/path
- [x] disabled, kinematic, dying, and falling bodies follow explicit policy
- [x] player results remain identical with and without inactive enemy bodies

## 16) Grojib And Hashash Grounded Locomotion

- [x] Convert authored speed to constant requested distance along support.
- [x] Do not apply Éloïse's uphill/downhill speed curve.
- [x] Preserve existing engagement, arrival, status, and control-lock
      multipliers before terrain projection.
- [x] Preserve world-X chase/stand-off targets.
- [x] Follow the support tangent in the intended horizontal direction.
- [x] Use the accepted 4-pixel step/snap helper during ordinary grounded
      pursuit.
- [x] Keep jump launch world-up and existing horizontal jump-edge velocity
      snap/commit rules.
- [x] Do not snap an accepted jump back to support.
- [x] Remove only velocity entering a blocking terrain constraint.
- [x] Preserve final-support-driven animation and resolved-distance playback.
- [x] Preserve melee/cast origins and facing behavior.
- [x] Ground-impact death waits for final support or the existing deterministic
      timeout.

Tests:

- [x] idle, walk, reverse, accelerate, decelerate, and stop on slopes
- [x] both directions at flat/intermediate/exact-limit angles
- [x] Grojib constant surface speed at `45°`
- [x] Hashash constant surface speed at `60°`
- [x] step, snap, seam, peak, valley, wall, ceiling policy, and one-way
- [x] jump/drop graph execution and off-course velocity recovery
- [x] nav/move/stun locks and status speed modifiers
- [x] melee engage/strike/recover facing and stand-off offsets
- [x] grounded/airborne animation has no seam flicker
- [x] death in air, slope landing, timeout, and culling

## 17) Hashash Teleport And Deferred Spawn

- [x] Route teleport writes through a terrain placement authority.
- [x] Clear prior support/path before destination validation.
- [x] Test the primary point `36 px` right and `36 px` above the predicted
      player first.
- [x] Require full capsule clearance; airborne ambush support is not required.
- [x] If blocked, test the mirrored left/above point second.
- [x] Queue the strike only after successful placement.
- [x] If both fail, restore/retain last safe transform, queue no strike, and
      apply the normal cooldown.
- [x] Consume no RNG during fallback.
- [x] Reinitialize last-valid capsule state after successful teleport.
- [x] Apply the same grounded placement query to deferred edge spawns; invalid
      placement skips that pending spawn.

Tests:

- [x] primary point clear
- [x] primary blocked/mirrored clear
- [x] both blocked by slope, wall, ceiling, and concave corner
- [x] no support remains valid for airborne ambush
- [x] no strike on cancellation and cooldown is normal
- [x] destination/result independent of candidate/input ordering
- [x] deferred spawn succeeds on eligible slope and skips invalid support

## 18) Unoco Demon Flying Contact And Hover

- [x] Resolve the highest relevant local solid terrain below the capsule's
      horizontal footprint.
- [x] Preserve the existing randomized `60-180 px` hover band and RNG order.
- [x] Retain the last valid local reference when no terrain lies below.
- [x] Use the level flight-reference plane only when no prior local reference
      exists.
- [x] Continue bounded vertical steering; never teleport to a new reference.
- [x] Sweep the complete capsule against solid terrain from every side.
- [x] Ignore one-way platforms for contact, recovery, support, and steering.
- [x] Never set grounded/support state.
- [x] Keep move-and-slide as the immediate collision response.
- [x] Add a fixed, bounded clearance-steering candidate set only when blocked.
- [x] Rank candidates by progress toward combat/hover target, then clearance,
      then stable candidate ID.
- [x] Consume no RNG and grant no phasing/teleport fallback.
- [x] Preserve cast/melee timing, target policy, origins, and facing.

Before implementing clearance steering, record its ordered candidate vectors
and turn/hold rule in this checklist. If profiling shows that a candidate set
materially changes combat pressure rather than merely resolving blockage, ask
the user one gameplay question before accepting it.

Recorded implementation default (July 23, 2026):

1. candidate `0`: current direct combat/hover velocity
2. candidate `1`: positive tangent of the prior solid blocking normal
3. candidate `2`: negative tangent of that normal
4. candidate `3`: outward along that normal

Candidates are generated only after a solid contact and previewed for six
fixed ticks through the real Unoco capsule/controller. Rank by accepted dot
progress toward the current combat/hover target, then accepted clear-travel
distance, then candidate ID. Hold the selected detour vector for `0.20 s`
(`12` ticks at `60 Hz`) unless a new solid contact forces deterministic
re-evaluation; when the hold expires, resume direct steering. The preview,
selection, and hold consume no RNG.

Implemented evidence (July 23, 2026):

- `FlyingEnemyLocomotionSystem` resolves the current combat/hover target first,
  then asks the selected world-motion authority for the local terrain reference
  and any blocked-flight clearance vector. The existing range/height RNG calls
  and combat-mode branches are unchanged.
- `TerrainMultiBodyWorldMotionAuthority` queries only upward solid surfaces
  below the facing-resolved capsule footprint, previews the four candidates
  through the retained Unoco controller scratch, and copies the final blocking
  normal into persistent steering state for the following tick.
- The ordinary terrain solve remains the only transform integrator. Solid
  contact projects entering velocity through move-and-slide; flying policy
  suppresses support and grounded publication. One-way surfaces are absent
  from both the hover reference and flying contact policy.
- `flying_enemy_terrain_locomotion_test.dart` covers local references, retained
  fallback, RNG parity, all-side blocking, maximum-speed thin solids, one-way
  pass-through, bounded non-oscillating clearance, deterministic route parity,
  and return to the hover target. Existing `flying_enemy_steering_test.dart`
  and `enemy_attacks_test.dart` retain combat-mode, target, timing, origin, and
  facing coverage.

Tests:

- [x] follow flat/uphill/downhill local hover reference
- [x] pit/no-surface retains last reference, then explicit plane fallback
- [x] wall, slope, ceiling, underside, and concave-corner blocking
- [x] thin solid at maximum flight speed does not tunnel
- [x] one-way platforms never block or ground
- [x] deterministic route around an obstacle and return toward target
- [x] no oscillation, new RNG, teleport, or terrain phasing
- [x] combat timing/outcomes remain intentional

## 19) Derf Kinematic Placement

- [x] Use the common placement query without giving Derf motion authority.
- [x] Accept solid intended obstacle-top support at `15°` inclusive.
- [x] Require at least `32 px` horizontal support span.
- [x] Require complete capsule clearance.
- [x] Clamp marker X only to the nearest valid point on the same support.
- [x] Skip absent, too-steep, too-narrow, or obstructed placements.
- [x] Emit a stable authoring/debug diagnostic.
- [x] Never fall back to unrelated highest terrain or ordinary ground.
- [x] Preserve face-player, predicted-player-center cast target, world-space
      cast origin, upright art, and instant death behavior.

Implemented evidence (July 23, 2026):

- `WorldMotionAuthority.resolveSpawnPlacement` preserves legacy placement under
  `LegacyWorldMotionAuthority` and routes terrain-harness Derf requests through
  the shared typed placement resolver without adding Derf to dynamic
  integration.
- Terrain resolution binds the requested marker X/Y to one canonical solid
  intended edge, applies Derf's inclusive `15°` profile, requires a full
  capsule foothold plus an independent `32 px` total perch span, and permits
  only the query's nearest same-edge clamp.
- Every attempt returns `terrain-spawn-placement-v1`, including profile,
  source-selection mode, validity, geometry version, requested/final
  coordinates, intended/support/blocker IDs, slope, and clamp state.
  `GameCore.lastSpawnPlacementDiagnostic` exposes the latest record to terrain
  tests and authoring tools.
- `TrackStreamer` retains marker placement intent and whether the legacy
  resolver found that exact kind. Normal legacy fallback remains unchanged;
  terrain Derf rejects an `obstacleTop` marker that reached highest-surface or
  ordinary-ground fallback.

Tests:

- [x] flat, `15°`, and just-over-limit support
- [x] exactly `32 px` and just-under-width support
- [x] blocked capsule/headroom and adjacent wall
- [x] same-support clamp in both directions
- [x] no unrelated fallback and stable diagnostic
- [x] cast origin/target/facing unchanged on gentle slope

## 20) Terrain-Dependent Spawn And Item Queries

- [x] Introduce one placement request/result API with explicit actor/item
      profile, intended support/source, clamp permission, and failure reason.
- [x] Preserve marker iteration, chunk selection, spawn rolls, rejection
      attempts, salts, and RNG consumption.
- [x] Grounded Grojib/Hashash require eligible same-support full-width
      placement and clearance.
- [x] Unoco spawn requires clearance at the intended flying point and skips
      when blocked.
- [x] Derf uses §19 only.
- [x] Collectible/restoration placement uses player-walkable solid or one-way
      support up to `60°`.
- [x] Items require at least `20 px` horizontal support and full AABB
      clearance with existing vertical/margin tuning.
- [x] Invalid item candidates consume their normal attempt; exhaustion spawns
      nothing.
- [x] Preserve placement-mode intent for `ground`, `highestSurfaceAtX`, and
      `obstacleTop` without depending on rectangle top faces.
- [x] Keep the required player-initial-placement validation query available
      for Phase 5; do not cut over production level startup here.

Implemented evidence (July 24, 2026):

- `TerrainSpawnPlacementRequest`, profile variants, and
  `TerrainSpawnPlacementResult` provide one mutation-free authority boundary.
  Exact `TerrainEdgeId` input bypasses the temporary legacy support-height
  bridge; physical support selection happens before actor/profile filtering,
  so invalid intended or highest terrain never falls through to a lower edge.
- `GameCore` sends every terrain-harness enemy marker through that boundary.
  Grojib and Hashash use their catalog capsules and traversal limits; ordinary
  markers may clamp only on the selected edge, deferred Hashash never clamps,
  Unoco performs clearance only at the authored flying point, and Derf retains
  its Section 19 obstacle-top policy.
- `SpawnService` retains its existing count draws, candidate draws, salts,
  snapping, spacing, attempt limits, marker ordering, and chunk schedule.
  Under terrain authority, each collectible/restoration candidate selects the
  physical highest surface first, requires Éloïse-eligible solid or one-way
  support, a `20 px` total span, exact `yAt(x)`, the existing vertical gap and
  no-spawn margin, and full upright AABB clearance. Rejection consumes only the
  attempt already drawn.
- A steep support may be player-walkable yet still reject a production item if
  its upright AABB plus the existing `10 px` clearance would clip the uphill
  side. This is the intended conjunction of support eligibility and full-AABB
  clearance, not a lower-surface fallback.
- Normal `GameCore(...)` still commits the historical rectangle candidate.
  Player initial placement remains on the existing shared placement query and
  is not switched to streamed terrain before Phase 5.

Tests:

- [x] all three marker placement modes on flat/sloped/overlapping terrain
- [x] enemy profile differences and same-support clamp
- [x] item solid/one-way/width/slope/clearance rules
- [x] invalid marker does not shift later RNG outcomes
- [x] deferred Hashash count/order remains deterministic
- [x] repeated and fresh-process spawn results match

Executable evidence:

- `packages/runner_core/test/ecs/terrain_spawn_placement_test.dart`
- `packages/runner_core/test/ecs/hashash_terrain_placement_test.dart`
- `packages/runner_core/test/ecs/derf_terrain_placement_test.dart`
- `test/core/track_streamer_hashash_deferred_spawn_test.dart`

## 21) Atomic Geometry, Index, Surface, And Graph Publication

Define one immutable versioned terrain runtime bundle for the Phase 3 harness:

- `TerrainGeometry`
- `TerrainEdgeIndex`
- shared surface set/index
- Grojib graph
- Hashash graph
- one shared geometry/graph version

- [x] Build all derived structures before publication.
- [x] Validate shared node identity/order and every profile graph first.
- [x] Publish the complete bundle atomically.
- [x] Never expose mixed old/new geometry and graph versions during a tick.
- [x] AI invalidates stale support/path before reading it.
- [x] Motion rejects stale support and resolves against the current bundle.
- [x] No-op rebuild signatures remain identical even if version increments.
- [x] Controlled spawn/cull replacement removes obsolete adjacency and paths.
- [x] Preserve normal `TrackManager` legacy publication until Phase 5.

Tests:

- [x] no-op replacement
- [x] add/remove a chunk-side surface
- [x] cull the current/target/landing surface
- [x] replace support while an enemy is grounded
- [x] replace graph during jump/drop execution
- [x] identical result independent of rebuild/input ordering
- [x] no consumer observes mixed versions

Implementation notes:

- `TerrainRuntimeBundle` owns immutable geometry, collision index, one shared
  surface set/index, and the Grojib/Hashash graph publication. Construction
  validates the exact shared surface-set identity and version before returning.
- `TerrainMultiBodyWorldMotionAuthority` builds a complete authority
  publication, including the placement query and all controller/query scratch
  bound to the bundle, before queueing it. `prepareTick` publishes the one
  pending reference before support/path preparation; queueing between prepare
  and integration is a hard failure.
- Replacement versions increase monotonically. A new version clears retained
  support, current/last/target surfaces, active edge, cursor, and path before
  AI. Integration rejects any stale support injected after preparation.
- `nav-surfaces-v1` and `nav-graphs-v1` omit the runtime version, so a no-op
  rebuild retains content signatures while all version-local caches still
  invalidate.
- Normal `GameCore(...)`, `TrackManager`, and replay-validator construction do
  not expose or publish the terrain bundle. Only the named terrain harness can
  queue a replacement.

Executable evidence:

- `packages/runner_core/test/navigation/terrain_runtime_bundle_test.dart`
- `packages/runner_core/test/ecs/world_motion_authority_test.dart`
- `packages/runner_core/test/terrain_game_core_harness_test.dart`

## 22) Consumer And Ordering Audit

For every row, add executable evidence or an explicit later-phase disposition.

| Consumer | Required evidence | Executable evidence or disposition |
| --- | --- | --- |
| enemy navigation | reads prior validated support/version and current graph bundle | `enemy_navigation_terrain_support_test.dart` fixes the prepared-support seam; `terrain_surface_navigator_test.dart` covers bundle-version support/path invalidation. Production continues to consume its legacy graph until Phase 5. |
| grounded locomotion | composes intent before exactly-one terrain integration | `ground_enemy_terrain_locomotion_test.dart` and `world_motion_authority_test.dart` cover tangent intent, locks, and the single dispatcher. |
| gravity/jump | policy-specific and ordered before motion | `terrain_game_core_harness_test.dart`, `ground_enemy_terrain_locomotion_test.dart`, and `world_motion_authority_test.dart` cover player/enemy launch, gravity composition, and flying no-gravity policy. |
| animation | reads final support and resolved support distance | `enemy_navigation_terrain_support_test.dart` distinguishes prior AI support from final airborne animation; `ground_enemy_terrain_locomotion_test.dart` covers final support distance and seam stability. |
| engagement/melee/cast | world-X targets and derived AABB/origins remain intentional | `ground_enemy_terrain_locomotion_test.dart`, `test/core/enemy_engagement_system_test.dart`, and `test/core/ground_enemy_melee_facing_lock_test.dart`. |
| Hashash teleport | authority-owned clearance, support/path reset, safe fallback | `hashash_terrain_placement_test.dart` plus legacy `test/core/hashash_teleport_ambush_test.dart`. |
| Unoco hover/combat | local terrain reference and final resolved transform | `flying_enemy_terrain_locomotion_test.dart` plus legacy `test/core/flying_enemy_steering_test.dart` and `test/core/enemy_attacks_test.dart`. |
| enemy death/cull | final support/AABB and authored cull plane; camera cull unchanged | `ground_enemy_terrain_locomotion_test.dart` covers landing/timeout; `world_motion_authority_test.dart` covers death/fall policies. Camera culling remains the unchanged AABB consumer until Phase 5. |
| spawn service | exact placement result, stable diagnostics, unchanged RNG order | `terrain_spawn_placement_test.dart`, `hashash_terrain_placement_test.dart`, and `test/core/track_streamer_spawn_placement_test.dart`. |
| track manager | Phase 3 harness bundle only; production legacy disposition | `terrain_game_core_harness_test.dart` proves normal construction rejects replacement; production `TrackManager` still publishes rectangle geometry/legacy graphs. |
| player target prediction | previous support or authoritative sloped landing | `terrain_surface_navigator_test.dart` and `terrain_trajectory_predictor_test.dart`. ECS production targeting remains legacy until Phase 5. |
| snapshots/debug | Core-authored support/path/contact only; no Flame authority | `terrain_game_core_harness_test.dart` covers immutable Core terrain debug and final snapshot support/animation. |
| replay validator | normal legacy construction unchanged in Phase 3 | `services/replay_validator/test/validator_worker_test.dart`; validator calls normal `GameCore(...)`, and no replay contract selects the harness. |
| ballistic projectiles | explicit later-phase rejection in terrain harness | `world_motion_authority_test.dart` expects `ballisticProjectileUnsupported`; projectile terrain cutover remains Phase 5. |

Frozen high-level tick order:

1. publish any complete terrain/index/surface/graph replacement
2. refresh timers, locks, and ability phases
3. AI reads prior-tick support against the current bundle version
4. movement, jump, mobility/teleport, knockback, and gravity compose intent
5. one dispatcher integrates every terrain-owned dynamic actor exactly once
6. final support/contact/resolved motion becomes authoritative
7. downstream combat, death/cull, animation, snapshots, and debug read their
   documented state

- [x] Add an ordering test that fails if AI reads current-tick support before
      motion.
- [x] Add an ordering test that fails if animation reads stale support.
- [x] Add an exactly-once audit with multiple enemy policies.

The ordering seam is exercised by
`enemy_navigation_terrain_support_test.dart`: navigation observes the prepared
grounded state, the test publishes an airborne final motion state, and
animation must select `fall`. The mixed-policy audit in
`world_motion_authority_test.dart` dispatches player, Grojib, Hashash, and
Unoco exactly once while Derf remains kinematic and unsupported ballistics
remain rejected.

## 23) Deterministic Signatures And Scenario Matrix

Add reviewed versioned signatures:

- `nav-surfaces-v1`: ordered nodes, IDs, endpoints, adjacency, and chain IDs
- `nav-graphs-v1`: per-profile eligibility, CSR edges, kinds, points, ticks,
  and quantized costs
- `enemy-terrain-run-v1`: fixed-tick transforms, support/path state, contacts,
  teleports, spawns, diagnostics, combat commits, and deaths

Signature rules:

- [x] serialize canonical integers/IDs/enums, never formatted platform doubles
- [x] include explicit schema/version prefixes
- [x] generate in Core only
- [x] compare against committed reviewed SHA-256 files
- [x] prove fresh object, input permutation, and fresh-process parity
- [x] never update a golden merely because a test failed

Required scenario IDs:

| ID | Scenario |
| --- | --- |
| `SG-E01` | Grojib traverses flat-to-`45°`-to-flat in both directions |
| `SG-E02` | Grojib is blocked while Hashash traverses the same `46-60°` route |
| `SG-E03` | both ground enemies use valid 4-pixel step/snap and reject 5 pixels |
| `SG-E04` | same-chain pursuit crosses peaks, valleys, and exact seams without oscillation |
| `SG-E05` | jump and drop takeoff/landing work on sloped supports |
| `SG-E06` | wall/ceiling/underside/one-way policies match collision and graph |
| `SG-E07` | target seam change, airborne prediction, and graph invalidation |
| `SG-E08` | Hashash primary/mirror/cancel teleport matrix |
| `SG-E09` | Unoco local hover, solid blocking, one-way ignore, clearance steering |
| `SG-E10` | Derf eligible/invalid perch and unchanged cast semantics |
| `SG-E11` | ground/flying/deferred/item spawn placement and RNG-order parity |
| `SG-E12` | move/nav/stun locks, status speed, death landing/timeout/cull |
| `SG-E13` | 8 Grojib + 8 Hashash + 4 Unoco + 4 Derf representative mixed run |
| `SG-E14` | controlled geometry replacement while grounded, navigating, and airborne |
| `SG-E15` | all Phase 3 signatures repeat across fresh processes |

All scenarios use seed `0x3E71`. The Core-owned canonical serializer records
the fixture ID, sorted actor profiles, ordered command/AI schedule, quantized
checkpoints, named outcomes, and explicit legacy disposition for every row.
`enemy_terrain_signatures_test.dart` proves fresh-object, reversed polygon and
scenario input, reviewed-golden, mutation, completeness, and two-fresh-process
parity.

| ID | Fixture | Transition/final evidence and direct assertion |
| --- | --- | --- |
| `SG-E01` | `flat-45-flat-v1` | Grojib crosses the inclusive `45°` face in both directions, stays supported, and finishes on both requested flats. |
| `SG-E02` | `shared-60-route-v1` | The same node is ineligible in the Grojib graph and eligible in the Hashash graph; Hashash executes the route grounded. |
| `SG-E03` | `step-snap-4-vs-5-v1` | Grojib and Hashash activate step/snap on the lower-to-upper transition at exactly `4 px`; the `5 px` transition never activates either helper. |
| `SG-E04` | `peak-valley-seams-v1` | Same-chain pursuit crosses exact chunk seams, peaks, and valleys without a direction reversal before arrival. |
| `SG-E05` | `sloped-jump-drop-v1` | The Hashash graph emits quantized jump and committed-drop edges between separated sloped/lower supports; jump landing is replayed through the shared predictor and drop retains its swept descent/landing record. |
| `SG-E06` | `solid-one-way-mask-v1` | One-way top support is retained, vertical wall faces are absent from navigation nodes, and solid edge policy remains signature-visible. |
| `SG-E07` | `target-seam-airborne-invalidation-v1` | A Hashash airborne query predicts the sloped landing; a version change then clears current/last/target surfaces, active edge, cursor, and path after the recorded seam schedule. |
| `SG-E08` | `hashash-teleport-transaction-v1` | Primary and mirrored commits succeed; wall, ceiling, slope, and concave double-blockers cancel to retained state with unchanged RNG. |
| `SG-E09` | `unoco-terrain-flight-v1` | Local sloped hover, solid sweep contact, one-way pass-through, and bounded deterministic clearance selection all execute through the flying authority. |
| `SG-E10` | `derf-perch-cast-v1` | Flat/`15°` perches accept, over-limit rejects, and the accepted slope preserves ability, aim point, execute tick, facing, and instant-death semantics. |
| `SG-E11` | `shared-spawn-placement-v1` | Grounded, item, flying, and exact-edge deferred diagnostics remain canonical under permutation with zero replacement RNG draws; existing stream tests retain iteration/roll order. |
| `SG-E12` | `locks-status-death-cull-v1` | Move/nav/stun locking, composed status speed, landing death, timeout death, and ordinary cull all preserve their existing outcomes. |
| `SG-E13` | `representative-mixed-enemies-v1` | `8` Grojib, `8` Hashash, `4` Unoco, and `4` Derf run for `90` ticks; exactly `20` dynamic enemy bodies integrate and all `24` final states are recorded. |
| `SG-E14` | `atomic-bundle-replacement-v1` | Three version-`23` authorities publish version `24` while grounded, navigating, and airborne; stale paths clear before continued motion. |
| `SG-E15` | `fresh-process-parity-v1` | Two new Dart processes independently reproduce `nav-surfaces-v1`, `nav-graphs-v1`, and `enemy-terrain-run-v1`. |

For each scenario, record:

- fixture and seed
- actor/profile
- command/AI schedule
- expected support/path/contact transitions
- final transform/outcome
- signature or direct assertions
- flat legacy disposition where relevant

## 24) Allocation, Capacity, And Performance

Extend the existing benchmark rather than creating an unrelated timing format.

Measure separately:

- [x] shared surface extraction/index build
- [x] Grojib graph build
- [x] Hashash graph build
- [x] both grounded-enemy graphs from one shared surface set
- [x] combined terrain index plus both graph variants
- [x] supported Grojib and Hashash terrain solves
- [x] jump/drop multi-contact solves
- [x] Unoco blocked-flight solve and clearance steering
- [x] steady-state navigator update with and without repath
- [x] trajectory prediction
- [x] complete representative mixed-enemy Core tick
- [x] controlled streamed-bundle replacement

Representative fixture:

- 5 active chunks
- 1280 exposed edges
- 1 player
- 8 Grojib
- 8 Hashash
- 4 Unoco Demon
- 4 Derf
- current projectile/pickup load
- one chunk replacement and both grounded-enemy graph rebuilds

Hard-stream fixture:

- 5120 exposed edges
- normal actor counts
- query/rebuild safety only; no truncation

Frozen gates:

- [x] enemy candidates p95 `<=24`, p99 `<=64`
- [x] dynamic actor solve p95 `<=75 us`, p99 `<=150 us`
- [x] one enemy-profile graph build p95 `<=5 ms`, p99 `<=10 ms`
- [x] both grounded-enemy graphs p95 `<=20 ms`, p99 `<=35 ms`
- [x] combined index + graph rebuild p95 `<=35 ms`, p99 `<=50 ms`
- [x] representative whole-Core slope tick p99 `<=2 ms`
- [x] representative whole-Core hard gate p99 `<4 ms`
- [x] terrain adds `<=25%` versus the matched flat fixture
- [x] zero steady-state terrain-query/controller allocations per dynamic actor
- [x] zero steady-state query-buffer growth after warmup
- [x] bounded controller, predictor, steering, A*, and graph-build loops
- [x] no candidate/path/edge truncation

Every report records revision, dirty flag, OS/runtime, fixture/signatures,
warmup, sample count, p50/p95/p99/max, candidates, graph nodes/edges, rebuild
counts, allocation evidence, buffer growth, diagnostics, and per-gate result.

Implemented evidence:

- `tool/src/slopes_phase3_benchmark_fixture.dart` owns the reusable functional
  five-chunk/1,280-edge and hard 5,120-edge fixtures. Nonfunctional capacity
  edges are distant, non-walkable detail and cannot create fake jump origins.
- `tool/benchmark_slopes_phase3.dart` emits the same JSON evidence shape as the
  accepted Phase 1/2 tools and rejects any frozen gate under `--strict`.
- `test/performance/slopes_phase3_benchmark_fixture_test.dart` fixes fixture
  identity, graph counts, `8/8/4/4` integration, warmed storage, hard-stream
  capacity, and no-truncation behavior.
- the exact controller allocation loop is profiled separately under the VM
  service. Paired 500-iteration trials report zero `_Double`, `_Mint`, terrain,
  capsule, record, or wrapper allocations and `0.0` allocations per solve.
- acceptance timing uses a compiled product executable, 100 rebuild samples,
  500 hot warmups, 5,000 controller/navigation samples, 10,000 hard queries,
  four balanced 1,000-tick flat/slope runs, and the frozen gates above.

Accepted July 28 product-AOT report (`85b5b902`, dirty working tree, Windows
`10.0.26200`, Dart `3.11.5`):

| Measurement | p95 | p99 | Frozen gate |
| --- | ---: | ---: | ---: |
| Grojib graph build | `1.964 ms` | `2.713 ms` | `5/10 ms` |
| Hashash graph build | `1.553 ms` | `1.803 ms` | `5/10 ms` |
| Both ground-enemy graphs | `3.048 ms` | `3.339 ms` | `20/35 ms` |
| Combined terrain bundle | `6.219 ms` | `6.971 ms` | `35/50 ms` |
| Hard 5,120-edge index build | `6.199 ms` | `8.079 ms` | p99 `50 ms` |
| Supported ground solve | `26 us` | `48 us` | `75/150 us` |
| Blocked flying solve | `29 us` | `68 us` | `75/150 us` |
| Whole-Core slope tick | `805 us` | `1,134 us` | p99 `2/4 ms` |

The combined candidate distribution is p95 `3` and p99 `4`; every warmed
query-buffer delta is zero. The matched slope fixture is `0.02%` faster than
flat in this balanced run, well inside the `25%` ceiling. The separate paired
VM profile reports zero tracked hot-loop instances and `0.0` allocations per
solve. Every strict report gate is `true`.

## 25) Implementation Findings

Record findings that affect later implementation without silently changing
accepted gameplay.

| Finding | Resolution | Later-phase impact |
| --- | --- | --- |
| Enemy capsule tuning could drift if copied beside the legacy collider. | All four archetypes and Phase 3 profiles now reuse one catalog collider constant; the capsule derives and quantizes from it once. | Production AABB consumers remain unchanged while later terrain stores attach the exact derived capsule. |
| Identical geometry may be republished under a new bundle version. | `nav-surfaces-v1` excludes publication version but includes exact IDs, integer geometry, metadata, adjacency, and chains. Runtime indices remain version-local. | Atomic bundle work must compare version for cache validity and signature for content parity. |
| Exact endpoint branches can have more than one geometrically compatible continuation. | Surface extraction connects only one reciprocal candidate; ambiguous branches remain deterministic ledges instead of choosing an arbitrary path. | Authoring diagnostics may flag such joins in Phase 4, but graph construction must not synthesize fallback continuity. |
| A capsule positioned from only one face can overlap the compatible neighbor at an exact convex/concave transition. | Ground placement starts from exact `yAt(x)` and normal-aware capsule height, then raises only enough to clear eligible surfaces in the same canonical chain. | Graph/runtime location must use the shared query result instead of reconstructing a face-local bottom Y. |
| Legacy runtime standability stores its foothold as a floating one-third fraction. | The shared query represents support width as an exact rational and rounds the required tick width upward; grounded spawn is a separate full-diameter rule. | Graph construction can preserve each jump profile's fraction without copying floating-point range math. |
| Squaring both a large capsule radius and a long surface length can overflow the VM's signed integer range before square-root reduction. | Normal-aware placement now divides the radius projection by the compiled quantized up-normal component, then uses the existing chain-clearance correction. | Long 512-unit surfaces and current enemy capsules are regression-tested; future fixed-point geometry should avoid multiplying squared magnitudes together. |
| Legacy navigation costs are platform doubles, while Phase 3 signatures require canonical values. | `nav-graphs-v1` stores one-million-units-per-second integer costs; walk cost derives from source length/speed and jump/drop cost derives from travel ticks. | The Phase 3 A* migration must compare integer cost units and must not reintroduce formatted doubles. |
| A partial foothold formula can mathematically place a capsule center beyond a finite surface, where authoritative `yAtXTicks` intentionally rejects extrapolation. | Shared standable ranges retain the exact rational width test but clamp their emitted center interval to the finite source segment. | Jump/drop sampling, spawn clamping, and runtime lookup now share finite ledge bounds instead of inventing support beyond an endpoint. |
| Legacy drop reachability estimated a vertical fall even though runtime navigation commits horizontal movement after leaving the ledge. | Sloped drop construction integrates zero-initial-speed gravity and authored horizontal air speed each tick, then sweeps the complete capsule to the first valid support. | Section 13 must execute the recorded commit direction and must not substitute a vertical-only landing predictor. |
| A chain ID alone says that geometry is connected, but does not prove that one enemy profile can traverse every intermediate segment. | Same-chain pursuit verifies profile eligibility and an emitted walk edge at every adjacency before bypassing A*. | Later locomotion can pursue directly across slopes without oscillation while still respecting Grojib/Hashash graph differences. |
| Letting a move-locked actor activate a jump edge consumes the one-tick jump request while locomotion suppresses it. | Move locks may refresh support/path state but cannot activate a pending edge; nav/stun locks hold state after mandatory bundle invalidation. | Ground-enemy integration must pass the existing locks explicitly and preserve the pending takeoff until movement unlocks. |
| A raw time-of-impact point is not necessarily the controller's final support point for that tick because remaining motion can slide along a slope. | The predictor uses the first blocking contact to accept/reject the landing, then replays that complete tick through the accepted capsule controller and publishes its final support state. | Enemy navigation can compare prediction with runtime replay without accumulating slope-position drift. |
| Looking past an invalid first support could predict a lower landing through terrain the capsule cannot actually occupy. | The first support contact must pass the shared placement/clearance query; failure is terminal for that prediction rather than continuing to a later surface. | Trajectory consumers receive no landing for narrow or blocked first contact and must use their existing safe fallback. |
| Sparse-set dense order changes after swap removal, so using it directly would make multi-body diagnostics and failure position lifecycle-dependent. | The terrain dispatcher reuses an insertion-sorted ascending entity-ID body buffer for both preflight and integration. | Later mixed-enemy goldens can rely on one canonical body order independent of component churn. |
| A flying capsule still needs floor faces to block motion, but the shared controller classifies eligible solid floor contact as support. | Unoco keeps the controller's solid constraint and velocity projection while its motion-kind policy suppresses support/contact grounding publication. | Flying steering can use wall/ceiling/solid clearance without entering grounded navigation or receiving step/snap behavior. |
| Lazy enemy spawn means terrain stores may first appear immediately before AI, while a partial topology must never allow earlier actors to move. | `prepareTick` preflights every body first, then atomically attaches the complete catalog topology for untouched known enemies; `step` permits no initialization. | Spawn and streaming work may add known enemies before preparation, but any missing or mismatched store remains a typed hard failure before integration. |
| Terrain preparation resets the legacy collision compatibility flags before AI, so reading `CollisionStore.grounded` at that point makes valid terrain support appear airborne. | Enemy navigation, locomotion, animation, death, and render snapshots now read `WorldSupportView`, which selects terrain contact for migrated actors and legacy collision for all others. | Remaining enemy consumers must use the staged support facade rather than observing compatibility storage mid-tick. |
| Reusing world-X velocity as the acceleration state on a slope makes authored speed depend on tangent X and can retain stale slope Y while reversing or stopping. | Grounded enemy locomotion projects final velocity onto the positive-world-X support tangent, applies existing tuning in signed scalar surface-speed space, then emits one tangent vector for terrain authority. | Future status/AI speed modifiers stay upstream of terrain projection; they must not add a second incline curve. |
| An unchecked teleport write cannot safely validate two candidates because the first rejected point would already have destroyed the retained transform/history. | World motion now exposes begin, exact-candidate commit, and cancel operations. Begin retains the last valid body/capsule-facing transform and clears support/path; only a valid placement result mutates the destination. | Future teleports must use the transactional authority contract instead of writing transforms around a clearance query. |
| Deferred Hashash requests were indistinguishable from ordinary authored marker spawns at the `GameCore` callback. | `SpawnEnemyRequest` now carries deterministic source provenance; only `deferredHashashEdge` binds its exact body-X/requested-Y point to one canonical intended edge and runs the full-width grounded placement query there. Rejection consumes the pending request without relocation or replacement RNG. | Phase 5 terrain streaming can replace the legacy surface hint with exact terrain source identity without changing spawn ordering or failure policy. |
| Terrain contact blockers are transient and reset before AI, while blocked flying steering must react on the following tick. | The authority copies only Unoco's final blocked bit and first canonical solid normal into its persistent steering store after integration. Clearance consumes that prior result, previews four fixed vectors for six ticks, and holds a selected detour for 12 ticks unless a new solid contact re-evaluates it. | Future flying profiles can reuse the authority contract without reading cleared contact state, adding RNG, or gaining a second transform writer. |
| The common foothold fraction alone cannot express Derf's 32-pixel perch margin: treating 32 pixels as capsule contact width would over-constrain an exactly 32-pixel support. | `TerrainGroundPlacementRequest.minimumSupportSpanTicks` is independent of the existing foothold requirement and reserves half the total span on each edge. Derf combines a full capsule foothold with a 32-pixel total span, so an exact perch accepts only its midpoint. | Section 20 item placement can reuse the independent absolute-span contract without changing grounded runtime foothold semantics. |
| A player-walkable steep support does not guarantee that an upright item using the existing vertical clearance fits above it. | Item placement first accepts support through Éloïse's inclusive 60-degree profile, then independently tests the complete margin-expanded AABB. A clipping candidate is terminal and consumes its normal attempt. | Content authoring may increase local clearance or choose gentler item-bearing surfaces; runtime must not rotate the pickup or search beneath an invalid highest surface. |
| Publishing geometry and graph objects alone would still leave controller, spawn, and flying-query scratch bound to the old indexes. | The authority queues a complete publication wrapper containing the immutable runtime bundle plus every geometry-bound controller/query scratch object, then swaps that one wrapper at `prepareTick`. | Phase 5 streaming must preserve this publication unit and must not rebuild controller/index state lazily inside consumers. |
| The terrain graph needs the same jump templates and speed tuning as the legacy graph, but world-motion authority construction previously happened before system/template initialization. | GameCore now creates the existing ground-enemy jump templates before authority selection and supplies those exact templates to both the terrain graph profiles and legacy TrackManager setup. | Production cutover can compare graph outputs without maintaining parallel reachability tuning or changing normal construction behavior. |
| Lifting by exactly the authored step height makes an inclusive `4 px` ledge appear as endpoint tangency, while capsule corner motion can otherwise activate a helper after crossing a `5 px` discontinuity. | Step preview adds deterministic skin/epsilon clearance, accepts an eligible endpoint only after comparing source/destination surface height, and applies the same geometric-height cap to snap transitions. Exact `4 px` accepts and `5 px` never activates the helper for both grounded enemies. | Future profile limits must test the inclusive boundary and the first rejected grid value, not only an interior `3 px` example. |
| Filling a performance fixture with ordinary walkable polygons silently creates graph nodes and jump origins that are not part of the intended workload. | The accepted fixture uses functional terrain for graph/navigation behavior and distant over-limit detail only for edge/index capacity. Exact fixture signatures and counts are tested. | Future benchmarks must prove their synthetic capacity geometry cannot participate in gameplay systems being measured. |
| Persisting every edge-to-cell membership as object records made the 5,120-edge hard rebuild spend memory and time on evidence needed only by golden serialization. | `TerrainEdgeIndex` stores only runtime buckets and derives canonical membership records on demand from immutable edge bounds. | Phase 5 streaming should keep diagnostic serialization outside query/rebuild hot storage. |
| Replacing one boxed retained-support `double` with naïve squared integer math introduced three boxed `_Mint` values per solve; multiplying a long edge length by the fractional scale also overflowed signed 64-bit arithmetic. | Edges now precompute bounded GCD-reduced projection factors and a conservative 1/1024-tick ceiling length without scaled-square multiplication. Long 3,000-unit support, endpoint, and full-kernel parity tests protect the fix; the profiler tracks both `_Double` and `_Mint`. | Fixed-point optimization is accepted only with allocation traces and long-coordinate tests, not by assuming integer expressions stay unboxed. |
| Skipping continuous sweep for every walkable candidate improved timing but changed the reviewed enemy-run digest because neighboring/overlapping support contacts are gameplay-significant. | Grounded motion skips only its already-retained support edge. Every neighboring or unrelated face remains in canonical sweep/contact selection, and all three reviewed signatures remain unchanged. | Later optimizations must use the scenario digest as a semantic guardrail and may not rewrite goldens to hide support-selection drift. |
| Unoco's local hover query rescanned every geometry edge for the same immutable maximum Y, multiplying a topology-wide operation by every flying actor and tick. | The authority publication now computes minimum/maximum terrain Y once beside the immutable bundle and every geometry-bound query scratch. Player placement and flying reference queries reuse those version-local bounds. | Phase 5 streamed publication must rebuild aggregate geometry bounds once with the bundle; per-actor queries must not rediscover topology-wide facts. |

## 26) Documentation

During implementation:

- [x] create or update a focused TDD for sloped navigation, enemy motion,
      placement authority, versioning, and deterministic ordering
- [x] update `docs/tdd/terrain_capsule_controller.md` if controller/profile
      contracts change
- [x] update `docs/tdd/runner_core_simulation_contract.md` if tick ordering or
      construction boundaries change
- [x] update the enemy/navigation/spawn GDD documents for delivered
      player-facing behavior
- [x] keep proposed Phase 4-7 work in `docs/building/**`
- [x] review the closest `AGENTS.md`; no working rule or boundary drift requires
      an update
- [x] update the master slopes plan status and immediate next step
- [x] keep public APIs self-usable with units, ownership, version, mutation,
      and failure behavior documented

Do not document the Phase 3 harness as normal production authority.

## 27) Validation Ledger

| Date/revision | Command/evidence | Environment | Result |
| --- | --- | --- | --- |
| July 21, 2026 / `9eea5cfd` clean baseline | `dart analyze`; `dart test` in `packages/runner_core`; `flutter test test/core`; validator `dart analyze` + `dart test test` | Windows `10.0.26200` X64; Dart `3.11.5`; Flutter `3.41.7` | PASS: `143` package, `432` root Core, `75` validator tests; analyzers clean |
| July 21, 2026 / working tree | Enemy profile, surface extraction, fresh-process signature, brute-force index, 1,280/5,120 capacity, and 10,000-query warm-buffer tests | Same baseline environment | PASS: `5` enemy-profile, `8` surface-extraction, and `8` surface-index tests; package analyzer clean |
| July 21, 2026 / working tree post-foundation | Root/package `dart analyze`; full package `dart test`; `flutter test test/core`; validator analysis + full tests | Same baseline environment | PASS: analyzers clean; `164` package, `432` root Core, and `75` validator tests |
| July 22, 2026 / working tree post-placement-query | Focused placement-query test; root/package `dart analyze`; full package `dart test`; `flutter test test/core` | Same baseline environment | PASS: `11` focused placement tests, analyzers clean, `175` package tests, and `432` root Core tests |
| July 22, 2026 / working tree post-walk-graphs | Focused placement/walk-graph tests; root/package `dart analyze`; full package `dart test`; `flutter test test/core` | Same baseline environment | PASS: `20` focused tests, analyzers clean, `184` package tests, and `432` root Core tests |
| July 22, 2026 / working tree post-jump/drop-graphs | Focused placement/graph tests; root/package `dart analyze`; full package `dart test`; diff check | Same baseline environment | PASS: `28` focused and `192` package tests; analyzers and diff check clean |
| July 22, 2026 / working tree post-terrain-navigator | Focused terrain pathfinder/navigator test; root/package analysis; full package `dart test`; diff check | Same baseline environment | PASS: `11` focused and `203` package tests; analyzers and diff check clean |
| July 22, 2026 / working tree post-terrain-trajectory | Focused terrain trajectory test; root/package analysis; full package `dart test`; diff check | Same baseline environment | PASS: `12` focused and `215` package tests; analyzers and diff check clean |
| July 22, 2026 / working tree post-multi-body-motion | Focused world-motion authority and terrain-harness tests; root/package analysis; full package `dart test`; `flutter test test/core`; diff check | Same baseline environment | PASS: `14` focused authority, `223` package, and `432` root Core tests; analyzers and diff check clean |
| July 23, 2026 / working tree post-ground-enemy-locomotion | Focused grounded-enemy terrain locomotion and prepared-support navigation tests; root/package analysis; full package `dart test`; `flutter test test/core` | Same baseline environment | PASS: `11` focused, `234` package, and `432` root Core tests; analyzers clean |
| July 23, 2026 / working tree post-Hashash-placement | Hashash terrain placement, world-motion authority, legacy ambush, and deferred-streamer tests; root/package analysis; full package `dart test`; `flutter test test/core`; final exact-intended-edge refinement followed by package full and root focused reruns | Same baseline environment | PASS: `19` package-focused, `4` root-focused, `239` full package, and `432` root Core tests; final rerun kept `239` package and `4` focused root tests green; analyzers clean |
| July 26, 2026 / working tree post-atomic-publication/audit | Runtime-bundle, world-motion replacement, prepared-support/final-animation ordering, and terrain-harness input-order tests; package/root analysis; full package `dart test`; `flutter test test/core --reporter compact`; diff check | Same baseline environment | PASS: `51` focused, `278` full package, and `432` root Core tests; package analyzer clean; root analyzer reports only the pre-existing unrelated `use_null_aware_elements` info in `services/replay_validator/lib/src/run_session_repository.dart:447` |
| July 27, 2026 / working tree post-scenario-signatures | Exact `4/5 px` controller boundary tests; `105` focused terrain/enemy tests; reviewed signature print; package/root analysis; full package `dart test`; `flutter test test/core --reporter compact`; replay-validator analysis + full tests; `git diff --check` | Windows `10.0.26200` X64; Dart `3.11.5`; Flutter `3.41.7` | PASS: package analyzer clean; `283` full package, `432` root Core, and `78` replay-validator tests; three reviewed hashes repeat across reversed input and two fresh processes; root analyzer reports only the same pre-existing unrelated `use_null_aware_elements` info |
| July 28, 2026 / `85b5b902` dirty working tree, Phase 3 acceptance | Compiled `benchmark_slopes_phase3.dart --strict`; paired VM allocation profile; package/root/validator analysis; full package, root Core, and validator tests; reviewed signature helper; diff check | Windows `10.0.26200` X64; Dart `3.11.5`; Flutter `3.41.7`; compiled-product benchmark | PASS: every frozen benchmark gate; zero tracked controller allocations and buffer growth; `291` package, `432` root Core, and `78` validator tests; all reviewed hashes unchanged. Package/validator analyzers are clean; root analysis retains only the pre-existing unrelated `use_null_aware_elements` info. |

Final validation commands:

```powershell
dart analyze
dart analyze packages/runner_core

Push-Location packages/runner_core
dart test
dart compile exe tool/benchmark_slopes_phase3.dart `
  -o .tmp/slopes-phase3.exe
.\.tmp\slopes-phase3.exe --strict `
  --json-out=.tmp/slopes-phase3-final.json
dart --observe=0 run tool/benchmark_slopes_phase2.dart `
  --warmup=10 --iterations=10 --harness-iterations=10 `
  --allocation-profile --allocation-iterations=500 `
  --json-out=.tmp/slopes-phase2-allocation-final.json
Pop-Location

flutter test test/core

Push-Location services/replay_validator
dart analyze
dart test test
Pop-Location
```

The allocation invocation deliberately uses small ordinary timing samples:
its acceptance evidence is the isolated paired heap profile, while timing
acceptance comes only from the compiled Phase 3 executable with default sample
counts.

## 28) Exit Gate

- [x] All four current enemies have explicit tested terrain policies.
- [x] Shared sloped surface nodes/identity/order are deterministic.
- [x] Grojib and Hashash graph variants differ only by eligibility/edges.
- [x] Collision and navigation agree on slopes, step/snap, one-way, clearance,
      jump, and drop feasibility.
- [x] Grounded enemy locomotion and animation use final support correctly.
- [x] Hashash teleport/deferred spawn cannot embed or silently relocate.
- [x] Unoco cannot tunnel, ground on one-way terrain, phase, or teleport around
      blockers.
- [x] Derf placement enforces slope, width, same-support, and clearance rules.
- [x] Spawn/item placement and RNG ordering pass.
- [x] Geometry/graph bundle replacement is atomic and invalidates stale state.
- [x] All `SG-E01` through `SG-E15` scenarios pass.
- [x] All reviewed signatures match across fresh instances/processes.
- [x] Allocation, capacity, and performance gates pass.
- [x] Normal production and replay construction remain legacy and unchanged.
- [x] Full Core, root gameplay, and replay-validator validation passes.
- [x] Documentation describes implemented Phase 3 behavior accurately.
- [x] Implementation findings are reviewed before Phase 4 work begins.

Only after every exit item is checked and evidence is accepted may Phase 4
polygon authoring/schema implementation planning begin.
