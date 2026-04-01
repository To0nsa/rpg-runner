# Chunk Creator High-Level Plan

Date: March 27, 2026  
Status: Active (Phase 0 completed on March 31, 2026; Phase 1 next)

## 1) Mission

Build a production-ready chunk authoring workflow for `rpg_runner` inside
`tools/editor`, focused on deterministic gameplay chunks, not freeform scene
building.

### Primary outcomes

- deterministic by construction
- grid-authoritative authoring
- usable by non-developers for daily content production, without editing Dart
  source or hand-editing JSON
- level-scoped chunk ownership: each chunk belongs to exactly one level
  context and must validate against that level's rules/content
- reuse-first implementation: existing editor code that is applicable must be
  modularized and reused across domains instead of duplicated
- evolution-friendly architecture: new gameplay authoring features (hazards,
  teleportation gates, power-ups, future marker types) can be added without
  rewriting existing chunk workflows or data
- incremental delivery with strict phase gates: each phase adds tested
  functionality, and phase `N+1` does not start until phase `N` is validated
- editor-to-runtime parity: authoring output matches runtime-consumed data
  through deterministic generation and parity tests
- round-trip safe authoring: load -> save with no edits preserves semantics via
  canonical deterministic serialization
- schema-versioned assets with explicit migrations and test coverage
- collaboration-friendly storage: one chunk per file with stable field/list
  ordering for reviewable diffs and low-conflict merges
- resilient workflow: autosave drafts, crash recovery, and safe failure when
  export is invalid
- validation-gated export: generation is blocked when critical validation
  errors exist, with actionable in-editor diagnostics
- responsive UX budget: pan/zoom/paint/select stays smooth at target chunk
  sizes on reference hardware

### Core rules

- Grid authority uses Core chunk snap spacing (`TrackTuning.gridSnap`) so
  geometry output, surface extraction, and navigation edge generation remain
  stable and deterministic.
- The same snapped spatial reference is used for navigation extraction, but
  navigation stays surface-graph based (walk surfaces + edges), not tile-cell
  pathfinding.
- Chunk authoring is level-scoped by default; cross-level chunk reuse is not a
  baseline behavior.
- This plan intentionally avoids a freeform map editor.

## 2) Current Repo Baseline (What Exists Today)

### Runtime side

Deterministic chunk streaming currently exists in:

- `packages/runner_core/lib/track/chunk_pattern.dart`
- `packages/runner_core/lib/track/chunk_builder.dart`
- `packages/runner_core/lib/track/track_streamer.dart`
- `packages/runner_core/lib/track/chunk_patterns_library.dart`

Current authored chunk contract is `ChunkPattern` with:

- `platforms`
- `obstacles`
- `groundGaps`
- `spawnMarkers` (enemy-focused)

### Editor side

`tools/editor` already provides:

- plugin architecture via `AuthoringDomainPlugin`
- load/validate/edit/export lifecycle
- undo/redo
- pending diff view
- safe write flow with source-drift guards

Implemented plugin and reusable UI pieces already exist:

- `EntityDomainPlugin`
- grid/zoom/scene/inspector pieces under
  `tools/editor/lib/src/app/pages/entities/**`

Prefab route exists for Phase 0 foundation:

- `tools/editor/lib/src/app/pages/prefabCreator/prefab_creator_page.dart`

Chunk route exists but remains placeholder for later composition phases:

- `tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart`

### Assets

- props atlas exists:
  `assets/images/level/props/TX Village Props.png`
- ground tileset exists:
  `assets/images/level/tileset/TX Tileset Ground.png`

## 3) Product Scope

### In scope

- Definition workflow:
  - atlas/tileset slicing (manual rect authoring)
  - tileset tile slicing for individual ground/platform tiles
  - tile composition: join multiple sliced tiles into reusable bigger platform
    modules
  - tile/prefab/marker definition authoring
  - collider/anchor/tag defaults
- Chunk operations workflow:
  - chunk create/duplicate/rename/deprecate operations
  - stable ID/revision handling and reference-safe updates
- Parallax workflow:
  - level-scoped parallax layer set authoring
  - per-layer asset/speed/depth ordering controls
- Chunk workflow:
  - tile paint
  - ground floor surface authoring
  - gap authoring and constraints
  - prefab placement
  - marker placement
  - metadata authoring (difficulty, sockets, tags, neighbors, weight)
- Level assembly workflow:
  - define a level chunk set and assembly rules
  - validate chunk references, order constraints, and socket transitions
- Validation workflow:
  - structural checks
  - traversal/spawn fairness checks
  - level-scope checks
- Simulation workflow:
  - in-editor run preview using runtime movement constraints
  - jump/dash reachability and unfair-transition diagnostics
- Runtime workflow:
  - generated Dart bridge into `runner_core` target contracts

### Out of scope (for now)

- freeform arbitrary-transform scene building as the default flow
- giant monolithic map files
- manual per-instance collider authoring as standard practice

## 4) Chosen Architecture

Use JSON authoring source of truth + generated Dart runtime data.

### 4.1 Authoring source of truth (data-first)

Authoring files:

- `assets/authoring/level/tile_defs.json`
- `assets/authoring/level/prefab_defs.json`
- `assets/authoring/level/marker_defs.json`
- `assets/authoring/level/chunks/*.json`
- `assets/authoring/level/level_defs.json`

Rules:

- every file has `schemaVersion`
- every chunk has `levelId`
- every chunk has stable identity + revision metadata for migration-safe updates
- integer grid coordinates only for baseline authoring
- canonical serialization order for deterministic diffs

### 4.2 Runtime integration (contract-first, not compatibility-first)

- evolve `runner_core` contracts as soon as cleaner contracts are identified
- avoid keeping legacy contracts longer than needed
- use temporary adapters only as short-lived transition seams
- each contract change requires deterministic tests + migration notes +
  explicit adapter removal criteria

Generated output target:

- generated runtime data under `packages/runner_core/lib/track/**`
- generation entrypoint:
  `tool/generate_chunk_runtime_data.dart`

### 4.3 Reuse-first implementation in `tools/editor`

Do not rebuild fundamentals already present in editor.
Extract and reuse from existing entity tooling where applicable:

- grid rendering and snapping helpers
- zoom/pan scene controls
- inspector sections and form patterns
- session/change-tracking/export plumbing

New chunk features must be added as modular domain plugins/components.

## 5) Authoring Data Contracts (High-Level)

Core authoring contracts:

- `TileDef`
- `PrefabDef`
- `MarkerDef`
- `LevelChunkDef`
- `TileLayerDef`
- `PlacedPrefabDef`
- `PlacedMarkerDef`

Required chunk-level fields:

- `id`
- `revision`
- `schemaVersion`
- `levelId`
- `tileSize`
- `width`
- `height`
- `entrySocket`
- `exitSocket`
- `difficulty`
- `tags`
- `tileLayers`
- `prefabs`
- `markers`

Level-scoping rule:

- chunk load/export validation fails when `levelId` is missing, unknown, or not
  equal to active editor level context

Mapping intent:

- terrain/prefab collision tags map to runtime geometry/collision contracts
- marker definitions map to runtime spawn/trigger contracts
- socket and metadata become runtime-consumed selection constraints
- level assembly definitions map to runtime chunk selection/ordering contracts

## 6) Non-Developer Workflow (Primary User Path)

1. Open **Prefab Creator** and use **Atlas Slice** to cut rectangles from a
   source atlas.
2. Save named slices as reusable source-rect references (props and tiles).
3. Join sliced individual tiles into reusable larger platform modules.
4. Open **Prefab Inspector** and assign anchor/collider/tags/snap/z-index.
5. Open **Chunk Composer** for a selected level.
6. Paint terrain, place prefabs, place markers, edit chunk metadata.
7. Run validation overlay and fix blocking errors.
8. Export/generate runtime data only when validation passes.

No step in the baseline workflow should require editing Dart or raw JSON files.

## 7) Validation Model And Export Gate

### Blocking errors (export denied)

- invalid schema or unknown version without migration path
- missing/unknown `levelId`
- duplicate chunk ID or invalid chunk revision transition
- unknown prefab/tile/marker references
- unknown composed-platform-module references
- unknown chunk references in level assembly definitions
- out-of-bounds placements
- missing required sockets/metadata
- illegal socket transitions in level assembly or neighbor constraints
- deterministic serialization failure
- traversal-critical invalid patterns (configured rule set)

### Warnings (export allowed with explicit acknowledgment)

- soft difficulty spikes
- decorative overlaps without gameplay impact
- non-critical spacing issues

Gate rule:

- phase and export gates both use the same validator categories so behavior is
  consistent between tooling and CI.

## 8) Delivery Phases (Hard Gate Model)

Hard rule: phase `N+1` does not start until phase `N` is implemented, tested,
and accepted.

### Phase 0 - Atlas/Tileset Slicing + Prefab/Tile Foundation + Asset Pipeline Bootstrap

Status: Completed on March 31, 2026

Scope:

- implement Phase 0 inside a dedicated `Prefab Creator` route/page (not in
  `Chunk Creator`)
- add `Atlas Slice` route for manual source-rect selection on atlas/tileset
  sheets
- support slicing individual tiles from tilesets (for example
  `TX Tileset Ground.png`)
- add tile composition tool to join sliced individual tiles into reusable
  larger platform modules
- add prefab inspector route for collider/anchor/tag/snap/z-index authoring
- persist definitions to `prefab_defs.json`
- persist tile slices/composed platform modules to tile definition data
- validate IDs and atlas bounds
- enable/verify asset pipeline wiring for level art in editor/runtime
  (`assets/images/level/**`)

Gate:

- non-dev user can create reusable prefab defs from atlas without code changes
- non-dev user can slice individual tiles and compose bigger platform modules
  from those tiles without code changes
- round-trip load/save works for definitions
- round-trip load/save works for tile slices and composed platform modules
- unit/widget tests for persistence + validation pass
- level atlases load correctly in editor and game builds

### Phase 1 - Chunk Schema + Composer Skeleton + Identity Operations

Scope:

- add chunk domain plugin scaffolding
- activate `Chunk Creator` route as composition workspace (replace placeholder)
- implement typed chunk JSON schema and validation
- implement chunk lifecycle operations: create, duplicate, rename, deprecate
- implement ID/revision safeguards and reference-safe updates

Gate:

- chunk files load/save/validate in editor
- chunk create/duplicate/rename/deprecate operations are deterministic and
  reference-safe
- no unresolved schema-versioning or chunk identity gaps

### Phase 2 - Obstacle/Platform Prefab Authoring

Scope:

- add explicit obstacle/platform prefab authoring flow in editor
- allow obstacle/platform prefabs to reference composed multi-tile platform
  modules created from tileset slices
- require collider + anchor point for obstacle/platform prefab definitions
- add prefab preview with anchor and collider overlays
- persist and validate obstacle/platform prefab defs in canonical format

Gate:

- non-dev user can create obstacle/platform prefabs with collider + anchor
  without code changes
- non-dev user can build platform prefabs from composed multi-tile modules and
  place them with deterministic alignment
- validator blocks obstacle/platform prefab defs missing required collider or
  anchor data
- round-trip load/save remains deterministic

### Phase 3 - Replace Existing Obstacles/Platforms With Prefab-Backed Runtime Data

Scope:

- implement `runner_core` contract changes needed to consume obstacle/platform
  prefab-backed authored data
- add migration path from existing obstacle/platform definitions to prefab refs
  (or generated equivalent runtime data)
- update generator to emit runtime data for prefab-backed obstacles/platforms
- keep temporary adapters only when strictly needed for cutover

Gate:

- runtime obstacle/platform behavior for migrated content is driven by prefab
  authored data
- deterministic replay/streaming behavior remains stable in tests
- legacy obstacle/platform authoring path is removed or marked with explicit
  adapter-removal criteria

### Phase 4 - Parallax Authoring Through Editor

Scope:

- add parallax authoring UI in `tools/editor` for level-scoped parallax sets
- allow creating/editing ordered parallax layers (asset, z/depth, speed factor)
- add preview of parallax motion using editor camera pan controls
- persist parallax definitions in deterministic authoring JSON
- wire generated parallax data into runtime theme/level consumption path

Gate:

- non-dev user can create and edit a level parallax setup fully in editor
- authored parallax data is consumed by runtime without manual Dart edits
- parallax load/save is deterministic and covered by tests

### Phase 5 - Ground Floor + Gap Authoring Through Editor

Scope:

- add dedicated authoring tools for ground floor topology and gap placement
- represent gaps as explicit authored data (width/type/placement), not only
  implicit paint holes
- add live overlays for walkable surfaces, jumpability, and unsafe gap spans
- map authored ground/gap data into runtime contracts deterministically
- validate level-specific gap constraints (minimum/maximum widths and clearance
  rules)

Gate:

- non-dev user can author ground floor and gaps entirely through editor tools
- generated runtime data reproduces authored surfaces/gaps deterministically
- invalid or unfair ground/gap patterns are blocked at export with actionable
  diagnostics

### Phase 6 - Gameplay Marker Authoring + Marker Contract Registry

Scope:

- add dedicated gameplay marker authoring mode in chunk editor
- support baseline marker families (enemy spawn, obstacle spawn, pickup spawn,
  trigger, checkpoint)
- add marker payload editor with typed validation by marker type
- add marker overlap/proximity validation (spawn fairness and illegal overlaps)
- implement marker contract registry: typed payload schema, defaults, and
  migration hooks per marker type
- map markers to runtime spawn/trigger contracts deterministically

Gate:

- non-dev user can create/edit/delete gameplay markers entirely in editor
- marker payload validation blocks invalid runtime configurations
- every shipped marker type has schema/default/migration coverage in tests
- generated runtime data spawns/activates markers deterministically in tests

### Phase 7 - Sockets + Level Assembly Workflow

Scope:

- add socket authoring UI (entry/exit socket + neighbor constraints)
- add explicit socket transition matrix validator (`exit -> next entry`)
- add level assembly editor for selecting chunk sets per level
- add deterministic ordering/weighting rules for assembled level chunk sets
- validate assembled level references and chunk transition legality

Gate:

- illegal socket transitions are blocked before export
- assembled level definitions reference only valid chunks for that level
- runtime chunk selection/ordering consumes socket + assembly constraints
  deterministically

### Phase 8 - Simulation Preview + Validation Hardening

Scope:

- add in-editor simulation preview that uses runtime movement constraints
- visualize jump/dash reachability, dead-ends, and unfair transitions
- align validator rules with simulation outcomes for golden scenarios
- harden UX diagnostics and recovery around simulation failures

Gate:

- simulation replay is deterministic for the same seed/configuration
- validator and simulation agree on pass/fail for golden test chunks
- designers can resolve simulation-blocking issues without code edits

### Phase 9 - First Playable End-To-End Chunk Pipeline

Scope:

- integrate terrain, prefabs, parallax, gaps, markers, sockets, and metadata
  into one level-scoped authoring/export path
- run end-to-end non-dev workflow from atlas slicing to in-game playtest
- verify level assembly constraints and chunk contracts across full level data

Gate:

- a full level chunk set authored in editor runs in-game through target runtime
  contracts
- deterministic replay/streaming tests remain green with authored level data
- non-dev acceptance pass completes on representative production tasks

### Phase 10 - CI Drift Gate + Adapter Removal + Feature Expansion

Scope:

- add CI generation drift check for authored JSON vs generated runtime data
- remove remaining temporary compatibility adapters
- finalize contract docs and migration closure notes
- expand marker/feature support (hazards, teleport gates, power-ups, future)

Gate:

- CI fails when generated runtime data is out-of-sync with source authoring
- no mandatory legacy adapter remains in runtime pipeline
- extensibility path validated by shipping at least one advanced marker family
- deterministic test suite remains green

## 9) Test And Tooling Matrix

Editor:

- `cd tools/editor && dart analyze`
- `cd tools/editor && flutter test`

Core/runtime:

- `dart analyze`
- `dart run tool/generate_chunk_runtime_data.dart`
- targeted deterministic tests including:
  - `test/core/track_streaming_test.dart`
  - `test/core/track_streamer_spawn_placement_test.dart`
  - `test/core/track_streamer_hashash_deferred_spawn_test.dart`

CI drift gate (after generator exists):

- run generator in CI and fail if generated output changes unexpectedly
  (example: `dart run tool/generate_chunk_runtime_data.dart` then
  `git diff --exit-code`)

Asset sync when new level assets are added:

- `dart run tool/sync_assets.dart`

## 10) Implementation Guardrails

- keep authoring state in `tools/editor/**`
- keep authoring data in `assets/authoring/**`
- keep gameplay authority in `packages/runner_core/lib/**`
- keep Flame/UI as consumers of Core snapshots/events
- never bypass validation gate for generated runtime data in normal workflow

## 11) Immediate Next Slice

1. Build Phase 0 routes (`Atlas Slice`, tile composition, `Prefab Inspector`)
   and asset pipeline bootstrap for level art.
2. Implement Phase 1 chunk schema/composer skeleton and chunk identity
   operations (`create/duplicate/rename/deprecate`).
3. Implement Phase 2 obstacle/platform prefab authoring with required collider
   and anchor validation.
4. Start Phase 3 runtime replacement of legacy obstacle/platform definitions
   with prefab-backed runtime data.
5. Start Phase 4 parallax authoring in editor and runtime wiring.
6. Start Phase 5 ground floor and gap authoring tools with validation overlays.
7. Start Phase 6 gameplay marker authoring and marker contract registry.
