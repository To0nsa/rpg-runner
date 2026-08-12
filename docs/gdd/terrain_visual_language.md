# Terrain Visual Language

## Current Player-Facing Baseline

Field and Forest runs now render their authored polygon ground with the shared
`grass_dirt` material. The current eight production chunks deliberately keep a
flat 224px support line so the runtime handoff can be reviewed without changing
level difficulty or jump timing.

The material has three visible layers:

- a repeating dirt fill inside the exact terrain polygon
- a grass-and-soil surface strip following walkable upward-facing edges
- sparse roots and overhang details following the same edge

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
- Terrain endpoint caps are not drawn yet because a streamed chunk boundary
  must never look like a cliff. They will be enabled only with reliable
  cross-chunk join evidence.

## Cutover Boundary

This visual pass is implemented, but normal gameplay still uses the legacy
flat-ground collision projection. Slope, platform, obstacle, and gap content
will be introduced only alongside the direct polygon-authority validation in
the active slopes plan.
