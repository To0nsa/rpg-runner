# Phase 2 Step 0 - Prefab Contract Freeze And Migration Map

Date: April 1, 2026  
Status: Frozen for Phase 2 implementation

Related docs:

- [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md)
- [docs/building/editor/chunkCreator/phase2-implementation-checklist.md](docs/building/editor/chunkCreator/phase2-implementation-checklist.md)

## Purpose

Lock the Phase 2 prefab contract before implementation so Phase 3 runtime
cutover consumes this contract without schema redesign.

This freeze defines:

- finalized v2 prefab schema shape
- field-level migration from current v1 data
- deterministic key allocation and normalization rules
- blocking/error behavior for malformed legacy records

## Frozen Decisions

1. `prefab_defs.json` moves to `schemaVersion: 2` in Phase 2.
2. Prefab identity becomes two-track:
   - `prefabKey`: immutable machine identity
   - `id`: user-facing renameable label
3. Prefab lifecycle and mutation safety are explicit:
   - `revision` is required and integer
   - `status` is required (`active`, `deprecated`)
4. Prefab intent is explicit:
   - `kind` is required (`obstacle`, `platform`)
5. Visual source is a typed union:
   - `visualSource.type = atlas_slice` with `sliceId`
   - `visualSource.type = platform_module` with `moduleId`
6. Phase 2 compatibility matrix is strict:
   - `obstacle` prefabs must use `atlas_slice`
   - `platform` prefabs must use `platform_module`
7. Phase 2 does not auto-heal gameplay-critical legacy data:
   - missing/invalid required fields are blocking validation errors
   - migration only synthesizes structural fields that did not exist in v1

## Frozen V2 Schema

```json
{
  "schemaVersion": 2,
  "slices": [
    {
      "id": "village_crate_01",
      "sourceImagePath": "assets/images/level/props/TX Village Props.png",
      "x": 32,
      "y": 10,
      "width": 64,
      "height": 64
    }
  ],
  "prefabs": [
    {
      "prefabKey": "village_crate_01",
      "id": "village_crate_01",
      "revision": 1,
      "status": "active",
      "kind": "obstacle",
      "visualSource": {
        "type": "atlas_slice",
        "sliceId": "village_crate_01"
      },
      "anchorXPx": 32,
      "anchorYPx": 32,
      "colliders": [
        {
          "offsetX": 0,
          "offsetY": 0,
          "width": 44,
          "height": 44
        }
      ],
      "tags": []
    }
  ]
}
```

### Field invariants

- `prefabKey`: lowercase slug-like token, immutable after create/duplicate.
- `id`: non-empty, unique in document, may change via explicit rename.
- `revision`: positive integer.
- `status`: `active` or `deprecated`.
- `kind`: `obstacle` or `platform`.
- `visualSource`:
  - `atlas_slice`: requires `sliceId`, must reference `prefab_defs.slices[].id`
  - `platform_module`: requires `moduleId`, must reference
    `tile_defs.platformModules[].id`
- `anchorXPx`, `anchorYPx`: integer pixel values.
- `colliders`: non-empty list, each collider has positive width/height.
- `tags`: normalized prefab metadata only. Placement snap/layer settings now
  belong to chunk placements, not prefab definitions.

## Migration Map (v1 -> v2)

Current v1 shape (Phase 0):

- `schemaVersion: 1`
- prefab record fields:
  - `id`
  - `sliceId`
  - `anchorXPx`, `anchorYPx`
  - `colliders[]`
  - `tags`

### Field mapping table

- `schemaVersion`
  - v1: `1`
  - v2: `2`
  - rule: set to `2` on first canonical save.
- `prefabKey`
  - v1: absent
  - v2: required
  - rule: allocate deterministically from `id` (algorithm below).
- `id`
  - v1: `id`
  - v2: `id`
  - rule: preserve as-is (normalization applies).
- `revision`
  - v1: absent
  - v2: required
  - rule: initialize to `1`.
- `status`
  - v1: absent
  - v2: required
  - rule: initialize to `active`.
- `kind`
  - v1: absent
  - v2: required
  - rule: initialize legacy records to `obstacle`.
- `visualSource`
  - v1: `sliceId`
  - v2: typed object
  - rule:
    - `type = atlas_slice`
    - `sliceId = v1.sliceId`
- `anchorXPx`, `anchorYPx`
  - v1: unchanged
  - v2: unchanged
  - rule: preserve.
- `colliders`, `tags`
  - v1: unchanged
  - v2: unchanged
  - rule: preserve and canonicalize ordering where applicable.

## Deterministic `prefabKey` allocation algorithm

For each prefab in source list order:

1. Start with `base = slug(id)`:
   - lowercase
   - trim whitespace
   - replace non `[a-z0-9_]` with `_`
2. If `base` is empty, use `base = "prefab"`.
3. If `base` is unused, assign `prefabKey = base`.
4. Otherwise append deterministic numeric suffix:
   - `base_2`, `base_3`, ...
   - first free candidate wins.

This guarantees deterministic results for identical inputs, including malformed
inputs with duplicate IDs.

## Legacy invalid data behavior (blocking vs normalize)

Normalize automatically:

- structural fields absent in v1:
  - `prefabKey`, `revision`, `status`, `kind`, `visualSource`

Block with validation errors:

- missing/empty `id`
- duplicate `id`
- missing/empty legacy `sliceId` during v1 migration
- missing/invalid anchor values
- missing/empty colliders
- collider width/height <= 0
- unresolved `visualSource` references
- unknown enum values in v2 (`kind`, `status`, `visualSource.type`)

Do not auto-rename duplicate IDs and do not invent gameplay geometry.

## Revision and lifecycle policy (frozen for Phase 2)

- create: `revision = 1`, `status = active`, new `prefabKey`
- duplicate: new `id`, new `prefabKey`, `revision = 1`, `status = active`
- rename: updates `id` only, preserves `prefabKey` and revision
- metadata/collider/source edits: bump `revision` by `+1` when values change
- deprecate: first transition to `deprecated` bumps `revision` by `+1`; repeated
  deprecate is idempotent

## Canonical serialization rules

- deterministic prefab ordering: by `(id, prefabKey)`
- deterministic key ordering inside each prefab object
- deterministic `tags` ordering (sorted, de-duplicated)
- trailing newline at end of file
- no legacy v1-only shape persists after first canonical v2 save

## Phase 3 handoff guarantees

Phase 3 can consume Phase 2 schema without redesign because:

- prefab intent is explicit (`kind`)
- source type is explicit (`visualSource.type`)
- identity is stable (`prefabKey`) and rename-safe (`id`)
- mutation/version safety is explicit (`revision`, `status`)
- migration from legacy data is deterministic and documented
