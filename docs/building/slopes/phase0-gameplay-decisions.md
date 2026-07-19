# Slopes Phase 0 - Gameplay Decisions

- Date: July 18, 2026
- Last updated: July 19, 2026
- Status: In progress; decisions are confirmed one at a time
- Source checklist:
  [phase0-implementation-checklist.md](phase0-implementation-checklist.md)
- Technical defaults:
  [phase0-technical-contracts.md](phase0-technical-contracts.md)

## Decision Process

- Ask only one unresolved player-facing question at a time.
- Lead with one recommended conservative default and its gameplay consequence.
- Record the answer and rationale before asking the next question.
- Technical work continues while an unrelated gameplay answer is pending.
- A decision may name a tuning/profile value; it does not need to expose
  collision implementation details in the final GDD.

## Decision 1 - Maximum Player Slope

- Decision ID: `SLP-P0-001`
- Status: Accepted
- Accepted value: 60 degrees from horizontal
- Accepted by user: July 19, 2026

Accepted behavior:

- Éloïse can stand, run, land, and ground-snap on terrain up to and including
  60 degrees.
- Anything steeper is non-walkable and behaves as a wall/steep barrier.
- The limit controls traversal eligibility, not the default visual grade used
  by level authors.
- The comparison uses a precomputed normal threshold, so the exact boundary is
  deterministic.

Implementation consequence:

- exactly 60 degrees is walkable; any representable slope above it is not
- the player traversal profile owns this value
- enemy profiles remain separate and are not implicitly changed to 60 degrees
- golden fixtures require one edge exactly at 60 degrees and one just above it

## Decision 2 - Ground Speed On Slopes

- Decision ID: `SLP-P0-003`
- Status: Accepted
- Accepted by user: July 19, 2026

Accepted behavior:

| Absolute slope angle | Uphill horizontal speed | Downhill horizontal speed |
| ---: | ---: | ---: |
| 0 degrees | 100% | 100% |
| 30 degrees | 95% | 105% |
| 45 degrees | 85% | 110% |
| 60 degrees | 75% | 115% |

The curve is continuous:

- values between authored control points use deterministic linear
  interpolation rather than discrete angle tiers
- slope direction is evaluated relative to Éloïse's requested travel
  direction, so the same terrain edge is uphill in one direction and downhill
  in the other
- the multiplier changes target horizontal speed; existing
  acceleration/deceleration approaches that target instead of rewriting
  velocity instantaneously at an angle boundary
- the terrain solver supplies the vertical movement required to remain
  supported
- acceleration, stamina use, and input authority are otherwise unchanged

Consequences:

- uphill distance/score progression and camera travel slow with actual X speed
- downhill distance/score progression and camera travel increase with actual X
  speed
- animation playback may follow distance-along-surface speed to prevent visible
  foot sliding
- at 60 degrees, uphill surface speed is 150% of flat surface speed and
  downhill surface speed is 230%; this is an intentional consequence of
  combining the accepted X-speed curve with steep terrain

## Accepted Decisions

| ID | Decision | Accepted value | Accepted |
| --- | --- | --- | --- |
| `SLP-P0-001` | Player maximum walkable slope | 60 degrees, inclusive | July 19, 2026 |
| `SLP-P0-003` | Player slope-speed curve | Continuous uphill 100/95/85/75%; downhill 100/105/110/115% at 0/30/45/60 degrees | July 19, 2026 |
| `SLP-P0-004a` | Automatic player step-up | Enabled for ordinary grounded locomotion | July 19, 2026 |
| `SLP-P0-004b` | Maximum automatic step-up height | 4 world pixels | July 19, 2026 |
| `SLP-P0-004c` | Maximum downward ground-snap distance | 4 world pixels | July 19, 2026 |
| `SLP-P0-005` | Sharp peak/valley behavior | No artificial launch impulse; snap within 4 pixels, otherwise natural departure | July 19, 2026 |
| `SLP-P0-006` | Sloped one-way platforms | Pass from below, stand/traverse from above, non-solid endpoints, no drop-through input | July 19, 2026 |
| `SLP-P0-019a` | Ordinary jump direction | World-up, independent of support normal | July 19, 2026 |
| `SLP-P0-019b` | Grounded dash/roll direction | Follow eligible support tangent; art remains upright | July 19, 2026 |
| `SLP-P0-019c` | Grounded dash/roll speed | Preserve authored distance along the terrain surface | July 19, 2026 |
| `SLP-P0-019d` | Grounded mobility step/snap | Use the same 4-pixel helpers as ordinary locomotion | July 19, 2026 |
| `SLP-P0-002a` | Grojib maximum walkable slope | 45 degrees, inclusive | July 19, 2026 |
| `SLP-P0-002b` | Grojib small terrain transitions | 4-pixel step-up and downward snap | July 19, 2026 |
| `SLP-P0-002c` | Grojib slope speed | Constant distance-along-surface speed | July 19, 2026 |
| `SLP-P0-002d` | Hashash maximum walkable slope | 60 degrees, inclusive | July 19, 2026 |

## Decision 3 - Automatic Step-Up

- Decision sub-ID: `SLP-P0-004a`
- Status: Accepted
- Accepted value: enabled for Éloïse
- Accepted by user: July 19, 2026

Accepted behavior:

- while grounded and using ordinary locomotion, Éloïse may automatically
  traverse a small upward ledge
- the complete capsule must have overhead, forward, and landing clearance
- the destination must provide eligible walkable support
- the feature cannot climb steep terrain faces, pass through a ceiling, or
  bypass an obstacle whose top exceeds the accepted maximum
- player step-up does not implicitly grant step-up to enemies

## Decision 3b - Maximum Automatic Step Height

- Decision sub-ID: `SLP-P0-004b`
- Status: Accepted
- Accepted value: 4 world pixels
- Accepted by user: July 19, 2026

Accepted consequences:

- it is one quarter of the current 16-pixel terrain grid
- it smooths genuinely small terrain ledges without turning 8- or 16-pixel
  obstacle faces into stairs
- it is comfortably below Éloïse's current capsule radius
- the value can remain an explicit player traversal tuning field

## Decision 3c - Downward Ground-Snap Distance

- Decision sub-ID: `SLP-P0-004c`
- Status: Accepted
- Accepted value: 4 world pixels
- Accepted by user: July 19, 2026

Accepted behavior:

- an eligible grounded Éloïse may snap downward by at most 4 pixels to remain
  attached across small descending transitions
- snapping never moves her upward and never crosses a blocking edge
- accepted jump takeoff, teleport, airborne state, and upward velocity disable
  snapping
- the destination must be eligible walkable support with full capsule
  clearance
- larger drops cause normal airborne/falling behavior

Using the same 4-pixel scale for upward step smoothing and downward ground
adhesion makes the terrain tolerance easy to author and test without hiding
real 8- or 16-pixel elevation changes.

## Decision 4 - Sharp Convex Peaks

- Decision ID: `SLP-P0-005`
- Status: Accepted
- Accepted value: terrain transitions do not add a launch impulse
- Accepted by user: July 19, 2026

Accepted behavior:

- when Éloïse crosses a convex peak, she remains supported if eligible
  descending terrain is reachable within the accepted 4-pixel ground snap
- if the terrain falls away by more than 4 pixels, she departs naturally and
  becomes airborne with her existing velocity
- a change in terrain angle never adds an artificial launch impulse
- concave valleys resolve as continuous supported traversal without a bounce
- ordinary coyote time starts on the first unsupported tick

## Decision 5 - One-Way Sloped Platforms

- Decision ID: `SLP-P0-006`
- Status: Accepted
- Accepted value: preserve current one-way-platform behavior
- Accepted by user: July 19, 2026

Accepted behavior:

- Éloïse passes through a one-way sloped platform from its underside
- she lands, stands, and traverses it from its authored walkable/top side
- the platform follows her accepted 60-degree slope limit and slope-speed curve
- exposed endpoints do not become invisible solid side walls
- automatic step-up cannot climb a one-way endpoint from the side
- no drop-through input is added in the first slope release

## Decision 6 - Jump Direction

- Decision sub-ID: `SLP-P0-019a`
- Status: Accepted
- Accepted value: world-up
- Accepted by user: July 19, 2026

Accepted behavior:

- an ordinary jump always applies its vertical impulse in world-up, regardless
  of the current support normal
- slope angle does not inject an extra horizontal jump impulse
- existing jump height, timing, air control, and gap reach remain predictable
- support and ground-snap eligibility clear before the jump impulse

The alternative—jumping along the support normal—would push Éloïse sideways
away from a slope. At 60 degrees, most of that impulse would be horizontal and
jump reach would change significantly depending on travel direction.

## Decision 7 - Grounded Dash/Roll Direction

- Decision sub-ID: `SLP-P0-019b`
- Status: Accepted
- Accepted value: follow the eligible support tangent
- Accepted by user: July 19, 2026

Accepted behavior:

- a dash or roll started while grounded follows the terrain tangent in the
  chosen horizontal direction
- Éloïse remains visually upright; only her movement follows the slope
- the ability adds no support-normal launch impulse
- over-limit slopes still behave as walls and stop/resolve the ability
- an ability started while airborne keeps its existing world-space behavior

This avoids a horizontal grounded dash digging into an uphill slope or
detaching immediately from a downhill slope. Speed/distance and helper
eligibility were resolved separately in Decisions 8 and 9.

## Decision 8 - Grounded Dash/Roll Speed

- Decision sub-ID: `SLP-P0-019c`
- Status: Accepted
- Accepted value: preserve authored distance along the terrain surface
- Accepted by user: July 19, 2026

Accepted behavior:

- grounded dash/roll speed and distance are measured along the support tangent
- the ordinary run slope-speed curve does not multiply an active dash or roll
- ability duration and travelled surface distance therefore remain consistent
  uphill, downhill, and on flat ground
- horizontal reach becomes shorter on steeper terrain; at 60 degrees it is
  half the flat-ground horizontal reach
- over-limit terrain still blocks the ability as a wall

This avoids doubling grounded ability velocity on a 60-degree slope and keeps
ability animation/distance predictable. Decision 9 separately accepted the
4-pixel step-up and ground-snap helpers for grounded abilities.

## Decision 9 - Grounded Mobility Step/Snap

- Decision sub-ID: `SLP-P0-019d`
- Status: Accepted
- Accepted value: use both accepted 4-pixel helpers
- Accepted by user: July 19, 2026

Accepted behavior:

- a dash or roll that starts grounded may step over a fully clear upward ledge
  of at most 4 pixels
- it may snap down by at most 4 pixels while valid support continues
- the same capsule-clearance, walkable-support, and one-way-endpoint rules used
  by ordinary locomotion remain mandatory
- a larger upward ledge blocks the grounded ability
- a larger downward departure cannot be hidden by snapping; normal
  ability/airborne behavior takes over
- an ability that starts airborne receives neither helper

This lets a grounded ability cross the same minor terrain irregularities as
ordinary running without increasing its obstacle-climbing authority.

## Decision 10 - Grojib Maximum Walkable Slope

- Decision sub-ID: `SLP-P0-002a`
- Status: Accepted
- Accepted value: 45 degrees, inclusive
- Accepted by user: July 19, 2026

Accepted behavior:

- Grojib can stand, pursue, and use ordinary walk graph edges on slopes up to
  and including 45 degrees
- steeper terrain is a collision wall and is excluded from Grojib's walk graph
- Grojib may still use an existing valid jump/drop graph transition to reach a
  separate eligible surface
- Éloïse's accepted 60-degree limit therefore leaves intentional steep escape
  routes that this larger basic ground enemy cannot follow directly

## Decision 11 - Grojib Small Terrain Transitions

- Decision sub-ID: `SLP-P0-002b`
- Status: Accepted
- Accepted value: 4-pixel step-up and downward snap
- Accepted by user: July 19, 2026

Accepted behavior:

- during ordinary grounded pursuit, Grojib may step up by at most 4 pixels and
  snap down by at most 4 pixels
- both operations require complete capsule clearance and 45-degree-eligible
  destination support
- navigation emits an ordinary walk transition only when the same capsule
  query proves the 4-pixel transition feasible
- larger elevation changes require an existing valid jump/drop graph
  transition or remain unreachable

Using the same small-transition tolerance prevents minor terrain details from
breaking pursuit without giving Grojib Éloïse's steeper traversal ability.

## Decision 12 - Grojib Slope Speed

- Decision sub-ID: `SLP-P0-002c`
- Status: Accepted
- Accepted value: constant distance-along-surface speed
- Accepted by user: July 19, 2026

Accepted behavior:

- Grojib keeps its authored locomotion speed measured along eligible terrain
- it receives no uphill slowdown or downhill boost beyond the geometry itself
- horizontal pursuit becomes slower on steeper slopes; at Grojib's 45-degree
  limit, horizontal progress is about 71% of flat-ground progress
- navigation walk cost is surface length divided by Grojib's authored speed, so
  path selection and runtime travel use the same time estimate
- movement animation can retain its existing speed relationship without the
  player's signed-slope curve

This suits the larger basic pursuer, avoids downhill acceleration surprises,
and gives Éloïse a clearer mobility advantage on steep terrain.

## Decision 13 - Hashash Maximum Walkable Slope

- Decision sub-ID: `SLP-P0-002d`
- Status: Accepted
- Accepted value: 60 degrees, inclusive
- Accepted by user: July 19, 2026

Accepted behavior:

- Hashash can stand, pursue, and use ordinary walk graph edges on slopes up to
  and including 60 degrees
- steeper terrain remains a collision wall and is excluded from Hashash's walk
  graph
- Hashash may still use valid jump/drop transitions and its separately
  validated ambush teleport
- matching Éloïse's limit makes the nimble assassin capable of following routes
  that intentionally exclude the larger Grojib

## Decision 14 - Hashash Small Terrain Transitions

- Decision sub-ID: `SLP-P0-002e`
- Status: Awaiting user confirmation
- Recommended default: 4-pixel step-up and downward snap

Recommended behavior:

- during ordinary grounded pursuit, Hashash may step up by at most 4 pixels and
  snap down by at most 4 pixels
- both operations require complete capsule clearance and 60-degree-eligible
  destination support
- its navigation graph emits the corresponding ordinary walk transition only
  when the same capsule query accepts it
- larger transitions require a valid jump/drop path, teleport behavior, or
  remain unreachable

This gives both navigating ground enemies the same authoring tolerance while
their different slope limits preserve their distinct route access.

User question:

> Should Hashash also use 4-pixel automatic step-up and downward ground snap?

## Later Decision Queue

After `SLP-P0-002e` is accepted, the next unresolved gameplay decision is asked
from this order:

1. Hashash slope-speed behavior
2. Hashash teleport/ambush placement behavior
3. Unoco Demon terrain-clearance behavior
4. Derf placement eligibility
5. steep/narrow spawn eligibility

This queue is sequencing information, not a request to answer multiple
questions at once.
