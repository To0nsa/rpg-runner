# Windows Chunk Playtest Phase 4 Implementation Checklist

Date: August 19, 2026

Status: In progress

Source plan: [Windows Chunk Playtest and Reusable Desktop Input Plan](plan.md)

Phase 3 evidence:
[Phase 3 implementation checklist](phase3-implementation-checklist.md)

This checklist implements Phase 4 only: add a narrow tooling-only package
entrypoint and a backend-free Flutter/Flame host for an already validated
`ChunkPlaytestScenario`. It mounts the shared desktop adapter and owns runtime
lifecycle, presentation, asset loading, and cleanup. It does not integrate the
host into the Chunk Creator yet.

## Completion gate

Phase 4 is complete only when:

- `lib/playtest.dart` exports a deliberate editor-facing API without changing
  `lib/runner.dart`
- every start/restart constructs `GameCore.chunkPlaytest` from the same
  immutable scenario and a fresh controller/router/dispatcher/Flame graph
- the host mounts the Phase 3 desktop adapter and no touch controls
- loading, ready, running, paused, game-over, failed, stopped, restart, focus
  loss, and disposal paths neutralize input in the required order
- a host-supplied asset bundle can load repository images read-only, and the
  workspace implementation rejects absolute paths, traversal, and symlink
  escapes
- no Provider, `AppState`, Firebase, run ticket, replay recorder/spool,
  submission, ghost, reward, board, or leaderboard code is invoked
- focused widget/unit tests prove lifecycle behavior, deterministic restart,
  asset safety/failure diagnostics, and complete cleanup

## Scope boundaries

### In scope

- `lib/playtest.dart` and a focused `lib/playtest/**` implementation
- a public playtest lifecycle/status/controller contract for later editor
  shortcut integration
- `GameCore.chunkPlaytest`, `GameController`, `RunnerInputRouter`, semantic
  dispatcher, `RunnerFlameGame`, previews, and desktop adapter composition
- ready/loading/running/paused/game-over/failed/stopped presentation
- explicit start, pause/resume, restart, focus, and stop operations
- isolated Flame `Images` cache with an injectable `AssetBundle`
- a read-only Windows workspace asset bundle with canonical containment checks
- focused tests and TDD updates for host/data/asset ownership

### Out of scope

- building a scenario from editor documents or compiler diagnostics
- adding `rpg_runner` as an editor dependency or mounting the host in a route
- F5/F6/Escape/P/Enter shortcut interception and text-field/dialog guards
- mutation locking, Edit state restoration, pending diffs, or source drift
- product desktop input adoption or changes to public embedding APIs
- backend/replay/reward/ghost behavior, network calls, or persistent writes
- new game rules, Core commands, protocol fields, or generated content

## Chosen host boundary

| Concern | Phase 4 owner |
| --- | --- |
| Draft compilation and scenario validation | Phase 1/2 callers |
| Deterministic runtime construction | playtest host via `GameCore.chunkPlaytest` |
| Simulation/render bridge | existing controller and Flame game |
| Gameplay semantics/device focus | Phase 3 dispatcher/desktop adapter |
| Host lifecycle commands | public playtest controller |
| Repository image reads | workspace asset bundle |
| Editor mode, shortcuts, restoration | Phase 5 |

The host accepts a complete immutable scenario. It must not reach back into an
editor document, compile source, change the scenario seed, or make Play mode a
validation authority.

## Step 0 — Runtime and asset audit

- [x] Re-read root/game/UI layer and documentation guidance.
- [x] Trace `RunnerFlameGame` construction, load progress, image-cache
      ownership, `GameWidget` load errors, and controller disposal order.
- [x] Confirm Flame permits a per-game `Images` cache backed by an injected
      Flutter `AssetBundle`.
- [x] Confirm `RunnerGameWidget` cannot be reused without importing real-run
      replay, Provider, backend, ghost, and settlement concerns.
- [x] Keep the unrelated terrain-material authoring JSON outside every Phase 4
      commit.

## Step 1 — Add the tooling-only public surface

- [ ] Add `lib/playtest.dart` and export only the scenario-facing host,
      lifecycle values, workspace asset bundle, and required stable types.
- [ ] Keep all implementation under `lib/playtest/**` or existing shared
      game/input/viewport modules.
- [ ] Do not export playtest APIs from `lib/runner.dart`.
- [ ] Document public construction, ownership, disposal, asset, and callback
      requirements so the editor does not depend on internal paths.

## Step 2 — Make Flame image loading host-configurable

- [ ] Allow `RunnerFlameGame` to receive an optional per-game `Images` cache
      while preserving the normal game's current default behavior.
- [ ] Give each playtest runtime a fresh isolated image cache.
- [ ] Use the host-supplied bundle for all player/enemy/projectile/terrain/
      parallax loads without copying assets into the editor package.
- [ ] Surface load failures through stable playtest failure state/presentation.
- [ ] Prove image caches are cleared with the old runtime on restart/disposal.

## Step 3 — Add the read-only workspace bundle

- [ ] Accept one existing repository workspace root and expose only bundle
      reads beneath its `assets/` directory.
- [ ] Normalize bundle keys deterministically and reject empty, absolute,
      drive-qualified, URI-like, backslash, dot, and `..` paths.
- [ ] Resolve the real file path before reading and require canonical
      containment beneath the canonical asset root, including symlink escapes.
- [ ] Return immutable byte data and perform no create/write/delete operation.
- [ ] Distinguish invalid key, missing asset, escaped path, and I/O failures in
      stable diagnostics.
- [ ] Test valid nested reads, traversal/absolute/drive/URI paths, missing
      files, symlink escape where supported, and proof of no workspace writes.

## Step 4 — Compose the backend-free runtime

- [ ] Construct a fresh Core/controller/router/dispatcher/preview/Flame graph
      from the scenario for initial load and every restart.
- [ ] Resolve dispatcher modes from the current runtime HUD snapshot.
- [ ] Mount `RunnerDesktopInputAdapter` around the fitted game surface and
      provide current viewport/camera/player aim geometry.
- [ ] Keep gameplay input disabled while loading, ready, paused, failed,
      game-over, or stopped so overlay clicks cannot queue gameplay commands.
- [ ] Keep `GameWidget.autofocus` disabled; request only adapter-local focus
      once ready/start/resume makes it appropriate.
- [ ] Add no touch overlay, Provider lookup, app state, replay recorder, ghost,
      haptics, submission, or backend client.

## Step 5 — Implement lifecycle and presentation

- [ ] Publish immutable status for loading progress, ready, running, paused,
      game-over, failed, and stopped states.
- [ ] Expose start, pause, resume/toggle, deterministic restart, focus request,
      and stop operations through a host controller suitable for Phase 5.
- [ ] Start only from ready; pause only from running; resume only from paused;
      make invalid/repeated commands safe no-ops.
- [ ] On focus loss, cancel desktop/semantic input before entering paused.
- [ ] Restart by canceling the old adapter, replacing the complete runtime with
      a fresh graph from the same scenario/seed, and disposing the old graph.
- [ ] Stop by canceling/disposing runtime state, publishing stopped, and then
      invoking the host callback exactly once.
- [ ] Detect Core game-over, neutralize input, and offer restart/stop without
      reward, score submission, or replay language.
- [ ] Present a persistent `PLAYTEST - NO REWARDS/REPLAY` label and compact
      fixed Windows control legend.
- [ ] Present explicit load/asset/runtime errors with retry and stop actions.

## Step 6 — Prove host isolation and lifecycle

- [ ] Widget-test real ready -> start -> running and semantic keyboard input.
- [ ] Test pause/focus-loss cancellation and explicit resume.
- [ ] Test restart creates a distinct runtime at the exact original tick-zero
      snapshot and stale load callbacks cannot change the replacement state.
- [ ] Test game-over, failed load/retry, stop callback once, widget disposal,
      and rapid repeated restart/stop safety.
- [ ] Assert touch controls, Provider, Firebase, replay, submission, ghost, and
      reward types are absent from the playtest implementation import graph.
- [ ] Prove no replay spool, repository source, generated output, or backend
      state is written during host lifecycle tests.

## Step 7 — Documentation, validation, and commits

- [ ] Update TDD documentation with implemented playtest construction, state,
      focus, asset, error, and cleanup ownership.
- [ ] Update the source plan and this checklist with factual Phase 4 delivery
      status only.
- [ ] Confirm no GDD, root README, editor README, or public embedding update is
      needed before Phase 5 mounts the feature.
- [ ] Run `dart format` on changed Dart files.
- [ ] Run `dart analyze lib test` and focused host/asset/input tests.
- [ ] Run relevant existing Flame/run-widget/input tests.
- [ ] Run the broader root Flutter suite and record only established external
      baseline exceptions separately.
- [ ] Run `git diff --check`, public-export, import-boundary, and write-safety
      searches.
- [ ] Commit planning, asset/runtime, host, and factual closeout milestones as
      coherent validated commits.

## Evidence record

### Validation

| Date | Command/test | Result | Notes |
| --- | --- | --- | --- |
| Pending | Host and asset tests | Pending | — |
| Pending | Analysis and relevant regression tests | Pending | — |
| Pending | Isolation/import/write checks | Pending | — |

### Delivered contracts

Pending implementation.

## Closeout

- [ ] Every Phase 4 checkbox is complete or explicitly accepted with evidence.
- [ ] Update status to `Complete` with date and commit references.
- [ ] Do not begin Phase 5 editor integration until host restart, cleanup,
      asset containment, and backend-isolation gates are green.

Phase 4 completion means the editor can later mount one already prepared
scenario through a safe backend-free Windows playtest surface. It does not add
Play/Edit state or shortcuts to the Chunk Creator.
