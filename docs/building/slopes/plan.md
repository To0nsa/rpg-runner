# Sloped Terrain And Capsule Traversal High-Level Plan

- Date: July 18, 2026
- Status: Phases 0-3 accepted; Phase 4 implementation is in progress
- Phase 0 tracker:
  [phase0-implementation-checklist.md](phase0-implementation-checklist.md)
- Phase 0 evidence:
  [phase0-consumer-inventory.md](phase0-consumer-inventory.md)
- Phase 0 technical defaults:
  [phase0-technical-contracts.md](phase0-technical-contracts.md)
- Phase 0 gameplay decisions:
  [phase0-gameplay-decisions.md](phase0-gameplay-decisions.md)
- Phase 0 golden/performance specification:
  [phase0-golden-performance-spec.md](phase0-golden-performance-spec.md)
- Phase 1 implementation checklist:
  [phase1-implementation-checklist.md](phase1-implementation-checklist.md)
- Phase 2 implementation checklist:
  [phase2-implementation-checklist.md](phase2-implementation-checklist.md)
- Phase 3 implementation checklist:
  [phase3-implementation-checklist.md](phase3-implementation-checklist.md)
- Phase 4 implementation checklist:
  [phase4-implementation-checklist.md](phase4-implementation-checklist.md)

Related plans and contracts:

- [Chunk Creator High-Level Plan](../editor/chunkCreator/plan.md)
- [Multi-Rect Prefab Collision Plan](../editor/chunkCreator/prefab-multi-rect-collision-plan.md)
- [Controls GDD](../../gdd/01_controls.md)
- [Combat System Design](../../gdd/combat/combat_system_design.md)
- [Replay Validator Worker TDD](../../tdd/replay_validator_worker.md)
- [Sloped Navigation And Enemy Terrain Foundation](../../tdd/sloped_navigation_and_enemy_terrain.md)
- [Enemy Terrain Traversal GDD](../../gdd/enemy_terrain_traversal.md)

## 1) Mission

Replace the current flat, axis-aligned static-world collision model with a
deterministic terrain pipeline that supports authored slopes and clean traversal
for the player and enemies.

The target pipeline is:

```text
Editor-authored polygons
  -> deterministic geometry generation
  -> canonical world-space terrain edges
  -> static spatial index
  -> capsule world-contact solver
  -> shared support/surface data
  -> player movement + enemy navigation + spawning + rendering
```

This is a cross-cutting gameplay migration. It is not complete when the player
can stand on one ramp. It is complete only when authoring, streaming, collision,
player movement, enemy locomotion, navigation/pathfinding, spawn placement,
rendering, replay validation, and content migration all agree on the same
geometry and traversal rules.

## 2) Target Outcome

After this plan is implemented:

- chunk and prefab collision is authored as simple polygons rather than
  collections of axis-aligned rectangles
- generated runtime collision uses canonical directed edges/segments derived
  from those polygons
- player and world-colliding enemy bodies use upright capsule colliders for
  static-world contact
- AABBs remain available as derived broad-phase, combat-overlap, culling, and
  renderer-debug bounds where an AABB is still the correct representation
- player and ground enemies traverse allowed slopes without jitter, corner
  snagging, unwanted airborne ticks, or discontinuities at chunk seams
- steep surfaces behave as walls according to explicit movement profiles
- enemy surface graphs, jump/drop reachability, trajectory prediction, and
  spawn placement understand sloped surfaces
- ground materials, foreground masking, and debug overlays render the same
  terrain geometry used by Core
- streamed chunk geometry rebuilds collision and navigation deterministically
- live clients and the replay validator run the same physics implementation and
  are compatibility-gated during rollout
- the rectangle/static-horizontal-surface runtime authority is removed after
  migrated content and parity coverage are complete

## 3) Current Baseline

### 3.1 Authoring and generation

Current editor/runtime authoring assumes:

- `PrefabColliderDef` is an axis-aligned rectangle
- prefabs may contain multiple rectangle colliders
- `LevelChunkDef.groundProfile` supports only `flat`
- gaps are separate horizontal ranges
- `tool/generate_chunk_runtime_data.dart` exports rectangle collision as
  `SolidRel`
- generated chunk data contains `solids`, `groundGaps`, spawn markers, and
  visual sprites

The existing multi-rect work remains a useful, implemented baseline because it
already provides:

- deterministic list ordering
- anchor, scale, and flip transforms
- schema/store/plugin ownership
- validation-gated export
- chunk-relative to world-space generation
- stable chunk and prefab identities

The polygon migration should evolve those seams instead of creating a second
authoring/export system.

### 3.2 Core static geometry and collision

Current Core behavior assumes:

- `StaticSolid` is an AABB with top/bottom/left/right collision flags
- `StaticGroundSegment` is horizontal with one constant `topY`
- `StaticWorldGeometryIndex` maintains face-specific lists queried primarily by
  X range
- `CollisionSystem` integrates velocity, resolves vertical faces, then resolves
  horizontal faces
- `ColliderAabbStore` is used by physics and by many non-physics systems
- fixed-point pilot quantization exists in selected movement/collision paths

That axis-separated solver cannot be extended into robust arbitrary slopes by
adding a `yAt(x)` special case. Slope traversal requires contact normals,
continuous movement along surfaces, vertex/seam handling, and persistent
support state.

### 3.3 Navigation and enemies

Current navigation assumes:

- a `WalkSurface` is a horizontal X interval at one `yTop`
- top faces are extracted from AABB solids
- adjacent coplanar spans may merge
- jump/drop reachability samples constant-height surfaces
- jump obstruction tests query AABB ceilings and walls
- runtime navigation locates an entity from its bottom Y and AABB half-width
- per-enemy graphs share identical surface IDs/order while edge sets may vary

Current enemy behavior also depends on flat/AABB geometry through:

- `EnemyNavigationSystem`
- `GroundEnemyLocomotionSystem`
- `SurfaceNavigator`
- `SurfaceGraphBuilder`
- `SurfaceSpatialIndex`
- trajectory prediction
- spawn-on-ground/highest-surface/obstacle-top placement
- teleport/ambush placement
- grounded death-state handling

### 3.4 Streaming, spawning, and rendering

Current chunk streaming rebuilds flattened lists of:

- static solids
- horizontal ground segments
- ground gaps
- visual sprites

`TrackManager` then rebuilds collision indexes, renderer snapshots, and
navigation graphs from those lists.

Current ground rendering consumes horizontal surface bands. Static collision
debug rendering consumes rectangles. Both must change before sloped collision
can have reliable visual parity.

### 3.5 Replay and backend authority

The app and replay validator both execute `runner_core`. A physics migration
therefore changes replay outcomes even if the replay command encoding does not
change.

Existing `RunTicket` compatibility fields provide rollout gates:

- `gameCompatVersion`
- `rulesetVersion` for Competitive/Weekly
- `scoreVersion` and `ghostVersion` where their contracts are affected

The geometry itself must not be copied into replay blobs. The ticket, compatible
Core build, level identity, and deterministic generated content remain the
authoritative reconstruction inputs.

## 4) Architecture Decisions

These decisions define the intended end state. Phase 0 may refine names and
tuning values, but changing an ownership rule requires updating this plan.

### 4.1 Core remains authoritative

- terrain contact, grounding, slope limits, and navigation truth remain in
  `packages/runner_core`
- Flame consumes immutable snapshots and events only
- the editor authors and validates data but does not become gameplay authority
- the replay validator uses the same Core geometry and movement implementation
  as the live client

### 4.2 Author simple polygons; run collision on edges

- source authoring uses snapped simple polygons with stable identities
- runtime collision uses compiled directed boundary edges, not per-tick polygon
  triangulation or raster collision
- curved/spline editor tools may be considered later only if they compile to a
  deterministic linear segment approximation
- polygon holes are not a baseline primitive; disconnected terrain or gaps use
  multiple polygons and empty space
- arbitrary dynamic, rotating, or deformable terrain is outside this plan

### 4.3 Use an upright kinematic capsule controller

- player and world-colliding enemies use an upright capsule for static-world
  contact
- actors do not rotate to match terrain
- the controller uses deterministic sweep, move, contact, slide, and support
  operations rather than general rigid-body dynamics
- current actor AABB outer bounds provide the initial capsule migration:
  `radius = halfX` and `halfSegmentY = max(0, halfY - radius)`, followed by
  character/enemy-specific review
- projectiles and non-actor bodies retain explicit shape policies; they do not
  silently inherit actor capsule behavior

### 4.4 Keep derived AABBs where appropriate

Replacing actor world contact with capsules does not require replacing every
AABB use.

Derived or separately authored AABBs may remain responsible for:

- broad-phase spatial indexing
- combat and trigger overlap candidates
- pickups and restoration collection
- culling
- render/debug bounds
- temporary hitboxes

The final APIs must distinguish authoritative world-contact shape from
broad-phase/combat bounds so neither is accidentally used as the other.

### 4.5 One geometry source feeds all consumers

Collision, support lookup, navigation extraction, spawn placement, ground
rendering, and debug visualization must derive from the same compiled terrain
identity and endpoints.

No consumer may reconstruct a separate approximate flat representation from
polygon bounds.

### 4.6 Direct production cutover

The new geometry kernel and controller may be built and tested before they are
production authority. The final content migration must then:

1. regenerate all authored content into the new contract
2. switch all runtime consumers together
3. remove the legacy `StaticSolid`/horizontal-ground authority and temporary
   adapters
4. update docs and generated fixtures in the same change

Do not leave a long-lived per-level or per-entity switch between two physics
authorities.

## 5) Product And Tuning Decisions To Freeze In Phase 0

Accepted player-facing input:

- Éloïse's maximum walkable slope is 60 degrees from horizontal, inclusive;
  steeper surfaces are non-walkable for her
- Éloïse's target horizontal speed varies continuously with signed slope:
  uphill multipliers are 100/95/85/75% and downhill multipliers are
  100/105/110/115% at 0/30/45/60 degrees, with deterministic interpolation
  between those control points
- automatic small step-up is enabled for Éloïse during ordinary grounded
  locomotion with a maximum height of 4 world pixels
- downward ground snap preserves existing ordinary-locomotion support by at
  most 4 world pixels and never pulls an already-airborne player onto terrain
- terrain-angle transitions never add an artificial launch impulse; convex
  peaks snap only within 4 pixels and wider departures retain existing velocity
- sloped one-way platforms pass Éloïse from below and support her from above;
  endpoints are not side walls and no drop-through input is added initially
- ordinary jumps always launch world-up; support angle adds no horizontal
  impulse
- grounded dash/roll movement follows eligible terrain tangents while Éloïse's
  art remains upright; airborne ability behavior remains world-space
- grounded dash/roll speed preserves authored distance along the terrain
  surface and does not use the ordinary running slope-speed curve
- grounded dash/roll may use the same 4-pixel step-up and downward-snap helpers
  as ordinary locomotion; airborne-started abilities use neither helper
- Grojib's maximum walkable slope is 45 degrees, inclusive; steeper edges are
  walls and are excluded from its ordinary walk graph
- Grojib uses 4-pixel step-up and downward snap during ordinary grounded
  pursuit, with navigation and collision sharing the same feasibility query
- Grojib moves at constant distance-along-surface speed; navigation walk cost
  uses the same surface distance and authored locomotion speed
- Hashash's maximum walkable slope is 60 degrees, inclusive; steeper edges are
  walls and are excluded from its ordinary walk graph
- Hashash uses 4-pixel step-up and downward snap during ordinary grounded
  pursuit, with navigation and collision sharing the same feasibility query
- Hashash moves at constant distance-along-surface speed; its navigation walk
  cost uses the same surface distance and authored locomotion speed
- Hashash ambush teleport tries the current right/above point, then its mirrored
  left/above point; both require capsule clearance, and failure cancels safely
  with the normal cooldown
- Unoco Demon's existing randomized 60-180-pixel hover band references local
  terrain beneath its capsule footprint, retaining its last valid reference
  where no terrain lies below
- solid terrain blocks Unoco Demon's swept capsule from every side; it ignores
  one-way platforms and uses bounded deterministic clearance steering without
  phasing
- Derf may spawn only on support up to 15 degrees with full stationary-capsule
  clearance and remains visually upright
- Derf requires at least 32 world pixels of horizontal span on its intended
  obstacle-top support; its marker may clamp only within that support, and an
  invalid placement is skipped instead of falling back to unrelated terrain
- every remaining grounded actor spawn requires profile-eligible support over
  its full capsule width plus complete clearance; marker correction stays on
  the intended support, optional invalid spawns skip, and an invalid required
  player start fails level validation
- Unoco Demon requires complete capsule clearance at its intended flying spawn
  and skips a blocked marker
- collectible/restoration placement uses player-walkable support up to
  60 degrees, a 20-pixel minimum horizontal span, exact surface height, and
  full AABB clearance; deterministic retry exhaustion produces no item
- final post-solver support state controls grounded/air animation selection;
  supported slope traversal does not trigger airborne frames, and all actor
  sprites remain upright with horizontal facing
- looping grounded walk/run playback follows final resolved support distance
  with a continuous 0.75x-1.50x authored-rate clamp; all action, airborne, hit,
  spawn, stun, and death timing remains unscaled
- future player ground-target abilities resolve an authored-range aim endpoint
  through a Core-owned world-down query to player-walkable terrain; preview
  displays that exact result, line-of-sight applies, and an invalid commit has
  no resource or cooldown cost
- no current player ability uses ground targeting; current projectile/melee
  previews and Derf's predicted-player-center explosion remain unchanged

All Phase 0 player-facing decisions, fixtures, budgets, implementation
contracts, and validation evidence are accepted.

The recommended baseline is conservative:

- apply the accepted continuous signed-slope speed curve while retaining
  world-X movement, distance, score, and camera semantics
- jump world-up
- use slope following, downward ground snap, and bounded automatic small
  step-up
- treat surfaces above the configured angle as walls
- preserve current one-way behavior without adding drop-through input

These accepted rules must be published in the GDD when the player traversal
implementation is delivered and accepted; until then they remain proposed
behavior owned by these building documents.

## 6) Authoring And Geometry Contracts

### 6.1 Authoring model

Introduce stable polygon types shared by prefab and chunk authoring concepts,
without duplicating serialization or validation rules.

A collision polygon needs, at minimum:

- stable `shapeId`
- ordered local-space vertices
- collision mode: solid or one-way
- semantic role: terrain, obstacle, or platform where authoring UX needs it
- optional material/surface key only when gameplay or rendering consumes it

Chunk ground should move from `flat + gaps` to one or more terrain polygons.
Prefab obstacle/platform collision should move from rectangle lists to polygon
lists.

Existing rectangles and flat ground/gaps require an explicit schema migration:

- each rectangle becomes a four-vertex polygon
- flat ground plus gaps becomes one or more filled terrain polygons
- stable prefab/chunk identity and revision rules remain intact
- migration output is canonical and test-covered
- current content that cannot migrate without overlapping/ambiguous polygons is
  blocked and reauthored before cutover

### 6.2 Polygon validation

Export-blocking validation must cover:

- schema version and migration support
- stable, unique shape identity
- at least three unique vertices
- finite, snapped coordinates
- no zero-length edges
- non-zero signed area
- canonical winding
- no self-intersection
- bounds against prefab source/chunk limits
- deterministic transform results for anchor, uniform scale, `flipX`, and
  `flipY`
- no unsupported placement rotation
- no ambiguous overlap between solid polygons
- legal one-way orientation and exposed face selection
- legal chunk-boundary endpoints
- configurable maximum edge/polygon counts
- no transformed edge shorter than the numeric tolerance/skin contract

Baseline authored polygons should be non-overlapping. Exact shared boundaries
are allowed and compiled as adjacency. If overlapping shapes are later required,
they need a deterministic offline union policy rather than runtime overlap
guessing.

### 6.3 Deterministic geometry compiler

The generator/compiler must:

1. normalize vertex order and winding
2. remove duplicate and safely removable collinear vertices
3. apply placement anchor, scale, and flips deterministically
4. transform chunk-local vertices into runtime chunk-relative data
5. emit directed edges with outward normals and stable IDs
6. classify solid, one-way, and potentially walkable edges
7. record previous/next adjacency needed for vertex handling
8. remove exact internal/shared boundaries
9. preserve seam metadata for neighboring chunk stitching
10. emit render polygons or equivalent immutable geometry data
11. use canonical ordering and numeric formatting

Stable runtime identity must include enough source lineage to diagnose content:

- chunk identity/index
- placed prefab identity/index when applicable
- local polygon identity/index
- local edge index

Runtime tie-breaks must use this stable identity, not collection hash order.

### 6.4 Chunk seam contract

Chunk seams are a first-class invariant:

- adjacent terrain endpoints must agree exactly after snapping
- continuous terrain must not expose opposing vertical boundary edges
- gaps and ledges must remain intentionally exposed
- stitching must work when chunks spawn, cull, and rebuild
- edge identity/order must remain deterministic across rebuilds
- navigation chains may cross a stitched seam without creating a false
  jump/drop transition
- rendering must not show cracks or texture-phase resets at the seam

The editor validator should diagnose invalid entry/exit terrain continuity
without reintroducing speculative generic socket metadata. Add only the minimum
seam data required by actual runtime stitching.

## 7) Runtime Static Geometry

### 7.1 Core types

The final Core model should have explicit concepts equivalent to:

- `StaticTerrainPolygon`
- `StaticTerrainEdge`
- `StaticTerrainEdgeId`
- `StaticTerrainGeometry`
- `StaticTerrainIndex`
- terrain collision flags/material
- edge adjacency/vertex metadata

Exact names are deferred, but types must make these distinctions clear:

- authored/generated polygon ownership
- runtime collision edge
- renderable filled region
- walkable surface classification
- spatial query index

### 7.2 Static spatial index

The current face-specific X index must be replaced with a 2D index that can
query edge candidates from:

- capsule swept AABB
- support/ground probe
- navigation clearance sweep
- projectile terrain sweep
- spawn clearance query
- renderer/debug visible bounds when useful

Requirements:

- deterministic candidate ordering after query
- reusable buffers and no avoidable per-actor/per-tick allocations
- stable deduplication when an edge occupies multiple cells
- bounded cell/edge counts
- rebuild only when streamed geometry changes
- explicit behavior for edges exactly on cell boundaries

Reuse existing Core grid primitives where they fit; do not create an unrelated
spatial-index framework solely for slopes.

### 7.3 Snapshots

Replace rectangle/horizontal-band-only snapshots with immutable geometry that
can support:

- terrain polygon fill
- collision edge debug lines
- one-way/walkable classification
- stable chunk/source identity for diagnostics
- ground material and foreground clipping

Snapshots remain renderer-facing read models. They must not become a second
collision representation used by gameplay.

## 8) Capsule Collision And Movement

### 8.1 Capsule shape

An upright capsule is defined by:

- center offset from the entity transform
- radius
- vertical half-segment length

Its derived AABB is:

```text
halfWidth  = radius
halfHeight = halfSegmentY + radius
```

Actor definitions must validate positive radius, non-negative half-segment,
finite offsets, and compatibility with render/attack-origin assumptions.

### 8.2 Pure geometry kernel

Build the collision math as pure, independently tested Core utilities before
ECS integration:

- point/segment projection
- closest points between capsule spine and terrain edge
- squared-distance and penetration evaluation
- moving capsule versus static segment time of impact
- endpoint/corner contact
- support cast/probe
- point-in-polygon or equivalent recovery test for invalid starting overlap
- contact normal and tangent calculation
- swept-AABB construction

The kernel must define numeric tolerances, inclusive/exclusive boundaries, and
degenerate-input behavior centrally.

### 8.3 Kinematic move-and-slide solver

Per body and fixed tick:

1. read prior support state
2. produce requested displacement from movement, mobility, and gravity
3. query terrain edges across the swept capsule AABB
4. find the earliest valid contact
5. move to contact while preserving skin separation
6. classify ground, wall, ceiling, or one-way contact from the normal
7. remove only the displacement/velocity component entering the surface
8. continue with remaining displacement for a fixed maximum iteration count
9. resolve bounded initial penetration if necessary
10. perform support probing/ground snap
11. write final transform, velocity, and contact/support state
12. apply fixed-point/quantization policy at documented points

Simultaneous or near-simultaneous contacts must use explicit deterministic
tie-breaks: contact time, contact classification where required, then stable
edge ID.

### 8.4 Vertex and seam behavior

The solver must distinguish:

- a smooth/connected walkable vertex
- a convex exposed corner
- a concave valley
- an intentional ledge
- an internal/shared edge
- a chunk seam

Adjacency or ghost-vertex information must prevent the capsule from snagging on
internal vertices or receiving a false wall normal while traversing a valid
slope chain.

Do not average unrelated contact normals. Normal smoothing is allowed only
under an explicit adjacency and walkability rule.

### 8.5 Persistent support state

`CollisionStateStore` or a focused support store must expose enough
authoritative state for movement, jumping, animation, and navigation:

- grounded
- support edge/surface ID
- support point
- support normal
- support tangent
- ceiling/left/right or generalized wall contacts needed by existing systems
- contact tick/validity where required

Grounded must mean supported by a valid walkable contact, not merely overlapping
an upward-facing broad-phase bound.

### 8.6 Existing movement behavior audit

The cutover must explicitly verify:

- player acceleration/deceleration
- coyote time and jump buffering
- air jumps
- dash/roll/mobility locks and impacts
- maximum velocity clamping
- ignored-ceiling policies
- ballistic projectile world collision and despawn flags
- grounded/air animation transitions
- death falling-until-ground behavior
- gap/fall death detection
- camera vertical follow
- distance and score accumulation
- caster/projectile origin derivation
- ground-targeted ability placement and terrain aim-preview queries
- facing-dependent collider offsets
- initial spawn grounding

Any system that reads `groundTopY`, `halfX/halfY`, or four directional collision
flags must be classified as:

- still correct
- changed to capsule/support data
- changed to terrain surface queries
- intentionally independent of world collision

### 8.7 System ordering

`GameCore.stepOneTick()` ordering remains a gameplay contract. The migration
must freeze and document:

- track streaming/stitching before navigation and collision queries
- whether navigation consumes prior-tick or current-tick support state
- jump execution clearing support before ground snap can run
- movement/mobility and gravity producing one requested displacement
- capsule resolution publishing final support before death, camera, animation,
  projectile-world-contact, and snapshot consumers need it
- broad-phase rebuild timing after authoritative transforms settle

If collision responsibilities split into actor and projectile systems, their
order and ownership must be explicit. No body may be integrated twice in one
tick.

## 9) Player Traversal

Player acceptance includes more than standing on a ramp:

- move uphill and downhill in both directions
- start, stop, and reverse on a slope
- remain supported through flat-to-slope and slope-to-flat transitions
- cross convex peaks and concave valleys according to the locked feel rules
- jump from a slope without being immediately snapped back
- land on a slope at different horizontal/vertical speeds
- dash/roll uphill, downhill, into steep walls, and across seams
- collide correctly with slope undersides and ceilings
- pass upward through and land on one-way sloped platforms
- leave intentional ledges and fall into pits
- preserve coyote/buffer behavior at sloped ledges
- avoid tunneling at maximum configured movement and mobility speeds
- place ground-targeted abilities and their renderer aim previews on the same
  authoritative sloped surface query
- preserve camera, distance, score, combat-origin, and animation semantics unless
  their GDD rules explicitly change

The first production pass should avoid implicit "helpful" behavior that changes
gameplay balance. Step-up, ledge forgiveness, slope boosting, and downhill
launching require named tuning and tests if included.

## 10) Enemies, Navigation, And Pathfinding

### 10.1 Enemy collision policy inventory

Every current enemy archetype must declare one world-contact policy:

- grounded capsule controller
- airborne/flying capsule collision
- kinematic/teleporting placement with capsule-clearance validation
- trigger-only/no static-world contact

No enemy may retain AABB world contact accidentally because it was omitted from
the migration.

Review at minimum:

- ordinary ground enemies
- enemies with different collider sizes and jump profiles
- flying enemies
- teleport/ambush enemies
- enemies in active mobility or control-lock states
- dying/falling enemies

### 10.2 Surface representation

Replace constant-height `WalkSurface` assumptions with immutable walkable edge
chains or an equivalent representation that supports:

- segment endpoints
- `yAt(x)` for X-monotonic walkable segments
- tangent and normal
- arc length or traversal-cost length
- stable surface/chain identity
- connected edge adjacency
- ledge endpoints
- one-way classification

Geometric surface extraction must remain identical across enemy profiles so
shared surface IDs/order and spatial indexes stay valid. Per-enemy graph
building then filters traversal edges using that enemy's:

- capsule radius/height
- maximum walkable slope
- required support policy
- ceiling/wall collision policy
- jump arc and air-control rules

### 10.3 Walk edges

Navigation must treat connected allowed slopes as ordinary walking, including
across chunk seams.

Walk transitions require:

- compatible edge adjacency
- capsule clearance
- slope within the enemy profile
- no step/height discontinuity beyond the locked policy
- deterministic cost and direction

The same-chain/direct-chase shortcut must follow chain geometry rather than
assuming a shared constant `yTop`.

### 10.4 Jump and drop edges

Update graph construction so:

- takeoff Y comes from the source segment at takeoff X
- landing Y comes from the destination segment at landing X
- standability uses capsule support, not AABB full-footprint assumptions
- jump obstruction uses capsule-versus-terrain sweeps
- landing surface normals satisfy the enemy's slope limit
- drop edges leave the true ledge and find the first valid capsule landing
- convex peaks, narrow surfaces, one-way platforms, ceilings, and walls are
  handled explicitly
- tie-breaks remain stable by surface/edge identity

### 10.5 Runtime navigation and locomotion

Update:

- current/target surface location
- path invalidation on streamed graph rebuild
- takeoff approach
- in-flight commit direction
- landing completion
- chase offsets
- stuck/invalid-plan fallback
- ground-enemy slope-following velocity
- jump velocity snapping for active graph edges

An enemy must not oscillate because target X lies on a different segment of the
same continuous slope chain.

### 10.6 Trajectory prediction and target reasoning

Trajectory and landing prediction must intersect the predicted capsule path
with sloped surfaces rather than horizontal bands.

Review all AI/combat decisions that derive:

- player bottom Y
- enemy bottom Y
- same-surface status
- vertical separation
- melee stand-off position
- reachable landing point
- teleport destination

Combat overlap may continue using derived AABBs where intended, but terrain
placement and path feasibility must use capsule/edge geometry.

## 11) Streaming, Spawning, Pickups, And Death Bounds

### 11.1 Track streaming

`ChunkPattern`, `chunk_builder.dart`, `TrackStreamer`, and `TrackManager` must
move together:

- generated chunk patterns carry polygon/edge geometry
- chunk build applies world placement and stable chunk identity
- active chunks flatten or stitch deterministic edge/polygon lists
- culling removes geometry and adjacency cleanly
- geometry changes rebuild the edge index, snapshots, and all per-enemy graphs
- RNG selection and spawn-roll ordering remain unchanged unless explicitly
  versioned

### 11.2 Spawn placement

Replace rectangle-top and constant-ground-Y lookup with terrain queries that:

- find the highest eligible walkable point at X
- evaluate exact surface Y and normal
- reject slopes outside the spawned actor's profile
- ensure the full capsule has clearance
- use stable tie-breaks when multiple surfaces overlap at X
- avoid placing actors on narrow peaks or inside adjacent terrain

Apply this to:

- player initial spawn
- enemy markers
- `ground`, `highestSurfaceAtX`, and `obstacleTop` placement modes
- deferred edge/teleport spawns
- collectible spawning
- restoration-item spawning
- any future checkpoint/respawn placement

Placement-mode names may be retained if their semantics remain clear, but their
implementation must no longer depend on AABB top faces.

### 11.3 Pits and fall death

The current global flat-ground reference cannot remain the sole fall-death
authority.

Define a level/world death-bound contract independent of terrain surface height,
for example:

- authored absolute kill plane
- camera-relative fall margin
- level-defined lower world bound

Pit rendering, absence of terrain, falling behavior, and run-end detection must
agree without reconstructing legacy `groundGaps`.

## 12) Rendering And Debugging

### 12.1 Terrain rendering

Replace horizontal ground-band layout with geometry-driven fill that:

- clips or meshes the visible authored terrain polygons
- keeps texture coordinates world-anchored to avoid sliding
- preserves pixel-art filtering and pixel snapping
- handles slopes, gaps, and concave terrain
- avoids cracks at chunk seams
- aligns the visible terrain boundary with authoritative Core edges

If rendering requires triangulation, it is render data derived from the same
canonical polygon, not gameplay collision authority.

### 12.2 Parallax foreground and masks

Update ground-dependent rendering consumers:

- foreground ground-band clipping
- temporary floor masks
- parallax bottom alignment
- any effect positioned from the visible ground top

Visual-only parallax remains non-authoritative, but its masks must follow the
authoritative terrain outline.

### 12.3 Debug tooling

Add toggles/overlays for:

- source terrain polygons
- compiled collision edges
- edge normals and one-way direction
- stitched/internal edge classification
- player/enemy capsules
- derived broad-phase AABBs
- current support edge, point, normal, and tangent
- navigation chains, graph edges, takeoff points, and landing points
- spatial-index cells/candidate counts when profiling

Debug visuals must consume snapshots/debug contracts from Core and must not
perform their own collision classification.

### 12.4 Editor parity

Editor scene views must:

- create/select/move/add/remove polygon vertices
- preview winding, solid fill, one-way direction, and invalid intersections
- reuse shared pan/zoom/input controls
- preserve undo/redo and plugin/store ownership
- show chunk-seam diagnostics
- preview compiled collision edges
- eventually run traversal validation using the same Core geometry rules

Load/edit/save/export must round-trip polygons deterministically without raw
JSON or Dart edits.

## 13) Determinism, Replay Compatibility, And Rollout

### 13.1 Numeric determinism

The geometry/compiler/solver contracts must define:

- authoring coordinate grid and runtime units
- fixed-point or quantization boundaries
- contact and geometry epsilons
- maximum solver iterations
- candidate sort and tie-break rules
- normal/tangent calculation policy
- rounding after transforms
- behavior for equal-time contacts
- stable ordering after chunk stitching and graph rebuild

Prefer squared-distance comparisons where normalization is unnecessary.
Quantize authoritative output at documented points. Do not use unordered
iteration, wall-clock time, or platform physics engines as gameplay authority.

### 13.2 Replay impact

Physics behavior changes alter:

- player positions and grounded ticks
- enemy paths and combat timing
- deaths, score, distance, drops, and rewards
- ghost trajectories

Required rollout review:

- bump `gameCompatVersion`
- bump Competitive/Weekly `rulesetVersion`
- determine whether `scoreVersion` changes because ranking semantics or score
  interpretation changed
- bump `ghostVersion` if old ghost artifacts cannot play safely
- provision new compatible boards instead of mutating historical board identity
- ensure live client and replay-validator deployments use matching Core/content
- stop issuance for the old compatibility version, drain or expire outstanding
  sessions, and clear the validation queue before removing old Core behavior
- preserve historical audit data even when old replays are no longer runnable

Do not accept old tickets with new physics merely because replay decoding still
succeeds.

### 13.3 Golden determinism

Add golden command streams and geometry fixtures that compare:

- two fresh Core instances
- live recorder playback
- replay-validator execution
- repeated graph rebuilds for the same active chunks
- generated content before and after a no-op regeneration

Golden signatures should include enough state to detect support, position,
enemy path, score, and end-reason drift.

## 14) Performance And Capacity

Phase 0 must measure the current representative baseline and set explicit
budgets for:

- polygons/edges per prefab
- polygons/edges per chunk
- active streamed edges
- static-index rebuild duration
- per-player collision query candidates
- per-enemy collision query candidates
- per-enemy graph build duration
- total graph rebuild duration across enemy profiles
- steady-state collision allocations
- editor polygon interaction responsiveness

Implementation rules:

- reuse query/contact buffers
- avoid per-tick geometry object creation
- precompute immutable edge data
- rebuild static indexes/graphs only when geometry changes
- bound solver iterations and penetration recovery
- expose debug counters before optimizing blindly

Performance shortcuts may not weaken deterministic ordering, collision
correctness, or navigation/collision parity.

## 15) Delivery Phases

Each phase has a hard exit gate. A later phase may prepare test fixtures, but
production authority does not cut over until the migration phase.

### Phase 0 - Contract Freeze And Baseline Inventory

Execution checklist:
[phase0-implementation-checklist.md](phase0-implementation-checklist.md)

Scope:

- freeze player-facing slope rules listed in Section 5
- inventory every flat-ground/AABB/static-solid consumer
- define authoring polygon, runtime edge, capsule, support, and navigation
  contracts
- define numeric tolerance, identity, ordering, and quantization policies
- define replay/version rollout
- create representative geometry and replay golden fixtures
- measure performance baselines and set budgets
- write the Phase 1 implementation checklist after Phase 0 contracts are
  accepted

Gate:

- no unresolved ownership or behavior decision blocks collision math
- all affected systems have an explicit migration disposition
- accepted target behavior is complete in `docs/building/slopes/**`, with
  implementation-owned TDD/GDD publication triggers recorded
- golden fixtures cover the first playable slope scenario

### Phase 1 - Pure Geometry Kernel And Static Edge Index

Execution checklist:
[phase1-implementation-checklist.md](phase1-implementation-checklist.md)

Scope:

- implement polygon/edge Core types
- implement validation-independent runtime geometry checks
- implement deterministic edge compilation helpers needed in Core
- implement capsule/segment geometry primitives
- implement the static 2D edge index
- add exhaustive geometry, degenerate-case, ordering, and allocation tests

Gate:

- pure geometry tests pass without Flutter/Flame
- edge queries and contact ordering are deterministic
- numeric policy is centralized and documented
- no gameplay system uses the new kernel as partial production authority yet

### Phase 2 - Capsule Controller And Player Traversal Harness

Execution checklist:
[phase2-implementation-checklist.md](phase2-implementation-checklist.md)

Scope:

- add authoritative world-contact capsule storage
- preserve/derive AABB bounds for existing non-world consumers
- implement move-and-slide, one-way, support, slope limit, and ground snap
- integrate player behavior against hand-authored Core test terrain
- update collision/support snapshots and debug data needed for verification
- audit jump, mobility, death, camera, score, projectile, and animation behavior

Gate:

- player passes the traversal matrix at normal and maximum configured speeds
- flat-terrain behavior remains intentionally equivalent or documented
- no jitter, snagging, tunneling, or false grounded/airborne transitions remain
- fixed-point/determinism golden tests pass

### Phase 3 - Sloped Surface Graphs And Enemy Cutover Readiness

Execution checklist:
[phase3-implementation-checklist.md](phase3-implementation-checklist.md)

Scope:

- generalize surface extraction to walkable edge chains
- update spatial lookup, standability, pathfinding, jump/drop construction, and
  trajectory prediction
- integrate grounded enemy capsule locomotion
- classify flying, teleporting, kinematic, and dying enemy policies
- update spawn/teleport placement and capsule-clearance checks
- update per-enemy graph profiles while preserving shared surface identity

Gate:

- every current enemy archetype has an explicit tested policy
- representative ground enemies pursue across slopes, seams, jumps, and drops
- flying/teleport enemies cannot spawn or move inside terrain
- navigation and collision agree on walkable/blocked surfaces
- graph rebuilds remain deterministic and within budget

### Phase 4 - Authoring Schema, Generator, And Editor Polygon Tools

Detailed tracker:
[phase4-implementation-checklist.md](phase4-implementation-checklist.md)

Scope:

- add versioned polygon schemas and migrations
- mechanically migrate current rectangle prefabs and flat ground/gaps without
  changing their occupied collision area
- update stores, validators, plugins, scene state, and pending diffs
- add polygon editing and seam diagnostics
- update generator output and dry-run drift validation
- generate canonical runtime polygon/edge data and deterministic render
  triangles
- add authoring/runtime parity fixtures

Gate:

- non-developer polygon authoring works end to end
- no-op round trips and generation are deterministic
- invalid polygons/seams block export with actionable diagnostics
- all committed content migrates or has an explicit blocking reauthor list

### Phase 5 - Streaming, Rendering, And Full Runtime Integration

Scope:

- replace streamed solids/ground segments/gaps with terrain geometry
- stitch/cull chunk edges and rebuild indexes/graphs
- replace ground, foreground mask, and collision-debug rendering
- update initial/entity/item spawn placement and fall-death bounds
- run full game integration against migrated representative levels

Gate:

- collision, navigation, spawning, and rendering use one geometry source
- no visible or physical chunk seam remains
- slopes render with pixel-stable materials and correct parallax masks
- representative full runs stay within performance budgets

### Phase 6 - Content Migration And Direct Authority Cutover

Scope:

- complete the reviewed slope-content reauthoring pass and regenerate all
  level/prefab content for production
- run all player/enemy/content acceptance scenarios
- switch Core production authority to edges/capsules
- remove `StaticSolid`, horizontal-ground, legacy gap, and temporary adapter
  paths that are no longer required
- remove stale tests/snapshots/debug APIs and replace them with final contracts
- update TDD, GDD, README, and AGENTS guidance

Gate:

- no production runtime path uses legacy rectangle terrain authority
- no current content depends on legacy generation
- all relevant analyzer, test, generator, and determinism suites pass
- documentation describes implemented behavior rather than migration intent

### Phase 7 - Compatibility Rollout And Production Verification

Scope:

- deploy matching client, backend configuration, generated content, and replay
  validator
- provision new versioned boards
- drain/expire incompatible outstanding sessions before validator cutover
- verify replay acceptance, rewards, leaderboards, and ghosts
- monitor collision/nav performance and invalid-run reasons
- execute rollback plan if deterministic parity fails

Gate:

- live and validator results match golden and staging runs
- no incompatible ticket can be issued or validated
- leaderboard/ghost history remains correctly partitioned by version
- production metrics remain within agreed budgets

## 16) Required Test Matrix

### Geometry and compiler

- clockwise/counterclockwise normalization
- duplicate, collinear, zero-length, and zero-area input
- self-intersection and polygon overlap rejection
- scale and X/Y flip transforms around prefab anchors
- exact shared-edge removal
- chunk-seam stitching and intentional ledge preservation
- stable IDs/order after no-op generation and streaming rebuild
- spatial-index cell-boundary and candidate-deduplication cases

### Capsule solver

- flat floor parity
- uphill/downhill in both directions across multiple allowed angles
- exactly-at-limit and just-over-limit slopes
- flat-to-slope, slope-to-flat, convex peak, and concave valley
- wall at the top/bottom of a slope
- ceiling and sloped underside
- one-way flat/sloped platforms from above and below
- jump from and land on slopes
- descending support snap
- ledge departure and coyote time
- maximum-speed run, dash, knockback, and ballistic projectile cases
- starting penetration and multiple simultaneous contacts
- narrow peaks and capsule-radius endpoint contacts
- mirrored actor offsets/facing

### Navigation and enemies

- surface lookup at every slope transition
- same-chain chase across multiple segments
- per-enemy maximum slope differences with shared surface IDs
- jump/drop takeoff and landing on slopes
- capsule-clearance obstruction by wall/ceiling/underside
- target moving across a seam or becoming airborne
- trajectory prediction onto sloped terrain
- chase offsets without stacking/oscillation
- flying/teleport placement near slopes and concave terrain
- grounded enemy death/fall handling
- graph-version invalidation during chunk spawn/cull

### Streaming, spawn, and content

- deterministic chunk selection remains unchanged
- neighboring chunks stitch in every allowed ordering
- culling/re-adding geometry yields identical identity/order
- ground/highest-surface/obstacle-top spawn modes
- player, enemy, collectible, and restoration capsule clearance
- intentional gaps and world death bounds
- all authored chunks generate and play without legacy fallback

### Rendering and editor

- polygon editing, undo/redo, selection, validation, and deterministic save
- runtime edge preview matches generated data
- material fill and foreground mask follow slopes/gaps
- no seam crack or texture-phase reset
- debug edge/capsule/support/nav overlays match Core snapshots
- render interpolation does not visibly detach actors from slopes

### Determinism, replay, and backend

- identical seed/commands/content produce identical snapshots and end result
- live Core and validator Core agree
- old compatibility tickets are rejected after cutover
- new boards carry new compatibility/ruleset identity
- accepted rewards, leaderboard order, and ghost publication remain idempotent
- representative long replay remains deterministic and within validation budget

## 17) Validation Commands

The implementation checklist for each phase should select the smallest relevant
subset, but the final cutover requires at least:

```text
dart analyze
flutter test
dart analyze packages/run_protocol
dart test packages/run_protocol/test
dart analyze services/replay_validator
dart test services/replay_validator/test
cd tools/editor && dart analyze
cd tools/editor && flutter test
dart run tool/generate_chunk_runtime_data.dart --dry-run
corepack pnpm --dir functions build
corepack pnpm --dir functions test
```

Also run focused Core collision/navigation/streaming tests and a generator drift
check after regenerating committed runtime content.

## 18) Documentation Deliverables

Before implementation cutover:

- create a focused TDD for static terrain geometry, capsule collision, support,
  solver ordering, determinism, and streaming ownership
- update navigation architecture documentation for sloped surface chains and
  per-enemy graph generation
- update `docs/gdd/01_controls.md` with player-facing slope behavior
- update `docs/gdd/combat/combat_system_design.md` for collider/support/nav
  stores and system ordering
- update editor README and chunk/prefab authoring docs
- update replay-validator compatibility/rollout docs
- update relevant AGENTS files if layer responsibilities or validation commands
  change
- archive this plan and phase checklists only after all authority cutover and
  production gates are complete

## 19) Major Risks And Mitigations

### Collision math is correct but traversal still feels bad

Mitigation:

- freeze feel rules first
- test transitions, support persistence, snap, and mobility rather than only
  intersection math
- require playable acceptance at multiple speeds/angles

### Capsules snag at vertices or chunk seams

Mitigation:

- compile adjacency and shared-edge information
- distinguish smooth vertices from exposed corners
- include cross-chunk seam fixtures before content migration

### Navigation and collision disagree

Mitigation:

- derive both from canonical edges
- reuse capsule clearance queries
- keep geometric surface identity shared across enemy profiles
- test every emitted graph edge through the runtime controller

### Numeric changes break replay determinism

Mitigation:

- centralize tolerances and ordering
- bound/quantize solver output
- compare live and validator goldens
- version and drain old sessions before cutover

### Hidden flat-ground assumptions survive

Mitigation:

- complete the Phase 0 consumer inventory
- search every `groundTopY`, `StaticSolid`, `StaticGroundSegment`,
  `groundSurfaces`, `colliderAabb`, and directional-contact use
- record an explicit disposition for every result

### Polygon authoring becomes difficult or unsafe

Mitigation:

- keep baseline polygons simple and snapped
- block self-intersection/overlap
- provide scene diagnostics and canonical migrations
- avoid adding holes, splines, rotations, or boolean editing in the first pass

### Runtime or graph rebuild cost grows too far

Mitigation:

- establish budgets before implementation
- use immutable precomputed edges and a 2D static index
- cap authoring complexity
- profile per-enemy graph construction and reuse shared geometry/indexes

### Scope expands into a general physics engine

Mitigation:

- keep terrain static
- keep actors upright and kinematic
- keep combat overlap separate
- defer rigid bodies, rotating shapes, dynamic polygon collision, and
  destructible terrain

## 20) Non-Goals

- general rigid-body simulation
- dynamic, rotating, moving, or deformable polygon terrain
- destructible terrain
- arbitrary actor rotation along slopes
- replacing all combat hitboxes with capsules
- changing raw input/replay command encoding solely for slopes
- runtime spline collision
- polygon holes/boolean authoring in the baseline editor
- automatic navmesh generation unrelated to the existing surface-graph model
- adding step-up beyond the accepted 4-pixel helpers, ledge grab, wall slide, or
  drop-through mechanics without a separately accepted gameplay contract

Moving platforms are not included in this static-terrain migration. If they are
added later, they need a separate deterministic support-velocity, transform,
navigation, and replay contract.

## 21) Definition Of Done

This plan is complete only when:

- polygons are the source-of-truth collision shape for current chunk/prefab
  static terrain
- runtime collision uses canonical edges and a deterministic spatial index
- player and every relevant enemy use an explicit capsule/static-world policy
- player traversal passes the slope and mobility matrix
- enemy pathfinding, jumping, dropping, pursuit, trajectory prediction, and
  special placement work on slopes
- spawning and pickups use exact eligible terrain points and clearance
- streaming stitches collision, navigation, and rendering across chunk seams
- ground rendering and debug tooling match Core geometry
- replay validator parity and version rollout are proven
- migrated content has no legacy fallback
- legacy rectangle/horizontal-ground runtime authority is removed
- required TDD/GDD/editor/replay documentation is current
- all validation, deterministic golden, performance, and production gates pass

## 22) Immediate Next Step

Phase 2 is accepted in
[phase2-implementation-checklist.md](phase2-implementation-checklist.md).
The reusable controller, isolated player traversal authority, player/consumer
matrix, golden signatures, zero-allocation profile, and performance gates all
pass.

Phase 3 is accepted in
[phase3-implementation-checklist.md](phase3-implementation-checklist.md).
Enemy capsule/policy definitions and the canonical shared sloped surface set,
signature, spatial index, reusable query buffers, actor-neutral
standability/support/placement query, and shared-node Grojib/Hashash ordinary
walk/jump/drop graph variants are implemented. Deterministic integer A* and the
isolated runtime navigator now consume those nodes and edges, including
prior-support validation, same-chain pursuit, committed jump/drop execution,
version invalidation, locks, and finite no-plan fallback. The isolated
full-capsule trajectory predictor now matches fixed-tick integration, continuous
segment contact, placement clearance, deterministic landing order, and accepted
controller replay. The isolated multi-body authority now preflights and
dispatches the player, Grojib, Hashash, and Unoco exactly once in stable entity
order, retains Derf as a kinematic placement actor, rejects unsupported bodies,
and preserves player motion/distance behavior. Grojib and Hashash now consume
prepared terrain support, apply existing AI/status/lock tuning in scalar
surface-speed space, follow eligible tangents at constant authored distance,
use the accepted 4-pixel helpers, launch jumps world-up without resnapping, and
drive animation/death from final support. Hashash ambush now validates its
fixed right-then-left airborne candidates transactionally, restores the last
safe transform on cancellation, and routes deferred edge spawns through the
same full-capsule placement authority without relocation or replacement RNG.
Unoco now follows the highest local solid surface under its capsule footprint,
retains that reference over pits, falls back to the explicit level plane only
before any local reference exists, and preserves its randomized 60-180-pixel
hover band and combat steering. Its full capsule sweeps all solid sides, ignores
one-way terrain, never grounds, and reacts to blocking through a fixed four-way,
six-tick preview with a deterministic 12-tick detour hold and no new RNG or
relocation path. Derf now binds only to a real intended solid obstacle top,
accepts slopes through 15 degrees, and requires an independent 32-pixel perch
span plus complete capsule clearance. It clamps only within that edge. Invalid
markers skip with a stable diagnostic while legacy placement fallback remains
unchanged. All enemy markers and procedural collectibles/restoration items now
share one typed placement request/result boundary in the terrain harness. It
preserves authored support-source intent, catalog/profile limits, same-edge
clamp policy, full actor/item clearance, item attempt consumption, marker
order, salts, and RNG draws. Exact terrain edge identity can bypass the
temporary legacy support-height bridge, while normal repository-backed levels
continue to use the legacy production authority. The terrain harness now builds
geometry, collision/surface indexes, one shared surface set, and both enemy
graph views into an immutable versioned bundle, then publishes a queued
replacement through one tick-boundary reference change. Grounded and airborne
support/path caches invalidate before AI, stale motion state is rejected, and
no-op rebuild signatures remain content-identical across version changes. The
consumer audit fixes prior-support AI, exactly-one integration, and final-state
animation/downstream evidence while retaining explicit later-phase dispositions
for production navigation, replay validation, and ballistics. Section 23 now
binds all of that evidence into reviewed `nav-surfaces-v1`, `nav-graphs-v1`,
and `enemy-terrain-run-v1` hashes across fresh objects, input permutations, and
fresh processes. Its five-chunk/1,280-edge representative fixture, 5,120-edge
hard fixture, paired VM allocation profile, compiled product benchmark, and
full package/root/replay-validator suites pass their frozen gates without
changing the reviewed scenario hashes or normal legacy construction.

Phase 4 is in progress under
[phase4-implementation-checklist.md](phase4-implementation-checklist.md).
The read-only baseline/migration audit, exact half-pixel source model, Core
canonicalization/overlap/transform seam, strict prefab-v3/chunk-v2 staging
records, shared polygon reducer/painter, and explicit locked Prefab/Chunk
staging workspaces are implemented. Chunk staging now also expands prefab-v3
collision through the exact Core transform, validates it together with direct
terrain, and renders the quantized result as a read-only lineage overlay with
separate capacity evidence. Normal source remains prefab v2/chunk v1;
scheduler-aware seams, safe source migration, staged generation, and the
coordinated normal editor cutover remain open. Phase 4 must not select polygon
terrain in normal production runs before the later streaming/content cutover
phases.
