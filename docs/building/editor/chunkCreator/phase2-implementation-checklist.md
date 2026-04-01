# Chunk Creator Phase 2 - Implementation Checklist

Date: April 1, 2026  
Status: Step 0 completed on April 1, 2026; Step 1 next  
Source plan: [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md)
Step 0 freeze doc:
[docs/building/editor/chunkCreator/phase2-step0-contract-freeze.md](docs/building/editor/chunkCreator/phase2-step0-contract-freeze.md)

This checklist turns Phase 2 of the chunk creator plan into an execution
sequence with concrete file targets, future-proof contract decisions, and
Phase 3 handoff seams.

## Goal

Ship Phase 2 end-to-end:

- obstacle/platform prefab authoring is explicit, typed, and deterministic
- prefab contract shape is future-proof for Phase 3 runtime cutover
- prefab visual source is explicit (atlas slice vs composed platform module)
- collider/anchor requirements are kind-aware and validation-gated
- legacy Phase 0 prefab data migrates safely without manual edits
- persistence remains deterministic and review-friendly
- preview overlays make collider/anchor/snap behavior obvious to designers
- no schema rewrite is needed in Phase 3 to consume authored prefab data

## Phase 2 Gate (must pass)

- non-dev user can create obstacle/platform prefabs without code changes
- platform prefabs can reference composed platform modules deterministically
- obstacle/platform prefab definitions block on missing or invalid collider/anchor
- kind/source contract is explicit and test-covered
- legacy v1 prefab data migrates deterministically to finalized Phase 2 schema
- load/save round-trip has no semantic drift
- prefab contract emitted by Phase 2 can be consumed by Phase 3 without schema redesign

## Scope Boundaries for Phase 2

In scope:

- prefab schema contract hardening and migration path
- obstacle/platform prefab kind model and typed source references
- collider/anchor semantics and validation
- prefab authoring UI for kind-specific flows
- prefab preview overlays (anchor + collider + source visualization)
- deterministic persistence and canonical serialization
- reference-safety constraints required for Phase 3 handoff
- regression coverage for existing Phase 0 authoring data

Out of scope in this phase:

- runtime replacement of obstacle/platform contracts in `runner_core` (Phase 3)
- chunk paint/placement UX and simulation overlays (later phases)
- parallax authoring (Phase 4)
- floor/gap tools (Phase 5)
- gameplay marker authoring (Phase 6)

## Current Gaps to Close

Current baseline gaps that Phase 2 must close to avoid rework:

- prefab contract is generic (`sliceId`) and does not encode obstacle vs platform intent
- visual source type is implicit instead of typed (`atlas_slice` vs `platform_module`)
- prefab identity is currently ID-only and rename-risky for downstream references
- validator does not enforce kind-specific source/collider rules
- no explicit migration contract from Phase 0 shape to a Phase 2/3-ready shape
- preview semantics are not yet kind-aware (for example platform surface behavior hints)

## Locked Invariants

- Source-of-truth files remain:
  - `assets/authoring/level/prefab_defs.json`
  - `assets/authoring/level/tile_defs.json`
- Prefab schema is versioned and deterministic on save.
- Prefab identity is explicit and stable:
  - `prefabKey` is immutable (machine identity)
  - `id` is user-facing and may be renamed only via explicit operation
  - `revision` is integer and mutation-safe
- Prefab kind is explicit and typed:
  - `kind` in `{obstacle, platform}`
  - kind-specific required fields are enforced by validator
- Prefab visual source is explicit and typed:
  - `visualSource.type` in `{atlas_slice, platform_module}`
  - `atlas_slice` source references prefab slice IDs only
  - `platform_module` source references tile module IDs only
- Collider and anchor contracts are explicit and deterministic:
  - anchor values are integer pixels
  - collider dimensions are positive integers
  - geometry-affecting values obey runtime-authoritative snap policy
- Validation errors are blocking for save/export in prefab workflow.
- Migration is deterministic:
  - same v1 input produces byte-equivalent normalized v2 output
  - no hidden lossy migration behavior

## Pre-flight

- [ ] Re-read Phase 2 in
      [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md).
- [ ] Snapshot current prefab/tile schema examples:
  - [assets/authoring/level/prefab_defs.json](assets/authoring/level/prefab_defs.json)
  - [assets/authoring/level/tile_defs.json](assets/authoring/level/tile_defs.json)
- [ ] Confirm current prefab model/store/validator baseline:
  - [tools/editor/lib/src/prefabs/prefab_models.dart](tools/editor/lib/src/prefabs/prefab_models.dart)
  - [tools/editor/lib/src/prefabs/prefab_store.dart](tools/editor/lib/src/prefabs/prefab_store.dart)
  - [tools/editor/lib/src/prefabs/prefab_validation.dart](tools/editor/lib/src/prefabs/prefab_validation.dart)
- [ ] Confirm current prefab UI flow baseline:
  - [tools/editor/lib/src/app/pages/prefabCreator/prefab_creator_page.dart](tools/editor/lib/src/app/pages/prefabCreator/prefab_creator_page.dart)
  - [tools/editor/lib/src/app/pages/prefabCreator/state/prefab_logic.dart](tools/editor/lib/src/app/pages/prefabCreator/state/prefab_logic.dart)
  - [tools/editor/lib/src/app/pages/prefabCreator/tabs/prefabs_tab.dart](tools/editor/lib/src/app/pages/prefabCreator/tabs/prefabs_tab.dart)
  - [tools/editor/lib/src/app/pages/prefabCreator/widgets/prefab_scene_view.dart](tools/editor/lib/src/app/pages/prefabCreator/widgets/prefab_scene_view.dart)
- [ ] Record baseline green:
  - [ ] `cd tools/editor && dart analyze`
  - [ ] `cd tools/editor && flutter test`

Done when:

- [ ] assumptions are validated
- [ ] baseline is green before Phase 2 changes

## Step 0 - Contract Freeze and Migration Plan

Objective:

- freeze a Phase 2 prefab contract that avoids schema churn in Phase 3

Reference:

- [docs/building/editor/chunkCreator/phase2-step0-contract-freeze.md](docs/building/editor/chunkCreator/phase2-step0-contract-freeze.md)

Tasks:

- [x] Define finalized Phase 2 prefab schema version (for example `schemaVersion: 2`).
- [x] Define stable identity model in schema:
  - [x] `prefabKey` (immutable)
  - [x] `id` (renameable label)
  - [x] `revision`
- [x] Define typed prefab kind:
  - [x] `kind: obstacle | platform`
- [x] Define typed visual source union:
  - [x] `visualSource.type: atlas_slice | platform_module`
  - [x] `visualSource.sliceId` for `atlas_slice`
  - [x] `visualSource.moduleId` for `platform_module`
- [x] Define deterministic migration from existing v1 records:
  - [x] `kind` default mapping for legacy records
  - [x] `visualSource` derivation from legacy `sliceId`
  - [x] `prefabKey` allocation strategy (stable and collision-safe)
  - [x] `revision` default strategy
- [x] Document migration behavior for invalid legacy records (block vs normalize).

Done when:

- [x] schema contract is frozen and documented
- [x] migration mapping is explicit and testable
- [x] no unresolved contract ambiguity remains for Phase 3

## Step 1 - Prefab Models and Typed Schema

Objective:

- implement typed Phase 2 prefab contracts in editor domain models

Tasks:

- [ ] Update
      [tools/editor/lib/src/prefabs/prefab_models.dart](tools/editor/lib/src/prefabs/prefab_models.dart)
      with Phase 2 types:
  - [ ] `PrefabKind` typed enum/value object
  - [ ] `PrefabVisualSource` typed union/value object
  - [ ] identity fields (`prefabKey`, `id`, `revision`)
  - [ ] explicit status/lifecycle field if deprecate semantics are needed
- [ ] Preserve/normalize deterministic field ordering and list ordering:
  - [ ] tags
  - [ ] colliders
  - [ ] prefab list ordering
- [ ] Keep parse tolerant and serialization strict:
  - [ ] tolerant `fromJson` for legacy/v1 payloads
  - [ ] strict canonical `toJson` output for v2 shape
- [ ] Add helper APIs needed by UI and validation:
  - [ ] kind-aware source helpers
  - [ ] identity-safe copy/update helpers

Done when:

- [ ] schema compiles with explicit typed contracts
- [ ] v1 payloads parse/migrate into v2 model deterministically
- [ ] v2 output shape is canonical and stable

## Step 2 - Store, Migration, and Deterministic Persistence

Objective:

- persist migrated/edited prefab definitions safely and deterministically

Tasks:

- [ ] Update
      [tools/editor/lib/src/prefabs/prefab_store.dart](tools/editor/lib/src/prefabs/prefab_store.dart)
      to:
  - [ ] load v1/v2 schema and migrate to in-memory v2 model
  - [ ] persist only canonical v2 output after save
  - [ ] keep deterministic serialization order and trailing newline policy
- [ ] Ensure deterministic cross-file consistency:
  - [ ] prefab source refs validate against tile module/slice registries
  - [ ] stable ordering across `prefab_defs.json` and `tile_defs.json`
- [ ] Add write safety expectations:
  - [ ] explicit failure behavior for malformed JSON
  - [ ] atomic write strategy for `prefab_defs.json` and `tile_defs.json`
- [ ] Add migration telemetry/hints for debugging (non-flaky deterministic messaging).

Done when:

- [ ] repeated load->save->load yields no semantic drift
- [ ] migrated output is deterministic across runs and machines
- [ ] write path is safe and failure modes are explicit

## Step 3 - Validation Rules (Kind-Aware and Future-Proof)

Objective:

- enforce blocking rules that keep Phase 2 data runtime-ready for Phase 3

Tasks:

- [ ] Expand
      [tools/editor/lib/src/prefabs/prefab_validation.dart](tools/editor/lib/src/prefabs/prefab_validation.dart)
      with Phase 2 checks:
  - [ ] invalid/missing schema version
  - [ ] invalid/missing `prefabKey`, duplicate `prefabKey`
  - [ ] invalid/missing `id`, duplicate `id`
  - [ ] invalid/missing `revision`
  - [ ] invalid/missing `kind`
  - [ ] invalid/missing `visualSource`
  - [ ] source mismatch (kind/source incompatibility)
  - [ ] unknown referenced slice/module IDs
  - [ ] missing/invalid anchor fields
  - [ ] missing/invalid collider fields
  - [ ] kind-specific collider contract violations
  - [ ] non-snapped geometry-affecting values against runtime authority
  - [ ] malformed tags/payload arrays
- [ ] Add stable validator issue codes for each blocking category.
- [ ] Ensure deterministic issue ordering and deterministic messages.

Done when:

- [ ] invalid Phase 2 prefab data is blocked before save/export
- [ ] validator clearly explains kind/source contract violations
- [ ] validation output is deterministic and test-covered

## Step 4 - Prefab Creator Flow (Kind-Specific Authoring UX)

Objective:

- expose explicit obstacle/platform prefab authoring flow in editor

Tasks:

- [ ] Update Prefab Creator UI to support kind-first flow:
  - [ ] add `kind` selector (`obstacle`, `platform`)
  - [ ] add source-type-aware picker
  - [ ] surface only compatible source choices for chosen kind
- [ ] Update prefab form behavior:
  - [ ] obstacle flow references prefab atlas slices
  - [ ] platform flow references composed platform modules
  - [ ] anchor/collider inputs remain explicit and validated
- [ ] Improve lifecycle operations for identity safety:
  - [ ] create/duplicate/rename/deprecate (or equivalent explicit operations)
  - [ ] preserve `prefabKey` invariants through rename
  - [ ] deterministic revision policy on edits
- [ ] Ensure UI actions are validation-gated and deterministic:
  - [ ] no hidden side effects in widget `build`
  - [ ] clear status/error messaging
  - [ ] deterministic ordering in list panels and pickers

Done when:

- [ ] designers can author both kinds end-to-end without raw JSON edits
- [ ] identity/revision behavior is explicit and predictable in UI
- [ ] kind/source mistakes are blocked with actionable feedback

## Step 5 - Preview Overlays (Anchor/Collider/Snap)

Objective:

- provide accurate visual feedback for prefab placement semantics

Tasks:

- [ ] Update
      [tools/editor/lib/src/app/pages/prefabCreator/widgets/prefab_scene_view.dart](tools/editor/lib/src/app/pages/prefabCreator/widgets/prefab_scene_view.dart)
      to render:
  - [ ] source preview for atlas slice prefabs
  - [ ] source preview for platform module prefabs
  - [ ] anchor crosshair/marker overlay
  - [ ] collider overlay(s) with clear bounds
  - [ ] grid snap overlay/hints for invalid unsnapped values
- [ ] Ensure preview is deterministic and frame-stable across interactions.
- [ ] Keep mobile/desktop usability parity for key interactions.

Done when:

- [ ] preview reflects serialized values exactly
- [ ] designers can verify anchor/collider visually before save
- [ ] no preview-only state drifts from stored contract values

## Step 6 - Phase 3 Handoff Seams (No Runtime Cutover Yet)

Objective:

- land adapter seams now so Phase 3 does not rewrite Phase 2 data contracts

Tasks:

- [ ] Define runtime-facing DTO mapping inside editor/tooling layer (not runner_core cutover yet):
  - [ ] kind mapping contract
  - [ ] collider mapping contract
  - [ ] anchor/source mapping contract
- [ ] Ensure generator/tool seam can read finalized Phase 2 prefab schema without lossy transforms.
- [ ] If needed for reference safety, add optional chunk-side prefab identity passthrough seam now:
  - [ ] optional `prefabKey` reference support where chunk-prefab refs are modeled
  - [ ] backwards-compatible fallback for legacy `prefabId` refs
- [ ] Document explicit adapter-removal criteria for Phase 3 implementation.

Done when:

- [ ] Phase 3 can consume Phase 2 schema directly (or via thin deterministic adapter)
- [ ] no additional schema redesign is needed for runtime replacement
- [ ] handoff contract is documented and test-covered

## Step 7 - Tests

Objective:

- lock Phase 2 behavior and migration safety before Phase 3 work begins

Tasks:

- [ ] Expand model/store tests:
  - [ ] v1->v2 migration determinism
  - [ ] typed kind/source parse/serialize
  - [ ] deterministic ordering invariants
  - [ ] identity/revision invariants
  - [ ] round-trip load/save stability
- [ ] Expand validation tests:
  - [ ] kind/source mismatches
  - [ ] missing/invalid anchor/collider failures
  - [ ] duplicate identity failures (`prefabKey`, `id`)
  - [ ] invalid source references (`sliceId`, `moduleId`)
  - [ ] unsnapped geometry failures
- [ ] Add widget tests for prefab authoring:
  - [ ] kind switch flow
  - [ ] source picker filtering behavior
  - [ ] obstacle create/edit flow
  - [ ] platform create/edit flow
  - [ ] blocking validation surfacing
- [ ] Add regression tests for legacy Phase 0 data compatibility.
- [ ] Add seam tests that assert Phase 3 mapping contract stability.

Done when:

- [ ] all Phase 2 gate behaviors are test-covered
- [ ] migration and identity-critical paths are covered
- [ ] Phase 3 handoff seam has explicit regression tests

## Step 8 - Validation Commands

- [ ] `cd tools/editor && dart analyze`
- [ ] `cd tools/editor && flutter test`
- [ ] `cd tools/editor && flutter test test/prefab_store_test.dart`
- [ ] `cd tools/editor && flutter test test/prefab_validation_test.dart`
- [ ] run new Phase 2 widget tests (once added)
- [ ] `dart run tool/generate_chunk_runtime_data.dart --dry-run`
- [ ] run touched root-level regression tests if shared contracts changed

Done when:

- [ ] analyzer is clean for touched scope
- [ ] relevant tests pass locally

## Step 9 - Docs and Handoff

- [ ] Update Phase 2 status in
      [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md)
      when complete.
- [ ] Document finalized Phase 2 prefab contract fields and migration rules.
- [ ] Document finalized identity policy (`prefabKey` vs `id`) and revision policy.
- [ ] Document finalized kind/source compatibility matrix.
- [ ] Document Phase 3 handoff seams and adapter-removal criteria.
- [ ] Include explicit list of new/changed files and tests in PR summary.
- [ ] Note deferred work explicitly (no hidden TODO behavior).

## Final Acceptance Checklist

- [ ] Prefab contract is typed and schema-versioned for obstacle/platform intent.
- [ ] Prefab visual source contract is explicit and deterministic.
- [ ] Collider/anchor requirements are enforced and test-covered.
- [ ] Legacy Phase 0 prefab data migrates deterministically to Phase 2 contract.
- [ ] Prefab authoring UI supports kind-specific obstacle/platform workflows.
- [ ] Preview overlays accurately reflect source, anchor, and collider data.
- [ ] Persistence is deterministic, canonical, and safe.
- [ ] Validation blocks invalid prefab definitions before save/export.
- [ ] Phase 3 runtime handoff requires no schema redesign.
- [ ] Analyzer and relevant tests pass.
