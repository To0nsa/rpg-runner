# AGENTS.md - Terrain Materials Package

This pure-Dart package owns the repository contract for terrain render
materials. It is shared by the editor and runtime generator so schema parsing,
validation, ordering, canonical JSON encoding, region/asset traversal, and
atlas-repeat math remain single-sourced.

The live contract is strict schema v2. Every fill, edge layer, and cap uses an
explicit terrain-owned PNG region. Do not add schema-v1 compatibility, full-image
fallback fields, editor grid state, or image decoding to this package. Region
bounds against decoded PNG dimensions remain a consumer validation step.

It must not import Flutter, Flame, or `runner_core`. Collision and navigation
authority remain in `runner_core`; this package describes visual assets only.

Validate changes with:

```powershell
dart analyze packages/terrain_materials
Push-Location packages/terrain_materials
dart test
Pop-Location
```
