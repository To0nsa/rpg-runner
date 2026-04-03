# AGENTS.md - Editor Tool

Instructions for AI coding agents working in `tools/editor/`.

## Editor Responsibility

`tools/editor` is a standalone Flutter authoring app for `rpg_runner` content
workflows. It owns editor UX, validation, and deterministic persistence for:

- entity collider/source-bound edits
- prefab + tile/module authoring data
- chunk authoring data

Gameplay authority remains in `packages/runner_core/lib/**`. Do not move runtime
rules into the editor.

## Read First

- repo root: `AGENTS.md`
- docs policy: `docs/rules/documentation_and_commenting_guide.md`
- chunk roadmap/checklists: `docs/building/editor/chunkCreator/**` when changing
  prefab/chunk contracts or milestone status

## Current Architecture

- app entry: `tools/editor/lib/main.dart`
- app bootstrap: `tools/editor/lib/src/app/runner_editor_app.dart`
- session orchestration: `tools/editor/lib/src/session/editor_session_controller.dart`
- plugin contract + registry:
  - `tools/editor/lib/src/domain/authoring_types.dart`
  - `tools/editor/lib/src/domain/authoring_plugin_registry.dart`
- routes:
  - `Entities` route (plugin-backed)
  - `Chunk Creator` route (plugin-backed)
  - `Prefab Creator` route (page/state/store workflow; currently not a domain
    plugin)
- shared scene/view primitives:
  - `tools/editor/lib/src/app/pages/shared/**`

## Modularization, Reuse, And Redundancy Bar

Treat editor changes as maintainability work, not just feature delivery.

- reuse-first: before adding new helpers/widgets/state flows, search existing
  code (`rg`) for equivalent behavior and extend what already exists when
  possible.
- no copy/paste feature logic across routes: if the same behavior appears in
  two places, consolidate into shared code in the same change unless there is a
  clear blocker.
- shared scene behavior belongs in `tools/editor/lib/src/app/pages/shared/**`;
  avoid per-page forks for pan/zoom/grid/input semantics.
- domain logic belongs in domain/state/store files, not in widget trees:
  - parsing/migration/serialization in `src/*/store.dart` or parser files
  - validation rules in `src/*/validation.dart`
  - command/state transitions in plugin or page-state logic files
- keep deterministic rules single-sourced (sorting, slug allocation, identity
  normalization, revision bump policy). Do not duplicate these rules in both UI
  and store layers.
- remove dead or shadowed code paths as part of the change; do not leave
  parallel legacy paths without explicit removal criteria.
- if temporary duplication is unavoidable, annotate with a tracked TODO and a
  clear removal trigger, then close it quickly.

Before finalizing non-trivial edits, do a redundancy pass:

1. check for duplicate helpers/constants introduced in the touched scope
2. check for repeated branching/validation logic that can be extracted
3. check for similar widget sections that should be parameterized/composed
4. verify refactor did not weaken determinism or export/write safety

## Domain Ownership And Write Targets

### Entities Domain

- Owner: `tools/editor/lib/src/entities/**`
- Plugin: `EntityDomainPlugin`
- Source parser: `entity_source_parser.dart`
- Writes are direct source edits against authoritative Dart files using source
  bindings/range replacement guards.
- Keep drift safety and backup behavior intact; do not bypass plugin/export
  guardrails with ad-hoc file writes.

### Prefab + Tile/Module Domain

- Owner: `tools/editor/lib/src/prefabs/**` and
  `tools/editor/lib/src/app/pages/prefabCreator/**`
- Source-of-truth files:
  - `assets/authoring/level/prefab_defs.json`
  - `assets/authoring/level/tile_defs.json`
- Persist through `PrefabStore` so canonical ordering, migration defaults, and
  atomic paired writes stay consistent.
- Validation is structural and contract-oriented; keep obstacle/platform
  contracts typed and deterministic.

### Chunk Domain

- Owner: `tools/editor/lib/src/chunks/**` and
  `tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart`
- Plugin: `ChunkDomainPlugin`
- Source-of-truth directory: `assets/authoring/level/chunks/*.json`
- Keep one-chunk-per-file semantics, stable `chunkKey`, deterministic save-plan
  output, source-drift checks, and case-insensitive path-collision protection.

## Determinism And Validation Rules

- Preserve canonical ordering and serialization in stores/models.
- Keep validation/export gating strict: blocking errors must prevent writes.
- Keep migration behavior explicit, deterministic, and test-backed.
- Do not silently coerce identity fields (`chunkKey`, `prefabKey`, module IDs)
  in a way that breaks existing references.

## Scene/Input Control Rules

Scene interaction behavior for phase-touched views must stay consistent through
shared code under `tools/editor/lib/src/app/pages/shared/scene_input_utils.dart`.

- `Ctrl+drag`: pan
- `Ctrl+scroll`: zoom stepping
- primary drag: tool-driven behavior (selection/paint/erase/move depending on
  active tool)

Do not introduce per-view control drift without explicit rationale and tests.

## Adding Or Changing Routes/Plugins

When adding a new plugin-backed authoring domain:

1. Implement `AuthoringDomainPlugin` end to end (`load`, `validate`,
   `buildEditableScene`, `applyEdit`, `describePendingChanges`, `exportToRepo`).
2. Register the plugin in `runner_editor_app.dart`.
3. Wire route/plugin mapping in `home_routes.dart`.
4. Ensure route switching remains session-coherent in `editor_home_page.dart`.
5. Add/adjust focused tests for load/edit/export and route-switch behavior.

For page-managed workflows (like current `Prefab Creator`), keep state/I/O
logic scoped to that page and use shared scene utilities instead of duplicating
viewport/input infrastructure.

## Validation Expectations

Minimum checks for editor changes:

- `cd tools/editor && dart analyze`
- `cd tools/editor && flutter test`

Run focused tests for touched slices, for example:

- entities/source editing: `tools/editor/test/widget_test.dart`
- prefab/module workflows:
  - `tools/editor/test/prefab_store_test.dart`
  - `tools/editor/test/prefab_validation_test.dart`
  - `tools/editor/test/prefab_creator_page_test.dart`
  - `tools/editor/test/platform_module_scene_view_test.dart`
  - `tools/editor/test/scene_control_parity_test.dart`
- chunk workflows:
  - `tools/editor/test/chunk_store_test.dart`
  - `tools/editor/test/chunk_validation_test.dart`
  - `tools/editor/test/chunk_domain_plugin_test.dart`
  - `tools/editor/test/chunk_domain_plugin_integration_test.dart`
  - `tools/editor/test/chunk_creator_page_test.dart`

When authoring-runtime contract seams are touched, also run repo-level generator
validation (`dart run tool/generate_chunk_runtime_data.dart --dry-run`).

## Common Failure Modes To Avoid

- bypassing stores/plugins with one-off file writes
- introducing non-deterministic ordering in save output
- weakening source-drift checks to force writes through
- leaking runtime gameplay rules into editor/UI layers
- adding custom scene-input behavior in one view instead of reusing shared
  scene-control utilities

## Documentation Upkeep

When editor contracts or workflows change:

- update this file if boundaries/rules drift
- update `tools/editor/README.md` for user-visible capability changes
- update `docs/building/editor/chunkCreator/plan.md` and relevant phase
  checklist/closure docs for chunk/prefab milestone changes
