# Chunk Creator Phase 1 - Implementation Checklist

Date: April 1, 2026  
Status: Phase 1 completed  
Source plan: [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md)

This checklist turns Phase 1 of the chunk creator plan into an execution
sequence with concrete file targets, behavior constraints, and test gates.

## Goal

Ship Phase 1 end-to-end:

- chunk domain plugin scaffolding is present and wired
- `Chunk Creator` route is a real composition workspace skeleton (not placeholder)
- typed chunk JSON schema is implemented with validation
- immutable chunk identity (`chunkKey`) and rename-safe editable identity (`id`)
  are both implemented
- active level-context authority is integrated into chunk workflow
- deterministic filename/rename policy is implemented with collision safety
- floor/gap contract ownership is implemented in schema/store/validation
  (contract-only in Phase 1)
- floor/gap contract shape is extensible without schema rewrites in Phase 5+
- grid snap + chunk-width structural checks are enforced at validation time
- Core chunk geometry validation no longer depends on debug-only `assert`s
- `TrackStreamer` is decoupled from hardcoded pattern pool via chunk-source seam
- runtime metadata includes stable identity passthrough (`chunkKey`/`gapId`)
- generator seam is bootstrapped to validate chunk contracts before runtime use
- create/duplicate/rename/deprecate operations exist and are safe
- ID/revision safeguards prevent unsafe mutations and drift
- export is drift-safe and atomic
- load/save/validate/export loop works with deterministic output

## Phase 1 Gate (must pass)

- chunk files load/save/validate in editor
- chunk create/duplicate/rename/deprecate operations are deterministic and
  reference-safe
- immutable identity vs renameable ID semantics are enforced and test-covered
- active level context is enforced in validation and export
- deterministic filename policy is collision-safe across OS filesystems
- grid/chunk-width constraints block invalid geometry-affecting data
- Core chunk geometry validation is enforced in all build modes (not assert-only)
- chunk-source abstraction seam is in place for streaming input
- runtime metadata identity passthrough exists for chunk/gap (`chunkKey`/`gapId`)
- generator seam validates schema/contracts before runtime consumption
- no unresolved schema-versioning or chunk identity gaps

## Scope Boundaries for Phase 1

In scope:

- chunk schema + persistence + validation + lifecycle operations
- immutable `chunkKey` + renameable `id` policy and storage
- active level-context selection + validation plumbing
- deterministic chunk filename and rename/write policy
- explicit floor/gap contract fields in chunk model/store/validator
- extensible floor/gap contract shape (typed `kind`/`type`, stable item IDs)
- grid/chunk-width authority checks tied to runtime tuning contracts
- Core runtime validation path for chunk geometry in all build modes
- chunk-source abstraction seam in Core streaming pipeline
- runtime identity passthrough fields for chunk/gap metadata
- generator seam bootstrap for contract validation
- editor page skeleton for chunk metadata and operations
- plugin integration with existing editor session flow

Out of scope in this phase:

- terrain paint tools
- prefab placement tools
- marker placement tools
- dedicated floor paint/brush UX and jumpability/fairness overlays (Phase 5)
- simulation overlays
- level assembly authoring UI
- full runtime replacement of existing hardcoded chunk libraries (Phase 3)

## Locked Invariants

- Source-of-truth files are under `assets/authoring/level/chunks/*.json`.
- Every chunk file is schema-versioned and deterministic on save.
- Chunk identity is explicit and stable:
  - `chunkKey` is immutable and never changes after create/duplicate.
  - `id` is user-facing and may change only via explicit rename operation.
  - `revision` is integer and mutation-safe.
- Filename policy is deterministic and stable:
  - filename derivation is explicit and deterministic.
  - rename operation does not create ambiguous file identity or OS-dependent
    collisions.
- Floor and gaps are explicit authored contract fields:
  - `groundProfile` and `groundGaps` exist in chunk documents.
  - `groundProfile` and `groundGaps` use explicit typed fields (`kind`/`type`),
    not opaque dynamic payload maps.
  - gap data is not inferred from implicit paint holes.
- Level context is explicit:
  - chunk validation/export runs against a selected active level context.
  - level option sources use deterministic precedence:
    1. `assets/authoring/level/level_defs.json` (if valid)
    2. `packages/runner_core/lib/levels/level_id.dart` enum values
    3. discovered chunk-file `levelId` values (sorted)
  - active level selection is deterministic:
    1. keep current selection if still valid
    2. otherwise choose lexicographically first option
    3. if no options exist, block export with explicit validation issue
- Geometry-affecting values are snapped to runtime-authoritative grid spacing.
- No operation silently mutates referenced IDs without explicit update logic.
- Validation errors are blocking for save/export actions in chunk workflows.

## Pre-flight

- [x] Re-read Phase 1 in
      [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md).
- [x] Confirm historical baseline route state before implementation
      (placeholder at phase start) in
      [tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart](tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart).
- [x] Confirm editor plugin baseline via:
  - [tools/editor/lib/src/domain/authoring_types.dart](tools/editor/lib/src/domain/authoring_types.dart)
  - [tools/editor/lib/src/session/editor_session_controller.dart](tools/editor/lib/src/session/editor_session_controller.dart)
  - [tools/editor/lib/src/entities/entity_domain_plugin.dart](tools/editor/lib/src/entities/entity_domain_plugin.dart)
- [x] Confirm runtime authority inputs:
  - [packages/runner_core/lib/tuning/track_tuning.dart](packages/runner_core/lib/tuning/track_tuning.dart)
  - [packages/runner_core/lib/levels/level_id.dart](packages/runner_core/lib/levels/level_id.dart)
- [x] Record baseline green:
  - [x] `cd tools/editor && dart analyze`
  - [x] `cd tools/editor && flutter test`

Done when:

- [x] assumptions are validated
- [x] baseline is green before any Phase 1 code changes

## Step 0 - Core Runtime Alignment Seams (No Behavior Drift)

Objective:

- align current Core runtime seams with authored chunk cutover so Phase 3 does
  not require double refactors

Tasks:

- [x] Replace assert-only geometry checks with runtime-safe validation in Core:
  - [x] update
        [packages/runner_core/lib/track/chunk_builder.dart](packages/runner_core/lib/track/chunk_builder.dart)
        to enforce bounds/snap/overlap checks in all build modes.
  - [x] ensure `TrackStreamer` failure behavior is deterministic when invalid
        chunk data is encountered.
- [x] Introduce chunk-source abstraction in Core:
  - [x] define chunk source interface/adapter layer (for example
        `ChunkPatternSource`) near
        `packages/runner_core/lib/track/**`.
  - [x] update
        [packages/runner_core/lib/track/track_streamer.dart](packages/runner_core/lib/track/track_streamer.dart)
        to consume abstraction instead of direct pool coupling.
  - [x] keep existing `ChunkPatternPool` behavior via adapter so no gameplay
        regression is introduced in this step.
- [x] Add runtime identity passthrough:
  - [x] propagate stable chunk identity (`chunkKey`, optional while migrating)
        through streamed chunk metadata where feasible.
  - [x] propagate stable gap identity (`gapId`, optional while migrating) through
        gap metadata where feasible.
  - [x] maintain compatibility for existing hardcoded patterns that do not yet
        provide authored IDs.
- [x] Bootstrap generator seam:
  - [x] add initial
        `tool/generate_chunk_runtime_data.dart`
        with `--dry-run` contract validation mode.
  - [x] ensure deterministic diagnostics/output for same inputs.

Done when:

- [x] existing deterministic runtime tests stay green (no behavior drift)
- [x] Core runtime has seam points required for authored-chunk cutover
- [x] `tool/generate_chunk_runtime_data.dart` exists and is invokable
- [x] generator dry-run command is usable in local/CI validation flows

## Step 1 - Chunk Contracts and Schema Types

Objective:

- define typed chunk authoring model with explicit schema and required fields,
  including floor/gap contract ownership

Tasks:

- [x] Add chunk models file:
      `tools/editor/lib/src/chunks/chunk_domain_models.dart`.
- [x] Define typed structures for Phase 1 minimum:
  - [x] `ChunkDocument` (editor document-level wrapper)
  - [x] `LevelChunkDef` (chunk contract)
  - [x] immutable identity value object (`chunkKey`)
  - [x] `GroundProfileDef` (chunk floor profile contract)
  - [x] `GroundGapDef` (explicit gap contract)
  - [x] `GroundGapType` enum-like value object (extensible type contract)
  - [x] typed enum/value objects where needed (`difficulty`, socket IDs, status)
- [x] Include required fields from plan:
  - [x] `chunkKey`
  - [x] `id`
  - [x] `revision`
  - [x] `schemaVersion`
  - [x] `levelId`
  - [x] `tileSize`
  - [x] `width`
  - [x] `height`
  - [x] `entrySocket`
  - [x] `exitSocket`
  - [x] `difficulty`
  - [x] `tags`
  - [x] `tileLayers`
  - [x] `prefabs`
  - [x] `markers`
  - [x] `groundProfile`
  - [x] `groundGaps`
- [x] Define Phase 1 floor/gap minimum schema shape explicitly:
  - [x] `groundProfile.kind` (for example `flat` in Phase 1 baseline)
  - [x] `groundProfile.topY` (baseline floor height contract)
  - [x] `groundGaps[].gapId` (stable per-gap identity)
  - [x] `groundGaps[].type` (for future semantics; baseline `pit`)
  - [x] `groundGaps[].x` and `groundGaps[].width`
- [x] Add typed `toJson`/`fromJson` with tolerant parse and strict normalized
      output.
- [x] Add deterministic sort/normalization helpers:
  - [x] stable list ordering for tags and nested arrays
  - [x] stable ordering for chunks in memory by (`levelId`, `id`)
  - [x] stable ordering for `groundGaps` (for example by x then width)
  - [x] canonical key order in serialized JSON output

Done when:

- [x] chunk contract compiles and round-trips JSON without semantic drift
- [x] all required fields are explicit in code
- [x] `chunkKey` remains stable across non-identity edits and rename operations
- [x] floor/gap contract fields are explicit and round-trip deterministically

## Step 2 - Chunk Store (Load/Save)

Objective:

- provide deterministic file-backed persistence for `chunks/*.json`

Tasks:

- [x] Add chunk store file:
      `tools/editor/lib/src/chunks/chunk_store.dart`.
- [x] Implement load behavior:
  - [x] discover files in `assets/authoring/level/chunks/`
  - [x] parse each file to typed chunk objects
  - [x] surface parse issues with path context
  - [x] apply deterministic in-memory ordering by (`levelId`, `id`, `chunkKey`)
  - [x] compute baseline fingerprint/hash per loaded file for drift detection
- [x] Implement save behavior:
  - [x] one chunk per file
  - [x] deterministic filename strategy (explicit and documented)
  - [x] filename strategy is safe on case-insensitive filesystems
  - [x] rename behavior does not implicitly re-key file identity
  - [x] deterministic JSON pretty-printing
  - [x] newline and key-order consistency
- [x] Ensure missing directory bootstrap is safe (`createSync(recursive: true)`).
- [x] Add schemaVersion migration hook shape (even if no migrations yet).
- [x] Ensure floor/gap contract fields are persisted in canonical JSON shape.
- [x] Save path applies atomic write strategy (temp + replace) for chunk files.

Done when:

- [x] repeated load->save->load yields no semantic change
- [x] output ordering is deterministic across runs
- [x] file identity and content drift checks are available for export

## Step 3 - Validation Rules

Objective:

- block invalid chunk data before save/export

Tasks:

- [x] Add validator module:
      `tools/editor/lib/src/chunks/chunk_validation.dart`.
- [x] Implement blocking checks:
  - [x] duplicate or malformed `chunkKey`
  - [x] duplicate chunk `id`
  - [x] invalid/missing `schemaVersion`
  - [x] invalid/missing `levelId`
  - [x] unknown `levelId` for current level options source
  - [x] mismatch between chunk `levelId` and active level context
  - [x] non-positive `tileSize`, `width`, `height`
  - [x] non-snapped geometry-affecting values against grid snap authority
  - [x] chunk width not compatible with runtime chunk width contract
  - [x] missing required sockets (`entrySocket`, `exitSocket`)
  - [x] invalid `revision` (non-integer or <= 0)
  - [x] invalid/missing `groundProfile`
  - [x] invalid `groundProfile.kind` or missing baseline fields
  - [x] malformed `groundGaps` entries
  - [x] duplicate `groundGaps[].gapId`
  - [x] invalid `groundGaps[].type`
  - [x] gap width <= 0
  - [x] gap spans outside chunk width bounds
  - [x] overlapping gap spans (structural conflict)
  - [x] malformed tags/payload arrays
  - [x] any unknown/invalid enum-like fields
- [x] Implement lifecycle-operation checks:
  - [x] create fails on existing ID
  - [x] create/duplicate always emits new `chunkKey`
  - [x] duplicate fails on target ID collision
  - [x] rename fails on target ID collision
  - [x] rename cannot mutate `chunkKey`
  - [x] deprecate is idempotent and non-destructive
  - [x] rename/deprecate cannot produce filename collisions
- [x] Return `ValidationIssue` with stable `code` values and `sourcePath`.

Done when:

- [x] validator returns deterministic issue lists
- [x] invalid authoring state is blocked before write
- [x] structural floor/gap contract issues are blocked before write/export

## Step 4 - Chunk Domain Plugin Scaffolding

Objective:

- integrate chunk data with editor plugin architecture

Tasks:

- [x] Add plugin file:
      `tools/editor/lib/src/chunks/chunk_domain_plugin.dart`.
- [x] Implement `AuthoringDomainPlugin` methods:
  - [x] `loadFromRepo`
  - [x] `validate`
  - [x] `buildEditableScene`
  - [x] `applyEdit`
  - [x] `exportToRepo`
  - [x] `describePendingChanges`
- [x] Expose active level context state in chunk scene/plugin flow:
  - [x] current active level id
  - [x] available levels source uses fixed precedence from Locked Invariants
- [x] Add editable-scene model for chunk page:
      `tools/editor/lib/src/chunks/chunk_domain_scene.dart` (or equivalent).
- [x] Define command kinds for chunk operations:
  - [x] `set_active_level`
  - [x] `create_chunk`
  - [x] `duplicate_chunk`
  - [x] `rename_chunk`
  - [x] `deprecate_chunk`
  - [x] `update_chunk_metadata`
  - [x] `update_ground_profile`
  - [x] `add_ground_gap`
  - [x] `update_ground_gap`
  - [x] `remove_ground_gap`
- [x] Register plugin in
      [tools/editor/lib/src/app/runner_editor_app.dart](tools/editor/lib/src/app/runner_editor_app.dart)
      with a stable plugin ID (for example `chunks`).
- [x] Wire `Chunk Creator` route to plugin ID in
      [tools/editor/lib/src/app/pages/home/home_routes.dart](tools/editor/lib/src/app/pages/home/home_routes.dart)
      so session/plugin state is coherent when switching routes.

Done when:

- [x] chunk plugin can load and expose editable scene through session controller
- [x] route switching preserves expected plugin/session behavior
- [x] active level context switching is deterministic and does not corrupt chunk
      state

## Step 5 - Chunk Creator Workspace Skeleton

Objective:

- replace placeholder page with a minimal but production-structured chunk
  workspace

Tasks:

- [x] Replace placeholder UI in
      [tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart](tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart)
      with:
  - [x] level context selector (explicit active level)
  - [x] chunk list panel
  - [x] chunk inspector form panel (includes floor baseline + gap list fields)
  - [x] read-only identity section (`chunkKey`, source file path)
  - [x] operation toolbar (create/duplicate/rename/deprecate/save/reload)
  - [x] status/error banners
- [x] Keep controls deterministic and form-driven (no hidden side effects).
- [x] Ensure no writes occur from widget `build` methods.
- [x] Maintain parity with existing editor interaction patterns:
  - [x] explicit reload/save actions
  - [x] clear success/error messaging
  - [x] bounded form validation before command dispatch

Done when:

- [x] users can manage chunk identities and metadata without hand-editing JSON
- [x] page is no longer an intro-card placeholder
- [x] level context and immutable identity behavior are visible and understandable
      in UI

## Step 6 - Identity and Revision Safeguards

Objective:

- make lifecycle operations safe, deterministic, and reference-aware

Tasks:

- [x] Define revision policy and apply consistently:
  - [x] create sets initial revision
  - [x] duplicate sets initial revision for new identity (`id` + `chunkKey`)
  - [x] rename updates `id` only and preserves `chunkKey`
  - [x] rename preserves content and revision unless policy says otherwise
  - [x] metadata edits bump revision deterministically (if chosen policy)
- [x] Define deprecate representation (explicit field or canonical tag) and
      keep it stable.
- [x] deprecate policy is explicit in schema (avoid implicit semantics through
      free-form tag text only).
- [x] Ensure rename updates all internal references in same document model.
- [x] If external refs are present in Phase 1 scope, implement reference-safe
      updates or block rename with explicit validation error.
- [x] Ensure operations are idempotent where appropriate (especially deprecate).
- [x] Emit deterministic errors for unsafe transitions.

Done when:

- [x] no operation can create ambiguous identity state
- [x] revision behavior is predictable and test-covered
- [x] rename + duplicate + deprecate semantics preserve immutable identity
      invariants

## Step 7 - Pending Diff + Export Behavior

Objective:

- provide reliable pending-change visibility and direct-write export flow

Tasks:

- [x] Implement `describePendingChanges` for chunk plugin with per-file diffs.
- [x] Ensure unchanged documents produce empty pending changes.
- [x] Implement `exportToRepo` direct write semantics with source-drift guards
      consistent with existing plugin patterns.
- [x] Drift checks must use load-time baseline fingerprints/hashes per file.
- [x] Writes must be atomic at file level (temp + replace semantics).
- [x] Export must fail deterministically on case-insensitive filename collisions.
- [x] Ensure export respects validation gate (errors block writes).
- [x] Ensure post-export reload path keeps session state coherent.

Done when:

- [x] diff view is meaningful for chunk edits
- [x] export behavior is deterministic and safe
- [x] export cannot silently overwrite drifted source files

## Step 8 - Tests

Objective:

- lock behavior with targeted tests before Phase 2 starts

Tasks:

- [x] Add chunk model/store tests:
  - [x] parse tolerance + strict serialization
  - [x] deterministic ordering
  - [x] round-trip invariants
  - [x] immutable `chunkKey` behavior through rename/edit flows
  - [x] deterministic filename strategy and case-insensitive collision handling
  - [x] baseline fingerprint generation and drift detection behavior
- [x] Add chunk validation tests:
  - [x] required-field failures
  - [x] `chunkKey` failures
  - [x] level-context mismatch failures
  - [x] grid/chunk-width snapping failures
  - [x] floor/gap type-shape failures
  - [x] duplicate ID failures
  - [x] revision guard failures
  - [x] operation precondition failures
- [x] Add plugin tests:
  - [x] load/validate/build scene
  - [x] active level context switching behavior
  - [x] command application semantics
  - [x] pending changes generation
  - [x] export write behavior
  - [x] export drift-safe failure paths
- [x] Add Core runtime seam tests:
  - [x] runtime-safe chunk validation behavior in release-mode equivalent path
  - [x] chunk-source abstraction parity with existing pool behavior
  - [x] optional identity passthrough does not alter deterministic selection
        behavior
- [x] Add widget tests for `Chunk Creator` page skeleton:
  - [x] level switch flow
  - [x] create flow
  - [x] duplicate flow
  - [x] rename flow
  - [x] deprecate flow
  - [x] blocking validation surfacing
- [x] Add regression test for route/plugin switching correctness.
- [x] Add generator seam tests:
  - [x] chunk contract parse/validate smoke test through generator entrypoint
  - [x] deterministic output or deterministic error behavior for same inputs

Done when:

- [x] test suite captures all Phase 1 gate behaviors
- [x] no untested identity/revision-critical path remains
- [x] no untested Core seam-critical path remains

## Step 9 - Validation Commands

- [x] `cd tools/editor && dart analyze`
- [x] `cd tools/editor && flutter test`
- [x] `dart run tool/generate_chunk_runtime_data.dart --dry-run`
- [x] `flutter test test/core/track_streaming_test.dart`
- [x] `flutter test test/core/track_streamer_spawn_placement_test.dart`
- [x] `flutter test test/core/track_streamer_hashash_deferred_spawn_test.dart`
- [x] run any root-level tests touched by shared contracts (if applicable)

Done when:

- [x] analyzer clean
- [x] relevant tests pass locally

## Step 10 - Docs and Handoff

- [x] Update Phase 1 status in
      [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md)
      once complete.
- [x] Document finalized revision policy and deprecate representation in plan.
- [x] Document finalized identity policy (`chunkKey` vs `id`) in plan.
- [x] Document deterministic filename + rename policy in plan.
- [x] Document finalized level-context source precedence policy in plan.
- [x] Include explicit list of added chunk files/contracts in PR summary.
- [x] Note any deferred Phase 2+ work explicitly (no hidden TODO behavior).

Phase 1 added chunk files/contracts (PR-summary source list):
1. `tools/editor/lib/src/chunks/chunk_domain_models.dart`
2. `tools/editor/lib/src/chunks/chunk_store.dart`
3. `tools/editor/lib/src/chunks/chunk_validation.dart`
4. `tools/editor/lib/src/chunks/chunk_domain_plugin.dart`
5. `tool/generate_chunk_runtime_data.dart`
6. `packages/runner_core/lib/track/chunk_pattern_source.dart`

## Final Acceptance Checklist

- [x] Chunk plugin exists, is registered, and is route-integrated.
- [x] Chunk workspace page is functional and not placeholder-only.
- [x] Schema is typed, versioned, and deterministic on save.
- [x] Immutable identity (`chunkKey`) and renameable label identity (`id`) are
      implemented and test-covered.
- [x] Floor/gap contract fields are schema-owned, persisted, and validated.
- [x] Floor/gap contract shape is typed and extensible (`kind`/`type` + stable
      IDs).
- [x] Validation blocks invalid chunk data and unsafe operations.
- [x] Active level context authority is enforced.
- [x] Grid/chunk-width authority checks are enforced before write/export.
- [x] Create/duplicate/rename/deprecate operations are deterministic and safe.
- [x] ID/revision safeguards are implemented and tested.
- [x] Drift-safe atomic export semantics are implemented and tested.
- [x] Generator seam validates chunk contracts in local/CI flow.
- [x] Load/save/validate/export loop is green with pending diff visibility.
- [x] Analyzer and relevant test suites pass.

