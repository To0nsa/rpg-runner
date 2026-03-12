# AGENTS.md - Game Layer

Instructions for AI coding agents working in `lib/game/`.

## Game Layer Responsibility

`lib/game/` is the Flame-facing runtime that turns Core outputs into visuals and bridges user input into tick-stamped commands.

This layer owns:

- the fixed-tick bridge in `game_controller.dart`
- Flame game composition in `runner_flame_game.dart`
- render components and registries under `components/`
- render-only camera shake, parallax, aim previews, debug overlays, and world/view transforms
- input aggregation and scheduling under `input/`

This layer does not own gameplay truth.

## Hard Rules

- do not make Flame authoritative for gameplay, collision, or progression
- do not mutate Core internals directly from components
- do not simulate future gameplay in the renderer
- do not treat snapshots as mutable state

If a change affects the actual rules of the game, it probably belongs in `packages/runner_core/lib/`.

## Current Important Files

- `lib/game/game_controller.dart`: owns `GameCore`, fixed-tick stepping, snapshot history, and event buffering
- `lib/game/runner_flame_game.dart`: main Flame scene and render synchronization
- `lib/game/input/runner_input_router.dart`: converts held/edge inputs into upcoming tick commands
- `lib/game/tick_input_frame.dart`: buffered input frame representation
- `lib/game/components/`: player, enemy, projectile, pickup, ground, aim, and sprite animation views
- `lib/game/themes/parallax_theme_registry.dart`: theme-to-parallax mapping
- `lib/game/spatial/world_view_transform.dart`: camera/view math utilities

Read the relevant coordinator before editing a subcomponent in isolation.

## Snapshot Consumption

The renderer currently depends on `GameController` exposing:

- `prevSnapshot`
- `snapshot`
- `alpha`
- transient `GameEvent` listeners

Rules:

- interpolate between known snapshots
- keep interpolation/render math read-only
- derive render-only effects from snapshots or events, not from hidden state machines
- if you need new render data, add it through a Core contract intentionally

## Input Bridge Rules

`RunnerInputRouter` already encodes important behavior:

- continuous input scheduling ahead of the current tick
- same-tick aim + action commits
- held ability slot transitions
- buffering to avoid starvation during frame hitches

Do not bypass that machinery with ad-hoc command scheduling from random widgets or Flame callbacks. Extend the router or controller when input behavior changes.

## Asset And Registry Discipline

The current render stack uses registries and explicit loading:

- player animations
- enemy render registry
- projectile render registry
- pickup render registry
- parallax theme registry

Preserve these rules:

- add new runtime render content through the existing registry/theme pattern
- keep asset lookup centralized instead of spreading path strings through components
- coordinate with `lib/ui/assets/` if a change affects preview or warmup behavior
- avoid hidden persistent caches inside leaf components

## Camera, Viewport, And Pixel Math

This repo already has non-trivial camera and pixel snapping logic. Respect it:

- Core owns the authoritative camera snapshot
- Game may add render-only shake on top of that camera
- viewport fitting belongs with the existing viewport math and route/widget integration
- pixel snapping and world-to-view transforms should stay consistent across components

If you change camera math, review both `lib/game/**` and `lib/ui/viewport/**`.

## Events And Render-Only Feedback

`GameEvent`s are used for short-lived visual or haptic cues such as:

- projectile hit effects
- entity visual cue flashes/pulses
- player impact feedback
- run-ended handling

Keep event handling side-effectful only on the render/UI side. Do not start putting game rule resolution into event consumers.

## What To Put In This Layer

Good fits for `lib/game/`:

- a new visual component for an existing Core entity
- render interpolation fixes
- camera shake or parallax behavior
- aim preview rendering
- debug overlays
- input routing changes that still end as commands

Bad fits for `lib/game/`:

- damage calculations
- collision truth
- cooldown or status authority
- persistence or backend writes

## Testing Expectations

When `lib/game/` changes, verify the relevant behavior:

- controller stepping and event buffering
- input scheduling edge cases
- render registry wiring
- widget or integration tests for route-level run behavior when needed

Do not assume a visual-only change is safe if it changes timing, camera transforms, or input scheduling.

---

For app-level boundaries, see `lib/AGENTS.md`. For the authoritative simulation side, see `packages/runner_core/lib/AGENTS.md`.
