# Runner Content Pipeline

Pure-Dart, repository-independent authored chunk decoding, deterministic
terrain compilation, seam validation, and Core runtime-data materialization.

The package accepts explicit source identities and source strings. Repository
filesystem discovery and generated-artifact writes remain in the root `tool/`
layer, while Flutter and editor state remain in `tools/editor/`.

Repository generation compiles and structurally validates every source, including
excluded levels and deprecated chunks. `PolygonTerrainSchedulerLevelSource` has
explicit build inclusion: whole-level scheduler and seam checks produce a runtime
batch only for included levels and active chunks. The result also retains all
structurally compiled chunks for the root generator's complete reference/asset
validation. Exclusion cannot conceal malformed source or geometry.

The root generator owns the Level v2 inclusion schema and publication policy,
including requiring playable included content. `isRuntimeEligibleChunkStatus`
keeps generated pools, authored Play and editor capacity admission consistent.
