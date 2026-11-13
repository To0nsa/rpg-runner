# Shared gameplay runtime

The product runner/Campaign, in-game Training Field and all three editor Play
modes share construction, input bindings and view composition. Core remains the
gameplay authority. The editor Training Field route still authors layout only.

## Ownership

| Owner | Responsibility |
| --- | --- |
| `lib/game/runner_gameplay_runtime.dart` | One owned Core, controller, router, Flame game, image cache and two aim models; starts paused at tick zero |
| `lib/ui/input/runner_gameplay_bindings.dart` | Semantic action-mode lookup, optional desktop device binding, aim cancellation, movement epoch, impact signals, charge feedback and optional haptics |
| `lib/ui/runner_gameplay_surface.dart` | One viewport/desktop-input/HUD coordinate space, metrics and deferred load-error reporting |
| `RunnerRunSession` | Product descriptor, recorder readiness, ghost lifetime and replay finalization |
| `TrainingFieldSession` / `TrainingFieldTab` | Selected build, auto-start, opponent picker, reset and tab lifetime |
| `runner_playtest_session.dart` | Backend-free editor loading/ready/running/paused/failed/stopped lifecycle and frozen restart |
| `AuthoredPlaytestSession` | Editor setup admission, captured sources/assets, preparation generation and return to authoring |

Sessions choose the existing Core factories explicitly. No universal mode state
machine, extra frame driver or editor filesystem dependency enters the game.
`RunnerGameWidget` retains product navigation, ticket preflight and resume policy;
`RunStartPreparation` remains the existing preflight coordinator. Training keeps
its safe-area, death-animation and unlock-aware opponent rules. Editor requires
explicit Start/Resume. Product mobile resume behavior remains separate.

Bindings stop first: cancel queued/held inputs and detach subscriptions. Runtime
stop fences preparation and controller ticks while retaining view-readable
notifiers. After GameWidget unmounts, dispose bindings and the runtime. Flame
render cleanup and notifier disposal are idempotent; `disposeAfterUnmount`
handles never-mounted attempts and rejects disposal while attached. A keyed
viewport survives changing desktop/touch wrappers without disposing the game.
Editor retired generations are disposed after the frame that removes them.

Charge-only cancellation retains movement. Full cancellation additionally changes
the touch movement epoch. Timeout, damage interruption, terrain failure and
stationary mouse aim refresh use the same binding in every host. HUD hits remain
outside the desktop world input adapter. Hosts decide when input is enabled.

`RunReplayFinalization` captures descriptor, recorder, summary and journal writer
before awaiting. Duplicate completion joins the pending operation; an explicit
retry follows a failed journal. Retirement prevents new work while an existing
operation can finish under its original run ID. Recorder close awaits it.
Disposal fences UI notifications. AppState still owns durable submissions and
backend authority; no account effects enter editor, Training or Developer Practice.

## Editor launch and preview

Chunk, Level and Campaign accept valid local fields through their existing page
commands, then open `PlaytestLaunchDialog`. Defaults are mobile HUD on, arrows and
iPhone 12 Pro. Floating/fixed joysticks, HUD off and custom logical dimensions/DPR
are available before capture. Cancel discards settings and starts no capture; it
does not undo already accepted authoring edits. Settings live in the page session.

Setup/capture acceptance checks controller, workspace, immutable document and
selected target. Repeated F5 keeps one setup dialog. Source replacement removes
only that session's setup and nested calibration routes. The session retires the
child route explicitly; it does not wait for the covered setup widget to dispose.
Retry captures current accepted sources with retained
settings; runtime Restart reuses the frozen scenario/assets/settings. Chunk and
Level omit a loadout override to use the same Core catalog starter path as Campaign,
including the shield. Explicit scenario overrides are preserved exactly.

The shared display frame receives logical geometry and a resolved uniform scale.
It centers the preview when it fits and exposes scrollbars when it overflows.
Window resizing changes margins/visible area, never scale. Scrollbars and wheel
scrolling pan overflow; dragging the game remains gameplay input. The entire game
and HUD receive the same scoped simulated MediaQuery and paint/input transform.
The simulated geometry clears monitor insets but retains ambient text scaling,
reduced motion and other accessibility preferences.
The product/Training hosts inherit the actual device environment unchanged.

## Physical calibration

Editor-only `display_calibration.dart` reads the Windows method channel
`lothringen.editor/display`. The adapter enumerates monitor device-interface IDs,
physical screen rectangles, resolution/orientation and the Flutter child window's
screen origin. It reports remote sessions. It does not infer physical size from
OS DPI. Missing native support remains unresolved rather than using a fit fallback.

The calibration dialog measures a reference line with a real ruler. The profile
stores physical pixels/mm, label and monitor/mode signature in
`%LOCALAPPDATA%/LothringenEditor/display_calibration_v1.json`. This is separate from
authored sources, saved game controls and mission settings. Invalid JSON/entries
are ignored. Resolution/orientation changes invalidate a profile; OS scaling alone
recomputes logical scale. Remote/unidentified monitors require explicit session
confirmation or a new measurement, never automatic profile reuse.

`scale = pixelsPerMm * deviceWidthMm / (monitorDpr * deviceLogicalWidth)`.

Device DPR belongs only to the inner simulated viewport. The outer monitor DPR
is applied once. `CalibratedPlaytestPreview` polls the native environment while
mounted, resolves the visible preview rectangle to one monitor, and blocks
Start/Resume while unresolved. Moving across monitors, straddling or changing
geometry cancels input and pauses the existing attempt. Resolving a profile never
automatically resumes it. Overflow is clipped to its scroll viewport before
monitor containment is checked.

`playtest_device_screen.dart` records manufacturer sources and quoted precision.
Presets model the nominal rectangular active screen, excluding chassis/bezel and
without cutout/system-bar emulation. The logical aspect ratio is preserved;
rounded DevTools dimensions are not stretched to match native pixels. iPhone SE
means the second generation and iPad Mini means the fifth generation. SE's size
is derived from Apple's 1334×750 pixels at 326 ppi because the rounded 4.7-inch
marketing diagonal alone exceeds the planned precision budget. Other diagonals
use manufacturer millimetres or rectangular-inch specifications.

This is layout/input preview, not hardware performance emulation. Automated tests
prove scale math, source fencing, input transforms and lifecycle retention. Actual
physical accuracy requires the ruler/device checks recorded in the
[implementation checklist](../building/shared_gameplay_runtime.md); mocked monitor
fixtures and native compilation do not establish the 1 mm per 100 mm target.
