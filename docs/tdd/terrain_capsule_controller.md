# Terrain Capsule Controller

## Status And Authority Boundary

The deterministic terrain geometry and upright-capsule controller are
implemented in `packages/runner_core`, but polygon terrain is not yet the
authority for normal repository-backed runs.

There are currently two construction-time world-motion owners:

| Construction path | Motion owner | Intended use |
| --- | --- | --- |
| `GameCore(...)` | `LegacyWorldMotionAuthority` | Normal game and replay execution |
| `GameCore.terrainMotionHarness(...)` | `TerrainMultiBodyWorldMotionAuthority` | Phase 2/3 tests and benchmarks only |

The selection is immutable after Core construction. It is not level data,
saved data, replay data, UI state, or remote configuration. The terrain
harness integrates the player, Grojib, Hashash, and Unoco through explicit
profiles, keeps Derf kinematic, and rejects unsupported dynamic or ballistic
bodies rather than falling back to rectangle collision. Grounded-enemy and
Unoco terrain locomotion plus the shared terrain-safe enemy/item placement
boundary are implemented only in that harness; atomic streaming publication,
authored-content, and production replay cutovers remain later work.
The implemented Phase 3 profile/surface/index foundation is documented in
[sloped_navigation_and_enemy_terrain.md](sloped_navigation_and_enemy_terrain.md).

## Authoritative Units And Geometry

Terrain motion uses integer physics ticks:

- `1024` ticks per world unit
- `1` tick geometry equality epsilon
- `2` ticks contact and equal-time tolerance
- `64` ticks retained collision skin
- at most `4` blocking-contact iterations
- at most `4` recovery iterations
- at most one capsule radius of recovery correction per tick
- `4096` ticks for both Éloïse step-up and support snap

The immutable `TerrainGeometry` and `TerrainEdgeIndex` produced by the Phase 1
compiler are the only terrain representation read by the controller. Candidate
edges and equal-time contacts remain in canonical `TerrainEdgeId` order.
Runtime slope angles come from `TerrainTraversalCache`; they are not calculated
with platform trigonometry in the tick loop.

## Actor Shape And Traversal Profile

`WorldContactCapsuleStore` owns the world-contact radius, vertical
half-segment, and facing-aware offset. Both current Éloïse definitions use:

```text
radius = 10.3 world units
vertical half-segment = 12.7 world units
offset = (-0.3, 1.0) world units
derived AABB half extents = (10.3, 23.0) world units
```

The capsule is authoritative only for terrain contact. Existing combat,
pickup, broad-phase, culling, and render consumers keep the exact derived AABB.
A facing reversal is included in the next capsule sweep through the retained
tick-start capsule center; it is not an unchecked shape teleport.

`TerrainTraversalProfile` is actor-neutral data. It owns enable/kinematic and
side-collision policy, the inclusive walkable slope threshold, signed speed
curve, step/snap distances, and one-way behavior. The controller does not read
a player entity ID or Éloïse tuning directly. Phase 3 can therefore provide
enemy-specific profiles without branching the collision kernel.

Éloïse's implemented walkability and target-X speed curve are:

| Absolute slope | Uphill | Downhill |
| ---: | ---: | ---: |
| 0° | 100% | 100% |
| 30° | 95% | 105% |
| 45° | 85% | 110% |
| 60° | 75% | 115% |

The curve is continuously integer-interpolated between points. A quantized
60-degree support is walkable; an over-limit edge is a wall.

## Motion Request Semantics

`TerrainMotionRequest` distinguishes three forms of authored movement:

- `groundedHorizontal` preserves ordinary locomotion's requested world-X
  displacement and derives Y from eligible support.
- `groundedSurface` preserves scalar distance along support for grounded
  mobility and constant-surface-distance enemy locomotion.
- `worldSpace` preserves airborne movement, falling, launch, and knockback as
  a world vector until an entering component is removed by contact.

Gravity is carried separately. Valid support consumes it as contact bias, so
idle or move-locked actors do not slide downhill. Once support is lost, gravity
is resolved in world space on that same tick. Jump impulse remains world-up;
grounded mobility uses the committed horizontal direction or facing when the
committed X direction is zero.

## Solve Pipeline

One controller instance owns reusable query, hit, contact, constraint, and
result scratch state and is not concurrent. A solve performs:

1. Validate previous support against the immutable geometry version.
2. Recover an invalid initial solid overlap in canonical order.
3. Query the expanded swept-capsule bounds.
4. Select the earliest allowed continuous contact and all equal-time blockers.
5. Advance to retained skin and constrain only entering motion.
6. Continue for at most four contacts.
7. Attempt at most one eligible step sequence.
8. Resolve final support or a support-preserving downward snap.
9. Atomically publish transform, velocity, contacts, resolved motion,
   last-valid state, and a stable diagnostic.

Solid faces block from their physical side and can classify as support, wall,
or ceiling. One-way faces:

- block only from the collidable side,
- require an approaching/crossing motion,
- require a finite-face projection,
- never recover a capsule from the back side,
- never turn an exposed endpoint into a wall or step.

Compatible endpoint adjacency suppresses ghost normals at smooth joins and
exact cross-polygon seams. Convex peaks and concave valleys retain support
through their canonical adjacent edges. A ledge beyond snap range clears
support on the first unsupported tick.

Equal-time non-parallel blockers are solved as a deterministic 2D half-space
intersection. The controller keeps the requested vector when it is feasible,
otherwise selects the closest feasible single-face tangent, otherwise stops at
the shared corner. This prevents alternating projection between floor/wall,
ceiling/wall, and opposing-wall contacts.

Step-up sweeps up, forward, and down. Its preview adds one deterministic
collision-skin/epsilon clearance beyond the authored lift so an exactly
`4 px` ledge is not misclassified as endpoint tangency. The final body rise
and the geometric height between the source and destination supports remain
bounded by the authored step height. An eligible endpoint may therefore be
used during the exact-boundary transition, but it cannot ratchet a capsule
onto a `5 px` ledge. Snap applies the matching geometric source/destination
height check. Complete support-width validation remains the responsibility of
navigation and placement queries; the runtime helper does not authorize a
narrow authored spawn perch.

Recovery is bounded. If correction exceeds one radius, cannot make progress,
or remains unresolved after four iterations, the controller restores the
last-valid transform when available, clears support, and reports
`recoveryFailed`.

## ECS Publication And Consumers

The terrain harness adds four focused stores/facades:

- `WorldContactCapsuleStore` for the authoritative contact shape
- `TerrainTraversalProfileStore` for immutable actor policy
- `TerrainContactStateStore` for final support, blockers, history, and
  diagnostics
- `ResolvedMotionStore` for requested and accepted per-tick movement
- `WorldSupportView` for consumers that must read terrain support in the
  harness and legacy collision flags everywhere else

`TerrainMultiBodyWorldMotionAuthority.prepareTick` preflights every body and
captures prior valid support before AI, jump, movement, mobility, and gravity.
Its `step` integrates each enabled dynamic terrain body exactly once in entity
ID order after those systems compose velocity. Final support and resolved
motion then drive distance, death/camera checks, snapshots, and animation.

Terrain-harness distance uses positive accepted body X progression and does not
count movement requested into a wall. Grounded locomotion animation advances
from accepted distance along support, with a continuous `0.75x` to `1.50x`
playback clamp. Recovery, snap, and vertical step legs do not advance that
phase. Normal `GameCore` runs keep their historical distance and collision
semantics.

`GameCore.setPlayerPosXYUnsafeForTest` is the only unchecked position mutation.
Its name exposes that it skips destination clearance, and it clears support,
snap eligibility, last-valid placement, and retained capsule history before
the write. No production player teleport exists. Hashash now uses the world
motion authority's transactional begin/commit/cancel placement API: rejected
candidates never write a transform, and accepted points reinitialize retained
capsule history. Derf obstacle-top spawning uses the authority's common
ground-placement query without entering the dynamic controller: it binds one
intended solid edge, enforces the catalog slope limit, a full-capsule foothold,
an independent 32-pixel support span, complete clearance, and same-edge-only
clamping. Future gameplay placement must use the same authority-owned clearance
boundary. An externally applied upward velocity clears support before the next
solve. Disabled or kinematic terrain bodies clear support and do not move.

## Diagnostics And Determinism

`GameCore.buildTerrainPlayerDebugSnapshot()` builds an immutable diagnostic
record only on demand and returns `null` on the legacy path. Normal ticks do not
allocate debug snapshots.

Phase 2 adds two versioned deterministic signatures without changing Phase 1
records:

- `contacts-v2` for quantized controller/contact checkpoints
- `player-run-v1` for the command-driven terrain harness

The reviewed hashes live under
`packages/runner_core/test/fixtures/goldens/`. Phase 1 `source-v1`, `edges-v1`,
and `contacts-v1` signatures remain unchanged.

Phase 3 adds reviewed `nav-surfaces-v1`, `nav-graphs-v1`, and
`enemy-terrain-run-v1` SHA-256 files. The enemy-run schema contains only
length-prefixed UTF-8 strings and integer/ID/enum fields, requires exactly
`SG-E01` through `SG-E15`, and includes fixed-tick transforms, support,
navigation, contacts, placement/teleport/combat outcomes, lifecycle state,
and each scenario's legacy disposition. Test-only fixtures drive the real Core
systems; normal gameplay and replay construction do not consume the signature
fixture.

## Future Ground Targets

`TerrainGroundTargetResolver` is a pure Core query for a future
ground-targeted ability. It resolves a ranged aim endpoint to the first
canonical walkable support below it, checks cast range and line of sight,
applies one-way sidedness, and binds the result to a geometry version.

No production ability currently consumes this resolver. Preview, HUD,
resource, and cooldown integration remain deferred until such an ability is
authored.

## Enemy And Navigation Handoff

The Phase 3 harness now attaches and dispatches the catalog-owned policies:

- Grojib and Hashash are grounded dynamic capsules
- Unoco Demon is a support-free flying capsule blocked by solid terrain
- Derf receives its capsule/profile but remains excluded from per-tick motion
- ballistic projectiles remain an explicit unsupported disposition

Phase 3 now has catalog-owned enemy shapes/policies, canonical walkable edge
chains, a deterministic shared surface index, and one complete-capsule
standability/support/placement query. Shared-node Grojib/Hashash graph views
now emit profile-valid walk edges for compatible joins and accepted 4-pixel
transitions plus continuously swept jump/drop edges on sloped supports.
Grojib/Hashash locomotion now projects the previous final tangent velocity into
signed surface-speed space, applies existing AI/status/lock tuning, and submits
one `groundedSurface` request. Enemy jumps clear support before their world-up
launch, and final support drives resolved-distance animation and ground-impact
death. Hashash airborne teleport and deferred grounded spawn placement now use
the shared complete-capsule query. Unoco now uses the shared surface index for
its retained local hover reference and the controller for solid-only contact
plus fixed, deterministic blocked-flight candidate previews; it remains
support-free and ignores one-way terrain. Derf obstacle-top placement and all
other enemy/item spawn candidates now use one typed world-authority
request/result with a stable canonical diagnostic. Grounded enemies reuse
full-width capsule support, Unoco uses exact-point clearance, and procedural
items combine Éloïse-eligible support with complete upright-AABB clearance.
Placement remains outside per-tick motion and consumes no RNG. Atomic streaming
publication stays on the same `TerrainEdgeId` and geometry-version contracts.

Enemy intent and navigation run before the current tick's motion result exists,
so Phase 3 AI must deliberately read the previous tick's validated support.
Post-motion animation, snapshots, and other presentation consumers read the
new final support.

## Validation

The focused controller benchmark is:

```powershell
Push-Location packages/runner_core
dart compile exe tool/benchmark_slopes_phase2.dart `
  -o "$env:TEMP\rpg_runner_slopes_phase2.exe"
& "$env:TEMP\rpg_runner_slopes_phase2.exe" --strict `
  --warmup=1000 --iterations=5000 --harness-iterations=5000
dart --observe=0 --no-pause-isolates-on-exit --profiler run `
  tool/benchmark_slopes_phase2.dart --allocation-profile `
  --allocation-iterations=500
Pop-Location
```

It measures supported idle, ordinary slope traversal, maximum-speed
multi-contact, step, snap, one-way landing, overlap recovery, and matched flat
and sloped full-harness ticks against a 1280-edge fixture.

The closest-segment kernel writes its result in one unboxed pass. Initial
overlap recovery uses a recovery-only query that records the exact integer
separation floor and collision-skin correction without materializing floating
contact fields; parity with the full contact query is tested.

Allocation-sensitive ECS dispatch uses `moveAtValues(...)` and
`ResolvedMotionStore.beginTickValues(...)`, so a dynamic body does not create a
`TerrainMotionRequest` or wrapper capsule per tick. Immutable edges cache their
squared length, a conservative 1/1024-tick ceiling length, and GCD-reduced
finite-face projection factors at construction. Retained-support validation
therefore uses bounded integer products and exact rounded contact points
without `sqrt`, boxed `_Double`, or overflowing `_Mint` intermediates. A
grounded solve also skips continuous sweep only for its already-retained
support edge; connected or overlapping neighboring faces remain observable to
canonical contact/support selection. Flat, ordinary slope, long 3,000-unit
slope, endpoint, seam, and reviewed enemy-run tests cover these distinctions.

Connected-support transition facts use one controller-owned mutable scratch
and a one-entry cache keyed by source-edge identity, direction, and capsule
dimensions. Repeated actors sharing one immutable profile/controller therefore
do not recreate identical join geometry, while a different edge, direction,
or capsule size recomputes it. The reviewed enemy-run hash guards the cached
path against changing canonical contact or support selection.

All Phase 2 gates pass. The accepted AOT run reports controller p95/p99 of
`22/24 us`, a full slope-harness p99 of `36 us`, `2.81%` matched-flat
overhead, at most `16` candidates, bounded iterations, and zero buffer growth.
The paired VM profile tracks `_Double`, `_Mint`, terrain/capsule objects,
records, and wrapper capsules. It reports zero tracked hot-loop instances,
`0.0` allocations per solve, and no runner-core allocation callsites. Small VM
service/JIT-only `_Double` deltas are reported separately and count as hot-loop
allocations whenever trace sampling resolves a runner-core callsite. This
accepts the isolated controller authority; it does not authorize production
cutover before the remaining content, editor, replay, and rollout phases.

## Removal And Cutover

At the direct production cutover:

- normal Core construction must select the terrain authority,
- enemies and other dynamic policies must already be migrated,
- authored/streamed polygon geometry must be the shared source,
- live and replay-validator compatibility must be issued together,
- the temporary `terrainMotionHarness` selection seam and legacy motion adapter
  must be removed rather than retained as runtime alternatives.
