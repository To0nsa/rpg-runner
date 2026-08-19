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
- typed `ChunkPattern` visual sprites and spawn markers
- semantic comparison of staged artifacts with a fresh accepted compile

The root `tool/` layer retains:

- repository directory traversal and file reads
- level, parallax, and terrain-material source orchestration
- conversion from root level definitions into the small scheduler-level input
- fixed generated target paths, drift inspection, coordinated writes, logging,
  arguments, and process exit codes

`tools/editor` will own draft/session selection and presentation. It may call
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
