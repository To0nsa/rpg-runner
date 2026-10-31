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
- run-session creation, replay submission, board/leaderboard loading, and ghost
  manifest/cache orchestration
- viewport integration, scoped orientation/system UI helpers, and haptics

Widgets should stay focused on presentation and orchestration, not backend or gameplay internals.

## Current Important Areas

- `lib/ui/app/`: `UiApp`, routes, navigation shell, `AppServices` lifetime owner,
  and production dependency construction in `firebase_app_services.dart`
- `lib/ui/bootstrap/`: startup loader, brand splash, profile-name setup
- `lib/ui/pages/`: hub, level/setup, town map/store, library, options, messages,
  profile, leaderboards
- `lib/ui/codex/`: discovery thresholds and world-reference prose; combat values
  come from Core catalogs, account progress from backend-settled ownership
- `lib/ui/hud/` and `lib/ui/controls/`: in-run overlays and input widgets
- `lib/ui/components/`, `lib/ui/text/`, `lib/ui/theme/`: app design system pieces
- `lib/ui/state/`: `AppState`, auth/profile/ownership/run/board APIs,
  Firebase-backed implementations, and app-state controllers
- `lib/ui/state/run/`: run-session API, replay-submission spool/coordinator,
  and submission status values
- `lib/ui/state/settings/`: device-wide control preferences, owned by
  `AppServices` independently of account/developer profile replacement
- `lib/ui/state/boards/`: active-board, leaderboard, ghost manifest, and ghost
  replay cache clients
- `lib/ui/assets/`: menu preview cache and warmup lifecycle
- `lib/ui/run/`: shared remote preflight and local run-session ownership/readiness
- `lib/ui/viewport/` and `lib/ui/scoped/`: viewport fitting and scoped system UI/orientation behavior

## House Style

Accepted account deletion resets memory before device cleanup or sign-out.
Keep server acceptance separate from local cleanup errors, fence late state
writes, and retry cleanup without reauthentication. Unknown deletion responses
must never count as acceptance.

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

Startup must create only the studio splash route. Preserve its 1.8-second
branding duration and the game loader's two-second cold-start minimum.
Initialize services through `AppBootstrapper`/`AppServices` behind the loader
so initialization failures are visible and retryable. `AppServices` owns
`AppState` disposal; the provider only subscribes after initialization. Keep
production client construction and theme configuration out of `UiApp`.
Web always uses `AppServices.practiceOnly`, including release builds, and cannot
switch to an online profile. `create_app_services.dart` selects web/native
services at compile time. Native debug Developer Practice checks the explicit
`DEVELOPER_PRACTICE` launch flag and restores its preference before online
initialization. The native flag never writes the toggle and is ignored outside
debug. Use `developerPracticeAllowed` for local profile/run guards. Keep native
filesystem/HTTP adapters behind conditional imports; shared replay APIs expose
opaque artifact IDs, not File handles. See `docs/tdd/platform_services.md`.
`AppServices` owns profile replacement as well as
disposal; the proxy provider owns only subscriptions. Keep developer selections
in their separate preference namespace, preserve the real account's queues,
and never create tickets, record/submit replays or grant rewards for local runs.
Use the existing menus and gameplay route; see `docs/tdd/developer_practice.md`.
Forced bootstrap owns ownership flush-before-refresh ordering. Page tracking
must ignore dialogs when deciding whether to show a resume loader; system Back
must not bypass a resume refresh. Hub warmup starts only after bootstrap.

## App State And Backend Access

`AppState` is the main orchestration boundary for authenticated app state. Current responsibilities include:

- auth session bootstrap
- loading remote profile data
- loading and mutating remote ownership canonical state
- preparing run-start descriptors from selected level/character/loadout after
  auth + ownership preflight
- creating remote run sessions and consuming server-issued run tickets
- submitting completed run replays for asynchronous validation
- foreground, app-owned submission retries and reward completion across routes;
  the durable final receipt remains until canonical ownership is refreshed
- loading active boards, leaderboards, ranks, and ghost manifests
- awarding run gold back into remote progression through validated run flows
- loading system messages and whole-inbox attention, and applying manually
  claimed gold through the revisioned ownership flow; widgets use the shared
  `AttentionMarker` with domain-owned visibility rules
- handling account deletion reset flow

Rules:

- widgets should call `AppState` or a narrow UI-facing abstraction, not Firebase SDKs directly
- keep backend contract handling in `lib/ui/state/**`
- wallet/XP widgets use `AppState.displayedGold` and `displayedPlayerProgress`;
  canonical `progression` remains the only source for spending, unlocks and
  persisted ownership. Local reward previews must reconcile against settled
  grant IDs and never satisfy verified-account paint diagnostics.
- when a callable/backend contract changes, update both the client adapter and the consuming UI/state flow
- when a run/replay/leaderboard payload changes, also check
  `packages/run_protocol/**`, `functions/src/**`, and
  `services/replay_validator/**`

## Run Route Responsibilities

The run route is a UI-owned assembly of lower layers:

- `RunnerRunSession` owns controller, input router, Flame game, aim previews, recorder, and ghost lifecycle
- `RunnerGameWidget` owns the session, overlays, input/lifecycle policy, and submission UI
- Online Start requires both world and recorder readiness; developer Practice
  requires world readiness only. Required load failures offer retry and exit.
- `RunStartPreparation` coordinates hub, leaderboard, and restart preflight through AppState
- `RunnerGameRoute` scopes orientation and system UI behavior for embedded or routed runs
- Runtime terrain waits preserve the same session and recorder. Keep controls
  mounted for hold releases; failure cancels input and offers same-run retry.
  Do not route runtime recovery through startup session replacement.
- HUD and controls read snapshots and send input through the existing router/controller path
- `RunnerControlScheme` selects one touch/desktop surface in the product host.
  Desktop pointers wrap only gameplay, with HUD as a sibling; focus/lifecycle
  cancellation precedes pause and desktop return requires explicit resume.
  Dispose the desktop controller before its session and keep browser context
  menu suppression scoped. See `docs/tdd/gameplay_input_architecture.md`.
- Movement presentation is selected by `MovementControlMode`; arrows, floating
  joystick and fixed joystick must emit the same digital -1/0/1 axis. Keep
  preferences outside gameplay/replay descriptors, and preserve pointer
  cancellation epochs.
- boss entrance haptics use the run-owned binding under `haptics/`; dispose it
  before replacing or disposing its controller, and retain pulse deduplication
  across pause/resume

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
- runtime images loaded only by run-owned Flame registries, released with that run
- preview asset lifecycle in `lib/ui/assets/`

If a page or widget needs art previews, integrate with the existing asset lifecycle instead of adding one-off preload code. Do not add a whole-run Flutter precache
pass; it does not populate the run-owned Flame image cache.

## What Belongs In This Layer

Good fits for `lib/ui/`:

- route changes
- page flow and onboarding logic
- component/theme cleanup
- HUD layout and controls
- backend-client integration through `AppState` and state APIs
- local and remote leaderboard presentation, ghost loading, and profile/account
  flows

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

## Shared game presentation

Item/skill icon renderers and names live in
[game_presentation](../../packages/game_presentation/AGENTS.md), consumed by the
game and Admin. Keep asset ownership canonical and backend grants out of these
widgets. Inbox schema changes also follow [Admin/inbox ownership](../../docs/tdd/admin_tools.md).
