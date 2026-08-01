# Account Deletion Workflow

## Status

Implemented and deployed on July 19, 2026. Two synthetic workflows completed
the final reconciliation and Auth-deletion path; the controlled evidence is in
the
[Functions production verification record](../building/functions-audit-remediation/production-verification-2026-07-19.md).
The engineering privacy review accepted a compact 30-day maximum with launch
conditions; see the
[retention review](../building/functions-audit-remediation/deletion-retention-privacy-review-2026-07-19.md).

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

The callable transaction creates the tombstone before attempting any Auth or
data operation. Once the document exists:

- every user-facing profile, ownership, board, run, leaderboard, and ghost
  callable rejects the UID;
- profile and ownership lazy creation reads the tombstone inside the same
  transaction that would create data;
- ownership command, run-session creation, upload-grant, finalize, and
  post-enqueue run-session transactions read the same tombstone before writing;
- validator terminal handoffs, reward settlement/backfill, validation repair,
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

The callable response status is one of `requested`, `in_progress`,
`retryable`, or `deleted`. All four mean the server owns the deletion request.
Flutter clears in-memory state, the ownership outbox, run-submission spool,
and the app-owned replay recorder directory before it signs out for any of
them. The recorder cleanup is limited to its dedicated temporary directory; it
does not trust arbitrary replay paths stored in submission metadata. A
retryable backend page is recovered by the scheduled worker and does not
require the deleted account to remain authenticated.

## Scheduling, retention, and operations

`accountDeletionRepair` runs every 15 minutes during pre-release cost
containment. Each request records attempts, stage, last retryable error, age
inputs, and aggregate deletion counters for operator inspection. Missing Auth
users and already-missing data/artifacts are normal idempotent outcomes. This
temporarily trades deletion-recovery latency for lower idle cost; before public
release, restore a measured cadence and re-verify the alert thresholds and
end-to-end deletion duration.

The repair worker selects active requests in ascending `requestedAtMs` order
through the source-controlled `state` plus `requestedAtMs` composite index. It
reads one extra document beyond the bounded processing page to expose
`activePageSaturated` without an unbounded count. Its structured heartbeat also
reports oldest age/stage, maximum attempt count, and retryable backlog. The
heartbeat contains no account identifier. Retryable-failure logs use a
16-character SHA-256 UID hash rather than raw UID.

Source-controlled production policies under
`functions/monitoring/account_deletion/` alert on:

- any transition to retryable failure;
- incomplete work at least twelve hours old or at 400 attempts;
- unexpected scheduled repair runtime errors.

Twelve hours accommodates the pre-release 15-minute repair cadence and the
normal multi-board repeated-reconciliation workflow. A threshold change
requires updated production-duration evidence and this document.

The implemented policy retains the compact completed tombstone for at most 30
days. The record exists only to keep the deletion barrier fail-closed and to
support bounded deletion/security incident evidence. It contains no gameplay
or identity-provider data.

The scheduled worker evaluates expiry every 15 minutes and deletes up to 10
expired completed records per invocation. Firestore native TTL is not enabled
because the source-controlled expiry field is integer epoch milliseconds while
native TTL requires a timestamp. A separate bounded completed-record inventory
walks document IDs with a durable maintenance cursor, records only aggregate
counts, and reports missing expiry, expired evidence, and non-minimal
completions without logging an account identifier.

The engineering privacy review accepted this policy with launch conditions.
The public privacy policy and external deletion resource must disclose the
purpose, fields, 30-day maximum, and automatic deletion. The project owner must
select the applicable lawful basis and obtain jurisdiction-specific advice if
needed. Changing the fields, purpose, or duration requires updating this
document, the retention review, and the EU-compliance checklist.

## Validation

Emulator tests cover:

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
- final Auth deletion only after reconciliation.
- asynchronous validation, settlement, projection, and ghost writes are
  tombstone-fenced and deletion-owned task results do not retry;
- accepted client deletion clears durable ownership/submission metadata and
  the app-owned recorder artifacts;
- completed-tombstone inventory detects missing expiry, expired evidence, and
  non-minimal records.

Production verification additionally confirmed:

- the original one-minute repair scheduler and IAM path before the pre-release
  cost-containment cadence change;
- three-pass final reconciliation after the 15-minute signed-upload quiet
  period;
- deletion of the synthetic Auth users, Firestore documents, pending replay
  objects, and ghost artifact;
- restoration of gameplay/projection counts to the pre-canary baseline;
- completion in 18.1 to 18.9 minutes with no retryable terminal state.

Production monitoring verification additionally confirmed the ordered index
as `READY`, structured zero-work heartbeats from the deployed repair revision,
all three policies enabled on the verified email channel, and an exact-filter
synthetic event that touched no deletion state.
