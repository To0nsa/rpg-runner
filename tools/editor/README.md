# Runner Editor

Standalone authoring tool for `rpg_runner` content workflows.

Current milestone focuses on entity collider authoring architecture for:

- players
- enemies
- projectiles

This app is intentionally separate from gameplay runtime authority. Core gameplay
truth remains in `packages/runner_core/lib/**`.

## Run

```bash
cd tools/editor
flutter run -d windows
```

## Current Phase

Phase 2 foundations are implemented:

- workspace path binding
- domain plugin contracts
- parser-driven import for enemy/player/projectile colliders
- interactive collider viewport with drag handles (center/right/top)
- viewport pan/zoom controls (mouse wheel + buttons)
- keyboard nudges (arrows for offsets, Alt+arrows for extents)
- snap-step controls for drag + keyboard edits
- entry filtering (search/type/dirty-only) and dirty-entry navigation
- auto-loaded sprite reference overlay in viewport (from render authoring data)
- reference frame row/index controls (sheet-aware preview window)
- numeric editing for selected collider entries
- undo/redo command stack for edits
- per-entry dirty markers and live file-level diff previews
- apply-ready unified diff patch artifact (`.patch`)
- direct-write export mode using source-range replacement guards
