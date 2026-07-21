# Slopes Phase 3 - Sloped Surface Graphs And Enemy Cutover Readiness Checklist

- Created: July 20, 2026
- Status: Ready for implementation; no open gameplay decision blocks work
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

- [ ] Record the starting revision, dirty flag, OS, Dart/Flutter versions, and
      relevant dependency lock state.
- [ ] Run `dart analyze packages/runner_core`.
- [ ] Run all `packages/runner_core` tests.
- [ ] Run the full root `test/core` suite.
- [ ] Run replay-validator analysis and tests.
- [ ] Record current Grojib and Hashash path/position/attack outcomes on flat
      geometry for fixed seeds and command streams.
- [ ] Record current Unoco hover, steering, cast, melee, and spawn behavior.
- [ ] Record current Hashash deferred spawn, teleport timing, destination,
      strike queue, cancellation, and cooldown behavior.
- [ ] Record current Derf placement, facing, cast origin, and target behavior.
- [ ] Record existing graph node/edge ordering and A* tie-break behavior.
- [ ] Confirm normal construction and replay validation still use the legacy
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

- [ ] Add immutable enemy world-contact shape/profile definitions to the
      authoritative enemy catalog or a catalog-owned resolver.
- [ ] Quantize every shape/profile value once at construction.
- [ ] Preserve the existing authored-facing offset mirror rule.
- [ ] Prove the derived AABB is exact for both facings and all four enemies.
- [ ] Keep combat, pickup, broad-phase, culling, and render bounds on the
      derived AABB.
- [ ] Give Grojib a `45°`, 4-pixel step/snap grounded profile.
- [ ] Give Hashash a `60°`, 4-pixel step/snap grounded profile.
- [ ] Give both grounded enemies constant distance-along-surface locomotion.
- [ ] Give Unoco a flying profile with no support, snap, step, gravity, or
      one-way contact.
- [ ] Give Derf a kinematic clearance profile; do not integrate it per tick.
- [ ] Preserve Grojib/Hashash ceiling-ignore and one-way behavior explicitly;
      do not inherit player defaults accidentally.
- [ ] Fail construction when a current enemy has no explicit terrain policy.

Tests:

- [ ] invalid dimensions and non-finite authoring values fail
- [ ] exact tick values and derived bounds for all four enemies
- [ ] mirrored offset parity for left/right facing
- [ ] profile slope/step/snap/one-way/ceiling flags are explicit
- [ ] catalog enumeration and policy enumeration contain the same four IDs

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

- [ ] Use canonical `TerrainEdgeId` as the graph node's persistent identity
      and deterministic tie-break; do not hash it into a legacy packed integer.
- [ ] Cache graph node indices in runtime nav state only with the exact bundle
      version and clear them before use on every version mismatch.
- [ ] Do not retain a node index across bundle versions.
- [ ] Include exposed, upward-facing, X-monotonic, non-vertical candidate
      surfaces in canonical edge-ID order.
- [ ] Keep over-limit slopes in the shared set; profile filtering happens
      later.
- [ ] Preserve solid versus one-way classification.
- [ ] Exclude walls, ceilings, internal/shared boundaries, and invalid seams
      from standable candidates.
- [ ] Build connected chains only through compatible exact endpoints.
- [ ] Preserve intentional ledges and incompatible material/collision-mode
      boundaries.
- [ ] Derive chain identity from the canonical lowest member identity and
      verify uniqueness.
- [ ] Reuse the Phase 1 geometry version; do not invent an independent surface
      version.
- [ ] Remove constant-`yTop` assumptions from the new representation.
- [ ] Keep one navigation node representation; any temporary legacy adapter
      must emit that representation rather than maintaining a second graph
      model.

Tests:

- [ ] flat, uphill, downhill, vertical, ceiling, and one-way edges
- [ ] flat-slope-flat, convex peak, concave valley, and intentional ledge
- [ ] exact and incompatible cross-polygon/chunk seams
- [ ] clockwise/counterclockwise input parity
- [ ] negative coordinates and overlapping X ranges
- [ ] canonical IDs/order across input permutations and fresh processes
- [ ] no-op geometry rebuild produces the same surface/chain signature

## 9) Surface Spatial Index And Query Buffers

- [ ] Index full segment bounds, not a thin slab at one `yTop`.
- [ ] Reuse the accepted Phase 1 grid and canonical candidate ordering where
      practical.
- [ ] Query into caller-owned buffers with stamp-based deduplication.
- [ ] Sort candidates by canonical surface identity only after deduplication.
- [ ] Expose candidate count, cells visited, and buffer resize count.
- [ ] Never truncate candidates to satisfy a budget.
- [ ] Handle exact cell boundaries, long slopes, negative coordinates, and
      5120-edge hard-stream bounds.
- [ ] Prove zero steady-state query-buffer growth after warmup.

Tests:

- [ ] indexed results match brute-force segment-bounds queries
- [ ] duplicate cell occupancy yields one candidate
- [ ] stable order is independent of insertion order
- [ ] queries above, below, and across a sloped segment are complete
- [ ] representative and hard-stream capacities do not truncate

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

- [ ] Use the complete upright capsule for terrain clearance.
- [ ] Use exact `yAt(x)` and the support normal; never reconstruct a flat
      bottom Y.
- [ ] Separate runtime navigation support fraction from spawn support width.
- [ ] Preserve the existing per-enemy runtime support fraction used by jump
      profiles unless a measured counterexample requires review.
- [ ] Require full capsule-width support for grounded spawns.
- [ ] Require profile-eligible slope/collision mode.
- [ ] Highest-surface lookup prefers smallest world Y, then canonical edge ID.
- [ ] Same-support clamp never crosses a ledge, chain break, or source boundary.
- [ ] Full-clearance validation checks walls, ceilings, undersides, adjacent
      polygons, and capsule endpoint contacts.
- [ ] One-way back sides do not block a clearance-only flying/teleport query
      when the actor policy ignores them.
- [ ] Return stable typed failure diagnostics; do not silently relocate.

Tests:

- [ ] surface lookup at every slope transition and exact endpoint
- [ ] profile difference at `45°`, between `45-60°`, exactly `60°`, and over
      `60°`
- [ ] narrow peaks, insufficient support, blocked headroom, and adjacent wall
- [ ] solid/one-way surfaces with overlapping X ranges
- [ ] highest-surface and same-support tie-breaks
- [ ] full-width spawn versus runtime partial-support distinction
- [ ] geometry-version mismatch invalidates a retained result

## 11) Shared Nodes And Per-Enemy Graph Variants

Refactor graph construction into:

1. one shared immutable surface set and spatial index
2. one Grojib graph view
3. one Hashash graph view

Both graph variants contain the same nodes, IDs, indices, and ordering. They
may differ only in node eligibility and directed traversal edges.

- [ ] Add an explicit `walk` edge kind alongside `jump` and `drop`.
- [ ] Store profile eligibility without deleting or reordering shared nodes.
- [ ] Assert shared node identity/order on every publication.
- [ ] Generate walk edges for compatible adjacent segments and accepted
      4-pixel transitions.
- [ ] Require the same capsule/clearance query used at runtime.
- [ ] Exclude over-profile slopes from ordinary walking.
- [ ] Preserve deterministic CSR edge grouping and ordering.
- [ ] Define walk cost from distance along the surface divided by the enemy's
      authored locomotion speed.
- [ ] Keep jump/drop costs time-based as currently authored.
- [ ] Make all cost/tie-break math deterministic and signature-visible.
- [ ] Do not add fallback edges merely to make every target reachable.

Tests:

- [ ] shared node IDs/order with different eligibility and edge sets
- [ ] Grojib rejects a `46-60°` walk route that Hashash accepts
- [ ] both accept their exact inclusive limits
- [ ] connected slopes and compatible seams emit ordinary walk edges
- [ ] a 4-pixel feasible transition emits walk; 5 pixels does not
- [ ] blocked/narrow/steep transition emits no walk edge
- [ ] walk cost equals measured constant-surface-speed travel time
- [ ] repeated graph builds and input permutations produce identical CSR

## 12) Jump And Drop Graph Construction

- [ ] Compute takeoff Y from the source segment at takeoff X.
- [ ] Compute landing Y/normal from the destination at landing X.
- [ ] Use profile-specific standability and slope eligibility.
- [ ] Use existing deterministic jump templates and tick integration.
- [ ] Sweep the complete capsule through solid terrain for obstruction.
- [ ] Respect each enemy's ceiling and one-way policy.
- [ ] Reject arcs blocked by walls, ceilings when applicable, sloped
      undersides, endpoints, or intervening terrain.
- [ ] Find the earliest valid landing on the collision-valid side.
- [ ] Drop from the true ledge and select the first valid support below.
- [ ] Preserve takeoff sampling bounds and document any changed sample rule.
- [ ] Tie-break equal landings by tick, vertical priority, then canonical
      surface ID.
- [ ] Never emit jump/drop edges to an ineligible destination.

Tests:

- [ ] flat-to-slope, slope-to-flat, slope-to-slope jump
- [ ] uphill/downhill takeoff in both directions
- [ ] landing at an endpoint, on a narrow surface, and at the slope limit
- [ ] one-way landing from above and pass from below
- [ ] convex peak and concave valley near takeoff
- [ ] wall, ceiling, underside, and intermediate-platform obstruction
- [ ] drop from both ledges to the first eligible sloped support
- [ ] high-speed/thin-surface landing without tunneling
- [ ] equal-time candidate order remains stable

## 13) Pathfinder And Runtime Navigator

- [ ] Preserve deterministic A* and reusable path buffers.
- [ ] Extend A* to `walk`, `jump`, and `drop` edges.
- [ ] Preserve stable cost, preferred-direction, and surface-ID tie-breaks.
- [ ] Read prior-tick validated support ID/version for the enemy.
- [ ] Read the player's prior-tick support for grounded target reasoning.
- [ ] Invalidate current/last/target support, path, cursor, and active edge
      before AI runs when geometry/graph version changes.
- [ ] Use the shared query only when retained support is absent or needs
      validation.
- [ ] Follow connected same-chain geometry without repeated repath or segment
      oscillation.
- [ ] Preserve takeoff approach and in-flight commit direction.
- [ ] Complete an edge only on validated destination support.
- [ ] Clamp no-plan fallback to the last known eligible support; never
      teleport or cross an ineligible ledge.
- [ ] Preserve nav/move/stun lock semantics.

Tests:

- [ ] same-chain chase across multiple slope segments
- [ ] target crosses a seam or moves to another chain
- [ ] target becomes airborne and lands on a slope
- [ ] path preference/tie-break parity in both horizontal directions
- [ ] takeoff overshoot does not oscillate
- [ ] in-flight jump/drop direction remains committed
- [ ] wrong landing does not complete the active edge
- [ ] graph-version replacement clears all stale references immediately
- [ ] no-plan fallback remains on eligible terrain

## 14) Sloped Trajectory Prediction

- [ ] Match Core's fixed-tick gravity/velocity integration.
- [ ] Predict the full capsule/support path, not a center ray or horizontal
      bottom band.
- [ ] Query swept segment bounds each predicted tick.
- [ ] Accept only descending contact on a profile-eligible surface.
- [ ] Return exact landing point, support ID, geometry version, and tick.
- [ ] Choose earliest tick, then highest surface, then canonical ID.
- [ ] Reuse candidate/output buffers in repeated AI queries.
- [ ] Return no landing when the first contact is a wall/ceiling or clearance
      is insufficient.

Tests:

- [ ] vertical and diagonal fall onto flat and sloped surfaces
- [ ] high-speed fall onto a thin sloped platform
- [ ] jump arc landing uphill/downhill
- [ ] multiple crossed surfaces select the first valid landing
- [ ] ascending/back-side/one-way-invalid contacts are ignored
- [ ] too-wide capsule and blocked landing return no result
- [ ] predictor result agrees with the accepted controller replay

## 15) Multi-Body World-Motion Authority

Generalize the isolated player authority into one terrain dispatcher that owns
every enabled non-kinematic actor in the Phase 3 harness exactly once.

- [ ] Preserve one `prepareTick` and one `step` audit per Core tick.
- [ ] Iterate bodies in stable entity order.
- [ ] Initialize capsule, traversal, contact, and resolved-motion stores for
      player, Grojib, Hashash, and Unoco according to policy.
- [ ] Reuse one controller/result scratch set per traversal profile; do not
      allocate per entity/tick.
- [ ] Read prior support before AI and publish final support after motion.
- [ ] Compose locomotion, jump, mobility/teleport state, gravity, and external
      velocity before the one terrain solve.
- [ ] Keep Derf kinematic and validate only explicit placement/mutation.
- [ ] Continue to reject unsupported dynamic bodies and ballistic projectiles
      in the Phase 3 harness.
- [ ] Do not fall back to legacy AABB collision for a terrain-owned body.
- [ ] Write derived AABB/contact compatibility only after the final transform.
- [ ] Preserve the player-distance return contract.
- [ ] Keep normal production construction on `LegacyWorldMotionAuthority`.

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

- [ ] zero/one/many enemies are integrated exactly once
- [ ] stable entity order cannot change outcomes
- [ ] missing policy/store fails before partial integration
- [ ] geometry replacement invalidates every affected support/path
- [ ] disabled, kinematic, dying, and falling bodies follow explicit policy
- [ ] player results remain identical with and without inactive enemy bodies

## 16) Grojib And Hashash Grounded Locomotion

- [ ] Convert authored speed to constant requested distance along support.
- [ ] Do not apply Éloïse's uphill/downhill speed curve.
- [ ] Preserve existing engagement, arrival, status, and control-lock
      multipliers before terrain projection.
- [ ] Preserve world-X chase/stand-off targets.
- [ ] Follow the support tangent in the intended horizontal direction.
- [ ] Use the accepted 4-pixel step/snap helper during ordinary grounded
      pursuit.
- [ ] Keep jump launch world-up and existing horizontal jump-edge velocity
      snap/commit rules.
- [ ] Do not snap an accepted jump back to support.
- [ ] Remove only velocity entering a blocking terrain constraint.
- [ ] Preserve final-support-driven animation and resolved-distance playback.
- [ ] Preserve melee/cast origins and facing behavior.
- [ ] Ground-impact death waits for final support or the existing deterministic
      timeout.

Tests:

- [ ] idle, walk, reverse, accelerate, decelerate, and stop on slopes
- [ ] both directions at flat/intermediate/exact-limit angles
- [ ] Grojib constant surface speed at `45°`
- [ ] Hashash constant surface speed at `60°`
- [ ] step, snap, seam, peak, valley, wall, ceiling policy, and one-way
- [ ] jump/drop graph execution and off-course velocity recovery
- [ ] nav/move/stun locks and status speed modifiers
- [ ] melee engage/strike/recover facing and stand-off offsets
- [ ] grounded/airborne animation has no seam flicker
- [ ] death in air, slope landing, timeout, and culling

## 17) Hashash Teleport And Deferred Spawn

- [ ] Route teleport writes through a terrain placement authority.
- [ ] Clear prior support/path before destination validation.
- [ ] Test the primary point `36 px` right and `36 px` above the predicted
      player first.
- [ ] Require full capsule clearance; airborne ambush support is not required.
- [ ] If blocked, test the mirrored left/above point second.
- [ ] Queue the strike only after successful placement.
- [ ] If both fail, restore/retain last safe transform, queue no strike, and
      apply the normal cooldown.
- [ ] Consume no RNG during fallback.
- [ ] Reinitialize last-valid capsule state after successful teleport.
- [ ] Apply the same grounded placement query to deferred edge spawns; invalid
      placement skips that pending spawn.

Tests:

- [ ] primary point clear
- [ ] primary blocked/mirrored clear
- [ ] both blocked by slope, wall, ceiling, and concave corner
- [ ] no support remains valid for airborne ambush
- [ ] no strike on cancellation and cooldown is normal
- [ ] destination/result independent of candidate/input ordering
- [ ] deferred spawn succeeds on eligible slope and skips invalid support

## 18) Unoco Demon Flying Contact And Hover

- [ ] Resolve the highest relevant local solid terrain below the capsule's
      horizontal footprint.
- [ ] Preserve the existing randomized `60-180 px` hover band and RNG order.
- [ ] Retain the last valid local reference when no terrain lies below.
- [ ] Use the level flight-reference plane only when no prior local reference
      exists.
- [ ] Continue bounded vertical steering; never teleport to a new reference.
- [ ] Sweep the complete capsule against solid terrain from every side.
- [ ] Ignore one-way platforms for contact, recovery, support, and steering.
- [ ] Never set grounded/support state.
- [ ] Keep move-and-slide as the immediate collision response.
- [ ] Add a fixed, bounded clearance-steering candidate set only when blocked.
- [ ] Rank candidates by progress toward combat/hover target, then clearance,
      then stable candidate ID.
- [ ] Consume no RNG and grant no phasing/teleport fallback.
- [ ] Preserve cast/melee timing, target policy, origins, and facing.

Before implementing clearance steering, record its ordered candidate vectors
and turn/hold rule in this checklist. If profiling shows that a candidate set
materially changes combat pressure rather than merely resolving blockage, ask
the user one gameplay question before accepting it.

Tests:

- [ ] follow flat/uphill/downhill local hover reference
- [ ] pit/no-surface retains last reference, then explicit plane fallback
- [ ] wall, slope, ceiling, underside, and concave-corner blocking
- [ ] thin solid at maximum flight speed does not tunnel
- [ ] one-way platforms never block or ground
- [ ] deterministic route around an obstacle and return toward target
- [ ] no oscillation, new RNG, teleport, or terrain phasing
- [ ] combat timing/outcomes remain intentional

## 19) Derf Kinematic Placement

- [ ] Use the common placement query without giving Derf motion authority.
- [ ] Accept solid intended obstacle-top support at `15°` inclusive.
- [ ] Require at least `32 px` horizontal support span.
- [ ] Require complete capsule clearance.
- [ ] Clamp marker X only to the nearest valid point on the same support.
- [ ] Skip absent, too-steep, too-narrow, or obstructed placements.
- [ ] Emit a stable authoring/debug diagnostic.
- [ ] Never fall back to unrelated highest terrain or ordinary ground.
- [ ] Preserve face-player, predicted-player-center cast target, world-space
      cast origin, upright art, and instant death behavior.

Tests:

- [ ] flat, `15°`, and just-over-limit support
- [ ] exactly `32 px` and just-under-width support
- [ ] blocked capsule/headroom and adjacent wall
- [ ] same-support clamp in both directions
- [ ] no unrelated fallback and stable diagnostic
- [ ] cast origin/target/facing unchanged on gentle slope

## 20) Terrain-Dependent Spawn And Item Queries

- [ ] Introduce one placement request/result API with explicit actor/item
      profile, intended support/source, clamp permission, and failure reason.
- [ ] Preserve marker iteration, chunk selection, spawn rolls, rejection
      attempts, salts, and RNG consumption.
- [ ] Grounded Grojib/Hashash require eligible same-support full-width
      placement and clearance.
- [ ] Unoco spawn requires clearance at the intended flying point and skips
      when blocked.
- [ ] Derf uses §19 only.
- [ ] Collectible/restoration placement uses player-walkable solid or one-way
      support up to `60°`.
- [ ] Items require at least `20 px` horizontal support and full AABB
      clearance with existing vertical/margin tuning.
- [ ] Invalid item candidates consume their normal attempt; exhaustion spawns
      nothing.
- [ ] Preserve placement-mode intent for `ground`, `highestSurfaceAtX`, and
      `obstacleTop` without depending on rectangle top faces.
- [ ] Keep the required player-initial-placement validation query available
      for Phase 5; do not cut over production level startup here.

Tests:

- [ ] all three marker placement modes on flat/sloped/overlapping terrain
- [ ] enemy profile differences and same-support clamp
- [ ] item solid/one-way/width/slope/clearance rules
- [ ] invalid marker does not shift later RNG outcomes
- [ ] deferred Hashash count/order remains deterministic
- [ ] repeated and fresh-process spawn results match

## 21) Atomic Geometry, Index, Surface, And Graph Publication

Define one immutable versioned terrain runtime bundle for the Phase 3 harness:

- `TerrainGeometry`
- `TerrainEdgeIndex`
- shared surface set/index
- Grojib graph
- Hashash graph
- one shared geometry/graph version

- [ ] Build all derived structures before publication.
- [ ] Validate shared node identity/order and every profile graph first.
- [ ] Publish the complete bundle atomically.
- [ ] Never expose mixed old/new geometry and graph versions during a tick.
- [ ] AI invalidates stale support/path before reading it.
- [ ] Motion rejects stale support and resolves against the current bundle.
- [ ] No-op rebuild signatures remain identical even if version increments.
- [ ] Controlled spawn/cull replacement removes obsolete adjacency and paths.
- [ ] Preserve normal `TrackManager` legacy publication until Phase 5.

Tests:

- [ ] no-op replacement
- [ ] add/remove a chunk-side surface
- [ ] cull the current/target/landing surface
- [ ] replace support while an enemy is grounded
- [ ] replace graph during jump/drop execution
- [ ] identical result independent of rebuild/input ordering
- [ ] no consumer observes mixed versions

## 22) Consumer And Ordering Audit

For every row, add executable evidence or an explicit later-phase disposition.

| Consumer | Required evidence |
| --- | --- |
| enemy navigation | reads prior validated support/version and current graph bundle |
| grounded locomotion | composes intent before exactly-one terrain integration |
| gravity/jump | policy-specific and ordered before motion |
| animation | reads final support and resolved support distance |
| engagement/melee/cast | world-X targets and derived AABB/origins remain intentional |
| Hashash teleport | authority-owned clearance, support/path reset, safe fallback |
| Unoco hover/combat | local terrain reference and final resolved transform |
| enemy death/cull | final support/AABB and authored cull plane; camera cull unchanged |
| spawn service | exact placement result, stable diagnostics, unchanged RNG order |
| track manager | Phase 3 harness bundle only; production legacy disposition |
| player target prediction | previous support or authoritative sloped landing |
| snapshots/debug | Core-authored support/path/contact only; no Flame authority |
| replay validator | normal legacy construction unchanged in Phase 3 |
| ballistic projectiles | explicit later-phase rejection in terrain harness |

Frozen high-level tick order:

1. publish any complete terrain/index/surface/graph replacement
2. refresh timers, locks, and ability phases
3. AI reads prior-tick support against the current bundle version
4. movement, jump, mobility/teleport, knockback, and gravity compose intent
5. one dispatcher integrates every terrain-owned dynamic actor exactly once
6. final support/contact/resolved motion becomes authoritative
7. downstream combat, death/cull, animation, snapshots, and debug read their
   documented state

- [ ] Add an ordering test that fails if AI reads current-tick support before
      motion.
- [ ] Add an ordering test that fails if animation reads stale support.
- [ ] Add an exactly-once audit with multiple enemy policies.

## 23) Deterministic Signatures And Scenario Matrix

Add reviewed versioned signatures:

- `nav-surfaces-v1`: ordered nodes, IDs, endpoints, adjacency, and chain IDs
- `nav-graphs-v1`: per-profile eligibility, CSR edges, kinds, points, ticks,
  and quantized costs
- `enemy-terrain-run-v1`: fixed-tick transforms, support/path state, contacts,
  teleports, spawns, diagnostics, combat commits, and deaths

Signature rules:

- [ ] serialize canonical integers/IDs/enums, never formatted platform doubles
- [ ] include explicit schema/version prefixes
- [ ] generate in Core only
- [ ] compare against committed reviewed SHA-256 files
- [ ] prove fresh object, input permutation, and fresh-process parity
- [ ] never update a golden merely because a test failed

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

- [ ] shared surface extraction/index build
- [ ] Grojib graph build
- [ ] Hashash graph build
- [ ] both grounded-enemy graphs from one shared surface set
- [ ] combined terrain index plus both graph variants
- [ ] supported Grojib and Hashash terrain solves
- [ ] jump/drop multi-contact solves
- [ ] Unoco blocked-flight solve and clearance steering
- [ ] steady-state navigator update with and without repath
- [ ] trajectory prediction
- [ ] complete representative mixed-enemy Core tick
- [ ] controlled streamed-bundle replacement

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

- [ ] enemy candidates p95 `<=24`, p99 `<=64`
- [ ] dynamic actor solve p95 `<=75 us`, p99 `<=150 us`
- [ ] one enemy-profile graph build p95 `<=5 ms`, p99 `<=10 ms`
- [ ] both grounded-enemy graphs p95 `<=20 ms`, p99 `<=35 ms`
- [ ] combined index + graph rebuild p95 `<=35 ms`, p99 `<=50 ms`
- [ ] representative whole-Core slope tick p99 `<=2 ms`
- [ ] representative whole-Core hard gate p99 `<4 ms`
- [ ] terrain adds `<=25%` versus the matched flat fixture
- [ ] zero steady-state terrain-query/controller allocations per dynamic actor
- [ ] zero steady-state query-buffer growth after warmup
- [ ] bounded controller, predictor, steering, A*, and graph-build loops
- [ ] no candidate/path/edge truncation

Every report records revision, dirty flag, OS/runtime, fixture/signatures,
warmup, sample count, p50/p95/p99/max, candidates, graph nodes/edges, rebuild
counts, allocation evidence, buffer growth, diagnostics, and per-gate result.

## 25) Implementation Findings

Record findings that affect later implementation without silently changing
accepted gameplay.

| Finding | Resolution | Later-phase impact |
| --- | --- | --- |
| _None yet_ | Record during implementation. | Review before Phase 4 planning. |

## 26) Documentation

During implementation:

- [ ] create or update a focused TDD for sloped navigation, enemy motion,
      placement authority, versioning, and deterministic ordering
- [ ] update `docs/tdd/terrain_capsule_controller.md` if controller/profile
      contracts change
- [ ] update `docs/tdd/runner_core_simulation_contract.md` if tick ordering or
      construction boundaries change
- [ ] update the enemy/navigation/spawn GDD documents for delivered
      player-facing behavior
- [ ] keep proposed Phase 4-7 work in `docs/building/**`
- [ ] update the closest `AGENTS.md` only if working rules/boundaries drift
- [ ] update the master slopes plan status and immediate next step
- [ ] keep public APIs self-usable with units, ownership, version, mutation,
      and failure behavior documented

Do not document the Phase 3 harness as normal production authority.

## 27) Validation Ledger

| Date/revision | Command/evidence | Environment | Result |
| --- | --- | --- | --- |
| _Pending_ | Baseline and implementation evidence | _Pending_ | _Pending_ |

Planned final validation:

```powershell
dart analyze
dart analyze packages/runner_core

Push-Location packages/runner_core
dart test
dart test test/navigation/sloped_graph_golden_test.dart
dart test test/enemies/terrain_enemy_harness_test.dart
dart run tool/benchmark_slopes_phase3.dart --strict
Pop-Location

flutter test test/core

Push-Location services/replay_validator
dart analyze
dart test test
Pop-Location
```

The exact focused test paths may be split during implementation, but the
complete package/root/validator suites and benchmark evidence are mandatory.

## 28) Exit Gate

- [ ] All four current enemies have explicit tested terrain policies.
- [ ] Shared sloped surface nodes/identity/order are deterministic.
- [ ] Grojib and Hashash graph variants differ only by eligibility/edges.
- [ ] Collision and navigation agree on slopes, step/snap, one-way, clearance,
      jump, and drop feasibility.
- [ ] Grounded enemy locomotion and animation use final support correctly.
- [ ] Hashash teleport/deferred spawn cannot embed or silently relocate.
- [ ] Unoco cannot tunnel, ground on one-way terrain, phase, or teleport around
      blockers.
- [ ] Derf placement enforces slope, width, same-support, and clearance rules.
- [ ] Spawn/item placement and RNG ordering pass.
- [ ] Geometry/graph bundle replacement is atomic and invalidates stale state.
- [ ] All `SG-E01` through `SG-E15` scenarios pass.
- [ ] All reviewed signatures match across fresh instances/processes.
- [ ] Allocation, capacity, and performance gates pass.
- [ ] Normal production and replay construction remain legacy and unchanged.
- [ ] Full Core, root gameplay, and replay-validator validation passes.
- [ ] Documentation describes implemented Phase 3 behavior accurately.
- [ ] Implementation findings are reviewed before Phase 4 work begins.

Only after every exit item is checked and evidence is accepted may Phase 4
polygon authoring/schema implementation planning begin.
