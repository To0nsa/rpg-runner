# Gameplay Input Architecture

Status: Implemented shared input boundary; desktop adapter is available but is
not yet mounted by a product or editor host.

Last updated: August 19, 2026

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

`RunnerGameWidget` now routes its existing touch controls through the semantic
dispatcher, but it deliberately does not mount `RunnerDesktopInputAdapter`.
The editor playtest host will become the first desktop consumer in Phase 4.

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
- existing touch control tests under `test/ui/controls/**`

Coverage includes all admitted slot modes, unsupported modes, both touch
release orders, opposing directions, alternate sources, OS repeat, mouse
chords/cancel, letterbox/zero aim, repeated unchanged cursor aim, focus loss,
pause, disposal, and touch-pointer exclusion from the desktop widget.
