# Windows Chunk Playtest and Reusable Desktop Input Plan

Date: August 19, 2026

Status: Active (Phase 0 completed with accepted baseline exceptions on August
19, 2026; Phase 1 completed in `25ae1a6e` on August 19, 2026; Phase 2
completed in `77af803f` on August 19, 2026; Phase 3 not started)

Related documents:

- [Phase 0 implementation checklist](phase0-implementation-checklist.md)
- [Phase 0 characterization record](phase0-characterization.md)
- [Phase 1 implementation checklist](phase1-implementation-checklist.md)
- [Phase 2 implementation checklist](phase2-implementation-checklist.md)
- [Chunk Creator high-level plan](../chunkCreator/plan.md)
- [Unified Chunk Scene strategy](../chunkCreator/unified-chunk-scene-strategy.md)
- [Editor UI system](../../../tdd/editor_ui_system.md)
- [Polygon terrain authoring foundation](../../../tdd/polygon_terrain_authoring_foundation.md)

## Decision summary

Add an in-editor Play mode to the Windows Chunk Creator that runs the selected
chunk through the real deterministic Core and Flame renderer. Play mode uses a
snapshot of the current plugin-owned document, including changes that have not
been applied to repository files. Starting or stopping a playtest must not
write authoring JSON or generated Dart.

Build keyboard and mouse support as a reusable desktop input adapter in the
game package. Touch controls and desktop controls remain separate UI input
sources. Both feed one source-neutral semantic action dispatcher, which in
turn uses the existing `RunnerInputRouter` and its tick-stamped Core command
path. The editor is the first desktop-input host; a later Windows game build
can mount the same adapter without importing editor code or rewriting input
semantics.

Do not reuse `RunnerGameWidget` as the playtest host. It currently owns real-run
concerns including server-issued run identity, replay recording, submission,
ghost playback, rewards, restart preflight, and app state. Add a narrow,
backend-free playtest host that reuses `GameController`, `RunnerFlameGame`, the
shared action dispatcher, and the desktop adapter.

```text
Touch controls --------------------+
                                    |
Keyboard/mouse desktop adapter -----+--> semantic action dispatcher
                                              |
                                              v
                                      RunnerInputRouter
                                              |
                                              v
                                      GameController -> Core

Editor F5/F6/Escape/P controls ---> playtest host lifecycle only
```

The input split is intentional:

- `RunnerInputRouter` remains the source-independent tick scheduler.
- The semantic dispatcher owns action begin/end/commit behavior.
- Touch widgets translate gestures only.
- The desktop adapter translates keyboard, mouse, and focus state only.
- The playtest host owns start, stop, restart, and pause only.
- No desktop module imports a touch-control module, and no touch module imports
  a desktop module.

## Goals

- Let an author press Play from Chunk Creator and immediately test the selected
  chunk on Windows.
- Test the current accepted editor document, not only the last version applied
  to files or emitted by the generator.
- Use production Core movement, collision, enemies, abilities, track streaming,
  snapshots, and Flame rendering.
- Preserve deterministic behavior: the same content snapshot, seed, character,
  loadout, and input stream produce the same simulation result.
- Keep keyboard/mouse reusable by the actual game and independent from touch.
- Preserve the selected owner, editor viewport, active tab, selection, undo
  history, and pending changes when returning to Edit mode.
- Fail closed on invalid content and show existing actionable validation
  diagnostics instead of fabricating preview geometry.
- Keep repository writes explicit through the existing Chunk plugin/store
  apply path.

## Non-goals

- Enabling keyboard/mouse in the shipping game shell in the first editor
  milestone. The adapter is production-ready and reusable, but product rollout
  is a separate composition step.
- Key rebinding UI, multiple binding profiles, controller/gamepad input, or
  accessibility remapping in the first milestone.
- Web pointer lock, browser context-menu policy, or web-specific focus handling.
- Editing chunk content while the simulation is running.
- Rewards, progression, run tickets, replay upload, leaderboard projection,
  ghosts, Firebase initialization, or backend calls from play mode.
- Treating play mode as proof that a chunk is valid. Static validation and
  generator drift checks remain authoritative gates.
- Moving gameplay authority, collision, or spawn rules into the editor or
  Flame.
- Making the editor a second complete game shell.

## Current baseline

### Runtime input

- `lib/game/input/runner_input_router.dart` already describes touch, keyboard,
  and mouse as possible sources, but only the source-independent scheduling
  layer exists.
- `RunnerInputRouter` owns continuous movement/aim buffering, edge-triggered
  actions, same-tick aim commits, and held ability-slot transitions.
- `GameOverlay` currently translates touch-control callbacks directly into
  router calls and repeats some ability-input-mode decisions in UI composition.
- There is no Flutter keyboard/focus adapter or mouse-to-world aim adapter.
- `GameWidget` currently has `autofocus: false`; the run widget does not own a
  desktop focus lifecycle.

### Runtime hosting

- `RunnerGameWidget` assembles the real game but also owns replay recording,
  backend submission status, ghost playback, app-state restart, haptics, and
  real-run overlays.
- `GameController` and `RunnerFlameGame` are already suitable reusable runtime
  seams once construction and assets are made host-configurable.
- `GameCore` currently resolves the checked-in generated staged terrain
  artifact internally. It has no explicit authoring-preview constructor or
  validated staged-terrain override.

### Editor

- `tools/editor` is already a Windows Flutter app and has a Windows runner.
- The Chunk route owns one plugin-backed `ChunkV2Document`; accepted editor
  commands update that in-memory document before Apply To Files.
- `ChunkAuthoringWorkspace` already blocks unsafe transitions while a gesture
  or local field draft is active.
- The Chunk scene already expands collision through Core and exposes compiled
  edges, resolved marker placement, parallax, terrain materials, and placed
  Prefab visuals.
- The exact generator pipeline that creates runtime `ChunkPattern` and staged
  terrain records is still rooted under `tool/`; importing or copying that code
  into the editor would create a second compiler path.

## Chosen architecture

### 1. Shared semantic gameplay input

Add a source-neutral action layer between UI event sources and
`RunnerInputRouter`.

The action contract should express intent rather than devices:

- movement axis or left/right held state
- aim direction and aim clear
- jump
- primary, secondary, projectile, spell, and mobility begin/end
- cancellation of every held input

The dispatcher reads the current authoritative HUD input-mode values when an
ability edge occurs. It converts semantic begin/end events into the existing
press, held-slot, aimed commit, and release calls. This keeps
`AbilityInputMode.tap`, `holdRelease`, and `holdAimRelease` behavior identical
across touch and desktop sources.

Pause, start, restart, stop, and exit are host lifecycle actions. They must not
be added to Core commands or conflated with gameplay input.

Expected ownership:

- `lib/game/input/runner_input_router.dart`: unchanged low-level scheduler
  responsibility.
- new code beside the router: semantic action state/dispatcher with no Flutter
  keyboard, mouse, or touch types.
- `lib/ui/controls/**`: touch adapter and touch presentation only.
- new `lib/ui/input/desktop/**`: Flutter keyboard, mouse, focus, and coordinate
  conversion only.
- run/playtest hosts: choose which adapters to mount and own lifecycle actions.

The touch UI should receive the shared semantic action binding rather than the
router itself. Existing touch presentation and gesture behavior remain
unchanged; this is an ownership cleanup, not a touch-control redesign.

### 2. Desktop keyboard and mouse adapter

The first fixed Windows bindings are:

| Intent | Primary binding | Alternate binding |
| --- | --- | --- |
| Move left | `A` | Left Arrow |
| Move right | `D` | Right Arrow |
| Jump | `Space` | `W` or Up Arrow |
| Mobility | Left or Right Shift | — |
| Primary slot | Left Mouse Button | `J` |
| Projectile slot | Right Mouse Button | `K` |
| Secondary slot | `Q` | — |
| Spell slot | `E` | `L` |

Playtest-host bindings are separate:

| Host action | Binding |
| --- | --- |
| Start/stop Play mode | `F5` |
| Restart the same scenario | `F6` |
| Return to Edit mode | `Escape` |
| Pause/resume | `P` |
| Start from the ready state | `Enter` |

Input rules:

- Physical key-down state, not repeated character events, is authoritative.
- OS key repeat must not emit repeated edge-triggered gameplay actions.
- Left and right held together resolve to neutral movement; releasing either
  key immediately recomputes the remaining direction.
- Mouse aim is calculated only inside the fitted game viewport. Letterbox and
  editor chrome coordinates are excluded.
- Convert cursor position relative to the rendered player position, using the
  same viewport and camera transforms as rendering, then normalize and pass it
  through the existing aim quantization path.
- A zero-length aim vector clears aim. Leaving the viewport keeps no hidden
  pointer-derived direction.
- Keyboard ability keys use the current valid mouse aim when one exists and
  retain the current facing/default semantics when it does not.
- Right-click behavior is owned by the desktop adapter; web context-menu
  suppression is explicitly deferred.
- Losing widget focus, deactivating the Windows app, pausing, stopping,
  restarting, disposing, or changing control schemes calls one shared
  `cancelAll` path before simulation continues.
- Focus loss while running also pauses the editor playtest. Resuming requires
  an explicit click or `P`, preventing unseen input after task switching.

The adapter owns one `FocusNode` and exposes explicit `requestFocus`,
`releaseFocus`, and `cancelAll` lifecycle operations. It must not use global
keyboard handlers that remain active while an author types in an editor field
or dialog.

### 3. Shared current-document runtime compiler

Do not duplicate the generator's terrain, render, Prefab expansion, marker, or
signature logic in `tools/editor`.

Extract the repository-independent source decoding and typed compilation parts
of the current `tool/polygon_terrain_*` and chunk-pattern generation flow into
a small pure-Dart package, provisionally
`packages/runner_content_pipeline/`. It depends on `runner_core`; Core must not
depend on it.

The shared package owns:

- strict current-schema Prefab-v3 and Chunk-v2 source DTOs/codecs
- direct and placed-Prefab terrain compilation
- collision/render partitioning and triangulation
- placement lineage and canonical signature construction
- runtime `ChunkPattern` projection, including visual sprites and markers
- materialized typed `StagedTerrainChunkData` output
- deterministic issue ordering

The repository generator and editor playtest scenario builder both call that
package. The editor adapter may encode its current immutable document to
canonical in-memory JSON before invoking the shared pipeline; it must not write
temporary authoring files merely to call the compiler.

Extraction is accepted only when the generator dry-run remains byte-stable and
all existing compiler/signature fixtures pass. Add package-level AGENTS guidance
and update the repository map when the package is introduced.

### 4. Explicit Core authoring-preview boundary

Add an explicit tool/test construction path, such as
`GameCore.chunkPlaytest`, instead of adding optional preview knobs throughout
the production constructor.

The construction input is immutable and validated. It contains:

- selected level definition and visual theme identity
- selected draft `ChunkPattern`
- selected draft `StagedTerrainChunkData`
- deterministic scenario path and seed
- player character and loadout

Introduce a staged-terrain catalog abstraction or validated overlay catalog so
the playtest can replace exactly one generated chunk record while every other
runtime lookup continues to use admitted generated content. The default
`GameCore` constructor must continue to use the checked-in artifact with no
behavior change.

The scenario path is derived from the current editor seam/scheduler analysis:

1. Require the selected chunk and its dependencies to compile without blocking
   issues.
2. Require the selected chunk to be active and reachable in its level context.
3. Choose a deterministic scheduler-valid path that reaches the selected chunk
   as early as possible.
4. Use canonical transition ordering to extend the path far enough for track
   prewarm and play beyond the target.
5. Replace the selected chunk's pattern and staged terrain with the current
   draft versions at every selected occurrence.
6. Fail with the existing seam/scheduler diagnostic if no compatible reachable
   path exists; do not insert an artificial collision pad that hides a real
   boundary problem.

Restart rebuilds the Core instance from the same immutable scenario and resets
the input/focus state. A different seed is an explicit scenario change, not a
wall-clock value.

The preview factory is not a replay/run-ticket option and is never accepted by
the replay validator. No run-protocol or backend payload changes are expected.

### 5. Backend-free Flame playtest host

Add a separate tooling entrypoint, for example `lib/playtest.dart`, that
exports only the narrow playtest API needed by the editor. Do not add editor
types to `lib/runner.dart`.

The host owns:

- `GameCore.chunkPlaytest` construction
- `GameController`
- `RunnerInputRouter`
- the semantic action dispatcher
- `RunnerFlameGame`
- desktop input focus and mouse-aim conversion
- ready, paused, failed, game-over, restart, and stop presentation
- deterministic cleanup

The host does not own:

- `AppState` or Provider lookup
- Firebase initialization or clients
- run sessions, boards, rewards, or submissions
- `RunRecorder` or local replay spool files
- ghost bootstrap/playback
- production restart preflight

Make Flame image loading host-configurable. The normal game keeps the default
asset bundle. The editor playtest supplies a read-only, workspace-backed asset
bundle rooted at the selected repository workspace, with canonical path and
traversal checks. This lets the Windows editor render repository assets without
copying them into `tools/editor` or relying on stale duplicate assets. Asset
load failures remain explicit playtest diagnostics.

### 6. Chunk Creator Play/Edit state machine

Add one route-local state machine:

```text
edit -> preparing -> ready/running -> paused/gameOver -> edit
              \-> failed -------------------------------> edit
```

Entry rules:

- A chunk owner and a Windows workspace must be selected.
- Plugin-owned pending changes are allowed and are included in the snapshot.
- Active pointer gestures, open dialogs, uncommitted polygon drafts, and
  unsaved inspector field edits block Play. The author must save or discard
  that local operation first.
- Validation runs against the exact snapshot used to build the scenario.
- Blocking issues keep the editor in Edit mode and surface the normal
  diagnostics. Warnings remain visible but do not block.
- Scenario preparation is asynchronous, cancelable by route/workspace change,
  and shows progress without freezing the editor shell.

Running rules:

- Replace the Chunk Creator workspace body with the bounded playtest surface;
  keep the editor shell available only for Stop/return context.
- Disable reload, apply, undo, redo, owner switching, route switching, and all
  source mutations while preparing or playing.
- Hide touch controls. Show a compact Windows binding legend and a clear
  `PLAYTEST - NO REWARDS/REPLAY` label.
- Request playtest focus only after the Flame world is ready.
- `F5` or `Escape` stops play, cancels input, disposes runtime resources, and
  restores the exact Edit projection.
- `F6` creates a fresh runtime from the same scenario snapshot.
- If the underlying workspace changes externally during play, stopping returns
  to the captured editor document and normal source-drift checks continue to
  guard a later Apply To Files.

State that must survive a Play/Edit round trip:

- active level and selected chunk owner
- active Terrain/Prefabs/Markers/Layers tab
- editor pan, zoom, and view-only overlay choices
- source selection where it remains valid
- session undo/redo history and pending file diff
- no new source revision or history entry solely from entering Play mode

## Delivery phases

### Phase 0: Characterization and contract freeze

- Add characterization tests for current touch-to-router ability behavior,
  including every `AbilityInputMode` and aim/hold release ordering.
- Record current generator output digests and require dry-run parity.
- Characterize Chunk workspace operation guards, document identity, pending
  diff, and Play/Edit state restoration targets.
- Freeze the binding table and focus-loss behavior in tests before UI wiring.

Gate: current touch behavior and generated output have executable baselines.

### Phase 1: Shared content pipeline extraction

- Create the pure-Dart shared pipeline package and its AGENTS guidance.
- Move reusable source/compilation/materialization logic out of root-only tool
  files without changing semantics.
- Adapt `tool/generate_chunk_runtime_data.dart` to the shared package.
- Add typed single-chunk compilation APIs for the editor.
- Prove generated Dart and signatures remain unchanged.

Gate: full generator dry-run is clean and focused pipeline tests pass.

### Phase 2: Core playtest scenario boundary

- Add the immutable playtest scenario contract.
- Add validated staged-terrain overlay/catalog behavior.
- Add deterministic scheduler-valid scenario-path selection.
- Add `GameCore.chunkPlaytest` and deterministic restart tests.
- Prove the production constructor and replay behavior are unchanged.

Gate: the selected draft record runs through Core in a headless test, and
identical scenario/input streams produce identical snapshots.

### Phase 3: Modular semantic and desktop input

- Add the source-neutral semantic action dispatcher.
- Migrate touch callbacks to the dispatcher without changing touch UX.
- Add the Windows keyboard/mouse adapter as a separate module.
- Add viewport-aware mouse aim and focus/cancel lifecycle handling.
- Add unit/widget tests for mapping, held-key combinations, key repeat, slot
  modes, focus loss, pause, and disposal.

Gate: touch parity tests remain green; desktop tests prove no duplicate edges
or stuck held input; desktop code has no touch imports.

### Phase 4: Backend-free playtest host

- Add the tooling-only playtest barrel and widget.
- Reuse Core/controller/Flame and mount only the desktop adapter.
- Add host-configurable image loading and the safe workspace asset bundle.
- Add ready, pause, restart, failure, game-over, and stop states.
- Prove no Provider/Firebase/replay dependency is invoked.

Gate: a widget test can start, control, restart, and dispose a deterministic
scenario without app state or backend initialization.

### Phase 5: Windows Chunk Creator integration

- Add Play/Edit state to the current-schema Chunk workspace.
- Add the Play action and keyboard shortcuts without intercepting text entry or
  dialogs.
- Compile the exact current document snapshot asynchronously.
- Lock editor mutations while preparing/running and restore state on stop.
- Surface validation, compile, asset, and runtime errors in editor language.
- Add focused editor tests and a Windows integration fixture.

Gate: an unapplied valid chunk edit can be played and stopped with no file
changes and no loss of editor state.

### Phase 6: Hardening, documentation, and Windows acceptance

- Complete focus, Alt+Tab, resize, DPI scaling, mouse-boundary, and repeated
  start/stop testing on Windows.
- Measure preparation and runtime behavior on the existing editor reference
  hardware; avoid UI-thread work that creates a visible long frame.
- Update `tools/editor/README.md` with controls and limitations.
- Add or update TDD documentation for the shared input boundary, playtest data
  flow, Core preview construction, and asset loading.
- Update relevant AGENTS files only if delivered ownership rules change.
- Archive this building plan when every required gate is complete.

Gate: automated validation is green and the manual Windows checklist is signed
off.

### Follow-on: actual desktop game adoption

The production Windows game later mounts the same desktop adapter beside the
existing shared dispatcher. That follow-on should require only host
composition, control-hint presentation, product settings, and any desired
binding persistence. It must not copy mappings from the editor or change Core
commands.

An optional `auto`, `touch`, or `desktop` control-scheme policy can be added to
`RunnerGameWidget` at that time. If it changes the public embedding API, update
`lib/runner.dart`, `RunnerGameWidget` API docs, route docs, and README in the
same change.

## Acceptance criteria

### Input architecture

- Touch and desktop are separate adapters over one semantic dispatcher.
- The desktop adapter and playtest host import no editor source.
- The editor imports the playtest barrel, not internal game/UI paths.
- No device adapter schedules Core commands outside `RunnerInputRouter`.
- Press, hold-release, hold-aim-release, same-tick aim commit, and cancel
  behavior are identical for equivalent touch and desktop action streams.
- Key repeat emits one edge; focus loss emits releases/cancel and cannot leave
  movement, aim, or an ability slot held.
- The actual game can mount the desktop adapter without importing or depending
  on touch-control implementation files.

### Playtest fidelity and safety

- Play mode uses current plugin-owned chunk, Prefab, marker, and terrain data,
  including unapplied accepted edits.
- Play mode uses real Core simulation, `GameController`, and
  `RunnerFlameGame`.
- The selected chunk is reached through a deterministic scheduler-valid level
  path.
- Restart with the same scenario resets to the same initial snapshot and seed.
- Invalid content cannot start and reports deterministic diagnostics.
- No playtest code writes authoring files, generated files, replay spools, or
  backend state.
- Default production Core construction and generated runtime selection remain
  unchanged.

### Editor UX

- Play is unavailable during active gestures, dialogs, or uncommitted local
  field drafts, but plugin-owned unapplied changes are allowed.
- `F5`, `F6`, `Escape`, `P`, and `Enter` behave as documented and do not fire
  while an editor text field/dialog owns input in Edit mode.
- Clicking the game surface acquires focus; leaving focus cancels input and
  pauses safely.
- Mouse aim remains correct with letterboxing, editor resize, Windows DPI
  scaling, and non-default viewport alignment.
- Stopping restores selection, tab, pan/zoom, overlays, history, and pending
  diff.
- Repeated Play/Stop cycles do not leak controllers, focus nodes, Flame games,
  images, or listeners.

### Windows delivery

- The editor Windows build succeeds from `tools/editor`.
- A manual pass confirms keyboard rollover, left/right mouse actions, Alt+Tab,
  resize, high-DPI behavior, pause/restart/stop, game over, and return to Edit.
- The control legend matches the implemented fixed bindings.

## Test and validation matrix

Minimum automated checks for implementation:

- `dart analyze packages/runner_core`
- relevant Core tests for preview catalog/scenario construction and
  determinism
- analyze and test the new shared content-pipeline package
- `dart run tool/generate_chunk_runtime_data.dart --dry-run`
- root `dart analyze`
- focused `RunnerInputRouter`, semantic dispatcher, desktop adapter, viewport
  aim, and playtest-host tests
- relevant existing touch-control and run-widget tests
- `cd tools/editor && dart analyze`
- focused editor scenario-builder, Chunk workspace, shortcut/focus, and state
  restoration tests
- `cd tools/editor && flutter test`
- `cd tools/editor && flutter build windows`

Tests must include:

- keyboard down/up, alternate bindings, opposing directions, and OS repeat
- all ability input modes on mouse and keyboard paths
- aim update, aim clear, commit ordering, and viewport coordinate conversion
- focus loss, pause, restart, stop, disposal, and rapid repeated Play/Stop
- valid pending document, invalid document, stale dependency, missing asset,
  and canceled preparation
- byte/hash proof that Play/Stop does not modify repository source or generated
  output
- deterministic snapshot equivalence for two identical scenario/input runs
- touch-control behavior parity after dispatcher extraction

## Risks and mitigations

### Compiler drift

Risk: the editor constructs runtime data differently from the generator.

Mitigation: one shared pure-Dart pipeline, generator byte-stability fixtures,
and no editor-local reimplementation of signatures, triangulation, Prefab
expansion, markers, or visual-sprite projection.

### Input semantic duplication

Risk: touch and desktop implement different hold/aim/commit behavior.

Mitigation: centralize semantic action transitions in one dispatcher and keep
device adapters limited to event translation.

### Stuck desktop input

Risk: focus loss or a missed key-up leaves movement or a charged slot held.

Mitigation: one idempotent `cancelAll` path invoked by focus, app lifecycle,
pause, restart, stop, scheme change, and disposal.

### Preview-only behavior leaks into production

Risk: optional overrides weaken normal terrain admission or replay behavior.

Mitigation: an explicit `GameCore.chunkPlaytest` factory and validated overlay
catalog; keep the default constructor unchanged and add production parity
tests.

### Asset path divergence

Risk: packaged-game asset lookup does not work from the standalone editor or
renders stale copied files.

Mitigation: injectable Flame image bundle plus a read-only, traversal-guarded
workspace bundle. Do not duplicate the game asset tree under `tools/editor`.

### Editor shortcut collisions

Risk: F-keys or gameplay keys mutate the editor while a field/dialog is active.

Mitigation: mode-scoped focus and shortcut ownership. The desktop adapter is
mounted only in Play mode, and Edit-mode Play commands honor dialog, text-entry,
and active-operation guards.

### Dependency cycles or a tooling API that becomes public game API

Risk: sharing the compiler/host entangles editor, Core, and product UI.

Mitigation: preserve this dependency direction:

```text
runner_content_pipeline -> runner_core
rpg_runner playtest host -> runner_core
tools/editor -> runner_content_pipeline + rpg_runner playtest barrel
runner_core -X-> editor/content pipeline/Flutter/Flame
```

Keep editor playtest exports in `lib/playtest.dart`; do not add them to the
normal embedding barrel.

## Commit and documentation hygiene

Implement each phase as a coherent, independently validated commit. Do not
bundle unrelated working-tree changes, generated drift, or incomplete
migrations.

When implementation changes boundaries, update documentation in the same
phase:

- TDD: input ownership, playtest scenario/data flow, Core preview boundary,
  deterministic lifecycle, and asset loading
- GDD only if player-facing controls or gameplay rules change
- `tools/editor/README.md`: Windows Play mode and controls
- root README/public embedding docs only when the actual game adopts desktop
  input
- AGENTS files only when ownership or contributor rules materially change

This building plan records proposed work. It must not be cited as proof that
Play mode or desktop input is already implemented.
