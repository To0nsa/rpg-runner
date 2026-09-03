# Visual-Pixel Collision Fitting Implementation Checklist

Date: September 3, 2026
Status: Implemented and validated

Source strategy:
[Visual-pixel collision fitting strategy](visual-pixel-collision-fitting-strategy.md)

This checklist is gated. A phase is complete only when its implementation,
tests, documentation, and validation items are complete. Fit visible bounds is
an intermediate milestone; it does not close the feature without outline,
Platform-surface, and downstream-placement validation.

## Closure Evidence

- `cd tools/editor && dart analyze`: pass.
- `cd tools/editor && flutter test`: pass, 602 tests.
- Focused fitting, raster, controller, workspace, plugin, painter, validation,
  and strict-load suites: pass.
- `dart analyze packages/runner_content_pipeline`: pass.
- `dart test packages/runner_content_pipeline/test`: pass, 43 tests.
- `dart run tool/generate_chunk_runtime_data.dart --dry-run`: pass with three
  Chunks, three Levels, three Parallax themes, and one terrain material; no
  generated drift.
- Current source audit: largest atlas slice is 68,628 pixels and largest
  platform module is 4,096 pixels. Fitting is synchronous under a hard
  1,048,576-pixel normalized-mask limit; increasing the limit requires new
  profiling and an isolate-boundary review.
- Source artwork and authored JSON were not changed by feature validation.

## Locked Invariants

- [x] Committed Prefab-v3 `collisionShapes` remain the only collision source of
      truth.
- [x] Runtime and the content pipeline never read PNG pixels.
- [x] Fit mode, thresholds, masks, and simplification settings remain
      route-local and never enter source JSON.
- [x] Every generated vertex is on the mandatory whole-pixel Prefab grid.
- [x] Visual rendering, atlas rectangles, module composition, and anchors are
      unchanged by fitting.
- [x] Atlas preview and fitting share one visual-layout calculation.
- [x] The creation UI exposes Rectangle, Polygon, Fit visible bounds, Trace
      visible outline, and Platform-only Detect platform surface directly.
- [x] Platform fitted collision is one-way; obstacle fitted collision is solid;
      decoration Prefabs remain collision-free.
- [x] Generation is a reversible draft and never dispatches a source command.
- [x] One accepted Save creates at most one collision command, one owner
      revision increment, and one undo entry.
- [x] No failure silently fills holes, drops components, truncates vertices, or
      raises simplification tolerance.
- [x] Existing source-drift, validation, canonical-order, Apply-to-Files, and
      navigation guards remain authoritative.
- [x] Every referencing Chunk placement is reviewed through the shared
      transform/compiler path before Save and before file export.

## Phase 0 — Baseline And Contract Freeze

Objective: verify the current seams and lock testable fitting behavior before
implementation.

### Confirmed implementation inventory

- [x] Prefab-v3 collision shapes are anchor-relative and validated on a fixed
      whole-pixel grid.
- [x] Atlas slices and platform modules already project through
      `PrefabPolygonVisualProjection`.
- [x] Module projection uses actual referenced slice dimensions and normalized
      complete module bounds.
- [x] `EditorUiImageCache` already owns asynchronous PNG decode, region caching,
      and image disposal.
- [x] `PrefabPolygonAuthoringController` already owns local collision drafts and
      guarded navigation.
- [x] `PrefabV3CollisionCommitPolicy` already accepts a complete before/after
      shape list and enforces one reviewed semantic commit.
- [x] Core exposes only upward-facing edges from one-way source loops.
- [x] Core hard limits are 64 shapes per placed Prefab and 64 vertices per
      shape; editor soft targets are 16 and 24 respectively.

### Pre-flight audit

- [x] Record a clean baseline for `cd tools/editor && dart analyze`.
- [x] Record a clean baseline for focused Prefab controller/workspace tests.
- [x] Record a clean baseline for `cd tools/editor && flutter test`.
- [x] Audit current authored Prefab-v3 shapes: 56 colliding Obstacles are solid;
      four Platforms currently have no shapes; there is no live mode mismatch.
- [x] Audit test fixtures and migration fixtures for kind/mode mismatches before
      tightening UI or validation.
- [x] Audit atlas slices for alpha patterns: fully transparent, binary alpha,
      partial alpha, disconnected islands, and internal holes.
- [x] Audit platform modules for negative cells, overlapping cells, missing
      slices, non-tile-sized slices, and multi-image composition.
- [x] Measure representative source dimensions and decode/generation time.
- [x] Record whether current validation permits adjacent generated shapes with
      shared boundaries and confirm Core seam cancellation behavior.
- [x] Inventory every referencing Chunk placement scale/reflection used by
      current Prefabs and capture cases that make one-pixel edges invalid.

### Contract fixtures

- [x] Add small in-memory RGBA fixtures for transparent padding, concavity,
      islands, holes, diagonal contact, and noisy top edges.
- [x] Add atlas-slice coordinate fixtures with asymmetric anchors.
- [x] Include anchors at zero/image edges plus rejected negative/outside-bound
      anchors in coordinate fixtures.
- [x] Add module fixtures with negative cell positions and mixed slice sizes.
- [x] Freeze default settings: alpha cutoff `1`, minimum island area `1 px²`,
      simplification tolerance `0 px` after mandatory collinear removal.
- [x] Freeze stable component ordering and additional-shape ID allocation.
- [x] Freeze exact hole partition, coverage evidence, and Detect-platform-
      surface profile/closure rules from the strategy.
- [x] Establish mask allocation limits and the measured threshold for moving
      pure fitting work to a background isolate.
- [x] Freeze explicit diagnostics and recovery actions for every blocking case.
- [x] Update the strategy first if profiling or fixture evidence requires a
      different default or topology rule.

Done when:

- [x] the same fixture input has one unambiguous expected shape list
- [x] kind/mode migration impact is known before validation or UI is tightened
- [x] no later phase must invent coordinate or ordering behavior locally

## Phase 1 — Pure Mask And Fitting Domain

Objective: build deterministic geometry generation without Flutter UI,
repository I/O, or session mutation.

### Data contracts

- [x] Add an immutable alpha-mask value with width, height, and exact row-major
      alpha bytes.
- [x] Add fit-method values for Fit visible bounds, Trace visible outline, and
      Detect platform surface.
- [x] Add validated integer settings for alpha cutoff, minimum island area, and
      whole-pixel simplification tolerance.
- [x] Add fit intent for create versus selected-shape replacement to the
      controller-owned draft contract.
- [x] Add a result containing ordered candidate shapes, component and support-
      column evidence, warnings, and blocking diagnostics; keep exact active-
      edge classification in the shared scene/Core parity seam.
- [x] Add deterministic evidence for raw threshold-visible pixels, filtered
      islands/pixels, covered/omitted accepted pixels, added transparent cells,
      and Platform support columns.
- [x] Document units, ordering, topology, and failure behavior on every public
      fitting API.

### Shared analysis

- [x] Validate dimensions and byte length without allocating malformed masks.
- [x] Reject invalid multiplication and masks above the 1,048,576-pixel budget
      before allocating working buffers.
- [x] Threshold with `alpha >= cutoff` and cover the default `cutoff = 1`
      contract explicitly.
- [x] Label four-way-connected components in stable scan order.
- [x] Apply minimum-island-area only when the author selected a value above the
      default.
- [x] Calculate component bounds and stable ordering.
- [x] Return a specific empty-mask diagnostic when no pixels survive.
- [x] Keep all algorithms independent of `dart:ui`, widgets, file paths, and
      session controllers.

### Pure tests

- [x] Cover alpha `0`, cutoff boundary, and alpha `255`.
- [x] Cover one pixel, one row, one column, full mask, and all-transparent mask.
- [x] Cover edge-touching versus diagonal-only component connectivity.
- [x] Cover deterministic component ordering across repeated runs.
- [x] Cover minimum-island filtering without implicit data loss at defaults.
- [x] Cover invalid dimensions, invalid cutoff, and inconsistent byte length.
- [x] Cover coverage metrics and exact repeated-run equality.
- [x] Cover exact positive-area pixel-cell intersection, including diagonal
      candidate edges passing through a cell.
- [x] Cover cancellation/generation tokens for the bounded synchronous
      execution policy selected after the source-dimension audit.

Done when:

- [x] component evidence is deterministic and fully testable without Flutter
- [x] no source or editor state can change from invoking the fitting domain

## Phase 2 — Shared Visual Layout And Alpha Extraction

Objective: provide exact atlas and module masks through one asynchronous,
cached editor boundary.

### Integer visual layout

- [x] Keep one owner-neutral Prefab visual-layout resolver in
      `PrefabPolygonVisualProjection` for preview and fitting.
- [x] Require every visual bound and source/destination tile rectangle to be an
      exact whole-pixel value before fitting.
- [x] Keep negative module cells and actual slice dimensions intact.
- [x] Make the existing scene painter consume that same layout through a thin
      `Rect` conversion.
- [x] Prove the refactor does not change visual bounds or tile destinations for
      existing Prefabs.
- [x] Remove duplicate layout math after parity tests pass.

### Raster adapter

- [x] Extend or compose `EditorUiImageCache` with raw RGBA extraction outside
      widget `build` methods.
- [x] Resolve only the selected Prefab's already-authored workspace source; do
      not add a system-file-picker path to fitting.
- [x] Crop atlas slices against the fully decoded PNG, not only header metadata.
- [x] Match the preview's first-frame rule for decoded PNG input.
- [x] Compose module cells in stable authored order using the shared layout.
- [x] Implement the strategy's exact integer source-over alpha formula for
      overlapping cells.
- [x] Convert the composed image into the pure row-major alpha mask.
- [x] Digest exact PNG bytes and calculate an integer visual-layout signature.
- [x] Cache masks by PNG digest, layout signature, and reload generation.
- [x] Key preview images by path plus digest, replacing and disposing stale
      path-only entries when bytes change.
- [x] Build module source identity from every referenced digest in authored cell
      order plus the layout signature.
- [x] Clear failed-path entries on Reload and expose an explicit retry after an
      image is repaired.
- [x] Avoid adding another image-decoding dependency; use the existing Flutter
      image cache and existing `image` package boundary where appropriate.
- [x] Dispose only adapter-owned UI resources and ignore stale async results.

### Failure behavior

- [x] Report missing image, decode failure, invalid crop, missing module slice,
      and empty module as distinct blocking diagnostics.
- [x] Report stale PNG/layout digest and oversized raster allocation separately.
- [x] Never generate a fallback collider from metadata bounds after pixel
      extraction fails.
- [x] Keep the existing visual fallback painter behavior unchanged for normal
      preview rendering.

### Tests and validation

- [x] Extend `prefab_polygon_visual_source_test.dart` for integer layout parity.
- [x] Add atlas crop-to-mask tests with exact RGBA assertions.
- [x] Add module composition tests for negative, overlapping, and mixed-size
      cells.
- [x] Cover partially transparent overlap and exact alpha rounding/clamping.
- [x] Add raster/mask cache reuse, digest invalidation, stale-result, and owned-
      image disposal coverage.
- [x] Prove preview pixels and fitted mask come from the same digest generation.
- [x] Add byte-digest drift tests where path, timestamp, or dimensions stay the
      same but PNG content changes.
- [x] Run `cd tools/editor && dart analyze`.
- [x] Run the focused visual projection/image tests.

Done when:

- [x] the scene and fitter cannot disagree about source placement or anchor
- [x] both Prefab source kinds produce exact deterministic masks
- [x] image failures are explicit and create no collision draft

## Phase 3 — Downstream Placement Validation Foundation

Objective: establish the shared validation gate before any assisted fit can be
saved, so locally valid pixel detail cannot break an existing scaled, reflected,
or overlapping Chunk placement.

### Read-only placement context

- [x] Extend the Prefab-domain load projection with immutable current Chunk
      snapshots or an equivalent typed placement-validation projection.
- [x] Retain chunk key, placement key, scale, reflection, translation, and
      source baseline identity needed for exact review.
- [x] Keep Chunk persistence authority in `ChunkDomainPlugin`/`ChunkStore`.
- [x] Load no placement data into Prefab source JSON or collision history.
- [x] Reconcile missing/deleted/renamed Chunk references on Reload.

### Candidate review

- [x] Substitute a candidate Prefab into each referencing Chunk snapshot.
- [x] Compile the baseline Chunk first and block with its original diagnostic if
      the baseline is already invalid.
- [x] Compile candidates against the complete current Prefab session snapshot,
      including other pending Prefab edits.
- [x] Run the shared content-pipeline expansion/compiler path for every affected
      Chunk rather than duplicating transform math in Prefab UI code.
- [x] Cover scale `0.3` through `3.0`, reflection, translation, quantization,
      bounds, positive-area overlap, shape/vertex/edge capacity, and one-way
      exposed-edge validity.
- [x] Attach blocking diagnostics to the exact Chunk and placement.
- [x] Permit an unreferenced Prefab after normal owner/Core review.
- [x] Route manual collision commits through the same gate, avoiding a fitter-
      only shadow validation path.

### Export drift gate

- [x] Re-read referencing Chunk sources during Apply to Files.
- [x] Compare their exact source identities with the snapshots used for review.
- [x] Block with Reload guidance when a Chunk changed after validation.
- [x] Re-run affected Chunk compilation before the Prefab pair is written.
- [x] Preserve existing atomic Prefab/tile write planning after the new gate.

### Tests and validation

- [x] Cover a locally valid one-pixel edge rejected after `0.3` scaling.
- [x] Cover horizontal and vertical reflection, including one-way edge changes.
- [x] Cover candidate collision with direct and other placed Chunk geometry.
- [x] Cover pre-existing invalid Chunk baselines without misattributing their
      diagnostics to the candidate fit.
- [x] Cover another pending Prefab edit in the same affected Chunk.
- [x] Cover transformed bounds and shape/edge capacity failures.
- [x] Cover multiple placements of one Prefab across multiple Chunks.
- [x] Cover unreferenced Prefab acceptance.
- [x] Cover Chunk source drift between candidate review and Apply to Files.
- [x] Cover the same gate for manual rectangle/polygon edits.
- [x] Run editor, content-pipeline, and generator validation required by the
      touched cross-domain seam.
- [x] Record Phase 3 as one validated logical milestone in this checklist.

Done when:

- [x] a Prefab collision commit cannot knowingly invalidate a current
      referencing placement
- [x] Prefab review reuses Chunk compilation without acquiring Chunk write
      authority

## Phase 4 — Fit Visible Bounds Vertical Slice

Objective: deliver the complete inline draft lifecycle with the simplest fit
method before adding topology complexity.

### Bounds generator

- [x] Calculate the tight rectangle on accepted pixel-cell boundaries.
- [x] Convert mask coordinates to anchor-relative whole pixels exactly.
- [x] Generate canonical clockwise rectangle vertices.
- [x] Apply obstacle-solid and Platform-one-way result semantics.
- [x] Report that disconnected gaps are spanned by Fit visible bounds.
- [x] Report exact visible/omitted/added pixel-cell coverage evidence.
- [x] Review the complete prospective owner list with current Prefab/Core
      validation before Save.

### Fit draft state

- [x] Add one fit-draft-set state to `PrefabPolygonAuthoringController` or its
      controller-owned helper.
- [x] Capture the complete before-shape snapshot and source/layout identity.
- [x] Track async loading, generation, settings, candidates, selection,
      diagnostics, and create/refit intent.
- [x] Track component inclusion separately from scene selection and require at
      least one included candidate before Save.
- [x] Seed a local prospective owner-shape list without inserting candidates
      into the session-owned committed state.
- [x] Add fit-local undo/redo snapshots for generation and candidate edits.
- [x] Include fit state in `hasActiveOperation`, undo/redo routing, and owner/view
      navigation guards.
- [x] Guard creation-method changes after drawing, generation, inclusion, or
      candidate edits with Save/Discard/Cancel.
- [x] Ensure stale async completion cannot replace a newer owner/settings draft.
- [x] Make Cancel restore the exact pre-fit state with no history entry.
- [x] Make Save dispatch the entire candidate set through
      `PrefabV3CollisionCommitPolicy` once.
- [x] Close an equivalent canonical Save as a no-op without revision/history.
- [x] Allocate final shape IDs from the captured baseline and stable component
      order, including optional primary custom name and collision-free suffixes.

### Inline UI

- [x] Replace the implicit creation-action cluster with one directly visible
      method choice: Rectangle, Polygon, Fit visible bounds, Trace visible
      outline, and Platform-only Detect platform surface.
- [x] Render fit settings inline in the Create collision shape section.
- [x] Add fit method, counts, loading, diagnostics, Advanced, Regenerate, Save,
      and Cancel controls.
- [x] Retain shape name, surface, material, and read-only kind-derived collision
      context in the inline fit editor.
- [x] Add labeled include/exclude controls when generation returns multiple
      components.
- [x] Disable unsupported methods until their phases land; do not label the
      bounds-only milestone as the completed feature.
- [x] Overlay the accepted mask boundary and generated rectangle without
      changing source artwork rendering.
- [x] Reuse current scene pan, zoom, selection, and whole-pixel editing rules.
- [x] Keep manual rectangle/polygon creation available throughout the change.
- [x] Keep the five method labels visible in a wrapping narrow layout instead of
      hiding them in an overflow menu or modal.

### Tests and validation

- [x] Cover exact bounds for transparent padding and asymmetric anchors.
- [x] Cover zero/edge anchors, rejected outside anchors, and doubled-coordinate
      overflow guards.
- [x] Cover atlas and module bounds fitting through the workspace.
- [x] Cover obstacle solid and Platform one-way defaults.
- [x] Cover loading, regenerate, Save, Cancel, and rejected Save.
- [x] Cover owner/view/reload/apply/undo/redo draft guards.
- [x] Cover guarded switching between manual and pixel-derived methods.
- [x] Cover custom primary naming, deterministic suffix allocation, inclusion,
      exclusion, and the zero-included disabled state.
- [x] Assert draft generation is source, revision, pending-diff, and history
      neutral.
- [x] Assert one Save yields one command, revision, and undo entry.
- [x] Assert an equivalent Save yields no revision or history entry.
- [x] Run analyzer, focused tests, and full editor tests.
- [x] Record Phase 4 as one validated vertical slice in this checklist.

Done when:

- [x] bounds fitting is usable end-to-end for atlas and module Prefabs
- [x] its draft lifecycle is safe enough for later multi-shape methods

## Phase 5 — Trace Visible Outline And Multi-Shape Drafts

Objective: make **Fit visible pixels** produce non-rectangular collision that
preserves visible components.

### Boundary generation

- [x] Trace component boundaries only along integer pixel-cell edges.
- [x] Produce canonical concave polygons for hole-free components.
- [x] Remove duplicate and collinear vertices before simplification.
- [x] Implement deterministic topology-preserving simplification at the
      selected whole-pixel tolerance.
- [x] Define tolerance as perpendicular source-pixel distance from a removed
      vertex to its replacement segment and compare it without floating point.
- [x] Evaluate removable vertices in stable source order and accept a removal
      only when integer winding, self-intersection, overlap, hole, and bounds
      checks continue to pass.
- [x] Preserve winding, visual containment, and non-self-intersection.
- [x] Preserve disconnected components as separate candidate shapes.
- [x] Detect transparent holes explicitly.
- [x] Keep hole-free components as traced outer polygons.
- [x] Partition holed components from stable top-to-bottom scanline runs into
      deterministic non-overlapping simple polygons.
- [x] Merge adjacent partition pieces only when exact accepted-pixel occupancy
      and Core validity are preserved.
- [x] Block with a precise capacity diagnostic when that exact partition cannot
      fit within the hard shape or vertex limits.
- [x] Never silently fill an internal transparent hole.

### Capacity and identities

- [x] Allocate shape IDs in stable component/partition order and allocate every
      suffix without collisions.
- [x] Warn when the complete prospective owner exceeds 16 shapes or any shape
      exceeds 24 vertices.
- [x] Block when the complete prospective owner exceeds 64 shapes or any shape
      exceeds 64 vertices.
- [x] Offer explicit recovery by increasing simplification, increasing minimum
      island area, or selecting Fit visible bounds.
- [x] Do not mutate fit settings automatically to pass a limit.

### Draft editing and scene

- [x] Let the author select each generated candidate in the list or scene.
- [x] Reuse vertex movement, insertion, exact-coordinate editing, and shape
      metadata views on the selected candidate.
- [x] Prevent fit-local actions from editing or deleting retained non-candidate
      shapes.
- [x] Preserve edits until explicit Regenerate; warn before regeneration would
      replace manual draft adjustments.
- [x] Draw every candidate and visibly distinguish the selected one.
- [x] Show component/vertex warnings in the candidate draft editor.
- [x] Recompute coverage evidence after candidate vertex or inclusion changes.

### Tests and validation

- [x] Cover convex, concave, diagonal-contact, and disconnected masks.
- [x] Cover exact boundary coordinates and stable component/ID order.
- [x] Cover simplification tolerance, topology preservation, and repeated-run
      parity.
- [x] Prove zero tolerance changes no accepted-pixel occupancy after mandatory
      duplicate/collinear cleanup.
- [x] Cover holes and verify no silent fill path exists.
- [x] Cover exact holed-mask occupancy and deterministic partition/merge order.
- [x] Cover soft warnings and hard shape/vertex limits.
- [x] Cover editing one candidate without changing its siblings.
- [x] Cover regenerate confirmation after manual candidate edits.
- [x] Validate every generated fixture through `TerrainSourceCoreAdapter` and
      `TerrainCompiler`.
- [x] Run analyzer, focused tests, full editor tests, and generator dry-run.
- [x] Record Phase 5 as one validated logical milestone in this checklist.

Done when:

- [x] irregular and disconnected artwork can produce editable polygonal fits
- [x] unsupported complexity fails honestly without partial geometry

## Phase 6 — Detect Platform Surface And One-Way Evidence

Objective: fit the visible support surface while keeping Platform collision
unambiguously one-way.

### Platform-surface generator

- [x] For each retained component, scan columns left-to-right and select the top
      boundary of the uppermost accepted pixel.
- [x] Split on empty columns without automatic gap bridging and preserve stable
      component order.
- [x] Emit integer vertical steps for height changes before explicit
      simplification.
- [x] Close each left-to-right profile at that component's bottom and return
      right-to-left so sides/bottom cannot become upward-facing edges.
- [x] Block interlocking/stacked closures that create positive-area overlap
      rather than returning partial surfaces.
- [x] Require at least one valid upward-facing edge per candidate.
- [x] Apply only one-way collision mode to generated Platform shapes.
- [x] Preserve author-selected surface kind and material metadata.
- [x] Keep decorative peak/noise removal controlled by visible settings rather
      than asset-name or RGB heuristics.

### Kind semantics

- [x] Make Platform the default fit method **Detect platform surface**.
- [x] Make obstacle default fit method **Trace visible outline**.
- [x] Hide collision fitting for decoration Prefabs.
- [x] Display collision kind as read-only context for manual and generated
      shapes: Platform one-way, obstacle solid, decoration none.
- [x] Prevent Platform drafts from switching to solid.
- [x] Prevent obstacle drafts from switching to one-way.
- [x] Resolve any audited retained kind/mode mismatch through an explicit
      migration or documented compatibility rule before tightening source
      validation.
- [x] Update editor Prefab validation to reject mode/kind mismatch without
      mutating loaded source.
- [x] Update current-schema content-pipeline validation with the same rule so
      hand-edited JSON cannot bypass the editor.

### Runtime-edge preview

- [x] Reuse the Core-aligned edge classification to identify upward-facing
      one-way edges.
- [x] Draw active Platform edges distinctly from inert polygon closure.
- [x] Recompute active-edge evidence after every candidate geometry edit.
- [x] Show an inline explanation only where the preview needs it; avoid
      permanent helper-text clutter in the main toolbar.
- [x] Verify owner-local preview edges match compiled exposed-edge output for
      fixtures and state that Chunk preview owns transformed placement evidence.

### Tests and validation

- [x] Cover flat, sloped, stepped, noisy, split, stacked/interlocking, and
      no-support masks.
- [x] Cover closure geometry and absence of unintended active side/bottom edges.
- [x] Cover Platform/obstacle/decoration method and mode restrictions.
- [x] Cover mismatched hand-authored source rejection in editor and content
      pipeline tests.
- [x] Cover active-edge preview parity with Core compilation.
- [x] Add a representative real platform-module fixture.
- [x] Run analyzer, focused tests, full editor tests, content-pipeline tests, and
      generator dry-run if kind validation touches shared compilation.
- [x] Record Phase 6 as one validated logical milestone in this checklist.

Done when:

- [x] a Platform can fit its artwork rather than a nominal cell
- [x] its authoring preview identifies exactly which edges are one-way supports

## Phase 7 — Retained-Shape Refit

Objective: let existing collision use the same fitting workflow without losing
identity, metadata, or undo safety.

### Contextual action and component scope

- [x] Add **Refit from pixels** beside the selected retained shape's existing
      Edit/Delete actions.
- [x] Keep the action inside the row-local expanded editor; do not add a modal or
      detached toolbar action.
- [x] Capture the selected stable shape ID and complete owner before snapshot.
- [x] Derive collision mode from Prefab kind and copy surface kind/material key
      to candidates.
- [x] Determine initial inclusion by exact positive-area intersection between
      generated pixel cells and the selected retained shape.
- [x] Let the author explicitly include/exclude generated components.
- [x] Disable Save when no generated component is included instead of guessing
      a replacement.
- [x] State how many shapes will replace the selected shape before Save.

### Multi-component replacement

- [x] Retain the selected shape ID on the deterministic first shape of the
      primary included component.
- [x] Allocate stable, collision-free IDs for additional included components
      from the selected shape's valid prefix or the normal collision prefix.
- [x] Replace only the captured selected shape and preserve every unrelated
      shape byte-for-byte.
- [x] Keep candidate order canonical before dispatch.
- [x] Reconcile selection to the retained primary ID after Save and undo.
- [x] Reject stale refit when owner revision, visual source, or selected shape
      changed after generation.

### Tests and validation

- [x] Cover one-to-one and one-to-many refit.
- [x] Cover initial component inclusion, manual inclusion changes, and no-
      intersection behavior.
- [x] Cover metadata preservation and kind-aware collision mode.
- [x] Cover exact unrelated-shape preservation.
- [x] Cover deterministic ID collisions and ordering.
- [x] Cover Cancel, rejected Save, stale source, undo, and redo.
- [x] Cover selection and expanded-row reconciliation.
- [x] Run analyzer, focused tests, and full editor tests.
- [x] Record Phase 7 as one validated logical milestone in this checklist.

Done when:

- [x] existing Prefab collision can be refitted with the same safety as creation
- [x] no retained shape is overwritten before an accepted semantic commit

## Phase 8 — Performance, Accessibility, Docs, And Closeout

Objective: prove the complete workflow and make implemented documentation match
shipped behavior.

### Performance and robustness

- [x] Record current authored-size evidence and enforce a hard normalized-mask
      budget; require re-profiling before that budget can increase.
- [x] Cover repeated atlas loads plus overlapping, negative, and mixed-size
      module-cell composition through digest-bound cache fixtures.
- [x] Verify changing settings does not block scene pan/zoom interaction.
- [x] Verify cache hits avoid repeated decode and RGBA extraction.
- [x] Verify stale async work cannot leak images, masks, or controller updates.
- [x] Exercise repeated generate/cancel/owner-switch lifecycles through widget
      and stale-result tests, with cache disposal owned by the workspace.

### Accessibility and manual UX

- [x] Verify visible labels, tooltips, semantics, and keyboard focus order.
- [x] Verify Enter/Space activation and Escape cancellation where consistent
      with current editor controls.
- [x] Verify loading, empty, missing-image, invalid-topology, warning, blocked,
      and accepted states at narrow and wide layouts.
- [x] Verify mask, candidate, selection, and active-edge colors remain readable
      without relying on color alone.
- [x] Verify long source/shape IDs and large counts wrap without obscuring the
      scene.
- [x] Verify manual rectangle and polygon authoring remain discoverable.

### Documentation

- [x] Update `tools/editor/README.md` with the implemented fit/refit workflow.
- [x] Update `docs/tdd/editor_ui_system.md` with fit-draft ownership, async
      lifecycle, and inline UX contracts.
- [x] Update `docs/tdd/polygon_terrain_authoring_foundation.md` with mask-to-
      polygon determinism, coordinates, topology, capacity, and one-way rules.
- [x] Update `tools/editor/AGENTS.md` only if layer ownership or working rules
      changed.
- [x] Keep proposed-only details in these building docs until their phase lands.
- [x] Record final defaults and any evidence-backed deviations in the strategy.

### Final validation

- [x] Run `cd tools/editor && dart analyze`.
- [x] Run all focused mask, visual-source, controller, collision-commit, and
      workspace tests.
- [x] Run `cd tools/editor && flutter test`.
- [x] Run `dart analyze packages/runner_content_pipeline` and
      `dart test packages/runner_content_pipeline/test` if shared validation or
      compilation changed.
- [x] Run `dart run tool/generate_chunk_runtime_data.dart --dry-run`.
- [x] Inspect generated/source diffs for unexpected geometry or ordering churn.
- [x] Perform the required redundancy pass for layout math, image decode/cache,
      component algorithms, mode rules, draft guards, and diagnostics.
- [x] Record Phase 8 as one validated closeout milestone in this checklist.
- [x] Mark the strategy and checklist implemented and move both to
      `docs/building/archived/editor/prefabCreator/` only after every required
      acceptance item is complete.

Done when:

- [x] all automatic and manual evidence is recorded
- [x] implemented TDD/README behavior matches the editor exactly
- [x] no parallel raster, layout, persistence, or draft-authority path remains

## Final Acceptance Checklist

- [x] The Create collision shape section exposes Rectangle, Polygon, Fit visible
      bounds, Trace visible outline, and Platform-only Detect platform surface.
- [x] Trace visible outline produces non-rectangular results.
- [x] Detect platform surface fits actual rendered module pixels rather than a
      fixed cell.
- [x] Atlas slices and platform modules use the same inline fit workflow.
- [x] Generated geometry is whole-pixel, anchor-relative, deterministic, and
      Core-valid.
- [x] Disconnected components become editable multi-shape drafts.
- [x] Authors can exclude generated components, and selected-shape refit uses an
      explicit deterministic component scope.
- [x] Holes preserve transparent area; capacity failures block explicitly.
- [x] Platform fitted shapes remain one-way and active support edges are shown.
- [x] Obstacle fitted shapes remain solid and decoration Prefabs remain
      collision-free.
- [x] Create and retained-shape refit both preview before Save.
- [x] Cancel, navigation guards, stale async work, undo, and redo are safe.
- [x] One accepted Save produces one command, owner revision, and undo entry.
- [x] Source artwork rendering and Prefab placement rendering are unchanged.
- [x] Runtime collision remains sourced only from committed polygons.
- [x] Every current referencing placement passes shared transformed Chunk
      compilation before Save/export.
- [x] Analyzer, focused tests, full editor tests, required pipeline tests,
      generator dry-run, performance evidence, manual UX, accessibility, and
      documentation are complete.
