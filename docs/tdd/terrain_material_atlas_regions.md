# Terrain Material Atlas Regions

Status: Implemented

Last updated: August 14, 2026

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
  of truth and uses schema v2 only.
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
| Edge base/detail | region plus `anchorY` | repeats along the edge tangent |
| Start/end cap | region plus `anchorX` and `anchorY` | draws once at an endpoint |

Anchors use region-local coordinates. Zero and the region width/height boundary
are valid; negative values and values beyond the boundary are invalid. They are
not coordinates in the complete atlas.

## Catalog Rules

The decoder accepts exactly `schemaVersion: 2`. Schema v1 whole-image fields are
invalid normal input; there is no runtime fallback or editor migration path.

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
TerrainMaterialStore ──► canonical schema v2 JSON
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
  modulo the selected region width

Consequently, chunk boundaries and camera movement do not reset texture phase.
Material and chunk previews call the same math so authored results match runtime
orientation and spacing.

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
- No normal consumer accepts or emits schema v1.
- Persisted material data never contains grid settings or cell IDs.
- No terrain shader repeats over a complete packed atlas.
- Shared atlas infrastructure has no dependency on Prefab or terrain domain
  models.
- Render data cannot alter deterministic terrain geometry or gameplay authority.
