# Slopes Phase 0 - Technical Defaults

- Date: July 18, 2026
- Status: Complete; technical defaults and gameplay-dependent values accepted
- Source checklist:
  [phase0-implementation-checklist.md](phase0-implementation-checklist.md)
- Consumer evidence:
  [phase0-consumer-inventory.md](phase0-consumer-inventory.md)

## 1) Decision Policy

These defaults are selected to preserve determinism, current gameplay
semantics, and existing ownership. They may be changed only with a concrete
counterexample, measurement, or confirmed gameplay decision.

Player-facing choices are recorded separately and confirmed one at a time.
Technical implementation should not wait on a gameplay choice when it can use
a named tuning field or profile.

Because slopes are not implemented yet, this building document is the
authority for planned contracts. TDD/GDD documents must be updated to describe
the delivered behavior during the implementation/cutover phases; they must not
claim this plan is already implemented.

## 2) Authority And Scope

- `runner_core` remains the sole collision, support, terrain-query,
  navigation, spawn-clearance, and deterministic simulation authority.
- The editor writes deterministic source polygons; it never writes gameplay
  runtime state.
- The generator validates and compiles authored geometry.
- Flame renders immutable Core snapshots and never classifies collision or
  walkability.
- Only static terrain is supported. Moving, rotating, deformable, destructible,
  or general rigid-body terrain is out of scope.
- Actor world contact changes to upright capsules. Combat overlaps, pickups,
  triggers, and the dynamic broad phase remain AABB-based.
- Production cutover is direct by compatibility version. There is no
  long-lived rectangle and polygon authority switch.

## 3) Source Polygon Contract

### Shape model

Each source shape has:

- stable `shapeId`, unique inside its prefab or chunk
- ordered vertices in prefab-local or chunk-local world-pixel units
- `collisionMode`: `solid` or `oneWay`
- optional semantic `surfaceKind`
- optional render `materialKey`

Semantic kind/material and collision mode are separate. Rendering metadata
cannot change collision behavior.

### Coordinates and transforms

- World X increases right; world Y increases down.
- Source vertices use exact half-world-pixel coordinates. JSON numbers must be
  multiples of `0.5` and are normalized immediately to integer half-pixel
  ticks, avoiding floating-point identity.
- The editor defaults to the owning document's grid snap but permits half-pixel
  vertices for exact legacy-bound preservation or intentional detail.
- Prefab vertices are relative to the existing prefab anchor.
- Placement applies anchor-relative vertex, optional X/Y reflection, uniform
  scale, and translation in that order.
- The transformed result is quantized once to the physics subpixel grid
  (`1 / 1024` world unit by default).
- Preserve the current prefab-source validation rule: for a colliding prefab,
  at least one source collision shape must intersect the resolved visual source
  bounds. Shapes may extend outside those bounds when the authored collision
  intentionally does so; the editor reports the extent and never clips it.
- After placement transform and quantization, every collision vertex must be
  inside the owning chunk's closed `[0, width] x [0, height]` authoring bounds.
  Cross-chunk terrain continuity is authored with matching boundary vertices,
  not by allowing one chunk to own geometry in its neighbor.
- Rotation, non-uniform scale, curves/splines, and holes are out of scope.

### Canonical form

- A polygon is simple, has at least 3 distinct vertices, and has non-zero area.
- Canonical winding is clockwise as viewed in the game's Y-down coordinates.
- The first vertex is rotated to the lexicographically smallest `(x, y)`
  vertex; remaining ties compare the complete cyclic sequence.
- Consecutive duplicates and a repeated closing vertex are rejected.
- Collinear middle vertices are removed during explicit normalization and
  reported; source saving never silently changes them.
- Edges shorter than one source pixel and polygons smaller than one square
  source pixel are rejected.
- Self-intersection is blocking.
- Polygons may share exact boundaries but may not overlap in area.
- Diagnostics sort by source path, shape ID, edge/vertex index, then code.

### Limits

Initial hard safety limits:

- 64 shapes per prefab
- 64 vertices per shape
- 512 placed/source shapes per chunk
- 4096 exposed compiled edges per chunk

Performance budgets may lower these limits; content cannot silently truncate
at a limit.

### Source schema example

The final field names may be adjusted to existing model naming during Phase 2,
but the contract shape is:

```json
{
  "collisionShapes": [
    {
      "shapeId": "ground_main",
      "collisionMode": "solid",
      "surfaceKind": "terrain",
      "materialKey": "forest_ground",
      "vertices": [
        {"x": 0, "y": 224},
        {"x": 96, "y": 176},
        {"x": 192, "y": 224},
        {"x": 192, "y": 270},
        {"x": 0, "y": 270}
      ]
    }
  ]
}
```

The example is clockwise in Y-down coordinates. The filled/solid side lies
below the two sloped top edges.

## 4) Migration Contract

- Each isolated AABB maps to four clockwise vertices preserving its occupied
  area exactly before transform quantization.
- Touching/overlapping AABBs are unioned by an offline deterministic migration
  tool.
- A union may emit multiple simple polygons when the occupied area has
  disconnected components.
- A union that creates a hole, ambiguity, or invalid subpixel boundary is a
  blocking reauthor case.
- Flat ground and gaps migrate to finite chunk terrain polygons; a pit is
  missing solid coverage, not a special runtime gap collider.
- Prefab and chunk schema versions increment. Stable prefab/chunk keys remain
  unchanged; revisions increment only for records whose canonical collision
  source changes.
- Migration produces a sorted report of automatic conversions, unions,
  reauthor blockers, and generated-data changes.
- Legacy readers exist only for the migration tooling window. They are removed
  before production authority cutover.

The Phase 0 topology-only union audit produced the following candidate output:

- 70 collision-bearing prefabs produce 88 simple source polygons
- 29 decoration prefabs remain unchanged
- 29 prefabs have multiple rectangles; no current union creates a hole,
  point-only ambiguity, or limit overflow
- 31 collision-bearing chunk placements produce 32 polygon instances
- 8 flat chunk profiles, including the one current gap, produce 9 ground
  polygons

Phase 4 exact Core revalidation corrects the earlier blocker conclusion. It
accepts 67 of the 70 collision-bearing prefabs and 85 of the 88 candidate
loops. `dark_menhir_01`, `dark_menhir_03`, and `ruin_stone_00` each contain an
exact one-source-tick (`0.5 px`) exterior edge, which is below the frozen
one-world-unit minimum edge length. This is not a hole or union ambiguity; it
is a resolution mismatch that the topology-only audit did not test.

The accepted content decision retains the one-world-unit global minimum and
uses explicit minimal outward corrections for only those three migration
records. The corrections add 34, 25, and 36 half-pixel-square ticks
(`8.5 px²`, `6.25 px²`, and `9 px²`) respectively. Exact legacy-collider guards
make source drift blocking. With those reviewed inputs, all 70 collision
prefabs and all 88 planned loops pass Core. Normal schema v2 source and legacy
runtime collision remain unchanged until the later single schema cutover.

The migration tool must reproduce this sorted report before writing source.

### Rectangle-union example

Two overlapping source rectangles:

```text
A = [0, 0] -> [32, 32]
B = [16, 16] -> [48, 48]
```

normalize to one clockwise concave outline:

```text
(0,0), (32,0), (32,16), (48,16),
(48,48), (16,48), (16,32), (0,32)
```

The shared/overlapped interior edges do not survive compilation. If the same
operation creates disconnected regions, each region receives a deterministic
derived shape ID ordered by its canonical first vertex.


## 5) Generated And Runtime Geometry

### Generated data

Generated Dart retains:

- normalized polygon loops and render metadata
- precompiled exposed local edges
- source identity lineage
- deterministic compiler/signature version

Both outputs are produced in one generator pass from one source model.
Runtime code never rebuilds collision edges from render triangles.

### Runtime types

The runtime geometry bundle owns:

- immutable terrain polygons for snapshots/diagnostics
- immutable exposed `TerrainEdge` records for collision
- deterministic terrain edge spatial index
- source-to-runtime identity maps used only for diagnostics

Each edge stores:

- quantized endpoints
- quantized or deterministically derived tangent and outward normal
- collision mode and walkability metadata
- previous/next exposed edge IDs when connected
- source shape and local-edge identity
- tight AABB

Clockwise Y-down polygon edges derive outward normal as the normalized
`(dy, -dx)` vector.

### Identity and ordering

Runtime identity lineage is:

```text
chunkIndex/chunkKey
  -> placedPrefab deterministic selection key, if any
  -> shapeId
  -> canonical local edge index
```

Base-level geometry uses a reserved base chunk identity. Ordering compares
chunk index, placed/source identity, shape ID, then local edge index. Runtime
lists, spatial candidates, seam matches, and equal-time contacts use that same
order.

## 6) Internal Edges, Adjacency, And Seams

- Exact reversed shared edges with compatible solid modes are internal and
  removed from collision output.
- Partially overlapping collinear edges must be deterministically split before
  internal removal.
- One-way edges are never removed against solid edges merely because they
  overlap.
- Connected exposed edges retain previous/next IDs as ghost-vertex context.
- Exact continuous chunk-boundary endpoints are stitched after active chunks
  are flattened.
- A seam is continuous only when quantized endpoints and compatible surface
  semantics match.
- A missing neighbor, incompatible mode, or unmatched endpoint is an exposed
  ledge.
- Gaps are deliberate missing adjacency.
- Streaming rebuild order remains active chunk order, source order, then local
  shape/edge order.
- Culling a neighbor may expose its former seam behind the safe cull margin;
  it must not renumber retained source edges.

## 7) Terrain Edge Spatial Index

- Reuse `GridIndex2D`; do not reuse the face-list implementation of
  `StaticWorldGeometryIndex`.
- Add terrain-owned cell-size tuning, initially 64 world units.
- Insert an edge into every cell touched by its closed tight AABB.
- On an exact cell boundary, insert into both adjacent cells by the same closed
  interval rule used by queries.
- Queries use the swept shape AABB expanded by skin/contact tolerance.
- Bucket insertion order is canonical edge order.
- Stamp-based candidate deduplication is allowed, followed by a canonical edge
  ID sort before narrow phase.
- Callers own reusable query/contact buffers; the hot path allocates nothing.
- `TrackManager` remains the single geometry mutation point and rebuilds
  geometry, collision index, snapshots, and navigation variants under one
  incremented geometry version.

## 8) Capsule And Other World Shapes

### Upright capsule

An actor capsule stores:

- center offset, including the current facing-offset rule where authored
- radius
- vertical half-segment length
- derived AABB half extents `(radius, radius + halfSegment)`

Mechanical AABB migration uses:

```text
radius = old halfX
halfSegment = max(0, old halfY - radius)
offset = old collider offset
```

The old AABB therefore remains exactly the capsule's derived broad-phase and
combat bound. Per-actor overrides are allowed only as explicit authored
tuning, not hidden solver exceptions.

### Shape roles

- player, Grojib, and Hashash: dynamic upright capsule
- Unoco Demon: dynamic upright capsule with a separate flying-contact policy
- Derf: kinematic upright capsule used for clearance and overlap, not
  integrated motion
- ballistic projectiles: one integration owner with an authored swept circle
  world shape; derived AABB remains combat/render broad phase
- non-physics projectiles: no implicit terrain contact
- pickups, restoration items, combat hitboxes, and triggers: AABB overlap only

Invalid negative dimensions, non-finite values, or an AABB narrower than zero
are blocking definition errors. A capsule with zero half-segment is a circle.

## 9) Geometry Kernel And Solver

### Pure operations

The kernel provides allocation-free:

- closest point on segment
- segment/segment closest points
- capsule/edge signed separation
- endpoint-aware contact normal
- initial-overlap recovery candidate
- support probe
- moving capsule/circle versus edge time of impact

Normals are precomputed/quantized during compilation, not normalized per query
unless an endpoint contact requires a derived radial normal.

For a one-way edge, collision is allowed only when the capsule's previous
support point is on the edge-normal/outside side by at least contact epsilon,
the requested displacement approaches or crosses the edge plane, and the
contact projection lies on the finite edge. A capsule already behind the
one-way edge is allowed to leave without recovery. Endpoint contact uses the
same previous-side test and the endpoint radial normal; it does not turn the
back side into a solid wall.

Accepted player-facing one-way behavior preserves the current feature scope:
Éloïse passes from below and lands/traverses from the authored walkable side.
Exposed endpoints are not solid side walls, automatic step-up cannot climb an
endpoint from the side, and the slope release adds no drop-through input.

### Continuous collision

Use deterministic conservative advancement over the exact
capsule-segment closest-distance function, with a fixed iteration limit and
fixed bisection refinement after a contact bracket is found. A discrete
end-position overlap is only a fallback diagnostic, never the normal
high-speed path.

Degenerate static edges are rejected by compilation. A degenerate capsule
center segment is handled as a circle.

### Move and slide

For each dynamic body:

1. compose requested displacement from current velocity and fixed tick
2. query edges with its swept AABB
3. find earliest allowed contact
4. tie-break equal TOI by canonical edge ID
5. advance to contact minus skin
6. project remaining displacement and velocity onto the contact tangent
7. repeat for at most 4 contact iterations
8. run support probe/snap if eligible
9. quantize final position, velocity, and recorded contact values

Simultaneous contacts whose TOIs are within tie epsilon are collected in edge
ID order. Two non-parallel blocking normals form a corner constraint rather
than allowing alternating penetration.

Initial overlap recovery is bounded to 4 iterations and a maximum correction
of one capsule radius per tick. Failure leaves the body at the last valid
position, clears support, emits a deterministic diagnostic in debug/test
builds, and never teleports through terrain.

### Automatic step-up

Éloïse has a bounded automatic step-up during ordinary grounded locomotion.
When requested horizontal motion is blocked by a candidate ledge, the solver
may perform one deterministic up-forward-down sweep sequence:

1. sweep upward by the accepted maximum step height and reject ceiling contact
2. sweep forward by the unresolved horizontal displacement
3. sweep downward to the first eligible walkable support
4. accept only if the full capsule path is clear and the final support is valid

The solver never applies a direct positional teleport. One-way back faces,
over-limit/steep faces and airborne motion cannot initiate step-up. Grounded
dash/roll explicitly uses the same 4-pixel player helper as ordinary
locomotion. Enemies require separate traversal-profile approval.

The maximum player step height is 4 world pixels, one quarter of the 16-pixel
terrain grid.

### Numeric defaults

- geometry/source quantization: `1 / 1024` world unit
- geometry equality epsilon: `1 / 1024`
- contact/tie epsilon: `2 / 1024`
- collision skin: `1 / 16` world unit
- solver contact iterations: 4
- conservative-advance iterations: 8
- bisection refinement iterations: 8

Squared distances are used until an actual distance/normal is required.
Division and square root use Dart arithmetic in the pure shared Core
implementation, followed by the stated quantization boundary. No trig is used
in the hot path; slope comparisons use dot/cross products against precomputed
profile thresholds.

The existing fixed-point pilot becomes the mandatory position/velocity
quantization path for the new solver rather than a parallel collision
algorithm. Live and validator run the same code and tuning.

## 10) Support And Contact State

The generalized contact store records:

- `grounded`
- support edge ID
- support point
- support normal and tangent
- support geometry version
- last valid support tick
- blocking wall/ceiling normals or compatibility flags

`grounded` means the final resolved capsule has an eligible walkable support
contact or successful eligible support probe in the current tick. Merely
touching a steep edge does not ground the actor.

Éloïse's ordinary-locomotion support probe is directed world-down and has a
maximum snap distance of 4 world pixels. Snap eligibility requires valid
support at the beginning of the tick, a matching geometry version, and no
upward requested velocity. It preserves support; it does not acquire terrain
for an actor that was already airborne.

Accepted jump takeoff, teleport, upward/launch knockback, or an explicit body
disable clears snap eligibility before motion. A grounded dash/roll explicitly
uses the same 4-pixel support snap as ordinary locomotion; an airborne-started
ability does not. A successful snap lands on the first eligible support in
canonical edge order, cannot cross a blocking edge, and never moves the capsule
upward.

An accepted ordinary jump applies its authored impulse in world-up, independent
of the support normal. Support and snap eligibility clear before that impulse.
Slope contact adds no horizontal jump impulse; existing air-control and
horizontal-velocity rules remain authoritative afterward.

Terrain-angle transitions never add an artificial launch impulse. At a convex
peak, eligible support within the 4-pixel snap range preserves grounding. If
support falls outside that range, the actor becomes airborne with its existing
resolved velocity, and ordinary coyote time begins on the first unsupported
tick. Concave valleys use the normal corner constraint and do not bounce or
inject velocity.

The collision solver is the sole normal-tick writer. Other systems may clear
support eligibility for jump, teleport, disable/death, or authored mobility,
but do not manufacture a support contact.

Directional `hitLeft`, `hitRight`, and `hitCeiling` compatibility values may be
derived during migration. New logic reads contact normals rather than those
booleans.

Support is cleared on:

- accepted jump takeoff
- teleport before destination validation/placement
- body disable or kinematic ownership change
- death transition when motion no longer resolves
- geometry-version mismatch when the support edge disappeared

## 11) GameCore Ordering

Preserve the current high-level order with these explicit boundaries:

1. stream/stitch terrain and atomically publish geometry/index/nav version
2. refresh timers, locks, and ability phases
3. AI reads prior-tick support plus the current geometry version
4. movement, mobility, knockback, and gravity compose velocity/displacement
5. one world-motion dispatcher integrates every body exactly once by shape
6. final support/contact state becomes authoritative
7. projectile world-contact despawn reads current-tick contact
8. camera, distance, death/cull, animation, snapshots, and hit detection read
   final transforms/support at their documented point

Navigation intentionally reads prior-tick support because current-tick support
does not exist until motion resolves. A geometry-version mismatch invalidates
the prior support/path before AI uses it.

Ballistic projectile integration moves out of any generic actor-only loop but
remains in the single world-motion dispatcher. `ProjectileSystem` continues to
skip `usePhysics` projectiles.

## 12) Navigation And Pathfinding

- Keep the existing surface graph, deterministic A*, navigator state,
  per-enemy graph variants, shared spatial-index ordering, and graph version.
- Replace horizontal `WalkSurface` with directed straight
  `WalkSurfaceSegment` nodes derived from canonical exposed terrain edges.
- A node exposes endpoints, `yAt(x)`, length, tangent, normal, edge/source ID,
  and collision mode.
- Walkable nodes must be X-monotonic and non-vertical. Vertical/over-limit
  edges remain collision walls and are not standable.
- Adjacent eligible surface nodes receive directed `walk` graph edges.
- Jump and drop edges retain their current concepts but evaluate source and
  destination `yAt(x)` and capsule clearance.
- Surface nodes and their order are shared across enemy profiles. Per-enemy
  graphs filter eligibility and transitions without reordering nodes.
- Current/target lookup queries the shared index, filters profile eligibility,
  then tie-breaks by vertical priority and stable surface ID.
- Spawn eligibility is stricter than mere point intersection: the complete
  capsule must be clear and the required support interval must exist.
- Trajectory prediction intersects the falling capsule support point with
  sloped segments, not a fixed `yTop`.
- Existing chase and melee stand-off offsets remain world-X distances. A target
  at `playerX + offsetX` resolves its support with `yAt(targetX)`; the offset is
  not rotated into distance along the slope.
- Combat vertical-separation and engagement checks use final actor transforms
  and derived bounds, never a shared flat `yTop`.
- Invalid/no-plan fallback clamps to the last known eligible surface and never
  gains hidden teleport authority.

Grojib and Hashash walk cost is surface length divided by the relevant
archetype's authored locomotion speed, matching their accepted constant
distance-along-surface runtime movement. Player movement uses the accepted
continuous world-horizontal speed curve in §18.

## 13) Spawn, Teleport, Death, And Culling

- Terrain queries return support point, edge ID, tangent, normal, and source
  identity, not only Y.
- Highest-surface queries prefer the smallest world Y and tie-break by stable
  edge ID.
- Unoco Demon's randomized 60-180-world-pixel hover band references the highest
  relevant local terrain beneath its horizontal capsule footprint rather than
  global `groundTopY`. Existing hold timing and RNG order remain unchanged.
  When no surface exists below it retains the last valid local reference;
  without one it uses an explicit level flight-reference plane. Existing
  bounded vertical steering follows the target without teleporting.
- Éloïse's required initial placement needs player-walkable support no steeper
  than 60 degrees, the full 20.6-pixel capsule-width support interval, and
  complete capsule clearance. Failure is a level-validation error; runtime
  does not relocate the player.
- Grojib and Hashash grounded placement needs support within the relevant
  traversal profile, the actor's full capsule-width support interval, and
  complete capsule clearance. A marker may clamp only to the nearest standable
  point on the same intended support. Failure, including a deferred Hashash
  edge spawn, skips that spawn and emits a diagnostic.
- Unoco Demon placement requires complete capsule clearance at the intended
  flying position. A blocked marker is skipped rather than embedded or moved
  to unrelated terrain.
- Marker RNG, marker iteration, chunk selection, and Hashash deferred-roll
  order remain unchanged.
- Hashash teleport must validate the destination capsule and support when the
  ambush requires landing; failure uses a deterministic ordered fallback list
  or cancels, never embeds the actor.
- Hashash's airborne ambush preserves its primary point 36 pixels right and
  36 pixels above the predicted player. Teleport-in requires full capsule
  clearance but not support. If blocked, it tries the mirrored left/above point;
  if both fail, it keeps/restores the last safe position, queues no strike, and
  applies the normal cooldown. The fixed candidate order consumes no RNG.
- Derf remains stationary and may spawn only on support at or below 15 degrees
  with full capsule clearance and at least 32 world pixels of horizontal
  support span. Marker X may clamp only to the nearest standable point on that
  same obstacle-top support. An absent, obstructed, too-steep, or too-narrow
  intended support skips the spawn and emits a diagnostic; it never falls back
  to unrelated highest terrain or ordinary ground.
- Derf retains its existing predicted-player-center cast target, face-player
  policy, and upright world-space cast-origin semantics. Support slope does not
  rotate its art, aim, cast origin, or target point.
- Pickups/restoration items remain AABBs and may use solid or one-way
  player-walkable support no steeper than 60 degrees. Placement requires at
  least 20 world pixels of horizontal support: the current 16-pixel item width
  plus the existing 2-pixel margin on each side. They use exact `yAt(x)`,
  existing vertical clearance, and full AABB clearance. An invalid candidate
  consumes its normal deterministic attempt; exhausting the existing attempt
  budget produces no item.

Player fall death uses a level-authored absolute `killPlaneY`. Legacy levels
default it to `groundTopY + gapKillOffsetY`, preserving current behavior.
Terrain height under the actor is never itself the kill bound. Enemy
below-world culling uses a level-authored enemy cull plane with the same legacy
default; behind-camera culling is unchanged.

## 14) Rendering And Snapshots

- Core publishes immutable terrain polygon snapshots with material/source
  metadata and optional compiled triangle indices.
- Triangulation is deterministic and performed by generation/compilation, not
  independently by Flame.
- Core may also publish debug edge/normal/support/nav snapshots behind the
  existing debug gate.
- Flame fills/clips polygons, uses world-anchored texture coordinates, and
  pixel-snaps only final render positions.
- Adjacent terrain with the same material shares world texture phase.
- The foreground/parallax mask consumes the same terrain fill polygons.
- `TemporaryFloorMask` is removed rather than generalized.
- Actor art remains upright and interpolates final Core transforms; support
  normals do not rotate sprites unless a later gameplay decision explicitly
  adds that feature.
- Snapshots are never read back by Core.

## 15) Replay And Rollout

Planned compatibility set for the slope cutover:

- `gameCompatVersion`: `2026.07.0`
- ranked `rulesetVersion`: `rules-v2`
- `scoreVersion`: keep `score-v1`
- `ghostVersion`: `ghost-v2`
- replay blob version: keep 1
- command encoding version: keep 1

`2026.07.0` is a reserved planned value, not permission to issue tickets. If
the slope-compatible release moves beyond that release line, allocate a newer
unused compatibility value before provisioning or issuance; never reuse a
value for different physics/content.

Rationale:

- collision/navigation changes alter simulation outcomes, so game compatibility
  and ranked rules must change
- the score formula is unchanged, so its version does not change
- ghosts replay through Core and therefore require the new physics version
- commands and replay payload shape do not change

The exact generated-content compiler signature/revision is part of the
compatible deployed build even though it is not added to the replay blob.

Rollout:

1. stop issuing old-compatible run sessions
2. allow the 24-hour ticket/session window plus active 10-minute validation
   leases and repair work to drain
3. verify no old non-terminal session remains
4. deploy the matching new Core/generated content to client and validator
5. provision new `rules-v2` boards before enabling ranked issuance
6. enable new-compatible issuance

The validator must use an explicit supported `gameCompatVersion` allowlist and
reject incompatible tickets before constructing Core. Rollback restores the
entire compatible client/validator/content/board-issuance set. No mixed
physics deployment is supported.

## 16) Deterministic Evidence

Phase 1 must add canonical signatures for:

- normalized source polygons
- compiled exposed edges and adjacency
- terrain index candidate order
- support/contact state
- per-enemy surface graphs
- selected paths
- representative full-run end state

Canonical signatures serialize quantized integers and stable enum/string IDs,
never unordered map/set iteration or default object `hashCode`.

The live recorder and validator must replay the same command fixture to the
same final signature under the same compatibility build.

## 17) Performance Defaults

The following are initial acceptance budgets, subject to measurement on the
repository's reference development machine and validator environment:

- zero steady-state allocations per dynamic body terrain query
- at most 4 move-and-slide contacts per body per tick
- candidate lists sorted only after grid deduplication
- 60 Hz Core tick p99 remains below 4 ms in the representative slope fixture
- terrain collision adds no more than 25% to the equivalent flat-fixture tick
  time
- streamed terrain/index/nav rebuild p99 remains below 50 ms and occurs only
  on geometry-version changes
- validator replay remains faster than real time with at least 2x headroom

Measured baselines and fixture sizes must be recorded before these budgets can
close Phase 0.

## 18) Gameplay Inputs

Accepted:

- The player's maximum walkable slope is 60 degrees from horizontal,
  inclusive. A representable slope above 60 degrees is non-walkable for the
  player and resolves as a steep wall.
- Authoring exposes the value in degrees. Runtime walkability compares the
  support normal against a precomputed threshold; it does not evaluate
  trigonometric functions in the simulation hot path.
- Player target horizontal speed uses this signed-slope curve:

  | Absolute slope angle | Uphill multiplier | Downhill multiplier |
  | ---: | ---: | ---: |
  | 0 degrees | 1.00 | 1.00 |
  | 30 degrees | 0.95 | 1.05 |
  | 45 degrees | 0.85 | 1.10 |
  | 60 degrees | 0.75 | 1.15 |

- Values between control points use deterministic linear interpolation. The
  runtime evaluates a precompiled curve from the quantized support normal; it
  does not use hard angle tiers or per-tick trigonometry.
- Uphill/downhill is relative to requested travel direction. The multiplier
  changes target X speed and existing acceleration/deceleration approaches the
  new target; support transitions do not directly rewrite velocity.
- Distance, score, and camera retain world-X semantics and therefore observe
  the accepted uphill slowdown/downhill increase. Looping grounded locomotion
  animation uses the accepted surface-distance rate in this section.
- Automatic small step-up is enabled for Éloïse during ordinary grounded
  locomotion with a maximum height of 4 world pixels. Enemies do not inherit
  the feature.
- Éloïse's ordinary downward ground snap is limited to 4 world pixels and only
  preserves prior valid support during non-upward motion. It never magnetizes
  an already-airborne player onto terrain.
- Sharp terrain transitions add no launch impulse. Convex peaks preserve
  support only within the accepted snap range; wider departures retain existing
  velocity and enter ordinary airborne/coyote-time behavior. Concave valleys
  do not bounce.
- Sloped one-way platforms pass Éloïse from below and support her from their
  authored walkable side. Their endpoints do not become side walls, and the
  first slope release adds no drop-through input.
- Ordinary jumps launch world-up regardless of support normal. Slope contact
  adds no sideways jump impulse.
- Grounded dash/roll displacement follows the eligible support tangent in the
  selected horizontal direction while actor art remains upright. Airborne
  ability behavior remains in its existing world-space form.
- Grounded dash/roll speed is constant along the support tangent and preserves
  the ability's authored surface distance/duration. The ordinary running
  uphill/downhill multiplier does not apply during the ability; horizontal
  reach therefore scales with the support tangent's X component.
- A grounded dash/roll may use the same 4-pixel step-up and downward snap
  helpers as ordinary locomotion, with identical clearance and support rules.
  Airborne-started abilities use neither helper.
- Grojib's maximum walkable slope is 45 degrees, inclusive. Steeper edges
  remain collision walls and are excluded from Grojib's walk graph; existing
  valid jump/drop transitions may still route to a separate eligible surface.
- Grojib uses 4-pixel automatic step-up and downward snap during ordinary
  grounded pursuit. Its navigation graph emits an ordinary walk transition
  across a small elevation change only when the same capsule-clearance and
  support query accepts it.
- Grojib moves at constant distance-along-surface speed. Its ordinary walk-edge
  cost is surface length divided by its authored locomotion speed, matching
  runtime travel time; no uphill/downhill multiplier is applied.
- Hashash's maximum walkable slope is 60 degrees, inclusive. Steeper edges
  remain collision walls and are excluded from Hashash's walk graph; existing
  valid jump/drop and separately validated teleport transitions remain
  available.
- Hashash uses 4-pixel automatic step-up and downward snap during ordinary
  grounded pursuit. Its graph emits a small ordinary walk transition only when
  the same capsule-clearance and support query accepts it.
- Hashash moves at constant distance-along-surface speed. Its walk-edge cost is
  surface length divided by its authored locomotion speed, matching runtime
  travel time; no uphill/downhill multiplier is applied.
- Unoco Demon's swept capsule is blocked by solid terrain from every side and
  completely ignores one-way platforms. It never becomes supported/grounded.
  When desired motion is blocked, a bounded deterministic clearance-steering
  candidate set ranks clear directions by progress toward the current
  hover/combat target, clearance, then stable candidate ID. It uses no flight
  nav graph, new RNG draw, teleport, or phasing fallback.
- Derf may be placed only on support at or below 15 degrees. It remains
  kinematic and visually upright; the complete capsule and required support
  interval must be clear. Its intended obstacle-top support must provide at
  least 32 world pixels of horizontal span. Marker X may clamp only within that
  same support; invalid placement is skipped with a diagnostic and never
  falls back to unrelated terrain.
- Final post-solver support state, rather than world vertical velocity,
  controls grounded versus airborne animation for the player, Grojib, and
  Hashash. Supported slope traversal, accepted step-up, and ground snap retain
  grounded animation; an accepted jump clears support immediately, and true
  support loss uses the existing airborne vertical-velocity thresholds.
- Player and enemy render art remains upright with horizontal facing. Terrain
  tangent and normal never rotate actor sprites, cast origins, or hit bounds.
- Looping grounded walk/run animation phase advances from final resolved
  support distance rather than requested velocity or slope-angle tiers. The
  rate is normalized by the archetype's authored flat-ground locomotion speed
  and continuously clamped to 0.75x-1.50x its authored animation rate.
  Player 60-degree downhill motion therefore caps at 1.50x rather than using
  its raw 2.30x surface-distance ratio.
- The locomotion phase is deterministic and snapshot-visible but has no
  gameplay authority. Idle, airborne, mobility, attack, cast, hit, spawn,
  stun, and death animation timing remains authored and unscaled.
- No current player ability uses `TargetingModel.groundTarget`. For a future
  player ground-target ability, Core derives the desired endpoint from the
  authoritative cast origin, normalized aim, and authored range, then probes
  world-down by the ability's authored limit to the first player-walkable solid
  or one-way top surface. The final point must remain within range and have
  unobstructed collision-side-aware line of sight.
- Core publishes the resolved ground-target point and validity for preview;
  Flame never reclassifies terrain. Commit reruns the same query against
  current geometry. Invalid commit spends no resource, starts no cooldown, and
  never redirects to unrelated terrain. Existing projectile/melee previews and
  Derf's predicted-player-center explosion are unchanged.

The Phase 0 gameplay decision, evidence, and implementation-planning audits are
complete. Delivery begins with the Phase 1 pure geometry checklist; no
unresolved gameplay behavior remains.
