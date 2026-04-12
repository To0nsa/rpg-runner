# Chunk Creator High-Level Plan

Date: March 27, 2026  
Status: Active (Phase 0 completed on March 31, 2026; Phase 1 completed on April 1, 2026; Phase 2 completed on April 1, 2026; Phase 3 completed on April 3, 2026; Phase 4 completed on April 11, 2026; Phase 5 completed on April 11, 2026; Phase 6 completed on April 11, 2026; Phase 7 completed on April 11, 2026; Phase 10 completed on April 10, 2026; Phases 8-9 and 11 remain open)

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
- immutable identity + rename safety: each chunk has a stable `chunkKey` that
  never changes, while human-readable `id` can change via explicit rename flow
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
- `packages/runner_core/lib/track/authored_chunk_patterns.dart`

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

Chunk route is now a functional composition workspace skeleton:

- `tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart`

Parallax route now exists as a dedicated theme-authoring workflow:

- `tools/editor/lib/src/app/pages/parallaxEditor/parallax_editor_page.dart`

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
  - theme-scoped parallax layer set authoring reusable across levels
  - deterministic level -> theme resolution via runtime level registry
  - per-layer asset/speed/depth ordering controls
  - render-side ground material selection only; gameplay ground authority stays
    in chunk/core systems
- Chunk workflow:
  - tile paint
  - ground floor surface authoring
  - gap authoring and constraints
  - prefab placement
  - marker placement
  - metadata authoring (difficulty, tags, neighbors, weight)
- Level assembly workflow:
  - define a level chunk set and assembly rules
  - validate chunk references, order constraints, and optional render-theme
    sequencing rules
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
- `assets/authoring/level/parallax_defs.json`

Rules:

- every file has `schemaVersion`
- every chunk has `levelId`
- every chunk has stable identity + revision metadata for migration-safe updates:
  `chunkKey` is immutable, `id` is renameable label identity
- integer grid coordinates only for baseline authoring
- deterministic filename policy is explicit and collision-safe on case-sensitive
  and case-insensitive filesystems
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

- `chunkKey`
- `id`
- `revision`
- `schemaVersion`
- `levelId`
- `tileSize`
- `width`
- `height`
- `difficulty`
- `tags`
- `tileLayers`
- `prefabs`
- `markers`
- `groundProfile`
- `groundGaps`

Current simplification:

- `entrySocket` and `exitSocket` were removed from the live chunk contract for
  now
- do not reintroduce transition/socket metadata until there is a concrete
  runtime problem that requires it

Floor/gap contract rollout rule:

- Phase 1 introduces schema/store/validation ownership for `groundProfile` and
  `groundGaps` (contract only).
- Phase 5 adds flat-floor gap authoring and scene/runtime parity on top of
  that existing contract.
- richer terrain editing, jumpability overlays, and fairness policy stay out of
  Phase 5 until gameplay rules are explicit enough to justify them.
- Phase 1 contract shape must already be extensible:
  - `groundProfile` uses typed kind/schema fields (not ad-hoc map payloads)
  - each `groundGap` has stable identity + type + snapped placement fields
  - default values are explicit so future tool modes do not require schema
    rewrites

Level-scoping rule:

- chunk load/export validation fails when `levelId` is missing, unknown, or not
  equal to active editor level context
- active editor level context must come from explicit level options using this
  deterministic precedence:
  1. `assets/authoring/level/level_defs.json` (when present and valid)
  2. `packages/runner_core/lib/levels/level_id.dart` enum values
  3. distinct `levelId` values discovered from loaded chunk files (sorted)
- active level selection policy must be deterministic:
  1. keep current selection if still present in options
  2. otherwise pick the lexicographically first option
  3. if no options exist, block export with explicit validation error

Mapping intent:

- terrain/prefab collision tags map to runtime geometry/collision contracts
- marker definitions map to runtime spawn/trigger contracts
- chunk metadata and optional render-theme sequencing become runtime-consumed
  selection constraints
- ground profile and gap definitions map to runtime ground segment/gap
  contracts
- level assembly definitions map to runtime chunk selection/ordering contracts

Grid and sizing rule:

- numeric geometry-affecting fields in chunk contracts must be snapped to
  `TrackTuning.gridSnap`
- chunk width contract must map cleanly to runtime `TrackTuning.chunkWidth`
  (or explicit per-level override once introduced)

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
- missing/invalid `chunkKey` or duplicate `chunkKey`
- missing/unknown `levelId`
- active level-context mismatch (`chunk.levelId != activeLevelId`)
- duplicate chunk ID or invalid chunk revision transition
- unknown prefab/tile/marker references
- unknown composed-platform-module references
- unknown chunk references in level assembly definitions
- grid-snapping violations for geometry-affecting fields
- chunk width incompatible with runtime chunk width contract
- out-of-bounds placements
- missing required assembly metadata
- invalid level assembly ordering/weighting or render-theme sequencing
- deterministic filename collision (including case-insensitive collision risk)
- source-drift detected between load baseline and export target
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

Status: Completed on April 1, 2026

Implementation checklist:
[docs/building/editor/chunkCreator/phase1-implementation-checklist.md](docs/building/editor/chunkCreator/phase1-implementation-checklist.md)

Scope:

- add chunk domain plugin scaffolding
- activate `Chunk Creator` route as composition workspace (replace placeholder)
- implement typed chunk JSON schema and validation
- replace assert-only runtime geometry guards with runtime-safe validation paths
  in Core chunk build/stream flow
- add runtime chunk-source abstraction so `TrackStreamer` is not hard-bound to
  any legacy static pattern library
- add immutable `chunkKey` + rename-safe identity semantics (`id` may change;
  `chunkKey` may not)
- add explicit deterministic filename strategy and case-insensitive collision
  handling for chunk files
- introduce explicit floor/gap contract fields (`groundProfile`, `groundGaps`)
  in chunk schema/store/validation
- add active level-context authority plumbing in chunk workflow with deterministic
  level-option source
- enforce grid snap + chunk-width structural validation in Phase 1 validators
- bootstrap generator seam (`tool/generate_chunk_runtime_data.dart`) with at
  least schema/contract validation mode
- create `tool/generate_chunk_runtime_data.dart` in Phase 1 with stable
  `--dry-run` behavior (deterministic output + deterministic non-zero exit on
  blocking validation failures)
- add runtime identity passthrough (`chunkKey`, `gapId`) through chunk/ground
  metadata where practical, without behavior drift
- implement chunk lifecycle operations: create, duplicate, rename, deprecate
- implement ID/revision safeguards and reference-safe updates
- implement drift-safe export semantics (baseline fingerprint checks + atomic
  writes)

Gate:

- chunk files load/save/validate in editor
- chunk create/duplicate/rename/deprecate operations are deterministic and
  reference-safe
- Core chunk geometry validation is enforced in all build modes (not `assert`-only)
- `TrackStreamer` consumes chunk data via abstraction seam, not direct hardcoded
  pattern dependency
- immutable `chunkKey` survives rename operations and is validated
- active level context is enforced for load/save/export validation paths
- grid/chunk-width invariants are validated before write/export
- deterministic filename policy avoids case-collision and rename drift
- floor/gap contract fields round-trip deterministically without manual JSON
  edits
- generator seam entrypoint exists and `--dry-run` runs in CI/local flow
- runtime metadata supports stable identity passthrough needed for authored
  chunk cutover (`chunkKey`/`gapId`)
- export detects source drift before write and applies writes atomically
- Phase 1 runtime seam changes are verified by explicit core test commands
- no unresolved schema-versioning or chunk identity gaps

Finalized Phase 1 policy decisions:

- revision policy:
  - create: `revision = 1`
  - duplicate: new identity with `revision = 1`
  - rename: updates `id` only and preserves `chunkKey` + revision
  - metadata/ground edits: bump revision by `+1` when values change
  - deprecate: idempotent; first transition to deprecated bumps revision by `+1`
- deprecate representation: explicit schema field `status: deprecated`
- deterministic filename policy:
  - loaded chunks preserve baseline source path even when `id` is renamed
  - new chunks default to `assets/authoring/level/chunks/<slug(chunkKey)>.json`
  - export blocks case-insensitive filename collisions deterministically
- active level-context precedence (implemented):
  1. `assets/authoring/level/level_defs.json`
  2. `packages/runner_core/lib/levels/level_id.dart`
  3. discovered chunk `levelId` values from loaded files

Phase 1 added files/contracts (implementation output list):

- `tools/editor/lib/src/chunks/chunk_domain_models.dart`
- `tools/editor/lib/src/chunks/chunk_store.dart`
- `tools/editor/lib/src/chunks/chunk_validation.dart`
- `tools/editor/lib/src/chunks/chunk_domain_plugin.dart`
- `tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart`
- `tool/generate_chunk_runtime_data.dart`
- `packages/runner_core/lib/track/chunk_pattern_source.dart`
- `test/tool/generate_chunk_runtime_data_test.dart`

### Phase 2 - Obstacle/Platform Prefab Authoring

Status: Completed on April 1, 2026

Implementation checklist:
[docs/building/editor/chunkCreator/phase2-implementation-checklist.md](docs/building/editor/chunkCreator/phase2-implementation-checklist.md)

Step 0 contract freeze:
[docs/building/editor/chunkCreator/phase2-step0-contract-freeze.md](docs/building/editor/chunkCreator/phase2-step0-contract-freeze.md)

Phase 2 closure summary:
[docs/building/editor/chunkCreator/phase2-closure-summary.md](docs/building/editor/chunkCreator/phase2-closure-summary.md)

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

### Phase 3 - Platform Module Creator + Scene Composition Authoring

Status: Completed on April 3, 2026

Implementation checklist:
[docs/building/editor/chunkCreator/phase3-implementation-checklist.md](docs/building/editor/chunkCreator/phase3-implementation-checklist.md)

Scope:

- add a dedicated platform-module authoring workflow with a scene view in
  `tools/editor`
- standardize scene-view controls across editor authoring surfaces (for example
  `Ctrl+drag` pan, wheel/pinch zoom, deterministic tool-modified primary drag)
  so control meaning is consistent for non-dev users
- implement scene-view input behavior through shared modularized code in
  `tools/editor/lib/src/app/pages/shared/**` so new scene views inherit the
  same controls with minimal custom code
- compose platform modules from sliced tiles with grid-snapped placement,
  deterministic tile ordering, and explicit module bounds
- support full module lifecycle operations needed for non-dev iteration
  (create, edit, duplicate, rename, deprecate/remove-safe)
- enforce module validation rules (valid tile-slice refs, in-bounds geometry,
  collision-safe IDs, deterministic canonical serialization)
- persist module data in `tile_defs.json` in canonical deterministic form
- ensure authored platform modules are immediately consumable by prefab authoring
  (`visualSource.type = platform_module`) without hand-editing JSON

Gate:

- non-dev user can create/edit platform modules entirely in-editor via scene
  view, without JSON edits
- scene-view control semantics are consistent across phase-touched views and
  backed by shared reusable input-control code
- authored modules round-trip load/save deterministically
- module validation blocks invalid composition states before save/export
- platform prefab flow can reference newly authored modules in the same session

### Phase 4 - Replace Existing Obstacles/Platforms With Prefab-Backed Runtime Data

Status: Completed on April 11, 2026

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

### Phase 5 - Flat Floor + Explicit Gap Authoring Through Editor

Status: Completed on April 11, 2026

Scope:

- keep `groundProfile` flat and runtime-locked for all current levels
- author explicit gaps against `groundGaps` on top of that locked flat floor
- use platforms above gaps for vertical variation instead of introducing terrain
  sculpting early
- render authored solid spans and gap spans in the chunk scene with runtime
  parity
- validate structural gap rules only: deterministic ordering, stable identity,
  grid snap, bounds, and overlap

Gate:

- non-dev user can author explicit gaps entirely through editor tools without
  hand-editing JSON
- generated runtime data reproduces authored surfaces/gaps deterministically
- invalid structural gap patterns are blocked at export with actionable
  diagnostics

Deferred from Phase 5:

- richer terrain editing (`ramps`, `steps`, per-segment height)
- jumpability or unsafe-gap overlays tied to character/enemy movement rules
- level-specific fairness constraints such as min/max widths or clearance rules

### Phase 6 - Enemy Spawn Marker Authoring Through Editor

Status: Completed on April 11, 2026

Scope:

- support the gameplay marker family the current game actually uses:
  deterministic enemy spawn markers
- add dedicated enemy-marker authoring in the chunk editor
- support typed enemy marker payload editing for `markerId`, `x`, `y`,
  `chancePercent`, `salt`, and `placement`
- validate marker ids, bounds, snap, chance range, salt, and placement against
  the current runtime contract
- map authored enemy markers deterministically into runtime `SpawnMarker`
  output

Gate:

- non-dev user can create/edit/delete enemy spawn markers entirely in editor
- marker payload validation blocks invalid runtime configurations
- generated runtime data spawns enemy markers deterministically in tests

Deferred from Phase 6:

- obstacle, pickup, trigger, checkpoint, and future marker families
- broad marker-family registry/default/migration infrastructure before multiple
  gameplay marker families actually exist
- overlap/proximity fairness policy beyond the enemy spawn rules the runtime
  already enforces

### Phase 7 - Level Assembly + Render Theme Sequencing

Status: Completed on April 11, 2026

Implementation checklist:
[docs/building/editor/chunkCreator/phase7-implementation-checklist.md](docs/building/editor/chunkCreator/phase7-implementation-checklist.md)

Scope:

- add level assembly editor for selecting chunk sets per level
- add deterministic ordering/weighting rules for assembled level chunk sets
- add optional render-only chunk theme sequencing so selected chunks can drive
  temporary visual theme runs without affecting gameplay authority
- validate assembled level references, ordering legality, and render-theme
  sequencing rules

Gate:

- assembled level definitions reference only valid chunks for that level
- runtime chunk selection/ordering consumes assembly constraints
  deterministically
- authored render-theme sequencing resolves through runtime render/theme lookup
  without affecting deterministic gameplay state

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

- integrate terrain, prefabs, gaps, markers, assembly metadata, and optional
  render-theme sequencing into one level-scoped authoring/export path
- run end-to-end non-dev workflow from atlas slicing to in-game playtest
- verify level assembly constraints and chunk contracts across full level data

Gate:

- a full level chunk set authored in editor runs in-game through target runtime
  contracts
- deterministic replay/streaming tests remain green with authored level data
- non-dev acceptance pass completes on representative production tasks

### Phase 10 - Parallax Authoring Through Editor (Visual Theme Layer)

Status: Completed on April 10, 2026

Implementation note:

- this phase was delivered out of the original sequence once the generator and
  runtime theme bridge were ready, without expanding parallax into gameplay
  authority

Scope:

- add parallax authoring UI in `tools/editor` for theme-scoped parallax sets
- resolve active theme selection from level context through
  `level_registry.dart` so a single authored theme can be reused by multiple
  levels
- allow creating/editing ordered parallax layers (asset, z/depth, speed factor)
- add preview of parallax motion using editor camera pan controls
- persist parallax definitions in deterministic authoring JSON
- wire generated parallax data into runtime theme/level consumption path
- keep ground geometry and other gameplay-critical decisions outside parallax;
  only render/theme lookup consumes authored parallax data
- integrate parallax into previously shipped chunk pipeline without regressing
  deterministic gameplay behavior

Gate:

- non-dev user can create and edit a reusable parallax theme fully in editor
- multiple levels can resolve the same authored theme without duplicating data
- authored parallax data is consumed by runtime without manual Dart edits
- parallax load/save is deterministic and covered by tests
- adding parallax does not alter gameplay-critical deterministic chunk outcomes

### Phase 11 - CI Drift Gate + Adapter Removal + Feature Expansion

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
- `dart run tool/generate_chunk_runtime_data.dart --dry-run` (Phase 1 seam)
- `dart run tool/generate_chunk_runtime_data.dart`
- targeted deterministic tests including:
  - `test/core/track_streaming_test.dart`
  - `test/core/track_streamer_spawn_placement_test.dart`
  - `test/core/track_streamer_hashash_deferred_spawn_test.dart`

Phase 1 minimum runtime verification commands:

- `flutter test test/core/track_streaming_test.dart`
- `flutter test test/core/track_streamer_spawn_placement_test.dart`
- `flutter test test/core/track_streamer_hashash_deferred_spawn_test.dart`

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
- keep scene-view input controls centralized and reusable; avoid per-view
  bespoke control mappings when shared control semantics are intended

## 11) Immediate Next Slice

1. Keep completed Phases 3-6 green with regression verification only (do not
   reopen completed scope):
   - `cd tools/editor && dart analyze`
   - `cd tools/editor && flutter test`
2. Keep completed Phase 7 assembly/theme sequencing green while the remaining
   chunk/runtime phases land.
3. Start Phase 8 simulation preview + validation hardening.
4. Start Phase 9 first playable end-to-end chunk pipeline.
5. Keep Phase 10 parallax parity and determinism coverage green while the
   remaining chunk/runtime phases land.
6. Start Phase 11 CI drift gate + adapter removal hardening.
