# Multi-Rect Prefab Collision Plan

Date: April 13, 2026  
Status: Implemented in code; authored content reauthoring pending

Related docs:

- `docs/building/editor/chunkCreator/plan.md`
- `docs/building/editor/chunkCreator/phase2-runtime-handoff-seams.md`
- `docs/building/editor/chunkCreator/prefab-multi-rect-collision-implementation-checklist.md`

Primary touched areas:

- `tools/editor/lib/src/prefabs/**`
- `tools/editor/lib/src/app/pages/prefabCreator/**`
- `tool/generate_chunk_runtime_data.dart`
- `packages/runner_core/lib/track/**`

## Implementation outcome

The planned migration landed with these final contract decisions:

- `SolidRel` is now the only runtime chunk collision contract for static prefab
  geometry.
- `PlatformRel` and `ObstacleRel` were removed after generated/runtime parity
  was proven in tests and current authored chunk sources were regenerated.
- `tool/generate_chunk_runtime_data.dart` now emits one `SolidRel` per authored
  prefab collider and only imports `enemy_id.dart` when generated spawn markers
  require it.
- obstacle/platform prefab editing in `tools/editor` now round-trips full
  collider lists and supports scene-based multi-collider authoring.

Current authored content intentionally remains minimal:

- committed chunk JSONs are limited to `field_flat` and `forest_flat`
- committed chunk JSONs still have empty `prefabs: []`
- `assets/authoring/level/prefab_defs.json` now contains committed
  multi-collider obstacle prefabs including `anvil_00`, `apple_00`, and
  `rock_moss_00`

That means the feature is implemented and test-covered, but the first live
generated multi-collider gameplay chunk will arrive once those prefabs are
placed into chunk JSONs in a separate content-authoring pass.

## Purpose

Preserve authored prefab collider lists into runtime collision instead of
collapsing every obstacle/platform prefab to one exported bounds box.

This is a follow-on cleanup after the prefab-backed runtime cutover in Phase 4.
It does not require a new collision system. Core already resolves collision
against many axis-aligned static solids; the current loss of fidelity happens in
the editor projection and generator/export path.

## Current state

What exists today:

- `PrefabDef.colliders` is already a list in authoring data.
- prefab validation already iterates all colliders and preserves deterministic
  ordering.
- the prefab editor scene/form flow only edits one collider at a time by
  projecting `prefab.colliders.first`.
- the generator computes one union/bounds box from all prefab colliders and
  exports that single box into runtime obstacle/platform geometry.
- `runner_core` collision uses `StaticSolid` AABBs, so multiple rectangles are
  already a natural fit on the simulation side.

Current consequence:

- authored extra colliders do not survive into gameplay as distinct collision
  pieces
- internal negative space is lost
- elevated or separated obstacle sub-shapes collapse into a grounded rectangle
- editor data shape and runtime behavior are misleadingly different

## Goals

- support multiple authored rectangle colliders for obstacle and platform
  prefabs
- preserve each collider through placement transform, scale, and flip
- keep deterministic ordering from authoring data through generated runtime data
- avoid any Flame/render-layer redesign
- keep decoration prefabs collision-free

## Non-goals

- arbitrary polygon or spline colliders
- rotated colliders
- freeform per-instance collision editing in the chunk editor
- replacing `StaticSolid`-based collision with a new physics representation
- changing decoration prefab semantics

## Decision

Use authored multi-rect AABBs as the long-term prefab collision primitive.

Do not add freeform collider shapes. The cleanest implementation is to add a
runtime chunk `SolidRel` contract that maps directly to `StaticSolid`, then have
the generator emit one `SolidRel` per authored prefab collider.

This is cleaner than trying to force every prefab collider through the current
`ObstacleRel` and `PlatformRel` split:

- `PlatformRel` can describe an elevated one-way box.
- `ObstacleRel` is implicitly grounded and cannot represent arbitrary vertical
  placement.
- authored prefab colliders already carry enough information to describe a
  general static box after placement transform.

## Target end state

After this plan lands:

- obstacle/platform prefabs can contain multiple colliders in
  `assets/authoring/level/prefab_defs.json`
- the prefab creator UI can add, select, edit, duplicate, and remove colliders
- the scene overlay draws all colliders and exposes handles for the selected
  collider
- the generator exports each collider as its own runtime static solid
- runtime chunk patterns preserve those solids without collapsing them to one
  union box
- Core collision, streaming, navigation, and snapshots continue consuming
  deterministic `StaticSolid` lists

## Architecture direction

### 1) Keep authoring JSON shape

Do not redesign `PrefabDef.colliders`.

The authoring contract is already the correct shape for this feature:

- `anchorXPx`
- `anchorYPx`
- `colliders[]`
- collider-local `offsetX`, `offsetY`, `width`, `height`

The problem is not the prefab JSON schema. The problem is that current editor
UI and runtime export only honor the first collider or the union bounds.

### 2) Add a runtime `SolidRel` chunk contract

Add a chunk-runtime rectangle contract under `packages/runner_core/lib/track/`
that expresses one static authored solid directly.

Recommended fields:

- `x`
- `aboveGroundTop`
- `width`
- `height`
- `sides`
- `oneWayTop`

Rationale:

- this maps cleanly to `StaticSolid`
- it avoids grounding all non-platform prefab collision
- it keeps side-mask and one-way behavior explicit
- it lets runtime collision consume authored boxes without inferring gameplay
  meaning from prefab kind alone

### 3) Use a staged runtime migration

Do not force a one-pass deletion of `PlatformRel` and `ObstacleRel`.

Safer rollout:

1. add `SolidRel` and teach `ChunkPattern` / `chunk_builder.dart` to consume it
2. keep existing `platforms` and `obstacles` paths temporarily for generated and
   test compatibility
3. move prefab-generated collision to `solids`
4. remove legacy runtime obstacle/platform export only after parity tests prove
   the cutover is stable

This keeps the migration small and reviewable while avoiding a long-lived
parallel runtime model.

## Implementation phases

### Phase A - Runtime contract freeze

Scope:

- define `SolidRel` in `packages/runner_core/lib/track/chunk_pattern.dart`
- decide whether `ChunkPattern` temporarily supports all three:
  `platforms`, `obstacles`, and `solids`
- document the exact mapping from prefab kind to solid flags:
  - platform collider -> `sideTop`, `oneWayTop: true`
  - obstacle collider -> `sideAll`, `oneWayTop: false`

Acceptance:

- `SolidRel` fields and semantics are documented before editor/export work begins
- no follow-up phase depends on guessing how collision flags should be derived

### Phase B - Core track/runtime support

Scope:

- update `packages/runner_core/lib/track/chunk_builder.dart` to build
  `StaticSolid`s from `SolidRel`
- preserve deterministic author ordering when appending built solids
- keep existing validation behavior for snap, bounds, and positive extents
- ensure `TrackStreamer` and downstream consumers need no behavior change beyond
  the new pattern contract

Acceptance:

- runtime can consume generated `solids` without changing Flame code
- existing streaming and collision behavior remains deterministic in tests

### Phase C - Generator fidelity cutover

Scope:

- update `tool/generate_chunk_runtime_data.dart` so prefab collider export emits
  one runtime solid per authored collider
- apply placement transform per collider:
  - placement position
  - prefab anchor
  - scale
  - `flipX` / `flipY`
- snap each collider rectangle to grid individually after transform
- stop using unioned collider bounds as the exported collision representation
- preserve existing visual sprite export unchanged

Acceptance:

- a prefab with `N` colliders yields `N` runtime solids
- flip and scale preserve each collider as a distinct piece
- exported generated chunk data no longer loses internal holes or separated
  sub-shapes

### Phase D - Editor state and scene lift

Scope:

- replace single-collider `PrefabSceneValues` projection with a collider-list
  projection plus selected-collider state
- replace single-collider form ownership in `PrefabFormState`
- update `PrefabEditorPrefabController` and
  `PrefabEditorPageCoordinator` to round-trip full collider lists
- add collider-list operations in obstacle/platform prefab tabs:
  - add collider
  - duplicate collider
  - remove collider
  - select collider
- keep decoration prefab flow unchanged except for continuing to forbid
  colliders

Acceptance:

- obstacle/platform prefab editing no longer truncates to `colliders.first`
- load -> edit -> save round-trips the full collider list deterministically
- decoration prefabs still save with no colliders

### Phase E - Editor scene UX and cleanup

Scope:

- update prefab scene overlay rendering to draw all authored colliders
- expose drag handles only for the selected collider
- keep anchor editing behavior shared with current scene interaction model
- ensure undo/redo and local draft history treat collider-list operations as
  coherent edits
- remove now-obsolete single-collider helper paths once replacements are stable

Acceptance:

- designers can visually edit multiple colliders without hand-editing JSON
- scene controls stay consistent with existing editor interaction rules
- there is no hidden second code path still projecting only one collider

## File-level work map

Editor authoring and validation:

- `tools/editor/lib/src/prefabs/models/prefab/prefab_def.dart`
- `tools/editor/lib/src/prefabs/models/prefab/prefab_collider_def.dart`
- `tools/editor/lib/src/prefabs/store/prefab_determinism.dart`
- `tools/editor/lib/src/prefabs/validation/prefab_validation.dart`
- `tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_form_state.dart`
- `tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_scene_values.dart`
- `tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_editor_prefab_controller.dart`
- `tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_editor_page_coordinator.dart`
- `tools/editor/lib/src/app/pages/prefabCreator/obstacle_prefabs/**`
- `tools/editor/lib/src/app/pages/prefabCreator/platform_prefabs/**`

Generator and runtime:

- `tool/generate_chunk_runtime_data.dart`
- `packages/runner_core/lib/track/chunk_pattern.dart`
- `packages/runner_core/lib/track/chunk_builder.dart`
- generated: `packages/runner_core/lib/track/authored_chunk_patterns.dart`

Likely unaffected:

- `lib/game/**` render-layer code
- `packages/runner_core/lib/ecs/systems/collision_system.dart`
- `packages/runner_core/lib/collision/static_world_geometry.dart`

## Testing plan

Editor tests to add or extend:

- `tools/editor/test/prefab_store_test.dart`
- `tools/editor/test/prefab_validation_test.dart`
- `tools/editor/test/prefab_creator_page_test.dart`
- `tools/editor/test/prefab_overlay_interaction_test.dart`
- `tools/editor/test/scene_control_parity_test.dart`
- `tools/editor/test/prefab_runtime_adapter_test.dart`

Runtime/generator tests to add or extend:

- `test/tool/generate_chunk_runtime_data_test.dart`
- `test/core/chunk_builder_validation_test.dart`
- `test/core/track_streaming_test.dart`
- targeted collision/navigation regression tests if multi-solid prefab shapes
  change reachable surfaces

Validation commands for implementation work:

- `cd tools/editor && dart analyze`
- `cd tools/editor && flutter test`
- `dart run tool/generate_chunk_runtime_data.dart --dry-run`
- relevant root `flutter test` / `dart test` targets for touched runtime code

## Acceptance criteria

- a prefab authored with multiple colliders exports multiple runtime solids
- obstacle/platform prefab collision no longer collapses to one union box
- flip and scale preserve per-collider fidelity in generated runtime data
- prefab editor load/save/edit flows preserve full collider lists
- decoration prefab validation still blocks colliders
- deterministic ordering remains stable in JSON, generated Dart, and runtime
  solid lists
- no Flame-specific code changes are required for shipped gameplay parity

## Risks and constraints

- introducing `SolidRel` without a staged bridge will create high churn in
  generated data, tests, and runtime helpers
- changing editor scene state before generator/runtime support lands will create
  an authoring/runtime parity gap
- keeping both single-collider and multi-collider editor paths too long will
  create stale logic and misleading UX
- collision fidelity changes can affect navigation/surface extraction outcomes,
  so pathing regressions need explicit test coverage

## Recommended implementation order

1. Freeze the runtime `SolidRel` contract and compatibility strategy.
2. Teach Core track building to consume `solids`.
3. Update generator/export so authored collider lists survive to runtime.
4. Add editor collider-list state and scene interactions.
5. Run parity/regression tests, then remove obsolete single-collider code.

This order keeps the runtime contract authoritative first, lets hand-authored
or test prefab collider lists prove the export path early, and avoids shipping
an editor UX that advertises fidelity the runtime still discards.
