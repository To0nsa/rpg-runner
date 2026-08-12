# Slopes Phase 4 - Manual Polygon Usability Pass

- Status: Pending a non-developer tester
- Owner: Phase 4 acceptance
- Source checklist:
  [phase4-implementation-checklist.md](phase4-implementation-checklist.md)

## Purpose

This pass answers one question that automated widget, integration, parity, and
performance tests cannot: can a person who did not implement polygon
authoring complete the normal Prefab-v3 and Chunk-v2 workflows without editing
JSON or Dart?

The tester must not receive step-by-step help while operating a control. They
may use this document and the labels/instructions visible in the editor. If a
maintainer has to explain an unlabeled action, record that as a usability
failure rather than coaching past it.

## Safe Disposable Setup

Do not run the write portion against the main working tree. From the repository
root, a maintainer creates a detached sibling worktree:

```powershell
git worktree add --detach ..\rpg_runner_phase4_usability HEAD

Push-Location ..\rpg_runner_phase4_usability\tools\editor
flutter pub get
flutter run -d windows
Pop-Location
```

Launching from that `tools\editor` directory selects the disposable worktree
root automatically. Confirm the workspace shown in the editor contains
`rpg_runner_phase4_usability` before applying any file change.

The chosen Prefab owner below, `anvil_00`, is active, collision-capable, and not
placed by current Chunks. This keeps its test geometry from creating unrelated
placement failures. The worktree begins from the intentional collision-reset
content state.

## Tester Record

Complete this before starting:

- tester name:
- tester role/background:
- date:
- tested revision:
- Windows display scale and editor window size:
- prior experience with this editor: none / limited / regular

## A) Discover And Reject Invalid Prefab Geometry

1. Open the Prefab Creator and select `anvil_00`.
2. Find the collision scene and Shapes panel using only visible navigation.
3. Start a new polygon, place only two distinct vertices, and choose **Save**.
4. Confirm that `too_few_vertices` explains that at least three distinct
   vertices are required and that the rejected draft remains available.
5. Cancel the draft. Confirm it disappears and does not create a pending file
   change.

Pass when the tester finds these actions without coaching, understands the
diagnostic, and can recover without reloading the workspace.

## B) Complete The Prefab Workflow

1. Choose **New polygon** and place five vertices inside the visible `anvil_00`
   sprite. Place one vertex badly, Undo it once, and Redo it. Confirm each
   keyboard command changes exactly that one draft vertex and session/source
   Undo remains untouched.
2. Before saving, confirm **Move vertex** and **Insert vertex** are available,
   while **Select**, **Create**, and **Move shape** are disabled. Move one draft
   vertex and insert another on an open draft edge, then exercise Undo/Redo for
   both edits.
3. Leave one middle draft vertex aligned with its neighbors and choose **Save**.
   Confirm Save removes the redundant vertex, closes the draft, and creates one
   source-history entry. No separate Close or Normalize Draft control may be
   present.
4. Choose **New rectangle**, drag between two opposite corners inside the
   sprite, and confirm a closed four-vertex draft appears. Cancel it and
   confirm the saved polygon remains unchanged.
5. Select the saved shape, one edge, and one vertex. Confirm selection is
   visible in both the scene and inspector.
6. On the saved shape, insert a non-collinear vertex, then move it back onto its
   original edge. Confirm the aligned preview remains visible with the same
   diagnostic. Choose **Normalize** and confirm it removes the redundant vertex
   as one undoable edit.
7. Begin another rejected saved-shape move, then choose a different tool.
   Confirm the uncommitted preview is discarded, the last committed polygon is
   restored, and the requested tool becomes active.
8. Exercise Move vertex on two different vertices consecutively without
   reselecting the tool, then exercise Insert vertex, Delete, Move shape, and
   Duplicate. Each chosen edit tool must remain active after a completed
   gesture. Undo after any experiment that would overlap or leave the visual
   bounds; no rejected operation may corrupt the last accepted shape.
9. Exercise Undo and Redo from both the visible buttons and the documented
   keyboard shortcuts.
10. Set or clear optional collision metadata and verify that rendering metadata
   does not change the collision-mode label.
11. Choose **Apply current source**, review the confirmation, apply, reload, and
   confirm the exact polygon and metadata remain present.

Pass when one valid Prefab-v3 shape survives apply/reload, each accepted gesture
creates one undo step, rejected edits remain recoverable, and no source file is
opened manually.

## C) Complete The Chunk Workflow

1. Open the Chunk Creator, select the `field` level and `field_flat` owner.
2. Repeat the two-vertex invalid-Save check, then cancel it.
3. Create a small orthogonal solid draft fully inside the Chunk bounds and away
   from both horizontal Chunk seams. Undo/Redo one placed vertex, move another,
   and insert one on an open edge. Confirm each keyboard command changes only
   one draft vertex and these remain local draft edits.
4. Confirm only Move vertex and Insert vertex remain available during creation,
   then choose **Save** and verify exactly one source-history entry is created.
5. Choose **New rectangle**, drag between two opposite corners within the Chunk
   bounds, and confirm a closed four-vertex draft appears. Cancel it and
   confirm the saved direct polygon remains unchanged.
6. Confirm the direct polygon is visibly filled and the scene states that the
   fill is authoring-only while Core-compiled edges remain collision and
   navigation evidence.
7. Inspect one compiled edge and confirm its stable ID, tangent/normal, slope,
   collision mode, and source lineage are readable.
8. Insert a non-collinear vertex, move it back onto its original edge, and use
   **Normalize** to commit the aligned preview. Then start another rejected
   move and choose a different tool to discard it. Confirm no invalid preview
   enters history and expanded Prefab shapes remain read-only.
9. Move two different vertices consecutively without reselecting Move vertex,
   then use Undo/Redo. Confirm the chosen edit tool remains active after each
   completed gesture.
10. Open Chunk composition. Confirm the visual stack identifies ground polygons,
   their `groundBandZIndex`, and bottom-to-top ordering separately from runtime
   collision authority.
11. Choose **Apply current source**, review the confirmation, apply, reload, and
   confirm the direct shape remains present.

Pass when the changed Chunk survives apply/reload, seam/bounds diagnostics stay
actionable, no per-instance Prefab vertex edit is offered, and no JSON is
edited by hand.

## D) Narrow Window And Keyboard Check

1. Resize the editor to approximately `900 x 900` logical pixels.
2. In both Prefab and Chunk polygon routes, use the labeled tabs to reach Owners
   or Chunks, Scene or Terrain, and Shapes.
3. Traverse the main actions with the keyboard. Confirm focus is visible and
   Enter/Escape, Delete, Undo, and Redo behave as the on-screen guidance says.
4. Confirm no control is clipped without an available scroll path and no
   exception or overflow banner appears.

## E) Evidence And Pass Decision

Close the editor, then run these read-only checks from the main repository:

```powershell
git -C ..\rpg_runner_phase4_usability status --short
git -C ..\rpg_runner_phase4_usability diff --check

Push-Location ..\rpg_runner_phase4_usability\tools\editor
dart run tool/migrate_polygon_authoring.dart --check `
  --report=.tmp/slopes-phase4-manual-usability.json
Pop-Location
```

Expected evidence:

- only `assets/authoring/level/prefab_defs.json` and the selected
  `field_flat.json` Chunk source are changed
- `git diff --check` is clean
- the migration/current-source check is blocker-free
- apply/reload was completed once in both routes
- no JSON, Dart, generated output, or production runtime file was hand-edited
- no crash, Flutter exception, overflow warning, or unexplained disabled action
  occurred

Record:

- result: pass / fail
- elapsed time:
- unclear labels or actions:
- diagnostics that did not explain recovery:
- keyboard, focus, scaling, or scrolling problems:
- unexpected changed files:
- screenshots or screen recording location:
- follow-up issue/commit links:

Any unexplained action, required maintainer coaching, lost edit, non-actionable
diagnostic, inaccessible control, or unexpected file write is a failure. Keep
the disposable worktree until a maintainer has reviewed the diff and evidence;
cleanup must not discard an unreviewed failure reproduction.

Only a recorded human pass may close the final unchecked Phase 4 gate.
