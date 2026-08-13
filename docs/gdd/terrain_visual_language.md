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
- start/end caps at exposed top-edge endpoints, suppressed where a
  same-material top edge continues

The terrain art stays aligned with collision-source geometry and scrolls in
world space, so seams do not appear to swim under the player. Actors and props
remain upright and retain their existing visual priority over the ground.

## Readability Rules

- Filled terrain means solid authored terrain; empty space remains visually
  open and may become a gap once polygon collision is authoritative.
- The bright grass edge is the primary support/readability cue at runner speed.
- Surface detail must not obscure enemies, pickups, hit effects, or the player.
- Material changes may alter biome appearance but must not imply different
  collision unless the authored polygon actually changes.
- Atlas packing is an image-storage and authoring concern only. Selecting a
  different cell or rectangle changes the visual role, never collision shape.
- Endpoint caps appear only at compiler-exposed top-edge endpoints. A continued
  same-material top edge must not acquire a false cliff cue.

## Runtime Boundary

Normal Field and Forest gameplay now uses the same authored polygons for
collision, support/navigation, placement, and rendering. Ground remains flat
apart from the reviewed woodcamp obstacle; slopes, platforms, and gaps can be
introduced as later content changes without another terrain-authority switch.
