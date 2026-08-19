# Editor Chunk Playtest Host

Status: Implemented tooling host; editor integration is not yet implemented.

Last updated: August 19, 2026

## Purpose and boundary

The chunk playtest host runs one already validated, immutable
`ChunkPlaytestScenario` through the real deterministic Core and Flame bridge.
It exists behind `package:rpg_runner/playtest.dart`, a tooling-only entrypoint
that remains separate from the product embedding barrel `runner.dart`.

The host does not read an editor document, compile a scenario, decide whether
a draft is playable, or write repository state. Those responsibilities remain
with the caller. It also imports no product app state, Provider, Firebase,
ticket, replay, ghost, reward, board, leaderboard, or submission workflow.

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
not part of this layer; the future editor integration will call the public
controller operations.

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

Coverage includes real Core/Flame readiness, physical keyboard translation,
pause/resume and focus-loss neutralization, exact tick-zero restart, stale
generation callbacks, game over, explicit load failure and retry, rapid
restart/stop, isolated cache cleanup, one-shot explicit stop, non-stop widget
disposal, canonical asset containment, symlink escape rejection where the host
supports it, and proof that workspace reads do not write files.
