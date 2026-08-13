# AGENTS.md - Terrain Materials Package

This pure-Dart package owns the repository contract for terrain render
materials. It is shared by the editor and runtime generator so schema parsing,
validation, ordering, and canonical JSON encoding remain single-sourced.

It must not import Flutter, Flame, or `runner_core`. Collision and navigation
authority remain in `runner_core`; this package describes visual assets only.

Validate changes with:

```powershell
dart analyze packages/terrain_materials
Push-Location packages/terrain_materials
dart test
Pop-Location
```
