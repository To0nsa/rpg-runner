# Sloped Navigation And Enemy Terrain Foundation

## Status And Authority Boundary

The Phase 3 navigation foundation and shared placement-query slice are
implemented in `runner_core`:

- every current enemy has a catalog-owned capsule and explicit terrain policy
- canonical polygon edges compile into one actor-neutral sloped surface set
- the set has a deterministic, caller-buffered spatial index
- one actor-neutral query resolves standability, exact support, and complete
  upright-capsule clearance
- Hashash teleport and deferred edge spawns consume that query through the
  selected world-motion authority

This is not a production terrain cutover. `GameCore(...)` and replay validation
still construct `LegacyWorldMotionAuthority`. The Phase 3 terrain harness now
dispatches the player and migrated enemies through explicit catalog policies;
unsupported dynamic bodies and ballistic projectiles fail without a rectangle
fallback. The new graph/navigation/placement systems remain isolated inputs for
the remaining Phase 3 integration work.

The existing horizontal `WalkSurface` graph remains the normal production
navigation representation until the isolated Phase 3 graph is complete. New
polygon navigation work must use `TerrainNavigationSurface`; it must not add a
second polygon-node identity or pack `TerrainEdgeId` into an integer.

## Baseline Compatibility Evidence

The implementation baseline was clean revision `9eea5cfd` on Windows
`10.0.26200` X64, Dart `3.11.5`, and Flutter `3.41.7`.

| Baseline behavior | Executable evidence |
| --- | --- |
| Grojib/Hashash pursuit, stand-off, jump, drop, obstruction, locks, and attacks | `test/core/ground_enemy_*`, `enemy_engagement_system_test.dart`, and `hashash_strike_timing_test.dart` |
| Unoco deterministic hover/steering and combat | `flying_enemy_steering_test.dart` and `enemy_attacks_test.dart` |
| Hashash deferred spawn and teleport/ambush timing | `track_streamer_hashash_deferred_spawn_test.dart`, `hashash_spawn_intro_test.dart`, and `hashash_teleport_ambush_test.dart` |
| Derf obstacle-top placement, facing, cast origin, and target | `track_streamer_spawn_placement_test.dart` and `target_point_impact_system_test.dart` |
| Graph ordering, A* tie behavior, and graph-version invalidation | `surface_graph_builder_test.dart`, `surface_pathfinder_test.dart`, and `surface_navigator_graph_version_test.dart` |
| Normal/replay construction remains legacy | `game_core.dart` selects legacy when no harness geometry is supplied; `validator_worker.dart` invokes that normal constructor |

The characterized legacy Hashash ambush has no terrain-placement failure path: after
teleport-out it unconditionally writes the predicted player point plus
`(+36, -36)`, queues the strike, and schedules the authored recovery/cooldown.
The terrain harness now adds primary/mirrored/cancel validation while preserving
those timings; the legacy authority still accepts the primary point exactly.
The deferred-spawn test also fixes Unoco/Hashash marker ordering and counts for
the same stream.

Before Phase 3 edits, package analysis and `143` package tests, `432` root Core
tests, replay-validator analysis, and `75` validator tests passed. The
`runner_core` lock SHA-256 was
`f8fd13d568779220b791a8f7fcc4e8ef62d5a5078fab50e11170bf3c6491722b`;
the root lock SHA-256 was
`960e659dc06af51944155d2f8495e505ce91e7d060d9e011a1b90494223f925a`.

## Enemy Contact Profiles

`EnemyCatalog.terrainContactProfile(EnemyId)` is exhaustive. Adding an enum
case without assigning a terrain policy is therefore a compile-time failure.
The returned objects are initialized once and reuse the same collider constants
as `EnemyArchetype`, preventing separate capsule and combat-bound tuning.

Capsules retain the Phase 0 derivation:

```text
radius = collider.halfX
verticalHalfSegment = collider.halfY - radius
offset = collider.offset
```

| Enemy | Motion role | Capsule `(radius, half spine, offset)` | Support policy |
| --- | --- | --- | --- |
| Grojib | grounded dynamic | `(19.5, 5.5, -4/18)` | `45°`, 4 px step/snap, solid + one-way, ceiling ignore |
| Hashash | grounded dynamic | `(14, 7.5, -1/7)` | `60°`, 4 px step/snap, solid + one-way, ceiling ignore |
| Unoco Demon | flying dynamic | `(8.125, 0.5, 0/2)` | solids on every side, no gravity/support/helpers, ignores one-way |
| Derf | kinematic placement | `(11.5, 12.75, 0/7)` | clearance-only, solid support up to `15°`, no per-tick integration |

Grounded enemy authored speed means constant distance along a support. The
profile records that semantic explicitly. A later intent producer converts
speed to the support tangent before the one terrain solve; the neutral
`TerrainTraversalProfile` speed points are not Éloïse's incline curve.

Unoco's traversal object can classify blocking solid normals, but
`EnemyTerrainMotionKind.flyingDynamic` is the final authority that forbids
grounded state. Derf's traversal object exists for common clearance and slope
eligibility queries, not dynamic motion.

Facing mirrors only capsule `offsetX`. Radius, vertical spine, `offsetY`, and
derived AABB extents remain unchanged. Combat, pickup, broad-phase, culling,
and rendering continue to consume the catalog AABB.

## Canonical Shared Surface Set

`TerrainSurfaceExtractor` consumes immutable `TerrainGeometry` and keeps every
exposed edge satisfying both conditions:

```text
edge.dxTicks > 0
edge.outwardNormal.yTicks < 0
```

Canonical clockwise Y-down polygons make such edges left-to-right and
upward-facing. Walls, undersides, downward ceiling faces, and compiler-removed
internal boundaries cannot enter the set. Slopes above an actor limit remain
present; `TerrainNavigationSurface.isEligibleFor(profile)` applies actor
filtering later.

Each node owns:

- exact `TerrainEdgeId`
- integer endpoints, tangent, outward normal, and nearest-tick length
- deterministic rational `yAtXTicks(x)` with half-tick ties away from zero
- solid/one-way mode and semantic/material metadata
- reciprocal previous/next IDs and endpoint ledge/smooth/corner classes
- a chain ID equal to the canonically lowest edge ID in its component

An exact endpoint connects only when there is one reciprocal candidate with
the same collision mode, surface kind, and material. Incompatible or ambiguous
joins remain ledges. This prevents arbitrary graph continuity at touching
branches and preserves authored material boundaries.

`TerrainSurfaceSet.geometryVersion` is exactly the source geometry version.
`indexOfId` is only a version-local optimization: consumers must store the
exact edge ID and invalidate every cached index when the bundle version
changes.

`nav-surfaces-v1` records serialize canonical integer fields, exact IDs,
metadata, adjacency, endpoint classes, and chain IDs. The SHA-256 signature
deliberately excludes the publication version, so rebuilding identical geometry
at a new version produces the same content signature.

## Surface Spatial Index

`TerrainSurfaceSpatialIndex` indexes the complete closed bounds of every
sloped segment using the accepted 64-world-unit Phase 1 grid. Exact cell
boundaries enter both adjacent lanes, including negative coordinates.

Queries:

1. visit all closed cells intersecting the requested tick-space AABB
2. deduplicate bucket entries with generation stamps
3. insertion-sort canonical surface indices without comparator allocation
4. compact by exact segment bounds
5. return every retained candidate without truncation

The caller owns `TerrainSurfaceQueryBuffer`. It exposes candidate count, cells
visited, raw bucket references, retained unique candidates, and resize count.
Using `createQueryBuffer()` prevents storage growth for the immutable index;
reusing a buffer with another surface count performs an explicit resize rather
than silently truncating.

## Standability And Placement Query

`TerrainPlacementQuery` validates that its geometry, full-edge index, and
surface index share one geometry version and canonical edge identity. It owns
reusable query buffers and the capsule/segment kernel, while every request
supplies actor-specific shape and policy. A resolved horizontal capsule offset
is explicit; callers mirror a facing-dependent authored offset before the
query. The result reports a typed validity, geometry version, body/capsule
centers, support point and edge ID, tangent/normal/slope, optional exact-edge
clamp, blocker ID, and candidate diagnostics.

Grounded support lookup is deterministic:

1. query complete surface bounds at the requested capsule X and Y interval
2. keep surfaces eligible for the supplied traversal profile, including
   one-way policy and the inclusive normal threshold
3. choose the smallest world Y, then the canonical `TerrainEdgeId`
4. apply the requested support-width rule to that chosen edge
5. derive support Y with exact rational `yAtXTicks(x)`
6. validate the complete capsule against all compiled terrain edges

The query does not silently try a lower surface when the chosen eligible
surface is too narrow or obstructed. Supplying an intended edge makes support
identity explicit. Optional clamping is legal only with that exact ID and is
bounded by that one finite edge, so it cannot cross a ledge, chain break, chunk
seam, or source boundary.

Runtime foothold and grounded-spawn support are separate contracts.
`TerrainSupportRequirement.groundedEnemyRuntime()` retains the legacy one-third
capsule-diameter fraction as the exact rational `1/3`; custom graph profiles may
carry another explicit rational. The minimum tick width rounds upward. A
grounded spawn uses `TerrainSupportRequirement.groundedSpawn()` and requires
the full horizontal capsule diameter on one source edge.

The supported capsule center is normal-aware rather than `surfaceY - flat
halfHeight`. It starts from the exact finite surface Y and the capsule's radius
offset from the sloped line. At an exact compatible transition, a face-local
position can intersect the neighboring face, so the resolver raises the
capsule only enough to clear other profile-eligible surfaces in the same
canonical chain. It retains the deterministic chosen edge and projected
support point. Incompatible or over-profile neighbors remain ordinary blockers.

Clearance uses `CapsuleSegmentKernel` against the full edge index, including
walls, ceilings, undersides, adjacent polygons, and finite endpoints. The
selected support may touch. Other contacts may touch within the frozen contact
epsilon but may not penetrate beyond it. One-way fronts obey the traversal
profile; backsides are nonblocking, and a clearance-only flying/teleport
request can explicitly ignore all one-way edges. No relocation occurs in a
clearance-only request.

Requests may carry an expected geometry version. A mismatch returns
`geometryVersionMismatch` before lookup, and `canCommit` rejects any retained
valid result whose version differs from the query's immutable geometry.

## Shared Nodes And Profile Surface Graphs

`TerrainSurfaceGraph` references a `TerrainSurfaceSet`; it does not copy or
replace its nodes. Each profile view stores a same-length eligibility vector,
CSR offsets, and directed edges. `TerrainSurfaceGraphPublication` sorts profile
keys and requires every view to reference the exact same surface-set instance.
This makes accidental node deletion, reordering, or separately rebuilt indices
a publication error rather than a later pathfinding mismatch.

The graph edge enum contains `walk`, `jump`, and `drop`, and the builder emits
all three. Edge points are body centers in physics ticks and retain destination
index, signed commit direction, travel ticks, measured distance, and integer
cost.

Ordinary walk edges are generated in both directions for:

- reciprocal compatible `previousId`/`nextId` joins, including exact chunk
  seams and slope-angle changes
- ledge-to-ledge endpoint pairs whose horizontal difference is within the
  frozen contact tolerance and whose vertical change is within that profile's
  upward step or downward snap limit

Both source and destination must be profile-eligible. The builder places the
direction-resolved complete capsule just inside each finite support through
`TerrainPlacementQuery`; its existing exact-edge clamp handles short-but-valid
runtime footholds. A small step also validates the raised transition midpoint
with the same clearance query. Failure produces no edge and never searches for
an unrelated fallback. Coplanar incompatible ledges, over-limit slopes,
5-pixel transitions, narrow supports, and blocked transitions therefore remain
disconnected.

`TerrainSurfaceGraphBuildProfile` is a build input, not new catalog authority.
Callers copy the current catalog capsule ticks and traversal object, resolve the
authored horizontal offset by walk direction, preserve the runtime rational
support fraction, provide the authored constant surface-distance speed in
physics ticks per second, and attach the existing
`JumpReachabilityTemplate`. Construction rejects mismatched capsule dimensions,
support fraction, fixed timestep, or ceiling/side collision masks. The graph
signature includes the quantized jump speed, gravity, air speed, air-tick cap,
and collision masks so two materially different graph profiles cannot share a
`nav-graphs-v1` digest.

## Jump And Drop Construction

Jump takeoff points use the same finite-edge standable interval and
normal-aware placement authority as walk edges. The legacy sample topology is
preserved after integer quantization: a narrow interval contributes its two
endpoints and midpoint; a wider interval is sampled from its minimum at no more
than 64 world units per step and always includes its maximum. Duplicate physics
ticks are removed. Partial-support intervals are bounded to the finite authored
segment because `yAtXTicks` deliberately has no extrapolation authority beyond
a ledge.

For each signed horizontal direction and candidate destination, the builder
scans the existing semi-implicit-Euler jump samples in tick order. At each
descending tick it intersects:

- the profile's horizontal reach
- the destination's exact standable interval
- the destination capsule-center heights crossed during that tick

The height interval is solved against the sloped segment with integer binary
search. Endpoint/midpoint candidates are then resolved through
`TerrainPlacementQuery`; no local body-height reconstruction can bypass normal,
slope, one-way, or clearance policy. Jumps keep the legacy reachability model
of linearly interpolating horizontal displacement to a reachable landing while
using the template's authoritative vertical samples.

Every trajectory tick continuously sweeps the complete upright capsule against
the canonical full-edge index. `TerrainContactPolicy` supplies solid/one-way
sidedness, slope support classification, and the profile's ceiling/left/right
wall masks. Equal-time contacts are handled as a manifold: any enabled wall or
ceiling rejects the arc; support candidates prefer the smallest world Y and
then canonical edge ID. A jump succeeds only when the first accepted support
is its eligible intended destination and an exact placement at the impact X is
valid. This blocks walls, finite endpoints, ceilings when enabled, sloped
undersides, narrow/ineligible supports, and intermediate terrain without
discrete-tick tunneling.

Drop edges are considered only at endpoints classified as true ledges. Their
takeoff uses the profile's standable boundary plus the frozen contact epsilon.
Drop flight starts with zero vertical speed, applies the same fixed-tick gravity
integration, and preserves the signed commit direction at authored air speed,
matching the existing enemy navigator's in-flight intent. Contacts constrained
back to the departed source face are ignored while leaving it; every other
blocking contact remains authoritative. The first accepted support must map to
an eligible navigation surface and pass exact destination placement, otherwise
no drop edge is emitted.

Navigation cost uses canonical integer microseconds:

```text
walk cost = round(surface.lengthTicks * 1,000,000 / speedTicksPerSecond)
walk travel ticks = ceil(surface.lengthTicks * simulationHz / speedTicksPerSecond)
jump/drop cost = round(travelTicks * 1,000,000 / simulationHz)
```

Walk distance is the source surface length. This matches the accepted constant
distance-along-surface runtime interpretation and makes steeper surfaces cost
their actual length rather than horizontal projection. CSR rows sort first by
canonical destination edge ID and then by kind/points/direction. The
`nav-graphs-v1` records include profile integer inputs, node eligibility, CSR
offsets, edge kind/points/ticks/distance/cost, and exact surface IDs. Publication
version remains a runtime invalidation field rather than content-signature
input, matching `nav-surfaces-v1`.

## Terrain A* And Runtime Navigator

`TerrainSurfacePathfinder` is the polygon-terrain A* implementation. It reads
the immutable `TerrainSurfaceGraph` CSR rows directly and writes global graph
edge indices into a caller-owned path list. Node-sized cost, predecessor,
open-set, and reconstruction storage is retained across searches and isolated
with generation stamps. Search is bounded by the configured expansion count.

All comparison and cost math is integer-only. The graph's signed commit
direction provides the optional first-pass horizontal preference; failure of
that restricted pass permits one unrestricted retry. Priority order is lower
`f`, lower `g`, then canonical `TerrainEdgeId`. Equal-cost predecessor updates
use canonical predecessor and edge order. Airborne transitions add
distance-along-source approach cost, every transition uses its signed graph
cost, and the final transition adds distance-along-destination cost to the
exact target body X. The midpoint horizontal-time heuristic divides by the
faster of authored surface and air speed, so it remains admissible when those
profile values differ.

`TerrainSurfaceNavigator` is the isolated actor-neutral consumer. It is not
wired into normal `GameCore` construction in Phase 3. Each entity update gets:

- one published bundle version and matching graph/placement query
- entity and target body centers/capsules in physics ticks
- each actor's traversal and support-width policy
- grounded state plus prior-tick support ID and geometry version
- explicit nav, move, and stun lock state

Valid prior support maps directly from persistent edge ID to the graph's
version-local node index. Missing, stale, absent, or profile-ineligible evidence
uses `TerrainPlacementQuery`; no separate bottom-band locator exists. An
airborne target retains its last validated target support until it lands or the
bundle changes. This supplies the player-target side of grounded enemy pursuit
without reading support that will only be produced after the current tick's
motion.

`TerrainSurfaceNavigatorState` owns persistent support IDs and cached node/path
indices together. Any bundle-version mismatch clears current, last-ground, and
target support; their cached indices; repath cooldown; path buffer/cursor; and
active edge before locks or other AI logic run. A cached node or global edge
index is never carried across that boundary.

Direct pursuit bypasses A* only when source and target share a chain and every
intermediate node is eligible with an emitted walk edge. This avoids repathing
at exact slope seams without treating chain identity alone as traversability.
The pursuit X is clamped to the enemy capsule's standable interval on the
target support, including player targets near a finite ledge. Other routes use
preferred-direction A* followed by the unrestricted retry.
Approach accepts being at or beyond takeoff in commit direction, preventing
overshoot reversal. Once active, jump/drop direction remains committed and the
edge completes only when grounded prior support equals its exact destination
ID; an unrelated landing does not advance the cursor.

When no plan exists, the desired body X is clamped to the shared query's exact
standable interval on current or last-known eligible support. It is an intent,
never a relocation, and cannot cross a finite ledge. Nav and stun locks hold
state after mandatory version invalidation. A move lock may observe refreshed
support/path state but suppresses movement/jump and cannot consume a pending
one-shot takeoff.

## Sloped Trajectory Prediction

`TerrainTrajectoryPredictor` is the isolated actor/profile-bound replacement
for the legacy horizontal-band predictor. It is not wired into normal
`GameCore` construction during Phase 3. Callers supply the current body center,
capsule, velocity, resolved gravity, terminal fall speed, and a caller-owned
`TerrainLandingPrediction` output.

Each predicted tick follows Core's motion order: apply gravity to vertical
velocity, clamp velocity to the actor's terminal magnitude, then quantize the
horizontal and vertical fixed-tick displacement. Every moving tick queries
collision, so a wall or ceiling reached during ascent still invalidates the
prediction. Only descending support is accepted as a landing; separating faces
and one-way backside crossings remain ignored by the shared contact policy.

Every descending tick queries the spatial index with the swept bounds of the
complete upright capsule and classifies continuous segment contacts through the
shared capsule kernel and `TerrainContactPolicy`. The first contact time is
authoritative. An equal-time wall or ceiling rejects the prediction; eligible
support ties choose the highest world surface and then canonical
`TerrainEdgeId`. The first support must pass `TerrainPlacementQuery` with the
actor's runtime foothold and clearance policy. An invalid, narrow, or blocked
first support terminates the prediction instead of looking through it for a
lower surface.

After that first contact is accepted, the predictor replays the complete
landing tick through `TerrainCapsuleController`. This consumes any remaining
post-impact motion along a slope, so the published body/capsule centers,
support point, tangent, normal, ID, and geometry version agree with runtime
motion rather than stopping at the raw time-of-impact point. A final shared
placement query validates the controller's support and clearance. The output
also records the first landing tick and its within-tick contact fraction.

The predictor owns and reuses its spatial-query, sweep, policy-decision, and
controller scratch. Its output remains caller-owned, and diagnostics expose
ticks, candidates, cells, and query-buffer growth for later performance gates.

## Multi-Body World-Motion Authority

`TerrainMultiBodyWorldMotionAuthority` is the single motion owner in the Phase
3 harness. Normal `GameCore` and replay construction still select
`LegacyWorldMotionAuthority`. The terrain selection is immutable at Core
construction and is not authored content, replay data, or a runtime toggle.

Before mutating tick state, `prepareTick` builds a reusable ascending-entity-ID
body view and preflights the whole view. Known enemies with no terrain stores
receive their catalog capsule and traversal profile. Grojib, Hashash, and Unoco
also receive contact and resolved-motion stores; Derf receives only the two
kinematic placement stores. Any partial topology, wrong profile/capsule,
unknown enabled dynamic body, or enabled ballistic projectile fails before
support state or transforms are changed.

Preparation then captures prior support for every dynamic terrain actor before
AI and clears stale support/path state on a geometry-version mismatch. Disabled
or runtime-kinematic actors publish no support. Unoco always starts support-free.
AI, locomotion, jump, mobility/teleport state, external velocity, and gravity
compose the transform velocity before `step` performs the one terrain solve.
Generic teleport/velocity/motion-stop hooks clear retained state without
granting another integration path.

One controller, traversal cache, and mutable result scratch is retained for
each of the player, Grojib, Hashash, and Unoco profiles. `step` visits enabled
dynamic actors in the same ascending entity order. Grojib and Hashash may
publish eligible support; Unoco is constrained by solid contacts but never
publishes grounding; Derf and other kinematic bodies are not integrated. Final
transforms are written before terrain contact, legacy collision compatibility,
and resolved-motion values. Only accepted positive player X progression is
returned to the run-distance accumulator.

Death-animation bodies remain dynamic but normally contribute zero requested
motion, while `fallingUntilGround` bodies continue through gravity and terrain
contact. Unsupported bodies never fall back to `CollisionSystem` inside the
terrain harness.

## Grounded Enemy Terrain Locomotion

Grojib and Hashash now consume prepared terrain support in the Phase 3 harness.
`WorldSupportView` is the staged read boundary for navigation, locomotion,
animation, render snapshots, and ground-impact death: a terrain-owned actor reads
`TerrainContactStateStore`, while a legacy actor continues to read
`CollisionStore`. This matters because `prepareTick` intentionally resets the
legacy compatibility flags after retaining authoritative prior support and
before AI executes.

Navigation and engagement continue to author world-X targets. Chase offsets,
melee stand-off, arrival slowing, engagement state speed, status speed, move
locks, acceleration, deceleration, and reversal retain their existing order.
Only the final grounded velocity interpretation changes:

1. project the prior final velocity onto the support tangent oriented toward
   positive world X, producing one signed scalar surface speed
2. apply the existing desired-speed and acceleration/deceleration rules to that
   scalar
3. emit the resolved scalar along the prior support tangent in the intended
   horizontal direction
4. keep gravity as the authority's separate displacement contribution
5. solve one `groundedSurface` request through the actor's catalog profile

Consequently, authored speed is distance per second along the surface for both
actors. Grojib receives no incline multiplier through `45°`; Hashash receives
none through `60°`. Their profiles retain the accepted 4-pixel step and snap
helpers, one-way top-side support, solid side blocking, and ceiling-ignore
policy. The controller removes velocity only along an entering contact normal;
it does not invent a bounce, slope impulse, or rectangle fallback.

An accepted enemy jump is an explicit mode boundary. Locomotion clears retained
terrain and compatibility support before writing the existing world-X
jump-edge snap/commit velocity and world-up launch velocity. The authority
therefore emits a `worldSpace` request for that tick with no grounded snap.
Airborne jump/drop commit and off-course recovery remain the existing
navigation/locomotion rules. Landing publishes final support before animation,
combat, or death-state consumers observe the actor.

`ResolvedMotionStore.supportedTravelTicks` drives terrain-owned enemy walk/run
phase with the same bounded fixed-point playback rule used by the player.
Support recovery, step and snap correction, and vertical helper legs do not
advance that phase. Sprites and combat geometry remain upright; facing,
world-space melee/cast origins, and stand-off offsets are unchanged.

`EnemyDeathStateSystem` now uses the same support facade. A
`groundImpactThenDeath` enemy killed in the air continues through terrain
motion until final eligible support is published, or begins its death animation
at the existing deterministic maximum-fall timeout. Legacy construction and
replay validation retain their old collision path and outcomes.

## Hashash Teleport And Deferred Spawn Placement

Hashash ambush no longer writes an unchecked transform in the terrain harness.
`WorldMotionAuthority` owns a small transactional placement lifecycle:

1. `beginBodyTeleport` retains the last valid body position and capsule-facing
   state, then clears support, legacy grounded compatibility, resolved motion,
   and every retained surface path reference
2. `tryCommitBodyTeleport` validates an exact body point with the Hashash
   capsule and traversal profile; one-way faces are ignored because the
   ambush is clearance-only and airborne
3. only a valid, current-geometry result writes position/facing and
   reinitializes last-valid body/capsule history
4. `cancelBodyTeleport` restores the retained safe transform when neither
   candidate is valid, while leaving support and paths invalidated for the
   next ordinary terrain solve

The ambush system always evaluates the predicted-player offsets in this order:
`(+36, -36)`, then `(-36, -36)`. Candidate construction, clearance, and
fallback consume no RNG. A strike, active ambush phase, and control lock are
created only after a successful commit. Failure queues no strike, returns the
teleport state to idle, and applies the same
`ambush duration + authored cooldown` gate as success.

`SpawnEnemyRequest.source` distinguishes ordinary authored markers from a
deferred Hashash edge request without changing marker rolls or iteration.
`GameCore` asks the selected authority to resolve only the deferred request at
its exact X and requested support height. Terrain authority uses
the requested body-X/Y point to select one canonical intended edge before
calling `TerrainPlacementQuery.resolveGrounded`. That second query uses the
real facing-resolved capsule offset, Hashash profile, full capsule-diameter
support, complete clearance, no same-surface clamp, and the current geometry
version. The intended support is terminal: absent, steep, narrow, or blocked
support rejects the request rather than searching another edge or height.
Rejection consumes the pending request without relocation or replacement RNG.
The approved body-center Y is passed to `SpawnService`; legacy authority derives
the historical flat-surface body Y.

## Remaining Phase 3 Integration

This foundation does not yet provide:

- Unoco clearance steering, Derf placement, or remaining terrain-backed spawn
  placement
- atomic geometry/index/surface/graph publication

Those layers must consume this one set and index. They may cache a node index
only alongside the exact geometry/graph version and must clear it before use on
any mismatch.

## Validation

Focused foundation validation:

```powershell
Push-Location packages/runner_core
dart analyze
dart test test/enemies/enemy_terrain_profile_test.dart
dart test test/navigation/terrain_surface_extractor_test.dart
dart test test/navigation/terrain_surface_spatial_index_test.dart
dart test test/navigation/terrain_placement_query_test.dart
dart test test/navigation/terrain_surface_graph_builder_test.dart
dart test test/navigation/terrain_surface_navigator_test.dart
dart test test/navigation/terrain_trajectory_predictor_test.dart
dart test test/ecs/world_motion_authority_test.dart
dart test test/ecs/ground_enemy_terrain_locomotion_test.dart
dart test test/ecs/enemy_navigation_terrain_support_test.dart
dart test test/ecs/hashash_terrain_placement_test.dart
Pop-Location
```

The tests cover exact enemy capsule/AABB parity, facing offsets, explicit role
flags, slope limits, invalid role mixtures, flat/sloped/one-way extraction,
cross-chunk seams, material ledges, winding/input permutations, negative
coordinates, version-independent signatures, brute-force index parity,
closed-cell boundaries, 1,280/5,120-surface capacity, and zero query-buffer
growth across 10,000 warm queries. Placement tests cover all main-chain
transitions/endpoints, `45°`/between/`60°`/over-profile slopes, narrow support,
full-width spawn versus runtime partial support, highest/canonical selection,
same-source clamping, headroom, adjacent walls, one-way fronts/backsides,
finite partial-support bounds, finite endpoints, and retained-result version
invalidation.

Surface-graph tests prove shared node identity/order, differing Grojib/Hashash
eligibility, exact `45°`/between-limit/`60°` behavior, compatible slope and
cross-chunk joins, 4-versus-5-pixel transitions, blocked/narrow/steep rejection,
flat/slope and slope/slope jump directions, endpoint/narrow/limit landings,
convex/concave joins, one-way landings, wall/ceiling/sloped-underside and
intermediate obstruction, committed ledge drops onto slopes, no-tunneling thin
supports, canonical equal-time ordering, integer walk/airborne costs,
publication assertions, and repeated CSR/signature parity across input
permutations. Pathfinder/navigator tests cover mixed walk/jump/drop routes,
canonical ties and direction preference in both horizontal directions,
multi-slope direct pursuit, target seam/chain/airborne transitions, retained
support versus fallback lookup, approach overshoot, jump/drop commitment,
wrong and correct landing completion, lock behavior, complete bundle
invalidation, and finite eligible-surface fallback.
Trajectory-predictor tests cover vertical/diagonal flat and sloped landings,
high-speed thin supports, uphill/downhill jump arcs, first-surface and canonical
seam selection, ascending and one-way rejection, wall/sloped-ceiling blocking,
narrow and obstructed clearance, reusable buffers, and exact agreement with a
controller replay of the landing tick.
World-motion tests cover zero/one/many enemy dispatch, exact once-only
integration, sparse-set reorder parity, preflight failure before partial
motion, geometry support/path invalidation, disabled/kinematic/death/fall
policy, player-distance isolation, Unoco support-free solid contact, ballistic
rejection, and unchanged locked player support.
Grounded-enemy integration tests cover constant Grojib `45°` and Hashash
`60°` surface distance, both directions, scalar acceleration/reversal/stop,
status and engagement multipliers, move/stun locks, 4-pixel step/snap, seams,
one-way support, blocking walls, world-space jump launch, resolved-distance
animation, prepared support handoff to navigation, and final-support/timeout
death behavior. Existing ground-enemy Core tests retain jump/drop commitment,
off-course recovery, melee facing/stand-off, ceiling-ignore, culling, and combat
origin coverage.
Hashash placement tests cover primary and mirrored success, airborne clearance
without support, wall/ceiling/slope/concave cancellation, retained safe-state
restoration, normal cooldown, unchanged RNG, input-order parity, eligible
slope spawning, and terminal rejection of invalid highest support. Existing
legacy ambush and deferred-stream tests remain unchanged apart from explicit
spawn-source provenance evidence.
