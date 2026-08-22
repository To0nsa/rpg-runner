# Terrain Visual Language

## Current Player-Facing Baseline

Field and Forest runs render their authored polygon ground with the shared
`grass_dirt` material. Forest currently contains only `forest_early_flat`: a
continuous 224px ground line with no raised obstacle, Prefab placement, or
enemy marker.

The material has three visible roles:

- a repeating dirt fill inside the exact terrain polygon
- a grass-and-soil surface strip following walkable upward-facing edges
- start/end caps at compiler-exposed edge endpoints and cardinal rectangle
  corners, with material-fill joins at other convex turns

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
- Prefab collision never paints or cuts the terrain material. A placed
  Prefab's sprite owns its appearance, while the Chunk terrain keeps the same
  fill and surface strip it had before placement, including at exact contact.
- The `grass_dirt` atlas cells carry a one-pixel export outline. Edge and cap
  regions omit that outward-facing row or column in source space, so device
  scaling and clip rasterization cannot reveal it. The visible grass and rock
  silhouette begins cleanly at the collision edge.
- Exposed endpoints retain their authored caps. Exact cardinal rectangle
  corners use their matching top or underside cap. Other convex turns use a
  local material-fill backing rather than rotating rectangular endpoint art,
  so slope bends cannot expose the sky through transparent cap pixels. Concave
  turns remain band-only, and smooth continuations never acquire a false cliff
  cue.
- Every selected cap and semantic edge base replaces lower terrain art with
  both its color and alpha. Transparent cutouts reveal the scene rather than a
  lower terrain role. Detail remains an overlay within its own base profile.
  Visible ownership resolves as cardinal corner, top-facing edge,
  wall/underside edge, generic join backing, then fill.
- Internal edge-tile joins receive a one-pixel material-fill backing on each
  side of the repeat boundary. This closes tiny atlas/raster seams without
  filling the rest of the transparent rocky silhouette or exposed endpoints.
- Edge strips stop at authored endpoints. Joins may show the polygon fill; the
  renderer does not stretch neighboring strips to conceal those spaces.
- Thin polygons use that same ownership order: top-facing corners and bands own
  overlaps above underside art. Content thickness or material regions must
  still provide the desired interior clearance.

## Runtime Boundary

Normal Field and Forest gameplay now uses one authored terrain set and one
atomic streamed candidate. Direct solid and one-way Chunk polygons feed
collision, support/navigation, placement, and terrain rendering. Placed Prefab
polygons join collision, support/navigation, and placement without becoming
terrain fills or material edges. `none` polygons feed only the render snapshot:
they create no support, blocker, seam, or collision edge.
Current Forest ground remains flat; slopes, platforms, and visually dressed
gaps can be introduced as ordinary content.

`none` is not a hazard type. A dark-pit material can communicate a fall, while
the existing absence of support and level kill-plane rules determine the
gameplay outcome.
