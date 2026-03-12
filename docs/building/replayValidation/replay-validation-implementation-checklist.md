# Replay Validation Implementation Checklist

Date: March 12, 2026  
Status: Planned (0/7 phases complete)  
Source plan: `docs/building/replayValidation/replay-validation-plan.md`

## Goal

Turn the replay-validation production plan into an execution checklist with:

- phase-locked delivery order
- concrete file/package targets
- explicit done criteria per phase
- cross-layer validation and release gates

## Delivery Assumptions

- Current Competitive leaderboard state is local-only and non-authoritative, so
  no production leaderboard migration is required.
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

- [ ] Confirm canonical naming and literals for:
      - `RunMode`: `practice|competitive|weekly`
      - board statuses: `scheduled|active|closed|disabled`
      - run-session states: `issued|uploading|uploaded|pending_validation|validating|validated|rejected|expired|cancelled|internal_error`
- [ ] Lock window cadence and ids:
      - Competitive season window = one UTC calendar month
      - Competitive `windowId` format = `YYYY-MM` (for example `2026-03`)
      - Weekly window = one week with unique `weekId`
- [ ] Confirm environment ownership:
      - Functions control-plane service account
      - Cloud Tasks dispatch service account
      - validator runtime service account
- [ ] [YOU - REQUIRED BEFORE PHASE 3] Create service accounts in
      `rpg-runner-d7add`:
      - `sa-run-control@rpg-runner-d7add.iam.gserviceaccount.com`
      - `sa-replay-task-dispatch@rpg-runner-d7add.iam.gserviceaccount.com`
      - `sa-replay-validator@rpg-runner-d7add.iam.gserviceaccount.com`
- [ ] [YOU - REQUIRED BEFORE PHASE 3] Apply IAM bindings:
      - `sa-run-control`:
        - `roles/datastore.user` (project)
        - `roles/cloudtasks.enqueuer` (queue `replay-validation`)
        - `roles/iam.serviceAccountTokenCreator` on itself
      - `sa-replay-task-dispatch`:
        - `roles/run.invoker` on Cloud Run `replay-validator`
      - `sa-replay-validator`:
        - `roles/datastore.user` (project)
        - Storage IAM Conditions for:
          - read `replay-submissions/**`
          - write/delete `ghosts/**`
- [ ] [YOU - REQUIRED BEFORE PHASE 3] Deploy Functions runtime with service
      account `sa-run-control`.
- [ ] [YOU - REQUIRED BEFORE PHASE 4 TESTING] Provision execution surfaces:
      - create Cloud Tasks queue `replay-validation`
      - deploy private Cloud Run service `replay-validator`
        using service account `sa-replay-validator`
      - configure queue OIDC service account `sa-replay-task-dispatch`
- [ ] [YOU - REQUIRED BEFORE BOARD TOOLING ENABLEMENT] Create admin principal:
      - `group:rpg-runner-board-admins@<your-domain>`
      - restrict board-management endpoints to this principal only
- [ ] Define initial operational defaults:
      - replay upload max size = `8 MiB` (`8,388,608` bytes)
      - upload grant TTL = `15 minutes`
      - run session expiry (`RunTicket.expiresAtMs`) = `24 hours`
      - validator retry budget = `8 attempts`
      - validator retry backoff = `30s,2m,5m,15m,30m,1h,2h,4h`
      - UI `verification delayed` threshold = `5 minutes`
      - player rank cache TTL = `60 seconds`
      - stale pending upload cutoff = `48 hours`
      - non-Top-10 validated replay blob TTL = `30 days`
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

- [ ] Create package scaffold:
      - `packages/runner_core/pubspec.yaml`
      - `packages/runner_core/lib/runner_core.dart`
      - `packages/runner_core/lib/**`
      - `packages/runner_core/test/**`
- [ ] Remove legacy in-app Core source tree after migration to
      `packages/runner_core`.
- [ ] Export public core surface from `package:runner_core/runner_core.dart`.
- [ ] Update Flutter app imports from legacy Core paths to
      `package:runner_core/**` in:
      - `lib/game/**`
      - `lib/ui/**`
      - `test/**`
- [ ] Update root package wiring so app resolves local path dependency to
      `packages/runner_core`.
- [ ] Enforce pure Dart boundaries:
      - no Flutter imports
      - no Flame imports
- [ ] Add/port deterministic tests in `packages/runner_core/test/**` for:
      - same seed -> same canonical outcome
      - stable score/distance/duration/tick behavior
- [ ] Add a headless smoke test that instantiates and ticks `GameCore` without
      Flutter bootstrapping.

Done when:

- app compiles and runs against `package:runner_core`
- `runner_core` is Flutter-free and Flame-free
- deterministic tests pass in the new package

## Phase 2: Build `packages/run_protocol` And Replay Recorder

Objective:

- lock shared contracts and produce canonical replay capture bytes on client

Tasks:

- [ ] Create protocol package scaffold:
      - `packages/run_protocol/pubspec.yaml`
      - `packages/run_protocol/lib/**`
      - `packages/run_protocol/test/**`
- [ ] Implement protocol DTOs and enums:
      - `run_mode.dart`
      - `board_key.dart`
      - `board_manifest.dart`
      - `run_ticket.dart`
      - `replay_blob.dart`
      - `replay_digest.dart`
      - `validated_run.dart`
      - `leaderboard_entry.dart`
      - `submission_status.dart`
- [ ] Encode practice-mode boardless invariants in schema:
      - `ReplayBlobV1.boardId/boardKey` optional
      - `ValidatedRun.boardId/boardKey` optional
      - required for Competitive/Weekly only
- [ ] Implement canonical sort-key builder utility shared by backend and
      validator.
- [ ] Implement stable codec and digest rules in `lib/codecs/**`.
- [ ] Add protocol tests:
      - encode/decode round-trip
      - canonical digest determinism
      - invalid payload rejection
- [ ] Add applied-command observer to `lib/game/game_controller.dart`:
      - immutable frame per stepped tick
      - no raw gesture/pointer recording
- [ ] Implement file-backed recorder pipeline:
      - streaming frame write
      - streaming digest
      - finalize into replay blob
- [ ] Centralize replay quantization policy in one shared module and ensure
      runtime play + replay capture use identical rules.
- [ ] Add long-run replay reproducibility tests:
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

- [ ] Refactor run mode domain in Flutter:
      - replace `RunType` with `RunMode` in `lib/ui/state/selection_state.dart`
      - update run setup/hub/routes/args/UI labels
- [ ] Introduce run-start descriptor flow in `lib/ui/state/app_state.dart`:
      - replace `buildRunStartArgs()` with async `prepareRunStartDescriptor()`
      - require live auth and connectivity for all modes
- [ ] Add backend domains and callable exports:
      - `functions/src/boards/**`
      - `functions/src/runs/**`
      - updates in `functions/src/index.ts`
- [ ] Implement board load callable:
      - active board resolution
      - `gameCompatVersion` gating
      - board status handling (`disabled` blocks issuance)
- [ ] Implement Competitive window rules:
      - resolve current UTC month window id (`YYYY-MM`)
      - enforce month-boundary open/close timestamps
      - prevent overlapping active Competitive boards per level/month window
- [ ] Implement `runSessionCreate`:
      - derive authoritative start snapshot from canonical ownership state
      - bind ticket to uid/mode/loadout snapshot
      - board-bound for Competitive/Weekly
      - create `run_sessions/{runSessionId}` in `issued`
- [ ] Update client run-prep adapters in `lib/ui/state/**` for board/ticket APIs.
- [ ] Remove local reward-bearing seed authority and local timestamp `runId`
      authority for submittable runs.
- [ ] Ensure starts fail closed without network/auth/session issuance.
- [ ] Add tests:
      - mode gating and board compat checks
      - Competitive month-window resolution and month rollover behavior
      - server-derived snapshot mismatch rejection
      - ticket issuance auth/user checks

Done when:

- no run mode can start without server-issued session authority
- Competitive/Weekly starts are board-bound and compat-gated
- client-local seed/run-id authority is removed for reward-bearing runs

## Phase 4: Submission Pipeline + Validator Service

Objective:

- deliver durable upload/finalize/validate pipeline with idempotent retries

Tasks:

- [ ] Implement run submission client components in `lib/ui/state/**`:
      - `run_boards_api.dart`
      - `firebase_run_boards_api.dart`
      - `run_session_api.dart`
      - `firebase_run_session_api.dart`
      - `run_submission_coordinator.dart`
      - `run_submission_spool_store.dart`
      - `pending_run_submission.dart`
      - `run_submission_status.dart`
- [ ] Implement callable/API surface in backend:
      - `runSessionCreateUploadGrant`
      - `runSessionFinalizeUpload`
      - `runSessionLoadStatus`
- [ ] Enforce upload grant constraints:
      - single run-session path
      - short-lived signed grant
      - size bounds
      - content-type constraints
- [ ] Implement run-session state transitions and legal-transition checks:
      - `issued -> uploading -> uploaded -> pending_validation -> validating -> terminal`
      - idempotent finalize for same metadata
      - conflict rejection for mismatched re-finalize
- [ ] Add Cloud Tasks enqueue path from finalize.
- [ ] Create validator service package:
      - `services/replay_validator/pubspec.yaml`
      - `services/replay_validator/bin/server.dart`
      - `services/replay_validator/lib/src/**`
      - `services/replay_validator/test/**`
- [ ] Implement worker algorithm:
      - lease acquire/release
      - blob fetch + digest verification
      - protocol sanity checks
      - headless core replay
      - validated run persistence
      - terminal session update
- [ ] Implement retry/backoff and exhausted-retry terminalization
      (`internal_error`).
- [ ] Add cleanup jobs for:
      - expired sessions
      - stale pending uploads
- [ ] Add metrics/log dimensions (runSessionId-centric traceability).
- [ ] Add tests:
      - duplicate task idempotency
      - bad digest/protocol rejection
      - enqueue retry safety
      - pending submission survives app restart

Done when:

- replay submission works end-to-end from client spool to terminal status
- validator can replay and decide deterministically without duplicate side effects
- pipeline is retry-safe and operationally observable

## Phase 5: Reward + Leaderboard Authority Cutover

Objective:

- move rewards and ranking to server-validated authority for all relevant modes

Tasks:

- [ ] Implement validated run storage and projection updates:
      - `validated_runs/{runSessionId}`
      - `leaderboard_boards/{boardId}/player_bests/{uid}`
      - `leaderboard_boards/{boardId}/views/top10`
- [ ] Implement reward grant writing:
      - `reward_grants/{runSessionId}`
      - no direct ownership canonical writes from validator
- [ ] Update ownership flows (`functions/src/ownership/**`) to reconcile unapplied
      grants transactionally.
- [ ] Add leaderboard read APIs:
      - `leaderboardLoadBoard`
      - `leaderboardLoadMyRank`
- [ ] Implement exact-rank query path from canonical `sortKey`.
- [ ] Remove client-authoritative reward path:
      - `RunnerGameWidget` no longer calls `AppState.awardRunGold(...)`
      - stop trusting `RunEndedEvent.goldEarned` for authority
- [ ] Remove local Competitive leaderboard authority:
      - no writes to `shared_prefs_leaderboard_store.dart` for Competitive
- [ ] Preserve Practice local PB display as local-only (not online authority).
- [ ] Update Game Over and leaderboard UI to show provisional/submission/validated
      states clearly.
- [ ] Add tests:
      - reward grant idempotency
      - lower-than-best run does not replace best
      - improved run updates best + top10
      - Practice validated rewards with no leaderboard projection

Done when:

- gold in all modes comes from validated results only
- Competitive/Weekly leaderboard authority is server-side only
- old local gold and local Competitive ranking authority paths are removed

## Phase 6: Ghost Publication + Deterministic Playback

Objective:

- expose ghosts only from verified top10 replay lineage

Tasks:

- [ ] Implement ghost promotion flow on accepted Competitive/Weekly runs that are
      top10:
      - promote verified replay lineage to `ghosts/{boardId}/{entryId}/...`
- [ ] Implement demotion handling:
      - revoke ghost exposure when entry falls out of top10
      - retain/delete artifacts by retention policy
- [ ] Implement ghost read surface:
      - `ghostLoadManifest` backend endpoint
      - client manifest/download API
- [ ] Implement client ghost cache and replay bootstrapping from verified payload.
- [ ] Implement deterministic ghost playback integration in run experience.
- [ ] Ensure non-top10 accepted replays remain validation artifacts only with TTL.
- [ ] Add tests:
      - top10 promotion
      - demotion exposure removal
      - deterministic playback reproducibility from promoted ghost blob

Done when:

- only top10 entries expose ghosts
- ghost playback uses verified replay lineage, not second client trust path

## Phase 7: Weekly Mode Activation

Objective:

- activate Weekly as a first-class mode using the same validated pipeline

Tasks:

- [ ] Add Weekly mode support in selection/run prep/navigation/UI labels.
- [ ] Add weekly board key/window resolution (`windowId = weekId`) in backend.
- [ ] Add weekly leaderboard browsing through online APIs.
- [ ] Add weekly rollover handling (new board identities per week).
- [ ] Wire weekly achievement/progression hooks to validated outcomes.
- [ ] Add tests:
      - weekly start gating
      - week rollover board rotation behavior
      - weekly leaderboard reads and rank behavior

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
- [ ] Keep account deletion coverage current as new collections are introduced:
      - update `functions/src/account/delete.ts`
      - update `functions/test/account/account_delete_callable.test.ts`
- [ ] Keep retention cleanup jobs aligned with documented TTL policies.
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

- [ ] `dart analyze lib test`
- [ ] `flutter test test/core`
- [ ] `flutter test test/game`
- [ ] `flutter test test/ui`
- [ ] `corepack pnpm --dir functions build`
- [ ] `corepack pnpm --dir functions test`

Run these once new package/service directories exist:

- [ ] `dart analyze packages/runner_core packages/run_protocol services/replay_validator`
- [ ] `dart test packages/runner_core/test`
- [ ] `dart test packages/run_protocol/test`
- [ ] `dart test services/replay_validator/test`

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
