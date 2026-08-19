# Editor Chunk Playtest Host

Status: Implemented tooling host and Windows Chunk Creator integration.

Last updated: August 19, 2026

## Purpose and boundary

The chunk playtest host runs one already validated, immutable
`ChunkPlaytestScenario` through the real deterministic Core and Flame bridge.
It exists behind `package:rpg_runner/playtest.dart`, a tooling-only entrypoint
that remains separate from the product embedding barrel `runner.dart`.

The host does not read an editor document, compile a scenario, decide whether
a draft is playable, or write repository state. The editor preparation and
route layers own those responsibilities. The host also imports no product app
state, Provider, Firebase, ticket, replay, ghost, reward, board, leaderboard,
or submission workflow.

## Editor snapshot preparation

`tools/editor/lib/src/playtest/chunk_playtest_preparation.dart` is the adapter
between the accepted authoring document and this host. The editor captures the
selected owner, its level/theme identity, and canonical Chunk, Prefab, and tile
source strings from the current immutable `ChunkV2Document`. It does not read
the document's repository baselines or create temporary source files, so valid
pending commands are part of the playtest while unapplied files remain
untouched.

Preparation runs in a background isolate through an injectable runner. It
delegates parsing, compilation, and typed pattern/terrain materialization to
`compilePolygonTerrainRuntimeChunkSource`, then delegates scheduler/seam
admission to `ChunkPlaytestScenario`. No editor-specific compiler or admission
path exists. Phase 5 fixes the scenario seed at `4401`, selects Eloise, and
uses the empty default loadout. A blocking parse, compile, level, or admission
issue returns stable editor diagnostics and no partial scenario.

## Editor readiness and route state

The current-schema Chunk workspace exposes only the selected accepted owner
and a fail-closed readiness result. Windows desktop targeting, a selected owner
and level, an idle session, no active gesture or uncommitted inspector draft,
and no blocking validation issue are required. Accepted session pending
changes are deliberately not a blocker. Migration-required or unavailable
source never exposes a usable Play action.

`ChunkCreatorPage` owns four route-local states: edit, preparing, playing, and
preparation failed. Starting preparation captures the document identity,
owner input, and workspace path under a monotonic generation. Stop, disposal,
document/controller replacement, and a newer attempt invalidate that
generation, so late isolate results cannot mount a host.

The existing `ChunkAuthoringWorkspace` remains mounted under `Offstage`,
`TickerMode`, and `IgnorePointer` while preparing or playing. It is therefore
non-interactive but retains its selected owner, scene domain, viewport,
toggles, local state object, undo/redo history, pending diff, and accepted
document identity. Stop returns to that same projection without reload or
Apply To Files. The route creates a fresh public host controller and a
read-only `RunnerWorkspaceAssetBundle` only after successful preparation, and
retires the controller after its host unmounts.

Preparation failures remain editor-owned and offer Retry or Return to Edit.
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
apply, undo, and redo. App inactive, paused, hidden, or detached state is
forwarded to the host as focus release; the desktop adapter neutralizes input
before the host pauses, and no automatic resume occurs.

## Runtime ownership

Each runtime generation owns a fresh graph:

```text
immutable ChunkPlaytestScenario
             |
             v
GameCore.chunkPlaytest -> GameController -> RunnerInputRouter
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
`RunnerChunkPlaytestController` and disposes it only after the host unmounts.

Initial mount and every restart call `GameCore.chunkPlaytest` again with the
same scenario, seed, character, loadout, and tick rate. Nothing is copied from
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
`RunnerWorkspaceAssetBundle`, which exposes reads only beneath the canonical
`<workspace>/assets/` directory.

Accepted keys are normalized forward-slash Flutter asset keys beginning with
`assets/`. Empty, absolute, drive-qualified, URI-like, backslash, dot, and
parent-traversal paths are rejected before I/O. The resolved target must remain
canonically contained under the canonical asset root, preventing directory
symlink escapes. Reads return copied byte data and never create, update,
delete, or copy repository files.

Workspace failures use stable codes for invalid keys, missing assets, escaped
paths, and I/O errors. The host preserves those codes in its failed status;
other construction and Flame load errors use host-specific stable codes with
human-readable details. Retry always builds a new generation and cache.

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
