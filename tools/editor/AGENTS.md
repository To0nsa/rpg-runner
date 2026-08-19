# AGENTS.md - Editor Tool

Instructions for AI coding agents working in `tools/editor/`.

## Editor Responsibility

`tools/editor` is a standalone Flutter authoring app for repository-backed
content workflows in `rpg_runner`.

It currently owns editor UX, validation, and deterministic import/export for:

- entity collider/source-bound edits
- prefab, tile, and platform-module authoring data
- chunk authoring data
- parallax theme authoring data
- level metadata authoring data

The editor may author data consumed by gameplay, but gameplay authority stays
outside the editor:

- runtime rules and simulation authority remain in `packages/runner_core/lib/**`
- reusable current-schema chunk compilation and Core runtime-data
  materialization remain in `packages/runner_content_pipeline/lib/**`
- source-of-truth repository writes remain explicit, deterministic, and
  reviewable
- do not turn the editor into a gameplay shell, a generic asset manager, or a
  backend/admin tool

## Scope And Growth Direction

Keep the editor small, focused, and extensible.

- small: prefer the least abstraction that cleanly serves current authoring
  workflows
- focused: this app exists to safely edit repository content that the team
  actively needs to author
- extensible: new authoring domains such as animation data or other
  gameplay-facing data are allowed when there is a concrete current workflow to
  support
- future growth should add one bounded authoring domain at a time, with a clear
  source of truth, deterministic validation/export rules, and tests
- future-proofing means preserving clean seams so new domains can slot into the
  existing plugin/session architecture without broad rewrites
- do not build speculative platform layers, generic tool frameworks, or
  "someday" abstractions for workflows that do not exist yet

## Read First

- repo root: `AGENTS.md`
- docs policy: `docs/rules/code-documentation-policy.md`
- chunk roadmap/checklists: `docs/building/editor/chunkCreator/**` when changing
  prefab/chunk contracts or milestone status
- Windows playtest roadmap/checklists:
  `docs/building/editor/windowsChunkPlaytest/**` when changing desktop input,
  preview preparation, or Play mode
- archived level creator plan:
  `docs/building/archived/editor/levelCreator/plan.md` for historical level
  authoring context

## Commenting For Onboarding

Comments and docs in `tools/editor` should help a new contributor understand
the slice quickly, not just satisfy API formality.

- prefer comments that explain intent, ownership, invariants, and why a seam
  exists
- be onboarding-friendly around session/plugin/route boundaries: make it easy
  for a new reader to tell which layer owns load, validation, scene building,
  pending changes, and export
- document non-obvious data flow and lifecycle rules, especially where page
  draft state projects over plugin-owned document state
- when a file is an entry point or registry, say so explicitly and describe
  what it is the source of truth for
- use comments to shorten ramp-up time for new contributors, but do not narrate
  obvious code or restate names
- if a newcomer would likely ask "why is this here instead of in the page/plugin/store?",
  that is a good place for a comment

Good editor comments should let someone new form the right mental model without
reading five other files first.

## Current Architecture

- app entry: `tools/editor/lib/main.dart`
- app bootstrap: `tools/editor/lib/src/app/runner_editor_app.dart`
- session orchestration: `tools/editor/lib/src/session/editor_session_controller.dart`
- plugin contract + registry:
  - `tools/editor/lib/src/domain/authoring_types.dart`
  - `tools/editor/lib/src/domain/authoring_plugin_registry.dart`
- plugin-backed routes:
  - `Entities` route -> `EntityDomainPlugin`
  - `Prefab Creator` route -> `PrefabDomainPlugin`
  - `Chunk Creator` route -> `ChunkDomainPlugin`
  - `Level Creator` route -> `LevelDomainPlugin`
  - `Parallax` route -> `ParallaxDomainPlugin`
  - `Terrain Materials` route -> `TerrainMaterialDomainPlugin`
- route/plugin mapping and session-coherent route switching:
  - `tools/editor/lib/src/app/pages/home/home_routes.dart`
  - `tools/editor/lib/src/app/pages/home/editor_home_page.dart`
- shared scene/view primitives:
  - `tools/editor/lib/src/app/pages/shared/**`

Page widgets may own transient UI state such as selection, tool mode, tab
state, viewport state, and form drafts. Repository load/validate/export
authority belongs in plugins and stores, not in alternate page-level write
paths.

## Consistent UX, Modularization, Reuse, And Redundancy Bar

Treat editor changes as maintainability work, not just feature delivery.

- the editor is one product: keep equivalent layouts, selection behavior,
  toolbars, dialogs, validation feedback, scene controls, and visual treatment
  consistent across authoring routes
- reuse-first: before adding new helpers/widgets/state flows, search existing
  code (`rg`) for equivalent behavior and extend the established pattern when
  possible
- no copy/paste feature logic across routes: if the same behavior appears in
  two places, consolidate into shared code in the same change unless there is a
  clear blocker
- shared scene behavior belongs in `tools/editor/lib/src/app/pages/shared/**`;
  avoid per-page forks for pan/zoom/grid/input semantics
- domain logic belongs in domain/state/store files, not in widget trees:
  - parsing/migration/serialization in `src/*/store.dart` or parser files
  - validation rules in `src/*/validation.dart`
  - command/state transitions in plugin or page-state logic files
- keep deterministic rules single-sourced (sorting, slug allocation, identity
  normalization, revision bump policy). Do not duplicate these rules in both UI
  and store layers
- page-local state is allowed for editing ergonomics, but it must reconcile
  through one plugin-owned document/export path
- remove dead or shadowed code paths as part of the change; do not leave
  parallel legacy paths without explicit removal criteria
- if temporary duplication is unavoidable, annotate with a tracked TODO and a
  clear removal trigger, then close it quickly
- when adding a future authoring domain, compose the existing session/plugin and
  shared-scene infrastructure before introducing new framework layers

Before finalizing non-trivial edits, do a redundancy pass:

1. compare the changed UX with its nearest existing editor workflow and reuse
   established controls or shared primitives where they fit
2. check for duplicate helpers/constants introduced in the touched scope
3. check for repeated branching/validation logic that can be extracted
4. check for similar widget sections that should be parameterized/composed
5. verify refactor did not weaken determinism or export/write safety

## Review Expectations

When the user asks for a review, default to a senior-level maintainability and
correctness review, not just a compile/test pass.

- actively look for redundancy, overlapping abstractions, duplicate logic, and
  copy/paste behavior
- look for unused or dead code, stale public surface, shadowed ownership, and
  legacy paths that should be removed
- judge changes against best current code practice in this repo: clear ownership,
  fail-fast configuration, deterministic behavior, explicit failure handling,
  and small focused APIs
- push toward DRY when duplication is real and current, but do not invent
  speculative abstractions just to remove a small amount of repetition
- call out places where generic contracts are actually domain-specific, where UI
  and plugin/store responsibilities are mixed, or where a page is becoming a
  second persistence authority
- treat "good review" as maintainability work too: surface weak seams, stale
  docs/contracts, missing focused tests, and accidental complexity early

Review findings should be high-signal and concrete. Prioritize bugs and
behavioral risk first, then redundancy, unused code, API shape, and longer-term
maintainability concerns.

## Domain Ownership And Write Targets

### Entities Domain

- owner: `tools/editor/lib/src/entities/**`
- plugin: `EntityDomainPlugin`
- source parser: `entity_source_parser.dart`
- writes are direct source edits against authoritative Dart files using source
  bindings/range replacement guards
- keep drift safety and backup behavior intact; do not bypass plugin/export
  guardrails with ad-hoc file writes

### Prefab + Tile/Module Domain

- owner: `tools/editor/lib/src/prefabs/**` and
  `tools/editor/lib/src/app/pages/prefabCreator/**`
- plugin: `PrefabDomainPlugin`
- source-of-truth files:
  - `assets/authoring/level/prefab_defs.json`
  - `assets/authoring/level/tile_defs.json`
- `prefab_defs.json` uses strict schema v3 polygon `collisionShapes`; legacy
  Prefab parsing belongs to the explicit offline polygon migration command
- persist through `PrefabStore` so canonical ordering and atomic paired writes
  stay consistent
- page-local form and scene state may stay in `prefabCreator/**`, but
  load/validate/export contracts still flow through the prefab plugin/store path
- validation is structural and contract-oriented; keep obstacle/platform
  contracts typed and deterministic

### Shared Atlas Authoring Foundation

- owner: `tools/editor/lib/src/atlas/**`,
  `tools/editor/lib/src/workspace/repository_png_catalog.dart`, and the neutral
  `tools/editor/lib/src/app/pages/shared/atlas_*.dart` widgets
- shared code owns integer pixel rectangles, configurable grid math, temporary
  selection state, per-workspace grid-setting caches, repository PNG discovery,
  view transforms, painters, manual fields, and exact-region previews
- shared code must remain independent of Prefab IDs, terrain roles, revisions,
  persistence commands, and domain-specific root policies
- Prefab and terrain callers translate between their domain values and the
  shared pixel rectangle; do not restore domain-specific copies of grid,
  coordinate, PNG-header, or thumbnail logic
- grid settings are editor-session state only and must not leak into source JSON
  or generated runtime contracts

### Terrain Material Domain

- owner: `tools/editor/lib/src/terrain_materials/**` and
  `tools/editor/lib/src/app/pages/terrainMaterials/**`
- plugin: `TerrainMaterialDomainPlugin`
- source-of-truth file:
  `assets/authoring/level/terrain_material_defs.json`
- source-image root: `assets/images/terrain/**`
- the manifest uses strict schema v3 explicit image regions and paired top and
  underside endpoint/corner caps; normal editor code must not accept older
  schemas or add a migration fallback
- source models, canonical validation, traversal, repeat/seam math, and
  normalized region-footprint math come from `packages/terrain_materials`; do
  not duplicate those rules in the editor
- discover image metadata through `RepositoryPngCatalog`, then fully decode and
  bounds-check referenced images again during apply
- persist through `TerrainMaterialStore` so canonical ordering, drift guards,
  revision semantics, and atomic writes remain authoritative
- atlas grid state is not material content; same-region assignment and grid-only
  changes must remain revision-neutral

### Chunk Domain

- owner: `tools/editor/lib/src/chunks/**` and
  `tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart`
- plugin: `ChunkDomainPlugin`
- source-of-truth directory: `assets/authoring/level/chunks/*.json`
- checked-in chunks use strict schema v2 direct polygon `collisionShapes`;
  direct shapes may use `collisionMode: none` for render-only terrain, which
  must be partitioned before Core collision expansion while remaining in the
  generated render snapshot; Prefab collision shapes remain solid/one-way;
  legacy flat-profile/gap parsing belongs to offline migration only
- keep one-chunk-per-file semantics, stable `chunkKey`, deterministic save-plan
  output, source-drift checks, and case-insensitive path-collision protection

### Parallax Domain

- owner: `tools/editor/lib/src/parallax/**` and
  `tools/editor/lib/src/app/pages/parallaxEditor/**`
- plugin: `ParallaxDomainPlugin`
- source-of-truth file: `assets/authoring/level/parallax_defs.json`
- parallax themes are visual-only render data keyed by stable `parallaxThemeId`
- active level selection resolves the current `parallaxThemeId` via
  authored `assets/authoring/level/level_defs.json`; generated runtime
  registries are output and must not become editor validation authority;
  multiple levels may reuse the same authored theme
- terrain materials own ground visuals, geometry, collision, traversal, spawn,
  and streaming; parallax themes must not define a ground material
- keep deterministic theme/layer ordering, canonical numeric formatting, and
  validation/export gating in the plugin/store path instead of page-local logic

### Level Domain

- owner: `tools/editor/lib/src/levels/**` and
  `tools/editor/lib/src/app/pages/levelCreator/**`
- plugin: `LevelDomainPlugin`
- source-of-truth file: `assets/authoring/level/level_defs.json`
- current scope includes the Level Creator route, list/inspector UI, store,
  validation, plugin, explicit create/reuse visual-theme workflow, compound
  pending diff, rollback-safe two-source write, and guarded Parallax handoff
- `levelId` remains stable identity, `visualThemeId` ownership belongs here, and
  gameplay authority stays in core/chunk systems
- create/use-existing intent must remain explicit; new themes are empty
  revision-1 Parallax records and must be staged in the same session command as
  their Level reference
- Level Creator export must compose `LevelStore` and `ParallaxStore` plans and
  verify both baselines through one `WorkspaceWriteTransaction`; never sequence
  independent store saves for this workflow
- keep canonical file ordering by `levelId`, stable `enumOrdinal`, source-drift
  checks, and export gating in the plugin/store path

### Future Authoring Domains

New authoring domains are allowed when they represent a real current workflow,
for example animation authoring or additional gameplay-facing data authoring.

Each new domain should define:

- an owning folder under `tools/editor/lib/src/**`
- authoritative repo files or source bindings
- a plugin id and route mapping when the workflow is user-facing
- deterministic validation and export rules
- focused tests for load/edit/export/session behavior

Do not overload an existing plugin with unrelated concerns just to avoid adding
a well-bounded new domain.

## Determinism And Validation Rules

- preserve canonical ordering and serialization in stores/models
- keep validation/export gating strict: blocking errors must prevent writes
- keep migration behavior explicit, deterministic, and test-backed
- do not silently coerce identity fields (`chunkKey`, `prefabKey`, module IDs)
  in a way that breaks existing references
- keep pending-change previews coherent with actual export behavior; UI should
  not imply writes the plugin will not perform

## Scene/Input Control Rules

Scene interaction behavior for touched views must stay consistent through shared
code under `tools/editor/lib/src/app/pages/shared/scene_input_utils.dart`.

- `Ctrl+drag`: pan
- `Ctrl+scroll`: zoom stepping
- primary drag: tool-driven behavior (selection/paint/erase/move depending on
  active tool)

Do not introduce per-view control drift without explicit rationale and tests.

## Adding Or Changing Routes/Plugins

When adding a new plugin-backed authoring domain:

1. Implement `AuthoringDomainPlugin` end to end (`loadFromRepo`, `validate`,
   `buildEditableScene`, `applyEdit`, `describePendingChanges`,
   `exportToRepo`).
2. Register the plugin in `runner_editor_app.dart`.
3. Wire route/plugin mapping in `home_routes.dart`.
4. Ensure route switching remains session-coherent in `editor_home_page.dart`.
5. Keep page-local UI state as a projection over plugin-owned document state,
   not as a second persistence authority.
6. Add or adjust focused tests for load/edit/export and route/workspace
   switching behavior.

If a route is widget-heavy, keep that complexity in UI composition and local
interaction state. Do not let that become a second import/export architecture.

## Validation Expectations

Minimum checks for editor changes:

- `cd tools/editor && dart analyze`
- `cd tools/editor && flutter test`

Run focused tests for touched slices, for example:

- session/route/plugin coordination:
  - `tools/editor/test/home_route_plugin_switch_test.dart`
  - `tools/editor/test/editor_session_controller_test.dart`
- workspace/path safety:
  - `tools/editor/test/editor_workspace_test.dart`
- entities/source editing:
  - `tools/editor/test/entity_document_pipeline_test.dart`
  - `tools/editor/test/entity_parser_export_test.dart`
  - `tools/editor/test/entity_inspector_panel_test.dart`
- prefab/module workflows:
  - `tools/editor/test/prefab_v3_file_codec_test.dart`
  - `tools/editor/test/prefab_v3_save_plan_test.dart`
  - `tools/editor/test/prefab_v3_domain_plugin_test.dart`
  - `tools/editor/test/prefab_v3_collision_commit_test.dart`
  - `tools/editor/test/prefab_polygon_validation_test.dart`
  - `tools/editor/test/prefab_polygon_authoring_controller_test.dart`
  - `tools/editor/test/platform_module_scene_view_test.dart`
- chunk workflows:
  - `tools/editor/test/chunk_v2_file_codec_test.dart`
  - `tools/editor/test/chunk_v2_save_plan_test.dart`
  - `tools/editor/test/chunk_v2_domain_plugin_test.dart`
  - `tools/editor/test/chunk_v2_collision_commit_test.dart`
  - `tools/editor/test/chunk_scene_coordinator_test.dart`
  - `tools/editor/test/chunk_polygon_authoring_controller_test.dart`
  - `tools/editor/test/chunk_prefab_scene_gesture_test.dart`
- terrain material workflows:
  - `tools/editor/test/terrain_material_domain_plugin_test.dart`
  - `tools/editor/test/terrain_materials_page_test.dart`
  - `tools/editor/test/terrain_material_preview_test.dart`
- parallax workflows:
  - `tools/editor/test/parallax_store_test.dart`
  - `tools/editor/test/parallax_domain_plugin_test.dart`
  - `tools/editor/test/parallax_editor_page_test.dart`
- level workflows:
  - `tools/editor/test/level_store_test.dart`
  - `tools/editor/test/level_domain_plugin_test.dart`
  - `tools/editor/test/level_domain_plugin_integration_test.dart`
  - `tools/editor/test/level_creator_page_test.dart`
  - `tools/editor/test/level_visual_theme_workflow_test.dart`
  - `tools/editor/test/level_context_resolver_test.dart`

When authoring-runtime contract seams are touched, also run repo-level
generator validation:

- `dart run tool/generate_chunk_runtime_data.dart --dry-run`

## Common Failure Modes To Avoid

- bypassing stores/plugins with one-off file writes
- introducing non-deterministic ordering in save output
- weakening source-drift checks to force writes through
- leaking runtime gameplay rules into editor/UI layers
- adding custom scene-input behavior in one view instead of reusing shared
  scene-control utilities
- adding speculative abstractions for future workflows without a concrete
  current authoring need
- letting page-local state become a second source of truth for repo writes

## Documentation Upkeep

When editor contracts or workflows change:

- follow the repo-root documentation policy: update or create `docs/tdd/**`
  for technical architecture, ownership, persistence, data-flow, or
  determinism changes; update `docs/gdd/**` for implemented player-facing
  workflow or UX changes; update both when both are affected
- update this file if boundaries/rules drift
- update `tools/editor/README.md` for user-visible capability changes
- update `docs/building/editor/chunkCreator/plan.md` and relevant phase
  checklist/closure docs for chunk/prefab milestone changes
- use `docs/building/**` for proposed or in-progress work; it does not replace
  TDD/GDD documentation for delivered behavior
- for newly added authoring domains, add focused documentation only for the
  implemented workflow; keep future ideas separate from current behavior
