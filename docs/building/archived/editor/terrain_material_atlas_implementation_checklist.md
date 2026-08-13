# Terrain Material Atlas Region Implementation Record

Date planned: August 13, 2026

Implemented: August 14, 2026

Status: Complete and archived

Source strategy:
[terrain_material_authoring_plan.md](terrain_material_authoring_plan.md)

## Acceptance Result

- [x] Terrain roles persist exact atlas pixel regions rather than whole-image
      paths.
- [x] Grid-assisted slicing accepts arbitrary positive cell dimensions; 32x32
      is only the default.
- [x] Manual `X/Y/W/H` supports non-grid and multi-cell rectangles.
- [x] Region assignment is explicit, bounds checked, and revision safe.
- [x] Prefab Creator uses the same neutral atlas grid, viewport, field, preview,
      and image-catalog foundations.
- [x] Terrain runtime and author-facing previews use the selected region rather
      than the full atlas.
- [x] Runtime region isolation prevents neighboring atlas cells from bleeding
      into repeated fill or edge shaders.
- [x] Schema v1 and legacy image paths were removed without a compatibility or
      migration path.
- [x] The production `grass_dirt` material and generated registry use schema v2.

## Pass 1 — Shared Atlas Foundation

- [x] Added immutable integer pixel rectangles, grid settings and geometry,
      selection state, and workspace-scoped per-atlas grid caching under
      `tools/editor/lib/src/atlas/**`.
- [x] Added one repository PNG catalog for normalized discovery and decoded
      image dimensions.
- [x] Extracted shared grid controls, grid and selection painters, image
      viewport, manual region fields, and source-region thumbnails.
- [x] Kept those shared libraries independent of Prefab and terrain models.
- [x] Adapted both Prefab atlas surfaces to the shared foundation.
- [x] Added Prefab auto-slice with cell width/height, origin, and gutter
      controls while retaining manual selection.
- [x] Removed the superseded Prefab-only slicer controller, preview tile, and
      workspace image-size cache.

Evidence:

- `tools/editor/test/atlas_grid_test.dart`
- `tools/editor/test/atlas_image_viewport_test.dart`
- `tools/editor/test/repository_png_catalog_test.dart`
- existing Prefab workspace and interaction tests

## Pass 2 — Strict Schema v2 and Content Cutover

- [x] Added `TerrainMaterialImageRegion` and changed fill, edge, and cap roles
      to explicit source regions.
- [x] Added value equality, canonical JSON, stable material/region/asset
      traversal, and decoded-image bounds validation.
- [x] Restricted normal asset paths to normalized PNGs under
      `assets/images/terrain/**`.
- [x] Validated anchors relative to the selected region, accepting the closed
      right/bottom boundary and rejecting values beyond it.
- [x] Rejected versions other than v2 and legacy whole-image field shapes.
- [x] Copied the 512x512 reference atlas byte-identically into terrain-owned
      storage and synchronized `pubspec.yaml`.
- [x] Re-authored `grass_dirt` with fill, top-base, start-cap, and end-cap
      regions while retaining the material key used by chunks.
- [x] Deleted the five obsolete standalone `grass_dirt` images after consumer
      cutover.

Evidence:

- `packages/terrain_materials/test/terrain_material_catalog_test.dart`
- `assets/authoring/level/terrain_material_defs.json`
- `assets/images/terrain/tx_tileset_ground/atlas.png`

## Pass 3 — Generator and Runtime

- [x] Generated explicit region literals and deduplicated terrain atlas asset
      paths deterministically.
- [x] Loaded each unique source atlas once per `StagedTerrain` lifecycle.
- [x] Extracted each unique `(path, x, y, width, height)` once into an owned
      in-memory image outside the render loop.
- [x] Replaced full-atlas fill, edge, and cap sampling with isolated-region
      rendering and nearest-neighbor filtering.
- [x] Kept fill phase stable in world space and edge phase stable along the
      signed world-space tangent.
- [x] Shared positive modulo, edge phase, and tile-origin math from the pure-Dart
      terrain package with runtime and editor consumers.
- [x] Disposed owned region images on component removal and on partial load
      failure without disposing Flame's shared atlas images.

Evidence:

- `packages/terrain_materials/test/terrain_material_render_math_test.dart`
- `test/game/staged_terrain_atlas_region_render_test.dart`
- `test/game/staged_terrain_component_test.dart`
- `test/tool/terrain_material_generation_test.dart`
- `test/tool/generate_chunk_runtime_data_test.dart`

## Pass 4 — Terrain Authoring and Preview Parity

- [x] Loaded immutable terrain atlas path/size metadata through the terrain
      plugin using the shared non-UI PNG catalog.
- [x] Added a role-aware region picker with grid and manual selection, explicit
      assignment, current-region restoration, and atlas-switch clearing.
- [x] Reported zero-complete-cell grids while keeping manual selection usable.
- [x] Cleared invalid manual selections so stale rectangles cannot be assigned.
- [x] Retained per-atlas grid settings only for the loaded workspace session and
      cleared them on reload.
- [x] Replaced free-form material image paths with read-only region summaries
      and Select/Change actions.
- [x] Added region-local anchor guides without silently clamping anchors.
- [x] Made new/duplicate revisions start at 1 and existing semantic changes
      increment exactly once; unchanged saves dispatch no command.
- [x] Re-decoded and bounds-checked every referenced PNG at apply time.
- [x] Updated material thumbnails, composed previews, polygon metadata dialogs,
      and chunk scene previews to crop and repeat exact regions.
- [x] Shared repeat phase calculations between runtime and both preview paths.

Evidence:

- `tools/editor/test/terrain_material_domain_plugin_test.dart`
- `tools/editor/test/terrain_materials_page_test.dart`
- `tools/editor/test/chunk_polygon_level_visual_source_test.dart`

## Architecture Audit

- [x] Shared atlas code imports no Prefab or terrain domain models.
- [x] Prefab and terrain persistence remain in their existing plugins/stores.
- [x] `packages/terrain_materials` is the single source for material validation,
      region traversal, asset traversal, and repeat math.
- [x] The editor has one repository PNG catalog rather than domain-specific file
      and PNG-header readers.
- [x] Old Prefab atlas helpers and old terrain whole-image fields have no normal
      references.
- [x] Grid configuration and cell identity do not leak into persisted material
      JSON or runtime contracts.

## Validation Completed

- [x] `dart analyze packages/terrain_materials`
- [x] `dart test packages/terrain_materials/test`
- [x] targeted root analysis for the generated registry, runtime component, and
      atlas-region render test
- [x] targeted editor analysis for shared atlas, Prefab integration, terrain
      plugin/store/page, and chunk/material preview files
- [x] focused editor tests for shared atlas primitives, repository PNG discovery,
      Prefab integration, terrain plugin/page, and chunk preview
- [x] runtime component and atlas-region rendering tests
- [x] terrain registry generator tests
- [x] the complete chunk-runtime generator fixture suite
- [x] root asset synchronization check
- [x] repository reference searches for removed helpers, legacy fields, and
      retired standalone terrain images

The feature-scope analysis and tests were green when each implementation commit
was created. A later whole-editor analysis during close-out encountered
uncommitted, unrelated Chunk Creator work in the shared worktree; that work is
outside this implementation and was not modified by these commits.

## Close-out

- [x] Durable architecture and ownership rules are documented in
      `docs/tdd/terrain_material_atlas_regions.md`.
- [x] Player-facing terrain visual guidance records that atlas packing changes
      image storage and selection, not terrain collision meaning.
- [x] Editor documentation describes the shipped workflow and clean v2 cutover.
- [x] The planning documents were converted to implementation records and moved
      to `docs/building/archived/editor/`.

Implementation commits:

- `56063629` — shared atlas slicing foundation and Prefab auto-slice
- `6fb03c3f` — schema v2, terrain authoring, content cutover, and runtime regions
- `e42714f4` — shared runtime/editor repeat semantics and picker hardening
