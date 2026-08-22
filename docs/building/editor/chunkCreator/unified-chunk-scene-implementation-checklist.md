# Unified Chunk Scene Implementation Checklist

Date: August 14, 2026
Updated: August 22, 2026
Status: Implementation complete; manual UX/accessibility acceptance remains

Source strategy:
[Unified Chunk Scene Strategy](unified-chunk-scene-strategy.md)

This checklist converts the unified Chunk scene strategy into gated delivery
passes. Checkboxes describe implementation work, not current behavior. Do not
start direct prefab or marker manipulation until the operation-token and stale
snapshot gate has passed.

## Delivery Gate

The initiative is complete when:

- the Chunk route presents one persistent `Chunk creation scene`
- Terrain, Prefabs, Markers, and Layers tabs appear at the top of that scene
- one matching flat group of authoring sections appears in the right sidebar at
  a time, with no redundant domain wrapper card
- wide and narrow layouts keep scene and viewport state mounted across tabs
- per-domain selection survives tab changes, and active operations lock tabs
- all existing owner, collision, composition, evidence, validation, undo/redo,
  pending-diff, and apply behavior remains available
- direct scene operations use explicit domain selection, a full stale-checked
  snapshot, expected owner key/revision, a captured canonical index when an
  existing record is targeted, deterministic hit testing, and exactly one
  accepted command per gesture
- no page-level persistence or shadow command path bypasses the Chunk plugin
- tile-layer UI describes only implemented capability
- required analysis, tests, generator checks, performance evidence, and docs
  are complete

## Delivery Milestones

This plan has two explicit release boundaries:

1. **Workspace consolidation (Phases 0-1 and Phase 8 refinement).** The
   persistent scene, tab-filtered cards, responsive layout, existing dialogs,
   route naming cleanup, and
   metadata-only layer language ship without waiting for direct prefab or
   marker gestures. No legacy composition page remains behind this boundary.
2. **Direct scene authoring (Phases 2-7).** Operation-scoped targeting, typed
   selection, direct prefab/marker manipulation, performance hardening, and
   final documentation close the full initiative.

Passing Milestone 1 does not claim that prefab or marker scene manipulation is
implemented. The strategy and checklist remain active until Milestone 2 is
implemented or explicitly closed.

## Current Snapshot

- [x] One `ChunkV2Document` and `ChunkV2Scene` already contain collision,
      layers, prefab placements, and markers.
- [x] The terrain scene already previews parallax, terrain material, placed
      prefab visuals, expanded prefab collision, compiled edges, and optional
      marker-placement evidence.
- [x] Direct terrain polygons already use a route-local draft controller and
      plugin-owned semantic commit path.
- [x] Layers, prefab placements, and markers already use validated canonical
      composition commands through the Chunk plugin.
- [x] The current composition stale check compares only tile-layer, prefab, and
      marker lists; `ChunkV2CompositionSnapshot` intentionally omits owner
      revision today.
- [x] The current UI separates terrain and composition through
      `_ChunkV2WorkspaceView` and two `ChoiceChip`s.
- [x] `ChunkV2CompositionWorkspace` currently replaces the terrain scene with a
      visual-stack summary and three form panels.
- [x] Prefab and marker instance selection keys are derived from record content
      and coordinates rather than immutable authored identity.
- [x] The derived prefab `placementKey` also participates in Core terrain
      lineage, edge IDs, generated signatures, and parity fixtures.
- [x] The marker evidence painter already draws authored anchors, connections,
      and resolved or rejected placement outcomes.
- [x] `TileLayerDef` currently stores metadata only (`id`, `kind`, `visible`).
- [x] Prefab and marker coordinates are integer source pixels; prefab
      `snapToGrid` is persisted, but the current composition form does not
      apply a shared coordinate-snapping function.
- [x] The planning audit found no off-grid `snapToGrid: true` prefab in
      checked-in JSON under `assets/`, `test/`, or `tools/editor/test/`.
- [x] Unified workspace implementation has started.

## Locked Invariants

- Repository load, validation, pending diff, history, and export remain owned by
  `ChunkDomainPlugin`, the Chunk store, and `EditorSessionController`.
- The page and scene never write source files directly.
- One accepted direct-manipulation gesture creates no more than one owner
  revision, one pending diff, and one undo entry.
- Pointer movement is a local candidate preview; it is not a stream of document
  commands.
- Rejected candidates do not alter the document, revision, history, or pending
  diff.
- Expanded Prefab edits, Marker dialog edits, and direct gestures use the
  existing `ChunkV2CompositionCommit`, extended with expected owner
  key/revision; this initiative adds no parallel document command.
- `Ctrl+drag` pans and `Ctrl+scroll` zooms in every scene domain.
- Only one source-editing domain owns primary input at a time.
- Evidence overlays are read-only and cannot silently mutate source selection.
- Selection after a document replacement is retained only when its current
  derived key resolves; otherwise clearing it is the correct behavior.
- Owner switch, reload, apply, and route switch cannot discard an active
  operation.
- Prefab collision remains prefab-owned and read-only in the Chunk scene.
- Chunk-v2 source shape, generated runtime output, and Core placement lineage
  remain unchanged by this initiative.
- Tile painting remains unavailable until a complete source and consumer
  contract exists.
- Prefab scene and inspector edits share one pure coordinate-policy module:
  `snapToGrid: true` gestures use the selected chunk's `tileSize`; false uses
  integer pixels. Exact prefab fields remain an intentional integer-pixel
  override and are not rounded. Marker anchors use integer pixels. Gesture ties
  round away from zero.
- Existing sources are never silently normalized on load to satisfy the new
  interaction policy.

## Phase 0 — Freeze Contracts And Characterize The Baseline

Objective: remove design ambiguity before reorganizing a stateful workspace.

### Repository and behavior inventory

- [x] Re-read `AGENTS.md`, `tools/editor/AGENTS.md`, and
      `docs/rules/code-documentation-policy.md` before implementation.
- [x] Confirm the live behavior and ownership in:
  - [x] `tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_polygon_workspace.dart`
  - [x] `tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_v2_composition_workspace.dart`
  - [x] `tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_polygon_scene_surface.dart`
  - [x] `tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_polygon_authoring_controller.dart`
  - [x] `tools/editor/lib/src/chunks/chunk_v2_composition_commit.dart`
  - [x] `tools/editor/lib/src/chunks/chunk_domain_plugin.dart`
- [x] Inventory every action currently reachable in both workspace views so the
      layout migration cannot drop a control.
- [x] Characterize the existing active-operation guards for owner switch,
      reload, apply, undo/redo, and route switch.
- [x] Record a wide and narrow widget-test baseline for scene, owner panel,
      shapes, seams, diagnostics, visual stack, layers, prefabs, and markers.
- [x] Capture the current scene interaction performance fixture result before
      adding more projections or listeners.

### UX decisions

- [x] Freeze the visible scene title as `Chunk creation scene` and the semantic
      label as a chunk-authoring surface rather than a collision-only editor.
- [x] Freeze the wide layout: primary scene plus one bounded right sidebar.
- [x] Freeze the narrow layout as a bounded scene followed by the same sidebar
      below it, with neither subtree unmounted.
- [x] Mount the active scene tab's natural-height section primitives directly in
      the sidebar, without a redundant top-level `EditorPanelCard`; the scene
      retains its own panel shell.
- [x] Keep the header owner selector and owner-card list synchronized through
      the route's one selected chunk key.
- [x] Start every owner, tab-specific, visual-stack, and Diagnostics section
      collapsed and keep expansion state presentation-only with stable keys and
      out of document state.
- [x] Separate global scene controls from contextual domain tools.
- [x] Freeze terrain as the initial source-editing domain when a chunk owner
      binds.
- [x] Freeze card/section expansion as presentation-only; it cannot change
      domain, selection, history, or pending changes.
- [x] Freeze tile-layer metadata as sidebar-only with no canvas input domain.
- [x] Define behavior when the selected owner is deleted and no fallback owner
      remains: bind the first canonical remaining owner, or clear owner-scoped
      state and preserve the existing no-template empty state when none remain.

### Operation identity decision

- [x] Record that the existing prefab/marker selection key is projection-local
      and changes when record values change.
- [x] Record that Core's existing derived `placementKey` is runtime lineage used
      by terrain edge IDs, signatures, and parity fixtures; do not repurpose it
      for UI persistence.
- [x] Freeze the gesture token as owner key, expected owner revision, complete
      `ChunkV2CompositionSnapshot`, target list, operation kind, and, for an
      existing record, canonical source index plus current presentation key.
- [x] Freeze append, replacement-at-index, or removal-at-index followed by the
      existing canonical sorting as the accepted candidate construction; add
      operations have no target index.
- [x] Freeze selection recomputation after acceptance: add/move/edit chooses the
      unique full-equality match or defensively clears selection, delete clears
      source selection, undo/redo/same-owner reload retains only an exactly
      resolving prior presentation key, and owner switch always clears
      owner-scoped selection.
- [x] Record that comparator-equal duplicate records are rejected by strict
      canonical structure; the valid ambiguity to test is colocated records
      with the same selection-key base but different canonical fields.
- [x] Do not add authored instance keys or a new Chunk schema for this workflow.
- [x] Do not begin Phases 3-5 until stale, same-location, and exact-duplicate
      rejection cases pass through the operation-token contract.

### Coordinate policy decision

- [x] Scan every current Chunk-v2 source and relevant fixture for
      `snapToGrid: true` prefab anchors that are not multiples of that chunk's
      positive `tileSize`.
- [x] Freeze one pure coordinate-policy helper used by scene gestures and
      prefab form edits: gestures snap to tile size when enabled and nearest
      integer pixels when disabled, with exact ties away from zero; exact fields
      preserve the entered integer as an explicit override.
- [x] Record that `snapToGrid` remains an interaction preference in this
      initiative, not a new codec/generator validity rule; never normalize
      existing data during decode, load, or layout migration.
- [x] Freeze marker dragging to nearest integer source pixels with exact ties
      away from zero; do not reuse the terrain half-pixel selector.
- [x] Keep the existing complete-document plugin validation authoritative for
      bounds and placement acceptance.

### Tile-layer boundary

- [x] Record that the current layer UI is metadata-only.
- [x] Keep spatial tile content and painting out of this initiative.
- [x] Record the trigger for a separate plan: an approved tile-content source
      contract and a concrete runtime/render consumer.
- [x] Prohibit paint, erase, tile-selection, and spatial layer affordances in
      this workspace workstream.

### Architecture record

- [x] Update `docs/tdd/editor_ui_system.md` with the accepted workspace topology
      and scroll ownership before Phase 1 closes.
- [x] Update or add the focused Chunk authoring TDD with the accepted domain,
      selection, operation-token, stale-rejection, and command rules before direct
      manipulation begins.
- [x] Reflect any accepted scope change in `docs/building/editor/chunkCreator/plan.md`.

### Phase 0 tests

- [x] Run `cd tools/editor && dart analyze`.
- [x] Run `cd tools/editor && flutter test test/chunk_authoring_workspace_test.dart`.
- [x] Run `cd tools/editor && flutter test test/chunk_polygon_authoring_controller_test.dart`.
- [x] Run `cd tools/editor && flutter test test/polygon_interaction_benchmark_fixture_test.dart`.

Phase 0 gate: layout, responsive behavior, active-domain semantics,
operation-scoped identity, stale rejection, selection invalidation, and the
metadata-only tile boundary are explicit. Characterization tests cover every
behavior that the layout phase will move.

## Phase 1 — Build The Persistent Scene And Right Sidebar

Objective: remove the workspace split without changing source contracts or
adding direct non-terrain manipulation.

### Modularize existing composition UI

- [x] Refactor `ChunkV2CompositionWorkspace` into focused presentational
      sections that can be composed in a sidebar.
- [x] Remove the standalone `ChunkV2CompositionWorkspace` root and its file in
      this phase after the retained sections move; do not keep a legacy page or
      compatibility wrapper.
- [x] Keep tile-layer, prefab, and marker actions on the existing typed
      composition commit path.
- [x] Keep tile-layer and Marker edit dialogs operational; Prefab and Marker
      creation forms live inline, and existing Prefab placement editing expands
      its selected row.
- [x] Move the visual-stack preview into the composition card as a compact
      section.
- [x] Avoid copying layer, prefab, marker, equality, sorting, or dispatch logic
      into the renamed route workspace.
- [x] Preserve current deterministic list ordering and stable widget keys where
      they still describe stable concepts.

### Replace the workspace switch

- [x] Rename `ChunkPolygonWorkspace` and its file to
      `ChunkAuthoringWorkspace`, including the `ChunkCreatorPage` global key and
      widget test file; keep no compatibility alias.
- [x] Remove `_ChunkV2WorkspaceView`.
- [x] Remove `chunk_v2_view_terrain` and `chunk_v2_view_composition` choice
      chips.
- [x] Remove `_selectWorkspaceView` and its view-switch-only operation guard.
- [x] Keep one scene mounted for the lifetime of the selected current-schema
      chunk workspace.
- [x] Rename the panel title from `Terrain collision scene` to
      `Chunk creation scene`.
- [x] Rename the route badge from `Chunk v2 polygon authoring` to
      `Chunk v2 authoring`.
- [x] Update the scene semantic label to describe chunk authoring.
- [x] Preserve scene viewport, focus, overlay toggles, and terrain draft state
      while cards expand, collapse, or scroll.

### Compose the right sidebar

- [x] Build one bounded sidebar with one vertical scroll owner.
- [x] Add the `Chunk owners` rail and `Terrain` authoring card.
- [x] Move owner list/lifecycle actions into that card without changing their
      command ownership.
- [x] Bind the header owner selector and owner-card selected row to the same
      route-local selected chunk key.
- [x] Add a fit-to-chunk visual preview to every owner row using the scene's
      normal visual projections.
- [x] Keep terrain creation and existing shapes as compact sections, while
      removing collision/seam/source-fill/marker count summaries from the
      scene.
- [x] Add dedicated `Prefabs`, `Markers`, and `Layers` authoring cards.
- [x] Put visual stack and layer metadata in Layers, prefab placements in
      Prefabs, and enemy markers in Markers.
- [x] Label the layer section as metadata management and expose no paint,
      erase, tile selection, cell grid, or other spatial-layer affordance.
- [x] Mount exactly one tab-specific sidebar `EditorPanelCard` followed by one
      shared, all-issues Diagnostics card; use `EditorSectionCard` or
      equivalent natural-height expansion sections for internal groups.
- [x] Remove the redundant scene-level `Place vertex` chip while retaining
      initial and resumed polygon placement through the terrain creation card.
- [x] Give cards and collapsible sections stable semantics and expansion keys.
- [x] Ensure nested cards do not introduce competing vertical scroll views.
- [x] Keep active-operation guards visible and actionable when controls are
      disabled.
- [x] While a terrain draft/gesture is active, disable every composition and
      owner mutation while leaving card expansion, viewport, and evidence
      controls usable.

### Responsive and accessibility work

- [x] Use a measured wide breakpoint and a bounded sidebar width.
- [x] Verify the scene receives usable minimum width and height at the target
      desktop size.
- [x] Implement the narrow scene-then-sidebar stack without unmounting either
      subtree.
- [x] Give the bounded scene an explicit responsive height and the sidebar the
      remaining height; keep the eager sidebar scroll view as the only vertical
      scroll owner.
- [x] Preserve logical keyboard traversal from header to scene to sidebar.
- [x] Verify screen-reader labels distinguish the scene, all authoring tabs,
      source selections, and read-only evidence.
- [x] Ensure opening a dialog from the sidebar restores focus coherently.

### Phase 1 tests

- [x] Prove the scene remains mounted and retains viewport state while all four
      tab-specific cards are used.
- [x] Re-run existing owner create/duplicate/rename/delete coverage.
- [x] Re-run existing terrain shape, seam, diagnostics, compiled-edge, and
      marker-evidence coverage.
- [x] Re-run existing layer, prefab, and marker add/edit/delete coverage.
- [x] Add a coexistence regression proving composition/owner mutations cannot
      interleave with an active terrain operation.
- [x] Add wide-layout assertions for scene/sidebar placement.
- [x] Assert owner previews, removed scene summaries/tool, and identical
      document diagnostics beneath all four tab cards.
- [x] Add narrow-layout assertions proving the old workspace tabs do not return.
- [x] Assert the removed workspace classes, enum, widget keys, and old root test
      name have no live references.
- [x] Add overflow coverage at representative minimum sizes and text scaling.

### Milestone 1 documentation

- [x] Update `tools/editor/README.md` for the persistent scene, two-card
      sidebar, responsive behavior, and retained dialog workflow; do not claim
      direct prefab or marker scene manipulation yet.
- [x] Update `docs/tdd/editor_ui_system.md` from the old multi-card/split-view
      adoption text to the delivered scene/sidebar topology.
- [x] Update `docs/tdd/polygon_terrain_authoring_foundation.md` for the renamed
      route workspace and persistent layout, while recording that the
      terrain-only scene surface remains until Phase 3.
- [x] Mark the layout milestone complete in
      `docs/building/editor/chunkCreator/plan.md` when its gate passes.

Phase 1 gate: the old view selector and separate composition page are gone. All
existing authoring actions remain reachable while the scene stays mounted. No
source schema, generated output, or runtime behavior changes. This gate is an
independently shippable completion point for the requested layout.

## Phase 2 — Build The Composition Gesture Adapter

Objective: make coordinate-changing scene edits safe by strengthening and
reusing the current Chunk-v2 optimistic composition contract.

### Adapter contract

- [x] Extract one route-local adapter used by both existing dialogs and future
      prefab/marker gestures to construct `ChunkV2CompositionCommit`.
- [x] Extend `ChunkV2CompositionCommit` with expected owner key and revision; do
      not add another command kind or source field.
- [x] Make `ChunkV2CompositionCommitPolicy` reject owner-key or revision
      mismatch before structure and full-document validation, while retaining
      its existing composition-snapshot stale check.
- [x] Preserve `chunk_v2_composition_commit_stale` as the diagnostic family for
      owner, revision, and composition mismatch, with one actionable retry
      message/path.
- [x] Capture owner key, expected owner revision, the full current
      `ChunkV2CompositionSnapshot`, target list, operation kind, and, when
      targeting an existing record, canonical source index plus presentation
      selection key when an operation begins.
- [x] Append, replace, or remove in the captured list according to the operation
      kind and run the existing deterministic comparator before dispatch.
- [x] Promote the needed prefab/marker semantic equality and canonical-list
      construction out of private widget/policy helpers into one focused domain
      seam shared by dialogs, the gesture adapter, and commit policy; leave no
      duplicated comparator/equality implementation.
- [x] Detect a candidate equal to `before` inside the adapter, close the local
      operation without dispatch, and do not show the generic rejection path.
- [x] Keep pointer-move preview state outside `EditorSessionController`.
- [x] Treat an open composition dialog as a route-local operation until it
      cancels or submits. Keep the expanded Prefab placement form non-blocking,
      discard its un-applied draft on domain/owner/source-revision change, and
      retain captured-revision validation on Apply.
- [x] Dispatch through
      `ChunkDomainPlugin.commitChunkCompositionCommandKind`; add no new document
      command or page-level validation path.
- [x] Extend the route-level active-operation guard so owner switch, reload,
      apply, route switch, and domain switch cannot discard a composition
      gesture.
- [x] On stale rejection, cancel the preview, project the current document, and
      show the existing actionable rejection path without history or revision.
- [x] After accepted add/move/edit, recompute the derived key from the accepted
      canonical list only when there is exactly one full-equality match; after
      accepted delete, clear source selection.
- [x] After undo, redo, or same-owner reload, retain selection only if the
      current derived key resolves; otherwise clear it. Always clear
      owner-scoped selection on owner switch.
- [x] Preserve strict rejection of comparator-equal duplicates; do not add
      persistent identity solely for colocated records that the canonical index
      already distinguishes during one operation.
- [x] Leave `PlacedPrefabDef`, `PlacedMarkerDef`, Chunk-v2 JSON, generated
      runtime data, and Core `placementKey` lineage unchanged.

### Phase 2 tests

- [x] Add focused adapter tests for prefab and marker replacement at a captured
      canonical index.
- [x] Add focused adapter tests for add-without-index and delete-at-index for
      both lists.
- [x] Add stale-snapshot rejection after an intervening composition command.
- [x] Add dialog-open guard tests for owner switch, reload, apply, session undo,
      and route switch.
- [x] Add a command-payload/commit owner-key mismatch test proving an owner with
      equal composition cannot be edited accidentally.
- [x] Add expected-revision rejection after intervening terrain, metadata, and
      lifecycle revisions whose composition lists are unchanged.
- [x] Assert revision-stale rejection does not change document, history,
      pending diff, or revision.
- [x] Add colocated same-key-base record move/delete tests and exact-duplicate
      candidate rejection tests.
- [x] Add accepted-move selection recomputation tests.
- [x] Add unique full-equality selection, defensive non-unique clearing, and
      delete-clears-selection tests.
- [x] Add undo/redo/reload selection-clearing tests when a derived key no longer
      resolves.
- [x] Assert pointer preview creates no session document, revision, history, or
      pending-diff change.
- [x] Assert acceptance produces one revision and one undo entry.
- [x] Assert a zero-distance or otherwise semantic no-op gesture creates no
      command dispatch, rejection message, revision, history entry, or
      pending-diff change.
- [ ] Run `dart run tool/generate_chunk_runtime_data.dart --dry-run` and verify
      no source or generated runtime diff.

Phase 2 gate: one current canonical record can be targeted safely, intervening
composition or owner-identity/revision changes fail stale, invalidated
selection is cleared rather than guessed, the strengthened composition command
remains the only write path, and Chunk-v2/runtime identity is unchanged.

## Phase 3 — Add Unified Domain And Typed Selection Coordination

Objective: make the shared scene and cards agree about what is active without
adding new source mutations yet.

### Coordinator and domain state

- [x] Introduce a focused route-local active-domain model for terrain, prefab,
      and marker source editing, with compiled-edge inspection modeled as an
      explicit read-only mode.
- [x] Introduce typed selection instead of unrelated terrain, marker-evidence,
      and future prefab selection fields.
- [x] Keep viewport and overlay visibility route-local and mutation-free.
- [x] Keep the existing polygon controller as the terrain gesture authority.
- [x] Aggregate terrain, prefab, and marker active-operation state through the
      route's `EditorPageLocalDraftState`, undo, and redo handlers so reload and
      session shortcuts cannot bypass a non-terrain gesture.
- [x] Recompute selection after an accepted command; reconcile by exact key
      after undo, redo, or same-owner reload; clear on rejection/deletion when
      unresolved; and always clear owner-scoped selection on owner switch.
- [x] Block domain and owner changes that would discard an active operation.
- [x] Keep card/section expansion and layer-metadata actions from implicitly
      changing the canvas domain.
- [x] While a local operation exists, block session history: route undo to the
      domain's local undo/cancel contract and expose redo only when that domain
      has local redo. Delegate to session history only with no active operation.
- [x] Do not turn the coordinator into a second document or validation model.

### Scene input routing

- [x] Promote `ChunkPolygonSceneSurface` to one chunk-specific scene surface
      named `ChunkSceneSurface` that routes primary input to the explicit active
      domain; remove the old terrain-only surface and compatibility alias in the
      same phase after parity coverage passes.
- [x] Preserve `SceneInputUtils` as the shared pan/zoom authority.
- [x] Keep terrain vertex/edge hit testing unchanged while terrain is active.
- [x] Extract deterministic world-space prefab bounds from
      `ChunkPolygonVisualProjection`, rename the full-scene projection to
      `ChunkSceneVisualProjection` in `chunk_scene_visual_source.dart`, rename
      the other full-scene `ChunkPolygon*` visual types and their test file, and
      make painter plus hit tester consume the same anchor/scale/flip projection
      without a compatibility alias.
- [x] Retain canonical source index in each projected prefab; paint by visual
      canonical comparator (including z-index), then source index, and hit-test
      the exact projected sequence in reverse.
- [x] Add deterministic marker-anchor hit testing in reverse canonical source
      order, independent of resolved Core placement evidence.
- [x] Ensure compiled-edge inspection remains read-only and explicitly active.
- [x] Define and implement domain-aware `Escape`, `Enter`, `Delete`, and
      `Backspace` behavior.
- [x] Do not intercept text-field or open-dialog keyboard events with scene
      delete/complete shortcuts.

### Bidirectional selection and overlays

- [x] Build one per-document selection projection for each composition family;
      sidebar rows, overlays, and hit testers reuse its canonical source index,
      derived presentation key, and source record rather than sorting
      independently.
- [x] Selecting a list record updates the scene selection overlay.
- [x] Selecting a scene element updates the matching card selection.
- [x] Draw prefab selection bounds without changing saved visual z-order.
- [x] Reuse `ChunkMarkerPlacementOverlayPainter` for its already-distinct source
      anchors and resolved placement evidence; add hit testing without creating
      a second marker overlay.
- [x] Keep marker anchors visible whenever the marker domain is active, while a
      separate view toggle controls resolved body/support evidence.
- [x] Preserve terrain source selection separately from read-only expanded
      prefab collision and compiled-edge evidence.
- [x] Keep selection changes free of revision, history, and pending-diff writes.

### Phase 3 tests

- [x] Add active-domain transition tests, including blocked transitions.
- [ ] Add tests proving card expansion and layer-metadata actions do not change
      canvas domain or source selection.
- [x] Add overlapping-prefab deterministic hit-test tests.
- [x] Add same-location/overlapping-marker deterministic hit-test tests.
- [x] Assert prefab hit-test order is exactly the reverse of paint order,
      including equal-comparator source-index ties.
- [x] Add list-to-scene and scene-to-list selection tests.
- [x] Add selection reconciliation/clearing tests for owner changes and source
      replacement.
- [x] Add keyboard routing tests for terrain and non-terrain domains.
- [x] Add focused text-entry/dialog tests proving scene shortcuts do not consume
      editing keys.
- [ ] Add undo/redo precedence tests for local terrain, prefab, and marker
      operations followed by session history.
- [x] Re-run `tools/editor/test/polygon_interaction_benchmark_fixture_test.dart`
      and the shared-control cases in the Chunk workspace tests.
- [x] Re-run terrain polygon controller and workspace tests unchanged where
      behavior is intentionally preserved.
- [x] Update the focused Chunk/Terrain TDD names and input-routing contract in
      the same change that replaces the terrain-only scene surface.

Phase 3 gate: the active domain makes primary input unambiguous; list and scene
selection are synchronized and deterministic within the current projection;
invalidated selection is cleared, and selection alone never mutates the
document.

## Phase 4 — Add Direct Prefab Placement Authoring

Objective: create, select, and move prefab placements spatially while preserving
the plugin-owned command and validation path.

### Prefab tools and draft state

- [x] Add explicit prefab select/place/move tools as accepted in Phase 0.
- [x] Start placement from a valid active prefab catalog selection.
- [x] Preserve the current new-placement defaults unless the author changes
      them before placement: z-index `0`, snap enabled, default scale, and no
      flips.
- [x] Render a local placement ghost before commit.
- [x] Capture the Phase 2 composition snapshot, canonical source index, and
      presentation key on pointer-down when moving an existing placement; both
      move and add also capture owner key and expected revision, while a new
      placement has no target index.
- [x] Apply the Phase 0 coordinate helper: snap the authored anchor to
      `chunk.tileSize` when `snapToGrid` is true and to integer source pixels
      otherwise, with ties away from zero.
- [x] Keep bounds, scale, flip, anchor, and complete-candidate acceptance on the
      existing projection and Chunk plugin validation path.
- [x] Keep pointer-move updates local to the gesture draft.
- [x] Cancel cleanly on `Escape`, pointer cancellation, or stale rejection.
- [x] Block owner switch, reload, apply, and route-switch attempts without
      discarding the active preview; require an explicit commit or cancel.

### Commit and projection parity

- [x] Build one existing `ChunkV2CompositionCommit` on pointer-up.
- [x] Validate the complete candidate through the Chunk plugin.
- [x] Increment revision/history/pending diff exactly once on acceptance.
- [x] Restore the current document projection and clear invalid selection on
      rejection.
- [x] Refresh placed visuals and expanded prefab collision from the same
      accepted candidate.
- [x] Keep existing dialog/inspector edits on the same canonical result.
- [x] Make exact coordinate entry use the shared policy's validation branch;
      preserve explicit integer pixels without silent rounding. Preserve
      z-index, scale, flips, and the `snapToGrid` control, which affects the next
      direct gesture.
- [x] Use the Phase 3 z-index/canonical-order hit-test rule when visuals overlap.

### Phase 4 tests

- [x] Add place-preview-cancel and place-preview-accept tests.
- [x] Add move-preview-cancel and move-preview-accept tests.
- [x] Assert no session command occurs during pointer movement.
- [x] Assert one accepted drag creates one revision and one undo entry.
- [x] Add rejection tests for bounds, missing prefab, stale snapshot, and invalid
      transform.
- [x] Add scale/flip/anchor projection parity tests.
- [x] Add tile-size-snap, integer-pixel, negative half-tie, and positive
      half-tie gesture tests, plus exact off-grid inspector override coverage.
- [x] Add a regression proving load/layout migration never rewrites existing
      placement coordinates.
- [x] Add expanded-collision refresh tests.
- [ ] Add dialog versus scene canonical-output parity tests.
- [x] Extend the realistic scene performance fixture with representative prefab
      placement counts.

Phase 4 gate: prefab placement through the scene and through existing forms
produces identical deterministic source, validation, projection, history, and
pending-diff behavior.

## Phase 5 — Add Direct Marker Authoring

Objective: edit marker source anchors spatially without confusing them with
Core-resolved spawn locations.

### Marker presentation and tools

- [x] Reuse the existing marker projection and overlay for every authored anchor
      and its placement mode.
- [x] Preserve the existing visually distinct resolved placement evidence and
      anchor-to-outcome connection.
- [x] Paint the runtime idle sprite behind accepted resolved placement
      evidence using the Core frame, anchor, and render scale; show rejected
      attempts and body-less outcomes as muted attempted-body or authored-anchor
      references beneath their diagnostic evidence.
- [x] Use the projection's current derived selection key only within the current
      document projection.
- [x] Add explicit marker select/place/move tools.
- [x] Start marker placement with deterministic defaults for marker ID, chance,
      salt, and placement mode.
- [x] Preserve the current dialog defaults for a new marker: first canonical
      supported enemy ID, `100` percent chance, salt `0`, and ground placement,
      unless the author changes them before placement.
- [x] Keep chance, salt, marker ID, placement mode, and exact coordinates
      editable through a typed inspector/dialog.
- [x] Drag only the authored source anchor; never write the resolved evidence
      coordinate back into source.
- [x] Quantize a dragged anchor to nearest integer source pixels with exact ties
      away from zero; do not expose the prefab or terrain snap policies here.
- [x] During add/move preview, draw the candidate anchor and suppress the
      targeted marker's old connection and resolved body/support evidence;
      never combine candidate source with accepted evidence.

### Commit and validation

- [x] Keep pointer movement in route-local preview state.
- [x] Dispatch one existing `ChunkV2CompositionCommit` on accepted placement or
      movement.
- [x] Refresh Core marker-placement projection after acceptance.
- [x] If live resolved-evidence preview is retained, compute it from the same
      local candidate and keep it out of session state; otherwise restore
      accepted evidence only after commit or rejection.
- [x] Preserve disabled, malformed, unsupported, and no-support outcomes as
      visible diagnostics.
- [x] Recompute marker selection after acceptance and clear it after rejection,
      undo, redo, or reload when its derived key no longer resolves.
- [x] Preserve deterministic marker ordering and the existing generator
      contract; the final dry-run remains a Phase 7 gate.

### Phase 5 tests

- [x] Extend existing authored-anchor versus resolved-outcome rendering tests.
- [x] Cover runtime-scale/anchor sprite geometry, decoded image loading, and
      accepted-versus-deferred sprite eligibility.
- [x] Add ground, highest-surface, and obstacle-top move tests.
- [x] Add integer-pixel and positive/negative half-tie marker drag tests.
- [x] Assert drag commits authored coordinates rather than projected spawn
      coordinates.
- [x] Assert a moving candidate anchor is never connected to evidence from its
      pre-drag coordinate.
- [x] Add unsupported/no-support diagnostic tests.
- [x] Add exactly-once revision/history/pending-diff tests.
- [ ] Add generator parity tests for scene-edited marker source.
- [x] Extend the performance fixture with representative marker counts and
      placement evidence enabled.

Phase 5 gate: marker placement is spatially authorable, source and evidence are
never conflated, scene/form edits remain deterministic and undoable, and
invalidated selection is cleared rather than guessed.

## Phase 6 — Close The Tile-Layer Boundary

Objective: keep the Layers card honest about the layer capability that exists
today and prevent this workspace change from becoming an unplanned map editor.

- [x] Re-audit the Phase 1 section and help text after the direct-interaction
      work; it must still say tile-layer metadata management.
- [x] Verify only the current `id`, `kind`, and `visible` add/edit/delete flow
      remains.
- [x] Verify no paint, erase, tile selection, cell grid, or spatial layer
      affordance was introduced.
- [x] Add a widget assertion that no unsupported tile-painting control is
      present.
- [x] Record in the Chunk roadmap that tile content needs its own strategy after
      an authored representation and concrete runtime/render consumer are
      approved.

Phase 6 gate: layer metadata remains usable, the Chunk scene makes no spatial
tile-authoring promise, and no source/runtime contract changed.

## Phase 7 — Hardening, Redundancy Pass, And Closure

Objective: remove transitional structure and prove the unified workflow as one
coherent production authoring surface.

### Cleanup

- [x] Verify the workspace-view enum, old chip keys, legacy root classes, and
      replaced tests remain absent after the later interaction phases.
- [x] Remove shadowed selection fields and duplicate domain-routing branches.
- [x] Confirm dialogs and direct gestures share one composition-commit adapter
      and no persistent UI-only identity was added to source.
- [x] Consolidate repeated list actions, deterministic comparators, and command
      construction without creating speculative generic abstractions.
- [x] Confirm card widgets are presentation-only and do not retain stale copies
      of the Chunk document.
- [x] Confirm the route coordinator does not duplicate plugin validation or
      persistence.
- [x] Review all touched public APIs and reasoning-hotspot comments against the
      documentation policy.

### UX and performance verification

- [ ] Complete a manual non-developer workflow:
  - [ ] select or create a chunk owner
  - [ ] author and inspect terrain collision
  - [ ] add/edit layer metadata
  - [ ] add/select/move/edit a prefab placement
  - [ ] add/select/move/edit an enemy marker
  - [ ] inspect seams, compiled edges, and marker evidence
  - [ ] undo/redo across domains
  - [ ] preview and apply the source change
- [x] Verify wide and narrow layouts at supported text scale.
- [ ] Verify keyboard-only reachability for scene, cards, lists, dialogs, and
      destructive actions.
- [x] Compare scene gesture performance against the Phase 0 baseline. The
      Windows profile fixture includes 43 prefabs and 24 marker outcomes;
      vertex/shape update p95 is `239/242 us`, build p99 is `1.866/1.854 ms`,
      and no input, build, or raster budget is missed.
- [x] Investigate unexpected rebuilds or image reloads before accepting a
      regression.

### Documentation closure

- [x] Update `tools/editor/README.md` with the unified Chunk scene workflow and
      controls.
- [x] Update `docs/tdd/editor_ui_system.md` with final topology and responsive
      behavior.
- [x] Update `docs/tdd/polygon_terrain_authoring_foundation.md` for the scene,
      selection, operation-token, or evidence contracts changed.
- [x] Confirm `tools/editor/AGENTS.md` needs no change because command,
      validation, and persistence ownership did not move.
- [x] Update `docs/building/editor/chunkCreator/plan.md` status and next slice.
- [x] Record that Chunk-v2 source shape, generated output, and Core placement
      lineage remained unchanged.
- [ ] Move this strategy and checklist to
      `docs/building/archived/editor/chunkCreator/` only when all accepted scope
      is implemented or explicitly closed.

Phase 7 gate: no old workspace switch, dead composition page, duplicated write
path, stale contract documentation, unresolved accessibility issue, or accepted
performance regression remains.

## Phase 8 — Tab-Filtered Authoring Cards

- [x] Move the active-domain selector to a persistent tab strip at the top of
      `Chunk creation scene`.
- [x] Add the passive Layers domain beside Terrain, Prefabs, and Markers.
- [x] Mount only the matching flat Terrain, Prefabs, Markers, or Layers section
      group in the right sidebar, without a domain wrapper card.
- [x] Keep the scene, viewport, tool state, and per-domain selection across tab
      changes.
- [x] Disable tab changes during a draft, gesture, or retained dialog.
- [x] Keep Layers metadata-only and ignore primary scene authoring input while
      it is active.
- [x] Cover four-tab order, sidebar filtering, selection retention, passive
      Layers input, and wide/narrow layout behavior.
- [x] Update the editor README, TDDs, and active Chunk planning documents.

## Phase 9 — Whole-Pixel Direct Terrain

- [x] Remove the direct Chunk terrain `1 px` / `0.5 px` selector and hardcode
      pointer snapping to whole pixels.
- [x] Apply the same whole-pixel step to exact vertex and rectangle fields.
- [x] Reject odd half-pixel ticks at the Chunk semantic-validation, file-codec,
      and staged-generator boundaries without adding migration behavior.
- [x] Normalize the only direct Chunk half-pixel compiler fixture and refresh
      its exact edge and signature expectations.
- [x] Keep Prefab-local half-pixel source and authoring behavior unchanged.

## Phase 10 — Retire Standalone Actor-Terrain Inspection

- [x] Remove the Actor terrain chip, actor selector, summary, and scene overlay.
- [x] Delete the actor-terrain overlay painter and its route-level references.
- [x] Build the existing Core terrain-policy projection only as an internal
      dependency when marker-placement evidence is requested.
- [x] Keep marker-placement evidence and authored marker behavior unchanged.

## Phase 10 Follow-up — Restore Actor-Terrain Inspection

- [x] Restore the default-off **Actor terrain** chip beside **Marker placement**.
- [x] Restore the actor selector, Éloïse default, summary, and Core-evidence
      overlay without adding source mutation or gameplay authority.
- [x] Reuse one cached `ChunkV2ActorTerrainProjection` for actor inspection and
      marker placement.
- [x] Suppress the overlay and controls in **Visual preview** while preserving
      the route-local selection.
- [x] Restore route-level regression coverage and current README/TDD guidance.

## Phase 11 — Shape-Edge And Visual Preview Controls

- [x] Add a default-off **Shape edges** chip to the persistent scene controls.
- [x] Hide only the Core-compiled pink/yellow edge painter when disabled.
- [x] Keep terrain materials, source selection, editing, collision authority,
      history, and pending source unchanged.
- [x] Cover default, hidden, and restored overlay states in the Chunk route.
- [x] Add **Visual preview** as a distinct mode that hides every editor-only
      canvas overlay plus the Chunk bounds and viewport border.
- [x] Retain only parallax, terrain-material art, and placed Prefab visuals;
      keep preview canvas input view-only while preserving pan and zoom.
- [x] Disable sidebar authoring during Visual preview without discarding route
      state, selection, pending changes, or overlay preferences.
- [x] Keep the complete global visual/viewport control group above the
      Terrain/Prefabs/Markers/Layers selector at every responsive width.

## Phase 12 — Chunk Tile Grid And Terrain Snap

- [x] Add a default-off **Show grid** chip directly after **Visual preview**.
- [x] Render the selected owner's tile-size grid across every domain tab,
      clipped to Chunk bounds and suppressed by Visual preview.
- [x] Add independent default-off **Snap to grid** switches inside **Create
      terrain shape** and the expanded existing-shape editor without restoring
      the removed half-pixel selector or adding it to the scene header; changing
      one setting must not change the other.
- [x] Quantize polygon and rectangle creation, inserted/moved vertices, and
      exact vertex/rectangle edits to the nearest tile-grid intersections.
- [x] Preserve mandatory whole-pixel authoring while tile snap is disabled and
      lock snap-policy changes during active operations.
- [x] Cover toggle defaults/persistence/preview suppression plus creation,
      rectangle, and committed-vertex quantization.

## Phase 13 — Searchable Visual Prefab Library

- [x] Replace the scene-toolbar and creation-form Prefab dropdowns with one
      persistent visual library in the Prefabs sidebar.
- [x] Search token-by-token across Prefab ID, stable key, kind, and tags; add
      kind and current-Chunk usage filters plus Enter-to-select.
- [x] Render atlas-slice and platform-module thumbnails through one
      browser-owned, workspace-path-scoped decoded-image cache and a bounded
      lazy grid.
- [x] Share the stable-key catalog selection between direct scene placement and
      inline creation without creating source history or pending diffs.
- [x] Expand the selected retained placement row with the same browser and keep
      its tentative owner and transform drafts isolated until Apply.
- [x] Use terrain-style select-to-reveal UX for retained placements: list or
      scene selection reveals a sibling editor, unselected rows omit Edit/Delete
      icons, and labeled Open/Delete actions live in the selected editor.
- [x] Keep that expanded form non-blocking, close it by row re-selection or
      Cancel, make Delete immediately undoable without a modal, and disable scene
      tools consistently only for genuine active operations.
- [x] Cover filtering, empty results, keyboard selection, route integration,
      and exact ID/key submission with focused widget tests.
- [x] Keep Chunk-v2 source, canonical ordering, composition validation, and
      runtime-generation contracts unchanged.

## Phase 14 — Whole-Pixel Prefab Surface Contact

- [x] Keep every authored Prefab placement origin on the existing integer-pixel
      contract; do not add fractional placement coordinates or schema fields.
- [x] Derive the post-reflection/scale lowest horizontal Prefab collision edge
      through the authoritative Core transform and one physics-grid
      quantization.
- [x] Offer only scales whose derived support height can meet a whole-pixel
      terrain line, while retaining and explaining an incompatible saved value
      instead of silently rewriting existing source.
- [x] Add a default-on route-local **Surface snap** policy after normal
      tile/pixel quantization, with an eight-screen-pixel reach and unchanged X.
- [x] Target only exposed upward-facing direct-terrain horizontal edges and
      require a positive-length shared interval rather than point-only contact.
- [x] Exclude the moved placement by captured placement key, then reject every
      proposal that leaves Chunk bounds or overlaps direct/other placed
      collision in positive area.
- [x] Draw the exact transformed candidate collision orange, or green after
      accepted terrain contact, without adding a preview write path.
- [x] Preserve the final Core compiler rule: shared boundary is legal and
      positive-area overlap remains blocking.
- [x] Cover compatible half-pixel/scaled support, unsupported colliders,
      blocker rejection, direct gesture commit, edit-form legacy retention,
      and final compiler parity.
- [x] Update README, TDD, active strategy, and high-level Chunk plan without
      changing Prefab-v3, Chunk-v2, or generated runtime contracts.

## Required Validation Commands

Minimum editor validation for every implementation phase:

- [x] `cd tools/editor && dart analyze`
- [x] focused tests for the touched phase
- [x] `cd tools/editor && flutter test` (538 pass on August 22, 2026)

Required focused coverage across the initiative:

- [x] `cd tools/editor && flutter test test/chunk_authoring_workspace_test.dart`
- [x] `cd tools/editor && flutter test test/chunk_polygon_authoring_controller_test.dart`
- [x] `cd tools/editor && flutter test test/chunk_scene_visual_source_test.dart`
- [x] `cd tools/editor && flutter test test/chunk_v2_collision_expansion_test.dart`
- [x] `cd tools/editor && flutter test test/chunk_v2_marker_placement_projection_test.dart`
- [x] `cd tools/editor && flutter test test/chunk_v2_domain_plugin_test.dart`
- [x] `cd tools/editor && flutter test test/chunk_v2_composition_commit_test.dart`
- [x] `cd tools/editor && flutter test test/chunk_v2_file_codec_test.dart`
- [x] `cd tools/editor && flutter test test/chunk_v2_save_plan_test.dart`
- [x] `cd tools/editor && flutter test test/polygon_terrain_generator_parity_test.dart`
- [x] `cd tools/editor && flutter test test/polygon_interaction_benchmark_fixture_test.dart`

Unchanged source/runtime seam gate:

- [x] `dart run tool/generate_chunk_runtime_data.dart --dry-run`
- [x] verify the dry-run reports no authored or generated drift caused by this
      initiative
- [ ] if an editor projection refactor touches shared terrain adapters, run
      `cd packages/runner_content_pipeline && dart test
      test/polygon_terrain_compilation_test.dart`, then run
      `flutter test test/tool/polygon_terrain_signature_probe_test.dart` from
      the repository root

Validation closure refreshed August 22, 2026: the normal dry-run validates
three chunks, three levels, three parallax themes, and one terrain material with
no blocking issues.

## Final Acceptance Checklist

- [x] One persistent Chunk creation scene replaces the two old workspace views.
- [x] Four tabs beneath the global scene controls select one matching flat group
      of right-side sections without replacing the scene.
- [x] Sidebar sections have no redundant domain wrapper and start collapsed.
- [x] Prefabs and Markers each expose foldable Create and Existing sections;
      adding from the Create form does not open a modal dialog.
- [x] Prefab selection uses one searchable visual library shared by scene Place
      and inline creation; no long Prefab dropdown remains in Chunk Creator.
- [x] Enemy selection uses one searchable Core-backed visual library shared by
      scene Place, inline creation, and retained-marker editing; no enemy
      dropdown remains in Chunk Creator.
- [x] Narrow layouts preserve scene, viewport, focus, selection, and draft state.
- [x] Existing terrain and composition features remain complete.
- [x] Active-domain and typed-selection behavior is deterministic and tested.
- [x] Prefab and marker gestures safely use a full stale-checked snapshot and a
      captured owner key/revision, plus a canonical index whenever an existing
      record is targeted.
- [x] Direct gestures use local previews and exactly one accepted semantic
      commit.
- [x] Marker authored anchors remain distinct from resolved placement evidence.
- [x] Layer capability remains explicitly metadata-only and no tile-painting
      affordance is present.
- [x] Plugin/store/session authority, Chunk-v2 source shape, Core placement
      lineage, canonical ordering, source-drift checks, and atomic apply remain
      intact.
- [x] Full editor analysis and tests pass.
- [x] Generator dry-run and runtime-lineage parity checks prove those contracts
      are unchanged.
- [x] Performance, documentation, and redundancy reviews are complete.
- [ ] Manual accessibility review is complete.
