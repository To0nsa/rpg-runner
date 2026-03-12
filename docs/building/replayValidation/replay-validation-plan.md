# Replay Validation Production Plan

Date: March 12, 2026  
Status: Ready to implement

## Goal

Build a production-grade replay-validation system for Competitive and Weekly
runs that:

- keeps gameplay local and low-latency on device
- moves run acceptance, rewards, leaderboard publication, and ghost exposure to
  backend authority
- is modular enough to support a dedicated validator service, online
  leaderboards, and deterministic ghost playback without turning the game into a
  live server-authoritative session game

This plan does not optimize for minimum churn. It favors clean boundaries,
shared contracts, and long-term maintainability.

## Outcome

After this plan lands:

- all runs require network + auth to start
- Practice remains unranked and ghost-free, but uses the same reward-validation
  authority path as other modes
- every run starts from a server-issued run session or ticket
- The client records a canonical replay stream from the actual commands applied
  to Core, not from raw gestures.
- every run submission uploads a replay blob for validation
- Only validated Top 10 entries retain durable ghost-visible replay assets.
- A dedicated Dart validator service replays the deterministic core headlessly.
- Only validated results can:
  - award gold in any mode
  - update online leaderboards for Competitive/Weekly
  - publish ghost payloads for Top 10 Competitive/Weekly entries
- the current client-trusted gold award path and local Competitive leaderboard
  path are removed

## Scope

In scope:

- extraction of deterministic gameplay into a pure Dart workspace package
- a shared replay/board/submission protocol module
- online run-start issuance for all modes
- Competitive/Weekly board metadata and compat gating
- canonical replay capture, local spool storage, upload, finalize, retry, and
  status tracking
- a Cloud Run style validator worker in Dart
- server-side validated result persistence, ranking, reward grant issuance, and
  ghost publication
- UI cutover for Game Over, leaderboard browsing, and submission status

Out of scope:

- replacing local gameplay with a live 60 Hz server session
- full anti-cheat beyond deterministic replay validation and protocol sanity
  checks
- broad economy redesign beyond validated reward authority
- Google Play leaderboard publishing during the initial replay-validation rollout

## Future Anti-Cheat Plan

This plan establishes the authority foundation first:

- server-issued run sessions
- canonical replay capture
- deterministic replay validation
- protocol sanity validation
- server-owned reward, leaderboard, and ghost decisions

A broader anti-cheat program can be layered on later without changing the core
validation architecture.

Likely later additions:

- suspicious-run heuristics and anomaly scoring
- account and device abuse rate limits
- build integrity or attestation checks
- client tamper or hook detection
- operational review tools for flagged runs
- enforcement policy for invalid or abusive accounts

## Google Play Integration Later

Google Play leaderboard support should be treated as a later adapter, not as a
core dependency of this plan.

Rules:

- backend-validated results remain the only source of truth for rewards,
  ranking, and ghost eligibility
- Google Play can be added later as an external publishing surface for accepted
  Competitive/Weekly results
- Google Play must never become the authority for:
  - run validation
  - gold rewards
  - board identity or window rules
  - Top 10 ghost publication

Recommended rollout order:

1. ship validated run submission and internal leaderboard authority
2. stabilize board, reward, and ghost contracts
3. add Google Play result publishing as a downstream sync adapter

## Current Baseline (As-Is)

The current runtime is not safe for server-authoritative rewards or
Competitive fairness:

- `lib/ui/state/app_state.dart`
  - `buildRunStartArgs()` issues a random seed for all modes.
  - `createRunId()` generates a timestamp-derived integer on device.
- `lib/ui/state/selection_state.dart`
  - `RunType` only models `practice` and `competitive`.
  - Weekly exists only in docs/UI placeholders, not in authoritative state.
- `lib/ui/runner_game_widget.dart`
  - trusts local `RunEndedEvent`
  - immediately calls `AppState.awardRunGold(...)`
- `lib/ui/leaderboard/shared_prefs_leaderboard_store.dart`
  - stores Competitive results locally in SharedPreferences
- `functions/src/index.ts`
  - exposes ownership/profile/account callables only
  - has no board metadata, run ticket, replay submission, or leaderboard
    endpoints
- `packages/runner_core` is now extracted as a pure Dart package, but replay
  protocol, submission, and validation authority are not implemented yet

This baseline is acceptable for a local game slice. It is not acceptable for a
production Competitive leaderboard.

## Locked Decisions

1. Do not build a live authoritative session service first.
2. All runs remain client-simulated, server-validated for rewards; Competitive
   and Weekly are additionally server-ranked.
3. Validator runtime is a separate Dart service, not a Firebase callable.
4. Keep deterministic simulation in a pure Dart workspace package
   (`packages/runner_core`).
5. Use a dedicated shared replay protocol instead of ad-hoc JSON maps in UI and
   backend code.
6. Canonical replay capture happens at the `GameController -> GameCore`
   boundary, after tick coalescing and command dedupe.
7. All runs require network + auth to start and receive a single-use
   server-issued run session or ticket.
8. Replay upload and validation are asynchronous and durable for every
   reward-bearing run submission.
9. Gold is granted only from validated results in every mode.
10. Online ranking uses a server-computed canonical sort key; clients never
    compute global rank authority.
11. Keep Practice PB storage local and separate from online leaderboards.
12. Top 10 only applies to ghost retention and ghost exposure, not to replay
    upload for validation.

## Chosen Architecture

Use a four-part architecture:

1. Flutter app:
   - runs the live game locally
   - records canonical replay data
   - uploads replay blobs
   - shows provisional result + submission status
2. Firebase Functions:
   - auth edge
   - board metadata read API
   - run ticket issuance
   - upload finalize / status endpoints
   - online leaderboard read API
3. Firestore + Cloud Storage + task queue:
   - Firestore stores board metadata, run session state, validated result
     records, best-entry projections, and reward grants
   - Cloud Storage stores pending replay submissions for all runs and promoted
     ghost payloads for Top 10 only
   - Cloud Tasks (or equivalent queue) drives validator retries and backoff
4. Dart replay validator service:
   - decodes canonical replay blobs
   - replays `runner_core` headlessly
   - writes validated results
   - issues server-owned reward grants
   - updates leaderboard projections and ghost availability

`Cloud Run` and `Cloud Tasks` are Google Cloud services used alongside Firebase,
not Firebase products themselves. In this plan, Firebase remains the app-facing
backend surface through Auth, Firestore, Storage, and Functions, while Cloud
Tasks dispatches background validation work to a private Cloud Run validator
service in the same Google project.

Topology:

```text
Flutter app
  -> Firebase callable: load boards / issue run ticket / finalize upload / poll status
  -> Cloud Storage signed upload: replay blob

Firebase Functions
  -> Firestore: board + run session state
  -> Cloud Tasks: validate run session

Cloud Tasks
  -> private Dart validator service

Validator service
  -> Cloud Storage: download replay blob
  -> Firestore: validated runs / best entries / top10 snapshot / reward grants

Ownership backend
  -> folds reward grants into canonical progression state
```

## Required Modularization

### 1) Keep deterministic gameplay in a pure Dart package (Phase 1 complete)

Create:

```text
packages/
  runner_core/
    lib/
      runner_core.dart
      ...
```

Current state:

- deterministic gameplay lives in `packages/runner_core/lib/**`
- legacy in-app Core source tree has been removed
- app/runtime imports use `package:runner_core/...`

Rules:

- `runner_core` must stay Flutter-free and Flame-free.
- All deterministic systems, commands, scoring, events, snapshots, and replay
  helpers live here.
- `lib/game/**` and `lib/ui/**` must import `package:runner_core/...`.

Reason:

- the validator must not depend on the Flutter application package
- replay tests must run headlessly without Flutter bootstrapping

### 2) Create a shared replay/board protocol package

Create:

```text
packages/
  run_protocol/
    lib/
      board_key.dart
      board_manifest.dart
      run_mode.dart
      run_ticket.dart
      replay_blob.dart
      replay_digest.dart
      validated_run.dart
      leaderboard_entry.dart
      submission_status.dart
      codecs/
```

This package is the source of truth for:

- replay blob header schema
- board identity and metadata DTOs
- run ticket shape
- validated result DTOs consumed by UI
- canonical sort-key construction

Do not leave these contracts split across Flutter UI models, TypeScript string
constants, and validator-local structs.

### 3) Add a dedicated validator service package

Create:

```text
services/
  replay_validator/
    pubspec.yaml
    bin/server.dart
    lib/src/
      app.dart
      validator_worker.dart
      replay_loader.dart
      board_repository.dart
      run_session_repository.dart
      leaderboard_projector.dart
      reward_grant_writer.dart
      ghost_publisher.dart
      metrics.dart
    test/
```

This service depends on:

- `package:runner_core`
- `package:run_protocol`

It must not depend on Flutter, Flame, or widget-layer code.

## Domain Model

### Run modes

Replace the current two-value mode split with a domain that can represent the
actual product rules:

```text
RunMode = practice | competitive | weekly
```

Refactor the current `RunType` state and route arguments to use this model.

### BoardKey

Competitive and Weekly boards are keyed by:

```text
BoardKey {
  mode,             // competitive | weekly
  levelId,
  windowId,         // seasonMonthId (competitive) | weekId (weekly)
  rulesetVersion,
  scoreVersion
}
```

### BoardManifest

Board metadata returned to the client:

```text
BoardManifest {
  boardId,              // stable server id
  boardKey,
  gameCompatVersion,
  ghostVersion,
  tickHz,
  seed,
  opensAtMs,
  closesAtMs,
  minClientBuild?,
  status               // scheduled | active | closed | disabled
}
```

`disabled` is part of the authoritative lifecycle even when hidden from normal
client browsing surfaces.

## Board Operations

Board metadata is runtime authority, not a loose config file.

Required operational rules:

- boards are authored and published through an internal admin path, never by
  direct document edits in production
- a board can move only through explicit states:
  - `scheduled`
  - `active`
  - `closed`
  - `disabled`
- only one active board may exist for a given `(mode, levelId, windowId)`
- Competitive and Weekly board publication must be atomic with:
  - seed
  - `gameCompatVersion`
  - `rulesetVersion`
  - `scoreVersion`
  - `ghostVersion`
- disabling a board must immediately block new run issuance without corrupting
  already-issued run sessions
- week rollover and season rollover must create new board identities rather than
  mutating historical boards in place
- historical board metadata must remain readable for audit, replay inspection,
  and ghost compatibility checks

Window cadence rules:

- Competitive seasons are exactly one calendar month in UTC.
- Competitive `windowId` must identify the month window
  (recommended format: `YYYY-MM`, for example `2026-03`).
- Competitive board windows should use:
  - `opensAtMs` = first day of month at `00:00:00.000` UTC
  - `closesAtMs` = first day of next month at `00:00:00.000` UTC
- Weekly boards rotate every week with a unique `weekId` per weekly window.
- Any window rollover creates a new board identity; historical board documents are
  immutable.

Emergency controls:

- disable a board from issuing new runs
- hide a board from browsing surfaces
- stop ghost publication for a board
- reject new submissions for a board while still preserving historical data

### RunTicket

Single-use server-issued start permission for any run that can affect
progression:

```text
RunTicket {
  runSessionId,         // string ULID/UUIDv7, never timestamp int
  uid,
  mode,
  boardId?,             // present for competitive | weekly
  boardKey?,            // present for competitive | weekly
  seed,
  tickHz,
  gameCompatVersion,
  rulesetVersion?,      // required for competitive | weekly
  scoreVersion?,        // required for competitive | weekly
  ghostVersion?,        // required for competitive | weekly
  levelId,
  playerCharacterId,
  loadoutSnapshot,
  loadoutDigest,
  issuedAtMs,
  expiresAtMs,
  singleUseNonce
}
```

Rules:

- one ticket = one submittable run
- ticket is bound to user + mode + loadout snapshot
- Competitive/Weekly tickets are additionally bound to board identity
- ticket cannot be reused after finalize succeeds
- run start requires live network/auth; offline ticket pools are not part of the
  production model

### Server-Derived Run Start Snapshot

The run start contract must not trust the client to declare its own authoritative
character/loadout snapshot.

Rules:

- the client may request a run using its current UI selection
- the backend must load canonical ownership state and derive the authoritative
  start snapshot from server-side selection/loadout state
- the issued `RunTicket.loadoutSnapshot` and any server-derived character/level
  fields are the only start state the validator will trust later
- if the client UI is stale relative to canonical ownership, run issuance must
  fail cleanly and force the client to refresh state before starting

### Run Session State Machine

`run_sessions/{runSessionId}` needs an explicit lifecycle. Do not treat state
transitions as implicit side effects.

Recommended states:

- `issued`
  - run ticket created, run not yet finalized
- `uploading`
  - upload lease is active via `runSessionCreateUploadGrant`
- `uploaded`
  - replay blob metadata has been recorded idempotently
- `pending_validation`
  - finalize succeeded and validation work has been queued
- `validating`
  - validator lease acquired
- `validated`
  - replay accepted and terminal artifacts persisted
- `rejected`
  - replay processed and rejected
- `expired`
  - issued run never finalized before expiry
- `cancelled`
  - admin or system cancellation before terminal validation
- `internal_error`
  - terminal failure after retry budget is exhausted

State rules:

- only legal forward transitions are allowed
- canonical happy path is:
  - `issued -> uploading -> uploaded -> pending_validation -> validating -> validated|rejected`
- `runSessionCreate` issues only the ticket and starts at `issued`
- `runSessionCreateUploadGrant` moves `issued|uploading -> uploading` and may be
  called repeatedly until finalize succeeds
- finalize is idempotent for the same replay metadata and must reject conflicting
  re-finalize attempts
- `runSessionFinalizeUpload` must:
  - record upload metadata idempotently (`uploading|issued -> uploaded`)
  - enqueue validation
  - transition to `pending_validation`
  - if enqueue fails transiently, remain in `uploaded` and allow safe retry
- validation retries may move `pending_validation -> validating ->
  pending_validation` without creating duplicate grants or duplicate leaderboard
  entries
- terminal states are immutable except for support metadata or audit annotations
- expired sessions must never mint rewards or leaderboard entries

### ReplayBlobV1

Canonical replay payload:

```text
ReplayBlobV1 {
  replayVersion: 1,
  runSessionId,
  boardId?,            // required for competitive | weekly
  boardKey?,           // required for competitive | weekly
  tickHz,
  seed,
  levelId,
  playerCharacterId,
  loadoutSnapshot,
  commandEncodingVersion,
  totalTicks,
  commandStream,
  canonicalSha256,
  clientSummary?       // diagnostics only, not authority
}
```

Practice replays are boardless and must omit `boardId` and `boardKey`.

The `commandStream` is not raw UI intent. It is the applied tick command stream
after `GameController` coalescing.

### ValidatedRun

Canonical output of the validator:

```text
ValidatedRun {
  runSessionId,
  uid,
  boardId?,            // required for competitive | weekly
  boardKey?,           // required for competitive | weekly
  mode,
  accepted,
  rejectionReason?,
  score,
  distanceMeters,
  durationSeconds,
  tick,
  endedReason,
  goldEarned,
  stats,
  replayDigest,
  replayStorageRef,
  createdAtMs
}
```

Practice validated runs remain auditable in `validated_runs` with board fields
unset and no leaderboard projection writes.

### Best leaderboard entry per player

Do not rank every run document directly. Persist every validated run for audit,
but maintain one canonical best entry per `(boardId, uid)`.

```text
PlayerBoardBest {
  boardId,
  uid,
  entryId,
  runSessionId,
  displayName,
  characterId,
  score,
  distanceMeters,
  durationSeconds,
  sortKey,
  ghostEligible,
  replayStorageRef,
  updatedAtMs
}
```

## Canonical Sort Key

To keep rank queries Firestore-friendly, materialize a single lexicographic
sort key that preserves:

1. score descending
2. distance descending
3. duration ascending
4. stable final tie-break

Recommended approach:

- invert descending fields into fixed-width positive ranges
- zero-pad all segments
- append a stable tie-break such as `entryId`

Example shape:

```text
sortKey = "{invScore}:{invDistance}:{duration}:{entryId}"
```

Benefits:

- `top10 = orderBy(sortKey).limit(10)`
- exact rank for a known player best can be derived via count query on
  `sortKey < mySortKey`
- no client-side rank recomputation

## Firestore and Storage Layout

Recommended layout:

```text
firestore
  leaderboard_boards/{boardId}
  leaderboard_boards/{boardId}/views/top10
  leaderboard_boards/{boardId}/player_bests/{uid}
  run_sessions/{runSessionId}
  validated_runs/{runSessionId}
  reward_grants/{runSessionId}

cloud storage
  replay-submissions/pending/{uid}/{runSessionId}/replay.bin.gz
  replay-submissions/validated/{runSessionId}.bin.gz
  ghosts/{boardId}/{entryId}/ghost.bin.gz
```

Rules:

- clients never write Firestore docs directly
- clients upload replay bytes only through a signed upload grant
- every run submission uploads to
  `replay-submissions/pending/...`
- accepted non-Top-10 replays are kept only in
  `replay-submissions/validated/...` with a short lifecycle TTL
- only Top 10 entries get a durable promoted ghost object under `ghosts/...`
- top10 exposure is derived after validation and ranking; it is never a client
  upload-time decision

## Security and IAM

The replay pipeline spans multiple trust boundaries. The plan needs explicit
service-to-service access rules.

Required rules:

- clients authenticate through Firebase Auth only
- callable or HTTP endpoints in `functions/src/**` are the only client-facing
  control plane for run issuance, finalize, status, and leaderboard reads
- Cloud Storage upload grants must be:
  - scoped to one `runSessionId`
  - scoped to one object path
  - short-lived (default: 15 minutes)
  - size-bounded (default: 8 MiB max object size)
  - content-type constrained where possible
- the validator service must be private and invokable only by Cloud Tasks or an
  internal service account
- Cloud Tasks must use a dedicated service account with least-privilege
  invocation rights
- the validator service account must have only the minimum required access to:
  - read replay blobs
  - write validated run and leaderboard projection docs
  - write reward grants
  - update ghost publication artifacts
- raw replay blobs and validated run documents must not be writable by clients
  through Firestore or Storage rules
- admin board-management actions must use separate privileged credentials from
  the normal runtime path

Operationally, define:

- one service account for Functions control-plane writes
- one service account for Cloud Tasks dispatch
- one service account for the validator runtime
- one admin-only path for board management and support tooling

Concrete baseline for Firebase/GCP project `rpg-runner-d7add`:

- Functions control-plane runtime service account:
  - `sa-run-control@rpg-runner-d7add.iam.gserviceaccount.com`
- Cloud Tasks dispatch service account:
  - `sa-replay-task-dispatch@rpg-runner-d7add.iam.gserviceaccount.com`
- Replay validator runtime service account:
  - `sa-replay-validator@rpg-runner-d7add.iam.gserviceaccount.com`
- Board/admin operator principal:
  - `group:rpg-runner-board-admins@<your-domain>`
  - if group IAM is not available, use a dedicated admin service account and keep
    it out of app runtime paths

Concrete IAM bindings:

- Bind `sa-run-control` to:
  - `roles/datastore.user` (project)
  - `roles/cloudtasks.enqueuer` (on queue `replay-validation`)
  - `roles/iam.serviceAccountTokenCreator` on
    `sa-run-control@rpg-runner-d7add.iam.gserviceaccount.com` (required for V4
    signed upload grants)
- Bind `sa-replay-task-dispatch` to:
  - `roles/run.invoker` on Cloud Run service `replay-validator`
- Bind `sa-replay-validator` to:
  - `roles/datastore.user` (project)
  - Storage access on replay bucket with IAM Conditions scoped to object prefixes:
    - read pending/validated replay blobs:
      `resource.name.startsWith("projects/_/buckets/<replay-bucket>/objects/replay-submissions/")`
    - write/update/delete ghost artifacts:
      `resource.name.startsWith("projects/_/buckets/<replay-bucket>/objects/ghosts/")`
- Bind board admin principal to:
  - board management callable/HTTP endpoints only
  - no direct privilege to validator runtime execution

Manual operator actions and timing:

- Before Phase 3 implementation starts (required):
  - create the three service accounts above
  - apply the IAM bindings above
  - deploy Functions with runtime service account = `sa-run-control`
- Before Phase 4 validation pipeline testing starts (required):
  - create Cloud Tasks queue `replay-validation`
  - deploy private Cloud Run service `replay-validator` with runtime service
    account = `sa-replay-validator`
  - configure queue HTTP task OIDC token service account =
    `sa-replay-task-dispatch`
  - verify Cloud Tasks -> Cloud Run invocation succeeds with no public ingress
- Before any board publishing tooling is enabled (required):
  - create/configure `rpg-runner-board-admins` principal
  - lock board management APIs to that principal only

If any required operator action is incomplete, the corresponding phase is blocked
and should not proceed.

## Safe Numeric Defaults (v1)

Use these defaults for first production rollout unless metrics force tuning:

- replay upload max size: `8 MiB` per run (`8,388,608` bytes)
- upload grant TTL: `15 minutes`
- run session expiry (`RunTicket.expiresAtMs`): `24 hours` from issuance
- validator retry budget: `8` attempts
- validator retry backoff: `30s, 2m, 5m, 15m, 30m, 1h, 2h, 4h`
- UI `verification delayed` threshold: `5 minutes` after finalize enqueue
- player exact-rank cache TTL: `60 seconds`
- stale pending upload cutoff: `48 hours`
- non-Top-10 validated replay blob retention: `30 days`
- demoted ghost artifact grace retention: `7 days`
- `run_sessions` retention after terminal state: `90 days`
- `validated_runs` retention: `365 days`
- `reward_grants` retention after apply/audit: `365 days`

## Retention and Account Deletion

Replay data is product data and user data. Retention cannot stay implicit.

Required policies:

- `run_sessions`
  - keep through terminal resolution plus audit window
  - default retention: `90 days` after terminal state
- `validated_runs`
  - retain long enough for support, disputes, and leaderboard integrity review
  - default retention: `365 days`
- `replay-submissions/pending/...`
  - short TTL; delete unfinished uploads aggressively
  - default stale-upload TTL: `48 hours`
- `replay-submissions/validated/...`
  - short TTL for non-Top-10 accepted runs
  - default TTL: `30 days`
- `ghosts/...`
  - retain while the ghost is exposed, plus a controlled demotion/grace window
  - default demotion grace: `7 days`
- `leaderboard_boards/{boardId}/views/top10`
  - derived cache; safe to rebuild
- `reward_grants`
  - retain applied and unapplied grant audit trail
  - default retention: `365 days`

Account deletion requirements:

- deleting an account must explicitly cover:
  - run session docs owned by that user
  - validated run audit docs owned by that user
  - pending and validated replay blobs owned by that user
  - promoted ghost assets owned by that user when policy requires removal
  - leaderboard player-best projections owned by that user
- if leaderboard policy requires historical public entries to persist after
  deletion, that exception must be documented explicitly and not inferred later
- ownership reward grants must not survive in an orphaned state after account
  deletion

Support a scheduled cleanup job for:

- expired sessions
- stale pending uploads
- validated replay blobs past TTL
- ghost artifacts for demoted entries past retention

Recommended cleanup cadence:

- mark `issued` sessions as `expired` when now - `issuedAtMs` > `24 hours`
- run cleanup every `1 hour`

## Client Refactor Plan

### Replace direct run-start argument building

Current:

- `AppState.buildRunStartArgs()` is synchronous and random-seeded

Target:

- replace it with `prepareRunStartDescriptor()`
- for Practice:
  - require network + auth before start
  - request a server-issued run session with a server-issued random seed
- for Competitive/Weekly:
  - require network + auth before start
  - ensure ownership/loadout state is synced
  - load active board metadata
  - request a board-bound run ticket
  - return a descriptor that includes `RunTicket`, optional board manifest, and
    local replay capture settings

### Introduce a run submission coordinator

Add in `lib/ui/state/`:

- `run_boards_api.dart`
- `firebase_run_boards_api.dart`
- `run_session_api.dart`
- `firebase_run_session_api.dart`
- `run_submission_coordinator.dart`
- `run_submission_spool_store.dart`
- `pending_run_submission.dart`
- `run_submission_status.dart`

Responsibilities:

- own run-start connectivity/auth preflight
- own run session issuance
- own replay upload/finalize retry logic
- persist pending submissions across process death
- surface per-run status to Game Over UI and leaderboards

### Replace the gold-award path

Remove client reward trust from:

- `lib/ui/runner_game_widget.dart`
- `lib/ui/state/app_state.dart`
- `AwardRunGoldCommand` call sites for all validated modes

New behavior:

- local run end shows provisional score only
- server validation issues a `reward_grant`
- app refreshes canonical progression after validation success

### Split leaderboard storage by authority

Replace the current single `LeaderboardStore` abstraction with:

- `PracticeLeaderboardStore`
  - current SharedPreferences-based PB storage
- `OnlineLeaderboardApi`
  - load board top10
  - load my best/rank
  - load submission status
  - load ghost manifest/download info

Do not keep local Competitive storage as a shadow authority.

### Record the replay from applied commands

Refactor `lib/game/game_controller.dart` so the command frames actually applied to
`GameCore` can be observed by a recorder.

Recommended shape:

- add a `TickCommandObserver`
- emit one immutable applied frame per stepped tick
- recorder writes frames incrementally to a spool file and streaming digest

Do not record raw pointer deltas or widget-level gesture events.

### Move command quantization into one explicit policy

Centralize any analog input quantization used by replay protocol in one shared
module. Live play and replay recording must use the same quantization rules.

Do not leave:

- UI gesture floats in one place
- router quantization in another
- replay serialization quantization in a third

## Backend Refactor Plan

### Firebase Functions remains the auth and query edge

Add new function domains:

```text
functions/
  src/
    boards/
    runs/
    leaderboards/
    ghosts/
```

Callable/API surface:

- `runBoardsLoadActive`
- `runSessionCreate`
- `runSessionCreateUploadGrant`
- `runSessionFinalizeUpload`
- `runSessionLoadStatus`
- `leaderboardLoadBoard`
- `leaderboardLoadMyRank`
- `ghostLoadManifest`

### Keep ownership authority in the ownership domain

Do not let the validator write gold directly into ownership canonical docs.

Instead:

- validator writes `reward_grants/{runSessionId}`
- ownership load/mutate flows reconcile unapplied grants transactionally before
  returning canonical state

Benefits:

- ownership source of truth remains `ownership_profiles`
- validator does not duplicate revision/idempotency rules
- reward application stays idempotent and auditable

### Validator service is the replay authority

The validator owns:

- replay decode
- protocol sanity validation
- deterministic replay execution
- validated run persistence
- player-best entry projection
- top10 snapshot refresh
- ghost promotion/demotion
- reward grant issuance

It does not own:

- Firebase user auth
- client session bootstrap
- widget-facing request/response shaping

## Run Ticket Flow

### Online start

1. Client verifies network + auth.
2. Client ensures ownership/loadout edits are flushed.
3. If mode is Competitive/Weekly, client loads active `BoardManifest`.
4. Client requests `runSessionCreate`.
5. Backend validates:
   - auth
   - mode-specific requirements
   - canonical ownership state can produce an authoritative start snapshot
   - active board + `gameCompatVersion` for Competitive/Weekly
6. Backend creates `run_sessions/{runSessionId}` in `issued` state.
7. Backend returns `RunTicket` only.

### Offline start

Not supported in the production model.

Rules:

- if network or auth is unavailable, run start is disabled
- if Competitive/Weekly board metadata cannot be verified live, run start is
  disabled
- replay submission may still complete later if connectivity drops after a run
  has already started

## Replay Capture and Upload Flow

1. Run starts with `RunTicket`.
2. `RunRecorder` streams applied tick command frames to a local spool file.
3. On run end:
   - finalize replay blob
   - compute canonical digest
   - write `PendingRunSubmission` record locally
4. Background coordinator calls `runSessionCreateUploadGrant`.
5. Backend returns a short-lived signed upload grant for that run session path.
6. Background coordinator uploads blob to the granted storage path.
7. Client calls `runSessionFinalizeUpload` with:
   - `runSessionId`
   - uploaded blob metadata
   - digest
   - provisional local summary
8. Backend records upload metadata, transitions to `pending_validation`, and
   enqueues a task.

Requirements:

- upload/finalize flow must be idempotent
- replay bytes are never sent through a callable payload
- spool files survive app kill until server acknowledges terminal state

## Validation Worker Algorithm

For each queued `runSessionId`:

1. Acquire an idempotent lease on `run_sessions/{runSessionId}`.
2. Load the run session and replay blob metadata.
   - If mode is Competitive/Weekly, also load the board manifest.
3. Download the replay blob and verify:
   - byte size bounds
   - gzip/container integrity
   - canonical digest
4. Decode `ReplayBlobV1`.
5. Validate protocol constraints:
   - monotonic ticks
   - in-range quantized values
   - no invalid command tags
   - no duplicate illegal transitions within a tick
   - ticket/header mismatch rejection
   - board mismatch rejection for Competitive/Weekly
6. Instantiate `runner_core.GameCore` with:
   - seed from the issued run ticket
   - level definition
   - character id
   - loadout snapshot from ticket
7. Apply recorded frames tick-by-tick until completion.
8. Build canonical result from replayed Core output only.
9. Persist `validated_runs/{runSessionId}`.
10. If accepted:
    - issue `reward_grants/{runSessionId}`
    - if mode is Competitive/Weekly:
      - update `player_bests/{uid}` if this run improves the board best
      - refresh `views/top10`
      - if the resulting entry is Top 10:
        - promote the verified replay to `ghosts/{boardId}/{entryId}/...`
        - publish ghost eligibility on the top10 projection
      - if the resulting entry is not Top 10:
        - keep the accepted replay only in short-retention validated storage
        - ensure no durable ghost exposure is published
11. Mark `run_sessions/{runSessionId}` terminal:
    - `validated`
    - `rejected`
    - `internal_error`

The worker must be safe to retry on the same run session without double rewards,
double promotions, or duplicate entries.

## Leaderboard Publication Model

### Store every run, rank only player bests

Persist:

- `validated_runs/{runSessionId}` for audit and replay retention in every mode
- `player_bests/{uid}` for Competitive/Weekly ranking only

Rules:

- Practice writes no leaderboard projection
- if a new Competitive/Weekly validated run is not better than the existing
  best, keep the audit record but do not change leaderboard projections
- if it is better, replace the player's best entry and recompute top10 snapshot

### Materialize top10

Maintain a lightweight board view document:

```text
leaderboard_boards/{boardId}/views/top10
```

Contents:

- top 10 rows
- ghost availability per row
- refreshed timestamp

This keeps leaderboard browsing fast and avoids rebuilding top10 on every client
request.

### Exact player rank

For the signed-in player:

- load `player_bests/{uid}`
- if present, compute exact rank from `sortKey`
- cache the rank result with a short TTL if needed (default: `60 seconds`)

Do not fake rank from top10-only data.

## Ghost Publication Model

Do not treat ghost storage as a separate client feature bolted on later.

Rules:

- every Competitive/Weekly submission uploads a replay blob because Top 10
  status is unknowable before validation
- accepted replays are validation artifacts first, ghost candidates second
- only Top 10 entries expose a ghost manifest to clients
- only Top 10 entries get a durable promoted ghost object under `ghosts/...`
- non-Top-10 accepted replays stay in validated storage with a short TTL, then
  expire automatically
- ghost payload references the already verified replay blob lineage, not a
  second client-supplied upload
- when top10 changes:
  - update the top10 snapshot
  - promote new Top 10 entries into durable ghost storage
  - revoke ghost exposure for demoted entries
  - keep or delete demoted validated replay blobs based on retention policy, not
    on client behavior

This avoids a second ingestion pipeline for ghosts.

## UI and UX Rules

### Game Over

Game Over for any reward-bearing mode must show:

1. local provisional result
2. submission state:
   - uploading
   - queued
   - validating
   - validated
   - rejected
   - retrying
3. validated outcome:
   - final gold granted
   - final rank / top10 status for Competitive/Weekly
   - ghost saved / not saved for Top 10 Competitive/Weekly entries

Do not present local score as a confirmed online result.

### Leaving the run screen

The user must be free to leave the Game Over screen while submission continues.

Requirements:

- submission state survives route exit
- hub/profile/leaderboard pages can reflect pending and recently validated runs
- progress refresh happens when a reward grant is observed as applied

### Failure and Recovery UX

The product needs explicit behavior when the happy path does not complete
quickly.

Required states:

- `upload pending`
- `upload failed, retrying`
- `waiting for verification`
- `verification delayed`
- `verification failed`
- `reward granted`

Rules:

- leaving the Game Over screen must never cancel an already-issued submission
- if upload fails transiently, the app retries automatically and shows a
  non-blocking pending state
- if validation is delayed beyond a product threshold (default: `5 minutes` from
  finalize enqueue), the UI must say so explicitly instead of looking stuck
- if validation reaches terminal rejection, the UI must show that gold was not
  granted
- if reward grant application lags behind validation success, the UI must show
  a separate pending reward state rather than silently dropping the result
- support and telemetry need a stable `runSessionId` surfaced in logs and, if
  needed later, in player-visible support copy

### Compat gating

Run start is network-gated for all modes.

If run start prerequisites cannot be verified:

- all starts are disabled when network/auth is unavailable
- Competitive/Weekly are additionally disabled when active board metadata or
  `gameCompatVersion` cannot be verified live

## Direct Replacement Plan

Do not leave parallel legacy authority paths behind.

When the validated run system cuts over:

- remove local gold authority in every mode
- remove local Competitive leaderboard writes
- stop using local `RunEndedEvent.goldEarned` as reward authority
- stop generating Practice reward-bearing seeds locally
- stop generating Competitive/Weekly seeds locally
- stop treating timestamp-derived `runId` as a backend-grade identifier

Practice can keep its local PB display, but all starts fail closed without live
network/auth/session issuance.

## Likely File Impact

### Existing Flutter files to refactor

- `lib/ui/state/app_state.dart`
- `lib/ui/state/selection_state.dart`
- `lib/ui/app/ui_routes.dart`
- `lib/ui/app/ui_router.dart`
- `lib/ui/runner_game_widget.dart`
- `lib/game/game_controller.dart`
- `lib/game/input/runner_input_router.dart`
- `lib/ui/leaderboard/leaderboard_store.dart`
- `lib/ui/leaderboard/shared_prefs_leaderboard_store.dart`
- `lib/ui/hud/gameover/leaderboard_panel.dart`
- `lib/ui/pages/leaderboards/leaderboards_page.dart`

### Existing backend files to refactor

- `functions/src/index.ts`
- `functions/src/ownership/**`
- `functions/src/account/delete.ts`
- `functions/test/account/account_delete_callable.test.ts`

### New top-level areas

- `packages/runner_core/**`
- `packages/run_protocol/**`
- `services/replay_validator/**`

## Delivery Plan

### Phase 1: Package extraction and deterministic replay harness

- validate `packages/runner_core` package extraction and remove any legacy
  in-app Core tree remnants
- update app imports to use the new package
- add replay-focused determinism tests around the extracted core
- add `run_protocol` package skeleton

Exit gate:

- app still runs
- extracted core tests pass
- validator package can instantiate and step `GameCore` headlessly

### Phase 2: Replay protocol and recorder

- define `ReplayBlobV1`
- add applied-command observer in `GameController`
- implement file-backed `RunRecorder`
- add round-trip encode/decode tests and long-run determinism tests

Exit gate:

- same seed + same recorded replay reproduces the same canonical result locally

### Phase 3: Board service and run ticket issuance

- add online run-session issuance for all modes
- add board metadata backend for Competitive/Weekly
- lock Competitive season cadence to one UTC calendar month per `seasonMonthId`
- refactor `RunType` to `RunMode`
- replace local reward-bearing seed issuance with server-issued run sessions

Exit gate:

- no mode can start without live network/auth/session issuance
- Competitive/Weekly also require valid active board metadata
- Competitive window identity resolves to the current UTC calendar month

### Phase 4: Submission pipeline and validator service

- add signed upload grant flow
- add pending submission spool and retry logic
- add validator worker and task queue
- add validated run persistence and reward grant writing

Exit gate:

- a submitted replay is validated end-to-end and produces a terminal status

### Phase 5: Leaderboard and reward cutover

- add player-best projection and top10 materialization
- add online leaderboard read API
- remove client-authoritative reward application for all modes
- remove local Competitive leaderboard writes

Exit gate:

- gold in every mode comes only from validated runs
- Competitive/Weekly leaderboard and ghosts come only from validated runs

### Phase 6: Ghost publication and playback

- promote verified replays to ghost manifests for top10 entries
- add ghost fetch/cache flow
- add deterministic ghost playback against validated replay blobs

Exit gate:

- top10 ghost selection launches a deterministic ghost race using verified data

### Phase 7: Weekly mode activation

- add Weekly as a real run mode in selection, board, leaderboard, and run prep
- add week rollover handling and weekly achievement hooks

Exit gate:

- Weekly uses the same validated run pipeline with its own board key/window

## Test Matrix

### Core and protocol

- replay encode/decode round trip preserves canonical bytes
- same replay blob reproduces identical result on two fresh cores
- invalid command ordering/range is rejected
- quantization policy is stable for identical user inputs

### Flutter client

- run prep blocks Competitive/Weekly without valid board/ticket
- pending submission survives app restart
- upload finalize retry keeps same `runSessionId`
- Game Over status updates correctly from provisional to validated/rejected
- ownership refresh applies reward grants after validation

### Functions

- board load gates by compat and active window
- Competitive board load resolves the current UTC calendar month window
- weekly board load resolves the current weekly window id
- run ticket issuance enforces auth and board state
- run ticket issuance derives the start snapshot from canonical ownership state
- finalize upload rejects reused or expired tickets
- illegal run-session state transitions are rejected
- leaderboard read endpoints return top10 + player best cleanly

### Validator service

- valid replay yields expected canonical result
- bad digest rejects cleanly
- duplicate task retry does not double-publish reward or leaderboard state
- lower-than-best run does not replace player best
- improved run replaces player best and refreshes top10
- Practice validation grants reward without creating leaderboard projections

### End-to-end

- Competitive happy path:
  - start with ticket
  - play locally
  - upload replay
  - validate
  - reward grant appears
  - leaderboard updates
- rejection path:
  - malformed replay
  - status moves to rejected
  - no reward
  - no leaderboard entry
- expiry path:
  - issued run never finalizes
  - session expires
  - no reward
  - no leaderboard or ghost artifacts
- account deletion path:
  - replay artifacts and projections are deleted or handled per retention policy
  - no orphaned reward grants remain

## Operational Metrics

Track at minimum:

- replay blob size p50/p95
- upload success rate
- finalize success rate
- validation latency p50/p95/p99
- accepted vs rejected runs
- rejection reason distribution
- duplicate task / idempotency replay count
- top10 refresh latency
- reward grant apply latency
- ghost fetch rate and cache hit rate
- expired-session cleanup count
- stale-upload cleanup count

Alert on:

- spike in digest mismatch
- spike in protocol rejection
- validator backlog growth
- reward grants pending too long
- abnormal rate of expired issued sessions

## Acceptance Criteria

- No mode trusts client-local end-of-run authority for gold rewards.
- Run start requires live network/auth/session issuance.
- Replay validation runs in a separate headless Dart service that depends on a
  pure Dart core package, not on Flutter UI code.
- Clients record canonical applied command streams and upload durable replay
  blobs instead of posting ad-hoc summary stats.
- Board/ticket/version contracts are explicit, modular, and shared across app
  and validator layers.
- Practice remains unranked and ghost-free, but still uses validated reward
  authority.
- Online leaderboards rank server-side player-best entries with deterministic
  sorting and exact rank support.
- Top 10 ghost availability is derived from verified replay data, not from a
  second trust path.
- Practice PB remains local and isolated from online authority.
- The old local gold-award path and local Competitive leaderboard path are
  removed.

## Recommended Implementation Order

Start with the extraction and replay protocol before touching leaderboards.
If the replay format and validator boundary are not stable first, every later
layer will churn.

Order:

1. `runner_core` extraction
2. `run_protocol` and recorder
3. board/ticket contracts
4. validator service
5. reward grants + leaderboard projection
6. UI cutover
7. ghost publishing and Weekly activation

## Summary

The right production architecture for this repo is not a live server session.
It is a local deterministic game client with:

- server-issued board/ticket authority
- canonical replay capture
- asynchronous durable submission
- headless validator replay
- server-owned reward grants
- server-owned leaderboard and ghost publication

That architecture keeps the game responsive, matches the existing deterministic
core investment, and gives the repo a clean path to real Competitive fairness
without coupling gameplay feel to network latency.
