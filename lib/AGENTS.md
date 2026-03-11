# AGENTS.md

Instructions for AI coding agents working in `lib/`.

## What Lives In `lib/`

`lib/` now contains a complete app-facing implementation, not just a demo shell:

- `lib/main.dart`: standalone app entrypoint for this game app
- `lib/runner.dart`: public embedding barrel for host apps
- `lib/core/`: deterministic gameplay authority
- `lib/game/`: Flame renderer and fixed-tick bridge
- `lib/ui/`: Flutter app shell, routes, pages, HUD, controls, state, and backend clients

The package must work in two modes:

- standalone app mode through `lib/main.dart`
- embedded mode through `lib/runner.dart`, `RunnerGameWidget`, and `createRunnerGameRoute`

Do not treat `lib/main.dart` as a disposable dev-only harness. The current app shell is real product code.

## Hard Layer Boundaries

The dependency direction is still strict:

- `ui -> game -> core`
- `ui -> core` is allowed only for stable value types and public gameplay definitions already used by the embedding API or app setup flow
- `core` must not import Flutter or Flame
- `game` must not become authoritative for gameplay, collision, or progression
- `ui` must not mutate core internals directly

Current key boundary files:

- `lib/core/game_core.dart`: authoritative simulation coordinator
- `lib/game/game_controller.dart`: fixed-tick bridge from Flutter/Flame to Core
- `lib/game/runner_flame_game.dart`: snapshot-driven Flame renderer
- `lib/ui/app/ui_app.dart`: top-level Flutter shell
- `lib/ui/app/ui_router.dart`: route graph
- `lib/runner.dart`: stable public embedding surface

## What Belongs Where

Put work in the layer that owns the behavior:

- gameplay rules, combat, AI, level data, progression math, authoritative events: `lib/core/`
- render components, interpolation, view registries, camera shake, aim rays, debug overlays: `lib/game/`
- menus, hub/setup flow, town/meta screens, HUD widgets, theme extensions, provider state, backend adapters: `lib/ui/`

Common mistakes to avoid:

- putting combat or collision logic in Flame components
- putting backend callable logic directly in widgets instead of `lib/ui/state/**`
- adding Flutter-specific types to Core contracts
- bypassing `GameController` to poke Core state

## Current App Shape

Important existing flows and modules:

- App shell and route orchestration: `lib/ui/app/`
- bootstrap, auth warmup, resume loader, profile onboarding: `lib/ui/bootstrap/`
- menu/meta pages: `lib/ui/pages/`
- shared components, text helpers, icons, theming: `lib/ui/components/`, `lib/ui/text/`, `lib/ui/theme/`
- HUD and in-run controls: `lib/ui/hud/`, `lib/ui/controls/`
- backend client interfaces and Firebase implementations: `lib/ui/state/`
- viewport math and route-scoped system UI/orientation helpers: `lib/ui/viewport/`, `lib/ui/scoped/`

The run route currently flows like this:

1. `AppState` builds run args from selection/meta state.
2. `UiRouter` creates the run route.
3. `RunnerGameWidget` constructs `GameCore`, `GameController`, `RunnerInputRouter`, and `RunnerFlameGame`.
4. `RunnerFlameGame` renders immutable snapshots while `GameOverlay` and `GameOverOverlay` handle in-run UI.
5. End-of-run rewards feed back into `AppState`, which talks to the ownership backend.

## Public API Discipline

`lib/runner.dart` is the public package boundary. Keep it stable and intentional.

When changing embedding-facing behavior:

- update `lib/runner.dart` exports only when necessary
- document changes in `RunnerGameWidget` and `createRunnerGameRoute`
- preserve reasonable defaults for host apps
- avoid leaking internal folder structure into public imports

## Cross-Layer Contracts

These are the contracts other layers depend on:

- commands and tick-stamped input entering Core
- immutable `GameStateSnapshot` output
- transient `GameEvent` output
- stable render metadata from Core contracts and catalogs
- `AppState` and `lib/ui/state/**` as the client-side ownership/profile facade

If you change one of these contracts, update all affected consumers in the same pass. Do not leave stale adapters behind.

## Prefer Existing Patterns

Before adding abstractions:

- inspect the relevant directory for an existing pattern
- reuse existing catalog, registry, presenter, theme-extension, or API-wrapper structure
- prefer extending the current route/state/component organization over introducing a second one

This repo already has patterns for:

- theme-driven widget APIs
- Provider-based app state
- snapshot-driven rendering
- render registries for enemies/projectiles/pickups
- Firebase client interfaces with concrete implementations in `lib/ui/state/`

## Testing And Verification

Match verification to the layer you touched:

- Core behavior: `test/core/**`
- Flame/render/controller behavior: `test/game/**`
- widgets, routes, and state orchestration: `test/ui/**`
- integration/benchmark coverage: `test/integration_test/**`

For multi-layer changes, do not stop at one slice's tests if the contract spans more than one layer.

## Documentation Responsibilities

When `lib/` contracts change, keep these docs aligned:

- this file for app-level boundaries
- `lib/core/AGENTS.md`, `lib/game/AGENTS.md`, or `lib/ui/AGENTS.md` for layer rules
- `README.md` for public capabilities and setup if user-visible behavior changed
- embedding docs and API docs when public usage changes

---

Use the layer-specific AGENTS file before editing within `lib/core/`, `lib/game/`, or `lib/ui/`.
