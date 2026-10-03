# Run startup

## Ownership and entry points

The app has two preparation boundaries. UI preflight obtains an authoritative
RunStartDescriptor; the run then prepares local resources without advancing ticks.

- RunStartPreparation in lib/ui/run coordinates selection, AppState preflight,
  failure reporting, and cancellation. Hub and leaderboard starts use
  RunStartBootstrapPage. Leaderboard mode/level changes use the existing paired
  selection API. In-place restarts use the same preparation coordinator with
  expected mode/level constraints; AppState still performs the fresh canonical
  read and issues a new ticket for a restart.
- AppState and its existing APIs remain responsible for auth, ownership sync,
  ticket prefetch/consumption, ticket issuance, and ghost artifact retrieval.
  Cancelling a UI request prevents navigation and subsequent preparation steps;
  it does not revoke backend calls that have already been issued.
- RunnerRunSession owns the local GameController, input router, aim models,
  RunnerFlameGame, ghost playback/feed, and replay recorder for one descriptor.
  RunnerGameWidget owns presentation, lifecycle/input policy, restart navigation,
  haptics, and completed-run submission UI.
- RunnerFlameGame owns render readiness. Its registries own asset requirements;
  Core owns terrain selection and the existing bounded preparation cache.

## Readiness and failures

The controller begins paused at tick zero. World loading starts player images,
render registries, terrain preparation, background loading, and optional ghost
preparation concurrently. It then awaits ghost visual preparation and mounts the
initial player/static scene before publishing worldReady. RunLoadState.failed
retains the original required-load error and stack for diagnostics. The widget
handles Flame's error future while the session presents the recovery state.

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

## Asset loading and performance

UiAssetLifecycle owns menu previews only. The former whole-catalog Flutter
precache pass, run preview scopes, and run-exit preview purge are removed.
Flutter precaching did not populate the separate Flame Images cache. Runtime
images are now decoded by their run-owned registries/cache without that earlier
awaited duplicate pass. Live and ghost player views still share the run's
PlayerAnimationLibrary. Registry coverage and terrain lookahead limits are unchanged.

Independent local tasks overlap rather than waiting for player animations before
starting registries and terrain preparation. This removes serial work from the
startup path; it is not a measured device-specific loading-time guarantee.
Internal progress remains milestone-based and the UI shows an indeterminate
spinner with a phase label. There is no minimum run-loading delay.

## Verification

Focused tests cover both readiness completion orders, required failures, first-tick
recording, world and recorder retry, late completion after exit, duplicate preflight
requests, cancellation during selection/ticket retrieval, hub/leaderboard routing,
recorder file-open errors, ghost readiness/cleanup, and existing terrain-render
readiness. Gameplay generation, authority, and replay compatibility are unchanged.
