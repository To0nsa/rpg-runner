# Terrain corner resizing and water movement

Status: implemented and closed. September 13, 2026.

## Strategy and acceptance

Extend Terrain's existing polygon gesture reducer and collision constraints for
selected axis-aligned rectangles. Share water's handle presentation and scene
snap targets. Add water Move shape through its existing rectangle gesture and
typed commit, preserving dimensions. Both workflows preview locally and publish
one edit on release, protect pending input and cancel with Escape or Undo.

## Checklist

- [x] Resize any selected Terrain rectangle corner in Select, fixing its opposite corner.
- [x] Preserve ordinary polygon/vertex tools and Terrain collision constraints.
- [x] Add water Move shape with fixed dimensions, grid and neighbor snapping.
- [x] Share snap-target capture and rectangle handle painting where equivalent.
- [x] Protect pending input, cancel invalid/stale gestures and preserve history.
- [x] Test reducer, controller and scene behavior, including existing water resizing.
- [x] Update current technical/authoring docs and complete editor validation.

## Validation

- Editor analysis: no issues.
- Focused checks: 90 reducer, contact, controller and water geometry tests;
  31 workspace tests. All 121 passed.
- New coverage includes all Terrain corners, expansion/shrinkage and crossing,
  metadata preservation, off-grid grab offsets, no-ops, invalid release,
  collision contact, exact neighbors, Water displacement/bounds/overlap,
  scene previews, field rebinding, pending input, cancellation and history.
- Full suite: 795 passed, two skipped, four failed. The preparation performance
  test timed out under contention and passed its isolated rerun. The remaining
  three failures are the [previously documented Play fixtures/timeouts](water_corner_resize.md#validation).
- Logs under `build/validation/`: `terrain_resize_water_move_geometry.log`,
  `terrain_resize_water_move_workspace.log`, `terrain_resize_water_move_full.log`,
  and `terrain_resize_water_move_performance.log`.
- `git diff --check` passed. No runtime schemas or generated artifacts changed;
  existing prefab/tile edits and the authored Forest water chunk remain outside
  this commit.

Current behavior is documented in the [Terrain authoring guide](../../../../../../gdd/terrain_visual_language.md),
[Water guide](../../../../../../gdd/swimming.md), [polygon interaction contract](../../../../../../tdd/polygon_terrain_authoring_foundation.md),
and [Water contract](../../../../../../tdd/swimmable_water.md).
