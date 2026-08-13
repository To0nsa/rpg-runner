# Terrain Material Atlas Authoring Strategy

Date: August 13, 2026

Implemented: August 14, 2026

Status: Implemented and archived

Implementation record:
[terrain_material_atlas_implementation_checklist.md](terrain_material_atlas_implementation_checklist.md)

Durable technical contract:
[terrain_material_atlas_regions.md](../../../tdd/terrain_material_atlas_regions.md)

## Outcome

Terrain materials now select exact pixel regions from packed PNG atlases. The
same reusable atlas foundation also supplies Prefab Creator's grid-assisted
auto-slice workflow, so grid math, rectangle parsing, selection rendering,
image discovery, and region previews are not maintained twice.

The first production source is a terrain-owned copy of
`TX Tileset Ground.png` at
`assets/images/terrain/tx_tileset_ground/atlas.png`. Its 32x32 layout is only
the initial editor default. Authors can use any positive cell width and height,
independent X/Y origins and gutters, or an arbitrary manual pixel rectangle.

## Product Decisions

- Runtime art stays packed. Selecting a region does not create cropped files.
- Terrain PNGs must live below `assets/images/terrain/**`.
- A persisted material stores an explicit `assetPath`, `x`, `y`, `width`, and
  `height` for every visual role.
- Grid configuration is session-only editor state. It never enters gameplay or
  authoring JSON.
- Selection is explicit: changing the overlay does not mutate a material, and
  pressing **Assign region** commits only the currently valid rectangle to the
  dialog draft.
- Fill and repeated edge layers use the complete selected rectangle as their
  repeat unit. Caps draw once at their region-local anchors.
- Backward compatibility was intentionally not implemented. Schema v1 inputs
  fail closed, and the repository contains one canonical schema v2 manifest.
- Existing chunk `materialKey` references were retained because `grass_dirt`
  was re-authored under the same semantic key; legacy terrain image files were
  removed rather than wrapped as full-image regions.

## Delivered Ownership

| Concern | Owner |
| --- | --- |
| Region, edge, cap, catalog, validation, traversal, and repeat math | `packages/terrain_materials` |
| Neutral grid/rectangle/selection state | `tools/editor/lib/src/atlas/**` |
| Repository PNG discovery and decoded size metadata | `tools/editor/lib/src/workspace/repository_png_catalog.dart` |
| Reusable viewport, controls, painters, numeric fields, and thumbnails | `tools/editor/lib/src/app/pages/shared/atlas_*.dart` |
| Prefab-specific slice semantics and persistence | Prefab domain/store |
| Terrain picker, material workflow, and terrain-root policy | Terrain material page/plugin/store |
| Generated render specifications | Root terrain material generator |
| Atlas loading, region isolation, caching, painting, and disposal | `StagedTerrain` |

Shared atlas code is deliberately unaware of Prefab IDs, terrain material
roles, persistence, and revision policy. Each authoring domain converts its own
model to and from the shared integer pixel rectangle.

## Schema v2

The source of truth is
`assets/authoring/level/terrain_material_defs.json`. A representative material
shape is:

```json
{
  "schemaVersion": 2,
  "materials": [
    {
      "key": "grass_dirt",
      "displayName": "Grass / Dirt",
      "revision": 1,
      "fill": {
        "assetPath": "assets/images/terrain/tx_tileset_ground/atlas.png",
        "x": 32,
        "y": 32,
        "width": 32,
        "height": 32
      },
      "top": {
        "base": {
          "region": {
            "assetPath": "assets/images/terrain/tx_tileset_ground/atlas.png",
            "x": 32,
            "y": 0,
            "width": 32,
            "height": 32
          },
          "anchorY": 12
        }
      }
    }
  ]
}
```

The required fill is a region directly. Each edge layer contains `region` and
region-local `anchorY`. Each cap contains `region`, region-local `anchorX`, and
region-local `anchorY`. Optional top detail, wall, underside, and cap roles use
the same types.

The contract requires integer non-negative origins, positive integer sizes,
normalized terrain-owned PNG paths, in-image bounds, and anchors within the
closed region boundary. Catalog encoding is canonical and material keys are
sorted.

## Authoring Workflow

The Terrain Materials dialog represents each role with a read-only atlas path
and `X/Y/W/H` summary plus **Select region** or **Change region**. Free-form
asset-path editing is not part of the material form.

The picker provides two equivalent ways to describe a region:

1. Grid-assisted selection with configurable cell width, cell height, origin
   X/Y, and gutter X/Y. Defaults are 32x32, origin `(0, 0)`, and zero gutters.
2. Manual integer `X/Y/W/H`, which supports non-grid-aligned and multi-cell
   rectangles.

Clicking a complete visible grid cell selects it. Partial cells at the right or
bottom edge are not selectable. A valid manual rectangle can use the whole
image boundary. Invalid or incomplete numeric input clears the assignable
selection and explains the problem. If a grid configuration produces no
complete cells, the picker reports that condition while leaving manual entry
available.

Settings are remembered per atlas for the current loaded workspace. Reloading
the workspace clears that cache. Opening an assigned role restores its exact
atlas and rectangle; switching atlas clears the rectangle until another valid
selection is made.

Anchors remain numeric semantic values in the material dialog. The source
region preview overlays their positions, and changing to a smaller region does
not silently clamp them. Validation reports an out-of-range anchor instead.

## Write and Revision Semantics

- A new or duplicated material begins at revision 1.
- Saving an existing material increments its revision exactly once when its
  semantic content changes.
- Reopening and assigning the same region is revision-neutral.
- Grid-only changes are revision-neutral because grid state is not content.
- Closing or accepting an unchanged dialog dispatches no command.
- Apply re-decodes every referenced PNG and validates current dimensions before
  writing, so an externally replaced atlas cannot make an out-of-bounds region
  silently persist.
- Writes continue through the terrain material plugin/store and retain canonical
  ordering, source-drift protection, and atomic replacement.

## Runtime and Preview Semantics

The generated registry carries explicit source rectangles for every role.
Within one terrain component load, each unique atlas path loads once and each
unique complete region identity is extracted once into an owned in-memory
image. Fill and edge shaders therefore repeat an isolated region and cannot
sample neighboring atlas cells. Caps draw from the same isolated representation.

Fill repetition is phased from world coordinates. Edge repetition uses the
signed projection of its start point onto the edge tangent. The positive-modulo,
edge-phase, and tile-origin calculations live in `packages/terrain_materials`
and are shared with editor previews.

Material and chunk previews crop to the selected source rectangle and use the
same fill/edge repeat rules. They cache each source atlas but do not acquire
runtime image ownership. Runtime-owned extracted images are disposed when the
terrain component is removed and on partial load failure; shared Flame source
atlases are never disposed by the region cache.

## Content Cutover

The production `grass_dirt` material uses four reviewed regions from the
terrain atlas:

| Role | Region | Anchor |
| --- | --- | --- |
| Fill | `(32, 32, 32, 32)` | n/a |
| Top base | `(32, 0, 32, 32)` | `anchorY: 12` |
| Start cap | `(0, 0, 32, 32)` | `(0, 12)` |
| End cap | `(64, 0, 32, 32)` | `(32, 12)` |

The copied atlas was verified byte-identical to
`assets/images/level/tileset/TX Tileset Ground.png` at cutover. The five former
`assets/images/terrain/grass_dirt/*.png` images were removed after all normal
consumers switched to schema v2.

## Non-Goals

- no automatic sprite-boundary or transparency detection
- no cropped PNG export
- no persisted cell IDs or grid settings
- no v1 reader, migration command, or dual-schema period
- no change to terrain collision, navigation, placement, or streaming authority

## Delivery

The implementation was delivered in three scoped commits:

- `56063629` — shared atlas slicing foundation and Prefab auto-slice
- `6fb03c3f` — schema v2, terrain authoring, content cutover, and runtime regions
- `e42714f4` — shared runtime/editor repeat semantics and picker hardening
