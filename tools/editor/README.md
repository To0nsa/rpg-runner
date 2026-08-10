# Runner Editor

Standalone authoring tool for `rpg_runner` content workflows.

This app is intentionally separate from gameplay runtime authority. Core gameplay
truth remains in `packages/runner_core/lib/**`.

## Run

```bash
cd tools/editor
flutter run -d windows
```

## Current Capabilities

Implemented authoring domains:

- entity collider/source-bound authoring for players, enemies, and projectiles
- prefab (obstacle/platform/decoration), tile-slice, platform-module, and exact
  half-pixel polygon-collision authoring, including tagged atlas/tile slices
  and searchable slice selection
- chunk authoring with direct terrain polygons, expanded placed-Prefab
  collision, actor/navigation/marker diagnostics, scene-based composition,
  shared pan/zoom/grid controls, and Prefab transform editing
- level metadata authoring with list/inspector editing, lifecycle controls,
  assembly segment sequencing, render-theme run validation, pending diff
  preview, and direct-write export
- parallax theme authoring scoped by active level, with ordered layer editing,
  deterministic save output, validation, and preview motion simulation

Editor foundations shared across those domains:

- workspace path binding and plugin-backed route selection
- session-managed load, validation, pending-change previews, and direct-write export
- undo/redo history for entity edits, chunk edits, and committed prefab/module edits
- shared pan/zoom scene controls, inspector forms, and deterministic export summaries

## Polygon Source And Offline Migration

The checked-in level content is currently in an intentional collision-reset
state for polygon reauthoring. All prefab visuals, kinds, metadata, placements,
and markers are retained, but Prefab-v3 and Chunk-v2 `collisionShapes` lists
are empty. The generator projects each empty Chunk to one full-width
`collision_cleared` compatibility gap. Missing Prefab collision is therefore a
visible, non-blocking authoring warning.

Until polygons are reauthored and runtime terrain authority is delivered, the
repository levels have no static terrain support for players, enemies, marker
placement, or navigation.

The normal editor accepts only current Prefab-v3/Chunk-v2 source. Legacy
Prefab-v1/v2 and Chunk-v1 parsing is isolated to this offline check command:

```bash
cd tools/editor
dart run tool/migrate_polygon_authoring.dart --check \
  --report=.tmp/slopes-phase4-migration.json
```

Omitting `--check` still runs check mode. The command detects a complete legacy
or current generation, strictly parses it, builds and round-trips all target
files in memory, records before/after SHA-256 values plus revision and
placement-impact facts, and rechecks source digests before reporting. The
optional report must be a workspace-relative `.json` path outside
`assets/authoring`. Checked-in source now reports current with nine validated
targets and zero pending representation migrations.

Exit codes are `0` for a blocker-free readiness plan, `1` for a source,
planning, target-validation, drift, or report failure, and `64` for invalid
arguments. Explicit `--write` is retained for a complete blocker-free legacy
workspace and requires `--report=<external-path.json>`; it uses the guarded
nine-file transaction and emits committed/no-op/failure evidence. Re-running it
against current source is a no-op. Source migration does not activate polygon
collision at runtime.

## Polygon Interaction Profile Benchmark

The Phase 4 polygon authoring surface has a deterministic Windows profile
benchmark for vertex and whole-shape drag. It uses 120 warmup and 600 measured
frames per mode against the reviewed 16-shape/256-edge fixture:

```powershell
cd tools/editor
flutter drive --profile `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/polygon_interaction_benchmark_test.dart `
  -d windows
```

The driver writes the compact report to
`.tmp/slopes_phase4_polygon_interaction.json` at repository root. It records
the Git revision/dirty state, fixture signatures, interaction and frame
percentiles, missed-input counts, source-identity evidence, and each gate. The
benchmark is test-only: it cannot write authoring source or select the future
terrain artifact at runtime.

## Polygon Controls

Prefab and Chunk polygon scenes share the same controls:

- select **Create**, then primary-click to append snapped vertices
- press Enter or choose **Close draft** to validate and close a polygon
- press Escape or choose **Cancel** to discard the active draft/gesture
- use **Select**, **Move vertex**, **Insert vertex**, or **Move shape** before
  primary-clicking or dragging the corresponding scene element
- press Delete/Backspace to delete the current selection
- use Ctrl+Z to undo and Ctrl+Y or Ctrl+Shift+Z to redo
- use Ctrl+drag to pan and Ctrl+wheel to zoom
- use **Normalize** explicitly to apply canonical winding/start and remove
  diagnosed collinear middle vertices

Rejected edits retain their draft/gesture and show diagnostics; they do not
enter session history. **Apply current source** is the only normal file-write
action and always requires confirmation.

## Polygon Workspace Navigation

When an all-current workspace loads the Chunk-v2 polygon workflow, each
read-only expanded prefab collision exposes **Open prefab**.
The action goes through the editor shell's unsaved-work guard, loads the
current Prefab-v3 document, and selects the exact stable source owner for shape
editing. Chunk placements continue to own transforms only; the editor does not
create per-instance polygon overrides.

Normal loading now detects strict Prefab-v3 and complete Chunk-v2 source and
selects these polygon workflows. Changed current documents can be applied only
through their confirmed, source-drift-guarded transactional stores, then are
reloaded from the exact installed bytes. Legacy or missing source opens one
shared migration-required workspace with no editable data, pending diff, or
export path. It shows the read-only readiness command and can atomically
recheck source after an external migration; it never exposes Prefab-v2
rectangle or Chunk-v1 ground/gap controls. The one-time migration command is
complete; live polygon runtime authority remains unavailable.

The release-signoff walkthrough uses a disposable Git worktree so a
non-developer can exercise diagnostics, editing, apply/reload, narrow-window,
and keyboard behavior without changing the main workspace. See the
[Phase 4 manual polygon usability pass](../../docs/building/slopes/phase4-manual-usability-pass.md).

The release-signoff walkthrough uses a disposable Git worktree so a
non-developer can exercise diagnostics, editing, apply/reload, narrow-window,
and keyboard behavior without changing the main workspace. See the
[Phase 4 manual polygon usability pass](../../docs/building/slopes/phase4-manual-usability-pass.md).
