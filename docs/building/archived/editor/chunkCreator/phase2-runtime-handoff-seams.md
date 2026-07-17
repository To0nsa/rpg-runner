# Phase 2 Runtime Handoff Seams

Date: April 1, 2026  
Status: Historical Phase 2 seam; runtime collision cutover completed on April 14, 2026

Related files:

- [tools/editor/lib/src/chunks/prefab_runtime_adapter.dart](tools/editor/lib/src/chunks/prefab_runtime_adapter.dart)
- [tools/editor/lib/src/chunks/chunk_domain_models.dart](tools/editor/lib/src/chunks/chunk_domain_models.dart)
- [tools/editor/test/prefab_runtime_adapter_test.dart](tools/editor/test/prefab_runtime_adapter_test.dart)
- [tools/editor/test/chunk_validation_test.dart](tools/editor/test/chunk_validation_test.dart)

Supersession note:

- this document still describes the Phase 2 editor/tooling adapter seam
- runtime chunk collision no longer waits on this seam; generated chunk output
  now lands directly in `runner_core` as `SolidRel` data via
  `packages/runner_core/lib/track/**`

## Purpose

Provide a stable, deterministic adapter seam so Phase 3 runtime integration can
consume Phase 2 prefab authoring contracts without schema redesign.

## Runtime-facing DTO contracts

`RuntimePrefabContract` (from `PrefabDef`) includes:

- identity: `prefabKey`, `prefabId`, `revision`, `status`
- intent: `kind`
- source: `visualSourceType`, `visualSourceRefId`
- geometry: `anchorXPx`, `anchorYPx`, `colliders`
- metadata: `tags`

`RuntimeChunkPrefabRef` (from `PlacedPrefabDef`) includes:

- `prefabKey` (preferred stable reference)
- `prefabId` (legacy compatibility field)
- placement coordinates: `x`, `y`
- placement presentation/policy: `zIndex`, `snapToGrid`

## Mapping rules

Prefab mapping (`mapPrefabToRuntimeContract`):

- default excludes deprecated prefabs (`includeDeprecated = false`)
- rejects unknown/invalid prefab contracts (unknown kind/source, empty source ref)
- preserves authored values without lossy transforms
- deterministic ordering provided by `buildRuntimePrefabContracts` (sorted by
  `prefabKey`, then `prefabId`)

Chunk placement mapping (`mapPlacedPrefabToRuntimeRef`):

- uses `prefabKey` when present
- falls back to legacy `prefabId` when `prefabKey` is absent
- always preserves legacy `prefabId` for backwards compatibility

## Backwards compatibility seam

`PlacedPrefabDef` now supports both identity fields:

- `prefabKey` optional (new)
- `prefabId` required legacy fallback path

JSON parse behavior:

- accepts `prefabId`-only records (legacy)
- accepts `prefabKey`-only records (fills `prefabId` fallback from `prefabKey`)
- deterministic `resolvedPrefabRef` prefers `prefabKey`, then `prefabId`

Validation seam:

- chunk validation blocks prefab placements with no `prefabId` and no `prefabKey`
- chunk validation enforces grid snap only when the placement opts into
  `snapToGrid`

## Adapter removal criteria for Phase 3

Remove this adapter layer only when all conditions are true:

1. `runner_core` runtime contracts natively consume `prefabKey` and typed
   prefab kind/source from Phase 2 schema.
2. Runtime loading no longer requires compatibility payloads keyed by
   `prefabId`.
3. End-to-end generation/runtime tests prove no semantic drift after adapter
   removal.
4. Phase 3 migration path for legacy chunk prefab references is complete and
   validated.
