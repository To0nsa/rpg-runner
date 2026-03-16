# Firebase Cloud Functions Overview (What, How, Why)

This doc explains the Firebase Cloud Functions currently used by the app, how each one is called, and why it exists.

## 1) Where functions are defined

All exported functions are defined in:

- `functions/src/index.ts`

The Flutter app calls these through `FirebaseFunctions.instance.httpsCallable(...)` inside adapters in:

- `lib/ui/state/*.dart`

## 2) Shared security model (all callables)

Every callable follows the same auth/authorization pattern:

1. Require authenticated Firebase user (`request.auth?.uid`).
2. Parse/validate request payload.
3. Verify `userId` in payload matches `request.auth.uid`.
4. Execute domain logic.

Why:

- Prevents client identity spoofing.
- Keeps identity authority on Firebase Auth token claims, not client input.
- Keeps backend contracts deterministic and auditable.

## 3) Callable functions used by the app

## Ownership / progression

### `loadoutOwnershipLoadCanonicalState`

- Client adapter: `lib/ui/state/firebase_loadout_ownership_api.dart`
- Called by: `AppState.bootstrap()`, run preflight, fallback flows.
- Returns canonical ownership state (selection/meta/progression + revision).

Why:

- Backend is source-of-truth for progression and ownership.
- Ensures app starts from authoritative state, not stale local cache.

### `loadoutOwnershipExecuteCommand`

- Client adapter: `lib/ui/state/firebase_loadout_ownership_api.dart`
- Called for all ownership mutations (`setSelection`, `setLoadout`, `equipGear`, `awardRunGold`, store actions, etc.).
- Uses command envelopes with revision + idempotency.

Why:

- Prevents write races and duplicate mutation effects.
- Centralizes gameplay economy/ownership invariants server-side.

---

## Player profile

### `playerProfileLoad`

- Client adapter: `lib/ui/state/firebase_user_profile_remote_api.dart`
- Called by: `AppState.bootstrap()` and fallback/default flows.
- Loads or lazily creates profile.

Why:

- Guarantees profile availability for authenticated users.
- Avoids brittle first-run client initialization logic.

### `playerProfileUpdate`

- Client adapter: `lib/ui/state/firebase_user_profile_remote_api.dart`
- Called by: profile rename flow + profile-name onboarding completion.

Why:

- Enforces display-name policy and uniqueness server-side.
- Prevents inconsistent profile writes across clients/devices.

---

## Account deletion

### `accountDelete`

- Client adapter: `lib/ui/state/firebase_account_deletion_api.dart`
- Called by: profile page destructive action.
- Deletes profile/ownership/run/ghost related data and attempts Firebase Auth user deletion.

Why:

- Provides one authoritative account-erasure path.
- Keeps deletion coverage explicit and testable.
- Supports compliance and user-data lifecycle requirements.

---

## Run session + replay submission lifecycle

### `runBoardsLoadActive`

- Client adapter: `lib/ui/state/firebase_run_boards_api.dart`
- Called by: run-start preflight and leaderboard board resolution.
- Returns active board manifest for mode+level+compat version.

Why:

- Board availability/windowing is server-controlled.
- Prevents clients from inventing board authority.

### `runSessionCreate`

- Client adapter: `lib/ui/state/firebase_run_session_api.dart`
- Called by: run start descriptor preparation.
- Returns run ticket (`runSessionId`, seed, mode/level/character/loadout snapshot, board linkage).

Why:

- Run issuance is server-authoritative.
- Removes reward-bearing run authority from local client-only state.

### `runSessionCreateUploadGrant`

- Client adapter: `lib/ui/state/firebase_run_session_api.dart`
- Called by: replay submission coordinator before upload.
- Returns scoped upload grant for pending replay artifact.

Why:

- Controls who can upload, where, and for which run session.
- Avoids open-ended client storage writes.

### `runSessionFinalizeUpload`

- Client adapter: `lib/ui/state/firebase_run_session_api.dart`
- Called after upload with content hash/size and metadata.
- Transitions server-side submission state.

Why:

- Moves session state progression to backend control.
- Enables deterministic replay validation pipeline entry.

### `runSessionLoadStatus`

- Client adapter: `lib/ui/state/firebase_run_session_api.dart`
- Called by: submission polling/refresh and resume flows.
- Returns current submission status.

Why:

- Lets UI reflect backend truth (queued/validated/rejected/etc.).
- Supports robust app resume and retry UX.

---

## Leaderboards

### `leaderboardLoadBoard`

- Client adapter: `lib/ui/state/firebase_leaderboard_api.dart`
- Called by: leaderboard screen.
- Returns board entries/view model.

Why:

- Keeps rank/ordering authority server-side.
- Avoids trust in local leaderboard state for competitive views.

### `leaderboardLoadMyRank`

- Client adapter: `lib/ui/state/firebase_leaderboard_api.dart`
- Called by: leaderboard “my rank” view.
- Returns caller-specific rank projection.

Why:

- Computes rank from authoritative board data.
- Avoids client-side rank inference drift.

---

## Ghost replay manifest

### `ghostLoadManifest`

- Client adapter: `lib/ui/state/firebase_ghost_api.dart`
- Called when loading a ghost entry from leaderboard context.
- Returns ghost manifest + signed short-lived download URL.

Why:

- Keeps ghost artifact paths private behind callable auth checks.
- Enforces URL TTL/signing policy centrally.

## 4) Scheduled backend maintenance functions (not directly called by app)

### `runSubmissionCleanup` (scheduled)

- Exported in `functions/src/index.ts`.
- Runs periodic cleanup for stale uploads/artifacts and retention windows.
- Uses logic in `functions/src/runs/cleanup.ts`.

Why:

- Prevents unbounded storage/doc growth.
- Keeps run submission lifecycle healthy over time.

### `leaderboardBoardMaintenance` (scheduled)

- Exported in `functions/src/index.ts`.
- Ensures managed leaderboard boards/windows exist.
- Uses logic in `functions/src/boards/provisioning.ts`.

Why:

- Keeps competitive/weekly windows provisioned without manual intervention.
- Avoids runtime board-missing failures.

## 5) End-to-end usage map

### Bootstrap/login phase

- App ensures Firebase auth session (`FirebaseAuthApi`).
- Calls:
  - `playerProfileLoad`
  - `loadoutOwnershipLoadCanonicalState`

### Profile management phase

- Calls:
  - `playerProfileUpdate`
  - `accountDelete` (destructive path)

### Run start + submit phase

- Calls:
  - `runBoardsLoadActive` (preflight/manifest)
  - `runSessionCreate`
  - `runSessionCreateUploadGrant`
  - `runSessionFinalizeUpload`
  - `runSessionLoadStatus`

### Leaderboard/ghost browsing phase

- Calls:
  - `leaderboardLoadBoard`
  - `leaderboardLoadMyRank`
  - `ghostLoadManifest`

### Progression mutations phase

- Calls:
  - `loadoutOwnershipExecuteCommand`

## 6) Why this architecture is used

- Security: identity and authorization are enforced server-side.
- Determinism: authoritative backend state for progression, runs, and rankings.
- Idempotency/revision safety: command-based ownership updates avoid duplicate effects.
- Operability: scheduled maintenance keeps storage and board windows clean.
- Client simplicity: Flutter side stays as typed adapters + state orchestration, without direct authority over protected data.