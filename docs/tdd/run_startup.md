# Run startup

## Ownership and entry points

The app has two preparation boundaries. UI preflight obtains an authoritative
RunStartDescriptor; the run then prepares local resources without advancing ticks.
Debug-only [Developer Practice](developer_practice.md) instead creates an
explicitly local descriptor through the same preflight, without an authenticated
ticket. It uses the same world, simulation and controls, skips replay recording
and submission, and requires only world readiness. Restarts remain local.

- RunStartPreparation in lib/ui/run coordinates selection, AppState preflight,
  failure reporting, and cancellation. Hub and leaderboard starts use
  RunStartBootstrapPage. Leaderboard mode/level changes use the existing paired
  selection API. In-place restarts use the same preparation coordinator with
  expected mode/level constraints; AppState still performs the fresh canonical
  read and issues a new ticket for a restart.
- AppState and its existing APIs remain responsible for auth, ownership sync,
  ticket prefetch/consumption, ticket issuance, and ghost artifact retrieval.
  A start joins an in-flight prefetch for the exact authenticated user, ownership
  revision, mode, level, character, loadout and compatibility key before consuming
  its ticket once. Failed, expired or mismatched prefetch falls back to foreground
  issuance. Canonical/auth invalidation fences late results even if the eventual
  key compares equal. Selection/session changes during the wait reject the start.
  A still-valid cached ticket suppresses redundant warmup requests.
  Cancelling a UI request prevents navigation and subsequent preparation steps;
  it does not revoke backend calls that have already been issued.
- RunnerRunSession owns the local GameController, input router, aim models,
  RunnerFlameGame, ghost playback/feed, and replay recorder for one descriptor.
  RunnerGameWidget owns presentation, lifecycle/input policy, restart navigation,
  haptics, and completed-run submission UI.
- RunnerFlameGame owns render readiness. Its registries own asset requirements;
  Core owns terrain selection and the existing bounded preparation cache.

## App bootstrap

After authentication (and flush-before-refresh on resume), profile and canonical
ownership reads run concurrently. Both must succeed before either result is
published. Existing disposal/account-change guards, ownership revision checks,
and outbox projection still apply. Studio splash and cold-start loader minimum
branding durations are unchanged; run loading has no artificial minimum.

## Readiness and failures

The controller begins paused at tick zero. World loading starts player images,
render registries, terrain preparation, background loading, and optional ghost
preparation concurrently. Player and static-prefab mounting overlap registry
loading. Scene readiness includes all required art and selected ghost visual
preparation; worldReady additionally waits for initial terrain readiness.
RunLoadState.failed retains the required-load error and stack for diagnostics.
The widget handles Flame's error future while the session presents recovery.

The session becomes ready only when the world is ready AND the replay recorder
has initialized. RunRecorder.create starts its lazy file consumer with an empty
buffer and awaits flush, so a file-open error is reported before Start without
adding any replay bytes. Recorder initialization can finish before or after the
world. The ready prompt and HUD wait for both; Start does not retry initialization
or ask the player to tap again. The first live command frame is recorded.

Required world or recorder failure shows Retry and the host's Exit action.
A pre-start retry reuses the same descriptor, including any selected ghost, and
keeps tick zero. It first stops the old session and awaits even a late recorder
creation/close before opening the same replay paths. A completed-run restart
continues to request a fresh server ticket instead of reusing a consumed run.

Stop immediately fences world preparation, stops terrain work through controller
shutdown, detaches ghost/tick listeners, and prevents late readiness notifications.
Flame still owns component removal and image disposal. Deferred work already
queued may finish, but cannot publish into a successor. Widget replacement delays
notifier disposal until the old subtree is detached. Final widget disposal also
closes a recorder that finishes opening after exit. A cancelled world load clears
late-decoded images on both successful and failed completion.

Ghost playback/outline preparation failures remain optional and disable the ghost.
A failure to retrieve the selected ghost artifact during remote preflight still
fails that request; it is not silently converted into a different race.

## Lifecycle pause and resume

RunnerGameWidget pauses the controller and clears held gameplay inputs whenever
the app leaves the resumed lifecycle. If the run was playing, it retains that
resume intent through every subsequent inactive, hidden, or paused notification.
Returning to resumed consumes the intent and unpauses only a started, unfinished
run. A manual pause, exit confirmation, or pre-start ready state stays paused.
Background time does not advance simulation ticks, and movement/ability holds
must be pressed again after returning.

Pause, lifecycle, focus-loss, restart, and exit cancellation discard every
unapplied movement, aim, hold starts, and action presses through RunnerInputRouter
before scheduling releases for its current held ability slots. Already queued
hold releases survive, including a previous slot during an unapplied switch.
Movement/aim scheduling and commit-time aim protection reset with that queue.
A queued tap or aimed release cannot fire on resume, while releases for holds
already applied to Core survive cancellation.

## Asset loading and performance

UiAssetLifecycle owns menu previews only. The former whole-catalog Flutter
precache pass, run preview scopes, and run-exit preview purge are removed.
Flutter precaching did not populate the separate Flame Images cache. Runtime
images are now decoded by their run-owned registries/cache without that earlier
awaited duplicate pass. Live and ghost player views still share the run's
PlayerAnimationLibrary. Registry coverage and terrain lookahead limits are unchanged.

RunAssetPreloader consumes the registries' existing manifests into that same
run-owned Flame Images cache. It deduplicates paths across groups and permits
eight concurrent catalog reads/decodes. Each registry constructs its sprites
when its own sources are ready; groups do not wait for unrelated images. Terrain
and parallax loading remain independent. Cancelling startup rejects queued
catalog work; already-running decodes drain before the closing load clears its
cache. A retry owns a new cache/preloader, including after a failed image.

GameCore.prepareTerrainForRun awaits the complete eight-state lookahead. Native
startup uses two independent isolate workers; browsers retain one cooperative
lane. Each finished candidate is immediately available under its exact selection
key. The next job is chosen from the latest requested window. Startup completion
still drains every worker; shutdown/failure prevents queued work and rejects late
results. Runtime refills retain one worker, the eight-state cache, and per-tick
admission. Live and ghost startup share this boundary. Initial worker errors fail
loading instead of being silently deferred until the first terrain miss.

The explicit GameCore.prepareTerrainAhead API retains one worker for ordinary
refills and serial benchmark controls. Reducing the awaited window was rejected:
a fixed-input browser experiment traded earlier readiness for a later terrain
wait. The shipped startup gate preserves the existing preparation headroom.

There is no minimum run-loading delay. Progress remains milestone-based and the
UI uses an indeterminate spinner. Once the scene is ready it can specifically
report terrain preparation; art, ghost and recorder waits also have phase labels.
RunnerFlameGame.loadTimings records overlapping wall durations by task. The
standalone gameplay benchmark includes constructor time, time to world-ready,
prepared-state count and image count. Durations overlap and must not be summed.
See [startup audit and measurements](../verification/run_startup_2026-10-11.md)
for the measured workload and its limits.

Device diagnosis can opt into `--dart-define=RUN_STARTUP_TRACE=true` in debug or
profile builds. `RunStartupDiagnostics` emits local JSON lines for preflight,
ownership/auth/ticket waits, recorder opening, construction, world milestones
and final readiness. It excludes account IDs, tickets and replay contents and
is disabled in release builds. Timings include overlapping wall waits; phase
logging is diagnostic, not a progress clock or readiness dependency.

The gameplay benchmark accepts native options through `BENCHMARK_OPTIONS` in
a Dart define file. `compareWarmup=1` repeats each filtered scenario in serial,
parallel, parallel, serial order with the same command tape when
`scriptedInput=1`. Keep the phone awake and unlocked for the entire capture;
discard passes interrupted by device suspension. These controls remain in the
standalone benchmark.

## Verification

Focused tests cover both readiness completion orders, required failures, first-tick
recording, world and recorder retry, late completion after exit, duplicate preflight
requests, in-flight prefetch consumption/invalidation, parallel bootstrap reads,
cancellation during selection/ticket retrieval, hub/leaderboard routing,
recorder file-open errors, ghost readiness/cleanup, and existing terrain-render
readiness. Lifecycle regressions cover the full background/return sequence,
frozen ticks, cleared movement input, manual pauses, and pre-start readiness.
Gameplay generation, authority, and replay compatibility are unchanged.
