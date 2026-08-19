# Windows Chunk Playtest Phase 0 Implementation Checklist

Date: August 19, 2026

Status: Complete with accepted baseline exceptions (August 19, 2026)

Source plan: [Windows Chunk Playtest and Reusable Desktop Input Plan](plan.md)

Characterization record: [Phase 0 Characterization](phase0-characterization.md)

Accepted closeout exceptions:

- root `dart analyze` is blocked by six pre-existing errors in a Firebase CLI
  Dart template under `functions/node_modules`; scoped root/Core/editor analysis
  passes
- the full editor suite has one reproducible, unrelated terrain-material
  no-op-save failure while 508 tests pass; the required focused Chunk Creator
  and route tests pass
- the Windows release build and automated startup probe pass; interactive
  navigation/shortcut confirmation is deferred to the Phase 6 Windows
  acceptance pass

The user explicitly directed work to continue to Phase 1 on August 19, 2026,
accepting these recorded exceptions rather than expanding Phase 0 into
unrelated Firebase CLI or terrain-material work.

This checklist implements Phase 0 only: characterize the current input,
generator, and Chunk Creator state boundaries; freeze the first Windows
keyboard/mouse contract; and establish executable baselines before any runtime
or editor playtest architecture is changed.

Checkboxes describe required work, not current behavior. Do not mark a task
complete from inspection alone when it requires a test or command result.

## Phase 0 completion gate

Phase 0 is complete only when:

- current touch gesture-to-command behavior is characterized for every
  supported slot and `AbilityInputMode`
- `RunnerInputRouter` command ordering, aim commit, held-slot exclusivity, and
  cancel/release expectations have focused regression coverage
- the source-neutral semantic action names and fixed Windows gameplay bindings
  are represented by small contract-only types with exact tests
- gameplay input remains separate from host lifecycle actions such as Play,
  Stop, Restart, Pause, and Exit
- current generator output and polygon terrain signatures have executable
  byte/signature drift baselines
- current Chunk Creator local-draft, plugin-document, pending-diff, history,
  selection, tab, and viewport ownership is characterized
- Play entry blockers and Play/Edit restoration targets are explicit and
  testable before UI work begins
- root, Core, generator, and editor baseline checks pass on Windows
- no desktop event adapter, Core preview override, playtest host, or Play UI is
  introduced in this phase

## Scope boundaries

### In scope

- read-only architecture and dependency inventory
- characterization tests around existing behavior
- pure/source-neutral semantic action identifiers
- fixed Windows gameplay binding data and tests, without event handling
- explicit supported slot/input-mode matrix
- focus/cancel and host-lifecycle decision matrix
- generator dry-run and signature baseline evidence
- Chunk Creator readiness/restoration inventory and tests
- Phase 0 documentation and closure evidence

### Out of scope

- extracting `packages/runner_content_pipeline`
- changing generator output or source schemas
- adding `GameCore.chunkPlaytest` or a staged-terrain overlay catalog
- adding `RunnerActionDispatcher` behavior
- adding `KeyboardListener`, `FocusNode`, `MouseRegion`, or pointer-button
  handling for gameplay
- changing `GameOverlay` or touch control behavior except to add test seams that
  are demonstrably necessary for characterization
- adding `lib/playtest.dart` or a backend-free Flame host
- adding Play/Stop controls to Chunk Creator
- enabling keyboard/mouse in the shipping game
- changing run protocol, backend, rewards, replay, or leaderboard behavior

If characterization exposes a current bug, record it as a Phase 0 finding and
add a focused regression that demonstrates it. Fix it only when the fix is
required to make the baseline truthful and is approved as an explicit scope
change; do not silently redefine current behavior during characterization.

## Locked decisions inherited from the source plan

- `RunnerInputRouter` remains the only device-independent scheduler of
  tick-stamped gameplay commands.
- Touch and keyboard/mouse remain separate UI adapters.
- Equivalent device action streams must converge on one future semantic
  dispatcher.
- Host actions never become Core gameplay commands.
- Desktop input collection belongs on the Flutter UI side; Core remains pure
  Dart and the router remains free of keyboard/mouse/touch event types.
- Focus loss, app deactivation, pause, restart, stop, scheme change, and
  disposal will use one idempotent future `cancelAll` behavior.
- Play mode will accept plugin-owned unapplied changes but reject active
  gestures, open dialogs, and uncommitted local field/polygon drafts.
- Play mode will use the real Core/Flame path and will never write authoring or
  generated files merely to start a preview.
- The editor will consume a tooling-only playtest barrel; editor types will not
  enter `lib/runner.dart`.

## Expected Phase 0 file scope

Prefer modifying only these existing test areas plus the smallest new contract
files required by the checklist:

- `lib/game/input/**` for source-neutral semantic action identifiers only
- `lib/ui/input/desktop/**` for immutable default binding data only
- `test/runner_input_router_release_test.dart`
- `test/game_controller_input_test.dart`
- `test/ui/controls/runner_controls_overlay_radial_test.dart`
- a focused new `test/ui/hud/game/game_overlay_input_characterization_test.dart`
  when end-to-end touch routing cannot be proven at a smaller seam
- a focused new desktop-binding contract test under `test/ui/input/desktop/**`
- `test/tool/polygon_terrain_signature_probe_test.dart`
- `test/tool/generate_chunk_runtime_data_test.dart` only if the existing
  generator drift contract lacks a required assertion
- `tools/editor/test/chunk_authoring_workspace_test.dart`
- `tools/editor/test/home_route_plugin_switch_test.dart`
- this checklist and the source plan

Do not create placeholder production classes for later phases. In particular,
Phase 0 must not add an unused dispatcher, preview scenario, asset bundle, or
playtest widget just to reserve names.

## Step 0 — Pre-flight and baseline capture

Objective: establish the exact repository and Windows environment before
adding characterization coverage.

### Guidance and worktree safety

- [x] Re-read the applicable guidance before changes:
  - [x] root `AGENTS.md`
  - [x] `lib/AGENTS.md`
  - [x] `lib/game/AGENTS.md`
  - [x] `lib/ui/AGENTS.md`
  - [x] `packages/runner_core/AGENTS.md`
  - [x] `packages/runner_core/lib/AGENTS.md`
  - [x] `tools/editor/AGENTS.md`
  - [x] `docs/rules/code-documentation-policy.md`
- [x] Record `git status --short` and identify unrelated user-owned changes.
- [x] Confirm Phase 0 can avoid every unrelated modified file or explicitly
      stop for direction if a required test/code seam overlaps one.
- [x] Record the active Flutter version, Dart version, Windows version, and CPU
      architecture in the Phase 0 evidence section.
- [x] Confirm both the root game and `tools/editor` have Windows runners and
      identify the editor's baseline window size.

### Baseline commands

- [x] Run root `dart analyze` before Phase 0 edits.
- [x] Run `dart analyze packages/runner_core`.
- [x] Run the existing focused input tests:
  - [x] `flutter test test/runner_input_router_release_test.dart`
  - [x] `flutter test test/runner_input_router_aim_quantize_test.dart`
  - [x] `flutter test test/game_controller_input_test.dart`
  - [x] `flutter test test/core/hold_input_mode_snapshot_test.dart`
  - [x] `flutter test test/ui/controls/runner_controls_overlay_radial_test.dart`
- [x] Run the existing terrain/generator baselines:
  - [x] `flutter test test/tool/polygon_terrain_compilation_test.dart`
  - [x] `flutter test test/tool/polygon_terrain_render_test.dart`
  - [x] `flutter test test/tool/polygon_terrain_repository_generation_test.dart`
  - [x] `flutter test test/tool/polygon_terrain_signature_probe_test.dart`
  - [x] `dart run tool/generate_chunk_runtime_data.dart --dry-run`
- [x] Run the existing editor baselines:
  - [x] `cd tools/editor && dart analyze`
  - [x] `cd tools/editor && flutter test test/chunk_authoring_workspace_test.dart`
  - [x] `cd tools/editor && flutter test test/home_route_plugin_switch_test.dart`
- [x] Record pre-existing failures exactly; do not attribute them to Phase 0.

Done when:

- [x] environment and dirty-worktree ownership are recorded
- [x] every required baseline has a dated pass/fail result
- [x] there is no unexplained failure before characterization begins

## Step 1 — Inventory the current input pipeline

Objective: document the behavior that later extraction must preserve.

### Trace ownership

- [x] Trace and record the current touch path through:
  - [x] `GameOverlay`
  - [x] `RunnerControlsOverlay`
  - [x] `MovementControl`, `MeleeControl`, `ProjectileControl`,
        `HoldActionButton`, and `DirectionalActionButton`
  - [x] `RunnerInputRouter`
  - [x] `GameController` and `TickInputFrame`
  - [x] Core commands and replay command frames
- [x] Identify which layer currently owns:
  - [x] pointer down/up/cancel translation
  - [x] slot input-mode branching
  - [x] aim preview begin/update/end
  - [x] held-slot exclusivity
  - [x] same-tick aim plus action commit
  - [x] input clearing on pause/lifecycle/restart/dispose
- [x] Inventory every direct `RunnerInputRouter` call outside tests.
- [x] Confirm no widget or Flame component bypasses the router to enqueue Core
      commands directly.
- [x] Record current `GameWidget.autofocus` and game-route focus behavior.
- [x] Record all current `_clearInputs` callers in `RunnerGameWidget` and the
      exact held/aim state each clears.

### Supported slot/input-mode matrix

- [x] Build an explicit matrix for these slots:
  - [x] primary
  - [x] secondary
  - [x] projectile
  - [x] mobility
  - [x] spell
  - [x] jump
- [x] For primary, secondary, projectile, and mobility, record behavior for:
  - [x] `AbilityInputMode.tap`
  - [x] `AbilityInputMode.holdAimRelease`
  - [x] `AbilityInputMode.holdMaintain`
  - [x] `AbilityInputMode.holdRelease`
- [x] Distinguish an intentionally unsupported slot/mode combination from a
      fallback branch that happens to render another control.
- [x] Audit current ability catalogs and loadout validation to determine which
      combinations can occur in production today.
- [x] Record spell and jump as explicit tap-only slots unless current authored
      content proves otherwise.
- [x] Freeze the action-edge sequence for every supported combination:
  - [x] pointer/button down
  - [x] held edge, if any
  - [x] aim updates, if any
  - [x] commit edge and its tick relationship to aim
  - [x] held release and aim clear
  - [x] cancel without commit
- [x] Resolve any ambiguous projectile `holdMaintain` behavior before Phase 3;
      do not preserve an accidental fallback as an undocumented contract.

Done when:

- [x] the current path and ownership can be understood without reconstructing
      it from several widgets
- [x] every production-reachable slot/input-mode combination has one expected
      edge sequence
- [x] unsupported combinations are explicit rather than silently inferred

## Step 2 — Add touch and router characterization tests

Objective: make the current input semantics executable before introducing a
shared dispatcher.

### Router-level characterization

- [x] Audit `test/runner_input_router_release_test.dart` against the matrix from
      Step 1; extend existing tests instead of duplicating equivalent cases.
- [x] Prove movement axis replacement overwrites buffered future ticks.
- [x] Prove aim replacement and aim clear overwrite buffered future ticks.
- [x] Prove aimed commit writes aim and action to the same tick.
- [x] Prove a post-commit clear cannot overwrite the commit tick.
- [x] Prove each held slot emits one start edge and one release edge rather than
      per-frame edges.
- [x] Prove starting a different held slot releases the previous slot on the
      same scheduled tick and latest hold wins.
- [x] Prove repeated start/end calls are idempotent.
- [x] Prove a complete clear sequence releases primary, secondary, mobility,
      and projectile held state and clears movement/aim.
- [x] Assert behavior through applied `ReplayCommandFrameV1` values where that
      is more stable than asserting downstream animation or damage.

### Touch-widget characterization

- [x] Extend `runner_controls_overlay_radial_test.dart` to verify callback edge
      sequences, not only control type/layout, for each supported input mode.
- [x] Verify pointer cancel differs from pointer release where commit behavior
      differs.
- [x] Verify an unaffordable or cooldown-blocked control does not emit gameplay
      callbacks.
- [x] Verify hidden secondary/projectile slots emit no callbacks.
- [x] Verify movement pointer transfer and release produce the expected axis
      sequence.
- [x] Add a focused `GameOverlay` characterization harness if callback-only
      tests cannot prove the current slot-mode-to-router mapping.
- [x] In the end-to-end harness, listen to applied replay command frames and
      verify equivalent touch sequences reach the router exactly once.
- [x] Keep tests deterministic: fixed Core seed, fixed tick rate, fixed player,
      fixed loadout, no wall-clock waits, and no backend/AppState dependency.

### Lifecycle characterization

- [x] Characterize input clearing when:
  - [x] a running game pauses
  - [x] app lifecycle leaves `resumed`
  - [x] restart begins
  - [x] exit confirmation opens
  - [x] the run ends or widget disposes
- [x] Prove clearing is safe when no input is held.
- [x] Record any missing current cancel path as a finding for Phase 3 rather
      than hiding it in test setup.

Done when:

- [x] tests fail if future dispatcher extraction changes a supported touch edge
      sequence
- [x] tests fail on duplicate commits, stale aim, or stuck held slots
- [x] tests require no keyboard/mouse implementation to pass

## Step 3 — Freeze semantic action and Windows binding contracts

Objective: define small reusable contracts without implementing a desktop event
source or dispatcher.

### Source-neutral semantic actions

- [x] Add the smallest pure/source-neutral semantic action representation
      needed by later adapters.
- [x] Include gameplay actions only:
  - [x] move left/right or an equivalent movement intent representation
  - [x] jump
  - [x] primary
  - [x] secondary
  - [x] projectile
  - [x] spell
  - [x] mobility
- [x] Keep aim as a directional value/update contract rather than four
      keyboard-only aim actions.
- [x] Exclude Play, Stop, Restart, Pause, Resume, Exit, and editor commands.
- [x] Do not import Flutter, keyboard, mouse, or touch types into the semantic
      action file.
- [x] Document only ownership/invariants required to prevent misuse; follow the
      repository documentation policy and avoid name-only comments.

### Immutable Windows binding data

- [x] Add a UI-side immutable default binding specification with no listeners,
      focus node, pressed-key set, or side effects.
- [x] Freeze the gameplay mapping from the source plan:
  - [x] `A` and Left Arrow -> move left
  - [x] `D` and Right Arrow -> move right
  - [x] `Space`, `W`, and Up Arrow -> jump
  - [x] Left Shift and Right Shift -> mobility
  - [x] Left Mouse Button and `J` -> primary
  - [x] Right Mouse Button and `K` -> projectile
  - [x] `Q` -> secondary
  - [x] `E` and `L` -> spell
- [x] Keep mouse-button bindings and keyboard bindings in explicitly named
      collections so Phase 3 does not infer device type from magic integers.
- [x] Keep host bindings (`F5`, `F6`, `Escape`, `P`, `Enter`) out of the
      gameplay binding specification.
- [x] Add exact tests for every default binding and alternate.
- [x] Add tests that one physical key/button does not map to two gameplay
      actions in the default set.
- [x] Add tests that left/right Shift are equivalent mobility bindings and
      opposing movement bindings remain distinct.
- [x] Do not add rebinding persistence, user settings, localization, or control
      hints in this phase.

Done when:

- [x] later touch and desktop adapters can share semantic names without device
      imports crossing the boundary
- [x] the Windows mapping is executable data with exact tests
- [x] no event is listened to and no Core command is scheduled by the new
      contract-only code

## Step 4 — Freeze focus, cancel, and host-lifecycle behavior

Objective: remove lifecycle ambiguity before the desktop adapter and Play UI
exist.

### Gameplay focus/cancel matrix

- [x] Record the required future behavior for:
  - [x] game surface receives focus
  - [x] pointer enters/leaves the fitted game viewport
  - [x] another editor field receives focus
  - [x] a modal editor dialog opens
  - [x] Windows app deactivates through Alt+Tab
  - [x] Windows app resumes
  - [x] playtest pauses/resumes
  - [x] playtest restarts
  - [x] playtest stops
  - [x] adapter/widget disposes
- [x] Freeze `cancelAll` as idempotent and complete: neutral movement, clear
      aim, release every held slot, end aim previews, and clear local pressed
      key/button state.
- [x] Freeze focus loss while running as cancel plus pause.
- [x] Freeze resume as explicit; merely regaining OS focus does not resume
      gameplay or restore old held keys.
- [x] Freeze pointer exit as aim clear; keyboard movement state is handled by
      focus, not by mouse hover.
- [x] Freeze viewport letterbox areas as non-aim regions.

### Editor host-action matrix

- [x] Freeze Edit-mode `F5` as Play only when:
  - [x] the Chunk route is active
  - [x] current-schema Chunk-v2 is loaded
  - [x] an active owner exists
  - [x] no text field or dialog owns the command
  - [x] no active gesture or uncommitted local draft exists
- [x] Freeze Play-mode `F5` and `Escape` as Stop/return to Edit.
- [x] Freeze Play-mode `F6` as deterministic restart from the same immutable
      scenario snapshot.
- [x] Freeze Play-mode `P` as pause/resume and `Enter` as ready-state start.
- [x] Freeze host actions as higher priority than gameplay actions only while
      the playtest host owns focus.
- [x] Confirm none of these host actions is represented by a Core command or
      gameplay binding.

Done when:

- [x] every focus/lifecycle transition has one expected cancel, pause, or
      no-op result
- [x] Edit-mode typing/dialog behavior cannot be intercepted by the future
      gameplay adapter
- [x] host and gameplay action ownership are unambiguous

## Step 5 — Characterize generator and runtime-content parity

Objective: establish the extraction baseline for Phase 1 without moving code.

### Generator ownership inventory

- [x] Inventory the current source-to-runtime path for:
  - [x] strict Prefab-v3 and Chunk-v2 decoding
  - [x] placed-Prefab expansion
  - [x] collision/render partitioning
  - [x] Core terrain compilation
  - [x] triangulation
  - [x] polygon, source, edge, placement, triangle, and seam signatures
  - [x] spawn marker projection
  - [x] visual sprite projection
  - [x] `ChunkPattern` rendering
  - [x] `StagedTerrainChunkData` rendering
- [x] Identify which code is repository I/O/CLI orchestration and must remain in
      `tool/` versus pure compilation suitable for Phase 1 extraction.
- [x] Record the exact generated target paths owned by
      `generate_chunk_runtime_data.dart`.
- [x] Confirm the editor parity test and generator use the same canonical
      authoring inputs today; record every current duplication.

### Executable parity baseline

- [x] Confirm `polygon_terrain_signature_probe_test.dart` binds all reviewed
      signature fields to checked-in fixture values.
- [x] Confirm two standalone Dart processes produce the same probe payload.
- [x] Confirm staged artifact rendering matches the checked-in golden fixture.
- [x] Confirm repository generation rejects partial output on any blocking
      parse/compile/scheduler/seam issue.
- [x] Confirm the repository dry-run compares every owned generated target and
      performs no writes.
- [x] Add missing assertions only where an extraction in Phase 1 could change
      bytes or signatures without failing an existing baseline.
- [x] Do not introduce a second digest manifest if checked-in generated files
      plus dry-run already provide exact byte comparison.

Done when:

- [x] Phase 1 can prove no generated byte/signature drift using existing or
      strengthened tests
- [x] pure compilation candidates and tool-only orchestration are separated in
      the inventory
- [x] no generator source has moved and no generated file has changed

## Step 6 — Characterize Chunk Creator readiness and restoration ownership

Objective: freeze what the future Play/Edit transition may read, block, and
restore.

### Document versus local draft

- [x] Characterize and test the distinction between:
  - [x] repository baseline document
  - [x] plugin-owned accepted in-memory document
  - [x] session pending file diff
  - [x] active pointer gesture preview
  - [x] open polygon creation/edit draft
  - [x] uncommitted inspector text
  - [x] open composition/owner dialog
- [x] Prove an accepted editor command can produce an unapplied pending document
      suitable for future snapshotting.
- [x] Prove an active gesture or field draft is not silently included as an
      accepted plugin document change.
- [x] Prove current reload/apply/route-switch guards observe local draft and
      pending document state through their existing owners.
- [x] Record the narrow API the future Play readiness calculation should read;
      do not add Play-specific state to the plugin in Phase 0.

### Restoration targets

- [x] Characterize current ownership and stable keys for:
  - [x] active level
  - [x] selected chunk owner
  - [x] active Terrain/Prefabs/Markers/Layers domain
  - [x] terrain/prefab/marker/edge selection
  - [x] pan and zoom
  - [x] grid, shape-edge, visual-preview, and marker-evidence toggles
  - [x] panel expansion state
  - [x] session undo/redo history
  - [x] pending diff and source baselines
- [x] Add focused tests for any restoration target whose ownership is currently
      implicit or unprotected by stable widget/state assertions.
- [x] Confirm the future playtest can replace only the workspace body without
      reconstructing `EditorSessionController` or reloading the plugin.
- [x] Confirm entering/exiting a future view-only mode must not increment chunk
      revision, add an undo entry, or alter pending files.

### Play readiness outcomes

- [x] Freeze deterministic readiness outcome categories for later UI use:
  - [x] ready
  - [x] unsupported platform/source generation
  - [x] no selected owner/level context
  - [x] active local operation or draft
  - [x] blocking validation issue
  - [x] preparation canceled/stale
- [x] Reuse existing validation issues and local-draft guards; do not invent a
      weaker page-local validator.
- [x] Record warnings as non-blocking and errors as blocking.
- [x] Keep workspace source-drift detection authoritative after Stop; Play does
      not reset or refresh source baselines.

Done when:

- [x] the future scenario builder has one immutable accepted document boundary
- [x] every Play blocker maps to existing authoritative state or a narrowly
      defined readiness result
- [x] every Edit state that must survive Play has an identified owner and test

## Step 7 — Phase 0 verification

Objective: prove Phase 0 added contracts/tests only and preserved current
behavior.

### Focused checks

- [x] Run `dart format` on changed Dart files.
- [x] Run `dart analyze packages/runner_core` if any Core-facing contract is
      touched.
- [x] Run root `dart analyze`.
- [x] Run all input tests changed or added in Steps 2–3.
- [x] Run existing touch-control regression tests.
- [x] Run `flutter test test/core/hold_input_mode_snapshot_test.dart`.
- [x] Run terrain/generator tests touched in Step 5.
- [x] Run `dart run tool/generate_chunk_runtime_data.dart --dry-run`.
- [x] Run `cd tools/editor && dart analyze`.
- [x] Run editor tests changed or added in Step 6.
- [x] Run `cd tools/editor && flutter test`; accept the recorded unrelated
      terrain-material baseline failure.

### Windows baseline

- [x] Run `cd tools/editor && flutter build windows`.
- [x] Launch the current editor build and record:
  - [x] startup succeeds
  - [x] defer manual Chunk Creator 1280x720 confirmation to Phase 6
  - [x] retain focused shortcut tests and defer manual shortcut confirmation to
        Phase 6
  - [x] no gameplay keyboard/mouse listener exists yet
- [x] Record any Windows-only analyzer/build/plugin warning with its disposition.

### Diff and boundary review

- [x] Run `git diff --check`.
- [x] Confirm generated outputs are unchanged.
- [x] Confirm authoring JSON is unchanged.
- [x] Confirm no Flutter/Flame import entered `runner_core`.
- [x] Confirm no keyboard/mouse/touch import entered the source-neutral semantic
      action contract.
- [x] Confirm no desktop module imports `lib/ui/controls/**`.
- [x] Confirm no touch control imports the desktop binding module.
- [x] Confirm no AppState, Firebase, replay, backend, or editor dependency was
      added to the contract-only input files.
- [x] Confirm public embedding exports are unchanged.
- [x] Confirm unrelated dirty-worktree changes remain untouched.

Done when:

- [x] every focused/full check required above passes or has an explicit approved
      exception
- [x] the diff contains only characterization tests, contract-only binding
      data, and documentation
- [x] Phase 1 can begin with the documented exceptions isolated from its scope

## Phase 0 evidence record

Complete this section during implementation; do not prefill results.

### Environment

- Windows version: Windows NT `10.0.26200.0` (Windows 11 25H2)
- CPU architecture: AMD64
- Flutter version: `3.41.7` stable (`cc0734ac71`), engine `59aa584fdf`
- Dart version: `3.11.5` on `windows_x64`
- Editor baseline window: 1280x720, confirmed from the Windows runner
- Worktree caveats: substantial terrain-material, staged-terrain, generated
  material, authoring JSON, editor, and documentation changes were already
  user-owned or appeared while Phase 0 ran. Phase 0 avoided those files. A
  user-started editor process was left running and untouched.

### Validation results

| Date | Command/test | Result | Notes |
| --- | --- | --- | --- |
| 2026-08-19 | root `dart analyze` (before and after) | Known failure | Same six errors in `functions/node_modules/firebase-tools/templates/init/functions/dart/server.dart`; missing template-only `firebase_functions` symbols |
| 2026-08-19 | `dart analyze lib test` | Pass | Phase 0 root app/test scope clean |
| 2026-08-19 | `dart analyze packages/runner_core` | Pass | Core remains clean and unchanged |
| 2026-08-19 | `cd tools/editor && dart analyze` | Pass | Editor source clean |
| 2026-08-19 | required pre-edit focused input tests | Pass, 38 tests | Sequential rerun after an initial concurrent Flutter build-directory collision |
| 2026-08-19 | changed plus existing input/touch tests | Pass, 55 tests | Includes binding exactness, router idempotence/neutralization, cancel paths, blocked controls, and production slot modes |
| 2026-08-19 | terrain/generator test set | Pass, 38 tests | Includes exact signature probe and two standalone process probes |
| 2026-08-19 | focused Chunk Creator and route tests | Pass, 31 tests | `chunk_authoring_workspace_test.dart` and `home_route_plugin_switch_test.dart` |
| 2026-08-19 | full editor `flutter test` | Baseline failure | 508 pass; `terrain_materials_page_test.dart:87` fails because a no-op save creates pending changes; isolated rerun reproduces it |
| 2026-08-19 | `flutter build windows` in editor | Pass | Release executable built in 84.6 seconds |
| 2026-08-19 | hidden release startup probe | Pass | Process remained alive for four seconds and was then stopped |
| 2026-08-19 | `git diff --check` | Pass | Only line-ending conversion warnings from the shared dirty worktree |

### Characterization findings

| ID | Finding | Resolution or later phase |
| --- | --- | --- |
| P0-1 | Projectile `holdMaintain` currently falls through to a directional widget but is not authored or production-reachable. | Phase 3 dispatcher rejects it explicitly; do not preserve the fallback. |
| P0-2 | Shipping `RunnerGameWidget` automatically resumes a lifecycle-paused run. | Editor Play mode remains paused after focus regain and requires explicit resume. |
| P0-3 | Current disposal and game-over paths do not call the private clear helper. | Phase 3/4 adapter and host disposal call idempotent `cancelAll`. |
| P0-4 | `hasLocalDraftChanges` includes accepted pending document diffs. | Phase 5 adds a narrow readiness view that permits accepted pending documents while blocking uncommitted local drafts. |
| P0-5 | Panel expansion lives in mounted widget state. | Phase 5 keeps the Chunk workspace subtree mounted across Play/Edit. |
| P0-6 | Full editor baseline has an unrelated terrain-material no-op-save regression in the shared dirty worktree. | Keep outside Phase 0; obtain exception acceptance or fix in the owning terrain-material work. |

### Generator baseline

- Dry-run result: pass; 9 chunks, 3 levels, 3 parallax themes, and 1 terrain
  material validated with no blocking issue or generated drift at execution
  time.
- Signature probe result: pass; every reviewed signature matched and two
  standalone processes reproduced the payload exactly.
- Generated-file diff result: Phase 0 changed no generated or authoring file.
  The shared worktree does contain user-owned modifications to
  `terrain_material_defs.json` and `authored_terrain_materials.dart`.

### Windows baseline

- Editor build result: pass; release executable created at
  `tools/editor/build/windows/x64/runner/Release/runner_editor.exe`.
- Manual launch result: automated hidden startup probe passed. Interactive
  Chunk-route navigation was not performed.
- Warnings/limitations: existing shortcut behavior is covered by focused widget
  tests, but manual Windows shortcut confirmation remains open. No gameplay
  desktop listener exists in Phase 0.

## Closeout

- [x] Every Phase 0 checkbox is complete or explicitly accepted as a baseline
      exception
      with evidence.
- [x] Update this document's status to `Complete` with the completion date.
- [x] Update the source plan only with factual delivered status; do not mark
      later phases started.
- [x] Commit Phase 0 as one coherent, independently validated milestone or a
      small sequence of test/contract commits that are each green.
- [x] Do not begin Phase 1 extraction until the completion gate is signed off.

Phase 0 completion does not claim keyboard/mouse input or Chunk Creator Play
mode is implemented. It proves that their required behavior and migration
baselines are explicit and protected.
