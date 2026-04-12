# Level Creator High-Level Plan

Date: April 11, 2026  
Status: Complete on April 11, 2026

## 1) Mission

Build a production-ready Level Creator workflow for `rpg_runner` inside
`tools/editor`, focused on authored level metadata and generated runtime
registries, not freeform world editing.

### Primary outcomes

- authored level metadata replaces hand-maintained Dart registry data
- `visualThemeId` ownership moves into Level Creator
- non-dev users can create and edit level metadata without touching runtime
  source files
- deterministic authoring output and generated runtime data stay reviewable
- chunk/core gameplay authority remains unchanged

### Core rules

- level metadata becomes authored data, not hand-maintained Dart
- `visualThemeId` mapping belongs to Level Creator, not Parallax Editor
- chunk/core stays authoritative for gameplay chunks, collision, traversal,
  spawn, and streaming
- first shipped scope edits only the runtime level contract that exists today
- no enum or registry hand-edits in normal workflow after cutover

## 2) Current Repo Baseline

### Runtime side

Current level authority is split across:

- `packages/runner_core/lib/levels/level_id.dart`
- `packages/runner_core/lib/levels/level_registry.dart`
- `packages/runner_core/lib/levels/level_definition.dart`
- `lib/ui/levels/level_id_ui.dart`

### Editor side

Current editor level discovery is indirect:

- `tools/editor/lib/src/workspace/level_context_resolver.dart`

The editor currently uses level options and theme mapping as discovered context.
It does not yet own level lifecycle, validation, or generated runtime output.

## 3) Chosen Architecture

Use JSON authoring source of truth + generated runtime Dart for level
definitions.

### 3.1 Authoring source of truth

Add:

- `assets/authoring/level/level_defs.json`

Typed models:

- `LevelDefsDocument`
- `LevelDef`
- `LevelSourceBaseline`

Suggested per-level fields:

- `levelId`
- `revision`
- `displayName`
- `visualThemeId`
- `cameraCenterY`
- `groundTopY`
- `earlyPatternChunks`
- `easyPatternChunks`
- `normalPatternChunks`
- `noEnemyChunks`
- `enumOrdinal`
- `status`

Determinism rules:

- `levelId` is stable and immutable
- `enumOrdinal` is stable and unique
- canonical field order
- deterministic level list order by `levelId`
- generated enum order by `enumOrdinal`
- normalized numeric formatting
- deterministic serialization and save plans

### 3.2 Runtime generation

Extend `tool/generate_chunk_runtime_data.dart` in phases to:

- read `level_defs.json`
- validate + canonicalize it
- emit generated `level_id.dart`
- emit generated `level_registry.dart`
- optionally emit generated UI metadata helpers

Phase 1 is foundation-only: parse, validate, canonicalize, and bootstrap the
authored file without changing runtime-generated level outputs yet.

### 3.3 Editor domain

Add a dedicated level authoring domain:

- `tools/editor/lib/src/levels/level_domain_models.dart`
- `tools/editor/lib/src/levels/level_store.dart`
- `tools/editor/lib/src/levels/level_validation.dart`
- `tools/editor/lib/src/levels/level_domain_plugin.dart`
- `tools/editor/lib/src/app/pages/levelCreator/level_creator_page.dart`

Capabilities:

- create level
- edit metadata
- assign `visualThemeId`
- deprecate/reactivate level
- select active level
- validate in real time
- include level edits in pending diff + safe write flow

## 4) Validation Model

### Blocking errors

- duplicate `levelId`
- duplicate `enumOrdinal`
- invalid or empty `displayName`
- invalid `levelId` or `visualThemeId` format
- invalid revision
- non-finite numeric values
- negative chunk-window counts
- invalid `status`
- deterministic canonicalization failure
- source drift during export

### Warnings

- `visualThemeId` not yet authored in parallax defs
- level has zero chunks
- deprecated level still selected in editor
- unusual `cameraCenterY` or `groundTopY`

## 5) Delivery Phases

### Phase 1 - Contract + Bootstrap Foundation

Status: Complete on April 11, 2026

Scope:

- add `assets/authoring/level/level_defs.json`
- add generator-side parser/serializer/validator
- enforce canonical serialization and deterministic ordering
- bootstrap authored level data from current runtime behavior
- update editor level option discovery to read the authored contract shape
- add focused tests for level authoring contract determinism

Gate:

- `level_defs.json` exists in canonical form
- generator dry-run validates authored level metadata
- authored level data round-trips deterministically in tests
- existing runtime behavior remains unchanged

### Phase 2 - Runtime Registry Generation Cutover

Status: Complete on April 11, 2026

Scope:

- generate `level_id.dart`
- generate `level_registry.dart`
- keep generated output behavior-equivalent with current runtime definitions
- add parity/snapshot tests for generated level runtime files

Gate:

- runtime level registry output is generated from authored data
- no manual level enum/registry edits are needed in the normal workflow
- current gameplay behavior remains unchanged

### Phase 3 - Level Domain Plugin + Safe Write Flow

Status: Complete on April 11, 2026

Scope:

- implement level store, plugin, validation, and pending diff flow
- support direct repository edits through safe write/export semantics

Gate:

- level metadata can be loaded, edited, validated, and written through the
  editor domain path

### Phase 4 - Level Creator UI

Status: Complete on April 11, 2026

Scope:

- add `Level Creator` route/page
- level list pane
- inspector pane
- create/deprecate/reactivate workflows
- `visualThemeId` assignment and metadata editing

Gate:

- non-dev user can create and edit a level fully in editor

### Phase 5 - Consumer Cutover

Status: Complete on April 11, 2026

Scope:

- chunk/parallax editor workflows resolve levels from authored defs first
- parallax consumes authored/generated level -> theme mapping
- UI level selection uses generated display metadata
- standard selection UI hides deprecated levels through generated UI metadata

Gate:

- level metadata is single-sourced through authored/generated paths

### Phase 6 - Hardening

Status: Complete on April 11, 2026

Scope:

- regression coverage
- replay/board/selection checks
- docs cleanup
- migration closure

Gate:

- deterministic tests remain green
- no gameplay drift
- docs reflect the new authoritative level workflow

## 6) Test Matrix

Editor:

- load/save round-trip determinism
- create/deprecate stability
- `enumOrdinal` stability
- validation categories
- pending diff correctness

Generator:

- authored JSON -> generated Dart parity
- stable output snapshots
- bootstrap migration parity

Runtime/UI:

- `LevelRegistry.byId` matches authored data
- level selection uses generated display metadata
- parallax theme resolves from authored level mapping
- chunk source still resolves by `levelId`

Regression:

- existing gameplay deterministic tests unchanged
- replay tests unchanged
- board/selection flows unchanged for existing levels

## 7) Immediate Next Slice

No open slice remains in this plan.

Future work should build on the completed Level Creator baseline in a new plan.
