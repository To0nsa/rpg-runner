# Authentication Flow And Authorization (App -> Firebase Auth -> Callable Backend)

This doc explains how identity is created in the app, how requests are authenticated, and where authorization decisions are enforced.

## 1) Current auth model at a glance

The app uses Firebase Authentication with this runtime policy:

- Primary boot identity: anonymous Firebase user.
- Optional account upgrade: link anonymous user to Play Games (Android).
- Backend authority: Firebase callable functions (`onCall`) using `request.auth.uid`.
- Firestore client writes/reads for authoritative game data are denied by rules.

Authoritative data access (profile, ownership, runs, boards, ghosts, account delete) goes through callables, not direct Firestore from the app.

## 2) Ownership by layer

- Flutter auth adapter: `FirebaseAuthApi`
  - `lib/ui/state/firebase_auth_api.dart`
  - Handles session discovery, refresh, anonymous sign-in fallback, provider linking.
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

1. `main()` initializes Firebase and starts `UiApp`.
2. `BrandSplashScreen` routes to loader.
3. `LoaderPage` calls `AppState.bootstrap()`.
4. `AppState.bootstrap()` calls `_ensureAuthSession()`.
5. `_ensureAuthSession()` delegates to `AuthApi.ensureAuthenticatedSession()`.

`FirebaseAuthApi.ensureAuthenticatedSession()` behavior:

- Try current Firebase user (`readCurrent(forceRefresh: false)`).
- If no user:
  - try Play Games restore (`tryRestorePlayGamesSession()`) on Android,
  - else create anonymous user (`signInAnonymously()`).
- If token is near expiry, force refresh and retry.
- If session is still invalid, retry refresh/restore/sign-in fallback chain.

This means the app does not rely on pre-existing login state; it guarantees an authenticated Firebase user before remote calls.

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

- `ProfilePage` offers "Link Play Games" when session is authenticated + anonymous + not already linked.

## 6) Callable request auth contract (server-side)

Current callable pattern across domains:

1. Require `request.auth?.uid`.
2. Parse and validate request payload.
3. Verify request `userId` equals authenticated `uid`.
4. Execute domain logic.
5. Return typed payload.

This pattern is implemented in:

- ownership/profile/account callables in `functions/src/index.ts`
- runs/leaderboards/ghost callables in `functions/src/*/callable_handlers.ts`

So even if client sends a forged `userId`, the backend rejects on uid mismatch.

## 7) Authorization boundaries and data access model

- Firestore security rules deny direct client access for key collections (`ownership_profiles`, `player_profiles`, `display_name_index`).
- App uses `cloud_functions` callables as the only remote mutation/read path for authoritative state.
- Backend uses Admin SDK with explicit auth checks in callable handlers.

## 8) Account deletion flow

Client flow:

1. `ProfilePage` confirms deletion.
2. `AppState.deleteAccountAndData()` ensures auth session.
3. Calls `accountDelete` callable with `userId` + `sessionId`.
4. On success, app clears local state and signs out via `AuthApi.clearSession()`.

Server flow (`functions/src/account/delete.ts`):

- Deletes profile docs and display-name index claims.
- Deletes ownership docs/subcollections.
- Deletes run/session/validated/reward docs and ghost-related docs/artifacts.
- Attempts Firebase Auth user deletion (`deleteUser(uid)`), tolerating already-missing user.

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