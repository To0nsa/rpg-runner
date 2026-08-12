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

- entity collider/source-bound authoring for players, enemies, and projectiles,
  with runtime-faithful capsule and broad-phase previews
- prefab (obstacle/platform/decoration), tile-slice, platform-module, and exact
  half-pixel polygon-collision authoring, including tagged atlas/tile slices
  and searchable slice selection
- chunk authoring with direct terrain polygons, expanded placed-Prefab
  collision, active-level parallax and terrain-material scene preview,
  actor/navigation/marker diagnostics, scene-based composition, shared
  pan/zoom/grid controls, and Prefab transform editing
- level metadata authoring with list/inspector editing, lifecycle controls,
  assembly segment sequencing, render-theme run validation, pending diff
  preview, and direct-write export
- parallax theme authoring scoped by active level, with ordered layer editing,
  deterministic save output, validation, and preview pan/zoom plus temporary
  all-layer Y-offset simulation

Editor foundations shared across those domains:

- workspace path binding and plugin-backed route selection
- session-managed load, validation, pending-change previews, and direct-write export
- undo/redo history for entity edits, chunk edits, and committed prefab/module edits
- shared pan/zoom scene controls, inspector forms, and deterministic export summaries

## Entity Collider Preview

The entity scene presents combat geometry using the runtime field meanings:

- players and enemies show their upright capsule as the primary outline and
  its tight enclosing broad-phase AABB as the secondary outline;
- for actors, `halfX` is capsule radius and `halfY - halfX` is the vertical
  half-spine; `offsetX` mirrors with facing;
- projectiles show a canonical horizontal preview of their runtime
  direction-oriented capsule, where `halfX` is half-spine and `halfY` is
  radius;
- actor `halfY < halfX`, non-positive dimensions, and non-finite values are
  invalid and block export rather than previewing a different runtime shape.

Actor previews call Core's quantized AABB-to-capsule derivation. The editor
still writes the existing catalog-bound size and offset fields; it does not
introduce an independent combat-hurtbox schema.

## Polygon Source And Offline Migration

The checked-in source includes `anvil_00` with one Prefab collision polygon,
and all eight chunks with a continuous `ground_001` polygon carrying `ground`
/ `grass_dirt` metadata. Other collision-reset Prefab owners remain available
for authoring. Missing Prefab collision is therefore a visible, non-blocking
authoring warning.

The generator compiles every source polygon into the staged terrain artifact.
Normal gameplay and replay validation consume that admitted polygon artifact
through the direct terrain authority. Collision, navigation, placement, and
render publication share the same streamed candidate; there is no selectable
legacy rectangle-terrain runtime path.

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

- use **New polygon** in Shapes and diagnostics to start a draft, then use
  **Place vertex** in the scene to append snapped draft vertices
- use **New rectangle** in Shapes and diagnostics, then drag across opposite
  corners to create an editable four-vertex polygon draft
- while a draft is open, **Place vertex**, **Move vertex**, and **Insert vertex**
  edit that draft; **Select shape** and **Move shape** remain disabled
- with no saved collision shape and no open draft, **Move vertex**, **Move
  shape**, and **Insert vertex** are disabled
- Undo and Redo traverse draft vertex placement, movement, and insertion locally
  without changing source history
- press Enter or choose **Save** to normalize, validate, and commit the complete
  draft as one source-history edit
- press Escape or choose **Cancel** to discard the active draft/gesture
- outside creation, use **Select shape**, **Move vertex**, **Insert vertex**, or
  **Move shape** before primary-clicking or dragging the corresponding element
- the chosen edit tool remains active after a completed gesture, so consecutive
  vertices, edges, or shapes can be edited without selecting the tool again
- press Delete/Backspace to delete the current selection
- use Ctrl+Z to undo and Ctrl+Y or Ctrl+Shift+Z to redo
- use Ctrl+drag to pan and Ctrl+wheel to zoom
- use **Normalize** explicitly to apply canonical winding/start and remove
  diagnosed collinear middle vertices

Rejected edits retain their draft/gesture and show diagnostics; they do not
enter source history. Draft **Save** removes redundant aligned middle vertices
before the single commit. For a rejected committed-shape gesture, **Normalize**
applies the visible preview or selecting another tool discards that preview.
**Apply current source** remains disabled until local work is resolved and is
the only normal file-write action; it always requires confirmation.

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
