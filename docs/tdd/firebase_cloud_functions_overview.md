# Firebase Cloud Functions Overview (What, How, Why)

This doc explains the Firebase Cloud Functions currently used by the app, how each one is called, and why it exists.

## 1) Where functions are defined

All exported functions are defined in:

- `functions/src/index.ts`

The Flutter app calls these through `FirebaseFunctions.instance.httpsCallable(...)` inside adapters in:

- `lib/ui/state/*.dart`

The deployed 2nd-generation Functions runtime is Node.js 24, selected by
`functions/package.json`. This runtime choice applies to every function in the
codebase and must stay aligned with the local/CI Node version used for builds
and emulator tests.

The backend SDK baseline is Firebase Functions 7, Firebase Admin 14, and Cloud
Tasks 6. The workspace lockfile contains narrow patched `uuid` overrides for
two older Storage HTTP helpers; remove those overrides only after their
upstream dependency ranges accept the patched major.

## 2) Shared security model (all callables)

Every callable follows the same auth/authorization pattern:

1. Apply the configured Functions v2 App Check policy.
2. Require authenticated Firebase user (`request.auth?.uid`).
3. Enforce shared JSON size/depth/node bounds and parse the request.
4. Verify `userId` in payload matches `request.auth.uid`.
5. Enforce deletion, quota, and operation-specific authorization policy.
6. Execute domain logic.

Why:

- Prevents client identity spoofing.
- Keeps identity authority on Firebase Auth token claims, not client input.
- Keeps backend contracts deterministic and auditable.
- Rejects bounded abuse before Storage signing, task dispatch, or protected
  expensive reads.

Authentication does not authorize every operation supported by an internal
domain module. Public ownership requests use an explicit client-command
allowlist. Internal reward, entitlement-grant, and reset operations are not
reachable by selecting a command type in the callable payload.

Authority time follows the same boundary rule. Public run, board, leaderboard,
upload-grant, and finalize requests must omit `nowMs`; supplying it is rejected.
After auth and UID matching, the callable captures one server timestamp and
passes it to the internal operation. Internal stores retain explicit time
injection only for deterministic tests and scheduled/server-owned workflows.

App Check and quotas are staged controls, not authority. The repository default
is monitoring mode because production platform-attestation rates and normal
request distributions have not been measured. Exact platform behavior,
configuration, request bounds, quota storage, and rollback rules are specified
in [`callable_abuse_controls.md`](callable_abuse_controls.md).

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
- Public commands are limited to selection/loadout/equip actions and
  server-validated store purchase/refresh actions.
- Direct gold awards, entitlement grants, and ownership reset are server-only
  operations and have no Flutter command DTO or callable API method.
- Uses bounded command envelopes with revision + payload-hash idempotency.
- Stores only the compact outcome/revision for 14 days, twice the supported
  seven-day offline retry window; it does not copy canonical state into every
  command record.
- Selection, loadout, gear, projectile, and ability mutations validate catalog
  compatibility and canonical ownership before writing.

Why:

- Prevents write races and duplicate mutation effects.
- Centralizes gameplay economy/ownership invariants server-side.
- Ensures verified replay settlement is the only run-gold credit path and store
  purchase is the public permanent-unlock path.

---

## Player profile

### `playerProfileLoad`

- Client adapter: `lib/ui/state/firebase_user_profile_remote_api.dart`
- Called by: `AppState.bootstrap()` and fallback/default flows.
- Loads or lazily creates the profile inside a Firestore transaction.

Why:

- Guarantees profile availability for authenticated users.
- Avoids brittle first-run client initialization logic.
- Prevents a first load from overwriting a concurrent first name update and
  orphaning its unique-name claim.

### `playerProfileUpdate`

- Client adapter: `lib/ui/state/firebase_user_profile_remote_api.dart`
- Called by: profile rename flow + profile-name onboarding completion.

Why:

- Enforces display-name policy and uniqueness server-side.
- Rejects caller-supplied `displayNameLastChangedAtMs`; Flutter only sends the
  requested name and renders the timestamp returned by the backend.
- Preserves the one-time initial-name exception with timestamp `0`. The first
  later rename captures server time and starts a 24-hour cooldown. Further
  renames are decided in the same transaction that reserves the normalized
  name; the exact 24-hour boundary is allowed.
- Treats a legacy future cooldown timestamp as invalid during the next rename,
  allowing the transaction to replace it with server time rather than leaving
  the profile locked indefinitely.
- Prevents inconsistent profile writes across clients/devices.

---

## Account deletion

### `accountDelete`

- Client adapter: `lib/ui/state/firebase_account_deletion_api.dart`
- Called by: profile page destructive action.
- Creates an idempotent `account_deletion_requests/{uid}` tombstone before
  returning an accepted deletion status.
- Disables Auth and delegates bounded, resumable erasure to the scheduled
  `accountDeletionRepair` worker.

Why:

- Immediately blocks lazy creation and user callables even while an older ID
  token remains valid.
- Prevents a timeout or concurrent request from leaving an enabled,
  partially-erased account.
- Repeats the explicit data/Storage inventory until empty, waits out the
  signed-upload lease, performs a fresh final pass, then deletes Auth.

The state machine, deletion inventory, client statuses, and completion
retention are specified in
[`account_deletion_workflow.md`](account_deletion_workflow.md).

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
- Sends a bounded client request ID. Identical retries and concurrent
  duplicates return one deterministic session/ticket; request-ID reuse with
  different parameters is rejected.
- Revalidates the selected loadout against the server catalog and canonical
  ownership before snapshotting it.
- Issues the ticket from callable-captured server time with a 24-hour lifetime.
- Ranked tickets snapshot the board open/close timestamps used later by replay
  validation; mutable board deletion does not reinterpret an issued ticket.
- Atomically observes a configurable non-terminal active-session cap before
  creating the session.

Why:

- Run issuance is server-authoritative.
- Removes reward-bearing run authority from local client-only state.

### `runSessionCreateUploadGrant`

- Client adapter: `lib/ui/state/firebase_run_session_api.dart`
- Called by: replay submission coordinator before upload.
- Returns scoped upload grant for pending replay artifact.
- The signed grant and upload lease cap the replay at 8 MiB, and active upload
  grants have a configurable transactional per-UID cap.
- Upload lease issue/expiry timestamps come from callable-captured server time.
- If the run ticket has expired, the terminal `expired` state commits before
  the callable returns its failed-precondition error.

Why:

- Controls who can upload, where, and for which run session.
- Avoids open-ended client storage writes.

### `runSessionFinalizeUpload`

- Client adapter: `lib/ui/state/firebase_run_session_api.dart`
- Called after upload with content hash/size and metadata.
- Rejects claimed or stored replay sizes above 8 MiB and records attempted
  finalized bytes against the per-UID quota before Storage metadata lookup.
- Transitions server-side submission state.
- Finalize expiry and `finalizedAtMs` use callable-captured server time.
- Expiry atomically revokes any provisional grant. A post-commit task enqueue
  failure leaves `uploaded` as the durable validation-repair handoff.
- Captures the exact positive Cloud Storage object generation and rejects a
  later re-finalization that points at a different generation.

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
- Returns the active manifest, including replay digest and Storage generation lineage, plus a short-lived URL signed for that exact promoted object generation.

Why:

- Keeps ghost artifact paths private behind callable auth, account-deletion, and quota checks.
- Enforces URL TTL/signing policy centrally.

## 4) Scheduled backend maintenance functions (not directly called by app)

### `runSubmissionCleanup` (scheduled)

- Exported in `functions/src/index.ts`.
- Runs periodic cleanup for stale uploads/artifacts, unreferenced canonical
  ghost objects older than a 48-hour consistency grace period, and retention
  windows.
- Uses logic in `functions/src/runs/cleanup.ts`.

Why:

- Prevents unbounded storage/doc growth without deleting a ghost that is still
  referenced by an active or demoted manifest.
- Keeps run submission lifecycle healthy over time.

### `leaderboardBoardMaintenance` (scheduled)

- Exported in `functions/src/index.ts`.
- Ensures managed leaderboard boards/windows exist.
- Uses logic in `functions/src/boards/provisioning.ts`.
- Defaults new boards to current game compatibility `2026.08.0`. A managed
  board ID binds mode, level, window, ruleset, score, game compatibility, and
  ghost version, so rollout partitions can coexist without sharing
  leaderboard/ghost descendants.
- Active-board and run-session callables accept only the compatibility
  allowlist resolved from `RUN_SUPPORTED_GAME_COMPAT_VERSIONS`. The Phase 7
  default is `2026.08.0,2026.03.0`; `2026.03.0` is removed only after the
  24-hour ticket drain and active-session audit complete.
- The read-only production inventory groups active sessions by game
  compatibility and reports their valid minimum/maximum expiry timestamps. It
  exposes no session or player identity and gives retirement operators an
  exact drain horizon. Its optional compatibility-retirement gate stays false
  until the 24-hour interval has elapsed, no active session remains, every
  issuance timestamp is assessable, and no matching ticket was observed after
  the operator-recorded cutoff.
- Missing-board fallback provisions the requested supported compatibility
  partition instead of silently using the current default.

Why:

- Keeps competitive/weekly windows provisioned without manual intervention.
- Avoids runtime board-missing failures.

### `playerProfileConsistencyRepair` (scheduled)

- Walks bounded, independently cursor-paged batches of `player_profiles` and
  `display_name_index`.
- Creates missing claims, repairs canonical normalized-name metadata, and
  removes claims whose recorded owner no longer has the indexed name.
- Never replaces an index entry owned by another UID. An orphan must first be
  removed by the index pass before a later profile pass can claim the name.
- Persists scan cursors and per-page inventory counts in
  `system_maintenance/profile_consistency_repair`.

Why:

- Repairs mismatches that may have been created by the former non-transactional
  first-profile load.
- Bounds each invocation while eventually inventorying both collections.

### `accountDeletionRepair` (scheduled)

- Leases one bounded page at a time from active account deletion requests.
- Resumes retryable failures without requiring the deleted account to remain
  authenticated.
- Removes completed tombstones after the documented retention window.

### Abuse/idempotency retention (scheduled)

- `abuseQuotaRetentionCleanup` deletes expired fixed-window UID counters.
- `ownershipIdempotencyRetentionCleanup` expires compact records and advances
  the bounded one-time legacy full-state compaction cursor.
- Both run hourly; Security Rules deny direct clients and account deletion
  removes UID-owned quota/idempotency state.

### Settlement and projection operations

- `runSettlementOnHandoff` settles an accepted run after Firestore handoff.
- `runSettlementImmediate` is the validator's low-latency authenticated request
  to the same idempotent settlement transaction.
- `runSettlementRepair` scans bounded pending sessions and retries only
  retryable delivery failures; persistent data contradictions are surfaced as
  invariant violations without crediting gold.
- `runValidationRepair` transactionally clears expired validator lease tokens
  and requeues expired/orphaned validation work with generation-specific Cloud
  Tasks names. It is the recovery path after worker death or queue exhaustion;
  ordinary retry timing remains Cloud Tasks-owned.
- `runSubmissionCleanup` atomically expires eligible run sessions and revokes
  their provisional grants, then terminalizes old orphaned provisional grants
  after a 48-hour grace period while preserving active validation grants.
- `runProjectionOnAccepted` enqueues board-backed leaderboard/ghost projection
  separately from settlement, so projection retry cannot delay payout.
- `runProjectionReconciliation` is configured with 512 MiB of memory, pages
  through managed board documents every 15 minutes, and enqueues deterministic
  reconciliation tasks. One Cloud Tasks client is reused for the complete
  invocation and closed on either success or enqueue failure. It advances its
  cursor only after the whole page is durably enqueued, so a failed page is
  replay-safe and leaderboard/ghost convergence does not require a new score.
- The completed legacy reward-grant cutover has no deployed scheduled
  function. Normal canonical state reads never perform migration work; any
  future migration must be explicitly introduced, verified, and removed as a
  finite operation rather than left as idle production infrastructure.

Operational metrics, alert thresholds, and the staged migration procedure are
defined in `docs/tdd/reward_settlement_operations.md`.

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

## 6) Build, audit, and emulator test contract

- `corepack pnpm --dir functions build` compiles production TypeScript.
- `corepack pnpm --dir functions test` compiles every test and uses Node 24's
  glob-based test discovery over `lib_test/test/**/*.test.js`.
- Functions tests use `firebase.test.json`, a demo project ID, and
  multi-project emulator mode. This keeps FlutterFire metadata out of the
  Firebase CLI test schema and permits domain-isolated emulator project IDs.
- The suite includes explicit Security Rules denials for authenticated and
  unauthenticated direct clients across all server-owned collection paths.
- `corepack pnpm --dir functions audit --prod` is a release gate and runs in the
  Functions CI workflow together with build and the emulator suite.
- Firebase CLI is pinned in `functions/package.json`; local and CI tests must
  use that workspace binary through the package script.

## 7) Why this architecture is used

- Security: identity and authorization are enforced server-side.
- Determinism: authoritative backend state for progression, runs, and rankings.
- Idempotency/revision safety: command-based ownership updates avoid duplicate effects.
- Operability: scheduled maintenance keeps storage and board windows clean.
- Client simplicity: Flutter side stays as typed adapters + state orchestration, without direct authority over protected data.
