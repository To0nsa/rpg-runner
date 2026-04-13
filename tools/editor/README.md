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
