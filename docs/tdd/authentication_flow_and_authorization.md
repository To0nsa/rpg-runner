# Authentication Flow And Authorization (App -> Firebase Auth -> Callable Backend)

This doc explains how identity is created in the app, how requests are authenticated, and where authorization decisions are enforced.

## 1) Current auth model at a glance

The app uses Firebase Authentication with this runtime policy:

- Primary boot identity: Play Games-backed Firebase user (Android only).
- Anonymous Firebase users are not created during bootstrap.
- Backend authority: Firebase callable functions (`onCall`) using `request.auth.uid`.
- Firestore client writes/reads for authoritative game data are denied by rules.

Authoritative data access (profile, ownership, runs, boards, ghosts, account delete) goes through callables, not direct Firestore from the app.

## 2) Ownership by layer

- Flutter auth adapter: `FirebaseAuthApi`
  - `lib/ui/state/firebase_auth_api.dart`
  - Handles session discovery, refresh, Play Games restore, and provider linking.
- App orchestration: `AppState`
  - `lib/ui/state/app_state.dart`
  - Calls `ensureAuthenticatedSession()` before remote operations.
- Backend callables:
  - `functions/src/index.ts`
  - `functions/src/*/callable_handlers.ts`
  - Enforce auth + uid match per request.
- Firestore rules:
  - `firestore.rules`
  - Deny client read/write for protected collections.

## 3) Startup and bootstrap identity flow

Boot route flow:

1. `main()` initializes Firebase, activates App Check where the platform is
   configured, and starts `UiApp`.
2. `BrandSplashScreen` routes to loader.
3. `LoaderPage` calls `AppState.bootstrap()`.
4. `AppState.bootstrap()` calls `_ensureAuthSession()`.
5. `_ensureAuthSession()` delegates to `AuthApi.ensureAuthenticatedSession()`.

`FirebaseAuthApi.ensureAuthenticatedSession()` behavior:

- Try current Firebase user (`readCurrent(forceRefresh: false)`).
- Require a non-anonymous session linked to Play Games.
- If no eligible session exists:
  - try Play Games restore (`tryRestorePlayGamesSession()`) on Android,
  - if restore fails, throw `PlayGamesAuthRequiredException`.
- If token is near expiry, force refresh and retry.
- If session is still invalid after refresh/restore, throw `PlayGamesAuthRequiredException`.

This means bootstrap is intentionally fail-closed until Play Games auth succeeds.

## 4) App-level session shape

`AuthSession` (in `lib/ui/state/auth_api.dart`) carries:

- `userId`: Firebase uid.
- `sessionId`: client-generated fingerprint derived from token/user metadata.
- `isAnonymous`: whether current Firebase user is anonymous.
- `expiresAtMs`: token expiry when available.
- `linkedProviders`: currently supports Play Games provider marker.

Important:

- `sessionId` is required by request contracts and passed to callables.
- Backend authorization authority is still `request.auth.uid`.
- `sessionId` is currently a request integrity/session-tracking field, not identity authority.

## 5) Play Games linking and restore

Play Games integration is Android-only.

- Dart side requests a server auth code through method channel `rpg_runner/play_games_auth`.
- Android side (`MainActivity.kt`) signs in with Play Games SDK and returns server auth code.
- Dart exchanges code with `PlayGamesAuthProvider.credential(...)` and links/signs in via Firebase Auth.

UI entry point:

- Runtime bootstrap requires Play Games identity, so anonymous-upgrade UI is not part of the normal startup path.

## 6) Callable request auth contract (server-side)

Current callable pattern across domains:

1. The Functions v2 callable runtime applies the configured App Check policy.
2. Require `request.auth?.uid`.
3. Bound, parse, and validate the request payload.
4. Verify request `userId` equals authenticated `uid`.
5. Enforce deletion, quota, domain allowlist, and ownership checks.
6. Execute domain logic.
7. Return a typed payload.

This pattern is implemented in:

- ownership/profile/account callables in `functions/src/index.ts`
- runs/leaderboards/ghost callables in `functions/src/*/callable_handlers.ts`

So even if client sends a forged `userId`, the backend rejects on uid mismatch.

App Check defaults to monitoring. Android and Apple release builds use
platform attestation; release web requires a configured reCAPTCHA v3 site key;
the current Windows SDK supports only a registered debug token and therefore
has no production enforcement path. `APP_CHECK_ROLLOUT_MODE=enforce` makes the
callable runtime reject missing/invalid tokens before the handler, but Firebase
Auth and UID authorization remain mandatory afterward. This switch applies
globally to each callable: it cannot be enabled while an in-scope production
platform lacks attestation unless that platform is excluded or uses separately
reviewed endpoints. Platform configuration, debug-token rules, per-UID quotas,
and rollback are defined in
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
2. `AppState.deleteAccountAndData()` ensures auth session.
3. Calls `accountDelete` callable with `userId` + `sessionId`.
4. On success, app clears local state and signs out via `AuthApi.clearSession()`.

Server flow (`functions/src/account/delete.ts`):

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

Flutter treats `requested`, `in_progress`, `retryable`, and `deleted` as
accepted server-owned outcomes, clears local state, and signs out. Detailed
stages, retention, and inventory rules are in
[`account_deletion_workflow.md`](account_deletion_workflow.md).

## 9) Failure behavior worth knowing

- Network token-read failures in auth adapter can fall back to cached current user snapshot for resiliency.
- Most app remote operations re-check auth via `_ensureAuthSession()` each call, so token/session rollover is naturally handled.
- Account deletion maps backend/platform errors to typed statuses (`requiresRecentLogin`, `unauthorized`, `unsupported`, `failed`).

## 10) Change checklist for auth-related work

When changing auth behavior or contract, update both sides in one change:

- client auth/session adapter (`lib/ui/state/firebase_auth_api.dart`)
- app orchestration (`lib/ui/state/app_state.dart`)
- callable validators/handlers (`functions/src/**`)
- Firestore rules if direct-access policy changes (`firestore.rules`)
- profile page/account-link UX if user-visible flow changes (`lib/ui/pages/profile/profile_page.dart`)

Do not move authorization authority from backend `request.auth.uid` to client-provided fields.
