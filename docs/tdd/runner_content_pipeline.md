# Runner Content Pipeline

Date: August 19, 2026

Status: Implemented

## Purpose

`packages/runner_content_pipeline` is the pure-Dart, repository-independent
boundary between authored Prefab-v3, tile-v2, and Chunk-v2 source text and the
typed data consumed by deterministic Core. It exists so the repository
generator and the Windows editor can prepare identical runtime content without
duplicating parsing, geometry, visual-sprite, or spawn-marker rules.

The package does not make gameplay decisions. `runner_core` remains the
authority for terrain compilation, chunk patterns, enemy identities, and
simulation behavior. The dependency points from `runner_content_pipeline` to
`runner_core`; the reverse dependency is forbidden.

## Ownership

The package owns:

- strict Prefab-v3, tile-v2, and Chunk-v2 decoding from explicit strings
- canonical source identities and terrain-authoring issues
- Core terrain compilation, placement lineage, triangulation, and signatures
- scheduler reachability and compiled seam validation
- typed `StagedTerrainChunkData` and `StagedTerrainArtifactData`
  materialization
- deterministic staged-terrain Dart rendering
- typed `ChunkPattern` visual sprites, spawn markers, traps and encounters
- semantic comparison of staged artifacts with a fresh accepted compile

The root `tool/` layer retains:

- repository directory traversal and file reads
- level, parallax, and terrain-material source orchestration
- conversion from root level definitions into the small scheduler-level input
- fixed generated target paths, drift inspection, coordinated writes, logging,
  arguments, and process exit codes

`tools/editor` owns draft/session selection and presentation. It calls
the package with in-memory source snapshots, but the package never imports
editor or Flutter code.

## Public Boundaries

`compilePolygonTerrainRuntimeChunkSource` is the isolated preview boundary. A
caller supplies explicit Prefab, tile, and Chunk source paths and contents. A
successful result contains one `PolygonTerrainRuntimeChunk` with:

- the accepted `PolygonTerrainCompiledChunk`
- its typed `StagedTerrainChunkData`
- its typed Core `ChunkPattern`

Any parse, compilation, missing visual reference, or unknown marker blocker
returns canonical issues and no partial runtime chunk.

Encounter-bearing chunks additionally require an explicit owning `groundTopY`
and complete catalog-valid participant placement. Shared `decodeEncounterDefinitions`
and `validateEncounterReadiness` separate strict source admission from runtime
readiness. Callers capturing structurally valid drafts may disable the immediate
readiness check, then validate the exact active/selected runtime pool before
publishing a scenario. The repository generator uses this distinction for
excluded/deprecated chunks. See [encounter contracts](npc_encounter_contracts.md)
for schema, immutable copies, diagnostics and placement ownership.

Repository generation uses `buildPolygonTerrainRepository` for the complete
source set. It takes package-owned scheduler-level records rather than root
`LevelDefinitionSource` objects, enumerates Core reachability, validates every
reachable seam, and returns no batch on any blocker. The root generator then
calls `materializePolygonTerrainRuntimeChunk` for each accepted repository
chunk and uses `renderStagedPolygonTerrainDart` for the staged artifact.

## Determinism and Ordering

All parsers reject non-current schemas, unknown fields, noncanonical ordering,
duplicate identities, and invalid numeric domains. Public result collections
are immutable or expose immutable Core records. Terrain issues use Core's
canonical ordering. Compilation and materialization preserve source paths,
placement keys, polygon/edge/triangle ordering, signatures, and local compiler
identity checks.

The staged Dart renderer writes the same typed artifact produced by
`materializeStagedTerrainArtifact`; rendering and in-memory consumption cannot
drift into separate validation paths. The Phase 1 extraction preserved every
reviewed signature and all generated target bytes.

## Decoration center rotation

Chunk-v2 placements optionally store `rotationDegrees`: a finite clockwise
angle in Y-down pixel space in [0, 360), omitted at zero. Strict decoding rejects
null, wrong types and noncanonical angles. Nonzero rotation is admitted only
for `decoration` Prefabs with no collision shapes; terrain never rotates.
Placement sorting includes the angle after flips, so distinct rotations at the
same anchor remain distinct canonical records.

The pivot is the center of the complete visual bounds after anchor translation,
scale and flips. Changing the angle keeps that center and placement X/Y fixed.
Atlas sprites rotate about their destination center. Module cells use the module's
authored tile size and normalize their minimum cell coordinates before the anchor
offset, matching the editor's visual projection. Each tile's center orbits the
complete placed bounds; each emitted sprite carries the same angle for rendering
about its own center. Gaps and negative cell coordinates remain part of the bounds.

The angle travels through generated `ChunkVisualSpriteRel` records, streaming,
`StaticPrefabSpriteSnapshot`, and Flame. Rotated tiles retain subpixel geometry;
Flame snaps a shared camera offset rather than rounding each tile independently.
Zero-degree sources retain their default runtime values and generated bytes.
This is render-only data: collision, navigation, terrain signatures, commands,
replay acceptance and scoring are unaffected.

### Editor transaction and preview

The shared placement controls expose rotation only when the resolved Prefab is
a collision-free decoration. Numeric author input wraps finite degrees into the
canonical range; nonfinite input shows a field error. Creation forms clear retained
rotation when the catalog changes to an owner that does not support it. Unsupported saved
rotation retains its value until the author uses Clear unsupported rotation;
validation continues to block it until that explicit repair.

The Chunk selected-prefab strip uses the existing transform draft: preview hides
the accepted placement, Apply submits one revision-guarded composition command,
and Cancel restores it. Degree values participate in semantic equality and
canonical ordering, so rotation-only edits create an undoable revision. Store
Save persists them through the same drift-checked transaction. Accepted unsaved
values flow through captured Chunk/Level Play preparation.

Preview painting rotates the complete post-reflection bounds around their center.
Selection uses the rotated AABB for rejection and inverse rotation for the oriented
rectangle test, preventing its empty AABB corners from stealing clicks.

## Side-Effect Boundary

Production code in the package must not import `dart:io`, Flutter, Flame, or
editor paths. It must not discover repository files, decode image bytes, read
assets, write targets, inspect generated drift, or select process exit codes.
These constraints are covered by package boundary tests and repository
guidance.

## Validation

```powershell
dart analyze packages/runner_content_pipeline

Push-Location packages/runner_content_pipeline
dart test
Pop-Location

dart run tool/generate_chunk_runtime_data.dart --dry-run
flutter test test/tool/generate_chunk_runtime_data_test.dart
flutter test test/tool/polygon_terrain_render_test.dart test/tool/polygon_terrain_signature_probe_test.dart
```


Connection admission derives Core physical profiles from compiled geometry before
selection. [The complete-state scheduler](chunk_connections.md) admits only
continuing schedules, including all section lengths and supported Normal spawn.
Structurally compiled chunks remain available for owner diagnostics on schedule
failure; `validatedBatch` is null and generation publishes nothing. The accepted
seam signature includes the selection contract digest as transition provenance.
