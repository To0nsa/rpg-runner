# Account Deletion Workflow

## Status

Implementation reviewed and hardened on September 15, 2026. This document
describes the repository source; the September changes have not been verified
in production. The original workflow was deployed on July 19, 2026. Two synthetic
workflows completed the final reconciliation and Auth-deletion path; the
controlled evidence is in the
[Functions production verification record](../archive/2026-09-15/building/functions-audit-remediation/production-verification-2026-07-19.md).
The historical engineering privacy review accepted compact completion evidence
with a 30-day maximum and launch conditions; see the
[retention review](../archive/2026-09-15/building/functions-audit-remediation/deletion-retention-privacy-review-2026-07-19.md).

## Purpose

Account deletion is a tombstone-first, asynchronous erasure workflow. The
authenticated callable accepts the request and returns after establishing
durable ownership of the deletion; the player does not remain signed in while
Firestore and Storage cleanup continues.

The implementation lives in:

- `functions/src/account/delete.ts`
- `functions/src/account/deletion_guard.ts`
- `functions/src/index.ts`
- `lib/ui/state/profile/account_deletion_api.dart`
- `lib/ui/state/profile/firebase_account_deletion_api.dart`
- `lib/ui/state/app/controllers/auth_profile_controller.dart`
- `lib/ui/state/run/run_submission_coordinator.dart`
- `services/replay_validator/lib/src/run_session_repository.dart`
- `services/replay_validator/lib/src/validated_replay_archiver.dart`

## Callable authorization and payload

`accountDelete` requires a Firebase-authenticated UID linked to Google Play
Games and an `auth_time` no more than five minutes old. A token refresh does
not renew that authentication time. Flutter reauthenticates before requesting
deletion. App Check follows the configured monitoring/enforcement policy and
does not replace identity checks.

The request is `{ "userId": "<authenticated UID>", "sessionId": "<client session>" }`.
Both strings are required and payload bounds apply. `userId` must match
Firebase Auth. `sessionId` is parsed client metadata, not authorization.
The account-delete quota is consumed before the tombstone transaction; this
route alone permits repeated requests for a tombstoned UID.

The response is `{ "result": { "status": "in_progress", "requestId": "<UID>" } }`.
Statuses are `requested`, `in_progress`, `retryable`, and `deleted`. All mean
the server owns deletion; `deleted` corresponds to the checkpoint's `complete`
state. Repeated authorized requests use the same UID checkpoint. The callable
also attempts one bounded worker stage, normally Auth disable/revocation,
before responding. Stage failures return `retryable` after durable acceptance.

Missing authentication, missing linked identity, stale authentication,
mismatched UID, invalid payload, and enforced quota failures reject acceptance.
Stale authentication is `failed-precondition` with reason
`recent-auth-required`; Flutter maps it to `requiresRecentLogin`.

## State and checkpoint contract

`account_deletion_requests/{uid}` is both the write barrier and the durable
workflow checkpoint. Its states are:

- `requested`: tombstone committed and no worker page has started.
- `in_progress`: a worker owns or most recently completed a page.
- `retryable`: the last page failed; the stage and counters remain resumable.
- `complete`: the final zero-change reconciliation passed and Firebase Auth was
  deleted.

While active, the record stores the current stage, pass number, final-pass
flag, per-pass deletion count, nested-board cursor, bounded lease token/expiry,
attempt count, last error class/message, and aggregate deletion counters. The
UID is the request ID, so repeated calls converge on one workflow.

On completion, all workflow mechanics and diagnostics are removed. The
document retains exactly `state`, `requestedAtMs`, `completedAtMs`, and
`expiresAtMs`; the UID remains only as the document ID.

Workers acquire a five-minute transactional lease. A crash after deleting data
but before checkpointing is safe: the same bounded page is retried and missing
documents/objects are accepted.

## Authority and concurrency boundary

After authorization and quota accounting, the callable transaction creates the
tombstone before attempting any Auth disable or erasure operation. Once the document exists:

- every user-facing profile, ownership, board, run, leaderboard, and ghost
  callable rejects the UID;
- profile and ownership lazy creation reads the tombstone inside the same
  transaction that would create data;
- ownership command, run-session creation, upload-grant, finalize, and
  post-enqueue run-session transactions read the same tombstone before writing;
- validator lease acquisition and terminal handoffs, reward settlement/backfill, validation repair,
  leaderboard player-best/top-10 projection, and ghost-manifest writes read
  the tombstone in their write transaction. A concurrent tombstone creation
  aborts that commit; projection and validation then acknowledge the task as
  deletion-owned instead of retrying it;
- Firestore rules deny direct client access to the tombstone and all
  authoritative user collections.

Firebase Auth is disabled and refresh tokens are revoked in the first worker
stage. Already-issued ID tokens remain possible until expiry, which is why the
Firestore tombstone remains the immediate server-side barrier.

## Bounded erasure inventory

The worker processes at most one bounded page per invocation across this
explicit inventory:

- `player_profiles`
- `display_name_index`
- `ownership_profiles`
- `ownership_profiles/*/idempotency`
- `abuse_quota`
- `run_sessions`
- `validated_runs`
- `reward_grants`
- `ghost_runs`
- `leaderboard_ghost_runs`
- `weekly_ghost_runs`
- `leaderboard_boards/*/ghost_manifests`
- `leaderboard_boards/*/player_bests`
- affected `leaderboard_boards/*/views/top10`
- `replay-submissions/pending/{uid}/**`
- `replay-submissions/validated/{runSessionId}.bin.gz`
- referenced `ghosts/**` artifacts

New UID-owned schemas, projections, or Storage prefixes must extend this
inventory and its emulator test before shipping.

Top-level UID queries repeat from the beginning until empty; they do not advance
past deleted documents. Nested ownership and board collections use durable
parent cursors and bounded child pages. A later full pass revisits all stages,
so records inserted by previously queued server work are detected.

Board player-best deletion and affected `top10` invalidation commit in one
Firestore transaction. The worker also inspects the view independently of
player-best existence and removes an orphaned view containing the UID. A view
containing only other players is preserved when no owned best is removed.
The board page caps its query at 498 documents, reserving writes for a separate
canonical best and the view within a 500-write transaction.

Run-session erasure defers records in `validating` with an unexpired validation
lease. New leases are tombstone-fenced, so deletion retains the run IDs for
existing validators without admitting new ones. Validation leases default to
ten minutes. Before starting an archive copy, the validator checks the account
barrier and its lease expiry. If deletion blocks the handoff, it deletes the
copied generation with `ifGenerationMatch`; a replacement generation is never
deleted by that compensation. This deletion classification also covers errors
from rejection/retry handlers and missing run documents.

If a validator crashes after copying, or compensating Storage deletion fails,
the erasure worker retries archive deletion using the preserved run ID after
lease expiry, before deleting the run record. Archive deletion failure leaves
the record and stage resumable. The general 15-day artifact-retention sweep is
not the account-deletion recovery mechanism. Worker deployments must preserve
bounded validation execution and lease expiry checks; lease fencing cannot
make Firestore and Storage commit atomically.

## Signed-upload and final reconciliation rule

An upload URL issued before deletion can remain valid for 15 minutes. The
worker therefore:

1. runs ordinary erasure passes until a complete pass deletes nothing;
2. waits until the signed-upload lease window from `requestedAtMs` has expired;
3. starts a fresh final pass from the profile stage;
4. repeats that final pass if it deletes anything;
5. deletes Firebase Auth only after a final pass deletes nothing.

This prevents a late upload from appearing after Storage was swept but before
completion.

## Client contract

Flutter accepts only an explicit recognized status with `requestId` matching
the requested UID. Empty/malformed responses, unknown statuses, and legacy
boolean success payloads produce `failed` / `invalid-response` and leave the
account state intact. Transport/backend rejection likewise does not discard
local state.

After acceptance, Flutter immediately clears in-memory profile, ownership,
progression, authentication, run statuses, and ticket prefetch state before
attempting device cleanup or sign-out. That AppState instance rejects further
authentication and ignores late canonical/profile results. It cancels the
ownership timer and waits for an active ownership flush before clearing the
outbox. Submission-spool mutations are fenced for the coordinator's remaining
lifetime; writes already started are drained before clearing. Late upload
results cannot recreate submission metadata.

Ownership-outbox cleanup, submission-spool/recorder cleanup, and Firebase
sign-out are all attempted. Recorder cleanup is limited to its dedicated
temporary directory and does not trust arbitrary metadata paths. Failures are
reported in `AccountDeletionResult.localCleanupIssues` as `ownershipOutbox`,
`replaySubmissions`, or `signOut`. `succeeded` continues to mean server
acceptance; `localCleanupSucceeded` reports the separate device outcome.

The profile page closes the app only when device cleanup succeeds. Otherwise
it shows an accepted-deletion message with `Retry cleanup`. Retrying invokes
`retryAccountDeletionLocalCleanup` without reauthentication or another backend
deletion request. This receipt/retry state is in memory, not a durable
cross-restart cleanup journal; failed OS/file/preference operations are not
claimed to have erased device data. A retryable backend stage remains owned
by the scheduled worker independently of the client's authentication state.

## Scheduling, retention, and operations

`accountDeletionRepair` is configured to run every minute in UTC, selecting up
to ten active requests and processing one stage page per selected request.
Pages default to 100 items, with validated bounds of 1–500. Each request records
attempts, stage, last retryable error, age inputs, and aggregate deletion counters
for operator inspection. Missing Auth
users and already-missing data/artifacts are normal idempotent outcomes. This
cadence replaces the former fifteen-minute cost-containment setting: three
ordinary/final inventory passes alone need at least 62 scheduled stage ticks
for a populated account, before extra pages and board traversal. At fifteen
minutes per tick, that lower bound was 15.5 hours and already exceeded the
twelve-hour alert budget. At one minute per tick it is 62 minutes. These are
stage-count estimates, not production-duration measurements; large accounts,
many boards, leases, retries, and queue saturation add time.

The repair worker selects active requests in ascending `requestedAtMs` order
through the source-controlled `state` plus `requestedAtMs` composite index. It
reads one extra document beyond the bounded processing page to expose
`activePageSaturated` without an unbounded count. Its structured heartbeat also
reports oldest age/stage, maximum attempt count, and retryable backlog. The
age, attempts, and retryable counts describe the selected bounded page, not
the entire collection. Oldest requests retain priority; saturation requires
operator attention because later requests may wait behind persistent failures.
The heartbeat contains no account identifier. Retryable-failure logs use a
16-character SHA-256 UID hash rather than raw UID.

Source-controlled production policies under
`functions/monitoring/account_deletion/` alert on:

- any transition to retryable failure;
- incomplete work at least twelve hours old or at 720 attempts;
- an expired-completion cleanup page containing more than ten eligible records;
- unexpected scheduled repair runtime errors.

Twelve hours and 720 attempts are operator safety budgets, not completion
guarantees. The attempt budget matches twelve hours of one-minute ticks and
accommodates ordinary retained-board traversal. The September production canary
passed 432 successful stages before its final pass across 56 retained boards
and three private fixtures, without retryable failures; the former 400-attempt
alert was too low for that traversal. The regression fixture verifies
populated-account completion under the twelve-hour budget using simulated
one-minute ticks. Production duration,
scheduler cadence, ordered indexes, and alert delivery must be reverified after
deploying this revision. Log-match policies cannot detect a scheduler that
stops emitting logs: scheduler execution and heartbeat freshness must also be
checked by operations.

`expiresAtMs` is set to completion time plus 30 days. It is an expiry deadline,
not a strict bound on physical Firestore removal. The record exists
only to keep the deletion barrier fail-closed and to
support bounded deletion/security incident evidence. It contains no gameplay
or identity-provider data.

The scheduled worker evaluates expiry every minute and deletes up to ten
expired completed records per invocation, oldest expiry first. Its query filters
`state = complete` using the source-controlled `state` + `expiresAtMs` index;
an active record with malformed expiry cannot obstruct the completed page. One
lookahead exposes `expiredCompletionPageSaturated` without an unbounded count.
A healthy scheduler still permits interval/jitter delay; a backlog or outage
extends retention until successful cleanup. Missing/invalid expiry is reported
for operator repair rather than silently assigned a new retention window.
Firestore native TTL is not enabled
because the source-controlled expiry field is integer epoch milliseconds while
native TTL requires a timestamp. A separate bounded completed-record inventory
walks document IDs with a durable maintenance cursor under
`system_maintenance/account_deletion_completed_tombstone_inventory`. Its cursor
temporarily stores a UID document key and resets at the end of a traversal;
page diagnostics and logs contain only aggregate counts. It reports missing
expiry, expired evidence, and non-minimal
completions without logging an account identifier.

The historical engineering privacy review accepted the compact record with
launch conditions; it does not establish a hard removal bound for this source.
The public privacy policy and external deletion resource must disclose the
purpose, fields, the 30-day expiry deadline, automatic cleanup, and operational
delays accurately; the historic review's strict maximum must not be presented
as an implemented removal guarantee. The project owner must
select the applicable lawful basis and obtain jurisdiction-specific advice if
needed. Changing the fields, purpose, or duration requires updating this
document, the retention review, and the EU-compliance checklist.

## Validation

Functions Firestore-emulator tests, with injected Auth/Storage dependencies,
cover:

- tombstone-before-disable ordering;
- transaction-protected lazy creation;
- multi-page ownership/idempotency/quota/run/reward/ghost cleanup;
- concurrent worker serialization;
- a crash after the side effects of each of all 23 ordered deletion stages,
  before checkpoint commit, followed by idempotent replay;
- a deliberately reinserted late record and pending upload;
- retryable Storage failure and resume;
- repeated delete requests;
- already-missing Auth users;
- final Auth deletion only after reconciliation;
- orphaned top-10 cleanup, preserving unrelated views, and atomic board erasure;
- retaining live-validator run IDs and deleting a late archive after expiry;
- populated-account completion with simulated one-minute repair ticks;
- expiry-page ordering, backlog lookahead, and malformed active-record isolation;
- completed-tombstone inventory detects missing expiry, expired evidence, and
  non-minimal records.

Dart validator tests use mocked repositories and HTTP clients to cover
tombstone-fenced lease/handoff/projection/ghost writes, generation-fenced archive
compensation, missing-record deletion classification, and exceptions raised in
retry handlers. Flutter tests cover all four accepted statuses, invalid response
rejection, memory reset before sign-out, cleanup failures/retry, and in-flight
spool/upload fencing. These tests do not exercise real Firebase Auth deletion,
Cloud Storage RPCs, deployed composite indexes, or scheduler/alert delivery.

Historical July production verification additionally confirmed:

- the original one-minute repair scheduler and IAM path before the pre-release
  cost-containment cadence change;
- three-pass final reconciliation after the 15-minute signed-upload quiet
  period;
- deletion of the synthetic Auth users, Firestore documents, pending replay
  objects, and ghost artifact;
- restoration of gameplay/projection counts to the pre-canary baseline;
- completion in 18.1 to 18.9 minutes with no retryable terminal state.

Historical production monitoring verification additionally confirmed the ordered
index as `READY`, structured zero-work heartbeats from the deployed repair revision,
all three policies enabled on the verified email channel, and an exact-filter
synthetic event that touched no deletion state.
The new expiry index and expired-backlog policy are source-controlled but have
not been deployed or production-verified by the September implementation pass.
