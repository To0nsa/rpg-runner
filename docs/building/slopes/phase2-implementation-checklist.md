# Slopes Phase 2 - Capsule Controller And Player Traversal Checklist

- Created: July 19, 2026
- Status: Accepted July 20, 2026; all Phase 2 functional, determinism,
  allocation, and performance gates pass
- Source plan: [plan.md](plan.md)
- Frozen gameplay decisions:
  [phase0-gameplay-decisions.md](phase0-gameplay-decisions.md)
- Frozen technical contracts:
  [phase0-technical-contracts.md](phase0-technical-contracts.md)
- Golden/performance specification:
  [phase0-golden-performance-spec.md](phase0-golden-performance-spec.md)
- Accepted geometry foundation:
  [phase1-implementation-checklist.md](phase1-implementation-checklist.md)
- Consumer inventory:
  [phase0-consumer-inventory.md](phase0-consumer-inventory.md)
- Implemented technical design:
  [terrain_capsule_controller.md](../../tdd/terrain_capsule_controller.md)

## Implementation Snapshot

Implemented and passing in the isolated Phase 2 authority:

- construction-time legacy versus terrain world-motion ownership with
  exactly-once audits and unsupported-body rejection
- Éloïse/Éloïse WIP capsule, traversal profile, support, and resolved-motion
  stores with exact derived AABB parity
- bounded recovery, continuous contact/slide, 60-degree support threshold,
  signed continuous speed curve, step, snap, one-way, peaks, valleys, and
  exact cross-polygon seams
- jump/coyote/buffer/air-jump, grounded/air mobility, launch/knockback,
  distance, absolute kill plane, animation phase, snapshots, diagnostics, and
  future ground-target query integration in the player harness
- versioned `contacts-v2` and `player-run-v1` golden signatures
- representative AOT timing, candidate, iteration, matched-flat overhead, and
  zero-buffer-growth budgets

Acceptance result:

- the reusable player controller and isolated Core terrain authority satisfy
  the frozen Phase 2 contracts
- normal production levels and replay construction intentionally remain on the
  legacy authority until the direct Phase 6 cutover
- Phase 3 enemy and navigation planning may proceed against this accepted
  actor-neutral controller

## 1) Goal And Exit Outcome

Implement the deterministic, actor-neutral capsule controller and prove
Éloïse's complete traversal contract against hand-authored Core terrain.

At Phase 2 acceptance:

- Core owns a validated upright world-contact capsule definition/store
- Core owns generalized support/contact and resolved-motion state
- a capsule moves through one bounded sweep, contact, slide, recovery, step,
  and snap pipeline
- one-way, endpoint, corner, seam, and slope-limit rules are deterministic
- Éloïse and Éloïse WIP pass the accepted player scenario matrix
- derived AABBs remain exact for combat, pickups, broad phase, culling, and
  render bounds
- jump, dash/roll, knockback, distance, camera, death, animation, projectile,
  targeting, snapshot, and replay implications have executable evidence or an
  explicit later-phase disposition
- the controller is reusable by Phase 3 enemy profiles without player-specific
  branches in collision math
- normal repository-backed levels still use the legacy static-world authority;
  Phase 2 does not perform the content/runtime cutover

Passing a single ramp test is not a Phase 2 completion condition.

## 2) Phase Boundary And Staged Authority

Phase 2 owns:

- actor capsule and traversal-profile definitions
- capsule, support/contact, and resolved-motion ECS stores
- actor-neutral capsule controller and reusable scratch buffers
- deterministic contact filtering, classification, move-and-slide, bounded
  overlap recovery, step-up, support probe, and ground snap
- player movement composition that consumes prior valid support
- player traversal harness using real Core movement, jump, mobility, gravity,
  animation, distance, camera, and death consumers where applicable
- contact/debug snapshots and Phase 2 deterministic signatures
- full player golden scenarios and controller performance evidence

Phase 2 does not:

- make polygon terrain authoritative for normal repository-backed level runs
- migrate `StaticSolid`, `StaticGroundPlane`, `StaticGroundSegment`, or
  `StaticGroundGap`
- migrate authored chunk/prefab schemas, generated content, streaming, ground
  rendering, or editor tools
- cut enemies, enemy navigation, pathfinding, spawn placement, teleport,
  flying steering, or enemy death behavior over to capsule terrain
- change ballistic projectiles to their final swept-circle terrain policy
- add a current ground-target player ability where none exists
- issue `gameCompatVersion = 2026.07.0`, `rules-v2`, or `ghost-v2`
- remove the legacy AABB collision implementation

### 2.1 One integration owner

- [x] Introduce one immutable `WorldMotionAuthority`-style dependency selected
      only when a Core/harness instance is constructed.
- [x] Make the normal `GameCore` constructor install a legacy adapter that
      delegates to the unchanged `CollisionSystem` with the same inputs and
      ordering.
- [x] Make a narrowly named test/tool traversal-harness factory install the
      terrain-capsule authority instead; do not expose the selection through
      level data, saved data, replay data, UI, or remote configuration.
- [x] Have the terrain authority route a body by its authoritative
      world-contact shape/component, not by entity ID or `isPlayer`.
- [x] In Phase 2, make that authority reject every enabled dynamic body that is
      not the explicitly supported capsule player. Phase 3 expands supported
      actor policies; Phase 6 replaces the legacy adapter.
- [x] Do not add a mutable runtime toggle, per-level JSON switch, remote-config
      switch, or per-tick legacy/new collision branch.
- [x] Assert that one body cannot be integrated by both the legacy AABB solver
      and the capsule controller in the same tick.
- [x] Assert that every enabled, non-kinematic harness body has exactly one
      recognized integration owner.
- [x] Keep the normal `GameCore` construction path behaviorally unchanged until
      the direct cutover phase.
- [x] Keep the traversal-harness factory outside the public gameplay barrel,
      document it as test/tool-only, and record the legacy adapter plus harness
      selection seam for removal at Phase 6.
- [x] Do not allow the terrain harness to silently fall back to rectangle
      collision for an unsupported body; fail the fixture with a deterministic
      diagnostic instead.

Gate:

- [x] A test proves that double integration, missing integration, and
      unsupported shape routing each fail deterministically.
- [x] A production-authority scan proves normal levels still use only the
      legacy terrain/collision path.

## 3) Entry Gate And Baseline

- [x] Re-read repository, Core, Core simulation, and replay-validator
      `AGENTS.md` guidance.
- [x] Re-read
      [change-core-simulation-contract.md](../../../.agent/workflows/change-core-simulation-contract.md).
- [x] Confirm Phase 0 and Phase 1 remain accepted with no open blocking row.
- [x] Record the starting revision and all unrelated dirty-worktree entries.
- [x] Verify the reviewed Phase 1 digests before controller work:
  - [x] `source-v1` =
        `88be670c79f41e1d984acd86f2d9529b8639d2c91e60ca3c863f21d9e3e3b2db`
  - [x] `edges-v1` =
        `84db4f4588286f76b2d7c504d8e71bd07be58ef9a79d2a1566f18353d84ce472`
  - [x] `contacts-v1` =
        `cb708e7cc2be7fb394016515393eb3461b3171a9028bfbe9b98cceb88bebf6b1`
- [x] Run and record the pre-Phase-2 baseline:
  - [x] `dart analyze packages/runner_core`
  - [x] `dart test packages/runner_core/test`
  - [x] focused root movement, platform, obstacle, gap, camera, determinism,
        and fixed-point tests
  - [x] fixed-point benchmark with and without track/autoscroll
  - [x] accepted Phase 1 representative and hard-stream slope benchmarks
- [x] Preserve baseline snapshots and expected values before changing a
      movement or support consumer.

Gate:

- [x] Every starting failure is classified and no unrelated failure is
      attributed to slopes.
- [x] The accepted geometry kernel/index still passes before controller work.

## 4) Required Core Types And Ownership

Use focused Core-owned types under the existing collision/terrain and ECS
domains. Exact filenames may follow a stronger existing naming convention, but
the responsibilities must remain separated.

| Area | Required responsibility |
| --- | --- |
| actor capsule definition/store | authoritative world-contact radius, vertical half-segment, and facing-aware offset |
| traversal profile | slope threshold, signed speed curve, step/snap policy, one-way policy, and mobility helper policy |
| support/contact store | final support identity and quantized contact data |
| resolved-motion store/result | actual per-tick displacement, support distance, contacts, and diagnostics |
| contact policy | solid/one-way filtering, endpoint filtering, walkability, wall, and ceiling classification |
| capsule controller | recovery, continuous sweep, move/slide, corner constraints, step, probe, snap, and final writes |
| scratch/buffers | reusable edge candidates, hits, normals, recovery candidates, and diagnostics |
| player harness | hand-authored terrain, commands, real player systems, consumers, signatures, and benchmarks |

- [x] Add a `WorldContactCapsuleStore`-style SoA component containing
      authoritative tick-grid capsule dimensions/offset.
- [x] Add a focused `TerrainContactStateStore`-style SoA component for support,
      contacts, geometry version, last-valid state, and diagnostics instead of
      overloading the four legacy booleans.
- [x] Add a focused `ResolvedMotionStore`-style SoA component/result for actual
      world displacement and supported travel.
- [x] Add one `WorldSupportView`-style read facade: terrain-integrated bodies
      read the terrain contact store; normal legacy bodies read
      `CollisionStateStore`.
- [x] Keep `CollisionStateStore` as the staged compatibility flag store.
      Derive its player flags from final terrain contacts only after the
      terrain result is complete.
- [x] Keep pure geometry operations in the Phase 1 kernel.
- [x] Keep gameplay policy out of `CapsuleSegmentKernel`.
- [x] Keep ECS iteration/state mutation out of the pure controller operation
      where practical.
- [x] Do not import Flutter or Flame into Core.
- [x] Do not key collision behavior on Éloïse's entity ID.
- [x] Make traversal differences data-driven through an immutable profile so
      Phase 3 can supply Grojib, Hashash, and flying policies.
- [x] Use integer physics ticks for authoritative capsule position,
      displacement, contact point, skin, step, snap, and stored support data.
- [x] Convert to world-unit `double` values only at existing ECS/API boundaries
      and quantize the authoritative result back through the frozen path.
- [x] Make the terrain controller's 1/1024 position/velocity quantization
      mandatory; the legacy `fixedPointPilot.enabled` flag must not select a
      second capsule algorithm or disable terrain quantization.

### 4.1 Numeric lock

Use the accepted constants without controller-local alternatives:

| Value | Frozen Phase 2 use |
| --- | --- |
| 1024 ticks/world unit | authoritative physics grid |
| 1 tick | geometry equality epsilon |
| 2 ticks | contact and equal-time tie epsilon |
| 64 ticks | collision skin |
| 64 world units | default terrain index cell width |
| 4 | maximum move/slide blocking contacts |
| 4 | maximum overlap-recovery iterations |
| one capsule radius | maximum recovery correction per tick |
| 8 + 8 | Phase 1 conservative advances plus bisection refinements |
| 4096 ticks | Éloïse step-up and support-snap limit |

- [x] Add no private epsilon, iteration cap, or alternative rounding rule in
      movement, support, one-way, step, snap, recovery, or targeting code.
- [x] Change a frozen value only through an explicit measured contract review,
      never to make one failing fixture pass locally.

### 4.2 Whole-player-slice harness

- [x] Construct the harness through the narrowly named terrain-motion
      `GameCore` test/tool factory selected in Section 2.1.
- [x] Compile `slopes_golden_v1` through the accepted Phase 1 compiler and
      index; never hand-build a second approximate collision representation.
- [x] Use a no-enemy/no-random-spawn level/track configuration for Phase 2
      player goldens so an unsupported actor cannot enter unnoticed.
- [x] Position the player through a capsule-clearance and support query; do not
      manufacture `grounded = true` without a valid support record.
- [x] Run the real command scheduling, ability activation, jump, movement,
      mobility, gravity, distance, death, camera, animation, snapshot, event,
      and resource systems instead of test copies of their logic.
- [x] Make the terrain motion result expose the actual resolved X delta used by
      Phase 2 progression. The temporary legacy adapter returns the historical
      velocity-times-delta value so normal-level behavior remains unchanged
      before cutover.
- [x] Keep normal TrackManager rectangle geometry completely outside terrain
      contact queries in the harness.
- [x] Add one controlled geometry-version replacement fixture for stale-support
      invalidation; otherwise geometry remains immutable during a scenario.
- [x] Fail immediately if a golden command unexpectedly creates an unsupported
      physics body.

## 5) Capsule Definition And Derived AABB Contract

### 5.1 Éloïse definitions

For both current player definitions:

```text
old halfX = 10.3
old halfY = 23.0
old offset = (-0.3, 1.0)

radius = 10.3
vertical half-segment = 12.7
derived AABB half extents = (10.3, 23.0)
```

- [x] Add an authored/derived world-contact capsule to the resolved player
      catalog without duplicating magic numbers.
- [x] Make authority-specific spawn assembly explicit: the Phase 2 terrain
      harness attaches capsule/contact/resolved-motion components, while the
      normal legacy `GameCore` path continues with its existing body, AABB, and
      collision physics components until direct cutover.
- [x] Apply the frozen mapping:
      `radius = old halfX`,
      `halfSegment = max(0, old halfY - radius)`.
- [x] Preserve the current facing-dependent X-offset rule exactly.
- [x] Preserve the authored Y offset exactly.
- [x] Retain the tick-start capsule center/facing and include any
      facing-offset change in the swept shape motion; a mid-contact turn may
      not teleport the capsule through an edge or begin behind a one-way.
- [x] Convert the resolved capsule-center result back to the entity transform
      without accumulating the authored offset into body position.
- [x] Validate finite offsets, positive radius, non-negative half-segment, and
      checked physics-grid conversion in release mode.
- [x] Make the AABB a named derived broad-phase/combat bound, not an
      authoritative terrain-contact shape.
- [x] Derive the AABB from the capsule in one place and prove exact equality to
      the existing player catalog values.
- [x] Keep separately authored ability hitboxes and projectile/pickup AABBs
      separate from the capsule-derived body AABB.
- [x] Update misleading API comments that still describe the player AABB as
      general world-collision authority.

Tests:

- [x] Éloïse and Éloïse WIP produce identical capsule and derived AABB values
- [x] both facing directions mirror only offset X
- [x] center, top, bottom, left, and right derived bounds match legacy values
- [x] invalid dimensions, non-finite offsets, and conversion overflow fail
- [x] circle degeneration remains valid for future actor profiles
- [x] combat broad phase, pickup overlap, cast-origin fallback, and
      behind-camera bound tests remain unchanged

## 6) Player Traversal Profile

Create an immutable profile owned by player tuning/catalog derivation.

- [x] Freeze maximum walkable slope at 60 degrees, inclusive.
- [x] Express runtime walkability as a quantized normal/dot threshold with no
      trigonometry in the per-body hot path.
- [x] Use the repository's Y-down convention explicitly:
      world-up is `(0,-1)` and world-down is `(0,1)`.
- [x] Prove the golden `(56,-97)` limit edge is walkable.
- [x] Prove the golden `(55,-97)` edge is over limit and wall-classified.
- [x] Freeze ordinary step-up at 4 world pixels.
- [x] Freeze support-preserving downward snap at 4 world pixels.
- [x] Freeze one-way support enabled and drop-through disabled.
- [x] Freeze grounded mobility step/snap enabled only when the activation
      started grounded.
- [x] Freeze ordinary jump direction as world-up.
- [x] Freeze Éloïse's solid policy to collide with support, both wall
      directions, and ceilings; `topOnlyGround` continues to describe the
      legacy ground plane and must not make polygon solid undersides/sides
      disappear.
- [x] Map the current enabled, kinematic, gravity, ceiling, and side-mask
      settings deliberately into the terrain body/profile policy rather than
      reinterpreting legacy booleans ad hoc inside the solver.
- [x] Store thresholds and multipliers as deterministic integer/fixed values.
- [x] Validate ordered control points, a 0-degree first point, a
      maximum-slope last point, and positive multipliers.

### 6.1 Signed slope-speed curve

| Absolute angle | Uphill target-X multiplier | Downhill target-X multiplier |
| ---: | ---: | ---: |
| 0 degrees | 100% | 100% |
| 30 degrees | 95% | 105% |
| 45 degrees | 85% | 110% |
| 60 degrees | 75% | 115% |

- [x] Implement continuous deterministic interpolation between adjacent
      control points; do not implement hard angle tiers.
- [x] Build a canonical-order traversal cache beside the immutable edge list
      whenever its geometry version is published.
- [x] Precompute each edge's absolute slope angle in fixed units of
      `1/1024 degree` with one centralized 24-iteration integer CORDIC
      implementation; do not use platform trigonometric output as
      authoritative state.
- [x] Snap direction-threshold equality to its authored control angle so the
      accepted quantized 30/45/60-degree boundaries evaluate exactly,
      including `(56,-97)` at 60 degrees.
- [x] Integer-interpolate multiplier basis points from that cached angle; do
      not add the derived cache value to stable edge identity or the reviewed
      `edges-v1` digest.
- [x] Do not call `atan`, `atan2`, `acos`, or other trigonometry in the
      per-player tick loop.
- [x] Classify uphill/downhill relative to requested horizontal travel, not
      edge authoring direction or facing alone.
- [x] Apply the multiplier to non-zero target horizontal speed before the
      existing acceleration/deceleration approach.
- [x] Keep existing acceleration, deceleration, input authority, gear/status
      speed multipliers, stamina, and maximum-velocity ordering unchanged.
- [x] Do not multiply the zero target during release/deceleration.
- [x] Use only prior valid support whose geometry version still matches;
      landing support affects ordinary slope speed beginning on the next tick.
- [x] Do not apply the ordinary curve in the air or during active grounded
      dash/roll.

Tests:

- [x] exact 0/30/45/60 control points in both travel directions
- [x] intermediate angles on each interval, including mirrored edges
- [x] fixed-angle derivation repeats across fresh processes and is monotonic
      from flat through 60 degrees
- [x] reverse direction on the same edge switches uphill/downhill
- [x] zero input, acceleration, deceleration, and stop thresholds
- [x] gear haste/slow composition order remains intentional
- [x] 60-degree consequences remain accepted: 150% flat surface speed uphill
      and 230% downhill before the animation-rate clamp

## 7) Contact Filtering And Classification

### 7.1 Solid edges

- [x] Query the swept capsule AABB expanded by frozen skin/contact tolerance.
- [x] Evaluate candidates in canonical edge-ID order.
- [x] Accept the earliest valid continuous contact.
- [x] Preserve the Phase 1 inclusive `2/1024` contact boundary when ranking
      endpoint tangencies.
- [x] Collect equal-time contacts within tie epsilon in canonical ID order.
- [x] Classify walkable support, steep wall, other wall, and ceiling through
      quantized normals and the active profile.
- [x] A steep surface never grounds Éloïse.
- [x] At a floor-to-wall corner, report support plus wall when both contacts
      fall within tie epsilon; do not choose a nondeterministic winner.

### 7.2 One-way edges

- [x] Accept contact only when the tick-start capsule support point is on the
      outward/collidable side by at least contact epsilon.
- [x] Require approaching or crossing the edge plane.
- [x] Require the contact projection to lie on the finite edge.
- [x] Let a capsule already behind the edge leave without recovery.
- [x] Apply the same previous-side rule to endpoint radial contacts.
- [x] Never convert an exposed endpoint into a side wall.
- [x] Never let step-up climb the one-way endpoint from the side.
- [x] Treat one-way surfaces as support only when they also satisfy Éloïse's
      slope profile.
- [x] Preserve no-drop-through behavior.

### 7.3 Vertices, adjacency, and seams

- [x] Use `previousId`, `nextId`, `startJoin`, and `endJoin` to reject ghost
      endpoint normals that would snag a continuous edge chain.
- [x] Preserve exposed convex corners and intentional ledges.
- [x] Treat compatible smooth/connected walkable vertices as one traversal
      continuation without averaging unrelated normals.
- [x] Apply a two-normal corner constraint for non-parallel simultaneous
      blockers.
- [x] Prevent alternating resolution between the same corner edges.
- [x] Cross exact stitched chunk endpoints without a false wall, support loss,
      or airborne animation frame.

Tests:

- [x] face and both endpoint hits on flat, slope, wall, and ceiling
- [x] clockwise/counter-direction travel over identical compiled geometry
- [x] smooth vertex, convex peak, concave valley, exposed ledge, and exact seam
- [x] solid/one-way overlap at the same X
- [x] one-way pass from below, land from above, traverse, depart, and endpoint
- [x] equal-time floor/wall and two-wall contacts
- [x] canonical result under reversed candidate insertion/query traversal

## 8) Initial Overlap And Last-Valid State

Edge proximity alone cannot detect a capsule placed deep inside a large solid
polygon. Recovery must therefore include deterministic solid containment
classification, not only nearby-edge overlap.

- [x] Add the minimum reusable polygon-containment/index support required to
      find solid polygons containing the capsule/spine.
- [x] Keep one-way back-side containment out of solid penetration recovery.
- [x] Gather recovery candidates in stable polygon/edge-ID order.
- [x] Run at most 4 recovery iterations.
- [x] Limit total correction in one tick to one capsule radius.
- [x] Never recover through a blocking edge or across a polygon to an unrelated
      surface.
- [x] Track a quantized last-valid transform for every terrain-integrated body.
- [x] On recovery failure, restore the last-valid transform, clear support,
      zero only unsafe entering motion as specified by the controller result,
      and emit a deterministic debug/test diagnostic.
- [x] Never teleport to a distant nearest surface.
- [x] Require initial harness spawn placement to validate capsule clearance
      before seeding last-valid state.

Tests:

- [x] shallow floor, wall, ceiling, corner, and sloped penetration
- [x] deep placement inside a large solid with no edge in capsule bounds
- [x] more-than-one-radius and iteration-exhaustion failures
- [x] one-way back-side overlap is not recovered
- [x] multiple equal recovery candidates use canonical identity
- [x] failure is repeatable and never writes non-finite state

## 9) Move-And-Slide Controller

### 9.1 Requested-motion semantics

One generic vector projection is not sufficient for all accepted movement:
projecting a horizontal run vector onto a 60-degree tangent would incorrectly
quarter its horizontal component, while projecting grounded gravity would make
an idle player slide downhill.

- [x] Tag composed motion with one actor-neutral mode:
  - [x] `groundedHorizontal`: ordinary locomotion whose tuned world-X component
        is authoritative
  - [x] `groundedSurface`: grounded dash/roll whose distance-along-surface
        component is authoritative
  - [x] `worldSpace`: airborne movement, landing velocity, knockback, launch,
        and other authored world-space motion
- [x] For `groundedHorizontal`, convert the accepted world-X displacement to
      the prior eligible support tangent while preserving that X component;
      the support tangent supplies the required Y component.
- [x] At a connected eligible support transition, reorient the remaining
      `groundedHorizontal` displacement to the new tangent while preserving
      unresolved X, subject to the new edge's walkability.
- [x] For `groundedSurface`, preserve unresolved scalar surface distance when
      reorienting across connected eligible support.
- [x] For `worldSpace`, keep the authored vector and use ordinary entering
      component projection when a blocker is hit.
- [x] If preserved support is lost, convert the unresolved/final result to
      world-space without adding a normal launch impulse.
- [x] Carry the gravity contribution separately from authored/control
      velocity through motion composition.
- [x] While final eligible support is retained, consume grounded gravity as
      contact bias and do not project it into downhill tangent speed.
- [x] When support is genuinely lost, retain the normal gravity contribution
      so falling begins without a one-tick hover.
- [x] Preserve tangential airborne landing velocity after removing only the
      component entering the support.
- [x] Keep over-limit and near-vertical tangent guards on integer thresholds;
      never divide by an ineligible tangent X component.

Tests:

- [x] ordinary 30/45/60-degree motion preserves the accepted target X
- [x] grounded dash/roll preserves authored surface distance at 30/45/60
- [x] stationary player on 30/45/60-degree support has no downhill drift
- [x] move-locked/stunned supported player has no gravity-driven slide
- [x] ledge departure receives gravity on the first unsupported tick
- [x] airborne landing and knockback retain only valid tangential world-space
      motion

### 9.2 Solve sequence

For one fixed tick:

1. read tick-start support and geometry version
2. compose quantized requested displacement from authoritative velocity
3. recover an invalid initial overlap if required
4. query the expanded swept AABB
5. find the earliest allowed contact
6. advance to contact minus frozen skin
7. collect equal-time blockers and apply the correct slide/corner constraint
8. project only the entering component from remaining displacement and velocity
9. repeat for at most 4 contact iterations
10. attempt at most one eligible step sequence when ordinary movement is
    ledge-blocked
11. resolve final support probe/snap
12. quantize and atomically write transform, velocity, support, resolved
    displacement, contact compatibility, last-valid state, and diagnostics

- [x] Do not integrate position outside the selected world-motion owner.
- [x] Keep continuous sweep as the normal high-speed path.
- [x] Treat discrete end overlap only as a diagnostic/recovery condition.
- [x] Consume no more than 4 blocking contact iterations.
- [x] Preserve tangent motion while removing only velocity entering a blocker.
- [x] Do not create energy through repeated projection or quantization.
- [x] Do not discard unresolved displacement silently on iteration exhaustion;
      record a deterministic diagnostic and safe final state.
- [x] Store actual resolved world displacement and distance along eligible
      support for downstream consumers.
- [x] Quantize all final authoritative fields at the frozen 1/1024 boundary.
- [x] Reuse query, hit, contact, normal, and recovery buffers with zero
      steady-state allocation.

Tests:

- [x] zero displacement and stationary support
- [x] free fall and free horizontal movement
- [x] single floor, wall, ceiling, and slope
- [x] floor-wall and ceiling-wall corners
- [x] maximum ordinary speed, maximum velocity clamp, dash speed, fall speed,
      and knockback speed without tunneling
- [x] repeated long-run contact has no positional drift
- [x] fixed iteration exhaustion produces the frozen safe failure
- [x] mirrored geometry and negative world coordinates

## 10) Support, Probe, Snap, And Contact State

The final terrain contact store records at minimum:

- grounded
- support edge ID
- support point
- support normal
- support tangent
- support geometry version
- last valid support tick
- blocking wall and ceiling normals or derived compatibility flags
- tick-start support/snap eligibility
- deterministic controller diagnostic code/counters

- [x] Make the capsule controller the sole normal-tick writer of final terrain
      support.
- [x] Define `grounded` as final contact/probe with a profile-eligible support,
      not proximity to any upward-facing edge.
- [x] Validate support identity against the current geometry version before
      movement and before AI/consumer reads.
- [x] Clear stale support when its edge is absent after a version change.
- [x] Direct the ordinary support probe world-down.
- [x] Allow snap only when support was valid at tick start, geometry still
      matches, and requested vertical velocity is not upward.
- [x] Limit snap to 4 world pixels.
- [x] Never snap upward.
- [x] Never cross a blocking solid or one-way back face while snapping.
- [x] Select the first eligible support by contact priority and canonical edge
      ID.
- [x] Do not let snap acquire ground for an actor that began the tick airborne.
- [x] Keep support over small descending transitions and convex peaks only
      while the eligible surface remains within snap range.
- [x] On a larger departure, preserve resolved velocity, clear grounded, and
      begin coyote timing on that first unsupported tick.
- [x] Resolve concave valleys without bounce or normal impulse.
- [x] Derive `hitLeft`, `hitRight`, and `hitCeiling` compatibility values for
      existing readers; new terrain logic reads normals.

Support-clearing tests:

- [x] accepted jump
- [x] upward launch/knockback
- [x] teleport before validation
- [x] body disable
- [x] transition to kinematic ownership
- [x] death transition when motion no longer resolves
- [x] geometry-version mismatch

## 11) Automatic Step-Up

- [x] Attempt step-up only for an actor that began the tick on valid support.
- [x] Attempt it only after ordinary horizontal/tangent motion is blocked by a
      candidate ledge.
- [x] Permit one deterministic step attempt per body per tick.
- [x] Sweep up by at most 4 pixels and reject any ceiling contact.
- [x] Sweep the unresolved forward component without teleporting.
- [x] Sweep down to the first eligible walkable support.
- [x] Require complete capsule clearance for the up, forward, and down path.
- [x] Require the final support to be connected/reachable without crossing a
      blocker.
- [x] Reject 4-pixels-plus-epsilon, 8-pixel, and 16-pixel obstacles.
- [x] Reject steep faces and one-way endpoints as step initiators.
- [x] Reject airborne ordinary movement.
- [x] Permit the helper for a grounded-started dash/roll under the same
      clearance rules.
- [x] Do not recursively step or chain multiple ledges in one tick.

Tests:

- [x] 0, just-below-4, exact-4, and just-above-4 heights
- [x] blocked overhead, blocked forward path, narrow landing, and steep landing
- [x] solid step from both directions
- [x] one-way endpoint cannot be climbed
- [x] grounded dash/roll may step; airborne-started mobility may not
- [x] high speed cannot use the helper to bypass a taller obstacle

## 12) Jump, Mobility, Knockback, And Body Lifecycle

### 12.1 Jump

- [x] Make jump read the authoritative support facade for a terrain-integrated
      player while preserving legacy collision reads on normal levels.
- [x] Preserve coyote time, jump buffering, air-jump count, resource costs,
      cooldown behavior, and velocity clamps.
- [x] Clear support and snap eligibility before applying an accepted jump.
- [x] Apply the ordinary jump impulse in world-up only.
- [x] Add no support-normal or horizontal slope impulse.
- [x] Prove landing does not consume a buffered jump until the existing
      documented tick.
- [x] Prove jump takeoff cannot be recaptured by the same-tick support probe.

### 12.2 Grounded dash/roll

- [x] Latch whether mobility began grounded at activation/commit time.
- [x] Resolve grounded-started movement along the eligible support tangent in
      the chosen horizontal direction.
- [x] Select that horizontal direction from the committed mobility X sign;
      when committed X is within the existing direction epsilon (including a
      vertical-only aim), use the committed facing. A grounded-started
      vertical aim must not become an upward/downward launch.
- [x] Preserve authored speed and distance along the terrain surface.
- [x] Do not apply the ordinary run slope-speed curve to active mobility.
- [x] Keep ability duration, resource cost, cooldown, impact behavior, control
      locks, and animation timing unchanged.
- [x] Keep Éloïse's art upright.
- [x] Stop/slide against an over-limit surface as a wall.
- [x] Allow the accepted 4-pixel step and snap helpers only for a
      grounded-started activation.
- [x] Preserve existing world-space direction and deny both helpers when the
      activation began airborne, even if it lands before ending.

### 12.3 Knockback, disable, kinematic, and death

- [x] Send knockback/launch motion through the same capsule controller.
- [x] Clear snap eligibility for an upward launch.
- [x] Preserve collision against floor, wall, and ceiling without added launch
      energy.
- [x] Define whether a disabled body freezes velocity or merely skips motion
      from the existing body contract; do not invent a slope-only exception.
- [x] Clear support before an ownership change to disabled/kinematic.
- [x] Keep death animation freeze and run-end sequencing intentional.
- [x] Record player falling/death behavior separately from Phase 3
      enemy-falling-until-ground behavior.
- [x] Treat `GameCore.setPlayerPosXYUnsafeForTest` as an explicit test mutation:
      clear support and snap before the write and never retain an old
      last-valid support identity at the new location.
- [x] Keep unsafe overlap setup in a clearly test-only helper. No production
      player teleport exists; Phase 3 Hashash teleport and any future gameplay
      placement must validate full destination clearance before committing.
- [x] Make an externally applied upward `setPlayerVelXY`/launch clear snap
      eligibility before the next terrain solve.

## 13) System Ordering And Consumer Audit

Freeze the Phase 2 harness order:

1. publish immutable terrain geometry/index and geometry version
2. refresh timers, locks, active ability phases, and held/charged state
3. read prior valid support for movement decisions
4. activate abilities and compose jump, ordinary movement, mobility,
   knockback, and gravity velocity
5. integrate the player exactly once through the capsule controller
6. publish final support/contact and resolved-motion state
7. update distance, death, camera, pickups/broad phase, projectile policy,
   animation, and snapshots at their documented points

- [x] Write a before/after dependency table in the implementation evidence.
- [x] Document that Phase 3 AI intentionally reads prior-tick support because
      current support does not exist before motion resolution.
- [x] Keep broad-phase rebuild after final authoritative transforms.
- [x] Ensure animation and snapshots read final post-solver support.
- [x] Ensure no consumer reads partially written support/contact state.

### 13.1 Required consumer dispositions

| Consumer | Phase 2 required behavior |
| --- | --- |
| ordinary movement | prior-support signed curve modifies target X before existing acceleration/deceleration |
| jump | reads support facade; clears terrain support/snap before impulse |
| mobility | latches grounded start; tangent motion for grounded dash/roll |
| gravity | composes velocity before the one controller solve |
| knockback/status locks | motion resolves through capsule; lock semantics unchanged |
| distance/score | harness uses positive actual resolved world-X displacement, not requested velocity |
| camera | reads final player transform; vertical mode behavior remains authored |
| pit death | harness uses absolute `killPlaneY`, never terrain height under player |
| behind-camera death | keeps the derived AABB right-bound rule |
| pickups/combat broad phase | keeps derived AABB overlap |
| caster/melee/projectile origin | preserves explicit offsets and derived-AABB fallback |
| projectile world collision | remains on its classified legacy policy; never capsule-routed accidentally |
| animation | final support selects ground/air; locomotion loop uses resolved support distance |
| entity snapshot | grounded comes from final support facade |
| public/HUD grounded | `GameCore.playerGrounded`, jump affordability, and HUD state use the same support facade |
| unsafe test mutation | `setPlayerPosXYUnsafeForTest` clears support/snap; upward velocity clears snap; gameplay destinations require authority-owned clearance |
| terrain debug snapshot | exposes quantized capsule, contacts, support, version, and counters |
| future ground target | pure Core resolver only; no production ability is invented |
| achievements/progression | consume final distance, score, events, kills, and end reason; own no terrain logic |

- [x] Add a focused regression test for every row changed in implementation.
- [x] Record every row intentionally deferred and its owning later phase.

## 14) Distance, Score, Camera, Death, And Bounds

- [x] Record tick-start and final player transforms in resolved-motion state.
- [x] Accumulate Phase 2 distance from
      `max(0, finalPosX - startPosX)`.
- [x] Do not count distance requested into a wall.
- [x] Do not count vertical or surface distance as run distance.
- [x] Prove accepted uphill/downhill X-speed changes flow naturally into
      distance and score.
- [x] Keep the score formula and `score-v1` unchanged.
- [x] Keep camera update after final capsule motion.
- [x] Test locked-Y and follow-player camera behavior over slopes, step, snap,
      jump, and pit fall.
- [x] Use `killPlaneY = 480` in `slopes_golden_v1`.
- [x] Add an optional absolute `killPlaneY` to the Core level definition and
      resolve an omitted value for legacy levels to the exact existing default
      `groundTopY + gapKillOffsetY`; do not migrate authored content yet.
- [x] Keep behind-camera death based on the exact capsule-derived AABB right
      bound.
- [x] Keep pickups, restoration, combat overlaps, and temporary hitboxes on
      AABBs and prove their bounds did not change.
- [x] Do not replace enemy below-world culling in Phase 2; assign it to
      Phase 3/5 as recorded in the consumer inventory.

Flat-parity evidence must distinguish:

- exact parity expected on unobstructed flat ground, floor landing, platform
  top, walls away from corners, camera, resources, and command scheduling
- intentional change at rounded capsule corners and terrain-support metadata
- Phase 2 harness-only behavior that cannot alter normal-level replay output
  before direct cutover

## 15) Animation And Render-Facing State

- [x] Use final support, not vertical velocity, to select grounded versus
      airborne animation for a terrain-integrated player.
- [x] Keep supported ascent, descent, 4-pixel step, and snap in grounded
      idle/walk/run or the active grounded mobility animation.
- [x] Clear support immediately for an accepted jump.
- [x] Allow natural ledge departure to select jump/fall through the existing
      vertical-velocity rule.
- [x] Keep player sprites upright; do not add rotation to
      `EntityRenderSnapshot`.
- [x] Preserve horizontal facing and authored art-facing behavior.
- [x] Add a deterministic grounded-locomotion phase accumulator driven by
      actual resolved distance along eligible support.
- [x] Define supported travel as the absolute tangential component of accepted
      resolved motion while support is valid. Exclude recovery correction,
      snap distance, and the vertical clearance/down legs of step-up; a
      successful step counts only its accepted forward supported travel.
- [x] Normalize walk/run playback against authored flat-ground locomotion
      speed.
- [x] Continuously clamp the resulting authored-rate multiplier to
      0.75x-1.50x.
- [x] Do not advance the grounded locomotion loop while blocked with zero
      resolved support distance.
- [x] Do not change timing for idle, jump/fall, dash/roll, attacks, casts, hit,
      spawn, stun, or death.
- [x] Do not let playback scaling alter ability windows or simulation timing.
- [x] Keep the existing renderer's deterministic `animFrame` consumption;
      Core remains the phase authority.
- [x] Use one fixed-point locomotion phase across walk/run transitions, pause
      it during idle, actions, and airborne states, and resume it without
      resetting gameplay or action animation clocks.

Tests:

- [x] no airborne flicker over every flat/slope transition and exact seam
- [x] true support loss selects air state on the first unsupported tick
- [x] walk/run phase follows resolved support distance uphill/downhill
- [x] downhill 60-degree playback clamps to 1.50x
- [x] pushing into a wall does not advance locomotion phase
- [x] all action and lifecycle animations retain existing authored frame timing

## 16) Snapshots, Diagnostics, And Signatures

### 16.1 Runtime/render snapshot

- [x] Preserve existing entity position, velocity, facing, size, grounded,
      animation, and frame semantics.
- [x] Resolve player `grounded` from the support facade when terrain capsule
      authority is active.
- [x] Keep `size` equal to the exact derived AABB.
- [x] Do not expose mutable ECS or controller objects.

### 16.2 Debug/test snapshot

Add an immutable Core-owned diagnostic record behind the existing debug/test
boundary containing:

- entity ID and tick
- capsule center/radius/half-segment
- requested and resolved displacement
- final quantized transform/velocity
- geometry version
- grounded and support edge ID
- support point/normal/tangent
- ordered blocking contact IDs/normals/features
- wall/ceiling compatibility values
- step/snap/recovery use
- contact/recovery iteration counts
- candidate/query counters
- deterministic diagnostic code

- [x] Keep debug snapshots one-way from Core to render/tests.
- [x] Do not make Flame classify slope, support, or one-way state.
- [x] Do not add production per-tick allocation merely to populate disabled
      debug data.

### 16.3 Deterministic signatures

- [x] Extend the reviewed contact signature through a new explicitly versioned
      record rather than silently changing `contacts-v1`.
- [x] Include tick, entity, quantized transform/velocity, support identity and
      geometry version, normals/tangent, ordered contacts, step/snap/recovery,
      and diagnostics.
- [x] Add a player-run signature containing seed, character, ordered commands,
      contact checkpoints, final tick/transform/resources, distance, score,
      events, run reason, and RNG state.
- [x] Use stable UTF-8 length-prefixed records and SHA-256.
- [x] Keep unordered maps/sets, object `hashCode`, formatted doubles, and debug
      text out of canonical records.
- [x] Require an explicit update command for reviewed golden files.
- [x] Treat any Phase 1 source/edge/contact digest change as a separate reviewed
      compatibility finding.

## 17) Future Ground-Target Query

No current player ability uses `TargetingModel.groundTarget`. Phase 2 must not
add a fake production ability or change existing projectile/melee previews.

- [x] Implement the reusable pure Core terrain query needed by a future
      ground-target resolver:
  - [x] derive desired endpoint from cast origin, normalized aim, and authored
        range
  - [x] probe world-down by an authored maximum distance
  - [x] select the first solid or one-way top support walkable by the player
  - [x] enforce final cast range
  - [x] use canonical candidate/edge tie order
  - [x] reject solid line-of-sight blockers
  - [x] apply one-way blocking only from its collidable side
  - [x] return immutable exact resolved point, support ID/version, and validity
- [x] Rerunning the query against unchanged geometry returns the exact same
      result.
- [x] A geometry-version change cannot redirect a committed stale result
      without revalidation.
- [x] Record preview/HUD and resource/cooldown commit integration as deferred
      until a real authored player ability consumes the contract.
- [x] Keep Derf's predicted-player-center target unchanged.

`SG-P10` closes in Phase 2 for geometry resolution, line of sight, identity,
and revalidation. Its production preview/cost/cooldown portion remains
explicitly non-applicable until a real player ground-target ability exists.

## 18) Projectile, Combat, Pickup, And Ability Audit

- [x] Prove the capsule-derived AABB remains the player combat/trigger bound.
- [x] Prove broad-phase target ordering is unchanged.
- [x] Prove melee, projectile, and hitbox origin fallback values are unchanged.
- [x] Prove pickup and restoration overlap behavior is unchanged on equivalent
      player transforms.
- [x] Classify every `usePhysics` projectile as legacy AABB in Phase 2 and
      future swept-circle at final terrain integration.
- [x] Ensure `ProjectileSystem` still skips physics-owned projectiles.
- [x] Ensure the Phase 2 terrain harness either contains no unsupported
      ballistic projectile or fails explicitly; it may not move one twice.
- [x] Preserve `ProjectileWorldCollisionSystem` compatibility flags on the
      normal legacy path.
- [x] Keep mobility-impact dynamic overlap AABB-based while the owner motion
      uses the capsule.
- [x] Run current ability resource, cooldown, hold, charge, melee, ranged,
      mobility-impact, and targeting regression tests touched by support or
      transform changes.

## 19) Enemy, Navigation, Spawn, And Streaming Handoff

Phase 2 must leave an executable, actor-neutral foundation for Phase 3 and a
complete handoff. It must not quietly specialize the controller so only the
player can use it.

- [x] Capsule controller accepts a traversal/contact profile rather than
      reading player tuning directly.
- [x] Support/contact identity uses stable terrain edge IDs and geometry
      versions usable by surface-chain navigation.
- [x] Clearance, stationary overlap, support probe, line-of-sight, and swept
      capsule queries are reusable without an ECS player component.
- [x] Resolved support exposes exact point, tangent, normal, and edge identity
      needed by enemy locomotion and graph location.
- [x] Motion diagnostics distinguish blocked wall, ceiling, unsupported,
      invalid geometry version, recovery failure, and iteration exhaustion.
- [x] The dispatcher has an explicit unsupported-policy result for:
  - [x] grounded enemies awaiting Phase 3 profiles
  - [x] Unoco Demon flying contact
  - [x] Derf kinematic clearance
  - [x] Hashash teleport validation
  - [x] ballistic projectiles awaiting swept-circle ownership
- [x] Normal legacy enemies remain untouched and continue passing their
      current navigation/collision tests.
- [x] No enemy receives Éloïse's 60-degree threshold or slope-speed curve by
      default.
- [x] Record Phase 3 prerequisites:
  - [x] Grojib 45-degree profile and 4-pixel helpers
  - [x] Hashash 60-degree profile, 4-pixel helpers, and teleport clearance
  - [x] constant distance-along-surface enemy speed
  - [x] walkable edge-chain extraction and shared IDs
  - [x] standability, jump/drop, trajectory, path, and stream invalidation
  - [x] flying solid blocking/one-way ignore
  - [x] Derf placement and all spawn-clearance policies
  - [x] enemy death/support and culling
- [x] Do not create the Phase 3 implementation checklist until Phase 2
      evidence and findings are accepted.

Later-phase decision traceability:

| Accepted IDs | Preserved owner |
| --- | --- |
| `SLP-P0-002a`, `SLP-P0-002b`, `SLP-P0-002c` | Phase 3 Grojib profile, helpers, locomotion, and graph costs |
| `SLP-P0-002d`, `SLP-P0-002e`, `SLP-P0-002f`, `SLP-P0-014a` | Phase 3 Hashash profile, helpers, locomotion, and ambush clearance/fallback |
| `SLP-P0-002g`, `SLP-P0-002h` | Phase 3 Unoco local hover reference and solid/one-way contact policy |
| `SLP-P0-002i`, `SLP-P0-014b` | Phase 3 Derf support/clearance placement |
| `SLP-P0-014c` | Phase 3/5 player, enemy, pickup, and restoration spawn eligibility |

## 20) Player Golden Scenario Matrix

Implement every Phase 2-applicable player scenario from
`slopes_golden_v1`.

Accepted player-decision traceability:

| Accepted ID | Owning checklist evidence |
| --- | --- |
| `SLP-P0-001` | Sections 6, 7, and `SG-P03`/`SG-P07` |
| `SLP-P0-003` | Section 6.1 and `SG-P02`/`SG-P03` |
| `SLP-P0-004a`, `SLP-P0-004b` | Section 11 and `SG-P05` |
| `SLP-P0-004c` | Section 10 and `SG-P02`/`SG-P05` |
| `SLP-P0-005` | Sections 7.3/10 and focused peak/valley cases |
| `SLP-P0-006` | Section 7.2 and `SG-P09` |
| `SLP-P0-019a` | Section 12.1 and `SG-P04` |
| `SLP-P0-019b`, `SLP-P0-019c`, `SLP-P0-019d` | Section 12.2 and `SG-P05` |
| `SLP-P0-020` | Section 15 and support-transition goldens |
| `SLP-P0-021` | Section 15 animation phase/rate evidence |
| `SLP-P0-022` | Section 17 and the Phase 2-applicable part of `SG-P10` |

| ID | Phase 2 acceptance |
| --- | --- |
| `SG-P01` | 180 stationary flat ticks: stable support ID, no drift, grounded idle |
| `SG-P02` | hold right then left across ordinary slopes: start/stop/reverse, no snag or air flicker |
| `SG-P03` | normal and maximum speed: no tunneling, exact signed speed curve |
| `SG-P04` | jump at flat/ascent/descent/ledge with buffer, coyote, and air jump |
| `SG-P05` | grounded dash/roll both directions: tangent distance plus 4-pixel helpers |
| `SG-P06` | knockback into floor, steep wall, and ceiling |
| `SG-P07` | land on 30/45/60-degree support at low/run/max fall velocity |
| `SG-P08` | natural pit departure, coyote, and absolute kill-plane run end |
| `SG-P09` | one-way slope pass from below, land/traverse above, no endpoint wall |
| `SG-P10` | future target query resolution/LOS/revalidation; production ability commit remains N/A |
| `SG-P11` | repeat command fixture: contact checkpoints and final run signature match |
| `SG-P12` | repeat applicable cases for Éloïse and Éloïse WIP |

Executable evidence:

| IDs | Focused evidence |
| --- | --- |
| `SG-P01`-`SG-P09` | `terrain_game_core_harness_test.dart` has the named two-character smoke matrix plus focused stationary, traversal, speed, jump, mobility, impact, landing, pit, and one-way cases. |
| `SG-P10` | `terrain_ground_target_resolver_test.dart` covers resolution, LOS, identity, and revalidation. Production preview/commit is N/A because no authored player ground-target ability exists; its eventual owning feature must consume this resolver contract. |
| `SG-P11` | `terrain_player_signatures_test.dart` repeats checkpoints and run signatures across fresh Core instances and Dart processes. |
| `SG-P12` | The harness smoke matrix runs both `eloiseCharacter` and `eloiseWipCharacter`; signatures also repeat independently for both definitions. |

Add focused cases beyond the golden:

- [x] exact and over-limit slope normals
- [x] flat/slope/flat in both directions
- [x] convex peak inside and outside snap range
- [x] concave valley at low and maximum speed
- [x] 4-pixel step success and every rejection reason
- [x] exact chunk seam and intentional ledge
- [x] ceiling/underside contact
- [x] grounded vertical-only mobility aim uses facing tangent; the equivalent
      airborne-started aim preserves its existing vertical world-space motion
- [x] initial overlap success/failure
- [x] geometry-version support invalidation
- [x] disable/kinematic/support lifecycle
- [x] negative coordinates and mirrored facing offset
- [x] reverse facing while supported, beside a wall, at a one-way edge, and
      with the authored `-0.3` X offset
- [x] equal-TOI and reordered-input determinism

Gate:

- [x] No scenario is skipped with a broad “covered elsewhere” claim.
- [x] Any truly non-applicable assertion names the missing production feature
      and later owning phase.

## 21) Determinism, Replay, And Compatibility

- [x] Run every golden from two fresh harness/Core instances.
- [x] Repeat in one process and in fresh processes.
- [x] Apply commands only at `tick + 1` through the existing command contract.
- [x] Preserve replay blob version 1 and command encoding version 1.
- [x] Add no terrain geometry to replay payloads.
- [x] Prove command order, RNG consumption, resources, events, distance, score,
      and run end are stable in the Phase 2 fixture.
- [x] Keep the normal legacy `GameCore` determinism fixtures byte/field stable
      unless an intentional non-authority refactor is separately reviewed.
- [x] Do not issue the reserved compatibility/ruleset/ghost versions.
- [x] Record that live-client/replay-validator parity, ticket draining, board
      provisioning, and deployed-content matching remain Phase 7 gates.
- [x] If a shared production `GameCore` API or step order changes, run the
      replay validator analyzer/tests and update its TDD impact assessment.
- [x] Do not accept an old ticket under new slope physics in any test helper.

The Phase 2 harness proves deterministic controller behavior. It does not
authorize mixed production physics or compatibility issuance.

## 22) Allocation, Capacity, And Performance

Extend the existing slope benchmark or add a focused player-controller mode.

- [x] Warm query, contact, recovery, and controller buffers before measuring.
- [x] Measure separately:
  - [x] single supported idle solve
  - [x] ordinary slope traversal solve
  - [x] maximum-speed multi-contact solve
  - [x] step-up solve
  - [x] support snap solve
  - [x] one-way landing
  - [x] overlap recovery
  - [x] full Phase 2 player-harness tick
- [x] Measure matched flat polygon and representative slope fixtures.
- [x] Use the accepted 1280-edge representative active set.
- [x] Include the 5120-edge hard-stream query safety case where relevant.
- [x] Report p50/p95/p99/max, candidates, contacts, recovery iterations,
      step/snap counts, buffer resize count, and diagnostics.
- [x] Add VM/profile-build heap evidence around the complete per-body solve,
      closing the Phase 1 profiling handoff.
- [x] Prove zero steady-state allocations per player terrain solve.
- [x] Never truncate candidates or contacts to meet a budget.

Phase 2 gates:

- [x] dynamic actor solve p95 <=75 us/body
- [x] dynamic actor solve p99 <=150 us/body
- [x] player candidates p95 <=24
- [x] player candidates p99 <=64
- [x] full representative slope harness/Core tick p99 <=2 ms
- [x] full tick hard-gate p99 <4 ms
- [x] full tick <=25% overhead versus matched flat fixture
- [x] zero steady-state terrain-query/controller allocations
- [x] no unbounded loop, recursion, or per-tick buffer growth

Record revision, dirty flag, OS/runtime, fixture/signature, warmup, samples,
percentiles, allocation evidence, and artifact path. A timeout, missing heap
evidence, or unknown result is not a pass.

## 23) Documentation And Publication

- [x] Add high-signal API documentation for units, ownership, previous/final
      support timing, one-way sidedness, ordering, failure behavior, and buffer
      reuse.
- [x] Update `docs/tdd/runner_core_simulation_contract.md` only for behavior
      actually implemented in the normal Core path or clearly label a
      test-harness-only dependency.
- [x] Create/update a focused terrain/capsule TDD describing the implemented
      reusable controller and its current non-production authority boundary.
- [x] Keep player-facing slope behavior in `docs/building/slopes/**` until it is
      authoritative in normal gameplay; do not present the harness as a shipped
      feature in the GDD.
- [x] Record the Phase 6 trigger to publish accepted traversal behavior in
      `docs/gdd/01_controls.md` and combat/collider system documentation.
- [x] Update Core README/export documentation if public types are exposed.
- [x] Update relevant `AGENTS.md` only if working boundaries or validation
      commands actually change.
- [x] Update this checklist and `plan.md` with evidence and implementation
      findings.
- [x] Keep editor, navigation, replay rollout, and rendering documents proposed
      until their owning phases deliver them.

## 24) Required Validation

Run the smallest relevant checks while developing, then the complete Phase 2
set before acceptance:

- [x] `dart format --output=none --set-exit-if-changed` on changed Dart files
- [x] `dart analyze packages/runner_core`
- [x] `dart test packages/runner_core/test`
- [x] all terrain kernel/index/controller/support tests
- [x] all `SG-P01` through applicable `SG-P12` tests
- [x] root player movement, platform, obstacle, gap, camera, snapshot,
      animation, ability, projectile, pickup, determinism, and fixed-point
      tests affected by the change
- [x] both fixed-point benchmark variants
- [x] Phase 1 representative and hard-stream benchmarks
- [x] Phase 2 player controller and full-slice benchmarks
- [x] replay-validator analyze/tests if shared Core construction or behavior is
      touched
- [x] `git diff --check`
- [x] local Markdown link integrity
- [x] production-authority and forbidden-import scans

Record command, revision, environment, result, duration, and artifact where
applicable. Do not mark a timeout or pre-existing unexplained failure as pass.

## 25) Non-Authority And Removal Proof

- [x] Normal `GameCore`/`TrackManager` levels do not query `TerrainEdgeIndex`
      for production collision.
- [x] No repository-authored level or chunk selects the Phase 2 harness.
- [x] No runtime remote/config flag selects legacy versus capsule terrain.
- [x] No enemy, navigation graph, spawn system, editor, renderer, or generated
      content has become partial polygon authority.
- [x] No legacy rectangle/flat-ground type, fixture, or production test is
      removed.
- [x] No unsupported body is silently integrated by the player controller.
- [x] No player body in a test is integrated twice.
- [x] Temporary test injection/adapter APIs are named, documented, and listed
      for Phase 6 removal.
- [x] Abandoned prototype stores, flags, and solver paths are removed before
      Phase 2 acceptance.

## 26) Phase 2 Exit Gate

- [x] The capsule and derived AABB contract is exact for both player
      definitions.
- [x] The actor-neutral controller implements the frozen numeric/contact rules.
- [x] Walkability is inclusive at 60 degrees and over-limit terrain is a wall.
- [x] The signed continuous speed curve matches all accepted controls.
- [x] Step, snap, peaks, valleys, seams, one-way, walls, and ceilings pass.
- [x] Jump, coyote, buffer, air jump, grounded/airborne mobility, knockback,
      disable, and lifecycle behavior pass.
- [x] Final support controls animation without flicker.
- [x] Locomotion playback follows resolved support distance with the accepted
      clamp and does not change gameplay timing.
- [x] Distance, score, camera, death, bounds, combat origins, pickups, and
      projectiles have explicit passing evidence/dispositions.
- [x] Every applicable player golden passes for Éloïse and Éloïse WIP.
- [x] Contact and player-run signatures match across fresh instances/processes.
- [x] Allocation and performance budgets pass with VM/profile evidence.
- [x] Normal production collision authority remains legacy and unchanged.
- [x] Enemy/navigation/spawn/streaming requirements are preserved in the
      Phase 3 handoff.
- [x] Documentation describes implemented authority accurately.
- [x] Validation ledger has no unexplained failure.
- [x] Implementation findings are reviewed before Phase 3 planning begins.

Only after every exit item is checked and evidence is accepted may the Phase 3
enemy/navigation checklist be written.

## 27) Implementation Findings

Record findings that alter later implementation detail without silently
changing frozen gameplay.

| Finding | Resolution | Later-phase impact |
| --- | --- | --- |
| VM allocation tracing exposed JIT `_Double` boxes at closest-segment result boundaries and while recovery reread floating separation. | Keep the closest-segment write in one unboxed pass and expose a recovery-only kernel query that writes the exact integer separation floor and skin correction while the floating value is already unboxed. The full public contact result remains unchanged, parity is tested, reviewed signatures remain identical, and repeated paired profiles now report zero hot-loop instances and no `_Double` call sites. | Phase 3 actors can reuse the same zero-steady-state-allocation query/controller path; later changes must keep the allocation profile green. |
| Windows wall-clock sampling produced rare scheduler pauses in both matched-flat and slope harness runs while p99 remained tens of microseconds. Phase 0 defines the whole-Core hard budget as p99 `<4 ms`, not raw observed maximum. | Keep reporting maximum for diagnosis, but apply the frozen hard gate to p99. The representative target remains the stricter p99 `<=2 ms`. | Later performance checklists should spell out percentile versus diagnostic-maximum semantics. |
| The normal constructor and replay path can retain the legacy solver while the real Core player systems exercise terrain through one construction-time authority seam. | Keep the seam test/tool-only, fail on unsupported dynamic bodies, and remove both the harness selector and legacy adapter at Phase 6. | Phase 3 must migrate every enemy/body policy before the direct cutover. |
| The first step implementation allowed its downward leg to finish on a solid endpoint, which let a capsule perch past a deliberately narrow landing. | Require the final step support hit to be a finite face. Added blocked-forward, narrow-landing, steep-landing, one-way-endpoint, and both-direction regressions. | Enemy step helpers in Phase 3 inherit the corrected actor-neutral rule. |
| Repeated sequential projection between two non-parallel wall normals could re-enter the first wall and consume the contact-iteration budget. | Resolve the 2D half-space intersection deterministically: retain a feasible vector, otherwise choose the closest feasible single-wall tangent, otherwise stop at the shared corner. Floor/wall, ceiling/wall, and symmetric two-wall regressions pass. | Phase 3 actors inherit stable multi-contact corner behavior instead of oscillation. |
| The existing player movement system implemented stun but did not consult its already-authored `LockFlag.move` contract. | Treat move-only lock as zero ordinary input/reference speed while leaving independently authorized active mobility untouched. A full slope-authority test proves gravity is consumed without drift for both move lock and stun. | Enemy movement keeps its separate navigation-lock policy; no slope-only lock exception is introduced. |
| The old `setPlayerPosXY` name did not reveal that destination clearance was intentionally skipped for tests. | Rename it to `setPlayerPosXYUnsafeForTest`, clear retained support/history before every write, and keep production gameplay placement absent until an authority-owned clearance contract exists. | Phase 3 Hashash teleport and later spawn/placement work cannot reuse the unsafe test mutation. |

## 28) Validation And Performance Ledger

| Date/revision | Command/evidence | Environment | Result |
| --- | --- | --- | --- |
| 2026-07-19 / `80e9752` + scoped dirty Phase 2 work | Reviewed Phase 1 signatures | Windows / Dart local checkout | Pass. `source-v1` `88be670c...`, `edges-v1` `84db4f45...`, `contacts-v1` `cb708e7c...`; new `contacts-v2` `b5e01c6c...`, `player-run-v1` `809ad307...`. |
| 2026-07-19 / `80e9752` + scoped dirty Phase 2 work | `dart analyze` at root and complete `packages/runner_core` package tests | Windows / Dart local checkout | Pass. Root analyzer clean; 122 package tests passed, including fresh-process signatures. |
| 2026-07-19 / `80e9752` + scoped dirty Phase 2 work | Focused root legacy movement/platform/obstacle/gap/camera/determinism/fixed-point/animation/ability/projectile/death/pickup/broad-phase tests | Windows / Flutter local checkout | Pass. 124 tests across two focused batches; normal construction remained legacy. |
| 2026-07-19 / `80e9752` + scoped dirty Phase 2 work | Replay-validator analyzer and tests | Windows / Dart local checkout | Pass. Analyzer clean; 75 tests passed. |
| 2026-07-19 / `80e9752` + scoped dirty Phase 2 work | Fixed-point benchmarks, no-track and track/autoscroll | Windows / Flutter test runtime | Pass. No-track baseline/fixed 31.42/14.78 us; track baseline/fixed 17.47/12.56 us; no resets. |
| 2026-07-19 / `80e9752` + scoped dirty Phase 2 work | Phase 1 representative and 5120-edge hard-stream benchmarks | Windows / Dart local checkout | Pass. Representative/hard rebuild p99 3067/3937 us; candidate p95/p99 3/3; zero buffer growth. |
| 2026-07-19 / `80e9752` + scoped dirty Phase 2 work | AOT `benchmark_slopes_phase2.dart`, 1000 warmup and 5000 measured iterations per case | Windows x64 / Dart AOT | Pass. Controller p95/p99 23/28 us; candidates 16/16; slope harness p99 55 us; matched-flat overhead 8.75%; zero buffer growth. Raw maxima remain diagnostic and included scheduler pauses. |
| 2026-07-19 / `80e9752` + scoped dirty Phase 2 work | VM service allocation profile, two 500-solve trial pairs after 50,000-solve warmup | Windows x64 / Dart JIT profiler | Open gate. No terrain-domain object delta or query-buffer growth; 5 `_Double` boxes per solve remain after removing primitive-boundary boxing. |
| 2026-07-20 / `80e9752` + scoped dirty Phase 2 work | Focused controller/Core evidence expansion | Windows x64 / Dart 3.11.5 | Pass. Added winding, feature, solid/one-way X overlap, floor/wall, ceiling/wall, two-wall, lock/stun, speed composition, 60-degree surface consequence, high-speed, dash-step, facing-offset, camera, seam-animation, two-character SG smoke, and fresh-signature coverage. |
| 2026-07-20 / `80e9752` + scoped dirty Phase 2 work | VM service allocation profile, two 500-solve trial pairs after 50,000-solve warmup | Windows x64 / Dart 3.11.5 JIT profiler | Open gate. No terrain-domain object or buffer growth; conservative repeated measurement reports 14 `_Double` boxes/solve. The temporary floating input-block experiment did not improve it and was removed. |
| 2026-07-20 / `80e9752` + scoped dirty Phase 2 work | Final package/root/validator validation and fresh-process signatures | Windows x64 / Dart 3.11.5 and Flutter test runtime | Pass. Root and `runner_core` analyzers clean; 143 package tests, 432 root Core tests, and 75 replay-validator tests pass; all reviewed signatures remain unchanged across fresh processes. |
| 2026-07-20 / `80e9752` + scoped dirty Phase 2 work | VM service allocation profile, two 500-solve trial pairs after 50,000-solve warmup plus 200 traced solves | Windows x64 / Dart 3.11.5 JIT profiler | Pass. Zero tracked hot-loop instances, `0.0` allocations/solve, no `_Double` call sites, and zero query-buffer growth. |
| 2026-07-20 / `80e9752` + scoped dirty Phase 2 work | AOT `benchmark_slopes_phase2.dart --strict`, 1000 warmup and 5000 measured iterations per case | Windows x64 / Dart 3.11.5 AOT | Pass. Controller p95/p99 22/24 us; candidates 16/16; slope harness p99 36 us; matched-flat overhead 2.81%; zero buffer growth; bounded contact/recovery iterations. |
