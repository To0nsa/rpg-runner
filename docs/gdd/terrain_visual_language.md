# Terrain Visual Language

## Current Player-Facing Baseline

Field and Forest runs now render their authored polygon ground with the shared
`grass_dirt` material. All eight production chunks keep a continuous 224px
ground line. Forest's easy woodcamp also has a grass-and-soil obstacle collider
under its wood-pile prop, creating the first raised production perch and a
player-readable jump obstacle.

The material has three visible roles:

- a repeating dirt fill inside the exact terrain polygon
- a grass-and-soil surface strip following walkable upward-facing edges
- start/end caps at compiler-exposed top-edge endpoints; connected polygon
  corners use the meeting edge bands without added corner art

The terrain art stays aligned with collision-source geometry and scrolls in
world space, so seams do not appear to swim under the player. Actors and props
remain upright and retain their existing visual priority over the ground.

## Readability Rules

- A filled polygon may be solid, one-way, or explicitly visual-only. Designers
  use **No collision (visual only)** for dressing such as a dark pit while the
  absence of collision/support remains what makes that space a gap.
- The bright grass edge is the primary support/readability cue at runner speed.
- Surface detail must not obscure enemies, pickups, hit effects, or the player.
- Material changes may alter biome appearance but never change collision. The
  polygon's authored collision role (`solid`, `oneWay`, or `none`) owns that
  behavior explicitly.
- Atlas packing is an image-storage and authoring concern only. Selecting a
  different cell or rectangle changes the visual role, never collision shape.
- Endpoint caps appear only at compiler-exposed top-edge endpoints. Connected
  corners and continued top edges must not acquire a false cliff cue.
- Edge strips stop at authored endpoints. Joins may show the polygon fill; the
  renderer does not stretch neighboring strips to conceal those spaces.

## Runtime Boundary

Normal Field and Forest gameplay now uses one authored terrain set and one
atomic streamed candidate. Solid and one-way polygons feed collision,
support/navigation, placement, and rendering. `none` polygons feed only the
render snapshot: they create no support, blocker, seam, or collision edge.
Ground remains flat apart from the reviewed woodcamp obstacle; slopes,
platforms, and visually dressed gaps can be introduced as ordinary content.

`none` is not a hazard type. A dark-pit material can communicate a fall, while
the existing absence of support and level kill-plane rules determine the
gameplay outcome.
