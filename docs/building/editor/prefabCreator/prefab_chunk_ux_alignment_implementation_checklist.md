# Prefab And Chunk Creator UX Alignment Implementation Checklist

Date: August 25, 2026
Status: In progress

Source strategy:
[Prefab and Chunk Creator UX alignment strategy](prefab_chunk_ux_alignment_strategy.md)

This checklist is gated. A phase is complete only when its behavior, tests,
documentation, and validation boxes are complete. The strategy's complete scope
matrix remains authoritative; implementation may be delivered in coherent
commits without claiming later phases are done.

## Locked Invariants

- [x] Prefab and Chunk plugins/stores remain the only document and export
      authorities.
- [x] Search, filters, expansion, selection, viewport, and unapplied form values
      remain route-local presentation state.
- [x] Metadata forms cannot mutate identity, dimensions, geometry, or
      composition outside their typed snapshots.
- [x] Rename preserves the stable owner key.
- [x] One accepted Apply produces at most one matching semantic command, owner
      revision increment, and undo entry.
- [x] Destructive owner/slice/module deletes retain reference-aware protection.
- [x] Prefab half-pixel collision capability remains supported.
- [x] Prefab Creator does not gain Chunk runtime evidence overlays.
- [x] Apply-to-files remains explicit, validated, drift-checked, and atomic.

## Phase 0 — Strategy And Baseline

Objective: freeze the requested scope and current contracts before moving
stateful forms.

### Documentation

- [x] Record the complete agreed UX comparison matrix in the strategy.
- [x] Include Chunk owner metadata in the inline-edit migration.
- [x] Mark Chunk runtime preview/evidence features as an intentional difference.
- [x] Define goals, non-goals, command boundaries, responsive layout, draft
      lifecycle, phases, validation, and acceptance criteria.
- [x] Create this gated implementation checklist.

### Implementation inventory

- [x] Locate Prefab owner create/edit/rename/delete paths and metadata fields.
- [x] Locate Chunk owner create/edit/rename/delete paths and metadata fields.
- [x] Confirm Prefab owner selection lacks the Chunk active-operation guard.
- [x] Confirm current Prefab collision metadata still opens a modal.
- [x] Confirm Prefab owners use a text list without catalog search or previews.
- [x] Confirm narrow Prefab layout uses exclusive panel tabs.
- [x] Identify existing Chunk inline terrain/prefab/marker patterns and shared
      panel/list/scene primitives.

## Phase 1 — Inline Owner Metadata And Draft Safety

Objective: remove normal metadata-edit modals for both owner types and close the
critical Prefab owner-switch data-loss path.

### Reusable owner forms

- [x] Extract a reusable Prefab-v3 owner field widget from the retained dialog.
- [x] Keep create-only fields and validation available for Phase 2 reuse.
- [x] Extract a reusable Chunk-v2 owner metadata field widget from the retained
      dialog.
- [x] Give both forms explicit Apply/Cancel callbacks and stable field keys.
- [x] Expose clean/dirty state without dispatching a source command.
- [x] Preserve submitted value objects and canonical tag behavior.
- [x] Report field and submission errors inline.

### Prefab owner editor

- [x] Selecting an owner row opens its editor directly below that row.
- [x] Selecting the expanded row again closes a clean editor.
- [x] Render owner key, revision, source, collision count, and downstream impact
      in the expanded context.
- [x] Apply the existing `PrefabV3MetadataCommit` with the captured stable key
      and before snapshot.
- [x] Leave the editor open with values intact when the command is rejected.
- [x] Cancel closes without changing source, history, revision, or pending diff.
- [x] Remove the detached Prefab **Edit** action.
- [x] Remove the normal Prefab owner metadata modal entry point and dead code.

### Chunk owner editor

- [x] Selecting a Chunk owner row opens its editor directly below that row.
- [x] Selecting the expanded row again closes a clean editor.
- [x] Render key, revision, dimensions, tile size, and composition counts in the
      expanded context.
- [x] Apply the existing `ChunkV2MetadataCommit` while preserving all non-owned
      fields.
- [x] Leave the editor open with values intact when the command is rejected.
- [x] Cancel closes without changing source, history, revision, or pending diff.
- [x] Remove the detached Chunk **Edit** action.
- [x] Remove the normal Chunk owner metadata modal entry point and dead code.

### Draft and navigation safety

- [x] Include dirty owner forms in `hasLocalDraftChanges`.
- [x] Disable Apply-to-files while an owner form is dirty.
- [x] Resolve Save/Discard/Cancel before switching owner or level.
- [x] Protect Prefab workspace-view changes while its owner form is dirty.
- [x] Do not silently dispose an active Prefab polygon operation on owner switch.
- [x] Prevent session undo/redo from bypassing an unresolved owner form.
- [x] Reconcile inline editors safely after accepted command, undo, redo, reload,
      owner deletion, and source revision change.

### Phase 1 tests

- [x] Prefab owner row opens and closes its inline editor.
- [x] Prefab metadata Apply preserves identity and collision while incrementing
      revision exactly once.
- [x] Prefab Cancel is a source/history no-op.
- [x] Prefab owner/view switching cannot discard dirty metadata or polygon work.
- [x] Chunk owner row opens and closes its inline editor.
- [x] Chunk metadata Apply preserves dimensions, collision, and composition
      while incrementing revision exactly once.
- [x] Chunk Cancel is a source/history no-op.
- [x] Chunk owner/level switching resolves dirty metadata safely.
- [x] Rejected/stale owner metadata leaves each form open and reports the issue.
- [x] Legacy edit-modal widget keys and expectations are removed.

### Phase 1 validation and docs

- [x] Update `tools/editor/README.md` for inline owner metadata behavior.
- [x] Update `docs/tdd/editor_ui_system.md` with owner editor/draft contracts.
- [x] Update `docs/tdd/polygon_terrain_authoring_foundation.md` where the
      retained dialog description becomes stale.
- [x] Run `dart analyze` in `tools/editor`.
- [x] Run focused Prefab and Chunk workspace tests.
- [x] Run the complete `flutter test` suite in `tools/editor`.
- [x] Commit Phase 1 as one validated logical milestone.

## Phase 2 — Contextual Lifecycle And Inline Creation

Objective: remove detached owner toolbars and remaining routine owner forms from
modal navigation.

### Contextual actions

- [x] Move Prefab Rename, Duplicate, and Delete into the expanded owner editor.
- [x] Move Chunk Rename, Duplicate, and Delete into the expanded owner editor.
- [x] Keep labels and tooltips explicit; do not expose icon-only destructive
      clusters on unselected rows.
- [x] Ensure every action captures and targets the expanded stable owner key.
- [x] Keep downstream/reference impact visible before owner deletion.
- [x] Clear or rebind selection deterministically after duplicate/delete.

### Inline rename

- [x] Add stable-key-preserving inline human-ID editing for Prefab owners.
- [x] Add stable-key-preserving inline human-ID editing for Chunk owners.
- [x] Validate trimmed unique IDs before command dispatch.
- [x] Keep metadata and rename command/revision semantics explicit when both are
      changed.
- [x] Remove Prefab and Chunk rename dialogs and their detached buttons.

### Inline creation

- [x] Add a collapsed **Create prefab owner** section.
- [x] Reuse the Prefab owner field widget for kind, source, anchor, and tags.
- [x] Show human ID and create-specific validation only in create mode.
- [x] Apply one existing Prefab lifecycle create command and select the result.
- [x] Add a collapsed **Create chunk owner** section.
- [x] Explain locked level dimensions/tile size and deprecated initial status.
- [x] Apply one existing Chunk lifecycle create command and select the result.
- [x] Cancel/reset creation without source or history changes.
- [x] Remove Prefab and Chunk create-owner dialogs and detached New actions.

### Phase 2 tests and validation

- [x] Cover contextual targeting for rename, duplicate, and delete.
- [x] Cover unique-ID errors and stable-key preservation.
- [x] Cover inline create Apply/Cancel and deterministic new selection.
- [x] Cover reference-aware owner delete confirmation.
- [x] Update README/TDD and this checklist.
- [x] Run analyzer, focused tests, and full editor tests.
- [x] Commit Phase 2 as one validated logical milestone.

## Phase 3 — Searchable Visual Prefab Owner Library

Objective: replace the long text-only Prefab owner list with the same quality of
selection model used by Chunk prefab and enemy libraries.

### Shared catalog foundation

- [x] Audit `ChunkPrefabCatalogBrowser` for owner-neutral image, thumbnail,
      token-search, filter, keyboard, and selection behavior.
- [x] Extract only genuinely shared primitives under the shared editor surface.
- [x] Keep source-specific labels and usage semantics in their owning routes.
- [x] Avoid duplicate image caches, tokenizers, and thumbnail projections.

### Prefab owner library

- [x] Render atlas-slice and platform-module previews for every owner.
- [x] Search ID, stable key, kind, source reference, and tags token-by-token.
- [x] Filter by kind and active/deprecated status.
- [x] Show collision-shape count, revision, source, and downstream usage.
- [x] Provide deterministic ordering and clear empty/no-result states.
- [x] Support Enter to select the first filtered result.
- [x] Preserve route-local selection without creating source changes.
- [x] Expand the selected owner's editor below its visual card.
- [x] Remove the legacy plain owner list.

### Selected-owner synchronization

- [x] Add a compact Prefab header owner selector.
- [x] Synchronize header, library card, scene context, and editor by stable key.
- [x] Preserve viewport and selection where safe across filtering and expansion.
- [x] Show selected owner ID/source in the scene heading or summary.

### Phase 3 tests and validation

- [x] Cover search tokens, kind/status filters, clear, no-results, and Enter.
- [x] Cover atlas, platform-module, missing-image, and deprecated previews.
- [x] Cover header/library/scene synchronization and no-op presentation state.
- [x] Add a representative expanded-catalog performance fixture.
- [x] Update README/TDD and this checklist.
- [x] Run analyzer, focused tests, and full editor tests (analyzer clean; 554
      complete editor tests pass on August 26, 2026).
- [x] Commit Phase 3 as one validated logical milestone.

## Phase 4 — Prefab Collision Shape Alignment

Objective: give Prefab collision shapes the complete Chunk terrain row-local
editing model without changing Prefab geometry rules.

### Section split

- [ ] Add a collapsed **Create collision shape** section.
- [ ] Add a collapsed **Existing collision shapes** section with a total count.
- [ ] Move Diagnostics into its own collapsed section in Phase 5-ready form.
- [ ] Remove the combined **Shapes and diagnostics** panel.

### Creation workflow

- [ ] Add optional/validated shape identity before drawing.
- [ ] Add permitted collision mode, surface, and material controls.
- [ ] Preserve Prefab kind restrictions and half-pixel/whole-pixel snap choice.
- [ ] Show polygon/rectangle draft status and minimum-vertex readiness.
- [ ] Keep Save and Cancel in the creation section.

### Existing-shape workflow

- [ ] Expand the selected shape directly below its row.
- [ ] Re-click closes the selected shape editor.
- [ ] Resolve Save/Discard/Cancel before leaving dirty exact fields.
- [ ] Move collision mode, surface kind, material, and shape identity inline.
- [ ] Keep Duplicate, Normalize, and Delete contextual.
- [ ] Remove the Prefab collision metadata modal and dead code.
- [ ] Keep list and scene shape/vertex selection synchronized.

### Exact geometry

- [ ] Reuse the shared compact rectangle editor for axis-aligned rectangles.
- [ ] Preserve arbitrary polygon vertex editing.
- [ ] Preserve Prefab half-pixel display and validation where allowed.
- [ ] Ensure accepted exact edits create one collision command/revision/undo.

### Phase 4 tests and validation

- [ ] Cover creation defaults, polygon/rectangle drafts, Save, and Cancel.
- [ ] Cover row-local metadata and lifecycle actions.
- [ ] Cover rectangle and arbitrary polygon exact editing.
- [ ] Cover list/scene synchronization and unsaved-edit resolution.
- [ ] Update README/TDD and this checklist.
- [ ] Run analyzer, focused tests, full editor tests, and generator dry-run when
      the runtime seam is touched.
- [ ] Commit Phase 4 as one validated logical milestone.

## Phase 5 — Panels, Diagnostics, And Responsive Layout

Objective: remove remaining layout drift while keeping the Prefab scene primary.

### Panel organization and defaults

- [ ] Use flat sibling `EditorSectionCard`s in sidebars without redundant
      wrapper cards.
- [ ] Make owner, creation, existing, atlas/module authoring, and Diagnostics
      sections independently collapsible.
- [ ] Start every inactive sidebar section collapsed.
- [ ] Keep a section expanded and non-collapsible while it owns an active draft.
- [ ] Preserve expansion as presentation-only state while mounted.

### Diagnostics

- [ ] Show complete session issue projection with error/warning/info counts.
- [ ] Keep owner/shape focus actions where a stable target resolves.
- [ ] Preserve issues for non-selected owners instead of hiding them.
- [ ] Ensure expansion/focus creates no source change.

### Responsive scene-preserving layout

- [ ] Replace exclusive narrow Owners/Scene/Shapes tabs.
- [ ] Keep the scene subtree mounted on wide and narrow layouts.
- [ ] Place owner and authoring sidebars below the bounded scene when narrow.
- [ ] Preserve viewport, selected owner, selected shape, and drafts during
      responsive changes.
- [ ] Verify keyboard traversal and semantics order in both layouts.

### Phase 5 tests and validation

- [ ] Cover default collapsed state and expansion retention.
- [ ] Cover active-editor forced expansion.
- [ ] Cover complete Diagnostics counts/focus/no-op behavior.
- [ ] Cover wide/narrow layout keys, scene identity, viewport, and selection.
- [ ] Update README/TDD and this checklist.
- [ ] Run analyzer, focused tests, and full editor tests.
- [ ] Commit Phase 5 as one validated logical milestone.

## Phase 6 — Atlas/Module Consistency And Closeout

Objective: finish consistent language and interaction without changing catalog
semantics.

### Atlas and platform modules

- [ ] Make nested atlas setup/action sections collapsible and collapsed by
      default where they do not own an active draft.
- [ ] Keep selected slice/module editing contextual to its visual row or clearly
      synchronized inspector.
- [ ] Keep creation distinct from existing-record edits.
- [ ] Keep reference-aware delete dialogs and source bounds validation.
- [ ] Preserve atlas/module local drafts across permitted panel/layout changes.
- [ ] Prevent source/view switching from silently discarding their drafts.

### Accessibility and manual UX

- [ ] Verify all controls have visible labels or tooltips.
- [ ] Verify focus order, Enter/Escape behavior, and screen-reader semantics.
- [ ] Verify long IDs/tags/source paths at supported window widths.
- [ ] Verify empty, filtered-empty, missing-image, deprecated, referenced, and
      rejected-command states manually.
- [ ] Verify scene remains usable at supported narrow and wide desktop sizes.

### Final documentation and validation

- [ ] Update `tools/editor/README.md` with the complete workflow.
- [ ] Update `docs/tdd/editor_ui_system.md` with final reusable UX contracts.
- [ ] Update `docs/tdd/polygon_terrain_authoring_foundation.md` with final
      Prefab/Chunk authoring behavior.
- [ ] Update `tools/editor/AGENTS.md` only if ownership or working rules changed.
- [ ] Update the Chunk Creator high-level plan's active follow-up references.
- [ ] Run `dart analyze` in `tools/editor`.
- [ ] Run all focused Prefab/Chunk/catalog/panel tests.
- [ ] Run the complete `flutter test` suite in `tools/editor`.
- [ ] Run generator dry-run if any authoring/runtime seam changed.
- [ ] Perform a redundancy pass for copied forms, tokenizers, image caches,
      field validation, action rows, and draft-resolution logic.
- [ ] Record manual UX/accessibility acceptance.
- [ ] Mark strategy/checklist implemented and archive only when no required work
      remains.

## Final Acceptance Checklist

- [ ] Both owner metadata editors are inline and row-local.
- [ ] Prefab owner creation and rename are inline.
- [ ] Owner actions are contextual rather than detached.
- [ ] Prefab owners use a searchable visual library with thumbnails and filters.
- [ ] Prefab collision creation/existing/diagnostics are separate sections.
- [ ] Prefab shape metadata and rectangle geometry edit inline.
- [ ] Sidebar sections start collapsed and avoid redundant nesting.
- [ ] Narrow Prefab layout keeps the scene mounted and visible.
- [ ] Selected-owner context is synchronized across header, library, scene, and
      editor.
- [ ] Navigation cannot silently discard any active form or geometry draft.
- [ ] Diagnostics is independent, counted, complete, and focusable.
- [ ] Chunk runtime evidence remains an intentional domain-only feature.
- [ ] Typed command, revision, validation, history, drift, reference, and export
      invariants remain intact.
- [ ] Required tests, analysis, docs, redundancy review, and manual acceptance
      are complete.
