# Replay Validation Implementation Checklist

Date: March 12, 2026  
Status: In progress (Phases 1-6 complete, Phase 7 in progress)  
Source plan: `docs/building/replayValidation/replay-validation-plan.md`

## Goal

Turn the replay-validation production plan into an execution checklist with:

- phase-locked delivery order
- concrete file/package targets
- explicit done criteria per phase
- cross-layer validation and release gates

## Delivery Assumptions

- Current Competitive leaderboard state is local-only and non-authoritative, so
      no production leaderboard data conversion is required.
- Existing local Practice PB data can remain local and isolated from online
  authority.
- Firebase Auth/Functions/Firestore/Storage are available in the same project as
  Cloud Run and Cloud Tasks.
- This rollout can introduce new packages/services in the same mono-repo without
  splitting repositories.

If any assumption is false, update this checklist before implementation begins.

## Locked Phase Order

Implementation order is locked:

1. `runner_core` extraction
2. replay protocol + recorder
3. board/ticket contracts + run start authority
4. submission pipeline + validator worker
5. reward/leaderboard authority cutover
6. ghost publication + playback
7. weekly mode activation

Do not start a later phase before the previous phase exit gate is met.

## Pre-Phase Setup

Objective:

- establish shared conventions so phase work does not diverge by layer

Tasks:

- [x] Confirm canonical naming and literals for:
      - `RunMode`: `practice|competitive|weekly`
      - board statuses: `scheduled|active|closed|disabled`
      - run-session states: `issued|uploading|uploaded|pending_validation|validating|validated|rejected|expired|cancelled|internal_error`
- [x] Lock window cadence and ids:
      - Competitive season window = one UTC calendar month
      - Competitive `windowId` format = `YYYY-MM` (for example `2026-03`)
      - Weekly window = one week with unique `weekId`
- [x] Confirm environment ownership:
      - Functions control-plane service account
      - Cloud Tasks dispatch service account
      - validator runtime service account
- [x] [YOU - REQUIRED BEFORE PHASE 3] Create service accounts in
      `rpg-runner-d7add`:
      - `sa-run-control@rpg-runner-d7add.iam.gserviceaccount.com`
      - `sa-replay-task-dispatch@rpg-runner-d7add.iam.gserviceaccount.com`
      - `sa-replay-validator@rpg-runner-d7add.iam.gserviceaccount.com`
- [x] [YOU - REQUIRED BEFORE PHASE 3] Apply IAM bindings:
      - [x] `sa-run-control`:
        - `roles/datastore.user` (project)
        - `roles/cloudtasks.enqueuer` (queue `replay-validation`)
        - `roles/iam.serviceAccountTokenCreator` on itself
      - [x] `sa-replay-task-dispatch`:
        - `roles/run.invoker` on Cloud Run `replay-validator`
      - [x] `sa-replay-validator`:
        - `roles/datastore.user` (project)
        - Storage IAM Conditions for:
          - read `replay-submissions/**`
          - write/delete `ghosts/**`
- [x] [YOU - REQUIRED BEFORE PHASE 3] Deploy Functions runtime with service
      account `sa-run-control`.
- [x] [YOU - REQUIRED BEFORE PHASE 4 TESTING] Provision execution surfaces:
      - [x] create Cloud Tasks queue `replay-validation`
      - [x] deploy private Cloud Run service `replay-validator`
            using service account `sa-replay-validator`
      - [x] configure queue OIDC service account `sa-replay-task-dispatch`
- [ ] [YOU - REQUIRED BEFORE BOARD TOOLING ENABLEMENT] Create admin principal:
      - `group:rpg-runner-board-admins@<your-domain>`
      - restrict board-management endpoints to this principal only
- [x] Define initial operational defaults:
      - replay upload max size = `8 MiB` (`8,388,608` bytes)
      - upload grant TTL = `15 minutes`
      - run session expiry (`RunTicket.expiresAtMs`) = `24 hours`
      - validator retry budget = `8 attempts`
      - validator retry backoff = `30s,2m,5m,15m,30m,1h,2h,4h`
      - UI `verification delayed` threshold = `5 minutes`
      - player rank cache TTL = `60 seconds`
      - stale pending upload cutoff = `48 hours`
      - non-Top-10 validated replay blob TTL = `15 days`
      - demoted ghost artifact grace retention = `7 days`
      - `run_sessions` retention after terminal = `90 days`
      - `validated_runs` retention = `365 days`
      - `reward_grants` retention = `365 days`
- [ ] Create a single implementation tracker issue/epic with one child issue per
      phase and link this checklist.

Done when:

- naming, state machine, and runtime assumptions are frozen for Phase 1-2 work
- required IAM/service-account/operator setup for Phase 3 and Phase 4 is complete

## Phase 1: Extract Deterministic Core To `packages/runner_core`

Objective:

- make deterministic gameplay headless and reusable by a server validator

Tasks:

- [x] Create package scaffold:
      - `packages/runner_core/pubspec.yaml`
      - `packages/runner_core/lib/runner_core.dart`
      - `packages/runner_core/lib/**`
      - `packages/runner_core/test/**`
- [x] Remove previous in-app Core source tree after move to
      `packages/runner_core`.
- [x] Export public core surface from `package:runner_core/runner_core.dart`.
- [x] Update Flutter app imports from previous Core paths to
      `package:runner_core/**` in:
      - `lib/game/**`
      - `lib/ui/**`
      - `test/**`
- [x] Update root package wiring so app resolves local path dependency to
      `packages/runner_core`.
- [x] Enforce pure Dart boundaries:
      - no Flutter imports
      - no Flame imports
- [x] Add/port deterministic tests in `packages/runner_core/test/**` for:
      - same seed -> same canonical outcome
      - stable score/distance/duration/tick behavior
- [x] Add a headless smoke test that instantiates and ticks `GameCore` without
      Flutter bootstrapping.

Done when:

- app compiles and runs against `package:runner_core`
- `runner_core` is Flutter-free and Flame-free
- deterministic tests pass in the new package

## Phase 2: Build `packages/run_protocol` And Replay Recorder

Objective:

- lock shared contracts and produce canonical replay capture bytes on client

Tasks:

- [x] Create protocol package scaffold:
      - `packages/run_protocol/pubspec.yaml`
      - `packages/run_protocol/lib/**`
      - `packages/run_protocol/test/**`
- [x] Implement protocol DTOs and enums:
      - `run_mode.dart`
      - `board_key.dart`
      - `board_manifest.dart`
      - `run_ticket.dart`
      - `replay_blob.dart`
      - `replay_digest.dart`
      - `validated_run.dart`
      - `leaderboard_entry.dart`
      - `submission_status.dart`
- [x] Encode practice-mode boardless invariants in schema:
      - `ReplayBlobV1.boardId/boardKey` optional
      - `ValidatedRun.boardId/boardKey` optional
      - required for Competitive/Weekly only
- [x] Implement canonical sort-key builder utility shared by backend and
      validator.
- [x] Implement stable codec and digest rules in `lib/codecs/**`.
- [x] Add protocol tests:
      - encode/decode round-trip
      - canonical digest determinism
      - invalid payload rejection
- [x] Add applied-command observer to `lib/game/game_controller.dart`:
      - immutable frame per stepped tick
      - no raw gesture/pointer recording
- [x] Implement file-backed recorder pipeline:
      - streaming frame write
      - streaming digest
      - finalize into replay blob
- [x] Centralize replay quantization policy in one shared module and ensure
      runtime play + replay capture use identical rules.
- [x] Add long-run replay reproducibility tests:
      - replay bytes reproduced from same command stream
      - replayed result equals live canonical result

Done when:

- replay contract is frozen in `run_protocol`
- client can produce canonical replay blobs from applied commands
- deterministic replay round-trip tests pass

## Phase 3: Board Metadata + Run Ticket Authority

Objective:

- remove client-authoritative run start for all modes and enforce online issuance

Tasks:

- [x] Refactor run mode domain in Flutter:
      - replace `RunType` with `RunMode` in `lib/ui/state/selection_state.dart`
      - update run setup/hub/routes/args/UI labels
- [x] Introduce run-start descriptor flow in `lib/ui/state/app_state.dart`:
      - replace `buildRunStartArgs()` with async `prepareRunStartDescriptor()`
      - require live auth and connectivity for all modes
- [x] Add backend domains and callable exports:
      - `functions/src/boards/**`
      - `functions/src/runs/**`
      - updates in `functions/src/index.ts`
- [x] Implement board load callable:
      - active board resolution
      - `gameCompatVersion` gating
      - board status handling (`disabled` blocks issuance)
- [x] Implement Competitive window rules:
      - resolve current UTC month window id (`YYYY-MM`)
      - enforce month-boundary open/close timestamps
      - prevent overlapping active Competitive boards per level/month window
- [x] Implement `runSessionCreate`:
      - derive authoritative start snapshot from canonical ownership state
      - bind ticket to uid/mode/loadout snapshot
      - board-bound for Competitive/Weekly
      - create `run_sessions/{runSessionId}` in `issued`
- [x] Update client run-prep adapters in `lib/ui/state/**` for board/ticket APIs.
- [x] Remove local reward-bearing seed authority and local timestamp `runId`
      authority for submittable runs.
      - `RunnerGameWidget` now requires non-empty `runSessionId`, `runId > 0`,
        and `seed > 0` (no local fallback issuance path)
      - `createRunnerGameRoute` now requires server-issued
        `runSessionId/runId/seed` and rejects fallback values
- [x] Ensure starts fail closed without network/auth/session issuance.
      - hub start path is fail-closed via board/ticket callables
      - in-run restart now requests a fresh server run session/ticket (no local
        restart issuance fallback)
- [x] Add tests:
      - mode gating and board compat checks
      - Competitive month-window resolution and month rollover behavior
      - server-derived snapshot mismatch rejection
      - ticket issuance auth/user checks
      - implemented in:
        - `functions/test/runs/run_session_callable.test.ts`
        - `functions/test/runs/run_callables_auth_gating.test.ts`

Done when:

- no run mode can start without server-issued session authority
- Competitive/Weekly starts are board-bound and compat-gated
- client-local seed/run-id authority is removed for reward-bearing runs

## Phase 4: Submission Pipeline + Validator Service

Objective:

- deliver durable upload/finalize/validate pipeline with idempotent retries

Tasks:

- [x] Implement run submission client components in `lib/ui/state/**`:
      - `run_boards_api.dart`
      - `firebase_run_boards_api.dart`
      - `run_session_api.dart`
      - `firebase_run_session_api.dart`
      - `run_submission_coordinator.dart`
      - `run_submission_spool_store.dart`
      - `pending_run_submission.dart`
      - `run_submission_status.dart`
- [x] Implement callable/API surface in backend:
      - `runSessionCreateUploadGrant`
      - `runSessionFinalizeUpload`
      - `runSessionLoadStatus`
      - runtime config requirements:
        - `REPLAY_STORAGE_BUCKET` (required)
        - `REPLAY_VALIDATOR_TASK_URL` or `REPLAY_VALIDATOR_URL` (required)
        - `REPLAY_VALIDATION_QUEUE_LOCATION` (optional, default `europe-west1`)
        - `REPLAY_VALIDATION_QUEUE_NAME` (optional, default `replay-validation`)
- [x] Enforce upload grant constraints:
      - single run-session path
      - short-lived signed grant
      - size bounds
      - content-type constraints
- [x] Implement run-session state transitions and legal-transition checks:
      - `issued -> uploading -> uploaded -> pending_validation -> validating -> terminal`
      - idempotent finalize for same metadata
      - conflict rejection for mismatched re-finalize
- [x] Add Cloud Tasks enqueue path from finalize.
- [x] Create validator service package:
      - `services/replay_validator/pubspec.yaml`
      - `services/replay_validator/bin/server.dart`
      - `services/replay_validator/lib/src/**`
      - `services/replay_validator/test/**`
- [x] Implement worker algorithm:
      - lease acquire/release
      - blob fetch + digest verification
      - protocol sanity checks
      - headless core replay
      - validated run persistence
      - terminal session update
- [x] Implement retry/backoff and exhausted-retry terminalization
      (`internal_error`).
- [x] Add cleanup jobs for:
      - expired sessions
      - stale pending uploads
- [x] Add metrics/log dimensions (runSessionId-centric traceability).
- [x] Add tests:
      - duplicate task idempotency
      - bad digest/protocol rejection
      - enqueue retry safety
      - pending submission survives app restart
      - implemented in this pass:
        - `functions/test/runs/run_submission_callable.test.ts`
        - `functions/test/runs/run_cleanup.test.ts`
        - `services/replay_validator/test/validator_worker_test.dart`
        - `test/ui/state/run_submission_coordinator_test.dart`
        - `test/ui/state/run_submission_spool_store_test.dart`
        - `test/ui/state/app_state_run_submission_test.dart`

Done when:

- replay submission works end-to-end from client spool to terminal status
- validator can replay and decide deterministically without duplicate side effects
- pipeline is retry-safe and operationally observable

## Phase 5: Reward + Leaderboard Authority Cutover

Objective:

- move rewards and ranking to server-validated authority for all relevant modes

Tasks:

- [x] Implement validated run storage and projection updates:
      - `validated_runs/{runSessionId}`
      - `leaderboard_boards/{boardId}/player_bests/{uid}`
      - `leaderboard_boards/{boardId}/views/top10`
      - implemented via validator-side Firestore projection:
        - `services/replay_validator/lib/src/run_session_repository.dart`
        - `services/replay_validator/lib/src/leaderboard_projector.dart`
- [x] Implement reward grant writing:
      - `reward_grants/{runSessionId}`
      - no direct ownership canonical writes from validator
- [x] Update ownership flows (`functions/src/ownership/**`) to reconcile unapplied
      grants transactionally.
      - load + execute ownership transactions reconcile pending grants and mark
            `reward_grants/*` as `validated_settled` when verification is accepted
- [x] Add leaderboard read APIs:
      - `leaderboardLoadBoard`
      - `leaderboardLoadMyRank`
- [x] Implement exact-rank query path from canonical `sortKey`.
- [x] Remove client-authoritative reward path:
      - `RunnerGameWidget` no longer calls `AppState.awardRunGold(...)`
      - stop trusting `RunEndedEvent.goldEarned` for authority
- [x] Remove local Competitive leaderboard authority:
      - no writes to `shared_prefs_leaderboard_store.dart` for Competitive
- [x] Preserve Practice local PB display as local-only (not online authority).
- [x] Update Game Over and leaderboard UI to show provisional/submission/validated
      states clearly.
- [x] Add tests:
      - [x] reward grant idempotency
      - [x] lower-than-best run does not replace best
      - [x] improved run updates best + top10
      - [x] Practice validated rewards with no leaderboard projection
      - implemented in:
        - `functions/test/ownership/ownership_callable.test.ts`
        - `functions/test/leaderboards/leaderboard_callable.test.ts`
        - `services/replay_validator/test/validator_worker_test.dart`
        - `services/replay_validator/test/leaderboard_projector_test.dart`

Done when:

- gold in all modes comes from validated results only
- Competitive/Weekly leaderboard authority is server-side only
- old local gold and local Competitive ranking authority paths are removed

## Phase 6: Ghost Publication + Deterministic Playback

Objective:

- expose ghosts only from verified top10 replay lineage

Tasks:

- [x] Implement ghost promotion flow on accepted Competitive/Weekly runs that are
      top10:
      - promote verified replay lineage to `ghosts/{boardId}/{entryId}/...`
- [x] Implement demotion handling:
      - revoke ghost exposure when entry falls out of top10
      - retain/delete artifacts by retention policy
- [x] Implement ghost read surface:
      - `ghostLoadManifest` backend endpoint
      - client manifest/download API
- [x] Implement client ghost cache and replay bootstrapping from verified payload.
      - `lib/ui/state/ghost_replay_cache.dart` verifies replay digest +
        manifest binding before caching/bootstrapping
- [x] Implement deterministic ghost playback integration in run experience.
      - `RunnerGameWidget` now advances an optional verified ghost replay in
        lockstep and surfaces ghost status in-run
- [x] Ensure non-top10 accepted replays remain validation artifacts only with TTL.
      - cleanup now deletes stale `replay-submissions/validated/*` artifacts
        only when they are not currently top10 ghost-exposed (`15 day` cutoff)
- [x] Add tests:
      - [x] top10 promotion
      - [x] demotion exposure removal
      - [x] deterministic playback reproducibility from promoted ghost blob
      - implemented in:
        - `services/replay_validator/test/ghost_publisher_test.dart`
        - `functions/test/ghosts/ghost_callable.test.ts`
        - `test/ui/state/ghost_replay_cache_test.dart`
        - `test/game/replay/ghost_playback_runner_test.dart`

Done when:

- only top10 entries expose ghosts
- ghost playback uses verified replay lineage, not second client trust path

## Phase 7: Weekly Mode Activation

Objective:

- activate Weekly as a first-class mode using the same validated pipeline

Tasks:

- [x] Add Weekly mode support in selection/run prep/navigation/UI labels.
- [x] Add weekly board key/window resolution (`windowId = weekId`) in backend.
- [x] Add weekly leaderboard browsing through online APIs.
- [x] Add weekly rollover handling (new board identities per week).
- [x] Wire weekly achievement/progression hooks to validated outcomes.
      - ownership reward-grant reconciliation now updates
        `progression.weeklyProgress` from validated weekly grants
      - hub weekly badge now reflects current weekly validated progression
- [x] Add tests:
      - [x] weekly start gating
      - [x] week rollover board rotation behavior
      - [x] weekly leaderboard reads and rank behavior
      - implemented in:
        - `functions/test/runs/run_session_callable.test.ts`
        - `functions/test/leaderboards/leaderboard_callable.test.ts`
        - `test/ui/state/app_state_leaderboard_test.dart`

Done when:

- Weekly is fully playable and ranked through validated submission flow
- Weekly uses board identity/window rules without custom side paths

## Cross-Cutting Tasks

These are mandatory alongside phase work, not after all phases.

- [ ] Keep shared contracts synchronized across:
      - `packages/run_protocol/**`
      - `functions/src/**`
      - `lib/ui/state/**`
      - `services/replay_validator/**`
- [ ] Keep IAM least-privilege boundaries enforced and documented.
- [ ] Keep Firestore/Storage rules client-deny for authority collections/artifacts.
- [x] Keep account deletion coverage current as new collections are introduced:
      - update `functions/src/account/delete.ts`
      - update `functions/test/account/account_delete_callable.test.ts`
- [x] Keep retention cleanup jobs aligned with documented TTL policies.
- [ ] Keep docs synchronized:
      - `docs/building/replayValidation/replay-validation-plan.md`
      - `AGENTS.md` files if boundaries/rules change
      - `README.md` if public capability/setup changes
- [ ] Keep rejection reasons typed and stable across backend + Flutter adapters.
- [ ] Keep determinism and idempotency invariants covered by tests.

## Release Gates

Gate A: Validation Foundation

- [ ] Phases 1-4 complete
- [ ] end-to-end submit/validate terminal status stable in staging
- [ ] no duplicate rewards/entries under forced retry tests

Gate B: Competitive Authority Cutover

- [ ] Phase 5 complete
- [ ] client-authoritative reward path removed
- [ ] local Competitive leaderboard writes removed
- [ ] leaderboard and rewards validated in staging load tests

Gate C: Ghost Launch

- [ ] Phase 6 complete
- [ ] top10 ghost promotion/demotion stable
- [ ] ghost manifest/download paths verified for compat/version rules

Gate D: Weekly Launch

- [ ] Phase 7 complete
- [ ] weekly rollover operation runbook verified
- [ ] weekly leaderboard + rewards + ghost rules validated

## Verification Commands

Run targeted checks as each phase lands:

- [x] `dart analyze lib test`
- [ ] `flutter test test/core`
- [ ] `flutter test test/game`
- [ ] `flutter test test/ui`
- [x] `corepack pnpm --dir functions build`
- [x] `corepack pnpm --dir functions test`

Run these once new package/service directories exist:

- [x] `dart analyze packages/runner_core packages/run_protocol services/replay_validator`
- [x] `dart test packages/runner_core/test`
- [x] `dart test packages/run_protocol/test`
- [x] `dart test services/replay_validator/test`

## Exit Criteria

The replay-validation implementation is complete when:

- all reward-bearing runs require network/auth/session issuance
- canonical replay blobs are captured from applied command streams
- submissions are durable, asynchronous, and terminally resolved server-side
- validator authority is headless, deterministic, and retry-safe
- gold rewards come only from validated results
- Competitive/Weekly ranking and top10 ghost publication are server-owned
- Practice remains unranked online while keeping local PB display
- Weekly mode runs through the same validated authority path
- account deletion and retention policies cover all new replay/board/ghost data
