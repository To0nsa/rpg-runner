# Editor Authored Playtest Host

Status: Implemented shared tooling host, captured authored Level/Chunk preparation, and both Windows editor Play entry points.

Last updated: September 9, 2026

## Purpose and boundary

The shared playtest host runs an already validated, immutable
`ChunkPlaytestScenario` or `LevelPlaytestScenario` through the real deterministic
Core and Flame bridge, with explicit captured appearance and image bytes.
It exists behind `package:rpg_runner/playtest.dart`, a tooling-only entrypoint
that remains separate from the product embedding barrel `runner.dart`.

The host does not read an editor document, compile a scenario, decide whether
a draft is playable, or write repository state. The editor preparation and
route layers own those responsibilities. The host also imports no product app
state, Provider, Firebase, ticket, replay, ghost, reward, board, leaderboard,
or submission workflow.

Normal gameplay and the editor host share `RunnerFlameGame`, including its
world-space terrain/Prefab ordering. The shared compiler normalizes Prefab z
against the owning Chunk's `groundBandZIndex`: lower values paint behind
terrain and equal/higher values paint over it, matching the authoring scene.
See [terrain rendering](polygon_terrain_authoring_foundation.md) for the
runtime priority and camera-transform contract.

## Editor snapshot preparation

`tools/editor/lib/src/playtest/authored_playtest_preparation.dart` captures
accepted source through `captureChunkPlaytestPreparationInput` or
`captureLevelPlaytestPreparationInput`. Both include the selected authored Level
metadata, assigned Parallax theme, complete selected-Level Chunk source set,
Prefab/tile dependencies, and current terrain-material definitions. The Level
adapter accepts the route's immutable `ChunkV2Document` dependency projection;
otherwise it loads that projection itself. No source files are written.

Capture checks canonical workspace paths and the loaded baselines for every
repository dependency before using accepted in-memory edits. It records exact
source text and the repository Chunk file set, rechecks them after capture, and
rechecks them after image capture. A changed, missing, or newly occupied source
returns a source-conflict issue; a stale projection cannot silently mix source
generations. The capture DTO copies and deterministically orders its inputs.

`preparePlaytest` is the pure compiler/admission entrypoint. It delegates every
selected-Level Chunk, including inactive source, to
`compilePolygonTerrainRuntimeChunkSource`; malformed source is never skipped.
It builds authored Level identity and settings, then delegates scheduler/seam
admission to the appropriate Core scenario. New Levels, first Chunks, themes,
and materials need no generated enum or catalog entry. Chunk Play projects the
current owner-catalog search, difficulty, and group filters into a playtest
pool, including a one-owner result. Core validates the exact compiled pool,
chooses a stable supported opener, and
builds a deterministic closed walk through matching physical boundaries that
covers every filtered active owner. No non-matching owner can enter that
multi-owner lasso; repeated matching owners may act as connectors. A filtered
set that cannot be covered and closed fails with a focused connection or seam
diagnostic instead of silently substituting content. A single matching owner
repeats only itself when its compiled exit matches its entrance; an incompatible
self seam fails with a diagnostic. For a filtered pool, Core first
checks the usual player start X, then searches nearby half-pixel X positions
within each candidate opener for a clear 32-by-64 px landing at the Level's
normal ground height. The chosen position is captured in the playtest Level
tuning and reused on restart. A solid normal-height entrance and the existing
exact connection rules remain required. The initial enemy-free prefix is
removed. The lasso retains an exactly matching repeating tail; see [chunk
connections](chunk_connections.md).
Whole-Level Play retains actual assembly, pacing, distinctness, looping and
marker rules. Default tooling selection is seed `4401`, Eloise, and the empty
default loadout.

`preparePlaytestInBackground` compiles off the UI isolate, captures the complete
image set used by the real renderer, validates decoded image dimensions and
Prefab/material source rectangles off the UI isolate, then checks source drift
again. The image set includes the selected character and runtime render
registries, background layers, all referenced material roles, and every active
pattern's visual sprites, including later streamed chunks. Actor sheets use the
same format flexibility as runtime decoding; authored atlas and Parallax inputs
must be PNGs. Asset capture rereads bytes to detect changes during capture.

A successful background result includes a scenario, `RunnerPlaytestAppearance`,
`RunnerCapturedAssetBundle`, source-and-image fingerprint, and warnings. Pure
compilation alone does not provide an asset bundle and cannot start an editor
host. Foreground Parallax layers remain unsupported by the runtime and produce
an explicit warning; only background layers are captured for rendering. Any
source, compilation, admission, missing-material, decoding, or rectangle error
returns diagnostics with no partial host input.

## Editor readiness and route state

The current-schema Chunk workspace exposes the canonically ordered filtered
owner keys and a fail-closed readiness result. Windows desktop targeting, a
selected owner and level, at least one filtered active owner, an idle session,
no active gesture, finalized valid inspector input, and no blocking validation
issue are required. The request finalizes completed visible edits before
checking strict capture readiness; invalid fields stay in the editor and stop
preparation. Accepted session pending
changes are deliberately not a blocker. Migration-required or unavailable
source never exposes a usable Play action.

The workspace header contains only the level selector, owner selector, and Play
button. It does not repeat route/schema, pending-change, or always-on readiness
status. Blocked capture readiness contributes an actionable diagnostic. Pending
inspector input can request finalization; active operations and unavailable
source remain blocked.

`AuthoredPlaytestSession` owns the shared edit, preparing, playing, and
preparation-failed lifecycle used by both `ChunkCreatorPage` and
`LevelCreatorPage`. Each page owns visible-input acceptance and selection;
`AuthoredPlaytestOverlay` presents the common host, preparation, and error views.
Starting preparation captures the document identity,
owner input, and workspace path under a monotonic generation. Stop, disposal,
document/controller replacement, and a newer attempt invalidate that
generation, so late isolate results cannot mount a host.

The existing `ChunkAuthoringWorkspace` remains mounted under `Offstage`,
`TickerMode`, and `IgnorePointer` while preparing or playing. It is therefore
non-interactive but retains its selected owner, scene domain, viewport,
toggles, local state object, undo/redo history, pending diff, and accepted
document identity. Stop returns to that same projection without reload or
Save to sources. The route creates a fresh public host controller only after successful
preparation, passes the result's frozen asset bundle and appearance to the host,
and retires the controller after its host unmounts.

Preparation failures remain editor-owned and offer Retry or Return to Edit.
Retry recaptures the accepted source generation; runtime Restart reuses the
existing frozen source and bytes.
Asset/loading/runtime/game-over failures remain host-owned. Neither path
creates a product run session or backend/replay side effect.

## Editor shortcut and shell ownership

`EditorHomePage` remains the only global keyboard and app-lifecycle listener.
It delegates to a narrow active-page contract only when its modal route is
current, no `EditableText` owns input, the event is an unmodified
`KeyDownEvent`, and the active page admits the command. Key-repeat events and
modified chords are not dispatched.

| Route state | Editor commands |
| --- | --- |
| edit | F5 requests Play through the same readiness result as the button |
| preparing/failed | F5 or Escape returns to Edit; failed state also offers Retry |
| playing | F5/Escape stop, F6 restarts, P pauses/resumes, Enter starts from ready |

While the route is not in edit, the shell disables route selection, reload,
Save, Undo, Redo, and Build. App inactive, paused, hidden, or detached state is
forwarded to the host as focus release; the desktop adapter neutralizes input
before the host pauses, and no automatic resume occurs.

## Runtime ownership

Each runtime generation owns a fresh graph:

```text
immutable ChunkPlaytestScenario / LevelPlaytestScenario
             |
             v
explicit Core playtest -> GameController -> RunnerInputRouter
                                  |                 |
                                  |                 v
                                  |       semantic action dispatcher
                                  |                 |
                                  v                 v
                         RunnerFlameGame <- desktop input adapter
```

The host owns Core indirectly through `GameController`, plus the router,
dispatcher, aim previews, desktop controller/focus node, Flame game, and a
per-generation `Images` cache. The caller owns
`RunnerPlaytestController` and disposes it only after the host unmounts.

Initial mount and every restart call `GameCore.chunkPlaytest` or
`GameCore.levelPlaytest` according to the concrete scenario, with the same
scenario, captured appearance, image bytes, seed, character, loadout, and tick rate. Nothing is copied from
the previous runtime. The host-local generation number increases monotonically
so late load/controller/focus callbacks from retired graphs cannot publish into
the replacement generation.

## Lifecycle contract

| Phase | Simulation | Gameplay translation | Admitted commands |
| --- | --- | --- | --- |
| loading | paused at tick zero | disabled | stop |
| ready | paused at tick zero | disabled | start, restart, focus, stop |
| running | active | enabled | pause, restart, focus, stop |
| paused | paused | disabled | resume, restart, focus, stop |
| game over | terminal | disabled | restart, focus, stop |
| failed | absent or paused | disabled | retry/restart, stop |
| stopped | absent | disabled | none |

Invalid or repeated controller commands return `false` and have no side
effects. Status publication is synchronous after each host transition and
contains the active generation, Flame load progress in `[0, 1]`, and stable
failure fields when applicable.

Start is explicit: asset readiness never advances Core. Pause disables and
cancels desktop/semantic input before pausing the controller. Focus loss uses
the desktop adapter's cancel-before-callback ordering and then transitions a
running host to paused. Ready, loading, paused, failed, game-over, and stopped
overlays keep gameplay translation disabled, so a button click cannot queue an
attack beneath the overlay.

Restart first neutralizes and detaches the old runtime, publishes a fresh
loading generation, removes the old `GameWidget`, and disposes its complete
graph after the frame. Stop follows the same neutralize/remove/dispose order,
publishes `stopped`, and invokes the caller callback once after disposal.
Ordinary widget disposal cancels resources but does not imply an explicit stop
callback.

## Presentation and input

The host mounts `RunnerDesktopInputAdapter` only around the fitted game
surface and supplies aim geometry from the current viewport, camera, and
player position. It mounts no touch overlay. `GameWidget.autofocus` stays off;
the adapter owns gameplay focus and the host requests it only through the
documented ready/start/resume paths.

The host always displays `PLAYTEST - NO REWARDS/REPLAY` and the fixed Windows
gameplay bindings. Ready, pause, failure, game-over, and stopped presentation
is owned by the host. Editor shortcuts and text-field/dialog interception are
not part of the host layer; the implemented editor integration calls the
public controller operations described above.

## Repository asset boundary

Every generation receives an isolated Flame `Images` cache. The production
game keeps its existing default cache behavior; tooling may inject an
`AssetBundle`. The editor-facing implementation is
`RunnerWorkspaceAssetBundle` during preparation, which exposes reads only
beneath the canonical `<workspace>/assets/` directory. The mounted host receives
`RunnerCapturedAssetBundle`; every restart receives copied bytes from that
immutable capture, even if original files later change or disappear. There is
no root-bundle fallback for a missing captured image.

Accepted keys are normalized forward-slash Flutter asset keys beginning with
`assets/`. Empty, absolute, drive-qualified, URI-like, backslash, dot, and
parent-traversal paths are rejected before I/O. The resolved target must remain
canonically contained under the canonical asset root, preventing directory
symlink escapes. Reads return copied byte data and never create, update,
delete, or copy repository files.

Workspace failures use stable codes for invalid keys, missing assets, escaped
paths, and I/O errors. The host preserves those codes in its failed status;
other construction and Flame load errors use host-specific stable codes with
human-readable details. Restart builds a new generation and cache from the same
capture. Tooling also injects explicit theme/material maps: their absence is a
failure rather than a generated-registry fallback. Production composition keeps
its existing generated registries when those injection arguments are omitted.

## Product isolation

Playtest runs have no run ticket and do not record or spool a replay. They do
not authenticate, call a backend, settle rewards, project a score, publish a
ghost, or mutate player/account state. Game-over presentation explicitly says
that no reward, replay, or score was recorded. This isolation is composition,
not a conditional branch inside product state orchestration.

## Verification

The executable boundary is covered by:

- `test/playtest/runner_chunk_playtest_host_test.dart`
- `test/playtest/runner_workspace_asset_bundle_test.dart`
- `test/ui/input/desktop/runner_desktop_input_adapter_test.dart`
- `tools/editor/test/chunk_playtest_preparation_test.dart`
- `tools/editor/test/chunk_playtest_editor_integration_test.dart`
- `tools/editor/test/chunk_playtest_performance_test.dart`
- `tools/editor/test/level_playtest_editor_integration_test.dart`
- `tools/editor/test/authored_playtest_session_test.dart`
- `packages/runner_core/test/playtest/level_playtest_scenario_test.dart`
- `tools/editor/test/editor_home_playtest_shortcut_test.dart`
- `tools/editor/integration_test/chunk_playtest_windows_acceptance_test.dart`

Coverage includes real Core/Flame readiness, physical keyboard translation,
pause/resume and focus-loss neutralization, exact tick-zero restart, stale
generation callbacks, game over, explicit load failure and retry, rapid
restart/stop, isolated cache cleanup, one-shot explicit stop, non-stop widget
disposal, canonical asset containment, symlink escape rejection where the host
supports it, accepted pending-document capture, preparation cancellation and
retry, Edit-state restoration, shell/text/modal shortcut guards, app lifecycle
pause, resize and non-unit-DPI aim geometry, repeated lifecycle cycles with
disposed-controller checks, preparation timing, native Windows keyboard/mouse
input, file-hash stability, and proof that workspace reads do not write files.
