# Terrain Material Atlas Regions

Status: Implemented

Last updated: August 19, 2026

## Purpose

Terrain materials reference exact pixel rectangles inside packed PNG atlases.
This contract lets editor previews and Flame runtime rendering use one source
image for several roles without treating the complete atlas as a texture tile.

This document owns the durable schema, validation, data-flow, caching, repeat,
and lifecycle rules. It does not define terrain geometry or collision meaning.

## Ownership

- `packages/terrain_materials` owns pure-Dart source types, strict decoding,
  canonical encoding, structural validation, traversal, and repeat math.
- `assets/authoring/level/terrain_material_defs.json` is the repository source
  of truth and uses schema v3 only.
- `tools/editor` discovers terrain PNGs, edits material regions, validates
  current image dimensions, and writes through its terrain plugin/store.
- the root terrain generator compiles source definitions into
  `lib/game/themes/authored_terrain_materials.dart`.
- `StagedTerrain` owns runtime atlas loading, region extraction, paint caching,
  drawing, and disposal.
- Core owns terrain geometry, collision, traversal, placement, and streaming;
  atlas regions are render-only data.

## Region Contract

`TerrainMaterialImageRegion` contains:

- `assetPath`: normalized repository path matching
  `assets/images/terrain/**/*.png`
- `x`, `y`: non-negative integer pixel origin from the source image's top-left
- `width`, `height`: positive integer pixel dimensions

The half-open source rectangle is `[x, x + width) × [y, y + height)`. Its right
and bottom values may equal the decoded source-image dimensions.

Material roles use regions as follows:

| Role | Stored value | Render behavior |
| --- | --- | --- |
| Fill | region | repeats in world X/Y and clips to terrain fill geometry |
| Edge base/detail | world-facing region plus normalized `anchorY` | normalizes for its role, repeats along the edge tangent, and clips to the owning polygon |
| Top or underside start/end cap | region plus `anchorX` and `anchorY` | draws once at an exposed endpoint or selected convex connected corner in a final pass and clips to the owning polygon |

Edge source art is selected in its natural world-facing orientation: top art
faces up, left/right wall art faces its named side, and underside art faces
down. Before tangent placement, renderers normalize left-wall art clockwise by
one quarter-turn, right-wall art by three quarter-turns, and underside art by
two quarter-turns; top art is already normalized. This prevents already
oriented atlas cells from receiving an extra 90° or 180° rotation on
axis-aligned polygons while preserving edge-relative rotation for slopes.

The production `grass_dirt` top band and its endpoint/corner caps use
`anchorY: 0`.
Their raster therefore starts on the polygon's upper boundary and remains
inside its filled collision region; terrain art does not visually extend above
the authored ground surface.

Fill, edge-band, and endpoint-cap pixels are all confined to the exact owning
polygon loop in both the Chunk Creator preview and `StagedTerrain`. Edge-local
rectangular clipping still limits repetition along the tangent, but it is not a
substitute for the owner clip: at a slope or corner that rectangle can cross an
adjacent polygon boundary. Runtime edges recover their owner through the exact
`TerrainSourceIdentity` shared by the render polygon and compiled edge lineage.
Within both the repeating-band pass and final endpoint-cap pass, wall and
underside decorations retain their source order and top-facing decorations
render last. Slopes with an upward-facing outward normal count as top-facing,
so the playable grass/surface silhouette remains visible at every corner.

Core join semantics drive non-repeating art. `exposed` endpoints retain their
configured start/end caps. For a `connected` join, shared pure-Dart math takes
the dot product of the incoming inward normal and outgoing tangent: positive is
a convex turn eligible for a corner patch, while zero/negative straight or
concave turns remain band-only. The resolver chooses exactly one available cap;
top-facing art wins across different paint priorities and the incoming end wins
ties. `smooth` joins never draw caps. The Chunk Creator applies the same rule to
closed source loops and treats only top-facing runs as active for one-way
terrain.

Every edge band is clipped to its exact authored edge endpoints. Runtime and
editor painters do not stretch or underlap adjacent bands to hide join wedges;
the meeting source regions and polygon fill remain visible as authored.

Cap `anchorX` and `anchorY` use tangent-normalized region coordinates, matching
the destination space in which the cap is placed. Edge `anchorY` uses that same
normalized tile: its valid range is the source height for top/underside regions
and the source width for wall regions. The atlas picker maps these normalized
anchors back onto the raw world-facing cell when it draws its guide. Zero and
the relevant boundary are valid; negative values and values beyond the boundary
are invalid. Anchors are never coordinates in the complete atlas.

## Catalog Rules

The decoder accepts exactly `schemaVersion: 3`. Older schemas are invalid
normal input; there is no runtime fallback or editor migration path. Top caps
and underside caps are independently optional pairs. Underside caps require an
underside profile so a corner cannot exist without its repeating edge band.

Validation is split deliberately:

1. Pure structural validation checks schema shape, keys, normalized paths,
   integer coordinates, positive sizes, duplicate material keys, and anchors.
2. Consumer validation checks every region against decoded source-image
   dimensions.

Canonical encoding sorts materials by key, emits fields in a stable order, and
ends with one newline. Stable traversal APIs expose every referenced region and
deduplicate asset paths without requiring consumers to reproduce role walking.

## Editor Data Flow

```text
repository terrain PNGs
        │
        ▼
RepositoryPngCatalog ──► immutable path + decoded size metadata
        │
        ▼
TerrainMaterialDomainPlugin ──► editor session snapshot
        │
        ▼
Terrain material dialog ──► atlas picker ──► local material draft
        │
        ▼
apply-time PNG decode + bounds validation
        │
        ▼
TerrainMaterialStore ──► canonical schema v3 JSON
```

Repository discovery and PNG metadata reading are non-UI infrastructure shared
with Prefab authoring. Pixel rectangles, grid math, selection state, viewport,
controls, painters, numeric region fields, and thumbnails are also neutral
shared editor components. Material-role assignment, revisions, terrain-root
policy, and persistence remain terrain-specific.

The grid is an authoring aid, not source data. Cell width and height are any
positive integers; origin and gutter values are non-negative integers. Only
complete cells inside the decoded image are selectable. Manual `X/Y/W/H` uses
the same rectangle validation and can describe arbitrary or multi-cell regions.

Per-atlas grid settings live only in the current loaded workspace session.
Reload clears them. Changing grids never changes an assigned rectangle, while
changing the selected atlas clears the current uncommitted rectangle.

## Revisions and Writes

Material drafts use semantic equality excluding the current revision to decide
whether a write exists.

- create and duplicate start at revision 1
- one semantic edit to an existing material increments once
- assigning the same region or changing only grid state is revision-neutral
- an unchanged dialog emits no session command

Apply reopens and fully decodes each referenced PNG, then validates bounds using
the current dimensions. This closes the time-of-check/time-of-use gap when an
atlas is replaced after workspace load. Store writes retain canonical ordering,
source-drift detection, and atomic file replacement.

## Generation and Runtime Data Flow

```text
terrain_material_defs.json
        │ strict v2 decode and source-image validation
        ▼
terrain material generator
        │ deterministic region literals + unique asset paths
        ▼
authored_terrain_materials.dart
        │
        ▼
StagedTerrain load lifecycle
        ├── load each unique atlas path once through Flame
        ├── extract each unique complete region identity once
        ├── cache region images and paints outside render
        └── render fill, edges, and caps from isolated images
```

A complete runtime region cache key is `(assetPath, x, y, width, height)`.
Different rectangles in the same atlas remain different entries. Identical
regions reused by roles or materials share one extracted image in the component
lifecycle.

Region extraction creates a new owned `ui.Image`. This isolation is required
before constructing a repeating shader: using a source rectangle only at draw
time would still allow repeat/filter sampling to reach neighboring atlas pixels.
Nearest-neighbor filtering is used for pixel art.

## Repeat Semantics

Fill and edge repeat calculations use shared pure-Dart functions from
`packages/terrain_materials`:

- positive modulo normalizes negative and positive world coordinates
- fill tile origin is the first repeat boundary at or before a world coordinate
- edge phase is the signed projection of the edge start onto its unit tangent,
  modulo the tangent-normalized tile width (source height for wall art, source
  width for top/underside art)

Consequently, chunk boundaries and camera movement do not reset texture phase.
Material and chunk previews call the same orientation, dimension, and repeat
math so authored results match runtime orientation and spacing. They also call
the same convex-corner owner resolver. Edge repeats stop at their exact
endpoints in both renderers; no corner decision extends a repeating band.

## Image Ownership and Failure Handling

Flame's loaded source atlas images are shared and are not disposed by terrain.
Every extracted region image is owned by the `StagedTerrain` instance that
created it.

- successful removal disposes each owned region image once
- a partial atlas-load or extraction failure disposes all regions already
  created in that attempt
- a failed load never marks terrain render assets ready
- extraction and paint creation never occur inside the frame render loop

Editor previews cache source atlases for their own widget/controller lifecycle
and draw exact source rectangles. They do not use or own the runtime extraction
cache.

## Invariants

- Terrain material paths never escape `assets/images/terrain/**`.
- No normal consumer accepts or emits terrain material schemas older than v3.
- Persisted material data never contains grid settings or cell IDs.
- No terrain shader repeats over a complete packed atlas.
- Shared atlas infrastructure has no dependency on Prefab or terrain domain
  models.
- Render data cannot alter deterministic terrain geometry or gameplay authority.
