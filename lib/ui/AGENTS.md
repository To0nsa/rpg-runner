# AGENTS.md - UI Layer

Instructions for AI coding agents working in `lib/ui/`.

## UI Layer Responsibility

`lib/ui/` is now a full Flutter app layer, not just overlays. It owns:

- the app shell and route graph
- bootstrap, auth warmup, resume handling, and profile onboarding
- hub/setup/meta/town/profile/leaderboard pages
- HUD, controls, and game-over presentation
- theme extensions and shared UI components
- app state, Firebase client adapters, and local orchestration around backend data
- viewport integration, scoped orientation/system UI helpers, and haptics

Widgets should stay focused on presentation and orchestration, not backend or gameplay internals.

## Current Important Areas

- `lib/ui/app/`: `UiApp`, routes, navigation shell
- `lib/ui/bootstrap/`: startup loader, brand splash, profile-name setup
- `lib/ui/pages/`: hub, level/setup, town, options, library, support, messages, credits, lab, profile, leaderboards
- `lib/ui/hud/` and `lib/ui/controls/`: in-run overlays and input widgets
- `lib/ui/components/`, `lib/ui/text/`, `lib/ui/icons/`, `lib/ui/theme/`: shared design system pieces
- `lib/ui/state/`: `AppState`, auth/profile/ownership/account-deletion APIs, Firebase-backed implementations
- `lib/ui/assets/`: preview cache and warmup lifecycle
- `lib/ui/viewport/` and `lib/ui/scoped/`: viewport fitting and scoped system UI/orientation behavior

## House Style

Default to the existing UI patterns:

- use `ThemeExtension`-driven component themes
- expose semantic widget inputs such as `variant`, `size`, ids, callbacks, and selected state
- avoid style-knob APIs unless the user explicitly asks for them
- keep widgets small by resolving theme specs up front instead of scattering visual calculations in `build`
- keep page-local widgets near the page that owns them, but move any widget reused across flows into `lib/ui/components/`

When cleaning up UI code, prefer a full migration to the active component/theme pattern over leaving half-old, half-new APIs in place.

## Modern Flutter Rules

- use `WidgetState` and `WidgetStateProperty`, not deprecated `MaterialState*`
- use `Color.withValues(alpha: ...)`, not `withOpacity`
- avoid side effects in `build`
- keep `SystemChrome` usage in app-shell or scoped helper code, not leaf widgets

This repo already centralizes global immersive-mode behavior in `UiApp` and route-scoped behavior in `scoped/`. Reuse that.

## App State And Backend Access

`AppState` is the main orchestration boundary for authenticated app state. Current responsibilities include:

- auth session bootstrap
- loading remote profile data
- loading and mutating remote ownership canonical state
- preparing run-start descriptors from selected level/character/loadout after
  auth + ownership preflight
- awarding run gold back into remote progression
- handling account deletion reset flow

Rules:

- widgets should call `AppState` or a narrow UI-facing abstraction, not Firebase SDKs directly
- keep backend contract handling in `lib/ui/state/**`
- when a callable/backend contract changes, update both the client adapter and the consuming UI/state flow

## Run Route Responsibilities

The run route is a UI-owned assembly of lower layers:

- `RunnerGameWidget` creates and owns the controller, Flame game, aim preview state, and overlay wiring
- `RunnerGameRoute` scopes orientation and system UI behavior for embedded or routed runs
- HUD and controls read snapshots and send input through the existing router/controller path

Do not push menu or backend concerns down into `lib/game/`. Do not bypass the run widget and assemble ad-hoc game routes in random pages.

## UI State Versus Gameplay State

Keep the separation clean:

- gameplay truth comes from Core snapshots and events
- app/meta state lives in `AppState` and its value objects
- ephemeral widget state stays local to the widget subtree when possible

Avoid duplicating gameplay state in UI-only models just to make rendering easier.

## Asset, Preview, And Warmup Rules

The UI layer already manages preview and warmup behavior:

- hub selection warmup in `UiApp`
- run cache purging after leaving a run
- preview asset lifecycle in `lib/ui/assets/`

If a page or widget needs art previews, integrate with the existing asset lifecycle instead of adding one-off preload code.

## What Belongs In This Layer

Good fits for `lib/ui/`:

- route changes
- page flow and onboarding logic
- component/theme cleanup
- HUD layout and controls
- backend-client integration through `AppState` and state APIs
- local leaderboard presentation and profile/account flows

Bad fits for `lib/ui/`:

- authoritative gameplay rules
- Flame-only rendering concerns
- direct Firestore or Cloud Functions usage from widget trees
- system-wide side effects fired from `build`

## Testing Expectations

UI changes should be verified with the right slice:

- widget tests for components, pages, overlays, and route behavior
- state tests for `AppState` and UI-facing APIs where relevant
- integration tests when the change spans app shell, run route, and backend/state interactions

## Documentation Responsibilities

If you change UI architecture or public usage, update:

- this file for UI-layer rules
- `lib/AGENTS.md` for app-wide boundaries
- `README.md` or public API docs when embedding or setup behavior changes

---

For app-level architecture, see `lib/AGENTS.md`. For the backend contract side of profile/ownership/account flows, see `functions/AGENTS.md`.
