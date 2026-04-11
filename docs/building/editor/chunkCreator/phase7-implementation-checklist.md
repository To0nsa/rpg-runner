# Chunk Creator Phase 7 - Level Assembly + Render Theme Sequencing Implementation Checklist

Date: April 11, 2026  
Status: Planned  
Source plan: [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md)

This checklist turns Phase 7 of the chunk creator plan into an execution
sequence with concrete contract decisions, file targets, runtime boundaries,
and test gates.

## Goal

Ship Phase 7 end-to-end:

- non-dev user can define per-level chunk assembly runs entirely in-editor
- chunk files carry explicit assembly membership metadata without overloading
  freeform `tags`
- Chunk Creator inspector exposes the chunk theme/group field directly
- Chunk Creator chunk list can be filtered by theme/group through a text input
- level assembly can request deterministic seeded runs such as:
  - `cemetery` with an authored range initially seeded to `2..5`
  - `none` with an authored range initially seeded to `4..10`
  - `village` with an authored range initially seeded to `2..5`
- render-theme sequencing is explicit and render-only
- runtime chunk selection stays deterministic while consuming authored assembly
  constraints
- explicit `none` theme behavior exists and does not rely on `null` fallback
  behavior
- default segment-count ranges are only initial editor suggestions by segment
  theme mode; the authored `minChunkCount` / `maxChunkCount` remain fully
  editable in the Level Creator
- levels with no authored assembly configuration keep current runtime behavior

## Phase 7 Gate (must pass)

- assembled level definitions reference only valid chunk groups for that level
- authored segment ordering and chunk-count range rules are deterministic
- authored `requireDistinctChunks` rules are enforced or blocked with explicit
  diagnostics
- runtime chunk selection/ordering consumes authored assembly constraints
  deterministically, including seeded count selection inside authored ranges
- runtime render theme override resolves as `level_default`, explicit `theme`,
  or explicit `none` without changing gameplay authority
- save/generate/load flows remain deterministic and test-covered

## Scope Boundaries for Phase 7

In scope:

- level-scoped assembly definitions in
  `assets/authoring/level/level_defs.json`
- chunk-scoped assembly membership metadata in
  `assets/authoring/level/chunks/**/*.json`
- chunk editor metadata support for assembly membership
- level creator support for segment sequencing
- generator/runtime bridge for assembly metadata and theme sequencing
- deterministic segment scheduler for chunk selection
- render-only theme override propagation to snapshot/render consumers

Out of scope in this phase:

- sockets, neighbor constraints, or transition matrices
- freeform adjacency graph authoring
- gameplay tuning/spawn/collision changes driven by render theme
- parallax asset authoring itself (Phase 10 already owns that)
- simulation/fairness overlays (Phase 8)
- cross-fade or blend effects between themes unless required for correctness

## Current Gaps to Close

Current baseline gaps that Phase 7 must close:

- chunk files currently have `difficulty` and `tags`, but no dedicated assembly
  membership field
- chunk list has no theme/group filter for narrowing visible chunks during
  authoring
- level definitions currently carry level metadata only; there is no authored
  segment scheduler
- runtime chunk selection is still tier-based list selection with no segment
  sequencing in
  [packages/runner_core/lib/track/chunk_pattern_source.dart](packages/runner_core/lib/track/chunk_pattern_source.dart)
- runtime theme is currently level-scoped, not dynamically overridden by active
  chunk sequence
- `null`/unknown theme currently falls back to default parallax theme instead
  of an explicit `none` render mode
- editor has no UI for level assembly sequencing

## Locked Invariants

- Sockets stay out of the live chunk contract.
- Do not overload chunk `tags` for assembly membership; use a dedicated field.
- Level assembly source of truth lives with level definitions; chunk membership
  source of truth lives with chunk definitions.
- Render theme sequencing remains render-only:
  - no influence on spawn, collision, traversal, streaming margins, or other
    deterministic gameplay authority
  - gameplay authority remains in `runner_core`
- `none` is an explicit authored mode, not `null`, empty string, or unknown
  theme fallback.
- Segment count ranges are explicit:
  - default `none` range is `4..10` only as an editor-initialized suggestion
  - default themed range (`theme` or `level_default`) is `2..5` only as an
    editor-initialized suggestion
  - authored `minChunkCount` / `maxChunkCount` are fully editable per segment
    in the Level Creator
  - those defaults are not hard caps and are not runtime-enforced ranges unless
    the authored segment keeps them
  - validation requires positive integers and `minChunkCount <= maxChunkCount`
- Levels without authored assembly configuration preserve current tier-based
  chunk selection and current level `themeId` behavior.
- Distinctness requirements are blocking:
  - if a segment requests `requireDistinctChunks = true`, the authored level
    must provide at least `maxChunkCount` eligible active chunks in that
    assembly group
- Active render theme resolution for gameplay snapshots must use one explicit
  deterministic anchor rule (for example, the chunk covering camera center X);
  no ad-hoc renderer-local switching logic.
- Assembly sequencing may influence which authored chunk pattern is selected,
  but theme resolution itself must not change deterministic gameplay outcomes.
- Actual chunk count for a segment run is chosen once, deterministically, when
  that segment starts (for example from `seed + segmentIndex + loopCount`), and
  then held fixed for the duration of that segment run.

## Pre-flight

- [ ] Re-read Phase 7 in
      [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md).
- [ ] Confirm current chunk-editor baseline in:
  - [tools/editor/lib/src/chunks/chunk_domain_models.dart](tools/editor/lib/src/chunks/chunk_domain_models.dart)
  - [tools/editor/lib/src/chunks/chunk_store.dart](tools/editor/lib/src/chunks/chunk_store.dart)
  - [tools/editor/lib/src/chunks/chunk_validation.dart](tools/editor/lib/src/chunks/chunk_validation.dart)
  - [tools/editor/lib/src/chunks/chunk_domain_plugin.dart](tools/editor/lib/src/chunks/chunk_domain_plugin.dart)
  - [tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart](tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart)
- [ ] Confirm current level-editor baseline in:
  - [tools/editor/lib/src/levels/level_domain_models.dart](tools/editor/lib/src/levels/level_domain_models.dart)
  - [tools/editor/lib/src/levels/level_store.dart](tools/editor/lib/src/levels/level_store.dart)
  - [tools/editor/lib/src/levels/level_validation.dart](tools/editor/lib/src/levels/level_validation.dart)
  - [tools/editor/lib/src/levels/level_domain_plugin.dart](tools/editor/lib/src/levels/level_domain_plugin.dart)
  - [tools/editor/lib/src/app/pages/levelCreator/level_creator_page.dart](tools/editor/lib/src/app/pages/levelCreator/level_creator_page.dart)
- [ ] Confirm current runtime/theme baseline in:
  - [packages/runner_core/lib/levels/level_definition.dart](packages/runner_core/lib/levels/level_definition.dart)
  - [packages/runner_core/lib/track/chunk_pattern.dart](packages/runner_core/lib/track/chunk_pattern.dart)
  - [packages/runner_core/lib/track/chunk_pattern_source.dart](packages/runner_core/lib/track/chunk_pattern_source.dart)
  - [packages/runner_core/lib/track/track_streamer.dart](packages/runner_core/lib/track/track_streamer.dart)
  - [packages/runner_core/lib/game_core.dart](packages/runner_core/lib/game_core.dart)
  - [packages/runner_core/lib/snapshot_builder.dart](packages/runner_core/lib/snapshot_builder.dart)
  - [lib/game/themes/parallax_theme_registry.dart](lib/game/themes/parallax_theme_registry.dart)
  - [lib/game/runner_flame_game.dart](lib/game/runner_flame_game.dart)
  - [lib/ui/assets/ui_asset_lifecycle.dart](lib/ui/assets/ui_asset_lifecycle.dart)
- [ ] Record baseline green:
  - [ ] `dart analyze`
  - [ ] `cd tools/editor && dart analyze`
  - [ ] `flutter test`

Done when:

- [ ] assumptions are validated
- [ ] baseline is green before Phase 7 code changes

## Step 0 - Contract Freeze for Assembly Groups + Render Theme Modes

Objective:

- freeze the Phase 7 data model before touching editor/runtime code

Tasks:

- [ ] Keep sockets out of the contract and out of the UI for this phase.
- [ ] Freeze dedicated chunk membership field name (recommended:
      `assemblyGroupId`) and do not reuse `tags`.
- [ ] Freeze level assembly shape in `level_defs.json`:
  - [ ] `assembly.segments[]`
  - [ ] `segmentId`
  - [ ] `groupId`
  - [ ] `minChunkCount`
  - [ ] `maxChunkCount`
  - [ ] `requireDistinctChunks`
  - [ ] `renderTheme.mode` (`level_default | theme | none`)
  - [ ] `renderTheme.themeId` when `mode = theme`
  - [ ] explicit segment loop/restart policy
- [ ] Freeze explicit `none` semantics:
  - [ ] choose one exact runtime rule for `none` across the full render stack
        (`background`, `ground`, `foreground`)
  - [ ] `none` must not resolve through default fallback theme behavior
  - [ ] document whether `none` is implemented as:
        - no parallax/ground/foreground components mounted, or
        - an explicit authored empty theme
  - [ ] do not allow mixed semantics between backdrop and ground layers
- [ ] Freeze default count ranges by render-theme mode:
  - [ ] `none` segments default to `4..10` only as initial editor values
  - [ ] themed segments default to `2..5` only as initial editor values
  - [ ] editor allows fully editing `minChunkCount` / `maxChunkCount` per
        segment after initialization
  - [ ] no hidden runtime clamp keeps authored ranges near the defaults
- [ ] Freeze behavior for levels with no `assembly` block:
  - [ ] current chunk tier selection remains in effect
  - [ ] level `themeId` remains the effective render theme
- [ ] Freeze deterministic active-theme anchor rule for runtime snapshots.
- [ ] Freeze deterministic chunk-count draw rule for each segment run.
- [ ] Freeze runtime theme-switch application rule:
  - [ ] theme changes are applied by explicit component remount/rebind, not by
        hoping the initially mounted Flame backdrop picks up new snapshot data
- [ ] Freeze asset-loading policy for segment themes:
  - [ ] either preload all reachable segment themes at run start, or
  - [ ] define an accepted first-use loading/hitch policy explicitly
- [ ] Freeze failure behavior when distinct-chunk requirements cannot be
      satisfied: blocking validation/generation error.

Done when:

- [ ] Phase 7 data contract is unambiguous
- [ ] no unresolved `none` theme semantics remain
- [ ] no unresolved no-assembly fallback behavior remains

## Step 1 - Extend Chunk Contracts With Assembly Membership

Objective:

- add dedicated assembly membership to chunk authoring contracts and editor
  flows, including chunk-list filtering

Tasks:

- [ ] Update
      [tools/editor/lib/src/chunks/chunk_domain_models.dart](tools/editor/lib/src/chunks/chunk_domain_models.dart):
  - [ ] add `assemblyGroupId` to `LevelChunkDef`
  - [ ] keep `fromJson` tolerant for legacy chunk files missing the field
  - [ ] keep `toJson` canonical and deterministic
- [ ] Update
      [tools/editor/lib/src/chunks/chunk_store.dart](tools/editor/lib/src/chunks/chunk_store.dart):
  - [ ] load missing `assemblyGroupId` with deterministic default
  - [ ] preserve canonical JSON key order on save
- [ ] Update
      [tools/editor/lib/src/chunks/chunk_validation.dart](tools/editor/lib/src/chunks/chunk_validation.dart):
  - [ ] validate non-empty stable identifier shape
  - [ ] validate level-scoped group usage rules as needed
- [ ] Update
      [tools/editor/lib/src/chunks/chunk_domain_plugin.dart](tools/editor/lib/src/chunks/chunk_domain_plugin.dart)
      to support editing `assemblyGroupId`.
- [ ] Update
      [tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart](tools/editor/lib/src/app/pages/chunkCreator/chunk_creator_page.dart):
  - [ ] expose `assemblyGroupId` in chunk inspector metadata UI
  - [ ] give the field a clear user-facing label aligned with theme/group
        terminology
  - [ ] add a chunk-list text filter that filters visible chunks by
        `assemblyGroupId`
  - [ ] keep filter behavior deterministic and case-normalized
  - [ ] keep editing deterministic and safe-write compatible

Done when:

- [ ] chunk files can carry dedicated assembly membership without JSON edits
- [ ] missing-field migration is deterministic
- [ ] chunk save/load round-trip preserves assembly membership cleanly
- [ ] author can narrow chunk list by theme/group from the Chunk Creator list
      pane

## Step 2 - Extend Level Contracts With Segment Sequencing

Objective:

- add level-scoped assembly sequencing to authored level definitions

Tasks:

- [ ] Update
      [tools/editor/lib/src/levels/level_domain_models.dart](tools/editor/lib/src/levels/level_domain_models.dart):
  - [ ] add typed assembly models (for example `LevelAssemblyDef`,
        `LevelAssemblySegmentDef`, `LevelRenderThemeModeDef`)
  - [ ] keep canonical ordering and deterministic normalization
- [ ] Update
      [tools/editor/lib/src/levels/level_store.dart](tools/editor/lib/src/levels/level_store.dart)
      for load/save support.
- [ ] Update
      [tools/editor/lib/src/levels/level_validation.dart](tools/editor/lib/src/levels/level_validation.dart):
  - [ ] segment references unknown `groupId`
  - [ ] invalid `minChunkCount` / `maxChunkCount`
  - [ ] `minChunkCount > maxChunkCount`
  - [ ] invalid `renderTheme.mode`
  - [ ] missing `themeId` when `mode = theme`
  - [ ] unknown parallax theme references
  - [ ] `requireDistinctChunks` asks for more chunks than the group contains
        at `maxChunkCount`
- [ ] Update
      [tools/editor/lib/src/levels/level_domain_plugin.dart](tools/editor/lib/src/levels/level_domain_plugin.dart)
      with segment CRUD/reorder/update commands.
- [ ] Update
      [tools/editor/lib/src/app/pages/levelCreator/level_creator_page.dart](tools/editor/lib/src/app/pages/levelCreator/level_creator_page.dart):
  - [ ] add assembly segment list UI
  - [ ] support create/edit/delete/reorder segments
  - [ ] expose editable `minChunkCount` / `maxChunkCount`
  - [ ] initialize count-range defaults from render-theme mode only as starting
        values
  - [ ] allow editing to any valid positive range without mode-based caps
  - [ ] expose render-theme mode controls
  - [ ] show helpful availability counts for chunk groups in the selected level

Done when:

- [ ] non-dev user can author assembly segments in the Level Creator
- [ ] validation blocks impossible segment plans before export
- [ ] `level_defs.json` round-trips deterministically with assembly data

## Step 3 - Generator Bridge for Assembly Metadata and Theme Sequencing

Objective:

- emit deterministic runtime contracts for chunk assembly and render-theme
  sequencing

Tasks:

- [ ] Update
      [tool/generate_chunk_runtime_data.dart](tool/generate_chunk_runtime_data.dart):
  - [ ] load chunk `assemblyGroupId`
  - [ ] thread assembly metadata into generated runtime output
- [ ] Update
      [tool/level_definition_generation.dart](tool/level_definition_generation.dart):
  - [ ] load/render level assembly contract from `level_defs.json`
  - [ ] emit deterministic generated runtime output for assembly segments
- [ ] Extend generated runtime contracts as needed:
  - [ ] [packages/runner_core/lib/track/chunk_pattern.dart](packages/runner_core/lib/track/chunk_pattern.dart)
        gets assembly metadata or equivalent runtime lookup support
  - [ ] [packages/runner_core/lib/levels/level_definition.dart](packages/runner_core/lib/levels/level_definition.dart)
        gets typed assembly configuration or equivalent scheduler input
- [ ] Keep no-assembly levels behavior-equivalent to current runtime.
- [ ] Keep output serialization stable and snapshot-testable.

Done when:

- [ ] generated runtime data contains all information required for Phase 7
- [ ] levels without assembly config still generate current-equivalent output
- [ ] generator output is deterministic for same authored input

## Step 4 - Deterministic Runtime Segment Scheduler

Objective:

- replace the current tier-only chunk selection seam with a deterministic
  scheduler that respects authored assembly segments

Tasks:

- [ ] Extend or replace the selection seam in
      [packages/runner_core/lib/track/chunk_pattern_source.dart](packages/runner_core/lib/track/chunk_pattern_source.dart):
  - [ ] resolve current segment by authored sequence and chunk index
  - [ ] choose segment run length deterministically from `minChunkCount` to
        `maxChunkCount`
  - [ ] filter eligible patterns by `assemblyGroupId`
  - [ ] keep tier requests (`early/easy/normal/hard`) compatible with segment
        filtering
- [ ] Update
      [packages/runner_core/lib/track/track_streamer.dart](packages/runner_core/lib/track/track_streamer.dart):
  - [ ] consume segment-aware pattern source/scheduler
  - [ ] preserve deterministic behavior for same seed and authored inputs
  - [ ] expose enough metadata to derive active render-theme override
- [ ] Define deterministic duplicate handling inside a segment:
  - [ ] honor `requireDistinctChunks = true`
  - [ ] define explicit fallback/error behavior when eligible pool is exhausted
- [ ] Define deterministic segment looping/restart behavior for long runs.

Done when:

- [ ] chunk selection obeys authored segment order and seeded chunk-count ranges
- [ ] distinctness rules are deterministic and test-covered
- [ ] no unintended gameplay behavior drift is introduced for no-assembly levels

## Step 5 - Runtime Render Theme Override Path

Objective:

- make authored assembly segments drive runtime render theme changes without
  leaking into gameplay authority

Tasks:

- [ ] Update runtime state ownership:
  - [ ] [packages/runner_core/lib/game_core.dart](packages/runner_core/lib/game_core.dart)
        resolves effective render-theme override from active assembly segment
  - [ ] [packages/runner_core/lib/snapshot_builder.dart](packages/runner_core/lib/snapshot_builder.dart)
        writes effective theme to `GameStateSnapshot`
- [ ] Update render theme resolution:
  - [ ] [lib/game/themes/parallax_theme_registry.dart](lib/game/themes/parallax_theme_registry.dart)
        supports explicit `none` semantics
  - [ ] [lib/game/runner_flame_game.dart](lib/game/runner_flame_game.dart)
        handles theme changes and `none` cleanly at runtime
  - [ ] define explicit mount/update lifecycle for:
        - `PixelParallaxBackdrop`
        - `GroundSurface`
        - `GroundBandParallaxForeground`
  - [ ] ensure mid-run theme changes rebuild or rebind those components
        deterministically when `snapshot.themeId` changes
- [ ] Keep render-theme override behavior explicit:
  - [ ] `level_default` uses level `themeId`
  - [ ] `theme` uses authored override
  - [ ] `none` follows the exact Step 0 rule for background/ground/foreground
- [ ] Update run-start / mid-run asset loading:
  - [ ] [lib/ui/assets/ui_asset_lifecycle.dart](lib/ui/assets/ui_asset_lifecycle.dart)
        preloads all authored segment themes reachable for the selected level,
        or explicitly implements the chosen fallback policy
  - [ ] no hidden dependency remains on only the initial level theme being
        warmed at run start
- [ ] Ensure theme changes do not influence chunk geometry, spawns, collision,
      or traversal decisions.

Done when:

- [ ] runtime can switch render themes by authored segment sequence
- [ ] explicit `none` works without fallback bleed-through
- [ ] runtime theme switches rebuild/rebind the full render stack correctly
- [ ] asset loading behavior for reachable segment themes is explicit and
      test-covered
- [ ] gameplay deterministic state remains independent from render theme logic

## Step 6 - Validation, Tests, and Documentation Hardening

Objective:

- lock the phase with regression coverage and documentation updates

Tasks:

- [ ] Add editor tests:
  - [ ] chunk `assemblyGroupId` load/save round-trip
  - [ ] level assembly segment CRUD/reorder determinism
  - [ ] validation for unknown groups, invalid count ranges, and impossible
        distinct-count requests
- [ ] Add generator tests:
  - [ ] authored chunk/level assembly -> generated runtime output parity
  - [ ] explicit `none` render-theme serialization/output behavior
  - [ ] stable generated snapshots
- [ ] Add runtime tests:
  - [ ] deterministic segment scheduler selection and range-resolved counts
  - [ ] no-assembly levels preserve current behavior
  - [ ] active theme override follows authored segment order
  - [ ] `none` theme produces no render-theme override visuals
  - [ ] theme changes remount/rebind the runtime render stack correctly
  - [ ] reachable segment themes are warmed according to the chosen asset-load
        policy
- [ ] Add regression coverage that gameplay determinism is unchanged except for
      the intended authored chunk-selection policy.
- [ ] Update docs:
  - [ ] [docs/building/editor/chunkCreator/plan.md](docs/building/editor/chunkCreator/plan.md)
        status and next slice
  - [ ] any touched editor/runtime `AGENTS.md` files if ownership boundaries
        drift

Done when:

- [ ] Phase 7 gate is covered by focused tests
- [ ] docs match shipped behavior
- [ ] no unresolved contract ambiguity remains

## Suggested Acceptance Test Scenario

Use one representative authored level with:

- group `cemetery` containing at least 5 active chunks
- group `none` containing at least 10 active chunks
- group `village` containing at least 5 active chunks
- authored segment order:
  - `cemetery` with a user-edited range (example starts at `2..5`)
  - `none` with a user-edited range (example starts at `4..10`)
  - `village` with a user-edited range (example starts at `2..5`)

Acceptance expectations:

- [ ] first segment resolves a deterministic count in `2..5` and all selected
      chunks come only from `cemetery`
- [ ] next segment resolves a deterministic count in `4..10` and all selected
      chunks come only from `none`
- [ ] next segment resolves a deterministic count in `2..5` and all selected
      chunks come only from `village`
- [ ] render theme is `cemetery` during the first segment
- [ ] render theme is explicit `none` during the break segment
- [ ] render theme is `village` during the final segment
- [ ] transition into and out of `none` updates background, ground, and
      foreground consistently according to the frozen `none` rule
- [ ] transition into `village` after `none` does not rely on stale starting
      theme components
- [ ] repeated run with same seed yields the same chunk-count and theme sequence
