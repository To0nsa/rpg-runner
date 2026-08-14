# AGENTS.md - Terrain Materials Package

This pure-Dart package owns the repository contract for terrain render
materials. It is shared by the editor and runtime generator so schema parsing,
validation, ordering, canonical JSON encoding, region/asset traversal, and
atlas-repeat math remain single-sourced.

The live contract is strict schema v3. Every fill, edge layer, and cap uses an
explicit terrain-owned PNG region. Edge regions are authored in their natural
world-facing role orientation; shared render math normalizes top, left-wall,
right-wall, and underside art into edge tangent space. Do not add compatibility
for older schemas, full-image fallback fields, editor grid state, or image
decoding to this package. Region bounds against decoded PNG dimensions remain a
consumer validation step.

It must not import Flutter, Flame, or `runner_core`. Collision and navigation
authority remain in `runner_core`; this package describes visual assets only.

Validate changes with:

```powershell
dart analyze packages/terrain_materials
Push-Location packages/terrain_materials
dart test
Pop-Location
```
