# Prefab Multi-Rect Collision Implementation Checklist

Date: April 13, 2026  
Status: Implemented in code; authored content follow-up pending  
Source plan:
[docs/building/editor/chunkCreator/prefab-multi-rect-collision-plan.md](docs/building/editor/chunkCreator/prefab-multi-rect-collision-plan.md)

This checklist turns the multi-rect prefab collision plan into an execution
sequence with concrete passes, file targets, runtime boundaries, and test
gates.

## Current Snapshot

- [x] `SolidRel` runtime contract is implemented in `runner_core`.
- [x] `chunk_builder.dart` consumes generated `solids` directly with the
      legacy `platforms` / `obstacles` bridge removed.
- [x] generator export preserves one authored prefab collider per runtime
      solid.
- [x] obstacle/platform prefab editor state now round-trips full collider
      lists.
- [x] prefab scene overlays draw all colliders, restrict handles to the
      selection, and allow direct scene-based collider selection.
- [x] focused runtime/editor tests cover multi-collider export, state, and
      scene interaction.
- [x] current authored chunk sources have been regenerated into committed
      runtime outputs, intentionally dropping the previously deleted legacy
      chunk set.
- [x] the legacy runtime `platforms` / `obstacles` bridge has been removed.
- [x] `cd tools/editor && dart analyze` is green.
- [x] `cd tools/editor && flutter test` is green.
- [x] `dart run tool/generate_chunk_runtime_data.dart --dry-run` is green.
- [x] focused root runtime/generator tests are green.
- [x] live authored multi-collider obstacle prefabs are committed in
      `assets/authoring/level/prefab_defs.json`.
- [ ] current chunk JSONs still do not place those prefabs.
      `assets/authoring/level/chunks/**` currently contains only `field_flat`
      and `forest_flat`, both with empty `prefabs: []`, so generated runtime
      output still lacks a live authored multi-collider chunk until content
      placement lands.

## Closure Summary

- Runtime chunk collision now uses `SolidRel` only.
- The generator preserves one runtime solid per authored prefab collider.
- The prefab editor can add, select, edit, duplicate, delete, and scene-drag
  multiple colliders for obstacle and platform prefabs.
- Current committed chunk content intentionally remains the simplified
  `field_flat` / `forest_flat` set.
- Committed prefab authoring now includes multi-collider obstacle prefabs such
  as `anvil_00`, `apple_00`, and `rock_moss_00`.
- Future content work:
  - place committed multi-collider prefabs into chunk JSONs
  - author at least one multi-collider platform prefab when platform content
    work begins

Historical note:

- the detailed phase checkboxes below are retained as the original execution
  template and were not exhaustively backfilled after landing the feature
- use `Current Snapshot`, `Regression and Validation Sweep`, and `Docs Close-out`
  as the authoritative completion record

## Goal

Ship multi-rect prefab collision end-to-end:

- obstacle/platform prefabs can author multiple rectangle colliders
- the prefab editor can select and edit collider lists without truncating to
  `colliders.first`
- generator output preserves one runtime collision solid per authored collider
- runtime chunk data consumes those solids deterministically without a Flame
  render rewrite
- decoration prefabs remain collision-free

## Gate (must pass)

- authored prefab collider count is preserved into generated runtime collision
  data
- per-collider scale and flip transforms are preserved in generator output
- runtime track building consumes generated solids deterministically
- prefab editor load -> edit -> save round-trips full collider lists
- no single-collider shadow path remains in touched editor flows
- validation and tests cover both editor and runtime seams

## Scope Boundaries

In scope:

- prefab collider authoring flow in `tools/editor`
- prefab validation and deterministic persistence
- generated chunk runtime collision export
- `runner_core` track contract changes needed to consume generated multi-rect
  solids

Out of scope in this checklist:

- polygon colliders
- rotated colliders
- per-placement collider overrides in the chunk editor
- Flame render-layer changes in `lib/game/**`
- collision system replacement in `packages/runner_core/lib/ecs/**`

## Locked Invariants

- `PrefabDef.colliders` remains the prefab authoring source of truth.
- Decoration prefabs must continue to reject colliders.
- Runtime collision remains AABB-based through `StaticSolid`.
- Deterministic ordering must be preserved in:
  - prefab JSON
  - generated Dart output
  - runtime solid build order
- Keep runtime chunk collision on `solids`; do not reintroduce a parallel
  `platforms` / `obstacles` collision path.
- Do not introduce a second long-lived editor path that silently edits only the
  first collider.

## Pre-flight

- [ ] Re-read the source plan:
      [docs/building/editor/chunkCreator/prefab-multi-rect-collision-plan.md](docs/building/editor/chunkCreator/prefab-multi-rect-collision-plan.md).
- [ ] Confirm current prefab authoring baseline in:
  - [tools/editor/lib/src/prefabs/models/prefab/prefab_def.dart](tools/editor/lib/src/prefabs/models/prefab/prefab_def.dart)
  - [tools/editor/lib/src/prefabs/models/prefab/prefab_collider_def.dart](tools/editor/lib/src/prefabs/models/prefab/prefab_collider_def.dart)
  - [tools/editor/lib/src/prefabs/store/prefab_determinism.dart](tools/editor/lib/src/prefabs/store/prefab_determinism.dart)
  - [tools/editor/lib/src/prefabs/validation/prefab_validation.dart](tools/editor/lib/src/prefabs/validation/prefab_validation.dart)
  - [tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_form_state.dart](tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_form_state.dart)
  - [tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_scene_values.dart](tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_scene_values.dart)
  - [tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_editor_prefab_controller.dart](tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_editor_prefab_controller.dart)
  - [tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_editor_page_coordinator.dart](tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_editor_page_coordinator.dart)
- [ ] Confirm current generator/runtime baseline in:
  - [tool/generate_chunk_runtime_data.dart](tool/generate_chunk_runtime_data.dart)
  - [packages/runner_core/lib/track/chunk_pattern.dart](packages/runner_core/lib/track/chunk_pattern.dart)
  - [packages/runner_core/lib/track/chunk_builder.dart](packages/runner_core/lib/track/chunk_builder.dart)
  - [packages/runner_core/lib/track/track_streamer.dart](packages/runner_core/lib/track/track_streamer.dart)
  - [packages/runner_core/lib/collision/static_world_geometry.dart](packages/runner_core/lib/collision/static_world_geometry.dart)
- [ ] Record baseline green:
  - [ ] `dart analyze`
  - [ ] `cd tools/editor && dart analyze`
  - [ ] `cd tools/editor && flutter test`
  - [ ] `flutter test`

Done when:

- [ ] assumptions are validated before edits start
- [ ] baseline is green before runtime/editor changes

## Step 0 - Contract Freeze for Runtime Solids

Objective:

- freeze the runtime handoff contract before changing editor or generator logic

Tasks:

- [ ] Define `SolidRel` in
      [packages/runner_core/lib/track/chunk_pattern.dart](packages/runner_core/lib/track/chunk_pattern.dart).
- [ ] Freeze `SolidRel` fields:
  - [ ] `x`
  - [ ] `aboveGroundTop`
  - [ ] `width`
  - [ ] `height`
  - [ ] `sides`
  - [ ] `oneWayTop`
- [ ] Freeze prefab-kind mapping rules:
  - [ ] platform collider -> `sideTop`, `oneWayTop: true`
  - [ ] obstacle collider -> `sideAll`, `oneWayTop: false`
- [ ] Freeze migration policy:
  - [ ] keep legacy `platforms` / `obstacles` temporarily
  - [ ] move prefab-generated collision to `solids`
  - [ ] remove legacy prefab export path only after parity tests pass
- [ ] Update the source plan if the final `SolidRel` field names or migration
      strategy differ from the proposed doc.

Done when:

- [ ] `SolidRel` shape is fixed before implementation begins
- [ ] no later pass needs to infer side-mask semantics ad hoc

## Pass 1 - Runtime Contract and Builder Support

Objective:

- teach runtime chunk building to consume generated solids without changing the
  collision engine

Primary files:

- [packages/runner_core/lib/track/chunk_pattern.dart](packages/runner_core/lib/track/chunk_pattern.dart)
- [packages/runner_core/lib/track/chunk_builder.dart](packages/runner_core/lib/track/chunk_builder.dart)
- [packages/runner_core/lib/track/track_streamer.dart](packages/runner_core/lib/track/track_streamer.dart)

Tasks:

- [ ] Add `solids` to `ChunkPattern`.
- [ ] Keep existing `platforms` and `obstacles` paths compiling during the
      staged migration.
- [ ] Update `chunk_builder.dart` to build `StaticSolid`s from `SolidRel`.
- [ ] Preserve stable author order when appending built solids.
- [ ] Reuse current bounds/snap/positive-size validation rules where possible.
- [ ] Verify `TrackStreamer` and downstream consumers do not require extra
      behavior changes beyond the new `ChunkPattern` field.

Tests:

- [ ] extend [test/core/chunk_builder_validation_test.dart](test/core/chunk_builder_validation_test.dart)
      for `SolidRel`
- [ ] extend [test/core/track_streaming_test.dart](test/core/track_streaming_test.dart)
      if pattern flattening/order changes
- [ ] run relevant root tests for touched track/runtime files

Done when:

- [ ] generated or hand-authored `solids` are consumable by runtime
- [ ] collision build order is deterministic and test-covered
- [ ] no Flame-layer change is required for the new runtime path

## Pass 2 - Generator Fidelity Cutover

Objective:

- stop collapsing authored collider lists into one bounds box

Primary files:

- [tool/generate_chunk_runtime_data.dart](tool/generate_chunk_runtime_data.dart)
- generated:
  [packages/runner_core/lib/track/authored_chunk_patterns.dart](packages/runner_core/lib/track/authored_chunk_patterns.dart)

Tasks:

- [ ] Replace union-bounds collision export with per-collider export.
- [ ] Apply per-collider transform rules:
  - [ ] placement position
  - [ ] anchor-relative offset
  - [ ] scale
  - [ ] `flipX`
  - [ ] `flipY`
- [ ] Snap each transformed collider rectangle to runtime grid individually.
- [ ] Export obstacle prefab colliders as solid collision entries.
- [ ] Export platform prefab colliders as one-way solid collision entries.
- [ ] Keep decoration prefab export collision-free.
- [ ] Preserve visual sprite export behavior unchanged.
- [ ] Regenerate runtime chunk data after the generator change.

Tests:

- [ ] extend [test/tool/generate_chunk_runtime_data_test.dart](test/tool/generate_chunk_runtime_data_test.dart)
      with multi-collider obstacle cases
- [ ] extend [test/tool/generate_chunk_runtime_data_test.dart](test/tool/generate_chunk_runtime_data_test.dart)
      with multi-collider platform cases
- [ ] add flip/scale parity cases
- [ ] run `dart run tool/generate_chunk_runtime_data.dart --dry-run`

Done when:

- [ ] prefab collider count equals generated runtime solid count
- [ ] no union-bounds fallback remains for prefab collision export
- [ ] generated Dart output is deterministic and reviewable

## Pass 3 - Editor Data and State Lift

Objective:

- replace single-collider editor state with collider-list-aware state

Primary files:

- [tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_scene_values.dart](tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_scene_values.dart)
- [tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_form_state.dart](tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_form_state.dart)
- [tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_editor_prefab_controller.dart](tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_editor_prefab_controller.dart)
- [tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_editor_page_coordinator.dart](tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_editor_page_coordinator.dart)
- [tools/editor/lib/src/prefabs/store/prefab_determinism.dart](tools/editor/lib/src/prefabs/store/prefab_determinism.dart)
- [tools/editor/lib/src/prefabs/validation/prefab_validation.dart](tools/editor/lib/src/prefabs/validation/prefab_validation.dart)

Tasks:

- [ ] Replace `PrefabSceneValues` single-collider projection with collider-list
      state plus selected-collider identity/index.
- [ ] Update `PrefabFormState` so obstacle/platform forms own collider-list
      draft data instead of only four collider text fields.
- [ ] Keep anchor editing explicit and shared across collider edits.
- [ ] Update `PrefabEditorPrefabController.buildUpsertPrefab` to round-trip the
      full collider list.
- [ ] Update prefab load projection to preserve all colliders, not only the
      first entry.
- [ ] Ensure default obstacle/platform create flows seed a valid initial
      collider list.
- [ ] Keep decoration create/load/save behavior collider-free.
- [ ] Preserve deterministic collider ordering through store normalization.

Tests:

- [ ] extend [tools/editor/test/prefab_store_test.dart](tools/editor/test/prefab_store_test.dart)
      for multi-collider round-trip
- [ ] extend [tools/editor/test/prefab_validation_test.dart](tools/editor/test/prefab_validation_test.dart)
      for multi-collider validation behavior
- [ ] extend [tools/editor/test/prefab_creator_page_test.dart](tools/editor/test/prefab_creator_page_test.dart)
      for load/save/edit flows

Done when:

- [ ] obstacle/platform prefab editing no longer truncates to the first collider
- [ ] load -> edit -> save preserves full collider lists
- [ ] deterministic store ordering remains intact

## Pass 4 - Editor Scene and UI Cleanup

Objective:

- make multi-collider authoring usable in the prefab scene and inspector

Primary files:

- [tools/editor/lib/src/app/pages/prefabCreator/obstacle_prefabs/obstacle_prefabs_tab.dart](tools/editor/lib/src/app/pages/prefabCreator/obstacle_prefabs/obstacle_prefabs_tab.dart)
- [tools/editor/lib/src/app/pages/prefabCreator/platform_prefabs/platform_prefabs_tab.dart](tools/editor/lib/src/app/pages/prefabCreator/platform_prefabs/platform_prefabs_tab.dart)
- [tools/editor/lib/src/app/pages/prefabCreator/obstacle_prefabs/widgets/prefab_scene_view.dart](tools/editor/lib/src/app/pages/prefabCreator/obstacle_prefabs/widgets/prefab_scene_view.dart)
- [tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_overlay_interaction.dart](tools/editor/lib/src/app/pages/prefabCreator/shared/prefab_overlay_interaction.dart)

Tasks:

- [ ] Add collider-list controls to obstacle/platform prefab inspectors:
  - [ ] add collider
  - [ ] duplicate collider
  - [ ] delete collider
  - [ ] select collider
- [ ] Draw all colliders in the scene overlay.
- [ ] Restrict drag handles to the selected collider.
- [ ] Preserve current anchor drag behavior and shared scene-control semantics.
- [ ] Ensure local draft history / undo-redo treats collider-list operations as
      coherent changes.
- [ ] Remove obsolete single-collider helpers and dead UI paths after the new
      scene flow is stable.

Tests:

- [ ] extend [tools/editor/test/prefab_overlay_interaction_test.dart](tools/editor/test/prefab_overlay_interaction_test.dart)
      for selected-collider drag behavior
- [ ] extend [tools/editor/test/scene_control_parity_test.dart](tools/editor/test/scene_control_parity_test.dart)
      if scene input paths change
- [ ] extend [tools/editor/test/prefab_creator_page_test.dart](tools/editor/test/prefab_creator_page_test.dart)
      for add/select/remove collider flows

Done when:

- [ ] designers can visually author multiple colliders without hand-editing JSON
- [ ] no hidden single-collider scene path remains
- [ ] editor interaction rules remain consistent with shared scene controls

## Regression and Validation Sweep

Tasks:

- [x] run `cd tools/editor && dart analyze`
- [x] run `cd tools/editor && flutter test`
- [x] run `dart run tool/generate_chunk_runtime_data.dart --dry-run`
- [x] run relevant root runtime tests for touched track/generator code
- [x] inspect generated diff for deterministic ordering and unexpected churn
- [ ] verify at least one representative authored obstacle prefab and one
      platform prefab with multiple colliders through generation output.
      Obstacle prefab authoring now exists, but current chunk JSONs do not yet
      place those prefabs and there is still no committed multi-collider
      platform prefab.

Done when:

- [x] editor, generator, and runtime seams are validated together
- [x] generated output is stable and no accidental contract drift remains

## Docs Close-out

Tasks:

- [x] update
      [docs/building/editor/chunkCreator/prefab-multi-rect-collision-plan.md](docs/building/editor/chunkCreator/prefab-multi-rect-collision-plan.md)
      with any contract decisions made during implementation
- [x] add completion notes or a closure summary if this work lands across
      multiple PRs
- [x] update any related runtime-handoff docs if `SolidRel` changes broader
      chunk contract assumptions

Done when:

- [x] implementation docs and final contract match shipped behavior
