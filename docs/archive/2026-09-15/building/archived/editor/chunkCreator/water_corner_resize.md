# Water corner resizing

Status: implemented and closed. September 13, 2026.

## Strategy

Extend the existing water rectangle gesture and Select workflow. Selected
corners become handles; the opposite corner stays anchored. Reuse snapping,
validation, material preview and the typed water commit instead of adding a
separate resize tool or persistence path.

## Implementation checklist

- [x] Hit-test all four selected corners at a constant canvas radius.
- [x] Preview expansion/shrinkage, preserving the opposite corner and grab offset.
- [x] Reuse grid/neighbor snapping and exclude the resized region's own corners.
- [x] Commit once on release; keep clicks and cancelled/invalid drags revision-neutral.
- [x] Protect pending inline edits and stale revisions; refresh fields after resizing.
- [x] Show visible handles, resize guidance and the existing snap controls.
- [x] Cover geometry and scene interaction, including Undo/Redo and cancellation.
- [x] Update authoring documentation, run editor checks and archive this plan.

Acceptance: Select a water region, drag any corner to resize, and release to
accept one undoable edit. Escape/pointer cancellation restores the original;
invalid rectangles give feedback without changing the saved region.

## Validation

- Editor analysis: no issues.
- All 45 water geometry and workspace tests passed in the full editor run,
  including eight new geometry cases and a scene interaction regression covering
  previews, release, history, cancellation, snapping, pending input and stale edits.
- Full editor suite: 784 passed, two skipped, three failures outside resizing.
  The accepted-Play projection and new-level preparation fixtures retain their
  [previously recorded failures](../../swimmable_water_validation.md).
  `Play validates focused metadata and captures accepted input` times out in
  `pumpAndSettle` while opening the owner list. It fails identically in an
  isolated copy of the pre-change editor at `705069a9` using current content.
- Full-run evidence: `build/validation/water_resize_editor_full.log`.
  Isolated timeout evidence: `water_resize_playtest_retry.log` and
  `water_resize_playtest_baseline.log` in the same directory.
- `git diff --check` passed. Runtime contracts and generated content are unchanged;
  existing prefab, tile and Forest chunk authoring edits are excluded.

The [authoring guide](../../../../../../gdd/swimming.md) and
[technical contract](../../../../../../tdd/swimmable_water.md) describe the delivered UX.
