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
- prefab (obstacle/platform/decoration), tile-slice, and platform-module
  authoring, including tagged atlas/tile slices and searchable slice selection
- chunk authoring with scene-based prefab composition, shared pan/zoom/grid
  controls, prefab flip toggles, rendered floor/gap visualization, and
  metadata/ground editing
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

## Polygon Migration Readiness Check

The checked-in level content is currently in an intentional collision-reset
state for polygon reauthoring. All prefab visuals, kinds, metadata, placements,
and markers are retained, but obstacle/platform collider lists are empty. Each
chunk uses one full-width `collision_cleared` gap to express that no legacy
ground should be generated. Missing prefab collision is therefore a visible,
non-blocking authoring warning. Partial gaps still obey the normal grid rules.

Until polygons are reauthored and the coordinated source/runtime cutover is
complete, the repository levels have no static terrain support for players,
enemies, marker placement, or navigation.

Phase 4 includes a read-only offline check for the planned prefab-v3/chunk-v2
polygon source migration:

```bash
cd tools/editor
dart run tool/migrate_polygon_authoring.dart --check \
  --report=.tmp/slopes-phase4-migration.json
```

Omitting `--check` still runs check mode. The command strictly parses the
legacy prefab/chunk files, builds and round-trips all target files in memory,
records before/after SHA-256 values plus revision and placement-impact facts,
and rechecks source digests before reporting. The optional report must be a
workspace-relative `.json` path outside `assets/authoring`.

Exit codes are `0` for a blocker-free readiness plan, `1` for a source,
planning, target-validation, drift, or report failure, and `64` for invalid
arguments. `--write` is intentionally unavailable: the command cannot modify
authored source or activate polygon collision at runtime.

## Polygon Interaction Profile Benchmark

The Phase 4 polygon staging surface has a deterministic Windows profile
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
benchmark is test-only: it cannot write authoring source or select staged
terrain at runtime.

## Explicit Polygon Workspace Navigation

When an all-current workspace loads the Chunk-v2 polygon workflow, each
read-only expanded prefab collision exposes **Open prefab**.
The action goes through the editor shell's unsaved-work guard, loads the
Prefab-v3 staging document, and selects the exact stable source owner for shape
editing. Chunk placements continue to own transforms only; the editor does not
create per-instance polygon overrides.

Normal loading now detects strict Prefab-v3 and complete Chunk-v2 source and
selects these polygon workflows. Changed current documents can be applied only
through their confirmed, source-drift-guarded transactional stores, then are
reloaded from the exact installed bytes. Legacy or missing source opens one
shared migration-required workspace with no editable data, pending diff, or
export path. It shows the read-only readiness command and can atomically
recheck source after an external migration; it never exposes Prefab-v2
rectangle or Chunk-v1 ground/gap controls. The one-time migration `--write`
command and live polygon runtime authority remain unavailable.
