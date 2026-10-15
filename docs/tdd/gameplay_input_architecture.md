# Gameplay Input Architecture

Status: Implemented shared input boundary; the Windows Chunk and Level Creators
mount the tooling-only desktop host, while the product game does not yet mount it.

Last updated: October 14, 2026

## Purpose

This document defines how touch and desktop device input becomes deterministic
runner commands. It fixes ownership for semantic action modes, physical device
state, focus, aim conversion, and cancellation so future editor and Windows
game hosts reuse the same behavior without importing each other's UI.

## Implemented dependency direction

```text
touch controls -> GameOverlay ------------------+
                                                  |
Windows keyboard/mouse adapter -----------------+--> semantic dispatcher
                                                          |
                                                          v
                                                 RunnerInputRouter
                                                          |
                                                          v
                                                 GameController -> Core
```

- `lib/ui/controls/**` owns touch gestures and touch-only presentation.
- `GameOverlay` translates those callbacks into semantic actions.
- `lib/ui/input/desktop/**` owns Flutter key, mouse, focus, and fitted-viewport
  conversion. It imports no touch controls or editor source.
- `RunnerSemanticActionDispatcher` owns device-neutral action lifecycles.
- `RunnerInputRouter` remains the only layer that schedules tick-stamped Core
  commands, buffers continuous input, owns held-slot exclusivity, and combines
  aim with a release commit.
- `GameController` coalesces scheduled commands into deterministic input
  frames. Neither UI adapter constructs a Core command.

`RunnerGameWidget` routes its existing touch controls through the semantic
dispatcher, but it deliberately does not mount `RunnerDesktopInputAdapter`.
`RunnerPlaytestHost` is the desktop consumer, mounted by the standalone editor's
Windows Chunk and Level Creators through the narrow
`package:rpg_runner/playtest.dart` tooling entrypoint. Both entry points share
the host lifecycle and input handling; their focused Chunk and seeded Level
scenarios follow the [authored Play contracts](editor_chunk_playtest_host.md).

## Semantic action contract

`RunnerGameplayAction` contains only gameplay intent: left, right, jump,
primary, secondary, projectile, spell, and mobility. Pause, start, restart,
stop, focus restoration, and editor shortcuts are host actions and are not
valid semantic gameplay actions.

The dispatcher supports these lifecycle operations:

| Operation | Use |
| --- | --- |
| `triggerAction` | touch tap with no retained pressed state |
| `beginAction` | physical down or touch hold start |
| `commitAction` | touch release commit separated from hold end |
| `endAction` | non-committing touch hold end |
| `releaseAction` | desktop commit-if-needed plus end |
| `cancelAction` | end one action without release commit |
| `cancelAll` | neutral movement/aim and release every supported hold |

The authoritative HUD `AbilityInputMode` is resolved once at `beginAction` and
retained through release or cancellation. A loadout/snapshot change during a
hold cannot reinterpret its matching release.

| Mode | Begin | Normal release | Cancel |
| --- | --- | --- | --- |
| `tap` | one press edge | no action | clear pressed bookkeeping |
| `holdAimRelease` | held-slot edge | aimed commit, then held-slot release | held-slot release only |
| `holdMaintain` | held-slot edge plus press | held-slot release | held-slot release |
| `holdRelease` | held-slot edge | commit, then held-slot release | held-slot release only |

Primary, secondary, projectile, and mobility support both release modes.
Primary, secondary, and mobility support hold-maintain. Projectile
hold-maintain is rejected with `runner_input_unsupported_mode`; spell and jump
reject every non-tap mode.

The existing touch leaf widgets have two callback orders. Directional release
commits before hold-end, while `HoldActionButton` calls hold-end before its
release callback. The dispatcher retains one immediately pending release-mode
commit so both produce the established same-tick command frame. Pointer cancel
does not call commit, and a new begin, explicit cancel, or `cancelAll` discards
any pending eligibility.

## Movement and held-source aggregation

### Action-control presentation

The run HUD and the Skills radial preview share `abilityRadialLayoutSpec` and
the circular control shell. Its Lucide symbols identify slots (sword, shield,
bow/arrow, wind/dash, upward jump, magic wand). Controls contain no visible
labels or authored skill images; their names remain semantic accessibility
labels. Skill lists, details, and store cards retain `GameIcon.ability` artwork.

`SnapshotBuilder` publishes an immutable, complete `abilityCostsBySlot` map in
`PlayerHudSnapshot`, using the same resolved commit costs as affordability.
Jump exposes its air cost while an air jump is available. The Skills preview
uses `resolveEffectiveAbilityCostForLoadout`, which shares payload selection
with the runtime store resolver. `ControlResourceUsage` also includes authored
hold stamina drain; the menu preview includes both ground and air-jump costs.
These values select colors and identify resource shortfalls for presentation.
Core affordability, slot validity, input modes, and cooldown ticks continue to
determine whether an action can begin.

`GameOverlay` supplies shortfalls only for valid slots whose authoritative
affordability flag is false. `ControlResourceUsage.shortfall` compares the
snapshot resource amounts with resolved commit costs (health spending must
leave one fixed-point unit). It does not infer ongoing hold drain or change
action gating. `RunnerControlsOverlay` additionally suppresses warnings during
cooldown. `ResourceActionFeedback` catches blocked pointer-downs outside the
disabled tap/hold/aim widget, outlines that control and forwards a UI-only
warning. No press, hold, release or Core command is emitted by this path.
Every blocked tap publishes a fresh warning, including repeated identical
shortfalls. This feedback describes current shortages, not a Core rejection
event; it is currently specific to the in-run touch controls.

`TopLeftHudOverlay` reads resource values directly from controller snapshots.
`ResourceBar` owns only interpolation, a recent-health-loss trail and transient
warnings. Decreases snap immediately; regeneration uses exponential smoothing
with a 60 ms time constant, so per-tick updates do not restart a tween. Health
loss holds for 180 ms and drains over 420 ms, independent of regeneration.
At 0 < health <= 25%, the outline pulses with a 1.6-second period. Tickers stop
when no visual work remains; pause/end settles values and clears warnings.
Reduced motion settles values and uses static low-health/450 ms shortfall
outlines. Maximum changes reset interpolation, and replacing the controller
remounts the vitals to prevent trails leaking between runs. Resource semantics
always expose current snapshot values, never interpolated values.

`UiHudTheme` is the shared ThemeExtension for the vitals, timer, score, boss
panel and pause/exit framing. Its charcoal surface and pale 1-pixel border use
the same visual family as the action controls. The compact vitals variant
keeps the top row separate below 600 logical pixels; the boss panel starts at
86 pixels to clear the taller vitals panel.

`UiActionButtonTheme` mutes the shared health/mana/stamina bar colors with a
charcoal overlay. Fills are approximately 58% opaque, allowing the scene to show
through. Free actions use neutral charcoal; multiple resources use a single
translucent gradient without a second fill underneath. Symbols dim on cooldown
and when unaffordable, and the
cooldown ring remains visible. The Skills selection ring is a quiet solid
outline with no backing disk. Symbol size scales with the touch target,
independently of skill art.

### Touch presentation and device preference

Options uses `AppSegmentedControl` for Settings/Controls and the movement-mode
choice. `AppServices` owns `ControlSettings` separately from `AppState`, so
profile replacement does not reset device preferences. Production injects
`SharedPrefsControlSettingsStore`; initialization restores the choice before
ready routes, including Developer Practice. The key is
`controls.movement_mode.v1`, with stable `arrows` / `joystick` values. Missing,
unknown or malformed values fall back to arrows. Writes are serialized by a
saving guard, publish only after success, and surface failure in Options while
retaining the previous selection. Hosts without a store use in-memory settings.

`UiApp` supplies the current choice when `UiRouter` creates a run route.
`createRunnerGameRoute` and `RunnerGameWidget` expose `movementControlMode`
(default arrows) for embedded hosts. It flows through `GameOverlay` and
`RunnerControlsOverlay` into `MovementControl`, and survives same-widget
restarts. Preference storage stays outside the run descriptor, Core, backend,
and replay contracts.

`MovementControl` selects `MoveButtons` or `MoveJoystick`, sharing the movement
callback and palette. Both emit **only -1, 0, 1**. The floating joystick uses a
96-pixel base, a 40-pixel thumb and an 8-pixel horizontal neutral deadzone (all
logical pixels, in `MoveJoystickTuning`). Its stationary hit region covers the
lower-left quarter of the overlay; action controls are stacked above it. On
touch-down the base centers under that pointer with neutral input. Horizontal
displacement is clamped to the thumb's 28-pixel travel radius, and excess travel
moves the base. The base follows the pointer's Y directly, so vertical drag
only moves the artwork. Beyond the horizontal deadzone the displacement's sign
produces full-strength input; reversal is relative to the current base.

The listener stays stationary while the artwork can paint beyond its activation
area, preserving a stable coordinate space and pointer capture during overdrag.
The first pointer owns the stick until up/cancel; other pointers cannot take it
over or interfere with action controls. Release/cancel restores the idle base
at the existing movement insets. Both presentation modes retain the same
`MovementControl` element so switching still neutralizes an active gesture.

The existing semantic dispatcher and router still schedule all movement.
Gameplay speed, acceleration, collision, timing and replay encoding are
unchanged. The run clears input on pause, lifecycle loss and exit. It also
increments a movement input epoch so UI pointer state is discarded even when
background/resume occurs without an intervening frame. Disabling movement or
changing presentation similarly neutralizes the axis and resets pointer state.
Runtime terrain waits preserve mounted controls and release delivery; terrain
failure follows the existing cancellation path.

### Desktop aggregation

Touch movement continues to supply a horizontal axis. Desktop movement uses
held left/right actions:

- left only resolves to `-1`
- right only resolves to `1`
- left and right together resolve to `0`
- releasing either direction immediately recomputes from the remaining state

The desktop controller aggregates every physical source into an active action
set before emitting transitions. This makes alternate keys and key/mouse pairs
reference-safe: releasing `A` does not end move-left while Left Arrow remains
held, and releasing `J` does not end primary while the left mouse button still
owns that action.

Only `KeyDownEvent` adds a key and `KeyUpEvent` removes it. `KeyRepeatEvent`
and duplicate downs are handled without producing another semantic begin.
Bindings use `PhysicalKeyboardKey`, so keyboard layout does not change the
documented Windows positions.

## Desktop focus and cancellation

`RunnerDesktopInputController` owns exactly one `FocusNode`. The widget uses a
local `Focus.onKeyEvent`; it installs no global keyboard handler. Only mouse
pointer events are admitted by `RunnerDesktopInputAdapter`, so mounting the
desktop adapter does not turn touch contact into a mouse gameplay action.

The controller exposes:

- `requestFocus`: clear stale state, then acquire gameplay focus
- `releaseFocus`: cancel and release gameplay focus
- `setEnabled`: cancel on disable and ignore gameplay translation while a host
  overlay owns interaction, without surrendering host focus
- `cancelForPause`: cancel while retaining focus for host shortcuts
- `cancelAll`: clear key/button/pointer state and neutralize the dispatcher
- `dispose`: cancel before disposing the owned focus node

Focus loss calls `cancelAll` before notifying `onFocusLost`. A host may pause
the simulation in that callback without racing a held movement or ability
edge. Hosts must also call the same cancellation path before pause, restart,
stop, app deactivation, control-scheme changes, and runtime disposal.

Semantic `cancelAll` always sets movement to zero, clears aim, attempts to
release primary/secondary/projectile/mobility, and pumps the neutral continuous
state. It does this even if adapter bookkeeping is already empty. Aim-preview
models remain presentation state: `RunnerGameWidget` ends them beside semantic
cancellation, and a desktop host supplies `onCancelPresentation`.

## Mouse aim conversion

`RunnerDesktopAimGeometry` works in logical pixels local to the adapter. Its
`viewportRect` is built from `ViewportMetrics`, so letterbox and host chrome are
outside the aim domain and Windows DPI scaling has already been incorporated.

`RunnerDesktopAimGeometry.fromWorld` performs the same axis-aligned camera
mapping used by rendering:

1. convert the player world point through `WorldViewTransform`
2. round the player point in virtual view space to match camera-relative pixel
   snapping
3. scale it into the fitted logical-pixel viewport and add its alignment offset
4. subtract that rendered player point from the local cursor position
5. normalize the delta and pass it to the dispatcher/router quantization path

Positions outside the fitted viewport and zero-length cursor/player deltas
clear aim. Moving into letterbox space clears pointer-derived aim without
altering keyboard movement or held keys.

The controller retains the last valid pointer direction while the cursor stays
inside the viewport and reapplies it at each ability transition. This is
required because an aimed release commit deliberately clears the router's aim;
a second keyboard action must still use the unchanged cursor direction without
requiring a synthetic mouse move.

Aim presentation is optional and supplied through `onAimChanged`,
`onAimCleared`, and `onCancelPresentation`; the device-neutral dispatcher does
not depend on `AimPreviewModel` or Flutter.

## Fixed Windows gameplay bindings

| Action | Bindings |
| --- | --- |
| Move left | `A`, Left Arrow |
| Move right | `D`, Right Arrow |
| Jump | Space, `W`, Up Arrow |
| Mobility | Left Shift, Right Shift |
| Primary | Left Mouse Button, `J` |
| Projectile | Right Mouse Button, `K` |
| Secondary | `Q` |
| Spell | `E`, `L` |

`F5`, `F6`, Escape, `P`, and Enter are intentionally absent. A playtest host
owns those controls outside `RunnerDesktopInputAdapter`. Unknown keys return
`KeyEventResult.ignored` so an enclosing focused host can handle them.

## Host integration requirements

A desktop host must:

1. construct one router and semantic dispatcher for its controller
2. provide current `RunnerDesktopAimGeometry` from its fitted viewport, camera,
   and rendered player point
3. construct and dispose one `RunnerDesktopInputController`
4. mount `RunnerDesktopInputAdapter` only around the gameplay surface
5. route focus loss and app lifecycle into cancel-before-pause behavior
6. keep host shortcuts outside the gameplay binding table

The adapter has no editor, backend, replay, reward, or Firebase dependency.
Adding it to a future production Windows game is host composition; it must not
change Core commands or duplicate semantic mode mapping.

## Verification

The executable contract is covered by:

- `test/game/input/runner_semantic_action_dispatcher_test.dart`
- `test/runner_input_router_release_test.dart`
- `test/ui/input/desktop/runner_desktop_bindings_test.dart`
- `test/ui/input/desktop/runner_desktop_aim_geometry_test.dart`
- `test/ui/input/desktop/runner_desktop_input_adapter_test.dart`
- `test/playtest/runner_chunk_playtest_host_test.dart`
- `tools/editor/test/chunk_playtest_editor_integration_test.dart`
- `tools/editor/test/level_playtest_editor_integration_test.dart`
- `tools/editor/test/authored_playtest_session_test.dart`
- `tools/editor/integration_test/chunk_playtest_windows_acceptance_test.dart`
- existing touch control tests under `test/ui/controls/**`

Coverage includes all admitted slot modes, unsupported modes, both touch
release orders, opposing directions, alternate sources, OS repeat, mouse
chords/cancel, letterbox/zero aim, repeated unchanged cursor aim, focus loss,
pause, disposal, touch-pointer exclusion, resize and non-unit device-pixel
ratios, every app deactivation state, repeated Play/Stop cycles, and a native
Windows-engine lifecycle pass. Product desktop composition remains a separate
follow-on.
