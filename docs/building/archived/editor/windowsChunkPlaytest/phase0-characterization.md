# Windows Chunk Playtest Phase 0 Characterization

Date: August 19, 2026

Status: Complete

This record freezes the existing input, generated-content, and Chunk Creator
boundaries that later phases must preserve. It describes current behavior and
separately labels future contracts; it does not claim desktop event handling or
Play mode exists.

## 1. Current input pipeline

```text
touch pointer stream
  -> leaf control (tap, hold, directional, movement)
  -> RunnerControlsOverlay callback
  -> GameOverlay slot-mode callback mapping
  -> RunnerInputRouter
  -> GameController coalescing into TickInputFrame
  -> Core commands
  -> applied ReplayCommandFrameV1 observer
```

Ownership is fixed as follows:

| Concern | Current owner |
| --- | --- |
| Pointer down/up/cancel and affordability gating | `ActionButton`, `HoldActionButton`, `DirectionalActionButton`, and `MoveButtons` |
| Slot-to-control branching | `RunnerControlsOverlay`, `MeleeControl`, and `ProjectileControl` |
| HUD-mode-to-router callback choice | `GameOverlay` |
| Aim preview begin/update/end | directional controls plus the two `AimPreviewModel` instances owned by `RunnerGameWidget` |
| Continuous move/aim buffering | `RunnerInputRouter` |
| Held-slot exclusivity | `RunnerInputRouter` (`latest hold wins`) |
| Same-tick aim and action commit | `RunnerInputRouter` combined commit methods |
| Per-tick input coalescing | `GameController` and `TickInputFrame` |
| Deterministic gameplay authority | Core commands and `GameCore` |
| Canonical applied replay frames | `GameController` observers after coalescing |

`GameOverlay` and `RunnerGameWidget` are the only production UI callers of
`RunnerInputRouter`. `RunnerFlameGame` only pumps held input once per update.
No widget or Flame component directly enqueues Core gameplay commands.

The shipping `GameWidget` uses `autofocus: false`. There is no gameplay
`FocusNode`, `KeyboardListener`, `HardwareKeyboard` handler, mouse-button
adapter, or pointer-to-world aim adapter. Editor text and scene focus are
therefore not currently shared with gameplay input.

### Current router clearing

`RunnerGameWidget._clearInputs` neutralizes movement, clears aim, releases
primary, secondary, mobility, and projectile holds, ends both aim previews,
then pumps the neutral continuous state. Its current callers are:

- leaving `AppLifecycleState.resumed`
- starting the ready run
- beginning restart and initializing the replacement controller
- opening exit confirmation while running
- entering pause

Disposal shuts down the controller and disposes previews without first calling
`_clearInputs`. A run becoming game-over also has no dedicated clear call.
Those are current findings, not the future desktop contract: Phase 3 must give
each mounted adapter one explicit idempotent `cancelAll` lifecycle.

## 2. Slot and input-mode contract

Legend:

- `press`: enqueue the slot's one-shot command for the next input-lead tick.
- `hold+` / `hold-`: enqueue one held transition; the router suppresses
  duplicate transitions.
- `aim`: update the shared quantized aim channel.
- `commit`: enqueue aim and the action on the same scheduled tick.
- `cancel`: release the hold and clear/end aim without a commit.

| Slot | `tap` | `holdAimRelease` | `holdMaintain` | `holdRelease` | Production-reachable today |
| --- | --- | --- | --- | --- | --- |
| Primary | down: `press strike` | down: `hold+`, aim; up: `commit strike`, `hold-`, clear; cancel: `hold-`, clear | down: `hold+` + strike; up/cancel: `hold-` | down: `hold+`; up: clear-aim commit + `hold-`; cancel: `hold-` | tap and hold-aim-release |
| Secondary | down: `press secondary` | down: `hold+`, aim; up: aimed secondary commit + `hold-`; cancel: `hold-`, clear | down: `hold+` + secondary press; up/cancel: `hold-` | down: `hold+`; up: secondary commit + `hold-`; cancel: `hold-` | hold-maintain |
| Projectile | down: `press projectile` | down: `hold+`, aim; up: aimed projectile commit + `hold-`; cancel: `hold-`, clear | unsupported; current widget falls through to its directional branch and must not define the future contract | down: `hold+`; up: projectile commit + `hold-`; cancel: `hold-` | tap and hold-aim-release |
| Mobility | down: `press dash` | down: `hold+`, aim; up: aimed dash commit + `hold-`; cancel: `hold-`, clear | down: `hold+` + dash; up/cancel: `hold-` | down: `hold+`; up: dash commit + `hold-`; cancel: `hold-` | tap |
| Spell | down: `press spell` | unsupported | unsupported | unsupported | tap only |
| Jump | down: `press jump` | unsupported | unsupported | unsupported | tap only |

The Core ability catalog audit confirms:

- primary: authored `tap` and directional/aimed `holdRelease`
- secondary: authored `holdMaintain`
- projectile: authored `tap` and aimed `holdRelease`
- mobility, spell, and jump: authored `tap`

`SnapshotBuilder` converts aimed/directional authored `holdRelease` to
`AbilityInputMode.holdAimRelease`; a non-aiming hold-release would become
`holdRelease`. No projectile `holdMaintain` is authored or admitted by the
current loadout content. The future semantic dispatcher must reject that
combination rather than reproduce `ProjectileControl`'s incidental fallback.

On directional release the leaf widget calls commit before its final hold-end
and aim-clear callbacks. Both router operations target the same input-lead
tick, and `GameController` coalesces them into one applied frame. Pointer
cancel and forced cancel never call commit. Tap actions fire on pointer-down.

Executable protection is in:

- `test/runner_input_router_release_test.dart`
- `test/game_controller_input_test.dart`
- `test/core/hold_input_mode_snapshot_test.dart`
- `test/ui/controls/runner_controls_overlay_radial_test.dart`
- `test/ui/controls/hold_action_button_test.dart`
- `test/ui/controls/directional_action_button_test.dart`
- `test/ui/controls/move_buttons_test.dart`

## 3. Desktop action and binding contract

`RunnerGameplayAction` is device-neutral and contains gameplay intent only.
Aim remains vector data, not keyboard direction actions. The immutable Windows
binding tables contain physical keys and mouse button identities, but no event
listener, focus object, pressed-state set, router reference, or side effect.

The exact gameplay mapping is:

| Action | Keys | Mouse |
| --- | --- | --- |
| Move left | `A`, Left Arrow | — |
| Move right | `D`, Right Arrow | — |
| Jump | `Space`, `W`, Up Arrow | — |
| Mobility | Left Shift, Right Shift | — |
| Primary | `J` | Left button |
| Projectile | `K` | Right button |
| Secondary | `Q` | — |
| Spell | `E`, `L` | — |

`F5`, `F6`, `Escape`, `P`, and `Enter` are absent because they belong to the
future editor host. Exact and uniqueness tests live in
`test/ui/input/desktop/runner_desktop_bindings_test.dart`.

## 4. Future focus, cancel, and host lifecycle

This is a future behavior contract for Phase 3 and Phase 5, not current UI.

| Transition | Required future result |
| --- | --- |
| Play surface becomes ready/clicked | Request its local gameplay focus; begin with empty pressed state |
| Pointer enters fitted viewport | Permit pointer-derived aim updates only inside the viewport |
| Pointer leaves fitted viewport or enters letterbox | Clear pointer-derived aim; do not alter keyboard movement merely from hover |
| Editor field gains focus | `cancelAll`, pause, and release gameplay focus before accepting text |
| Modal dialog opens | `cancelAll`, pause, and keep shortcuts with the dialog |
| Windows app deactivates/Alt+Tabs | `cancelAll`, pause, and release focus |
| Windows app resumes | Remain paused with empty pressed state; require click or `P` to resume |
| Playtest pauses | `cancelAll`, then pause |
| Playtest restarts | `cancelAll`, dispose runtime state, rebuild the same immutable scenario/seed |
| Playtest stops | `cancelAll`, dispose runtime state, restore the existing editor workspace state |
| Adapter or host disposes | Idempotent `cancelAll`, detach listeners, dispose owned focus/runtime objects |

Future `cancelAll` means all of the following, even if nothing is held:

- neutral movement
- clear aim
- release primary, secondary, projectile, and mobility holds
- end aim previews
- clear adapter-local pressed key and mouse-button state

Editor host actions remain separate:

| Mode | Binding | Result and guard |
| --- | --- | --- |
| Edit | `F5` | Play only on active current-schema Chunk-v2 route with an owner, no dialog/text command owner, no active operation, and no uncommitted local draft |
| Play | `F5` or `Escape` | Stop and restore Edit state |
| Play | `F6` | Restart the same immutable scenario |
| Play | `P` | Explicit pause/resume |
| Play ready state | `Enter` | Start the prepared scenario |

These host bindings take priority only while the playtest host owns focus and
never become `RunnerGameplayAction`, router calls, Core commands, or replay
frames.

## 5. Generator and runtime-content baseline

The current repository path is:

```text
Prefab-v3 + Chunk-v2 + level/parallax/material JSON
  -> strict string decoders in polygon_terrain_source.dart
  -> placed-Prefab expansion and collision/render partitioning
  -> Core terrain compilation and triangulation
  -> polygon/source/edge/placement/triangle signatures
  -> scheduler-reachable seam validation
  -> ChunkPattern, staged terrain, marker, sprite, level, theme, and material renderers
  -> GeneratedArtifactPlan drift inspection or atomic write sequence
```

Pure Phase 1 extraction candidates are the strict decoders, typed compilation,
Prefab expansion, render/collision partitioning, signatures, seam validation,
marker/sprite projection, and deterministic Dart render functions. Repository
directory enumeration, file reads/writes, fixed target selection, CLI argument
handling, stdout/stderr, and process exit codes remain in `tool/`.

The generator owns these checked-in targets:

- `packages/runner_core/lib/track/authored_chunk_patterns.dart`
- `packages/runner_core/lib/levels/level_id.dart`
- `packages/runner_core/lib/levels/level_registry.dart`
- `lib/ui/levels/generated_level_ui_metadata.dart`
- `lib/game/themes/authored_parallax_themes.dart`
- `lib/game/themes/authored_terrain_materials.dart`
- `packages/runner_core/lib/track/staged_authored_terrain.dart`

The signature probe binds authoring polygon, source, edge, placement, triangle,
reachable seam, isolated seam, and staged-artifact SHA-256 values to reviewed
fixtures. It also runs two standalone Dart processes and compares their exact
JSON payloads. Repository-generation tests fail closed on blocking seam or
compilation issues. `GeneratedArtifactPlan.inspectDrift` compares every owned
target and performs no write in dry-run mode.

The editor and generator read the same canonical authoring files, but the
editor currently projects `ChunkV2Scene` through editor-owned expansion and
visual-source code while the generator owns its separate root-tool pipeline.
That duplication is the Phase 1 extraction target; no second compiler may be
created for Play mode.

## 6. Chunk Creator document and restoration ownership

| State | Authoritative owner | Included in a future scenario snapshot? |
| --- | --- | --- |
| Repository source baseline | active Chunk plugin/workspace | No; it is comparison/persistence state |
| Accepted in-memory Chunk-v2 document | `EditorSessionController.document` | Yes, captured immutably after readiness passes |
| Pending file diff | `EditorSessionController.pendingChanges` | The accepted document is allowed; the diff itself remains session state |
| Undo/redo history | `EditorSessionController` | No; retain untouched for Edit restoration |
| Active polygon/prefab/marker pointer gesture | workspace authoring/gesture controllers | No; blocks Play |
| Open polygon creation/edit and exact/name field draft | `ChunkPolygonAuthoringController`, `_shapeNameDrafts`, and `TerrainPolygonExactEditController` | No; blocks Play |
| Open composition/owner dialog | dialog route plus `_compositionOperationActive` for composition operations | No; dialog command ownership blocks Play |
| Active owner/level | `ChunkV2Document.activeLevelId` plus `ChunkAuthoringWorkspaceState._selectedChunkKey` | Restore unchanged |
| Active Terrain/Prefabs/Markers/Layers domain and selection | `ChunkSceneCoordinator` | Restore unchanged |
| Pan/zoom and visibility toggles | `ChunkAuthoringWorkspaceState` | Restore unchanged |
| Panel expansion | mounted `EditorSectionCard` states keyed by stable expansion keys | Restore by keeping the workspace subtree mounted |

Existing widget tests prove that accepted commands increment document revision,
enter undo history, and produce pending changes, while gesture previews,
invalid field text, and open composition dialogs do not silently become
accepted document edits. Route switching, reload, apply, and exit guards use
`EditorPageLocalDraftState`, `EditorPageReloadHandler`, and
`EditorPageApplyHandler` backed by workspace/session owners.

Phase 5 should read a narrow readiness view composed from:

- current `ChunkV2Scene` and `ChunkV2Document`
- an active selected owner in the accepted document
- session validation errors versus warnings
- session loading/exporting state
- workspace active operation and uncommitted local field/draft state
- a preparation generation token to reject stale async results

Pending accepted document changes are not a blocker. Active gestures, open
dialogs, and uncommitted field/polygon drafts are blockers. The future view-only
transition must conditionally replace only the workspace body; it must not
replace `EditorSessionController`, reload the plugin, change a chunk revision,
add history, apply files, or reset source-drift baselines.

Readiness outcomes are frozen as:

- `ready`
- `unsupportedPlatformOrSourceGeneration`
- `missingOwnerOrLevelContext`
- `activeLocalOperationOrDraft`
- `blockingValidationIssue`
- `preparationCanceledOrStale`

Validation warnings remain non-blocking; errors block. Source-drift detection
remains authoritative after Stop.

## 7. Findings routed to later phases

1. Projectile `holdMaintain` is an incidental directional-widget fallback and
   is not an admitted semantic combination. Phase 3 must reject it explicitly.
2. Current `RunnerGameWidget` automatically resumes a lifecycle-paused shipping
   run. The editor playtest contract instead requires explicit resume.
3. Current disposal and game-over paths do not call the existing private clear
   helper. Phase 3/4 adapter disposal must call idempotent `cancelAll` before
   listener/runtime teardown.
4. The workspace's public `hasLocalDraftChanges` intentionally includes
   accepted pending diffs. Phase 5 readiness must distinguish accepted pending
   documents from uncommitted route-local drafts without weakening existing
   reload/apply guards.
5. Panel expansion is owned by mounted widget state rather than a serializable
   model. The Play/Edit implementation must keep the workspace subtree mounted
   if exact panel restoration is required.
