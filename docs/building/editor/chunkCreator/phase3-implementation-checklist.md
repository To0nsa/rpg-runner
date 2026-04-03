# Chunk Creator Phase 3 - Platform Module Creator + Scene Composition Implementation Checklist

Date: April 1, 2026  
Status: Completed (April 3, 2026)  
Source plan: [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md)
Phase 2 closure input:
[docs/building/editor/chunkCreator/phase2-closure-summary.md](docs/building/editor/chunkCreator/phase2-closure-summary.md)

This checklist turns Phase 3 of the chunk creator plan into an execution
sequence with concrete file targets, contract decisions, scene-view interaction
requirements, and test gates.

## Goal

Ship Phase 3 end-to-end:

- non-dev user can create and edit platform modules entirely in-editor
- platform modules are authored in a scene view (not grid-coordinate text entry only)
- scene-view control meaning is consistent across editor views (`Ctrl+drag` pan,
  wheel/pinch zoom, tool-driven primary drag behavior)
- module composition is grid-authoritative, deterministic, and validated
- module lifecycle operations are safe for prefab references
- module data in `tile_defs.json` round-trips without semantic drift
- module authoring output is directly consumable by platform-prefab flow
  (`visualSource.type = platform_module`)

## Phase 3 Gate (must pass)

- non-dev user can create/edit platform modules entirely in-editor via scene
  view, without JSON edits
- phase-touched scene views share the same control semantics via reusable
  modularized control code
- authored modules round-trip load/save deterministically
- module validation blocks invalid composition states before save/export
- platform prefab flow can reference newly authored modules in the same session

## Scope Boundaries for Phase 3

In scope:

- platform module contract hardening (module lifecycle + deterministic rules)
- platform module scene view and interaction tools
- shared scene-control abstraction reuse/simplification across scene views
- platform module lifecycle operations (create/edit/duplicate/rename/deprecate)
- deterministic module persistence + validation gating
- prefab reference-safety behaviors for module rename/deprecate/delete
- regression coverage for module persistence, validation, and scene interactions

Out of scope in this phase:

- runtime obstacle/platform cutover in `runner_core` (Phase 4)
- chunk floor/gap tool mode (Phase 5)
- marker/sockets/simulation/parallax phases
- gameplay balancing rules beyond structural validity of module composition

## Current Gaps to Close

Current baseline gaps that Phase 3 must close:

- platform module editing is form/list driven; no dedicated scene-composition UX
- tile placement requires manual grid X/Y input instead of paint-style authoring
- no module-focused viewport tools for pan/zoom/paint/erase with tile previews
- scene-view control mappings are not yet enforced through one shared control
  profile across views
- lifecycle safety is incomplete for rename/deprecate flows and prefab references
- validation/persistence rules exist, but are not aligned to scene-authoring
  expectations (normalization, interaction-safe feedback, operation gating)

## Locked Invariants

- Source-of-truth file for modules remains:
  - `assets/authoring/level/tile_defs.json`
- Schema output remains deterministic and canonical on save.
- Module reference policy for this phase is explicit:
  - prefab platform source continues using `visualSource.moduleId`
  - module rename must cascade prefab `moduleId` references atomically
  - no silent reference breakage is allowed
- Module lifecycle semantics are explicit and deterministic:
  - create and duplicate start at `revision = 1`
  - edit/rename/deprecate bump revision by `+1`
  - deprecate is idempotent
- Module geometry is grid-authoritative:
  - cell coordinates are integer grid coordinates
  - tileSize is a positive integer
  - duplicate cell positions are invalid
- Scene-view control contract is explicit and shared:
  - `Ctrl+drag` always means pan
  - wheel/pinch always means zoom
  - primary drag action is tool-driven and deterministic
  - control mapping lives in shared reusable code, not duplicated per view
- Validation errors are blocking for save/export in module workflows.
- No destructive operation silently removes dependent prefabs.

## Pre-flight

- [x] Re-read Phase 3 scope and gate in
      [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md).
- [x] Confirm current module baseline in:
  - [tools/editor/lib/src/prefabs/prefab_models.dart](tools/editor/lib/src/prefabs/prefab_models.dart)
  - [tools/editor/lib/src/prefabs/prefab_store.dart](tools/editor/lib/src/prefabs/prefab_store.dart)
  - [tools/editor/lib/src/prefabs/prefab_validation.dart](tools/editor/lib/src/prefabs/prefab_validation.dart)
  - [tools/editor/lib/src/app/pages/prefabCreator/tabs/platform_modules_tab.dart](tools/editor/lib/src/app/pages/prefabCreator/tabs/platform_modules_tab.dart)
  - [tools/editor/lib/src/app/pages/prefabCreator/state/module_logic.dart](tools/editor/lib/src/app/pages/prefabCreator/state/module_logic.dart)
- [x] Confirm reusable scene tooling baseline:
  - [tools/editor/lib/src/app/pages/prefabCreator/widgets/prefab_scene_view.dart](tools/editor/lib/src/app/pages/prefabCreator/widgets/prefab_scene_view.dart)
  - [tools/editor/lib/src/app/pages/shared/scene_input_utils.dart](tools/editor/lib/src/app/pages/shared/scene_input_utils.dart)
  - [tools/editor/lib/src/app/pages/shared/editor_scene_viewport_frame.dart](tools/editor/lib/src/app/pages/shared/editor_scene_viewport_frame.dart)
  - [tools/editor/lib/src/app/pages/shared/editor_viewport_grid_painter.dart](tools/editor/lib/src/app/pages/shared/editor_viewport_grid_painter.dart)
- [x] Record baseline green:
  - [x] `cd tools/editor && dart analyze`
  - [x] `cd tools/editor && flutter test`

Done when:

- [x] assumptions are validated
- [x] baseline is green before Phase 3 changes

## Step 0 - Contract Freeze for Module Lifecycle + Shared Controls + Reference Safety

Objective:

- lock module lifecycle, shared scene-control semantics, and reference behavior
  before UI rewrites

Tasks:

- [x] Freeze module contract additions in `TileModuleDef` for this phase:
  - [x] `revision` (int)
  - [x] `status` (`active | deprecated`)
- [x] Keep module reference model explicit for this phase:
  - [x] `moduleId` remains canonical reference in prefab visual source
  - [x] rename flow must rewrite all matching prefab `moduleId` references
- [x] Freeze shared scene-control profile for phase-touched editor scene views:
  - [x] `Ctrl+drag` pan semantics
  - [x] wheel/pinch zoom semantics
  - [x] primary drag semantics by tool mode (paint/erase/select)
- [x] Define shared control-code ownership in
      `tools/editor/lib/src/app/pages/shared/**` and disallow per-view mapping
      drift without explicit rationale
- [x] Define deterministic migration for existing module records missing
      lifecycle fields.
- [x] Define deprecate semantics:
  - [x] deprecated modules remain readable and referenceable by existing prefabs
  - [x] new module picks in UI default to active modules only
- [x] Document failure policy for destructive actions with dependencies:
  - [x] block delete by default when prefabs still reference the module
  - [x] force-remove flow is intentionally deferred in Phase 3; no implicit or
        silent destructive path exists in editor UI.

Done when:

- [x] lifecycle + shared-controls + reference contract is unambiguous
- [x] migration and operation behavior are documented and testable
- [x] no unresolved rename/deprecate/delete behavior remains

## Step 1 - Models + Store Migration Wiring

Objective:

- implement module contract updates in models/store with deterministic migration

Tasks:

- [x] Update
      [tools/editor/lib/src/prefabs/prefab_models.dart](tools/editor/lib/src/prefabs/prefab_models.dart):
  - [x] add module status enum parsing/serialization
  - [x] add `revision` and `status` fields to `TileModuleDef`
  - [x] keep `fromJson` tolerant for legacy records
  - [x] keep `toJson` strict and canonical for current schema
- [x] Update
      [tools/editor/lib/src/prefabs/prefab_store.dart](tools/editor/lib/src/prefabs/prefab_store.dart):
  - [x] migrate legacy module records in memory with deterministic defaults
  - [x] sort modules deterministically (status, id)
  - [x] sort module cells deterministically (gridY, gridX, sliceId)
  - [x] preserve atomic write semantics for `tile_defs.json`
- [x] Ensure schema-version behavior is explicit and deterministic when module
      fields are introduced.

Done when:

- [x] legacy module data loads without manual edits
- [x] save emits canonical module lifecycle fields
- [x] repeated load->save->load has no semantic drift

## Step 2 - Validation Expansion for Module Authoring

Objective:

- enforce blocking rules that match scene-authoring expectations

Tasks:

- [x] Expand
      [tools/editor/lib/src/prefabs/prefab_validation.dart](tools/editor/lib/src/prefabs/prefab_validation.dart):
  - [x] missing/duplicate module id
  - [x] invalid/missing module lifecycle fields (`revision`, `status`)
  - [x] non-positive module tileSize
  - [x] empty cell list for active modules
  - [x] missing tile-slice references in module cells
  - [x] duplicate cell coordinates in a module
  - [x] invalid grid-coordinate values (non-int should not survive parse)
- [x] Add reference-safety validation:
  - [x] prefab cannot reference missing module
  - [x] UI save/delete operations blocked when dependency rules fail
- [x] Add stable issue codes/messages for all module-specific failures.

Done when:

- [x] invalid module composition is blocked before save/export
- [x] validator output is deterministic and action-oriented
- [x] lifecycle/reference failures are consistently surfaced

## Step 3 - Scene View Foundation for Module Composition

Objective:

- build a reusable platform-module scene viewport for paint-style authoring
  using shared scene-control semantics

Tasks:

- [x] Add module scene widget file (new):
      `tools/editor/lib/src/app/pages/prefabCreator/widgets/platform_module_scene_view.dart`.
- [x] Extract/extend shared scene-control adapter in
      `tools/editor/lib/src/app/pages/shared/**` (around
      `scene_input_utils.dart`) so pointer/keyboard mapping is centralized.
- [x] Reuse shared viewport primitives for consistency:
  - [x] zoom controls
  - [x] scrollable scene frame
  - [x] grid painter and input helpers
- [x] Render module cells using selected tile slices from atlas sources.
- [x] Implement deterministic interaction model:
  - [x] paint cell at pointer grid coordinate
  - [x] erase cell at pointer grid coordinate
  - [x] replace cell slice on occupied coordinate when paint tool is active
  - [x] `Ctrl+drag` pan + wheel/pinch zoom parity with all phase-touched scene
        widgets
- [x] Migrate phase-touched scene views to shared control profile:
  - [x] platform module scene view
  - [x] prefab scene view
  - [x] atlas slicer scene
- [x] Keep per-view input code limited to tool-specific action callbacks.
- [x] Keep view state isolated from persisted model until explicit state update.

Done when:

- [x] scene view supports full module composition without manual grid text entry
- [x] viewport interactions are stable on desktop and mobile
- [x] control mappings are shared and consistent across phase-touched views
- [x] rendered module layout matches persisted cell geometry

## Step 4 - Platform Modules Tab Rewrite Around Scene Workflow

Objective:

- transition from form-list workflow to module-authoring workflow

Tasks:

- [x] Update
      [tools/editor/lib/src/app/pages/prefabCreator/tabs/platform_modules_tab.dart](tools/editor/lib/src/app/pages/prefabCreator/tabs/platform_modules_tab.dart):
  - [x] add module selector + lifecycle actions panel
  - [x] add tile-slice palette with current selection state
  - [x] embed module scene view as primary editing surface
  - [x] keep module metadata inspector (id, tileSize, status, revision)
- [x] Update module interaction state in:
  - [x] [tools/editor/lib/src/app/pages/prefabCreator/state/module_logic.dart](tools/editor/lib/src/app/pages/prefabCreator/state/module_logic.dart)
  - [x] [tools/editor/lib/src/app/pages/prefabCreator/state/selection_logic.dart](tools/editor/lib/src/app/pages/prefabCreator/state/selection_logic.dart)
- [x] Ensure tab-level interactions do not introduce custom control mappings
      that diverge from shared scene-control profile.
- [x] Retain deterministic ordering and clear status/error messaging.

Done when:

- [x] module authoring is primarily scene-driven
- [x] module metadata and scene edits stay in sync
- [x] user feedback for invalid operations is immediate and clear

## Step 5 - Lifecycle Operations + Prefab Reference Safety

Objective:

- make create/edit/duplicate/rename/deprecate/remove operations safe by default

Tasks:

- [x] Implement module lifecycle operations in module logic:
  - [x] create
  - [x] duplicate (new id, `revision = 1`)
  - [x] rename (cascade update matching prefab `moduleId` refs)
  - [x] deprecate/reactivate
  - [x] delete with dependency policy
- [x] Prevent silent destructive behavior:
  - [x] remove implicit cascade-delete of prefabs on module delete
  - [x] force delete remains unavailable in Phase 3 by policy (blocked delete
        only), with deferred explicit-confirmation flow documented for a later
        phase.
- [x] Ensure revision policy is deterministic across all operations.
- [x] Ensure selected prefab module source updates coherently after rename/deprecate/delete.

Done when:

- [x] lifecycle operations are deterministic and reference-safe
- [x] no silent prefab removal occurs
- [x] rename/deprecate flows preserve user intent and data integrity

## Step 6 - Prefab Flow Integration and UX Guardrails

Objective:

- ensure module authoring and platform-prefab authoring work as one workflow

Tasks:

- [x] Keep Prefab tab source picker synchronized with module lifecycle state:
  - [x] active modules are selectable by default
  - [x] deprecated modules are visually flagged
- [x] Ensure newly created modules are available for platform prefab source
      selection in the same editor session.
- [x] Ensure module rename reflects immediately in prefab source pickers and
      editing state.
- [x] Keep save behavior validation-gated across prefabs + modules as one unit.

Done when:

- [x] user can create module then create/edit platform prefab without reload
- [x] module lifecycle changes stay consistent with prefab source references
- [x] save path remains deterministic and safe

## Step 7 - Tests

Objective:

- lock Phase 3 behavior before Phase 4 runtime cutover begins

Tasks:

- [x] Expand model/store tests:
  - [x] module lifecycle migration defaults (`revision`, `status`)
  - [x] deterministic module + cell ordering
  - [x] lifecycle field round-trip stability
- [x] Expand validation tests:
  - [x] invalid module lifecycle fields
  - [x] empty active module cells
  - [x] missing slice refs / duplicate cells
  - [x] rename/delete dependency safety failures
- [x] Add widget tests for platform module authoring UX:
  - [x] scene paint flow
  - [x] scene erase flow
  - [x] module lifecycle actions (duplicate/rename/deprecate/delete)
  - [x] prefab reference safety prompts/errors
- [x] Add control-parity tests across phase-touched scene views:
  - [x] `Ctrl+drag` pans in each scene
  - [x] wheel or pinch zoom updates zoom consistently
  - [x] primary drag behavior follows selected tool mode consistently
- [x] Update integration tests that assert prefab source coherence after module
      lifecycle changes.

Recommended file targets:

- [tools/editor/test/prefab_store_test.dart](tools/editor/test/prefab_store_test.dart)
- [tools/editor/test/prefab_validation_test.dart](tools/editor/test/prefab_validation_test.dart)
- [tools/editor/test/prefab_creator_page_test.dart](tools/editor/test/prefab_creator_page_test.dart)
- `tools/editor/test/platform_module_scene_view_test.dart` (new)
- `tools/editor/test/scene_control_parity_test.dart` (new)

Done when:

- [x] Phase 3 gate behaviors are test-covered
- [x] scene interaction + lifecycle critical paths are stable in tests
- [x] module-prefab integration has regression coverage

## Step 8 - Validation Commands

- [x] `cd tools/editor && dart analyze`
- [x] `cd tools/editor && flutter test`
- [x] `cd tools/editor && flutter test test/prefab_store_test.dart`
- [x] `cd tools/editor && flutter test test/prefab_validation_test.dart`
- [x] `cd tools/editor && flutter test test/prefab_creator_page_test.dart`
- [x] `cd tools/editor && flutter test test/platform_module_scene_view_test.dart`
- [x] `cd tools/editor && flutter test test/scene_control_parity_test.dart`
- [x] `dart run tool/generate_chunk_runtime_data.dart --dry-run`

Done when:

- [x] analyzer is clean for touched scope
- [x] relevant tests pass locally

## Step 9 - Docs and Handoff

- [x] Update Phase 3 status in
      [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md)
      when complete.
- [x] Add Phase 3 closure summary doc:
      `docs/building/editor/chunkCreator/phase3-closure-summary.md`.
- [x] Document finalized module lifecycle contract and migration rules.
- [x] Document module rename/delete dependency policy for prefab references.
- [x] Document finalized shared scene-control profile and extension rules for
      future scene views.
- [x] Include explicit list of changed files and tests in PR summary.
- [x] Note deferred work explicitly (no hidden TODO behavior).

## Final Acceptance Checklist

- [x] Platform module authoring is scene-driven and non-dev usable.
- [x] Module lifecycle operations are deterministic and reference-safe.
- [x] Module validation blocks invalid composition before save/export.
- [x] Module data round-trips deterministically in `tile_defs.json`.
- [x] Platform prefab flow can consume newly authored modules immediately.
- [x] Phase-touched scene views share one control profile through reusable code.
- [x] Analyzer and relevant tests pass.
- [x] No unresolved blockers remain for Phase 4 runtime prefab cutover.
