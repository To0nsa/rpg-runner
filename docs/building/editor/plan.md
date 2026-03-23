# Entity Collider Authoring Editor Plan

Date: March 23, 2026  
Status: Proposed (implementation not started)

## 1) Goal

Deliver a standalone authoring tool that can edit collider data for:

- player entities
- enemy entities
- projectile entities

The first milestone is collider editing only, but the architecture must be reusable for later domains (level chunk authoring, then animation authoring) without a rewrite.

## 2) Scope For This Milestone

### In scope

- Standalone editor application (not coupled to live run execution).
- Repository-linked workflow on Windows.
- Import/edit/export for collider values in current gameplay data.
- Validation rules for collider correctness.
- Clear extension points for future chunk and animation editors.

### Out of scope

- Level chunk editing UI and chunk persistence.
- Animation timeline/keyframe editing.
- Runtime gameplay-authoritative in-game editing.
- Backend integration.

## 3) Current Source-Of-Truth Map (Today)

Collider data is currently authored in Core Dart catalogs:

- Enemies: `packages/runner_core/lib/enemies/enemy_catalog.dart`
- Players: `packages/runner_core/lib/players/characters/eloise.dart` (and other character files as they are added)
- Projectiles: `packages/runner_core/lib/projectiles/projectile_catalog.dart`

Projectile collider values are consumed at spawn in:

- `packages/runner_core/lib/projectiles/spawn_projectile_item.dart`

Existing render debug overlay that can inspire editor visualization:

- `lib/game/debug/debug_aabb_overlay.dart`

## 4) Locked Architecture Decisions

1. The editor is a separate app/process and never becomes gameplay authority.
2. Core remains deterministic and unchanged in authority model.
3. The editor links to a repo path and performs import/export against source files.
4. Editor internals use one canonical collider model regardless of entity type.
5. Domain-specific logic is plugin-style so new domains (chunks, animation) can be added incrementally.
6. Export supports a safe workflow first (preview + patch output), then optional direct write mode.
7. Validation happens in the editor before export; invalid payloads cannot be exported as "applied".

## 5) Target Architecture

### 5.1 Editor App Layers

- UI Layer: canvas/handles/inspector panels, selection, undo/redo.
- Domain Layer: collider domain model + validation + editing commands.
- Workspace Layer: repo path binding, file read/write, change detection.
- Export Layer: patch generation/direct write, dry-run validation, diff preview.

### 5.2 Domain Plugin Contract (Future-Proofing)

Define a common authoring plugin interface (conceptual):

- `loadFromRepo(workspace)`
- `validate(document)`
- `buildEditableScene(document)`
- `applyEdit(command)`
- `exportToRepo(document, mode)`

Phase 1 implements only `ColliderDomainPlugin`.
Future phases add `ChunkDomainPlugin` and `AnimationDomainPlugin` with the same lifecycle.

### 5.3 Canonical Collider Model

Use a normalized collider shape in editor memory:

- `id` (stable content id)
- `entityType` (`player`, `enemy`, `projectile`)
- `halfX`
- `halfY`
- `offsetX`
- `offsetY`
- optional metadata (`displayName`, `spriteRef`)

Normalization rule:

- player authored width/height are converted to half extents on import
- projectile authored `colliderSizeX/Y` are converted to half extents on import
- export converts back to each source format

## 6) Export Strategy

### Phase A (first implementation)

- Generate human-readable patch output and/or ready-to-apply snippets.
- Require explicit user confirmation before writing files.
- Keep source ownership in existing Core files.

### Phase B (optional hardening)

- Add structured authoring files as intermediate source.
- Generate Core Dart code from structured source in one deterministic step.
- Keep generated output committed and reviewable.

Rationale: Phase A gets working value quickly with low migration risk; Phase B improves maintainability once flow is proven.

## 7) UX Contract (Collider Milestone)

1. Open workspace path.
2. Load all player/enemy/projectile collider entries.
3. Select an entry from list/tree.
4. Edit collider by dragging handles in viewport, numeric inspector fields, and nudge controls.
5. See immediate preview and validation state.
6. Export patch/snippet for selected or all changed entries.
7. Apply changes in repo and rerun game/tests.

## 8) Phased Plan With Acceptance

### Phase 1 - Workspace + Domain Foundation

Work:

- Create standalone editor app skeleton.
- Create workspace binding to repo root.
- Implement plugin interface and register collider plugin.

Acceptance:

- App opens and binds to a repo path.
- Collider plugin lifecycle executes end-to-end with stub data.

### Phase 2 - Import + Validation

Work:

- Parse current collider values from player/enemy/projectile authoring files.
- Normalize to canonical collider model.
- Implement validator rules.

Validation rules:

- `halfX > 0`, `halfY > 0`
- finite offsets and extents
- stable id mapping for each entry

Acceptance:

- Editor can load current repo collider data with no manual edits.
- Invalid entries are reported with actionable messages and source location.

### Phase 3 - Editing UX

Work:

- Canvas rendering for collider boxes.
- Selection/highlight.
- Handle drag + numeric inspector editing.
- Undo/redo.

Acceptance:

- User can edit all three entity groups in one session.
- Edits are deterministic and reversible via undo/redo.

### Phase 4 - Export + Write Safety

Work:

- Patch/snippet export generation.
- Optional direct-write mode with confirmation and backup.
- Diff preview before write.

Acceptance:

- Exported output is reviewable and maps to exact source ids.
- Direct write does not touch unrelated lines/files.

### Phase 5 - Hardening

Work:

- Unit tests for parser/normalizer/validator/exporter.
- Golden tests for representative source inputs.
- Error handling for partial/missing files.

Acceptance:

- Stable outputs for unchanged input.
- Regression suite catches mapping and conversion drift.

## 9) Extensibility Plan (After Collider Milestone)

### 9.1 Chunk Editing

Add `ChunkDomainPlugin` reusing:

- workspace binding
- selection model
- command stack
- export pipeline

Chunk-specific additions:

- grid-snap enforcement
- chunk-relative bounds checks
- overlap constraints
- spawn marker editing

### 9.2 Animation Editing

Add `AnimationDomainPlugin` reusing:

- workspace binding
- inspector/panel framework
- command stack
- export pipeline

Animation-specific additions:

- timeline UI
- frame window editing
- per-animation validation

## 10) Risks And Mitigations

- Risk: brittle source parsing against manual formatting changes.
  Mitigation: robust parser strategy + golden tests + clear parse errors.

- Risk: id mismatch between editor model and source entries.
  Mitigation: explicit stable id mapping and uniqueness checks.

- Risk: direct-write accidental churn.
  Mitigation: diff preview, scoped write targets, backup file, dry-run mode.

- Risk: future domains force editor rewrite.
  Mitigation: plugin contract from day one; collider implementation must use shared plugin lifecycle.

## 11) Validation Expectations During Implementation

For editor/tooling code changes:

- `dart analyze`
- targeted `flutter test`/`dart test` for editor packages

For Core integration changes:

- `dart analyze`
- relevant core/game tests covering collider import/export assumptions

If a check cannot run in CI/local, record it in implementation handoff.

## 12) Milestone Exit Criteria (Collider Editor v1)

- Player/enemy/projectile collider data can be imported from repo.
- Collider edits can be made visually and numerically.
- Validation blocks invalid export.
- Export produces deterministic, reviewable changes.
- Architecture has a documented plugin path for chunk and animation domains.
