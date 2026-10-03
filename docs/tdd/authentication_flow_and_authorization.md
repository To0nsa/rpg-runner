# Authentication Flow And Authorization (App -> Firebase Auth -> Callable Backend)

This doc explains how identity is created in the app, how requests are authenticated, and where authorization decisions are enforced.

## 1) Current auth model at a glance

The app uses Firebase Authentication with this runtime policy:

- Primary boot identity: Play Games-backed Firebase user (Android only).
- Anonymous Firebase users are not created during bootstrap.
- Backend authority: Firebase callable functions (`onCall`) require both the
  Firebase `uid` and a linked Google Play Games identity.
- Firestore client writes/reads for authoritative game data are denied by rules.

Authoritative data access (profile, ownership, runs, boards, ghosts, account delete) goes through callables, not direct Firestore from the app.

## 2) Ownership by layer

- Flutter auth adapter: `FirebaseAuthApi`
  - `lib/ui/state/auth/firebase_auth_api.dart`
  - Handles session discovery, refresh, Play Games restore, and provider linking.
- App orchestration: `AppState`
  - `lib/ui/state/app/app_state.dart`
  - Calls `ensureAuthenticatedSession()` before remote operations.
- Backend callables:
  - `functions/src/index.ts`
  - `functions/src/*/callable_handlers.ts`
  - Enforce a linked Play Games identity plus uid match per request.
- Firestore rules:
  - `firestore.rules`
  - Deny client read/write for protected collections.

## 3) Startup and bootstrap identity flow

Boot route flow:

1. `main()` starts `UiApp` immediately with the production `AppServices` owner.
   `firebase_app_services.dart` holds Firebase client construction, while
   `ui_theme.dart` holds the common theme. No Firebase client is created yet.
2. The initial route generator creates only `BrandSplashScreen`, without an
   underlying `/` or hub route. Its cancellable 1.8-second studio timer replaces
   the splash with the game loader.
3. `LoaderPage` calls `AppBootstrapper`, which awaits `AppServices.initialize()`
   before `AppState.bootstrap()`. Initialization creates Firebase, activates
   App Check, then constructs state and API adapters. The loader's two-second
   minimum runs concurrently with this work; it is never shortened on cold
   start. Retries and resume do not impose another minimum.
4. `AppState.bootstrap()` calls `_ensureAuthSession()`.
5. `_ensureAuthSession()` delegates to `AuthApi.ensureAuthenticatedSession()`.

`AppServices` shares in-flight initialization and retains successful state.
Failed initialization is retryable; Firebase already initialized before an
App Check failure is reused on retry. `UiApp` disposes the service owner and
its state, while the lazy `ListenableProvider` only owns the subscription.
Disposal during initialization prevents late construction of clients.

Initialization errors are displayed by the existing game loader, even if
Firebase is unavailable. Release attestation requirements still fail closed.
Authentication failures offer **Retry Play Games sign-in**; service and player
data failures offer **Retry** with a stage-specific explanation. Raw exceptions
and stack traces stay in diagnostics, rather than player-facing text. Successful
cold bootstrap replaces the loader with required name setup or the hub. Back
cannot reveal an uninitialized hub or skip onboarding. Unknown routes and
invalid run arguments display explicit errors rather than routing to the hub.

`FirebaseAuthApi.ensureAuthenticatedSession()` behavior:

- Try current Firebase user (`readCurrent(forceRefresh: false)`).
- Require a non-anonymous session linked to Play Games.
- If no eligible session exists:
  - try Play Games restore (`tryRestorePlayGamesSession()`) on Android,
  - if restore fails, throw `PlayGamesAuthRequiredException`.
- If token is near expiry, force refresh and retry.
- If session is still invalid after refresh/restore, throw `PlayGamesAuthRequiredException`.

This means bootstrap is intentionally fail-closed until Play Games auth succeeds.

Concurrent `AppState.bootstrap()` calls share one attempt. Forced refreshes
finish the pending ownership flush before loading profile and canonical
ownership. A delayed bootstrap read cannot replace a newer ownership revision
published while that read was in flight; queued selection is projected again
after loading. Disposed app state and accepted account deletion fence late
bootstrap responses. Hub warmup only starts after bootstrap succeeds, handles
background errors, and permits another attempt after a warmup failure.

Lifecycle ownership flushes (inactive, paused, detached, and reconnect/resume)
are deferred until bootstrap succeeds. The app shell also suppresses these
flushes while the splash or loader route is visible, including a resume loader
for a previously bootstrapped session. Native Play Games activity transitions
therefore cannot retrigger sign-in behind a failed loader. Returning to the
splash keeps its existing transition to the loader instead of stacking a resume
loader. A failed loader remains available for explicit retry.

On menu resume, one loader gates the existing route while forced bootstrap
owns flush-before-refresh ordering. System Back cannot dismiss this loader;
successful completion pops it. The shell tracks page routes separately from
dialogs and handles replacement/removal below the top route. Run preparation
and gameplay retain their own lifecycle handling, including when a dialog is
open, and are not covered by an app resume loader. Ownership reconnect flushes
remain available on those routes.

The shell configures landscape and immersive display outside widget builds.
Immersive updates are coalesced per frame and checked for disposal; platform
channel failures are logged without preventing the loading/error UI.

## 4) App-level session shape

`AuthSession` (in `lib/ui/state/auth/auth_api.dart`) carries:

- `userId`: Firebase uid.
- `sessionId`: client-generated fingerprint derived from token/user metadata.
- `isAnonymous`: whether current Firebase user is anonymous.
- `expiresAtMs`: token expiry when available.
- `linkedProviders`: currently supports Play Games provider marker.

Important:

- `sessionId` is required by request contracts and passed to callables.
- Backend authorization authority is still `request.auth.uid`.
- `sessionId` is request correlation only: it is neither identity authority
  nor part of ownership-command idempotency identity. Firebase can refresh an
  ID token while retrying a durable command, so retries retain their command
  ID and semantic payload while accepting a new session fingerprint.

### Durable local work is account-scoped

The ownership outbox and replay-submission spool persist the UID that created
each row. Reads, coalescing, retries, status projection, and removal are
scoped to that UID. A second player signing in on the same device therefore
cannot deliver or discard another player's locally queued command or replay.
Historical unscoped rows are intentionally ignored because their owner cannot
be established safely.

## 5) Play Games linking and restore

Play Games integration is Android-only.

- Dart side requests a server auth code through method channel `rpg_runner/play_games_auth`.
- Android side (`MainActivity.kt`) signs in with Play Games SDK and returns server auth code.
- Dart exchanges code with `PlayGamesAuthProvider.credential(...)` and links
  or signs in via Firebase Auth. When an existing anonymous Firebase user is
  upgraded, it uses `linkWithCredential` and preserves that UID.

UI entry point:

- Runtime bootstrap requires Play Games identity, so anonymous-upgrade UI is
  not part of the normal startup path. It remains a safe recovery path for a
  pre-existing anonymous session.

### Local Android sign-in troubleshooting

If the native bridge reports `play-games-not-authenticated`, the rejection
occurs before a server auth code is exchanged with Firebase. Verify the Play
Games Android credential uses the built application's package name and signing
certificate SHA-1. A new workstation or regenerated debug keystore can change
the certificate even when the package name is unchanged. Register the current
debug certificate in Firebase and link its Android OAuth credential in Play
Console; retain credentials needed by other builds. Refresh
`android/app/google-services.json` after updating Firebase configuration.

For unpublished Play Games configuration, enable the device's Google account
as a Play Games tester. Check the game server credential and Firebase Play
Games provider configuration if authentication succeeds but the server auth
code or Firebase exchange fails. See Google's
[Play Games troubleshooting guide](https://developer.android.com/games/pgs/android/troubleshooting)
and [Firebase Play Games setup](https://firebase.google.com/docs/auth/android/play-games).

## 6) Callable request auth contract (server-side)

Current callable pattern across domains:

1. The Functions v2 callable runtime applies the configured App Check policy.
2. Require `request.auth.uid` and a non-empty
   `request.auth.token.firebase.identities['playgames.google.com']` value.
3. Bound, parse, and validate the request payload.
4. Verify request `userId` equals authenticated `uid`.
5. Enforce deletion, quota, domain allowlist, and ownership checks.
6. Execute domain logic.
7. Return a typed payload.

This pattern is implemented in:

- ownership/profile/account callables in `functions/src/index.ts`
- runs/leaderboards/ghost callables in `functions/src/*/callable_handlers.ts`

So even if client sends a forged `userId`, the backend rejects on uid mismatch.

App Check defaults to the explicit `monitor` rollout mode; only `monitor` and
`enforce` are accepted, so a typo fails Functions initialization instead of
silently relaxing the policy. Android and Apple release builds use platform
attestation; release web requires a configured reCAPTCHA Enterprise site key;
Windows, Linux, and Fuchsia have no production attestation provider and their
release bootstrap fails closed. `APP_CHECK_ROLLOUT_MODE=enforce` makes the
callable runtime reject missing/invalid tokens before the handler, but Play
Games identity and UID authorization remain mandatory afterward. This switch
applies globally to each callable: it cannot be enabled while an in-scope
production platform lacks attestation unless that platform is excluded or uses
separately reviewed endpoints. Platform configuration, debug-token rules,
per-UID quotas, and rollback are defined in
[`callable_abuse_controls.md`](callable_abuse_controls.md).

For ownership commands, matching the UID is necessary but not sufficient. The
public callable accepts only selection/loadout/equip and store
purchase/refresh intents. Gold award, entitlement grant, and reset command
types are rejected as server-only before Firestore mutation. Flutter does not
define DTOs or API methods for those server-only operations.

Selection and loadout intents are authorized against the backend catalog and
the caller's canonical inventory/learned abilities. Run-session issuance
repeats the loadout authorization before creating a reward-bearing ticket.

Profile time authority follows the same boundary. `playerProfileUpdate`
accepts a requested display name but rejects
`displayNameLastChangedAtMs`. The callable captures server time after
authentication and UID matching, and the profile transaction uses it for the
24-hour rename decision and persisted timestamp. Flutter's countdown is
advisory; a backend `failed-precondition` rejection is final.

The first non-empty display name is the explicit exception and retains
timestamp `0`, allowing one immediate correction. That correction records
server time and starts the ordinary cooldown. A legacy future timestamp from
the removed client-authoritative contract is repairable on the next rename.

## 7) Authorization boundaries and data access model

- Firestore security rules deny direct client access for server-owned
  collections, including ownership idempotency, profiles/name claims,
  deletion tombstones, and abuse quota state.
- App uses `cloud_functions` callables as the only remote mutation/read path for authoritative state.
- Backend uses Admin SDK with explicit auth checks in callable handlers.

## 8) Account deletion flow

Client flow:

1. `ProfilePage` confirms deletion.
2. `AppState.deleteAccountAndData()` performs interactive Play Games
   reauthentication and forces an ID-token refresh.
3. Calls `accountDelete` callable with `userId` + `sessionId`.
4. On success, app clears local state and signs out via `AuthApi.clearSession()`.

Server flow (`functions/src/account/delete.ts`):

- The callable requires a linked Play Games identity and an `auth_time` no
  more than five minutes old. Refreshing an ID token does not reset this
  timestamp, so stale sessions receive `failed-precondition` with
  `reason: recent-auth-required` before deletion work starts.
- Transactionally creates `account_deletion_requests/{uid}` before any
  destructive work.
- Disables the Auth user and revokes refresh tokens first.
- Uses the tombstone in callable guards and profile/ownership/run mutation
  transactions, so a still-valid ID token cannot recreate user data.
- A scheduled worker erases the explicit Firestore/Storage inventory in
  bounded, leased, resumable pages.
- The inventory includes quota counters and ownership idempotency records.
- Waits out the signed-upload URL lifetime and requires a fresh zero-change
  final pass before deleting Firebase Auth.
- Tolerates already-missing Auth users, documents, and objects.

Flutter requires one of `requested`, `in_progress`, `retryable`, and `deleted`
with the matching UID request ID. Empty/unknown/legacy boolean responses are
rejected. Acceptance immediately resets memory before device cleanup and
sign-out; individual cleanup failures are reported separately and can be
retried without authentication or another deletion request. Detailed
stages, retention, and inventory rules are in
[`account_deletion_workflow.md`](account_deletion_workflow.md).

## 9) Failure behavior worth knowing

- Network token-read failures in auth adapter can fall back to cached current user snapshot for resiliency.
- Most app remote operations re-check auth via `_ensureAuthSession()` each
  call, so token/session rollover is naturally handled.
- Account deletion maps backend/platform errors to typed statuses (`requiresRecentLogin`, `unauthorized`, `unsupported`, `failed`).

## 10) Change checklist for auth-related work

When changing auth behavior or contract, update both sides in one change:

- client auth/session adapter (`lib/ui/state/auth/firebase_auth_api.dart`)
- app orchestration (`lib/ui/state/app_state.dart`)
- callable validators/handlers (`functions/src/**`)
- Firestore rules if direct-access policy changes (`firestore.rules`)
- profile page/account-link UX if user-visible flow changes (`lib/ui/pages/profile/profile_page.dart`)

Do not move authorization authority from backend Firebase claims and
`request.auth.uid` to client-provided fields.
