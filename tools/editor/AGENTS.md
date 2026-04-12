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

The editor may author data consumed by gameplay, but gameplay authority stays
outside the editor:

- runtime rules and simulation authority remain in `packages/runner_core/lib/**`
- source-of-truth repository writes remain explicit, deterministic, and
  reviewable
- do not turn the editor into a gameplay shell, a generic asset manager, or a
  backend/admin tool

Current in-progress domain foundations also include:

- level metadata authoring in `tools/editor/lib/src/levels/**`

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
- docs policy: `docs/rules/documentation_and_commenting_guide.md`
- chunk roadmap/checklists: `docs/building/editor/chunkCreator/**` when changing
  prefab/chunk contracts or milestone status

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
- route/plugin mapping and session-coherent route switching:
  - `tools/editor/lib/src/app/pages/home/home_routes.dart`
  - `tools/editor/lib/src/app/pages/home/editor_home_page.dart`
- shared scene/view primitives:
  - `tools/editor/lib/src/app/pages/shared/**`

Page widgets may own transient UI state such as selection, tool mode, tab
state, viewport state, and form drafts. Repository load/validate/export
authority belongs in plugins and stores, not in alternate page-level write
paths.

## Modularization, Reuse, And Redundancy Bar

Treat editor changes as maintainability work, not just feature delivery.

- reuse-first: before adding new helpers/widgets/state flows, search existing
  code (`rg`) for equivalent behavior and extend what already exists when
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

1. check for duplicate helpers/constants introduced in the touched scope
2. check for repeated branching/validation logic that can be extracted
3. check for similar widget sections that should be parameterized/composed
4. verify refactor did not weaken determinism or export/write safety

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
- persist through `PrefabStore` so canonical ordering, migration defaults, and
  atomic paired writes stay consistent
- page-local form and scene state may stay in `prefabCreator/**`, but
  load/validate/export contracts still flow through the prefab plugin/store path
- validation is structural and contract-oriented; keep obstacle/platform
  contracts typed and deterministic

### Chunk Domain

- owner: `tools/editor/lib/src/chunks/**` and
  `tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart`
- plugin: `ChunkDomainPlugin`
- source-of-truth directory: `assets/authoring/level/chunks/*.json`
- keep one-chunk-per-file semantics, stable `chunkKey`, deterministic save-plan
  output, source-drift checks, and case-insensitive path-collision protection

### Parallax Domain

- owner: `tools/editor/lib/src/parallax/**` and
  `tools/editor/lib/src/app/pages/parallaxEditor/**`
- plugin: `ParallaxDomainPlugin`
- source-of-truth file: `assets/authoring/level/parallax_defs.json`
- parallax themes are visual-only render data keyed by stable `parallaxThemeId`
- active level selection resolves the current `parallaxThemeId` via
  `packages/runner_core/lib/levels/level_registry.dart`; multiple levels may
  reuse the same authored theme
- `groundMaterialAssetPath` belongs to render/theme selection only; gameplay
  ground geometry, collision, traversal, spawn, and streaming authority remain
  in chunk/core systems
- keep deterministic theme/layer ordering, canonical numeric formatting, and
  validation/export gating in the plugin/store path instead of page-local logic

### Level Domain

- owner: `tools/editor/lib/src/levels/**` and
  `tools/editor/lib/src/app/pages/levelCreator/**`
- plugin: `LevelDomainPlugin`
- source-of-truth file: `assets/authoring/level/level_defs.json`
- current scope includes the Level Creator route, list/inspector UI, store,
  validation, plugin, pending diff, and safe write flow
- `levelId` remains stable identity, `visualThemeId` ownership belongs here, and
  gameplay authority stays in core/chunk systems
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
  - `tools/editor/test/widget_test.dart`
- prefab/module workflows:
  - `tools/editor/test/prefab_store_test.dart`
  - `tools/editor/test/prefab_validation_test.dart`
  - `tools/editor/test/prefab_creator_page_test.dart`
  - `tools/editor/test/prefab_overlay_interaction_test.dart`
  - `tools/editor/test/platform_module_scene_view_test.dart`
  - `tools/editor/test/workspace_scoped_size_cache_test.dart`
  - `tools/editor/test/scene_control_parity_test.dart`
- chunk workflows:
  - `tools/editor/test/chunk_store_test.dart`
  - `tools/editor/test/chunk_validation_test.dart`
  - `tools/editor/test/chunk_domain_plugin_test.dart`
  - `tools/editor/test/chunk_domain_plugin_integration_test.dart`
  - `tools/editor/test/chunk_creator_page_test.dart`
- runtime authoring adapters when touched:
  - `tools/editor/test/prefab_runtime_adapter_test.dart`
- parallax workflows:
  - `tools/editor/test/parallax_store_test.dart`
  - `tools/editor/test/parallax_domain_plugin_test.dart`
  - `tools/editor/test/parallax_editor_page_test.dart`

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

- update this file if boundaries/rules drift
- update `tools/editor/README.md` for user-visible capability changes
- update `docs/building/editor/chunkCreator/plan.md` and relevant phase
  checklist/closure docs for chunk/prefab milestone changes
- for newly added authoring domains, add focused documentation only for the
  implemented workflow; keep future ideas separate from current behavior
