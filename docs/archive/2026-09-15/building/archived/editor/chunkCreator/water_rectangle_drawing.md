# Water rectangle drawing

Status: implemented and closed. September 13, 2026.

The [Terrain/Water UX alignment](water_terrain_ux_alignment.md) follow-up replaces
this initial control layout and numeric modal with shared creation controls,
explicit drawing and inline editing. Validation below records the initial delivery.

## Strategy

Use a Water domain in the existing shared Chunk scene. A dedicated local water
rectangle draft fits the existing non-terrain gesture callbacks and preserves
water's non-solid source contract. Extending the solid polygon reducer would
couple distinct geometry rules; keeping only numeric forms would not provide
the requested scene workflow. Reuse terrain snapping and the existing water
plugin transaction for both drawing and exact-coordinate edits.

## Implementation checklist

- [x] Add Water tab, material picker, and independent grid/neighbor switches.
- [x] Draw opposite corners with material preview, bounds and snap feedback.
- [x] Reuse nearest-vertex selection; retain eight-screen-pixel capture at zoom.
- [x] Snap to whole-pixel direct terrain, expanded prefab and water corners.
- [x] Keep drafts local until Enter/Save water; Escape/Cancel discards them.
- [x] Preserve one-edit Undo/Redo and revision-checked plugin publication.
- [x] Block Save/Play/owner/domain transitions during unfinished drawing.
- [x] Reuse ID allocation and runtime source validation for both input paths.
- [x] Update the authoring guide, technical contract and editor README.
- [x] Pass static analysis and focused gesture/workspace regressions.
- [x] Run the full editor suite and record unrelated baseline failures.

Acceptance: rectangle geometry/material survive the existing save path; drawing
never emits solid terrain; snapping respects zoom, bounds and neighbor priority;
invalid, cancelled and stale drafts cannot change source or history.

## Validation

- Editor static analysis: no issues.
- Water gesture, exact-form and plugin tests: eight passed. They cover reverse
  dragging, bounds, grid/neighbor priority at multiple zoom levels, transformed
  prefab vertices, touching/overlapping pools, zero-area rejection, material
  persistence, stale revisions and the ordinary Save diff.
- Workspace interaction passed both its focused run and the full suite:
  material selection, draft-only preview, Enter, Escape, Undo/Redo, unchanged
  solid terrain, and Save/Play/domain guards.
- Full editor suite: 773 passed, two skipped, three failed. The preparation
  performance timeout passed in the final sequential rerun (nine total passes
  including the eight water tests).
- Two existing failures remain: the accepted-Play fixture references missing
  `forest/forest_early_flat.json`; the new-level preparation fixture reports a
  preparation issue. These were already reproduced against original code in
  the [water delivery validation](../../swimmable_water_validation.md).
- `git diff --check` passed. No source schema, generated runtime content, or
  gameplay rules changed. Existing edits to prefab/tile definitions are excluded.

See the [authoring guide](../../../../../../gdd/swimming.md) and
[technical contract](../../../../../../tdd/swimmable_water.md).
